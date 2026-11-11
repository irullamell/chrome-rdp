#!/bin/bash
# ---------------------------------------------------------------------------
# Isi sesi X: window manager minimal + Chromium. Tidak ada panel/desktop.
# Optimasi: tanpa loop spinner, tanpa fork berlebih, restart cepat kalau
# jendela Chromium ditutup user (biar tidak pernah mendarat di layar kosong).
# ---------------------------------------------------------------------------
export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}
export XDG_SESSION_TYPE=x11
export BROWSER=/usr/bin/chromium
export LIBGL_ALWAYS_SOFTWARE=1
export MALLOC_ARENA_MAX=${MALLOC_ARENA_MAX:-2}

XDG_RUNTIME_DIR="/run/user/$(id -u)"
[ -d "$XDG_RUNTIME_DIR" ] && [ -w "$XDG_RUNTIME_DIR" ] || XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null
export XDG_RUNTIME_DIR

[ -S /run/pulse/native ] && export PULSE_SERVER=unix:/run/pulse/native

# profil terpisah per entrypoint (web vs RDP) supaya tidak saling lock
if [ -z "${BROWSER_PROFILE:-}" ] && [ "$(id -un)" != "root" ]; then
    BROWSER_PROFILE="$HOME/.config/chromium-rdp"
fi
if [ -n "${BROWSER_PROFILE:-}" ]; then
    mkdir -p "$BROWSER_PROFILE"
    export CHROMIUM_FLAGS="${CHROMIUM_FLAGS:-} --user-data-dir=${BROWSER_PROFILE}"
fi

# dbus session (dipakai Chromium untuk clipboard/notifikasi)
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax 2>/dev/null)"
    export DBUS_SESSION_BUS_ADDRESS
fi

# latar polos (tidak ada wallpaper manager = tanpa proses tambahan)
xsetroot -solid "#1e1e2e" 2>/dev/null || true

# window manager: tanpa dekorasi, selalu maximize
openbox --config-file /root/.config/openbox/rc.xml >/dev/null 2>&1 &

# Chromium dengan DevTools lokal (untuk memasang extension Auto Refresh).
# Port hanya 127.0.0.1 dan tidak pernah diekspos keluar container.
EXT_DIR="${EXT_DIR:-/opt/auto-refresh}"
AUTO_REFRESH_SECONDS="${AUTO_REFRESH_SECONDS:-0}"
DEBUG_PORT="${CHROMIUM_DEBUG_PORT:-9222}"

run_chromium() {
    local cdp=""
    if [ -d "$EXT_DIR" ]; then
        cdp="--enable-unsafe-extension-debugging --remote-debugging-port=${DEBUG_PORT}"
    fi
    # shellcheck disable=SC2086
    /usr/bin/chromium $cdp
}

# pasang extension sekali per boot (Chromium >= 137 mengabaikan --load-extension)
install_extension() {
    command -v python3 >/dev/null 2>&1 || return 0
    # Auto Refresh (MV3)
    if [ -d "$EXT_DIR" ]; then
        /usr/local/bin/ext-init.py --port "$DEBUG_PORT" --ext-dir "$EXT_DIR" \
            --seconds "$AUTO_REFRESH_SECONDS" >&2 || true
    fi
    # Extension tambahan (opsional). Contoh: uBlock Origin dari Debian
    #   EXTRA_EXT_DIRS="/usr/share/chromium/extensions/ublock-origin"
    for d in ${EXTRA_EXT_DIRS:-}; do
        [ -d "$d" ] || continue
        /usr/local/bin/ext-init.py --port "$DEBUG_PORT" --ext-dir "$d" \
            --seconds 0 >&2 || true
    done
}

while :; do
    run_chromium &
    CHROME_PID=$!
    ( sleep 3; install_extension ) &

    wait "$CHROME_PID"
    xset q >/dev/null 2>&1 || exit 0    # X sudah mati -> keluar, jangan loop
    sleep 1
done
