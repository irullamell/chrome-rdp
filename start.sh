#!/bin/bash
# ---------------------------------------------------------------------------
# Entrypoint container — browser only, TANPA password.
#
#   RDP mode : xrdp  on RDP_PORT  (default 3389)   -> langsung masuk sesi Chromium
#   WEB mode : noVNC on HTTP_PORT (default 8080)   -> halaman langsung connect
#
# Tidak ada password di mana pun:
#   - akun sistem dibuat "terkunci" (password hash '!')
#   - xrdp dijalankan tanpa PAM (EnablePAMAuth=false) + sesi [Xorg] pakai
#     username/password tetap -> form login xrdp dilewati (autorun)
#   - noVNC tanpa password VNC (tanpa -rfbauth)
#
# Env opsional:
#   ACCESS_TOKEN=<rahasia>   kunci akses sederhana (URL ?token=... atau cookie)
#   AUTH_PROXY=u:p@host:port proxy ber-bayar untuk publik (basic auth di proxy)
# ---------------------------------------------------------------------------
set -u

RDP_PORT="${RDP_PORT:-3389}"
HTTP_PORT="${HTTP_PORT:-8080}"
ENABLE_RDP="${ENABLE_RDP:-1}"
ENABLE_WEB="${ENABLE_WEB:-1}"
DEBUG="${DEBUG:-0}"
ACCESS_TOKEN="${ACCESS_TOKEN:-}"
AUTH_PROXY="${AUTH_PROXY:-}"
RDP_INI=/etc/xrdp/xrdp.ini
SESMAN_INI=/etc/xrdp/sesman.ini

# ---- akun sistem tanpa password yang bisa dipakai login --------------------
if ! id chromium >/dev/null 2>&1; then
    useradd -m -s /bin/bash chromium 2>/dev/null || true
fi
# password hash '!' = akun terkunci (tidak ada yang bisa login pakai password)
usermod -p '!' chromium 2>/dev/null || true

HOME_DIR=/home/chromium
mkdir -p "${HOME_DIR}/.config" "${HOME_DIR}/Downloads"
echo "browser-session" > "${HOME_DIR}/.xsession"
chown -R chromium:chromium "${HOME_DIR}" 2>/dev/null || true
chmod 700 "${HOME_DIR}/.xsession"
[ -f /root/.xsession ] || { echo "browser-session" > /root/.xsession; chmod 700 /root/.xsession; }

