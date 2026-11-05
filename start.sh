#!/bin/bash

# remove stale pid files (avoids xrdp failing to start after a restart)
rm -f /var/run/xrdp/*.pid /var/run/xrdp-sesman.pid /tmp/.X*-lock
mkdir -p /var/run/xrdp /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# keep the connection alive / no slowdown after idle (ignored if the host blocks sysctl)
sysctl -w net.ipv4.tcp_keepalive_time=30 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_keepalive_intvl=10 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_keepalive_probes=6 >/dev/null 2>&1 || true
sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true

service dbus start
pulseaudio --start --system --disallow-exit --disable-shm
service xrdp start

touch /var/log/xrdp-sesman.log
tail -F /var/log/xrdp-sesman.log &

# watchdog: if xrdp / sesman / pulseaudio ever die, bring them back automatically
while true; do
    sleep 5
    if ! pgrep -x xrdp-sesman >/dev/null || ! pgrep -x xrdp >/dev/null; then
        pkill -x xrdp 2>/dev/null
        pkill -x xrdp-sesman 2>/dev/null
        sleep 1
        rm -f /var/run/xrdp/*.pid /var/run/xrdp-sesman.pid
        service xrdp start
    fi
    if ! pgrep -x pulseaudio >/dev/null; then
        pulseaudio --start --system --disallow-exit --disable-shm
    fi
done
