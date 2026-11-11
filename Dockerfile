# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="Railway Chromium Browser" \
      org.opencontainers.image.description="Chromium-only remote browser (RDP + noVNC), optimized" \
      org.opencontainers.image.source="https://github.com/shadowhexreal/Railway-Fast-Rdp" \
      org.opencontainers.image.licenses="MIT"

# ---------------------------------------------------------------------------
# Build switches (all optional, defaults = full browser)
#   --build-arg WITH_WEB=0        RDP saja   (-8 MB, tanpa Xvfb/x11vnc/noVNC)
#   --build-arg WITH_CJK_FONTS=0  tanpa font CJK (-80 MB)
#   --build-arg WITH_UBLOCK=0     tanpa uBlock Origin
#   --build-arg RDP_MAX_BPP=16    16-bit colour (paling ringan di jaringan jelek)
# ---------------------------------------------------------------------------
ARG WITH_WEB=1
ARG WITH_CJK_FONTS=1
ARG WITH_UBLOCK=1
ARG RDP_MAX_BPP=24

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    XDG_RUNTIME_DIR=/run/user/0 \
    BROWSER=/usr/bin/chromium \
    PULSE_SERVER=unix:/run/pulse/native \
    DISPLAY=:0 \
    RDP_PORT=3389 \
    HTTP_PORT=8080 \
    SCREEN=1600x900x24 \
    # glibc: 2 arena => RSS Chromium jauh lebih kecil di container kecil
    MALLOC_ARENA_MAX=2 \
    # Python (websockify) tidak perlu menulis .pyc
    PYTHONDONTWRITEBYTECODE=1

# Buang dokumen/man/lintian/info saat install (tidak dipakai browser, hemat ~100 MB).
# copyright tetap dipertahankan (wajib untuk lisensi Debian).
RUN printf '%s\n' \
      'path-exclude=/usr/share/doc/*' \
      'path-include=/usr/share/doc/*/copyright' \
      'path-exclude=/usr/share/man/*' \
      'path-exclude=/usr/share/lintian/*' \
      'path-exclude=/usr/share/info/*' \
      > /etc/dpkg/dpkg.cfg.d/01-no-docs \
    && printf '%s\n' \
      'Acquire::Retries "3";' \
      'Acquire::Languages "none";' \
      'APT::Install-Recommends "0";' \
      'APT::Install-Suggests "0";' \
      > /etc/apt/apt.conf.d/99-tune

