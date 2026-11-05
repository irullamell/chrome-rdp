#!/bin/bash

# remove stale pid files (avoids xrdp failing to start after a restart)
rm -f /var/run/xrdp/*.pid /var/run/xrdp-sesman.pid /tmp/.X*-lock
mkdir -p /var/run/xrdp /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

service dbus start
pulseaudio --start --system --disallow-exit --disable-shm
service xrdp start

touch /var/log/xrdp-sesman.log
tail -f /var/log/xrdp-sesman.log
