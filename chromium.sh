#!/bin/bash
# ---------------------------------------------------------------------------
# Chromium launcher for this container. This image is browser-only: every
# flag here exists so that Chromium behaves like a normal browser on a remote
# desktop (WebGL, audio, downloads, clipboard, passwords) and nothing else.
#
# Override without editing this file:
#   CHROMIUM_FLAGS="--incognito --lang=id"     chromium
#   START_URL="https://youtube.com"            (first tab)
# ---------------------------------------------------------------------------
set -u

CHROMIUM_BIN="${CHROMIUM_BIN:-/usr/lib/chromium/chromium}"
CACHE_DIR="${CHROMIUM_CACHE_DIR:-/tmp/chromium-cache}"
START_URL="${START_URL:-}"

if [ ! -x "$CHROMIUM_BIN" ]; then
    for cand in /usr/bin/chromium.dist /usr/bin/chromium-browser; do
        [ -x "$cand" ] && CHROMIUM_BIN="$cand" && break
    done
fi

mkdir -p "$CACHE_DIR" 2>/dev/null || true

RUN_AS_ROOT=0
[ "$(id -u)" = "0" ] && RUN_AS_ROOT=1

FLAGS=(
    # --- container basics ---------------------------------------------------
    --test-type
    --disable-dev-shm-usage                 # /dev/shm is tiny inside containers
    --password-store=basic                  # no gnome-keyring in this image
    --no-first-run
    --no-default-browser-check
    --disable-breakpad
    --disable-crash-reporter
    --disk-cache-dir="$CACHE_DIR"
    --disk-cache-size="${CHROMIUM_CACHE_SIZE:-536870912}"
    --media-cache-size=134217728

    # --- rendering: WebGL / Canvas2D / CSS3 without a GPU -------------------
    --use-gl=angle
    --use-angle=swiftshader
    --enable-unsafe-swiftshader
    --ignore-gpu-blocklist
    --enable-features=CanvasOopRasterization,ParallelDownloading
    --disable-features=Translate,MediaRouter,OptimizationHints,CalculateNativeWinOcclusion

    # --- browsing quality of life -------------------------------------------
    --ozone-platform=x11
    --force-color-profile=srgb
    --autoplay-policy=no-user-gesture-required
    --window-position=0,0
    --start-maximized
)

if [ "$RUN_AS_ROOT" = "1" ]; then
    FLAGS+=(--no-sandbox)                   # no user namespaces for root
fi

# Optional proxy: CHROMIUM_PROXY=http://host:port or socks5://host:port
if [ -n "${CHROMIUM_PROXY:-}" ]; then
    FLAGS+=("--proxy-server=${CHROMIUM_PROXY}")
fi

# Optional language / UI locale
if [ -n "${BROWSER_LANG:-}" ]; then
    FLAGS+=("--lang=${BROWSER_LANG}")
fi

# Optional extra flags
if [ -n "${CHROMIUM_FLAGS:-}" ]; then
    # shellcheck disable=SC2206
    FLAGS+=(${CHROMIUM_FLAGS})
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null

# Audio: the container runs a system-wide PulseAudio daemon.
export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"

# No GPU in the container: render with software GL.
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

if [ -n "$START_URL" ]; then
    exec "$CHROMIUM_BIN" "${FLAGS[@]}" "$START_URL" "$@"
fi
exec "$CHROMIUM_BIN" "${FLAGS[@]}" "$@"
