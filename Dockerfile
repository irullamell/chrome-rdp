FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="Railway Chromium Browser" \
      org.opencontainers.image.description="Chromium-only remote browser: fullscreen Chromium over RDP, plus noVNC web login" \
      org.opencontainers.image.source="https://github.com/shadowhexreal/Railway-Fast-Rdp" \
      org.opencontainers.image.licenses="MIT"

# Two display modes out of one container:
#   RDP   -> RDP client connects to RDP_PORT      (3389, plain RDP + TLS)
#   WEB   -> browse to https://<domain>           (noVNC over HTTP_PORT, default 8080)
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    XDG_RUNTIME_DIR=/run/user/0 \
    BROWSER=/usr/bin/chromium \
    PULSE_SERVER=unix:/run/pulse/native \
    DISPLAY=:0 \
    RDP_PORT=3389 \
    HTTP_PORT=8080 \
    SCREEN=1600x900x24

# ---------------------------------------------------------------------------
# Only what a browser session needs. No Wine, no XFCE, no office apps.
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssl \
    curl \
    procps \
    ssl-cert \
    # --- display server + window manager (no full desktop) ---
    xvfb \
    x11-utils \
    x11-xserver-utils \
    xauth \
    openbox \
    xdotool \
    dbus \
    dbus-x11 \
    # --- the browser ---
    chromium \
    chromium-common \
    chromium-sandbox \
    webext-ublock-origin-chromium \
    # --- software GL so WebGL works without a GPU ---
    libgl1-mesa-dri \
    libglx-mesa0 \
    libegl1 \
    libgles2 \
    libgbm1 \
    # --- fonts so every site renders correctly ---
    fonts-liberation \
    fonts-dejavu-core \
    fonts-freefont-ttf \
    fonts-noto-core \
    fonts-noto-color-emoji \
    fonts-noto-cjk \
    # --- audio ---
    pulseaudio \
    pulseaudio-utils \
    # --- remote access: RDP + web (noVNC) ---
    xrdp \
    xorgxrdp \
    x11vnc \
    novnc \
    websockify \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# ---------------------------------------------------------------------------
# Chromium launcher: the only browser entrypoint in the image.
# ---------------------------------------------------------------------------
COPY chromium.sh /usr/local/bin/chromium-rdp
RUN chmod +x /usr/local/bin/chromium-rdp \
    && if [ -f /usr/bin/chromium ] && [ ! -e /usr/bin/chromium.dist ]; then cp -a /usr/bin/chromium /usr/bin/chromium.dist; fi \
    && ln -sf /usr/local/bin/chromium-rdp /usr/bin/chromium \
    && update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/chromium-rdp 200 \
    && update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/local/bin/chromium-rdp 200 \
    && mkdir -p /etc/chromium/policies/managed /tmp/chromium-cache

# Browser-only policies: no telemetry, no "make default browser" nag, downloads,
# printing, autofill and password manager ON (a normal browsing experience).
RUN printf '%s\n' \
    '{' \
    '  "DefaultBrowserSettingEnabled": false,' \
    '  "MetricsReportingEnabled": false,' \
    '  "BackgroundModeEnabled": false,' \
    '  "ShowHomeButton": true,' \
    '  "HomepageLocation": "https://www.google.com",' \
    '  "BookmarkBarEnabled": true,' \
    '  "PasswordManagerEnabled": true,' \
    '  "AutofillAddressEnabled": true,' \
    '  "AutofillCreditCardEnabled": true,' \
    '  "DownloadRestrictions": 0,' \
    '  "PrintingEnabled": true,' \
    '  "HardwareAccelerationModeEnabled": true,' \
    '  "ExtensionInstallForcelist": [],' \
    '  "RestoreOnStartup": 1,' \
    '  "IncognitoModeAvailability": 0' \
    '}' \
    > /etc/chromium/policies/managed/browser-defaults.json

# ---------------------------------------------------------------------------
# Session: openbox + Chromium kiosk, nothing else.
# ---------------------------------------------------------------------------
COPY session.sh /usr/local/bin/browser-session
COPY openbox-rc.xml /root/.config/openbox/rc.xml
COPY startwm.sh /etc/xrdp/startwm.sh
RUN chmod 755 /usr/local/bin/browser-session /etc/xrdp/startwm.sh \
    && echo "browser-session" > /root/.xsession && chmod 700 /root/.xsession \
    && mkdir -p /root/.config/chromium /root/Downloads

# ---------------------------------------------------------------------------
# xrdp tuning (TLS + speed) and self-signed certificate for the RDP listener.
# ---------------------------------------------------------------------------
COPY tune-ini.sh /tmp/tune-ini.sh
RUN chmod +x /tmp/tune-ini.sh && /tmp/tune-ini.sh && rm -f /tmp/tune-ini.sh

RUN set -eux; \
    xrdp-keygen xrdp /etc/xrdp/rsakeys.ini >/dev/null 2>&1 || true; \
    if [ ! -s /etc/xrdp/cert.pem ] || [ ! -s /etc/xrdp/key.pem ]; then \
      umask 077; \
      openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 3650 \
        -subj "/C=ID/O=Railway-Chromium/CN=railway-chromium" \
        -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem; \
    fi; \
    chmod 600 /etc/xrdp/key.pem; chmod 644 /etc/xrdp/cert.pem

# ---------------------------------------------------------------------------
# Audio (Chrome/Chromium sound), system-wide PulseAudio
# ---------------------------------------------------------------------------
COPY pulse-client.conf /etc/pulse/client.conf
COPY pulse-default.pa /etc/pulse/default.pa
RUN adduser xrdp ssl-cert 2>/dev/null || true; \
    for g in pulse-access pulse; do getent group "$g" >/dev/null || addgroup --system "$g"; done; \
    adduser xrdp pulse-access 2>/dev/null || true; \
    adduser xrdp pulse 2>/dev/null || true; \
    adduser root pulse-access 2>/dev/null || true; \
    printf 'root\trw\nxrdp\trw\n' > /etc/pulse/access.conf; \
    mkdir -p /run/pulse /var/run/pulse && chmod 755 /run/pulse /var/run/pulse

# ---------------------------------------------------------------------------
# noVNC web entrypoint: "browse to the Railway domain" opens Chromium in a tab
# ---------------------------------------------------------------------------
COPY novnc-index.html /usr/share/novnc/index.html
COPY web.sh /usr/local/bin/web-entry
RUN chmod +x /usr/local/bin/web-entry \
    && mkdir -p /var/log /var/run/dbus /run/xrdp /run/user/0 \
    && dbus-uuidgen > /var/lib/dbus/machine-id

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389 8080
STOPSIGNAL SIGTERM

# Healthy when either entrypoint answers (RDP socket or web UI)
HEALTHCHECK --interval=30s --timeout=5s --start-period=25s --retries=3 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/${HTTP_PORT:-8080}' \
        || bash -c 'exec 3<>/dev/tcp/127.0.0.1/${RDP_PORT:-3389}'

CMD ["/start.sh"]
