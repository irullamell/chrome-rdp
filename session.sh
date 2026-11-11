#!/bin/bash
# ---------------------------------------------------------------------------
# The only thing that runs inside the X session: window manager + Chromium.
# No panel, no file manager, no terminal — this container is a browser.
# ---------------------------------------------------------------------------
export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null
[ -d "$XDG_RUNTIME_DIR" ] || XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR
export XDG_SESSION_TYPE=x11
export BROWSER=/usr/bin/chromium
export LIBGL_ALWAYS_SOFTWARE=1
export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"

# separate profile per entrypoint (web session vs RDP session)
if [ -n "${BROWSER_PROFILE:-}" ]; then
    mkdir -p "$BROWSER_PROFILE"
    export CHROMIUM_FLAGS="${CHROMIUM_FLAGS:-} --user-data-dir=${BROWSER_PROFILE}"
fi

[ -S /run/pulse/native ] || unset PULSE_SERVER

# dbus session (Chromium wants it for notifications / MPRIS / clipboard)
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS
fi

# Desktop "look": dark background, no icons (openbox + xsetroot)
xsetroot -solid "#1e1e2e" 2>/dev/null || true

# Window manager keeps the window fullscreen-ish and gives us focus/maximize
openbox --config-file /root/.config/openbox/rc.xml >/dev/null 2>&1 &
sleep 0.6

# One Chromium window. If it is closed, the session stays alive and reopens it
# (an RDP user should never land on an empty grey screen).
while true; do
    /usr/bin/chromium >/dev/null 2>&1
    # only restart if the X session still exists
    if ! xset q >/dev/null 2>&1; then exit 0; fi
    sleep 1
done
