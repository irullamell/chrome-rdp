FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

# Debian 11 (bullseye) is end-of-life: its packages moved to archive.debian.org.
# Without this, apt gives "404 Not Found" on debian-security.
RUN printf '%s\n' \
    'deb http://archive.debian.org/debian bullseye main' \
    'deb http://archive.debian.org/debian-security bullseye-security main' \
    > /etc/apt/sources.list && \
    rm -f /etc/apt/sources.list.d/* && \
    printf '%s\n' \
    'Acquire::Check-Valid-Until "false";' \
    'Acquire::Retries "5";' \
    > /etc/apt/apt.conf.d/99archive

# --no-install-recommends + xfce4-goodies removed => much smaller image, faster build, faster desktop
# Firefox removed, Google Chrome installed from official .deb
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    xrdp \
    xorgxrdp \
    xfce4 \
    xfce4-terminal \
    xorg \
    xauth \
    x11-xserver-utils \
    libgl1-mesa-dri \
    dbus-x11 \
    procps \
    sudo \
    curl \
    wget \
    nano \
    net-tools \
    policykit-1 \
    pulseaudio \
    pulseaudio-utils \
    fonts-liberation \
    wine \
    wine32 && \
    wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get install -y --no-install-recommends /tmp/chrome.deb && \
    rm -f /tmp/chrome.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Chrome as root inside a container: needs --no-sandbox, small /dev/shm fix, no GPU
RUN mv /opt/google/chrome/google-chrome /opt/google/chrome/google-chrome-real && \
    printf '%s\n' '#!/bin/bash' \
    'exec /opt/google/chrome/google-chrome-real --no-sandbox --test-type --disable-dev-shm-usage --disable-gpu --no-first-run --no-default-browser-check --password-store=basic "$@"' \
    > /opt/google/chrome/google-chrome && \
    chmod +x /opt/google/chrome/google-chrome && \
    (update-alternatives --set x-www-browser /usr/bin/google-chrome-stable || true) && \
    (update-alternatives --set gnome-www-browser /usr/bin/google-chrome-stable || true)

# Set root password
RUN echo "root:root" | chpasswd

RUN sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config || echo "allowed_users=anybody" >> /etc/X11/Xwrapper.config

RUN echo "startxfce4" > /root/.xsession && chmod 700 /root/.xsession

# Generate machine-id for dbus
RUN mkdir -p /var/run/dbus && dbus-uuidgen > /var/lib/dbus/machine-id

RUN sed -i 's/crypt_level=high/crypt_level=low/' /etc/xrdp/xrdp.ini && \
    sed -i 's/security_layer=negotiate/security_layer=rdp/' /etc/xrdp/xrdp.ini && \
    echo "exec startxfce4" > /etc/xrdp/startwm.sh && chmod +x /etc/xrdp/startwm.sh

# Fast RDP: compression, fastpath, nodelay, big buffers, 16-bit colour
RUN for kv in "max_bpp=16" "use_fastpath=both" "bitmap_cache=true" "bitmap_compression=true" "bulk_compression=true" "tcp_nodelay=true" "tcp_keepalive=true" "tcp_send_buffer_bytes=4194304" "tcp_recv_buffer_bytes=6291456"; do \
      k="${kv%%=*}"; \
      if grep -qE "^[#; ]*${k}=" /etc/xrdp/xrdp.ini; then \
        sed -i -E "0,/^[#; ]*${k}=.*/s//${kv}/" /etc/xrdp/xrdp.ini; \
      else \
        sed -i "0,/^\[Globals\]/s//[Globals]\n${kv}/" /etc/xrdp/xrdp.ini; \
      fi; \
    done

# Fast desktop: turn off XFCE window compositor (big CPU saver over RDP)
RUN mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml && \
    printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<channel name="xfwm4" version="1.0">' \
    '  <property name="general" type="empty">' \
    '    <property name="use_compositing" type="bool" value="false"/>' \
    '  </property>' \
    '</channel>' \
    > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

RUN adduser xrdp ssl-cert

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389

CMD ["/start.sh"]
