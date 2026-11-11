FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="Railway Fast RDP" \
      org.opencontainers.image.description="Debian 12 + XFCE4 + Chromium (full support) remote desktop over RDP" \
      org.opencontainers.image.source="https://github.com/shadowhexreal/Railway-Fast-Rdp" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    XDG_RUNTIME_DIR=/run/user/0 \
    BROWSER=/usr/bin/chromium \
    PULSE_SERVER=unix:/run/pulse/native

# i386 is only needed for wine32 (Windows .exe). Set ENABLE_WINE=0 to skip it.
ARG ENABLE_WINE=1
RUN if [ "$ENABLE_WINE" = "1" ]; then dpkg --add-architecture i386; fi

# OCI image config so Railway (and "docker inspect") knows the port + entrypoint.
ENV RDP_PORT=3389

# Debian 12 (bookworm, LTS) => Chromium straight from Debian security,
# no Google Chrome .deb, no archive.debian.org workaround.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    openssl \
    curl \
    wget \
    nano \
    less \
    procps \
    sudo \
    net-tools \
    ssl-cert \
    xrdp \
    xorgxrdp \
    xorg \
    xauth \
    x11-xserver-utils \
    x11-utils \
    xdg-utils \
    dbus \
    dbus-x11 \
    xfce4 \
    xfce4-terminal \
    mesa-utils \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libegl1 \
    libgles2 \
    libgbm1 \
    libpulse0 \
    pulseaudio \
    pulseaudio-utils \
    policykit-1 \
    polkitd \
    upower \
    chromium \
    chromium-common \
    chromium-sandbox \
    libnss3-tools \
    libu2f-udev \
    fonts-liberation \
    fonts-dejavu-core \
    fonts-freefont-ttf \
    fonts-noto-core \
    fonts-noto-color-emoji \
    fonts-noto-cjk \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# ---- Wine (optional, for Windows .exe) ------------------------------------
