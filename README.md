<div align="center">

# 🚀 DEBIAN XRDP · FAST EDITION

### Deploy di Railway · **Chromium native** · Remote Desktop super cepat

![Debian](https://img.shields.io/badge/Debian-12_Bookworm-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![XFCE](https://img.shields.io/badge/Desktop-XFCE4-2284F2?style=for-the-badge&logo=xfce&logoColor=white)
![Chromium](https://img.shields.io/badge/Browser-Chromium_100%25-4285F4?style=for-the-badge&logo=chromium&logoColor=white)
![Railway](https://img.shields.io/badge/Deploy-Railway-0B0D0E?style=for-the-badge&logo=railway&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)

**Developer: SHADOW HEX ~ REAL**

[![Telegram](https://img.shields.io/badge/Telegram-@SHADOW__HEX__REAL-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/SHADOW_HEX_REAL)
[![Channel](https://img.shields.io/badge/Channel-Shadow_Hex_Official-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Shadow_Hex_Official)

</div>

---

## 🔥 Yang berubah di versi ini

| Sebelum | Sekarang |
|---|---|
| Google Chrome (file `.deb` dari dl.google.com) | **Chromium native Debian** — tanpa download `.deb`, ikut update security Debian |
| Base `debian:bullseye` (EOL, harus pakai `archive.debian.org` + hack `Check-Valid-Until`) | **`debian:bookworm-slim`** (LTS sampai 2028) — `apt update` normal, tanpa hack |
| Browser di-patch manual (`mv google-chrome`) | **Launcher terpisah** `chromium-rdp` + `update-alternatives`, desktop icon otomatis |
| Tanpa TLS, tanpa audio RDP | **TLS 1.2/1.3**, clipboard, drive redirection, audio PulseAudio |
| Password & port hard-code | Bisa diubah lewat **Environment Variables** di Railway |

> Chrome **tidak** dipakai lagi. Semua yang tadinya jalan di Chrome sekarang jalan di Chromium, termasuk WebGL, audio, clipboard, upload/download, print, dan video.

---

## ✅ Dukungan "100%" — apa saja yang sudah dites jalan

Chromium di dalam container sering "setengah jalan" (WebGL mati, suara tidak keluar, tab crash, password tidak tersimpan). Semua penyebabnya sudah ditangani:

| Fitur | Status | Bagaimana ditangani |
|---|---|---|
| Browsing normal, tab, bookmark | ✅ | Normal |
| **WebGL / WebGL2 / Canvas 3D** (game, Figma, Maps 3D) | ✅ | `--use-angle=swiftshader` + `--enable-unsafe-swiftshader` (software GL, tanpa GPU) |
| **Video YouTube / MP4 / WebM / H.264** | ✅ | Codec Debian Chromium + `libopenh264` |
| **Audio browser** (YouTube, Spotify web) | ✅ | PulseAudio system-wide `unix:/run/pulse/native` |
| **Audio RDP** (suara sampai ke client) | ✅ | `xrdp-chansrv` + modul `module-xrdp-sink` (auto kalau tersedia) |
| **Clipboard copy/paste 2 arah** | ✅ | Channel `cliprdr` (`allow_channels=true`) |
| **Download & upload file** | ✅ | Folder `/root/Downloads` (bisa dipersist ke volume `/data`) |
| **Print ke PDF / printer** | ✅ | `PrintingEnabled=true` |
| **Password manager + autofill** | ✅ | `--password-store=basic` (tanpa keyring) + policy aktif |
| **Emoji & font Asia** | ✅ | `fonts-noto-color-emoji`, `fonts-noto-cjk`, `fonts-noto-core` |
| **Zoom / video call di browser** | ✅ | Kamera virtual: pakai `--use-fake-device-for-media-stream` atau `/dev/video0` kalau ada |
| **Multi-monitor & resize window** | ✅ | Backend `xorgxrdp` + `allow_multimon=true` |
| **Warna akurat (tidak kusam)** | ✅ | `max_bpp=24` + `--force-color-profile=srgb` |
| **Zoom HiDPI** | ✅ | XFCE 96 dpi + zoom bawaan Chromium |
| **Wine (.exe Windows)** | ✅ | `wine` + `wine32` (matikan dengan `ENABLE_WINE=0`) |
| **Netflix / DRM (Widevine)** | ⚠️ | Chromium Debian tidak membawa Widevine. Untuk DRM: `ENABLE_WINE` + Chrome di dalam Wine, atau pakai build Chromium ber-Widevine |
| **Akselerasi GPU** | ⚠️ | Railway tidak punya GPU → otomatis software (SwiftShader), tetap mulus untuk web ringan–menengah |

---

## 🔐 Login

| Field | Default | Bisa diubah lewat |
|---|---|---|
| **Username** | `root` | `RDP_USER` |
| **Password** | `root` | **`RDP_PASSWORD`** ← wajib diganti! |
| **Port RDP** | `3389` | `RDP_PORT` |
| **Host** | dari Railway TCP Proxy | — |

> ⚠️ **Keamanan:** jangan deploy publik dengan `root/root`. Di Railway cukup buka tab **Variables** lalu tambahkan `RDP_PASSWORD` (dan `RDP_USER` kalau mau user lain). Tidak perlu edit file.

---

## ⚙️ Environment Variables

| Variable | Default | Fungsi |
|---|---|---|
| `RDP_USER` | `root` | Username login (dibuat otomatis kalau belum ada, masuk grup sudo) |
| `RDP_PASSWORD` | `root` | Password login |
| `RDP_PORT` | `3389` | Port listener xrdp (samakan dengan TCP Proxy) |
| `ENABLE_WINE` (build arg) | `1` | `0` = image lebih kecil tanpa Wine |
| `CHROMIUM_FLAGS` | – | Flag tambahan, contoh `--incognito --lang=id` |
| `CHROMIUM_PROXY` | – | Proxy browser, contoh `socks5://user:pass@host:port` |
| `CHROMIUM_CACHE_SIZE` | `536870912` | Ukuran disk cache (byte) |

---

## 📁 Struktur

```
Railway-Fast-Rdp/
├── Dockerfile          # Debian 12 + XFCE + Chromium + xrdp + (Wine)
├── start.sh            # Entrypoint: kredensial, port, dbus, PulseAudio, xrdp + watchdog
├── startwm.sh          # Sesi XRDP → XFCE dengan env Chromium/audio yang benar
├── chromium.sh         # Launcher Chromium (flag container, WebGL, audio, cache)
├── tune-ini.sh         # Tuning xrdp.ini & sesman.ini saat build
├── pulse-default.pa    # Konfigurasi PulseAudio system-wide
├── pulse-client.conf   # Client audio → socket /run/pulse/native
├── docker-compose.yml  # Untuk tes lokal
├── railway.json        # Konfigurasi deploy Railway
└── README.md
```

---

## 🚂 Deploy ke Railway

**1️⃣ Upload ke GitHub**
Upload semua file di folder ini ke repository baru.

**2️⃣ Buat project di Railway**
[railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo** → pilih repo.
Railway mendeteksi `Dockerfile` sendiri (`railway.json` juga sudah disediakan).

**3️⃣ Set password (jangan skip)**
Tab **Variables** → tambah:

```
RDP_PASSWORD = passwordkuat123
```

**4️⃣ Tambah TCP Proxy**
Service → **Settings** → **Networking** → **TCP Proxy** → **Add** → target port **`3389`**.

Railway memberi alamat seperti `something.proxy.rlwy.net:12345`. **Port `12345` inilah yang dipakai**, bukan `3389`.

---

## 🔌 Cara Connect

### 🪟 Windows
`Win + R` → `mstsc` → Computer: `something.proxy.rlwy.net:12345` → Connect → user `root` + password kamu.
Kalau muncul peringatan sertifikat, pilih **Yes / Continue**.

### 🤖 Android
Install **Microsoft Remote Desktop (RD Client)** → **Add PC** → host `something.proxy.rlwy.net`, port `12345` → user `root`.

### 🍎 Mac / 🐧 Linux
- Mac: **Windows App / Microsoft Remote Desktop**
- Linux: `xfreerdp /v:something.proxy.rlwy.net:12345 /u:root /p:password /dynamic-resolution +clipboard`

Di layar login xrdp pilih **Session: `Xorg`** (bukan Xvnc) supaya resize & Chromium stabil.

---

## 🏎️ Tips biar makin ngebut

- Client RDP → **Experience** → *Low-speed broadband* / *Modem*
- Aktifkan **Dynamic resolution / resize** di client
- Matikan wallpaper (`xfdesktop`) kalau koneksi lambat
- Naikkan RAM service di Railway — Chromium butuh ±700 MB untuk 5–8 tab
- Mau lebih tajam? `max_bpp=24` sudah default; turunkan ke `16` di `tune-ini.sh` untuk koneksi jelek

---

## 🐳 Tes lokal

```bash
docker compose up --build -d
# lalu connect ke localhost:3389  (root / root)
```

Atau manual:

```bash
docker build -t xrdp-chromium .
docker run -d -p 3389:3389 -e RDP_PASSWORD=rahasia --shm-size=1g \
  -v rdp-data:/data --name rdp xrdp-chromium
```

---

## 🛠️ Troubleshooting

| Masalah | Solusi |
|---|---|
| `apt` 404 / build gagal | Jangan pakai `debian:bullseye`. Versi ini sudah di `bookworm` |
| RDP tidak connect | TCP Proxy port `3389` sudah dibuat? Port di client harus port proxy Railway |
| "Protocol error" / disconnect | Pakai client terbaru, pilih session **Xorg**, aktifkan TLS otomatis |
| Layar hitam | Disconnect lalu login ulang, session **Xorg**; cek log: `tail -f /var/log/xrdp-sesman.log` |
| Chromium tidak mau buka | Jalankan `chromium` di terminal XFCE untuk lihat error; pastikan `RDP_PASSWORD` benar |
| Tab crash / "Aw, Snap" | Tambah RAM di Railway (min. 1 GB) atau set `CHROMIUM_CACHE_SIZE=268435456` |
| WebGL/diagram 3D blank | Sudah di-handle SwiftShader; pastikan tidak menambah flag `--disable-gpu-compositing` sendiri |
| Tidak ada suara | Client RDP → **Local Resources → Remote audio → Play on this computer** |
| Copy-paste tidak jalan | Aktifkan clipboard di client; `allow_channels=true` sudah default |
| Download hilang setelah restart | Mount Railway Volume ke `/data` (profil Chromium & Downloads otomatis dipindah ke sana) |

Log penting:

```bash
tail -f /var/log/xrdp.log /var/log/xrdp-sesman.log
```

---

## 👨‍💻 Developer

<div align="center">

### **SHADOW HEX ~ REAL**

[![Telegram](https://img.shields.io/badge/Contact-@SHADOW__HEX__REAL-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/SHADOW_HEX_REAL)
[![Channel](https://img.shields.io/badge/Join-Shadow_Hex_Official-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Shadow_Hex_Official)

📩 **Telegram:** [@SHADOW_HEX_REAL](https://t.me/SHADOW_HEX_REAL)
📢 **Channel:** [t.me/Shadow_Hex_Official](https://t.me/Shadow_Hex_Official)

*Project ini berguna? Join channel & share* ⭐

</div>

---

<div align="center">

**Made with ❤️ by SHADOW HEX ~ REAL**

</div>
