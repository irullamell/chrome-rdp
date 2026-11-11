#!/usr/bin/env python3
"""Muat extension Auto Refresh ke Chromium yang sedang berjalan (CDP).

Chromium >= 137 mengabaikan --load-extension, jadi extension dipasang lewat
DevTools Protocol: Extensions.loadUnpacked (butuh --enable-unsafe-extension-debugging).
Setelah terpasang, interval global diambil dari env AUTO_REFRESH_SECONDS.

Dipakai oleh session.sh:
    ext-init.py --port 9222 --ext-dir /opt/auto-refresh --seconds 300
"""
import argparse
import base64
import json
import os
import socket
import struct
import sys
import time
import urllib.request

HOST = "127.0.0.1"


def log(msg):
    print(f"[ext] {msg}", flush=True)


class WS:
    """WebSocket client minimal (tanpa dependency)."""

    def __init__(self, url, timeout=10):
        assert url.startswith("ws://"), url
        hostport_path = url[5:]
        hostport, path = hostport_path.split("/", 1)
        host, port = hostport.split(":")
        self.sock = socket.create_connection((host, int(port)), timeout=timeout)
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET /{path} HTTP/1.1\r\n"
            f"Host: {hostport}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        self.sock.sendall(req.encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError("handshake gagal")
            buf += chunk
        if b"101" not in buf.split(b"\r\n")[0]:
            raise RuntimeError("websocket ditolak: " + buf.split(b"\r\n")[0].decode("latin1"))

    def _recv_exact(self, n):
        data = b""
        while len(data) < n:
            chunk = self.sock.recv(n - len(data))
            if not chunk:
                raise EOFError
            data += chunk
        return data

    def send_json(self, obj):
        payload = json.dumps(obj).encode()
        header = bytearray([0x81])
        n = len(payload)
        if n < 126:
            header.append(0x80 | n)
        elif n < 65536:
            header += bytes([0x80 | 126]) + struct.pack(">H", n)
        else:
            header += bytes([0x80 | 127]) + struct.pack(">Q", n)
        mask = os.urandom(4)
        header += mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(bytes(header) + masked)

    def recv_json(self, timeout=10):
        self.sock.settimeout(timeout)
        head = self._recv_exact(2)
        length = head[1] & 0x7F
        if length == 126:
            length = struct.unpack(">H", self._recv_exact(2))[0]
        elif length == 127:
            length = struct.unpack(">Q", self._recv_exact(8))[0]
        return json.loads(self._recv_exact(length).decode("utf-8", "replace"))

    def call(self, msg_id, method, params=None, timeout=10):
        self.send_json({"id": msg_id, "method": method, "params": params or {}})
        deadline = time.time() + timeout
        while time.time() < deadline:
            msg = self.recv_json(timeout=max(0.5, deadline - time.time()))
            if msg.get("id") == msg_id:
                return msg
        raise TimeoutError(method)

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def http_json(path, timeout=3):
    with urllib.request.urlopen(f"http://{HOST}:{PORT}{path}", timeout=timeout) as r:
        return json.load(r)


def wait_for_debug_port(limit=40):
    deadline = time.time() + limit
    while time.time() < deadline:
        try:
            return http_json("/json/version", timeout=1)
        except Exception:
            time.sleep(0.5)
    return None


def find_worker(timeout=15):
    """Cari target service worker extension (tempat chrome.storage bisa diakses)."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            for t in http_json("/json"):
                if t.get("type") in ("service_worker", "background_page") and \
                        t.get("url", "").startswith("chrome-extension://"):
                    return t
        except Exception:
            pass
        time.sleep(0.5)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9222)
    ap.add_argument("--ext-dir", default="/opt/auto-refresh")
    ap.add_argument("--seconds", type=int, default=0)
    ap.add_argument("--timeout", type=int, default=40)
    args = ap.parse_args()

    global PORT
    PORT = args.port

    if not os.path.isdir(args.ext_dir):
        log(f"folder extension tidak ada: {args.ext_dir}")
        return 1

    ver = wait_for_debug_port(args.timeout)
    if not ver:
        log("DevTools port tidak merespons — extension dilewati")
        return 1

    ext_id = None
    try:
        ws = WS(ver["webSocketDebuggerUrl"])
        res = ws.call(1, "Extensions.loadUnpacked", {"path": args.ext_dir})
        ws.close()
        if "error" in res:
            log("gagal memuat extension: " + json.dumps(res["error"])[:160])
        else:
            ext_id = res.get("result", {}).get("id")
            log(f"Auto Refresh terpasang (id {ext_id})")
    except Exception as exc:  # noqa: BLE001
        log(f"CDP error: {exc}")
        return 1

    if args.seconds and args.seconds > 0:
        worker = find_worker()
        if not worker:
            log("service worker belum siap, interval global dilewati")
            return 0
        try:
            ws = WS(worker["webSocketDebuggerUrl"])
            expr = (
                "chrome.storage.local.set({globalSeconds:%d,paused:false})"
                ".then(()=>'ok')" % args.seconds
            )
            res = ws.call(
                1, "Runtime.evaluate",
                {"expression": expr, "awaitPromise": True, "returnByValue": True},
            )
            ws.close()
            value = res.get("result", {}).get("result", {}).get("value")
            if value == "ok":
                log(f"auto refresh global = {args.seconds}s")
            else:
                log("gagal set interval: " + json.dumps(res)[:160])
        except Exception as exc:  # noqa: BLE001
            log(f"set interval error: {exc}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
