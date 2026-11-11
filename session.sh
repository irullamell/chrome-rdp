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

# Chromium: kalau ditutup, buka lagi (RDP user tidak boleh lihat layar kosong)
while :; do
    /usr/bin/chromium
    xset q >/dev/null 2>&1 || exit 0    # X sudah mati -> keluar, jangan loop
    sleep 1
done
