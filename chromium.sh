#!/bin/bash
# ---------------------------------------------------------------------------
# Chromium launcher — sadar-RAM (anti "Aw, Snap!").
#
# "Aw, Snap" = proses renderer/GPU dibunuh. Penyebab tersering di container:
#   1. RAM container habis (OOM killer)      -> limit renderer + process-per-site
#   2. /dev/shm kecil (64 MB)                -> --disable-dev-shm-usage + tmpfs
#   3. cache/backing store memakan RAM       -> cache kecil + /tmp = tmpfs
#   4. terlalu banyak tab/ekstensi           -> renderer limit & tab discard
#
# Semua otomatis menyesuaikan RAM yang benar-benar tersedia (cgroup limit),
# dan bisa dipaksa lewat env: CHROMIUM_LOW_RAM=1, CHROMIUM_RENDERER_LIMIT=2,
# CHROMIUM_HEAP_MB=256, CHROMIUM_DISABLE_GPU=1, dst.
# ---------------------------------------------------------------------------
set -u

CHROMIUM_BIN="${CHROMIUM_BIN:-/usr/lib/chromium/chromium}"
START_URL="${START_URL:-}"

if [ ! -x "$CHROMIUM_BIN" ]; then
    for cand in /usr/bin/chromium.dist /usr/bin/chromium-browser; do
        [ -x "$cand" ] && CHROMIUM_BIN="$cand" && break
    done
fi

# ---- 1. berapa RAM yang boleh dipakai? -------------------------------------
mem_limit_mb() {
    local v
    # cgroup v2
    if [ -r /sys/fs/cgroup/memory.max ]; then
        v="$(cat /sys/fs/cgroup/memory.max 2>/dev/null)"
        case "$v" in ''|max) ;; *) echo $(( v / 1048576 )); return;; esac
    fi
    # cgroup v1
    if [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        v="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)"
        if [ -n "${v:-}" ] && [ "$v" -lt 9000000000000000000 ] 2>/dev/null; then
            echo $(( v / 1048576 )); return
        fi
    fi
    # fallback: RAM total host
    awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo
}
MEM_MB="$(mem_limit_mb)"
[ -n "${MEM_MB:-}" ] && [ "$MEM_MB" -gt 0 ] 2>/dev/null || MEM_MB=1024

# ---- 2. pilih profil berdasarkan RAM ---------------------------------------
LOWRAM="${CHROMIUM_LOW_RAM:-auto}"
if [ "$LOWRAM" = "auto" ]; then
    if [ "$MEM_MB" -le 1024 ]; then LOWRAM=1; else LOWRAM=0; fi
fi

# renderer: 1 per ~350 MB, minimal 2, maksimal 6
if [ -n "${CHROMIUM_RENDERER_LIMIT:-}" ]; then
    RENDERERS="$CHROMIUM_RENDERER_LIMIT"
else
    RENDERERS=$(( MEM_MB / 350 ))
    [ "$RENDERERS" -lt 2 ] && RENDERERS=2
    [ "$RENDERERS" -gt 6 ] && RENDERERS=6
fi

# heap JS per renderer: 1/4 RAM, batas 128..512 MB
if [ -n "${CHROMIUM_HEAP_MB:-}" ]; then
    HEAP="$CHROMIUM_HEAP_MB"
else
    HEAP=$(( MEM_MB / 4 ))
    [ "$HEAP" -lt 128 ] && HEAP=128
    [ "$HEAP" -gt 512 ] && HEAP=512
fi

# cache: jangan pernah lebih dari 1/16 RAM
if [ -n "${CHROMIUM_CACHE_SIZE:-}" ]; then
    CACHE="$CHROMIUM_CACHE_SIZE"
else
    CACHE=$(( MEM_MB * 1048576 / 16 ))
    [ "$CACHE" -lt 67108864 ] && CACHE=67108864        # min 64 MB
    [ "$CACHE" -gt 268435456 ] && CACHE=268435456      # max 256 MB
fi

# backing store maksimal: sisakan RAM untuk renderer
BACKING=$(( MEM_MB * 3 / 8 ))
[ "$BACKING" -lt 64 ] && BACKING=64
[ "$BACKING" -gt 512 ] && BACKING=512

