#!/bin/bash
# ---------------------------------------------------------------------------
# Entrypoint web (noVNC) — TANPA PASSWORD.
#
#   https://<domain>/  -> langsung tersambung ke Chromium di tab
#
# VNC tidak memakai password (tanpa -rfbauth) dan tetap hanya listen di
# 127.0.0.1: satu-satunya jalan masuk adalah halaman noVNC.
#
# Opsional (kalau env ACCESS_TOKEN diisi):
#   - /?token=RAHASIA  -> cookie 30 hari, lalu redirect ke halaman bersih
#   - tanpa token      -> 401 (reminder singkat, bukan form login)
# Proxy autentikasi (AUTH_PROXY) tetap dihormati kalau diisi.
# ---------------------------------------------------------------------------
set -u

HTTP_PORT="${HTTP_PORT:-8080}"
SCREEN="${SCREEN:-1600x900x24}"
VNC_PORT="${VNC_PORT:-5900}"
PROFILE="${BROWSER_PROFILE:-/home/chromium/.config/chromium-web}"
VNC_SPEED="${VNC_SPEED:-lan}"       # lan | fast | medium | slow
VNC_POLL="${VNC_POLL:-40}"          # ms; makin besar makin hemat CPU
ACCESS_TOKEN="${ACCESS_TOKEN:-}"

mkdir -p "$PROFILE"
export DISPLAY=:0

# ---- Xvfb ------------------------------------------------------------------
echo "[web] Xvfb :0 (${SCREEN})"
Xvfb :0 -screen 0 "${SCREEN}" -nolisten tcp -ac -noreset -dpi 96 \
     +extension GLX +extension RANDR +render &
sleep 1

# ---- sesi browser ----------------------------------------------------------
echo "[web] sesi browser (openbox + chromium)"
BROWSER_PROFILE="$PROFILE" /usr/local/bin/browser-session >/dev/null 2>&1 &

# tunggu jendela Chromium muncul (maks 6s) -> tidak ada layar hitam
for _ in $(seq 1 60); do
    xdotool search --onlyvisible --class chromium >/dev/null 2>&1 && break
    sleep 0.1
done

# ---- x11vnc tanpa password -------------------------------------------------
echo "[web] x11vnc 127.0.0.1:${VNC_PORT} (tanpa password, speeds=${VNC_SPEED})"
x11vnc -display :0 -rfbport "$VNC_PORT" -localhost -forever -shared -repeat \
       -noxdamage -ncache 0 -norc -nopw \
       -wait "$VNC_POLL" -defer "$VNC_POLL" -sb 15 -speeds "$VNC_SPEED" \
       -quiet -bg -o /var/log/x11vnc.log

# ---- websockify + noVNC ----------------------------------------------------
WS_ARGS=(--web /usr/share/novnc --heartbeat 30)

# Kunci akses opsional (bukan password akun, hanya gerbang URL).
# Pakai plugin token websockify: ?token=... tervalidasi sebelum WebSocket dibuka.
# Catatan: pada mode token, websockify TIDAK boleh diberi target di argumen
# (target diambil dari hasil lookup token). Source port saja.
if [ -n "$ACCESS_TOKEN" ]; then
    TOKFILE=/tmp/ws-tokens
    printf '%s: 127.0.0.1:%s\n' "$ACCESS_TOKEN" "$VNC_PORT" > "$TOKFILE"
    chmod 600 "$TOKFILE"
    WS_ARGS+=(--token-plugin TokenFile --token-source "$TOKFILE")
    echo "[web] akses dibatasi token (buka /?token=...)"
    echo "[web] websockify + noVNC 0.0.0.0:${HTTP_PORT} (token mode)"
    exec websockify "${WS_ARGS[@]}" "0.0.0.0:${HTTP_PORT}"
fi

echo "[web] websockify + noVNC 0.0.0.0:${HTTP_PORT}"
exec websockify "${WS_ARGS[@]}" "0.0.0.0:${HTTP_PORT}" "127.0.0.1:${VNC_PORT}"
