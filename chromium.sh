#!/bin/bash
# ---------------------------------------------------------------------------
# Chromium launcher — dioptimalkan untuk container kecil tanpa GPU.
#
# Prinsip: satu profil, cache kecil, background work dimatikan, WebGL lewat
# SwiftShader, dan semua tuning bisa diubah lewat env TANPA edit file.
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
    --disable-dev-shm-usage                 # /dev/shm container cuma 64 MB
    --password-store=basic                  # tanpa gnome-keyring
    --no-first-run
    --no-default-browser-check
    --disable-breakpad
    --disable-crash-reporter
    --disk-cache-dir="$CACHE_DIR"
    --disk-cache-size="${CHROMIUM_CACHE_SIZE:-268435456}"   # 256 MB (hemat disk & RAM)
    --media-cache-size="${CHROMIUM_MEDIA_CACHE_SIZE:-67108864}"  # 64 MB

    # --- rendering tanpa GPU -----------------------------------------------
    --use-gl=angle
    --use-angle=swiftshader
    --enable-unsafe-swiftshader
    --ignore-gpu-blocklist
    --enable-features=CanvasOopRasterization,ParallelDownloading
    --disable-features=Translate,MediaRouter,OptimizationHints,CalculateNativeWinOcclusion,InterestFeedContentSuggestions

    # --- hemat CPU / latensi start (semua fitur ini tidak berguna di container)
    --disable-background-networking
    --disable-component-update
    --disable-domain-reliability
    --disable-client-side-phishing-detection
    --disable-sync
    --disable-default-apps
    --disable-hang-monitor
    --disable-prompt-on-repost
    --no-pings
    --no-service-autorun
    --hide-crash-restore-bubble            # setelah container restart tidak ada popup "Restore pages?"
    --disable-smooth-scrolling              # kurangi repaint saat scroll via RDP/VNC

    # --- kualitas tampilan remote ------------------------------------------
    --ozone-platform=x11
    --force-color-profile=srgb
    --autoplay-policy=no-user-gesture-required
    --window-position=0,0
    --start-maximized
)

# Batasi jumlah renderer process (RAM lebih kecil di container 1 vCPU)
FLAGS+=("--renderer-process-limit=${CHROMIUM_RENDERER_LIMIT:-3}")

# Mode RAM kecil: 1 proses per situs + low-end device mode
if [ "${CHROMIUM_LOW_RAM:-0}" = "1" ]; then
    FLAGS+=(--process-per-site --enable-low-end-device-mode --disable-gpu-program-cache)
fi

# Root butuh --no-sandbox (tidak ada user namespace untuk root)
[ "$RUN_AS_ROOT" = "1" ] && FLAGS+=(--no-sandbox)

# Proxy opsional
[ -n "${CHROMIUM_PROXY:-}" ] && FLAGS+=("--proxy-server=${CHROMIUM_PROXY}")

# Bahasa UI opsional
[ -n "${BROWSER_LANG:-}" ] && FLAGS+=("--lang=${BROWSER_LANG}")

# Flag tambahan bebas
if [ -n "${CHROMIUM_FLAGS:-}" ]; then
    # shellcheck disable=SC2206
    FLAGS+=(${CHROMIUM_FLAGS})
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
[ -d "$XDG_RUNTIME_DIR" ] || { XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"; export XDG_RUNTIME_DIR; }
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null

export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
# glibc arena kecil => RSS lebih rendah di container
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"

if [ -n "$START_URL" ]; then
    exec "$CHROMIUM_BIN" "${FLAGS[@]}" "$START_URL" "$@"
fi
exec "$CHROMIUM_BIN" "${FLAGS[@]}" "$@"