# ---------------------------------------------------------------------------
# Browser + sesi. Satu layer, tanpa recommends.
# ---------------------------------------------------------------------------
RUN set -eux; \
    WEB_PKGS=""; \
    if [ "$WITH_WEB" = "1" ]; then \
        WEB_PKGS="xvfb x11vnc novnc websockify x11-utils"; \
    fi; \
    UBLOCK_PKGS=""; \
    if [ "$WITH_UBLOCK" = "1" ]; then UBLOCK_PKGS="webext-ublock-origin-chromium"; fi; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates openssl curl procps ssl-cert \
        openbox xdotool dbus dbus-x11 \
        chromium chromium-common $UBLOCK_PKGS \
        libgl1-mesa-dri libglx-mesa0 libegl1 libgles2 libgbm1 \
        fonts-liberation fonts-dejavu-core fonts-noto-color-emoji \
        pulseaudio pulseaudio-utils \
        xrdp $WEB_PKGS; \
    if [ "$WITH_CJK_FONTS" = "1" ]; then \
        apt-get install -y --no-install-recommends fonts-noto-cjk; \
    fi; \
    # --- trim font CJK: sisakan Sans Regular + Bold saja (~91 MB -> ~40 MB) ---
    if [ -d /usr/share/fonts ]; then \
        find /usr/share/fonts -type f -name 'Noto*CJK*' \
             ! -name 'NotoSansCJK-Regular.ttc' ! -name 'NotoSansCJK-Bold.ttc' -delete || true; \
        find /usr/share/fonts -type d -empty -delete || true; \
    fi; \
    # --- buang sisa paket yang tidak dipakai runtime ---
    rm -rf /usr/share/lintian /usr/share/pixmaps/gdeb* \
           /var/lib/apt/lists/* /var/cache/apt/* /var/cache/debconf/* \
           /tmp/* /root/.wget-hsts /etc/apt/apt.conf.d/99-tune; \
    find /usr/lib/chromium -name '*.debug' -delete 2>/dev/null || true; \
    # cache font dibuat sekarang supaya Chromium start cepat (tidak build cache saat login)
    fc-cache -f >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Chromium: launcher tunggal untuk semua jalur (ikon, terminal, xdg-open)
# ---------------------------------------------------------------------------
COPY chromium.sh /usr/local/bin/chromium-rdp
RUN set -eux; \
    chmod +x /usr/local/bin/chromium-rdp; \
    if [ -f /usr/bin/chromium ] && [ ! -e /usr/bin/chromium.dist ]; then cp -a /usr/bin/chromium /usr/bin/chromium.dist; fi; \
    ln -sf /usr/local/bin/chromium-rdp /usr/bin/chromium; \
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/chromium-rdp 200; \
    update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/local/bin/chromium-rdp 200; \
    mkdir -p /etc/chromium/policies/managed /tmp/chromium-cache

# Policy ramping: tanpa telemetri, tanpa nag "set as default", hemat background work
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
    '  "RestoreOnStartup": 1,' \
    '  "IncognitoModeAvailability": 0' \
    '}' \
    > /etc/chromium/policies/managed/browser-defaults.json

# ---------------------------------------------------------------------------
# Sesi browser-only
# ---------------------------------------------------------------------------
COPY session.sh /usr/local/bin/browser-session
COPY openbox-rc.xml /root/.config/openbox/rc.xml
COPY startwm.sh /etc/xrdp/startwm.sh
RUN set -eux; \
    chmod 755 /usr/local/bin/browser-session /etc/xrdp/startwm.sh; \
    echo "browser-session" > /root/.xsession; chmod 700 /root/.xsession; \
    mkdir -p /root/.config/chromium /root/Downloads

# ---------------------------------------------------------------------------
# xrdp: TLS + tuning cepat, sertifikat self-signed sekali bikin
# ---------------------------------------------------------------------------
COPY tune-ini.sh /tmp/tune-ini.sh
RUN set -eux; \
    chmod +x /tmp/tune-ini.sh; RDP_MAX_BPP="${RDP_MAX_BPP}" /tmp/tune-ini.sh; rm -f /tmp/tune-ini.sh; \
    xrdp-keygen xrdp /etc/xrdp/rsakeys.ini >/dev/null 2>&1 || true; \
    if [ ! -s /etc/xrdp/cert.pem ] || [ ! -s /etc/xrdp/key.pem ]; then \
        umask 077; \
        openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 3650 \
            -subj "/C=ID/O=Railway-Chromium/CN=railway-chromium" \
            -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem; \
    fi; \
    chmod 600 /etc/xrdp/key.pem; chmod 644 /etc/xrdp/cert.pem

# ---------------------------------------------------------------------------
# Audio (PulseAudio system-wide)
# ---------------------------------------------------------------------------
COPY pulse-client.conf /etc/pulse/client.conf
COPY pulse-default.pa /etc/pulse/default.pa
RUN set -eux; \
    adduser xrdp ssl-cert 2>/dev/null || true; \
    for g in pulse-access pulse; do getent group "$g" >/dev/null || addgroup --system "$g"; done; \
    adduser xrdp pulse-access 2>/dev/null || true; \
    adduser xrdp pulse 2>/dev/null || true; \
    adduser root pulse-access 2>/dev/null || true; \
    printf 'root\trw\nxrdp\trw\n' > /etc/pulse/access.conf; \
    mkdir -p /run/pulse /var/run/pulse && chmod 755 /run/pulse /var/run/pulse

# ---------------------------------------------------------------------------
# noVNC (opsional)
# ---------------------------------------------------------------------------
COPY novnc-index.html /tmp/novnc-index.html
COPY web.sh /usr/local/bin/web-entry
RUN set -eux; \
    if [ "$WITH_WEB" = "1" ]; then \
        cp /tmp/novnc-index.html /usr/share/novnc/index.html; \
        chmod +x /usr/local/bin/web-entry; \
    else \
        rm -f /usr/local/bin/web-entry; \
    fi; \
    rm -f /tmp/novnc-index.html

RUN mkdir -p /var/log /var/run/dbus /run/xrdp /run/user/0 \
    && dbus-uuidgen > /var/lib/dbus/machine-id \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/*

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389 8080
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/${HTTP_PORT:-8080}' \
        || bash -c 'exec 3<>/dev/tcp/127.0.0.1/${RDP_PORT:-3389}'

CMD ["/start.sh"]
