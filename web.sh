#!/bin/bash
# ---------------------------------------------------------------------------
# Web entrypoint: Chromium in the browser (no RDP client needed).
#
#   browser  ->  https://<railway-domain>/vnc.html   (noVNC)
#
# Chain: Xvfb :0 -> Chromium + openbox -> x11vnc (localhost) -> websockify
#        -> noVNC static files.  VNC is bound to 127.0.0.1 only; the only way
#        in is the noVNC page, which asks for BROWSER_PASSWORD.
# ---------------------------------------------------------------------------
set -u

HTTP_PORT="${HTTP_PORT:-8080}"
SCREEN="${SCREEN:-1600x900x24}"
VNC_PORT="${VNC_PORT:-5900}"
WEB_PASS="${BROWSER_PASSWORD:-${RDP_PASSWORD:-root}}"
PROFILE="${BROWSER_PROFILE:-/root/.config/chromium-web}"

mkdir -p "$PROFILE"

# Password file for x11vnc (0600, inside /tmp so it never lands in a layer)
umask 077
x11vnc -storepasswd "$WEB_PASS" /tmp/vnc.pass >/dev/null 2>&1

echo "[web] starting Xvfb :0 (${SCREEN})"
Xvfb :0 -screen 0 "${SCREEN}" -nolisten tcp -ac +extension GLX +render -noreset &
sleep 1.5

echo "[web] starting browser session (openbox + chromium)"
export DISPLAY=:0

# Independent profile so a web session and an RDP session can coexist.
BROWSER_PROFILE="$PROFILE" /usr/local/bin/browser-session >/dev/null 2>&1 &

sleep 1

echo "[web] starting x11vnc on 127.0.0.1:${VNC_PORT}"
x11vnc -display :0 -rfbport "$VNC_PORT" -localhost -forever -shared -repeat \
       -noxdamage -ncache 0 -rfbauth /tmp/vnc.pass -quiet -bg -o /var/log/x11vnc.log

echo "[web] starting websockify + noVNC on 0.0.0.0:${HTTP_PORT}"
exec websockify --web /usr/share/novnc "0.0.0.0:${HTTP_PORT}" "127.0.0.1:${VNC_PORT}"