# ---- 3. cache & tmp: taruh di tmpfs supaya tidak dobel di page cache ------
CACHE_DIR="${CHROMIUM_CACHE_DIR:-/tmp/chromium-cache}"
case "$CACHE_DIR" in /tmp/*|/dev/shm/*) ;; *) CACHE_DIR=/tmp/chromium-cache;; esac
mkdir -p "$CACHE_DIR" 2>/dev/null || true

RUN_AS_ROOT=0
[ "$(id -u)" = "0" ] && RUN_AS_ROOT=1

# ---- 4. flag ---------------------------------------------------------------
FLAGS=(
    # container basics
    --test-type
    --disable-dev-shm-usage                 # jangan pakai /dev/shm yang cuma 64 MB
    --disable-crash-reporter
    --no-first-run
    --no-default-browser-check
    --password-store=basic
    --disk-cache-dir="$CACHE_DIR"
    --disk-cache-size="$CACHE"
    --media-cache-size="${CHROMIUM_MEDIA_CACHE_SIZE:-33554432}"

    # anti-OOM: renderer dibatasi, tab lama dibuang otomatis, memori GPU dibatasi
    --renderer-process-limit="$RENDERERS"
    --force-gpu-mem-available-mb=64

    # background work dimatikan (hemat CPU + RAM)
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
    --disable-smooth-scrolling
    --hide-crash-restore-bubble

    # tampilan remote
    --ozone-platform=x11
    --force-color-profile=srgb
    --autoplay-policy=no-user-gesture-required
    --window-position=0,0
    --start-maximized
)

# Feature flags: SATU flag enable + SATU flag disable (flag kedua akan menimpa
# yang pertama, jadi semuanya digabung di sini).
#  - AutomaticTabDiscarding : tab yang lama tidak dipakai dilepas dari RAM
#  - MemoryPressurePressureSignals : renderer mengecil sendiri sebelum OOM killer
#    membunuh seluruh container (penyebab utama "Aw, Snap" massal)
FLAGS+=("--enable-features=CanvasOopRasterization,ParallelDownloading,AutomaticTabDiscarding,MemoryPressurePressureSignals")
FLAGS+=("--disable-features=Translate,MediaRouter,OptimizationHints,CalculateNativeWinOcclusion,InterestFeedContentSuggestions,BackForwardCache")

# heap V8 per renderer dibatasi -> satu tab berat tidak menghabiskan container
FLAGS+=("--js-flags=--max-old-space-size=${HEAP} --max-semi-space-size=$(( HEAP / 8 )) --expose-gc=0")

# Root butuh --no-sandbox
[ "$RUN_AS_ROOT" = "1" ] && FLAGS+=(--no-sandbox)

# GPU software (SwiftShader) — tetap ada WebGL, tapi bisa dimatikan total
# kalau GPU process yang bikin crash: CHROMIUM_DISABLE_GPU=1
if [ "${CHROMIUM_DISABLE_GPU:-0}" = "1" ]; then
    FLAGS+=(--disable-gpu --disable-software-rasterizer --disable-accelerated-2d-canvas)
else
    FLAGS+=(--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader --ignore-gpu-blocklist)
fi

# Mode RAM kecil: satu proses per situs (banyak tab di situs sama = 1 proses)
if [ "$LOWRAM" = "1" ]; then
    FLAGS+=(--process-per-site --enable-low-end-device-mode --disable-gpu-program-cache
            --disable-background-timer-throttling)
fi

[ -n "${CHROMIUM_PROXY:-}" ] && FLAGS+=("--proxy-server=${CHROMIUM_PROXY}")
[ -n "${BROWSER_LANG:-}" ] && FLAGS+=("--lang=${BROWSER_LANG}")
if [ -n "${CHROMIUM_FLAGS:-}" ]; then
    # shellcheck disable=SC2206
    FLAGS+=(${CHROMIUM_FLAGS})
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
[ -d "$XDG_RUNTIME_DIR" ] || { XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"; export XDG_RUNTIME_DIR; }
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null && chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null

export PULSE_SERVER="${PULSE_SERVER:-unix:/run/pulse/native}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"   # kurangi fragmentasi heap glibc

echo "[chromium] RAM=${MEM_MB}MB lowram=$LOWRAM renderers=$RENDERERS heap=${HEAP}MB cache=$((CACHE/1048576))MB backing=${BACKING}MB" >&2

if [ -n "$START_URL" ]; then
    exec "$CHROMIUM_BIN" "${FLAGS[@]}" "$START_URL" "$@"
fi
exec "$CHROMIUM_BIN" "${FLAGS[@]}" "$@"
