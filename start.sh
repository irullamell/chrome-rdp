#!/bin/bash
# ---------------------------------------------------------------------------
# Entrypoint container — browser only, jalur start sependek mungkin.
#
#   RDP mode : xrdp  on RDP_PORT  (default 3389)   -> sesi Chromium
#   WEB mode : noVNC on HTTP_PORT (default 8080)   -> sesi Chromium
#
# Env: RDP_USER, RDP_PASSWORD, BROWSER_PASSWORD, RDP_PORT, HTTP_PORT,
#      ENABLE_RDP, ENABLE_WEB, DEBUG
# ---------------------------------------------------------------------------
set -u

RDP_PORT="${RDP_PORT:-3389}"
HTTP_PORT="${HTTP_PORT:-8080}"
ENABLE_RDP="${ENABLE_RDP:-1}"
ENABLE_WEB="${ENABLE_WEB:-1}"
DEBUG="${DEBUG:-0}"

# ---- kredensial ------------------------------------------------------------
RDP_USER_NAME="${RDP_USER:-root}"
RDP_USER_PASS="${RDP_PASSWORD:-root}"
if [ "$RDP_USER_NAME" != "root" ] && ! id "$RDP_USER_NAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$RDP_USER_NAME"
fi
echo "${RDP_USER_NAME}:${RDP_USER_PASS}" | chpasswd
HOME_DIR="$(getent passwd "$RDP_USER_NAME" | cut -d: -f6)"
[ -n "${HOME_DIR:-}" ] || HOME_DIR=/root
[ -f "${HOME_DIR}/.xsession" ] || { echo "browser-session" > "${HOME_DIR}/.xsession"; chmod 700 "${HOME_DIR}/.xsession"; }

# ---- port xrdp (hanya ditulis kalau beda) ----------------------------------
if [ -f /etc/xrdp/xrdp.ini ] && ! grep -qE "^port=${RDP_PORT}$" /etc/xrdp/xrdp.ini; then
    sed -i -E "0,/^[#;[:space:]]*port=.*/s//port=${RDP_PORT}/" /etc/xrdp/xrdp.ini
fi

# ---- bersihkan state lama (restart-safe) -----------------------------------
rm -f /var/run/xrdp/*.pid /run/xrdp/*.pid /var/run/xrdp-sesman.pid \
      /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null
mkdir -p /var/run/xrdp /run/xrdp /tmp/.X11-unix /run/pulse /run/user/0 /var/log
chmod 1777 /tmp/.X11-unix; chmod 700 /run/user/0 2>/dev/null || true
[ -s /var/lib/dbus/machine-id ] || dbus-uuidgen > /var/lib/dbus/machine-id

# ---- profil browser persisten kalau ada volume -----------------------------
if [ -d /data ]; then
    mkdir -p /data/chromium-profile /data/Downloads
    chown -R "${RDP_USER_NAME}:" /data 2>/dev/null || true
    mkdir -p "${HOME_DIR}/.config"
    [ -L "${HOME_DIR}/.config/chromium" ] || { rm -rf "${HOME_DIR}/.config/chromium"; ln -sfn /data/chromium-profile "${HOME_DIR}/.config/chromium"; }
    [ -L "${HOME_DIR}/Downloads" ] || { rm -rf "${HOME_DIR}/Downloads"; ln -sfn /data/Downloads "${HOME_DIR}/Downloads"; }
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

# ---- web (noVNC) -----------------------------------------------------------
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

# banner ringkas (satu echo, bukan lima)
VER="$(/usr/local/bin/chromium-rdp --version 2>/dev/null || echo chromium)"
echo "=============================================================="
echo " Chromium Browser · user=${RDP_USER_NAME} · rdp=$([ "$ENABLE_RDP" = 1 ] && echo "$RDP_PORT" || echo off) · web=$([ "$ENABLE_WEB" = 1 ] && echo "$HTTP_PORT" || echo off)"
echo " ${VER}"
echo "=============================================================="

[ "$DEBUG" = "1" ] && { touch /var/log/web.log; tail -n +1 -F /var/log/xrdp.log /var/log/xrdp-sesman.log /var/log/web.log 2>/dev/null & }

# ---- watchdog ringan (3s, tanpa fork berlebihan) ---------------------------
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
