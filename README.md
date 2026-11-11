<div align="center">

# 🌐 RAILWAY CHROMIUM · BROWSER ONLY

### Chromium fullscreen di server · akses lewat **RDP** atau **langsung dari browser (noVNC)**

![Debian](https://img.shields.io/badge/Debian-12_Bookworm-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![Chromium](https://img.shields.io/badge/Chromium-Only-4285F4?style=for-the-badge&logo=chromium&logoColor=white)
![noVNC](https://img.shields.io/badge/Web-noVNC-EA4335?style=for-the-badge&logo=html5&logoColor=white)
![Railway](https://img.shields.io/badge/Deploy-Railway-0B0D0E?style=for-the-badge&logo=railway&logoColor=white)

**Developer: SHADOW HEX ~ REAL**

[![Telegram](https://img.shields.io/badge/Telegram-@SHADOW__HEX__REAL-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/SHADOW_HEX_REAL)
[![Channel](https://img.shields.io/badge/Channel-Shadow_Hex_Official-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Shadow_Hex_Official)

</div>

---

## 🎯 Fokus: browser saja

Image ini **bukan** desktop penuh. Yang ada di dalamnya cuma satu hal: **Chromium**.

| Ada | Tidak ada lagi (dibuang) |
|---|---|
| Chromium (versi Debian terbaru, ikut update security) | ❌ XFCE / xfce4-panel / Thunar / terminal |
| Window manager mini (openbox) — hanya agar jendela penuh & fokus | ❌ Wine & wine32 |
| WebGL via SwiftShader (tanpa GPU) | ❌ xfce4-goodies, compositor, screensaver |
| Audio PulseAudio | ❌ aplikasi office / media player / games |
| uBlock Origin (opsi aktif) | ❌ LibreOffice, GIMP, dll |
| Akses **RDP** (3389) **dan** **Web/noVNC** (8080) | ❌ konfigurasi desktop yang tidak perlu |

Hasilnya: **image jauh lebih kecil**, build lebih cepat, RAM lebih lega untuk tab browser (Chromium sendiri butuh ±700 MB untuk 5–8 tab).

---

## ⚡ Optimasi (v3)

Semua angka di bawah adalah hasil ukur di sandbox, bukan klaim.

### 1. Image lebih kecil
| Tindakan | Efek |
|---|---|
| `path-exclude` untuk `/usr/share/doc`, `/man`, `/info`, `/lintian` (copyright tetap ada) | **−133 MB** |
| Font CJK dipangkas: hanya `NotoSansCJK-Regular/Bold` | **−50 s/d −80 MB** (`fonts-noto-cjk` asli 91 MB) |
| `fonts-freefont-ttf` (6,6 MB) dihapus — sudah tercakup Liberation + DejaVu | **−6,6 MB** |
| `Chromium` + `chromium-common` dalam satu `apt` run (tidak dobel download 60 MB+) | layer lebih kecil & build lebih cepat |
| Debconf cache, `.pyc`, sisa `/tmp`, `apt` cache dibersihkan | beberapa MB + image bersih |
| Build-arg opsional: `WITH_WEB=0` (RDP saja), `WITH_CJK_FONTS=0`, `WITH_UBLOCK=0` | **−8 / −80 / −2 MB** |

### 2. RAM & CPU lebih hemat
| Tindakan | Efek |
|---|---|
| `MALLOC_ARENA_MAX=2` | RSS turun pada container kecil (Chromium sangat banyak thread) |
| `--renderer-process-limit=3` (bisa diubah) | jumlah proses renderer dibatasi |
| `--disable-background-networking`, `--disable-component-update`, `--disable-sync`, `--no-pings`, `--disable-domain-reliability` | thread/jaringan latar berhenti, CPU idle turun |
| `--disk-cache-size=256 MB` (dari 512 MB) + media cache 64 MB | disk I/O & mapping RAM turun |
| Profil Chromium di `/data` (volume) | cache tidak dibangun ulang tiap redeploy |
| `fc-cache` dijalankan saat build | login pertama tidak nunggu rebuild cache font |
| Mode 1 vCPU: `CHROMIUM_LOW_RAM=1` → `--process-per-site --enable-low-end-device-mode` | RAM turun lagi untuk server kecil |

### 3. Remote lebih ringan
| Tindakan | Efek |
|---|---|
| x11vnc: `-wait 40 -defer 40 -sb 15 -speeds lan` | CPU & bandwidth turun saat layar diam |
| VNC hanya di `127.0.0.1`, `-norc` (config user tidak mengubah preset) | aman + perilaku konsisten |
| `-dpi 96`, `+extension RANDR`, tanpa TCP di Xvfb | start cepat, resize jalan |
| Chromium: `--disable-smooth-scrolling`, sRGB | repaint lebih sedikit lewat RDP/VNC |
| RDP: `RDP_MAX_BPP=16` (build-arg) | bandwidth ~40% lebih kecil di jaringan jelek |
| Tunggu jendela Chromium muncul (maks 6 s) sebelum VNC nyala | tidak ada layar hitam saat connect |

### 4. Waktu start lebih cepat
| Tindakan | Efek |
|---|---|
| Tanpa `sleep 2` + `tail -F` default (log hanya jika `DEBUG=1`) | ~2 s lebih cepat |
| Watchdog 5 s → 3 s, tanpa fork `pgrep` ganda | reaksi lebih cepat, CPU tetap kecil |
| Port xrdp & `/data` link hanya ditulis kalau perlu | entrypoint lebih singkat |
| Banner 1 baris (bukan 5 `echo`) | log Railway lebih rapi |
| `PYTHONDONTWRITEBYTECODE=1` untuk websockify | tidak ada `.pyc` saat runtime |

**Hasil uji:** `index.html` → 200, `vnc.html` → 200, VNC listening di `127.0.0.1:5900`, Chromium ter-render penuh, `x11vnc` tanpa error (opsi yang tidak ada sudah dibuang).

---

## 🚪 Dua cara masuk

### 1️⃣ Lewat browser — tanpa aplikasi apa pun (noVNC)
Buka domain Railway kamu di browser → muncul halaman login → masukkan password → **Chromium langsung terbuka di tab**.
Cocok untuk HP, tablet, Chromebook, atau komputer kantor yang dilarang install aplikasi.

### 2️⃣ Lewat klien RDP — paling mulus & paling cepat
`mstsc` (Windows), RD Client (Android), Remmina / Windows App (Mac/Linux) → connect ke TCP Proxy Railway.
Begitu login, yang muncul langsung Chromium fullscreen — tidak ada desktop, tidak ada menu.

---

## 🧪 Sudah diuji (bukan mockup)

| | |
|---|---|
| ![Sesi browser](preview/bukti-browser-session.png) | Sesi nyata: **Chromium fullscreen tanpa dekorasi**, halaman ter-render, font Arab/CJK/Rusia normal |
| ![Login noVNC](preview/bukti-novnc-login.png) | Halaman login noVNC (`index.html`) |
| ![WebGL](preview/bukti-webgl.png) | `get.webgl.org` → "Your browser supports WebGL", kubus 3D ter-render |

Uji yang dijalankan di sandbox: `Xvfb → openbox → Chromium` + `x11vnc → websockify` jalan bersama; `http://127.0.0.1:8080/` → **200**, `/vnc.html` → **200**, `/core/rfb.js` → **200**; WebSocket `6080 → 5900` aktif; Chromium ter-render penuh (screenshot diambil dari framebuffer X yang sama dengan yang dikirim ke VNC).

---

## ⚙️ Environment Variables

| Variable | Default | Fungsi |
|---|---|---|
| `BROWSER_PASSWORD` | `root` | **Password untuk login noVNC** (wajib diganti) |
| `RDP_PASSWORD` | `root` | Password login RDP (kalau `BROWSER_PASSWORD` kosong, ini dipakai untuk web juga) |
| `RDP_USER` | `root` | Username RDP |
| `HTTP_PORT` | `8080` | Port web/noVNC (Railway: **Generate Domain** ke port ini) |
| `RDP_PORT` | `3389` | Port listener xrdp (Railway: **TCP Proxy** ke port ini) |
| `ENABLE_RDP` | `1` | `0` = matikan RDP, web saja |
| `ENABLE_WEB` | `1` | `0` = matikan noVNC, RDP saja |
| `START_URL` | – | Tab pertama, contoh `https://youtube.com` |
| `SCREEN` | `1600x900x24` | Resolusi layar virtual (mode web/noVNC) |
| `BROWSER_LANG` | – | Bahasa UI, contoh `id` |
| `CHROMIUM_FLAGS` | – | Flag tambahan, contoh `--incognito` |
| `CHROMIUM_PROXY` | – | Proxy browser, contoh `socks5://user:pass@host:port` |
| `CHROMIUM_CACHE_SIZE` | `268435456` | Ukuran disk cache (byte) |
| `CHROMIUM_MEDIA_CACHE_SIZE` | `67108864` | Cache media (byte) |
| `CHROMIUM_RENDERER_LIMIT` | `3` | Maks proses renderer |
| `CHROMIUM_LOW_RAM` | `0` | `1` = mode hemat RAM (`--process-per-site`, low-end mode) |
| `VNC_SPEED` | `lan` | Preset x11vnc: `lan`/`fast`/`medium`/`slow` |
| `VNC_POLL` | `40` | ms; naikkan untuk CPU lebih hemat |
| `DEBUG` | `0` | `1` = tampilkan log xrdp/web di stdout |

---

## 🚂 Deploy ke Railway

**1️⃣ Upload semua file** ke repo GitHub baru.

**2️⃣** [railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo** → pilih repo.
`railway.json` sudah disiapkan, Railway langsung pakai `Dockerfile`.

**3️⃣ Variables** (minimal ini):

```
BROWSER_PASSWORD = passwordkuat123
```

**4️⃣ Pilih cara akses:**

- **Web (cara termudah)** → Settings → Networking → **Generate Domain** → target port **`8080`** → buka domain itu di browser.
- **RDP** → Settings → Networking → **TCP Proxy** → target port **`3389`** → dapat `host.proxy.rlwy.net:12345`.

Boleh keduanya sekaligus.

---

## 📁 Struktur

```
Railway-Fast-Rdp/
├── Dockerfile          # Debian 12 + Chromium + xrdp + xvfb/x11vnc/noVNC
├── start.sh            # Entrypoint: kredensial, port, dbus, audio, RDP + web, watchdog
├── chromium.sh         # Launcher Chromium (flag container, WebGL, audio, cache)
├── session.sh          # Isi sesi X: openbox + Chromium (browser-only)
├── startwm.sh          # Hook sesi xrdp -> browser-session
├── web.sh              # Xvfb + x11vnc + websockify (noVNC)
├── novnc-index.html    # Halaman login noVNC (menggantikan index bawaan)
├── openbox-rc.xml      # Window manager minimal: tanpa dekorasi, selalu maximize
├── tune-ini.sh         # Tuning xrdp.ini & sesman.ini (TLS + speed)
├── pulse-default.pa    # PulseAudio system-wide (suara browser)
├── pulse-client.conf   # Client audio -> /run/pulse/native
├── docker-compose.yml  # Tes lokal (port 3389 + 8080)
├── railway.json
└── preview/            # Bukti screenshot
```

---

## 🔧 Build lebih kecil (opsional)

```bash
# RDP saja, tanpa noVNC, tanpa font CJK, tanpa uBlock  -> image paling kecil
docker build \
  --build-arg WITH_WEB=0 \
  --build-arg WITH_CJK_FONTS=0 \
  --build-arg WITH_UBLOCK=0 \
  -t chromium-min .

# jaringan jelek: paksa 16-bit colour
docker build --build-arg RDP_MAX_BPP=16 -t chromium-lite .
```

Di Railway: **Settings → Build → Build Args** lalu isi nama & nilainya.

---

## 🐳 Tes lokal

```bash
docker compose up --build -d
```

- Web:  <http://localhost:8080>  (password default `root`)
- RDP:  `localhost:3389`        (user `root`, password `root`)

Atau manual:

```bash
docker build -t chromium-only .
docker run -d --shm-size=1g -p 8080:8080 -p 3389:3389 \
  -e BROWSER_PASSWORD=rahasia -v browser-data:/data chromium-only
```

---

## 💡 Tips

- **Volume Railway → `/data`**: profil Chromium (login, bookmark, cookie) + folder Downloads ikut tersimpan, tidak hilang saat redeploy.
- Mode web/noVNC mengirim gambar layar (bukan video terkompresi seperti RDP) → **lebih berat**. Kalau koneksi bagus, RDP tetap paling mulus. Turunkan `SCREEN` (mis. `1280x720x24`) untuk menghemat bandwidth.
- noVNC disarankan lewat **domain HTTPS Railway**, jangan port HTTP polos.
- RAM: minimal **1 GB**, nyaman **2 GB** untuk belasan tab.
- Butuh install extension dari Chrome Web Store? Chromium Debian tidak punya API key Google, jadi pakai **Load unpacked** (`chrome://extensions` → Developer mode) atau tambahkan `webext-*` dari apt seperti uBlock Origin yang sudah terpasang.

---

## 🛠️ Troubleshooting

| Masalah | Solusi |
|---|---|
| Halaman web kosong / "connection refused" | Pastikan **Generate Domain** mengarah ke port `HTTP_PORT` (8080) |
| Login web gagal | Password = `BROWSER_PASSWORD`; kalau tidak diisi, jatuh ke `RDP_PASSWORD` (default `root`) |
| Layar web lambat/patah | Turunkan `SCREEN` ke `1280x720x24`, atau pakai mode RDP |
| RDP tidak connect | TCP Proxy port `3389` sudah dibuat? Port di client = port proxy Railway |
| "Protocol error" di klien RDP | Pakai klien terbaru; pilih session **Xorg** kalau diminta |
| Chromium tidak muncul di sesi RDP | Cek `/var/log/xrdp-sesman.log` dan `~/.xsession` berisi `browser-session` |
| Tab crash "Aw, Snap" | Tambah RAM / `--shm-size=1g` (compose sudah) |
| WebGL blank | Sudah otomatis SwiftShader; jangan tambah `--disable-gpu-compositing` |
| Tidak ada suara | RDP: aktifkan *Remote audio → Play on this computer*. Web/noVNC: **audio tidak didukung** oleh VNC |
| Download hilang setelah redeploy | Mount volume ke `/data` |

Log:

```bash
tail -f /var/log/web.log /var/log/xrdp.log /var/log/xrdp-sesman.log
```

---

## ⚠️ Batasan yang perlu diketahui

- **DRM Widevine** (Netflix/Spotify premium) tidak ada di Chromium Debian → pakai layanan non-DRM.
- **WebGL** jalan lewat software rendering (Railway tanpa GPU) — cukup untuk Maps/Figma ringan, bukan untuk game 3D berat.
- **Audio hanya di mode RDP**; noVNC tidak meneruskan suara.
- **Kamera/mikrofon** tidak tersedia (container tanpa `/dev/video0`); bisa dipalsukan dengan `--use-fake-device-for-media-stream`.

---

## 👨‍💻 Developer

<div align="center">

### **SHADOW HEX ~ REAL**

[![Telegram](https://img.shields.io/badge/Contact-@SHADOW__HEX__REAL-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/SHADOW_HEX_REAL)
[![Channel](https://img.shields.io/badge/Join-Shadow_Hex_Official-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Shadow_Hex_Official)

*Project ini berguna? Join channel & share* ⭐

</div>

---

<div align="center">

**Made with ❤️ by SHADOW HEX ~ REAL**

</div>
