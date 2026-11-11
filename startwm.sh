#!/bin/sh
# ---------------------------------------------------------------------------
# Session startup for xrdp: environment that Chromium, Wine and PulseAudio
# need in a container. Keeps the session alive across disconnects.
# ---------------------------------------------------------------------------

export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}
export XDG_RUNTIME_DIR=/run/user/$(id -u)
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce
export BROWSER=/usr/bin/chromium
export LIBGL_ALWAYS_SOFTWARE=1
export MOZ_ENABLE_WAYLAND=0

# System-wide PulseAudio (container has no per-user session bus for it)
if [ -S /run/pulse/native ]; then
    export PULSE_SERVER=unix:/run/pulse/native
    export PULSE_COOKIE=/run/pulse/cookie
fi

# Fontconfig cache helps first Chromium paint over RDP
fc-cache -f >/dev/null 2>&1 || true

if [ -r /etc/X11/Xresources ]; then
    xrdb -merge /etc/X11/Xresources 2>/dev/null || true
fi

# Start a session bus if dbus-daemon is available (needed by xfce4 + Chromium)
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS
fi

if command -v startxfce4 >/dev/null 2>&1; then
    exec startxfce4
elif command -v xfce4-session >/dev/null 2>&1; then
    exec xfce4-session
else
    exec xterm
fi
