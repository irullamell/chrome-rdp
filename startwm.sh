#!/bin/sh
# ---------------------------------------------------------------------------
# xrdp session hook: start the browser session instead of a full desktop.
# ---------------------------------------------------------------------------
export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_SESSION_TYPE=x11
export BROWSER=/usr/bin/chromium

# Opt-in proxy autentikasi (opsional, untuk deploy publik).
# Diisi oleh start.sh dari AUTH_PROXY, contoh "user:pass@host:port".
if [ -s /etc/xrdp/authproxy.conf ]; then
    . /etc/xrdp/authproxy.conf
    export http_proxy="http://${AUTH_PROXY}" https_proxy="http://${AUTH_PROXY}"
    export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"
fi

exec /usr/local/bin/browser-session