RUN if [ "$ENABLE_WINE" = "1" ]; then \
      apt-get update && \
      apt-get install -y --no-install-recommends wine wine32 && \
      apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/* ; \
    fi

# ---------------------------------------------------------------------------
# Chromium launcher
# The Debian package puts the real binary in /usr/lib/chromium/chromium and a
# thin wrapper in /usr/bin/chromium. We keep the official wrapper as
# /usr/bin/chromium.dist and put our container-aware launcher in front, so
# desktop icon, terminal, xdg-open and "chromium" all behave the same.
# ---------------------------------------------------------------------------
COPY chromium.sh /usr/local/bin/chromium-rdp
RUN chmod +x /usr/local/bin/chromium-rdp \
    && if [ -f /usr/bin/chromium ] && [ ! -e /usr/bin/chromium.dist ]; then cp -a /usr/bin/chromium /usr/bin/chromium.dist; fi \
    && ln -sf /usr/local/bin/chromium-rdp /usr/bin/chromium \
    && update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/chromium-rdp 200 \
    && update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/local/bin/chromium-rdp 200 \
    && sed -i 's|^Exec=.*|Exec=/usr/bin/chromium %U|' /usr/share/applications/chromium.desktop \
    && mkdir -p /etc/chromium/policies/managed /tmp/chromium-cache

# Managed Chromium policies: sane defaults for a remote desktop (no telemetry,
# no "make default browser" nag, downloads/printing/autofill enabled).
RUN printf '%s\n' \
    '{' \
    '  "DefaultBrowserSettingEnabled": false,' \
    '  "MetricsReportingEnabled": false,' \
    '  "BackgroundModeEnabled": false,' \
    '  "ShowHomeButton": true,' \
    '  "HomepageLocation": "https://www.google.com",' \
    '  "BookmarkBarEnabled": false,' \
    '  "PasswordManagerEnabled": true,' \
    '  "AutofillAddressEnabled": true,' \
    '  "AutofillCreditCardEnabled": true,' \
    '  "DownloadRestrictions": 0,' \
    '  "PrintingEnabled": true,' \
    '  "HardwareAccelerationModeEnabled": true' \
    '}' \
    > /etc/chromium/policies/managed/rdp-defaults.json

# ---------------------------------------------------------------------------
# xrdp: TLS + speed tuning
# ---------------------------------------------------------------------------
COPY tune-ini.sh /tmp/tune-ini.sh
RUN chmod +x /tmp/tune-ini.sh && /tmp/tune-ini.sh && rm -f /tmp/tune-ini.sh

# Self-signed TLS certificate for the RDP listener (valid 10 years, unique per
# build). Clients show "unknown publisher" once; accept and it works over TLS.
RUN set -eux; \
    xrdp-keygen xrdp /etc/xrdp/rsakeys.ini >/dev/null 2>&1 || true; \
    if [ ! -s /etc/xrdp/cert.pem ] || [ ! -s /etc/xrdp/key.pem ]; then \
      umask 077; \
      openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 3650 \
        -subj "/C=ID/O=Railway-Fast-RDP/CN=railway-fast-rdp" \
        -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem; \
    fi; \
    chmod 600 /etc/xrdp/key.pem; chmod 644 /etc/xrdp/cert.pem

# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------
COPY startwm.sh /etc/xrdp/startwm.sh
RUN chmod 755 /etc/xrdp/startwm.sh && \
    echo "startxfce4" > /root/.xsession && chmod 700 /root/.xsession

# Audio: system-wide PulseAudio on /run/pulse/native (RDP audio + Chromium)
COPY pulse-client.conf /etc/pulse/client.conf
COPY pulse-default.pa /etc/pulse/default.pa
RUN adduser xrdp ssl-cert 2>/dev/null || true; \
    for g in pulse-access pulse; do getent group "$g" >/dev/null || addgroup --system "$g"; done; \
    adduser xrdp pulse-access 2>/dev/null || true; \
    adduser xrdp pulse 2>/dev/null || true; \
    adduser root pulse-access 2>/dev/null || true; \
    printf 'root\trw\nxrdp\trw\n' > /etc/pulse/access.conf; \
    mkdir -p /run/pulse /var/run/pulse && chmod 755 /run/pulse /var/run/pulse

# XFCE defaults: compositor off (CPU saver over RDP), 96 dpi, emoji-capable fonts
RUN mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml && \
    printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<channel name="xfwm4" version="1.0">' \
    '  <property name="general" type="empty">' \
    '    <property name="use_compositing" type="bool" value="false"/>' \
    '    <property name="box_move" type="bool" value="true"/>' \
    '    <property name="box_resize" type="bool" value="true"/>' \
    '  </property>' \
    '</channel>' \
    > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml && \
    printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<channel name="xsettings" version="1.0">' \
    '  <property name="Net" type="empty">' \
    '    <property name="ThemeName" type="string" value="Adwaita"/>' \
    '    <property name="IconThemeName" type="string" value="Adwaita"/>' \
    '  </property>' \
    '  <property name="Xft" type="empty">' \
    '    <property name="DPI" type="int" value="96"/>' \
    '    <property name="Antialias" type="int" value="1"/>' \
    '    <property name="HintStyle" type="string" value="hintslight"/>' \
    '    <property name="RGBA" type="string" value="none"/>' \
    '  </property>' \
    '  <property name="Keyboard" type="empty">' \
    '    <property name="RepeatDelay" type="int" value="400"/>' \
    '    <property name="RepeatInterval" type="int" value="30"/>' \
    '  </property>' \
    '</channel>' \
    > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml && \
    mkdir -p /root/Desktop && \
    cp /usr/share/applications/chromium.desktop /root/Desktop/chromium.desktop && \
    chmod +x /root/Desktop/chromium.desktop && \
    sed -i 's|^Name=.*|Name=Chromium Browser|' /root/Desktop/chromium.desktop

# dbus machine-id + runtime dirs
RUN mkdir -p /var/run/dbus /run/xrdp /run/user/0 && dbus-uuidgen > /var/lib/dbus/machine-id

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=5s --start-period=25s --retries=3 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/3389' || exit 1

CMD ["/start.sh"]
