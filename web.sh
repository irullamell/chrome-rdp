#!/bin/bash
# ---------------------------------------------------------------------------
# Entrypoint web (noVNC): Chromium bisa dibuka dari browser apa pun.
#
#   https://<domain>/  -> login -> vnc.html (autoconnect)
#
# Optimasi:
#   - Xvfb tanpa TCP, tanpa extension yang tidak dipakai browser
#   - x11vnc: wait/defer + sb supaya CPU turun saat layar diam (bandwidth turun)
#   - websockify: heartbeat + tanpa pyc
#   - VNC hanya 127.0.0.1 (satu-satunya jalan masuk = halaman noVNC berpassword)
# ---------------------------------------------------------------------------
set -u

HTTP_PORT="${HTTP_PORT:-8080}"
SCREEN="${SCREEN:-1600x900x24}"
VNC_PORT="${VNC_PORT:-5900}"
WEB_PASS="${BROWSER_PASSWORD:-${RDP_PASSWORD:-root}}"
PROFILE="${BROWSER_PROFILE:-/root/.config/chromium-web}"
VNC_SPEED="${VNC_SPEED:-lan}"       # lan | fast | medium | slow (preset x11vnc)
VNC_POLL="${VNC_POLL:-40}"          # ms; makin besar makin hemat CPU.

mkdir -p "$PROFILE"

# password x11vnc (0600, di /tmp supaya tidak ikut ke image layer)
umask 077
x11vnc -storepasswd "$WEB_PASS" /tmp/vnc.pass >/dev/null 2>&1

echo "[web] Xvfb :0 (${SCREEN})"
Xvfb :0 -screen 0 "${SCREEN}" -nolisten tcp -ac -noreset -dpi 96 \
     +extension GLX +extension RANDR +render &
sleep 1

export DISPLAY=:0

echo "[web] sesi browser (openbox + chromium)"
BROWSER_PROFILE="$PROFILE" /usr/local/bin/browser-session >/dev/null 2>&1 &

# tunggu jendela Chromium muncul (maks 6s) baru nyalakan VNC -> tidak ada layar hitam
for _ in $(seq 1 60); do
    xdotool search --onlyvisible --class chromium >/dev/null 2>&1 && break
    sleep 0.1
done

echo "[web] x11vnc 127.0.0.1:${VNC_PORT} (speeds=${VNC_SPEED})"
x11vnc -display :0 -rfbport "$VNC_PORT" -localhost -forever -shared -repeat \
       -noxdamage -ncache 0 -norc -rfbauth /tmp/vnc.pass \
       -wait "$VNC_POLL" -defer "$VNC_POLL" -sb 15 -speeds "$VNC_SPEED" \
       -quiet -bg -o /var/log/x11vnc.log

echo "[web] websockify + noVNC 0.0.0.0:${HTTP_PORT}"
exec websockify --web /usr/share/novnc --heartbeat 30 \
     "0.0.0.0:${HTTP_PORT}" "127.0.0.1:${VNC_PORT}"
