#!/bin/sh
# ---------------------------------------------------------------------------
# xrdp session hook: start the browser session instead of a full desktop.
# ---------------------------------------------------------------------------
export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_SESSION_TYPE=x11
export BROWSER=/usr/bin/chromium

exec /usr/local/bin/browser-session
