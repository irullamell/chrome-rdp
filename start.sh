#!/bin/bash
# ---------------------------------------------------------------------------
# Container entrypoint for Railway Fast RDP
#   - cleans stale X/pid state after a restart
#   - password / resolution are configurable through env
#   - starts dbus, system PulseAudio, xrdp (+ watchdog)
# ---------------------------------------------------------------------------
set -u

PORT="${RDP_PORT:-3389}"
GEOMETRY="${RDP_GEOMETRY:-1600x900}"

echo "=============================================================="
echo " Railway Fast RDP  ·  Debian 12 + XFCE4 + Chromium"
echo " RDP port   : $PORT"
echo " Credentials: ${RDP_USER:-root} / (set via RDP_PASSWORD, default: root)"
echo "=============================================================="

# ---- credentials (change these in Railway -> Variables!) -------------------
RDP_USER_NAME="${RDP_USER:-root}"
RDP_USER_PASS="${RDP_PASSWORD:-root}"
if [ "$RDP_USER_NAME" != "root" ] && ! id "$RDP_USER_NAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo "$RDP_USER_NAME"
fi
echo "${RDP_USER_NAME}:${RDP_USER_PASS}" | chpasswd
HOME_DIR="$(getent passwd "$RDP_USER_NAME" | cut -d: -f6)"
[ -n "${HOME_DIR:-}" ] || HOME_DIR=/root
if [ ! -f "${HOME_DIR}/.xsession" ]; then
    echo "startxfce4" > "${HOME_DIR}/.xsession"
    chown "${RDP_USER_NAME}:" "${HOME_DIR}/.xsession" 2>/dev/null || true
    chmod 700 "${HOME_DIR}/.xsession"
fi

# ---- xrdp port ------------------------------------------------------------
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i -E "0,/^[#;[:space:]]*port=.*/s//port=${PORT}/" /etc/xrdp/xrdp.ini
fi

# ---- stale state from a previous (crashed) run ----------------------------
rm -f /var/run/xrdp/*.pid /var/run/xrdp-sesman.pid /run/xrdp/*.pid \
      /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null
mkdir -p /var/run/xrdp /run/xrdp /tmp/.X11-unix /run/pulse /run/user/0 /var/log
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/0 2>/dev/null || true
[ -s /var/lib/dbus/machine-id ] || dbus-uuidgen > /var/lib/dbus/machine-id

# ---- persist the browser profile across restarts (Railway volume) --------
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
echo "export RDP_GEOMETRY=${GEOMETRY}" > /etc/profile.d/rdp-geometry.sh

# ---- kernel tuning (ignored when the host blocks sysctl) -----------------
sysctl -w net.ipv4.tcp_keepalive_time=30 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_keepalive_intvl=10 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_keepalive_probes=6 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true
sysctl -w net.core.rmem_max=26214400 >/dev/null 2>&1 || true
sysctl -w net.core.wmem_max=26214400 >/dev/null 2>&1 || true

# ---- services -------------------------------------------------------------
if ! pgrep -x dbus-daemon >/dev/null; then
    dbus-daemon --system --fork 2>/dev/null || service dbus start 2>/dev/null || true
fi

if ! pgrep -x pulseaudio >/dev/null; then
    pulseaudio --system --daemonize=yes --disallow-exit --disallow-module-loading=no \
               --exit-idle-time=-1 -n --file=/etc/pulse/default.pa >/dev/null 2>&1 || \
    (mkdir -p /run/pulse && chmod 777 /run/pulse)
fi

if ! service xrdp start >/dev/null 2>&1; then
    /usr/sbin/xrdp >/dev/null 2>&1 || true
fi
sleep 2

touch /var/log/xrdp.log /var/log/xrdp-sesman.log
tail -n +1 -F /var/log/xrdp.log /var/log/xrdp-sesman.log 2>/dev/null &

echo "[ok] xrdp listening on ${PORT}"
echo "[ok] browser   = $(/usr/bin/chromium --version 2>/dev/null || echo 'chromium (check /usr/lib/chromium/chromium)')"
if [ -S /run/pulse/native ]; then echo "[ok] audio     = /run/pulse/native"; else echo "[warn] audio socket missing (PulseAudio belum siap)"; fi

# ---- watchdog -------------------------------------------------------------
while true; do
    sleep 5

    if ! pgrep -x xrdp-sesman >/dev/null || ! pgrep -x xrdp >/dev/null; then
        echo "[watchdog] restarting xrdp"
        pkill -x xrdp 2>/dev/null; pkill -x xrdp-sesman 2>/dev/null
        sleep 1
        rm -f /var/run/xrdp/*.pid /run/xrdp/*.pid /var/run/xrdp-sesman.pid 2>/dev/null
        if ! service xrdp start >/dev/null 2>&1; then
            /usr/sbin/xrdp >/dev/null 2>&1 || true
        fi
    fi

    if ! pgrep -x pulseaudio >/dev/null; then
        echo "[watchdog] restarting pulseaudio"
        pulseaudio --system --daemonize=yes --disallow-exit --exit-idle-time=-1 \
                   -n --file=/etc/pulse/default.pa >/dev/null 2>&1 || true
    fi

    if ! pgrep -x dbus-daemon >/dev/null; then
        dbus-daemon --system --fork >/dev/null 2>&1 || true
    fi

    # Chromium left behind by a closed RDP session must not eat the CPU
    if pgrep -u root -f -- "chromium.*--type=renderer" >/dev/null 2>&1; then
        if ! pgrep -x xrdp-sesman >/dev/null && ! pgrep -f "xorgxrdp|Xorg" >/dev/null; then
            pkill -u root -f "/usr/lib/chromium/chromium" 2>/dev/null || true
        fi
    fi
done
