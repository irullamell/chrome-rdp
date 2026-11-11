#!/bin/bash
# ---------------------------------------------------------------------------
# One-shot tuner for /etc/xrdp/xrdp.ini + sesman.ini (xrdp 0.9.21, Debian 12).
#
# Behaviour, per key:
#   * active  "key=..."        -> value replaced in place
#   * commented "#key=..."     -> enabled in place with the new value
#   * not present at all       -> appended right after [Globals]
# Sections are never invented, so xrdp always starts even if upstream renames
# something. Values with '/' (paths) are handled safely by awk, not sed.
# ---------------------------------------------------------------------------
set -u

XIN="/etc/xrdp/xrdp.ini"
SIN="/etc/xrdp/sesman.ini"

set_kv() { # set_kv <file> <key> <value>
    local f="$1" k="$2" v="$3" tmp mode=""
    [ -f "$f" ] || return 0

    # decide what to do with this key *before* touching the file
    if grep -qE "^${k}[[:space:]]*=" "$f"; then
        mode="active"
    elif grep -qE "^[#;][[:space:]]*${k}[[:space:]]*=" "$f"; then
        mode="commented"
    elif grep -qE '^\[Globals\]' "$f"; then
        mode="append"
    else
        return 0
    fi

    tmp="$(mktemp)"
    awk -v k="$k" -v v="$v" -v mode="$mode" '
        mode == "active" && !done && $0 ~ ("^" k "[ \t]*=")            { print k "=" v; done=1; next }
        mode == "commented" && !done && $0 ~ ("^[#;][ \t]*" k "[ \t]*=") { print k "=" v; done=1; next }
        mode == "append" && !done && $0 ~ /^\[Globals\]/              { print; print k "=" v; done=1; next }
        { print }
    ' "$f" > "$tmp" && cat "$tmp" > "$f"
    rm -f "$tmp"
}

# ---- xrdp.ini: TLS + performance -----------------------------------------
set_kv "$XIN" port 3389
set_kv "$XIN" security_layer negotiate        # plain RDP *and* TLS => no "protocol error"
set_kv "$XIN" crypt_level high
set_kv "$XIN" ssl_protocols TLSv1.2,TLSv1.3
set_kv "$XIN" tls_ciphers HIGH:!aNULL:!eNULL:!3DES
set_kv "$XIN" certificate /etc/xrdp/cert.pem
set_kv "$XIN" key_file /etc/xrdp/key.pem
set_kv "$XIN" allow_channels true
set_kv "$XIN" allow_multimon true
set_kv "$XIN" max_bpp 24                      # 24-bit: correct colours, still fast
set_kv "$XIN" use_fastpath both
set_kv "$XIN" bitmap_cache true
set_kv "$XIN" bitmap_compression true
set_kv "$XIN" bulk_compression true
set_kv "$XIN" new_cursors true
set_kv "$XIN" tcp_nodelay true
set_kv "$XIN" tcp_keepalive true
set_kv "$XIN" tcp_send_buffer_bytes 1048576
set_kv "$XIN" tcp_recv_buffer_bytes 2097152
set_kv "$XIN" autorun ""
set_kv "$XIN" hidelogwindow true
set_kv "$XIN" require_credentials false
set_kv "$XIN" enable_token_login false

# ---- sesman.ini: sessions survive disconnects ----------------------------
set_kv "$SIN" KillDisconnected false
set_kv "$SIN" DisconnectedTimeLimit 0
set_kv "$SIN" IdleTimeLimit 0
set_kv "$SIN" MaxLoginRetry 0
set_kv "$SIN" AllowRootLogin true
set_kv "$SIN" DefaultWindowManager startwm.sh
set_kv "$SIN" EnableUserWindowManager true
set_kv "$SIN" UserWindowManager startwm.sh
set_kv "$SIN" EnablePAMAuth false

exit 0
