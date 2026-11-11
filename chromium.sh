#!/bin/bash
# ---------------------------------------------------------------------------
# Chromium launcher for a root / RDP container (Debian Chromium, not Chrome).
#
# Everything that Debian's Chromium normally loses inside a container is
# handled here: the SUID sandbox, /dev/shm size, GPU/WebGL fallback (SwiftShader),
# audio backend, fonts/emoji, codecs, cache location and password store.
#
# You can override anything without touching this file, e.g.:
#   CHROMIUM_FLAGS="--incognito --proxy-server=socks5://1.2.3.4:1080" chromium
# ---------------------------------------------------------------------------
set -u

CHROMIUM_BIN="${CHROMIUM_BIN:-/usr/lib/chromium/chromium}"
CACHE_DIR="${CHROMIUM_CACHE_DIR:-/tmp/chromium-cache}"

if [ ! -x "$CHROMIUM_BIN" ]; then
    # fall back to whatever the Debian package installed
    for cand in /usr/bin/chromium.dist /usr/bin/chromium-browser /opt/chromium/chromium; do
        [ -x "$cand" ] && CHROMIUM_BIN="$cand" && break
    done
fi

mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Chromium refuses to start as root unless the sandbox is disabled (the
# container has no user namespaces for the root user).
RUN_AS_ROOT=0
[ "$(id -u)" = "0" ] && RUN_AS_ROOT=1

FLAGS=(
    # --- container basics ---------------------------------------------------
    --test-type
    --disable-dev-shm-usage                 # /dev/shm is tiny in containers
    --password-store=basic                  # no gnome-keyring / kwallet here
    --no-first-run
    --no-default-browser-check
    --disable-breakpad
    --disable-crash-reporter
    --disk-cache-dir="$CACHE_DIR"
    --disk-cache-size="${CHROMIUM_CACHE_SIZE:-536870912}"
    --media-cache-size=134217728

    # --- rendering: WebGL / Canvas / CSS 3D work without a real GPU --------
    --use-gl=angle
    --use-angle=swiftshader
    --enable-unsafe-swiftshader
    --ignore-gpu-blocklist
    --enable-features=CanvasOopRasterization,ParallelDownloading
    --disable-features=Translate,MediaRouter,OptimizationHints,CalculateNativeWinOcclusion

    # --- desktop / RDP friendliness ---------------------------------------
    --ozone-platform=x11
    --force-color-profile=srgb               # correct colours on 24-bit RDP
    --disable-smooth-scrolling
    --autoplay-policy=no-user-gesture-required
    --window-position=0,0
    --start-maximized                       # full window on a small RDP screen
)

# Root needs --no-sandbox; a normal user gets the real SUID sandbox back.
if [ "$RUN_AS_ROOT" = "1" ]; then
    FLAGS+=(--no-sandbox)
fi

# Optional Widevine/DRM (Netflix, Spotify, Prime Video) if the CDM is present.
if [ -d /opt/google/chrome/WidevineCdm ]; then
    FLAGS+=(--widevine-cdm-path=/opt/google/chrome/WidevineCdm)
    FLAGS+=(--widevine-cdm-version="$(cat /opt/google/chrome/WidevineCdm/manifest.json 2>/dev/null | grep -oE '"version"[^"]*"[^"]*"' | grep -oE '[0-9]+(\.[0-9]+)+' || true)")
fi

# Optional proxy: CHROMIUM_PROXY=http://host:port  (or socks5://...)
if [ -n "${CHROMIUM_PROXY:-}" ]; then
    FLAGS+=("--proxy-server=${CHROMIUM_PROXY}")
fi

# Optional extra flags: CHROMIUM_FLAGS="--incognito --lang=id"
if [ -n "${CHROMIUM_FLAGS:-}" ]; then
    # shellcheck disable=SC2206
    FLAGS+=(${CHROMIUM_FLAGS})
fi

# XDG_RUNTIME_DIR must exist and be 0700 or Chromium/Theora audio complains.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null

# PulseAudio: the container runs a system-wide daemon on this socket.
export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"

# Render with software GL inside a VM / no GPU.
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

exec "$CHROMIUM_BIN" "${FLAGS[@]}" "$@"
