<div align="center">

# 🌐 RAILWAY CHROMIUM · BROWSER ONLY · **TANPA PASSWORD**

### Chromium fullscreen di server · akses lewat **RDP** atau **langsung dari browser (noVNC)**
### Tidak ada login, tidak ada form password — connect, langsung dipakai.

![Debian](https://img.shields.io/badge/Debian-12_Bookworm-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![Chromium](https://img.shields.io/badge/Chromium-Only-4285F4?style=for-the-badge&logo=chromium&logoColor=white)
![No Password](https://img.shields.io/badge/Auth-Tanpa_Password-34A853?style=for-the-badge&logo=keepassxc&logoColor=white)
![noVNC](https://img.shields.io/badge/Web-noVNC-EA4335?style=for-the-badge&logo=html5&logoColor=white)
![Railway](https://img.shields.io/badge/Deploy-Railway-0B0D0E?style=for-the-badge&logo=railway&logoColor=white)

**Developer: SHADOW HEX ~ REAL**

[![Telegram](https://img.shields.io/badge/Telegram-@SHADOW__HEX__REAL-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/SHADOW_HEX_REAL)
[![Channel](https://img.shields.io/badge/Channel-Shadow_Hex_Official-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Shadow_Hex_Official)

</div>

---

## 🚪 Masuk tanpa password

| Cara | Yang terjadi |
|---|---|
| **Web (noVNC)** | Buka domain Railway → klik **Buka Browser** → Chromium langsung muncul di tab. Tidak ada form password. |
| **RDP** | `mstsc` / RD Client / Remmina → connect ke TCP Proxy → **langsung masuk sesi Chromium**, form login xrdp dilewati. Kalau klien tetap minta kredensial, isi apa saja atau `chromium`. |

### Kenapa bisa tanpa password
- Akun sistem `chromium` dibuat dengan password hash `!` → **akun terkunci**, tidak ada password yang bisa dicuri atau ditebak.
- `EnablePAMAuth=false` → xrdp tidak memanggil PAM saat membuat sesi.
- Section `[Xorg]` di `xrdp.ini` memakai `username=chromium` + `password=chromium` tetap (bukan `ask`), dan `[Globals] autorun=Xorg` → **form login xrdp di-skip** ([man page xrdp.ini(5)](https://manpages.debian.org/bookworm/xrdp/xrdp.ini.5.en.html)).
- noVNC/x11vnc jalan **tanpa password VNC** (`-nopw`), dan port VNC hanya listen di `127.0.0.1` — satu-satunya pintu adalah halaman noVNC itu sendiri.

> ⚠️ **Tanpa password = siapa pun yang punya URL/port bisa memakai server ini.**
> Kalau ini menyangkut kuota/billing atau data pribadi, ada dua pengaman opsional yang **tidak membawa balik form password**:
> - `ACCESS_TOKEN=rahasia` → halaman web tetap satu klik, tapi hanya bisa connect dari `/?token=rahasia` (tanpa token, WebSocket ditolak `403`).
> - `AUTH_PROXY=user:pass@host:port` → pakai proxy ber-bayar (mis. IPRoyal, Smartproxy). Autentikasi terjadi di proxy, **bukan di Chromium/RDP** — jadi tidak ada popup password, dan provider proxy yang menanggung reputasi IP.

---

## 🧪 Sudah diuji (bukan mockup)

| | |
|---|---|
| ![Sesi browser](preview/bukti-browser-session.png) | Sesi nyata: **Chromium fullscreen tanpa dekorasi**, halaman ter-render, font Arab/CJK/Rusia normal |
| ![WebGL](preview/bukti-webgl.png) | `get.webgl.org` → "Your browser supports WebGL", kubus 3D ter-render (SwiftShader, tanpa GPU) |
| ![Login noVNC](preview/bukti-novnc-login.png) | Halaman pembuka noVNC — sekarang **tanpa form password** |

Bukti uji mode tanpa password (dijalankan di sandbox):

```
# 1. VNC benar-benar tanpa password -> security type 1 (None) ditawarkan
server banner: RFB 003.008
security types ditawarkan: [1]        # 1 = None (tanpa auth)
SecurityResult: 00000000              # langsung diterima
ServerInit -> framebuffer 1600 x 900  # sesi VNC terbuka tanpa kredensial

# 2. xrdp auto-login (xrdp.ini hasil patch)
autorun=Xorg
[Xorg]
username=chromium
password=chromium                     # tetap, bukan "ask" -> form login di-skip
[Security]
EnablePAMAuth=false                   # akun terkunci tetap bisa buka sesi

# 3. Token opsional (kalau ACCESS_TOKEN diisi)
GET /websockify                -> (ditolak, tidak ada 101)
GET /websockify?token=salah    -> (ditolak)
GET /websockify?token=rahasia123 -> HTTP/1.1 101 Switching Protocols
```

---

## 🎯 Fokus: browser saja

| Ada | Tidak ada |
|---|---|
| Chromium (paket Debian, ikut update security) | ❌ XFCE / panel / Thunar / terminal |
| openbox minimal (jendela penuh, tanpa dekorasi) | ❌ Wine & wine32 |
| WebGL via SwiftShader (tanpa GPU) | ❌ aplikasi office / media player |
| Audio PulseAudio | ❌ compositor, screensaver |
| uBlock Origin (opsional saat build) | ❌ LibreOffice, GIMP, dll |
| Akses **RDP** (3389) **dan Web/noVNC** (8080) | ❌ password / form login |

---

## ⚡ Optimasi (v3)

### 1. Image lebih kecil
| Tindakan | Efek |
|---|---|
| `path-exclude` untuk `/usr/share/doc`, `/man`, `/info`, `/lintian` (copyright tetap) | **−133 MB** |
| Font CJK dipangkas: hanya `NotoSansCJK-Regular/Bold` | **−50 s/d −80 MB** (paket asli 91 MB) |
| `fonts-freefont-ttf` dihapus (sudah tercakup Liberation + DejaVu) | **−6,6 MB** |
| Chromium + chromium-common satu kali `apt` (tak dobel unduh 60 MB+) | layer lebih kecil |
| Build-arg: `WITH_WEB=0`, `WITH_CJK_FONTS=0`, `WITH_UBLOCK=0` | −8 / −80 / −2 MB |

### 2. RAM & CPU lebih hemat
| Tindakan | Efek |
|---|---|
| `MALLOC_ARENA_MAX=2` | RSS turun pada container kecil |
| `--renderer-process-limit=3` (bisa diubah) | jumlah renderer dibatasi |
| `--disable-background-networking`, `--disable-component-update`, `--disable-sync`, `--no-pings` | thread/jaringan latar berhenti |
| `--disk-cache-size=256 MB` + media cache 64 MB | I/O dan mapping RAM turun |
| Profil Chromium di volume `/data` | cache tidak dibangun ulang tiap redeploy |
| `CHROMIUM_LOW_RAM=1` → `--process-per-site --enable-low-end-device-mode` | untuk server 1 vCPU |

### 3. Remote lebih ringan
| Tindakan | Efek |
|---|---|
| x11vnc: `-wait/-defer 40ms`, `-sb 15`, `-speeds lan` (`VNC_SPEED`) | CPU & bandwidth turun saat layar diam |
| VNC hanya `127.0.0.1`, `-norc` | aman + preset konsisten |
| Tunggu jendela Chromium muncul (maks 6 s) sebelum VNC nyala | tidak ada layar hitam |
| `--disable-smooth-scrolling`, sRGB | repaint lebih sedikit |
| `RDP_MAX_BPP=16` (build-arg) | bandwidth ~40% lebih kecil di jaringan jelek |

### 4. Start lebih cepat
| Tindakan | Efek |
|---|---|
| Tanpa `sleep 2`, `tail -F` hanya jika `DEBUG=1` | ~2 s lebih cepat |
| Watchdog 5 s → 3 s, tanpa fork berlebih | reaksi cepat, CPU tetap kecil |
| Port & symlink hanya ditulis kalau perlu, banner 1 baris | entrypoint & log lebih rapi |
| `fc-cache` saat build, `PYTHONDONTWRITEBYTECODE=1` | login pertama tidak menunggu |

---

## ⚙️ Environment Variables

| Variable | Default | Fungsi |
|---|---|---|
| `ACCESS_TOKEN` | – | **Opsional.** Kunci akses: `/?token=RAHASIA`. Tanpa token → connect ditolak |
| `AUTH_PROXY` | – | **Opsional.** `user:pass@host:port` proxy ber-bayar (autentikasi di luar Chromium) |
| `ENABLE_RDP` | `1` | `0` = matikan RDP |
| `ENABLE_WEB` | `1` | `0` = matikan noVNC |
| `RDP_PORT` | `3389` | Port listener xrdp |
| `HTTP_PORT` | `8080` | Port web/noVNC |
| `SCREEN` | `1600x900x24` | Resolusi layar virtual (mode web) |
| `START_URL` | – | Tab pertama, mis. `https://youtube.com` |
| `BROWSER_LANG` | – | Bahasa UI, mis. `id` |
| `CHROMIUM_FLAGS` | – | Flag tambahan, mis. `--incognito` |
| `CHROMIUM_PROXY` | – | Proxy browser biasa (tanpa auth) |
| `CHROMIUM_CACHE_SIZE` | `268435456` | Disk cache (byte) |
| `CHROMIUM_MEDIA_CACHE_SIZE` | `67108864` | Cache media (byte) |
| `CHROMIUM_RENDERER_LIMIT` | `3` | Maks proses renderer |
| `CHROMIUM_LOW_RAM` | `0` | `1` = mode hemat RAM |
| `VNC_SPEED` | `lan` | Preset x11vnc: `lan`/`fast`/`medium`/`slow` |
| `VNC_POLL` | `40` | ms; naikkan untuk CPU lebih hemat |
| `DEBUG` | `0` | `1` = tampilkan log di stdout |

Build args: `WITH_WEB`, `WITH_CJK_FONTS`, `WITH_UBLOCK`, `RDP_MAX_BPP`, dan **`RDP_PAM=1`** (kembali ke mode password/PAM).

---

## 🚂 Deploy ke Railway

1. **Upload semua file** ke repo GitHub.
2. [railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo** → pilih repo. `railway.json` sudah disiapkan.
3. **Tidak perlu Variables** — image sudah tanpa password. (Opsional: `ACCESS_TOKEN`, `START_URL`.)
4. Pilih akses:
   - **Web** → Settings → Networking → **Generate Domain** → target port **`8080`** → buka domain itu.
   - **RDP** → Settings → Networking → **TCP Proxy** → target port **`3389`** → dapat `host.proxy.rlwy.net:12345`.
5. Opsional: mount **Volume** ke `/data` (profil Chromium + Downloads persisten).

---

## 🔌 Cara connect

### 🪟 Windows
`Win + R` → `mstsc` → Computer: `host.proxy.rlwy.net:12345` → **Connect**.
Kalau muncul prompt kredensial (beberapa versi Windows selalu menampilkannya), isi user `chromium`, password bebas — atau klik **Connect** tanpa mengisi apa pun.
Kalau ada peringatan sertifikat → **Yes/Continue**.

### 🤖 Android
**Microsoft Remote Desktop (RD Client)** → **Add PC** → host + port → user `chromium` (password bebas).

### 🍎 Mac / 🐧 Linux
```bash
xfreerdp /v:host.proxy.rlwy.net:12345 /u:chromium /p:x /dynamic-resolution +clipboard
```
Session yang tersedia hanya **Xorg** (sudah otomatis lewat `autorun=Xorg`).

---

## 🐳 Tes lokal

```bash
docker compose up --build -d
```

- Web: <http://localhost:8080>  → klik **Buka Browser** (tanpa password)
- RDP: `localhost:3389` → user `chromium` / password bebas

Manual:

```bash
docker build -t chromium-only .
docker run -d --shm-size=1g -p 8080:8080 -p 3389:3389 -v browser-data:/data chromium-only
```

Mode password (opsional):

```bash
docker build --build-arg RDP_PAM=1 -t chromium-pam .
```

---

## 🔧 Build lebih kecil

```bash
# RDP saja, tanpa noVNC, tanpa font CJK, tanpa uBlock
docker build --build-arg WITH_WEB=0 --build-arg WITH_CJK_FONTS=0 \
             --build-arg WITH_UBLOCK=0 -t chromium-min .

# jaringan jelek: 16-bit colour
docker build --build-arg RDP_MAX_BPP=16 -t chromium-lite .
```

Di Railway: **Settings → Build → Build Args**.

---

## 💡 Tips & batasan

- `SCREEN` turun ke `1280x720x24` kalau bandwidth terbatas (mode web).
- noVNC mengirim gambar layar (bukan video terkompresi seperti RDP) → RDP tetap paling mulus untuk paket besar.
- **Audio hanya di mode RDP** (noVNC tidak meneruskan suara).
- **DRM Widevine** (Netflix/Spotify premium) tidak tersedia di Chromium Debian.
- **WebGL** software rendering — cukup untuk Maps/Figma ringan, bukan game 3D berat.
- **Kamera/mikrofon** tidak ada; bisa dipalsukan `--use-fake-device-for-media-stream`.
- Extension dari Chrome Web Store: pakai **Load unpacked** atau paket `webext-*` dari apt (uBlock Origin sudah tersedia).

---

## 🛠️ Troubleshooting

| Masalah | Solusi |
|---|---|
| Diminta password saat RDP | Isi `chromium` / apa saja, atau kosongkan. Kalau build kamu `--build-arg RDP_PAM=1`, mode password aktif |
| RDP langsung terputus | Pastikan `autorun=Xorg` ada di `xrdp.ini` dan `EnablePAMAuth=false` di `sesman.ini` (`docker exec -it <c> grep -E 'autorun|EnablePAMAuth' /etc/xrdp/*.ini`) |
| Halaman web minta token | `ACCESS_TOKEN` diisi → buka `https://domain/?token=RAHASIA` |
| WebSocket ditolak / layar tidak muncul | Cek `/var/log/web.log`; pastikan domain mengarah ke port `HTTP_PORT` |
| Layar web lambat | `SCREEN=1280x720x24`, `VNC_SPEED=medium`, `VNC_POLL=60` |
| RDP tidak connect | TCP Proxy port `3389` sudah dibuat? Port di klien = port proxy Railway |
| Chromium tidak muncul | `tail /var/log/xrdp-sesman.log`; pastikan `~/.xsession` berisi `browser-session` |
| Tab crash "Aw, Snap" | Tambah RAM / `--shm-size=1g` |
| Download hilang saat redeploy | Mount volume ke `/data` |

Log: `DEBUG=1` lalu lihat stdout Railway, atau `docker exec -it <c> tail -f /var/log/web.log /var/log/xrdp-sesman.log`.

---

## ⚠️ Keamanan (baca ini)

Tanpa password, proteksi satu-satunya adalah **kerahasiaan URL/port**. Railway TCP Proxy bisa dipindai bot, dan domain `*.up.railway.app` mudah ditemukan. Minimal lakukan salah satu:

1. `ACCESS_TOKEN` (paling murah, satu env var), atau
2. `AUTH_PROXY` (proxy ber-bayar, autentikasi di sisi proxy), atau
3. batasi pemakaian di Railway (hapus TCP Proxy kalau hanya butuh mode web + token).

---

## 📁 Struktur

```
Railway-Fast-Rdp/
├── Dockerfile          # Debian 12 + Chromium + xrdp + (noVNC) — tanpa password
├── start.sh            # Entrypoint: akun terkunci, autorun=Xorg, PAM off, watchdog
├── chromium.sh         # Launcher Chromium (WebGL, audio, cache, limit proses)
├── session.sh          # Isi sesi X: openbox + Chromium (browser-only)
├── startwm.sh          # Hook sesi xrdp -> browser-session (+ proxy opsional)
├── web.sh              # Xvfb + x11vnc (tanpa password) + websockify/noVNC
├── novnc-index.html    # Halaman pembuka noVNC (satu klik, tanpa password)
├── openbox-rc.xml      # WM minimal: tanpa dekorasi, selalu maximize
├── tune-ini.sh         # Tuning xrdp.ini & sesman.ini (TLS + speed)
├── pulse-default.pa    # PulseAudio system-wide (suara browser)
├── pulse-client.conf   # Client audio -> /run/pulse/native
├── docker-compose.yml
├── railway.json
└── preview/            # Bukti screenshot
```

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
