#!/bin/bash
# ---------------------------------------------------------------------------
# Container entrypoint — browser only.
#
#   RDP mode : xrdp on RDP_PORT (default 3389)  -> Chromium session
#   WEB mode : noVNC on HTTP_PORT (default 8080) -> Chromium session
#
# Toggle with ENABLE_RDP / ENABLE_WEB. Both run at once by default.
# ---------------------------------------------------------------------------
set -u

RDP_PORT="${RDP_PORT:-3389}"
HTTP_PORT="${HTTP_PORT:-8080}"
ENABLE_RDP="${ENABLE_RDP:-1}"
ENABLE_WEB="${ENABLE_WEB:-1}"

echo "=============================================================="
echo " Railway Chromium Browser  ·  Debian 12 + Chromium only"
echo " User     : ${RDP_USER:-root}"
echo " Password : ${RDP_PASSWORD:+set}${RDP_PASSWORD:-root}"
echo " RDP      : $([ "$ENABLE_RDP" = "1" ] && echo "port ${RDP_PORT}" || echo "off")"
echo " Web      : $([ "$ENABLE_WEB" = "1" ] && echo "port ${HTTP_PORT} (noVNC)" || echo "off")"
echo "=============================================================="

# ---- credentials -----------------------------------------------------------
RDP_USER_NAME="${RDP_USER:-root}"
RDP_USER_PASS="${RDP_PASSWORD:-root}"
if [ "$RDP_USER_NAME" != "root" ] && ! id "$RDP_USER_NAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$RDP_USER_NAME"
fi
echo "${RDP_USER_NAME}:${RDP_USER_PASS}" | chpasswd

HOME_DIR="$(getent passwd "$RDP_USER_NAME" | cut -d: -f6)"
[ -n "${HOME_DIR:-}" ] || HOME_DIR=/root
if [ ! -f "${HOME_DIR}/.xsession" ]; then
    echo "browser-session" > "${HOME_DIR}/.xsession"
    chown "${RDP_USER_NAME}:" "${HOME_DIR}/.xsession" 2>/dev/null || true
    chmod 700 "${HOME_DIR}/.xsession"
fi

# ---- xrdp port -------------------------------------------------------------
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i -E "0,/^[#;[:space:]]*port=.*/s//port=${RDP_PORT}/" /etc/xrdp/xrdp.ini
fi

# ---- stale state -----------------------------------------------------------
rm -f /var/run/xrdp/*.pid /run/xrdp/*.pid /var/run/xrdp-sesman.pid \
      /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null
mkdir -p /var/run/xrdp /run/xrdp /tmp/.X11-unix /run/pulse /run/user/0 /var/log
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/0 2>/dev/null || true
[ -s /var/lib/dbus/machine-id ] || dbus-uuidgen > /var/lib/dbus/machine-id

# ---- persist the browser profile when a volume is mounted ------------------
if [ -d /data ]; then
    mkdir -p /data/chromium-profile /data/Downloads
    chown -R "${RDP_USER_NAME}:" /data 2>/dev/null || true
    mkdir -p "${HOME_DIR}/.config"
    if [ ! -L "${HOME_DIR}/.config/chromium" ]; then
        rm -rf "${HOME_DIR}/.config/chromium" 2>/dev/null || true
        ln -sfn /data/chromium-profile "${HOME_DIR}/.config/chromium"
    fi
    if [ ! -L "${HOME_DIR}/Downloads" ]; then
        rm -rf "${HOME_DIR}/Downloads" 2>/dev/null || true
        ln -sfn /data/Downloads "${HOME_DIR}/Downloads"
    fi
fi

# ---- kernel tuning (ignored when the host blocks sysctl) -------------------
for kv in net.ipv4.tcp_keepalive_time=30 net.ipv4.tcp_keepalive_intvl=10 \
          net.ipv4.tcp_keepalive_probes=6 net.ipv4.tcp_slow_start_after_idle=0; do
    sysctl -w "$kv" >/dev/null 2>&1 || true
done

# ---- dbus + audio ----------------------------------------------------------
pgrep -x dbus-daemon >/dev/null || dbus-daemon --system --fork 2>/dev/null || true

if ! pgrep -x pulseaudio >/dev/null; then
    pulseaudio --system --daemonize=yes --disallow-exit --exit-idle-time=-1 \
               -n --file=/etc/pulse/default.pa >/dev/null 2>&1 || mkdir -p /run/pulse
fi

# ---- web entrypoint (noVNC) ------------------------------------------------
if [ "$ENABLE_WEB" = "1" ]; then
    if ! pgrep -f "websockify.*${HTTP_PORT}" >/dev/null; then
        nohup /usr/local/bin/web-entry >/var/log/web.log 2>&1 &
        echo "[web] noVNC di http://0.0.0.0:${HTTP_PORT} (log: /var/log/web.log)"
    fi
fi

# ---- RDP entrypoint --------------------------------------------------------
if [ "$ENABLE_RDP" = "1" ]; then
    if ! service xrdp start >/dev/null 2>&1; then
        /usr/sbin/xrdp >/dev/null 2>&1 || true
    fi
    touch /var/log/xrdp.log /var/log/xrdp-sesman.log
fi

sleep 2
echo "[ok] browser = $(/usr/bin/chromium --version 2>/dev/null || echo 'chromium')"
[ -S /run/pulse/native ] && echo "[ok] audio   = /run/pulse/native" || echo "[warn] audio socket belum siap"

tail -n +1 -F /var/log/xrdp.log /var/log/xrdp-sesman.log /var/log/web.log 2>/dev/null &

# ---- watchdog --------------------------------------------------------------
while true; do
    sleep 5

    if [ "$ENABLE_RDP" = "1" ]; then
        if ! pgrep -x xrdp-sesman >/dev/null || ! pgrep -x xrdp >/dev/null; then
            echo "[watchdog] restart xrdp"
            pkill -x xrdp 2>/dev/null; pkill -x xrdp-sesman 2>/dev/null
            sleep 1
            rm -f /var/run/xrdp/*.pid /run/xrdp/*.pid /var/run/xrdp-sesman.pid 2>/dev/null
            service xrdp start >/dev/null 2>&1 || /usr/sbin/xrdp >/dev/null 2>&1 || true
        fi
    fi

    if [ "$ENABLE_WEB" = "1" ]; then
        if ! pgrep -f "websockify.*${HTTP_PORT}" >/dev/null; then
            echo "[watchdog] restart web entrypoint"
            pkill -f "x11vnc -display :0" 2>/dev/null
            pkill -f "Xvfb :0" 2>/dev/null
            sleep 1
            nohup /usr/local/bin/web-entry >>/var/log/web.log 2>&1 &
        fi
    fi

    pgrep -x pulseaudio >/dev/null || \
        pulseaudio --system --daemonize=yes --disallow-exit --exit-idle-time=-1 \
                   -n --file=/etc/pulse/default.pa >/dev/null 2>&1 || true
    pgrep -x dbus-daemon >/dev/null || dbus-daemon --system --fork >/dev/null 2>&1 || true
done