# ---- xrdp: tanpa PAM, sesi tanpa tanya kredensial, port dari env -----------
if [ -f "$RDP_INI" ]; then
    sed -i -E "0,/^[#;[:space:]]*port=.*/s//port=${RDP_PORT}/" "$RDP_INI"

    # [Globals] autorun=Xorg  -> langsung ke sesi, tidak lewat pemilihan sesi
    if grep -qE '^autorun=' "$RDP_INI"; then
        sed -i -E 's|^autorun=.*|autorun=Xorg|' "$RDP_INI"
    else
        sed -i -E '0,/^\[Globals\]/s//[Globals]\nautorun=Xorg/' "$RDP_INI"
    fi

    # hanya section [Xorg] yang aktif: username/password tetap, tidak "ask"
    awk '
        BEGIN { inx = 0 }
        /^\[Xorg\]/ { inx = 1; print; next }
        /^\[/ { inx = 0 }
        inx && /^username=/ { print "username=chromium"; next }
        inx && /^password=/ { print "password=chromium"; next }
        { print }
    ' "$RDP_INI" > "${RDP_INI}.tmp" && cat "${RDP_INI}.tmp" > "$RDP_INI"
    rm -f "${RDP_INI}.tmp"
fi

# sesman: jangan pakai PAM (akun terkunci), izinkan root, sesi tidak dimatikan
if [ -f "$SESMAN_INI" ]; then
    for kv in "EnablePAMAuth=false" "AllowRootLogin=true" "KillDisconnected=false" \
              "DisconnectedTimeLimit=0" "IdleTimeLimit=0"; do
        k="${kv%%=*}"
        if grep -qE "^${k}=" "$SESMAN_INI"; then
            sed -i -E "0,/^${k}=.*/s//${kv}/" "$SESMAN_INI"
        else
            sed -i -E "0,/^\[Globals\]/s//[Globals]\n${kv}/" "$SESMAN_INI"
        fi
    done
fi

# ---- Auto Refresh: policy managed (fallback) + env untuk extension ---------
export AUTO_REFRESH_SECONDS="${AUTO_REFRESH_SECONDS:-0}"
export EXT_DIR="${EXT_DIR:-/opt/auto-refresh}"
if [ -d /etc/chromium/policies/managed ]; then
    printf '{\n  "AutoRefreshSettings": { "seconds": %s, "enforce": %s }\n}\n' \
        "${AUTO_REFRESH_SECONDS:-0}" \
        "$([ "${AUTO_REFRESH_SECONDS:-0}" -gt 0 ] 2>/dev/null && echo true || echo false)" \
        > /etc/chromium/policies/managed/auto-refresh.json
fi

# ---- proxy autentikasi opsional (dipakai startwm.sh) -----------------------
rm -f /etc/xrdp/authproxy.conf
if [ -n "$AUTH_PROXY" ]; then
    echo "AUTH_PROXY=${AUTH_PROXY}" > /etc/xrdp/authproxy.conf
    chmod 600 /etc/xrdp/authproxy.conf
    export http_proxy="http://${AUTH_PROXY}" https_proxy="http://${AUTH_PROXY}"
    export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"
fi
export ACCESS_TOKEN

# ---- bersihkan state lama (restart-safe) -----------------------------------
rm -f /var/run/xrdp/*.pid /run/xrdp/*.pid /var/run/xrdp-sesman.pid \
      /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null
mkdir -p /var/run/xrdp /run/xrdp /tmp/.X11-unix /run/pulse /run/user/0 /var/log
chmod 1777 /tmp/.X11-unix; chmod 700 /run/user/0 2>/dev/null || true
[ -s /var/lib/dbus/machine-id ] || dbus-uuidgen > /var/lib/dbus/machine-id

# ---- /dev/shm & /tmp: penyebab #1 "Aw, Snap" di container -------------------
# shm_size di Railway/compose sering hanya 64 MB -> Chromium langsung crash.
# Kalau /dev/shm kecil, pasang tmpfs yang lebih besar DI ATASNYA (butuh
# CAP_SYS_ADMIN; kalau ditolak, launcher sudah memakai --disable-dev-shm-usage).
shm_mb() { df -m /dev/shm 2>/dev/null | awk 'NR==2 {print $2}'; }
SHM_NOW="$(shm_mb)"
if [ -n "${SHM_NOW:-}" ] && [ "$SHM_NOW" -lt "${SHM_MIN_MB:-512}" ] 2>/dev/null; then
    TARGET=1024
    if mount -t tmpfs -o "size=${TARGET}m,mode=1777" tmpfs /dev/shm 2>/dev/null; then
        echo "[init] /dev/shm diperbesar ${SHM_NOW}MB -> ${TARGET}MB"
    else
        echo "[init] /dev/shm hanya ${SHM_NOW}MB (tidak bisa mount) -> mode hemat shm aktif"
    fi
fi
# cache Chromium di /tmp; kalau /tmp bukan tmpfs, tetap aman (disk container)
mkdir -p /tmp/chromium-cache && chmod 1777 /tmp/chromium-cache 2>/dev/null || true

# ---- profil browser persisten kalau ada volume -----------------------------
if [ -d /data ]; then
    mkdir -p /data/chromium-profile /data/Downloads
    chown -R chromium:chromium /data 2>/dev/null || true
    [ -L "${HOME_DIR}/.config/chromium" ] || { rm -rf "${HOME_DIR}/.config/chromium"; \
        ln -sfn /data/chromium-profile "${HOME_DIR}/.config/chromium"; }
    [ -L "${HOME_DIR}/Downloads" ] || { rm -rf "${HOME_DIR}/Downloads"; \
        ln -sfn /data/Downloads "${HOME_DIR}/Downloads"; }
fi

# ---- sysctl (diabaikan host yang memblokir) --------------------------------
for kv in net.ipv4.tcp_keepalive_time=30 net.ipv4.tcp_keepalive_intvl=10 \
          net.ipv4.tcp_keepalive_probes=6 net.ipv4.tcp_slow_start_after_idle=0; do
    sysctl -w "$kv" >/dev/null 2>&1 || true
done

# ---- dbus + audio (satu kali, tanpa sleep) ---------------------------------
pgrep -x dbus-daemon >/dev/null || dbus-daemon --system --fork 2>/dev/null || true
pgrep -x pulseaudio >/dev/null || \
    pulseaudio --system --daemonize=yes --disallow-exit --exit-idle-time=-1 \
               -n --file=/etc/pulse/default.pa >/dev/null 2>&1 || mkdir -p /run/pulse

# ---- web (noVNC tanpa password) -------------------------------------------
start_web() {
    pgrep -f "websockify.*${HTTP_PORT}" >/dev/null && return 0
    setsid nohup /usr/local/bin/web-entry >>/var/log/web.log 2>&1 < /dev/null &
}

# ---- RDP -------------------------------------------------------------------
start_rdp() {
    pgrep -x xrdp >/dev/null && pgrep -x xrdp-sesman >/dev/null && return 0
    service xrdp start >/dev/null 2>&1 || /usr/sbin/xrdp >/dev/null 2>&1 || true
}

[ "$ENABLE_WEB" = "1" ] && start_web
[ "$ENABLE_RDP" = "1" ] && start_rdp

VER="$(/usr/local/bin/chromium-rdp --version 2>/dev/null || echo chromium)"
echo "=============================================================="
echo " Chromium Browser · TANPA PASSWORD · rdp=$([ "$ENABLE_RDP" = 1 ] && echo "$RDP_PORT" || echo off) · web=$([ "$ENABLE_WEB" = 1 ] && echo "$HTTP_PORT" || echo off)"
echo " ${VER}"
[ -n "$ACCESS_TOKEN" ] && echo " Akses dilindungi ACCESS_TOKEN (URL: /?token=...)"
echo "=============================================================="

[ "$DEBUG" = "1" ] && { touch /var/log/web.log; tail -n +1 -F /var/log/xrdp.log /var/log/xrdp-sesman.log /var/log/web.log 2>/dev/null & }

# ---- watchdog ringan -------------------------------------------------------
while :; do
    sleep 3
    if [ "$ENABLE_RDP" = "1" ] && { ! pgrep -x xrdp >/dev/null || ! pgrep -x xrdp-sesman >/dev/null; }; then
        pkill -x xrdp 2>/dev/null; pkill -x xrdp-sesman 2>/dev/null
        rm -f /var/run/xrdp/*.pid /run/xrdp/*.pid /var/run/xrdp-sesman.pid 2>/dev/null
        service xrdp start >/dev/null 2>&1 || /usr/sbin/xrdp >/dev/null 2>&1 || true
        echo "[watchdog] xrdp di-restart"
    fi
    if [ "$ENABLE_WEB" = "1" ] && ! pgrep -f "websockify.*${HTTP_PORT}" >/dev/null; then
        pkill -f "x11vnc -display :0" 2>/dev/null
        pkill -f "Xvfb :0" 2>/dev/null
        start_web
        echo "[watchdog] web/noVNC di-restart"
    fi
    pgrep -x pulseaudio >/dev/null || pulseaudio --system --daemonize=yes --disallow-exit \
        --exit-idle-time=-1 -n --file=/etc/pulse/default.pa >/dev/null 2>&1 || true
done
