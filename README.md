<div align="center">

# 🚀 DEBIAN XRDP · FAST EDITION

### Railway par deploy karo · Google Chrome ke saath · Fast Remote Desktop

![Debian](https://img.shields.io/badge/Debian-11_Bullseye-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![XFCE](https://img.shields.io/badge/Desktop-XFCE4-2284F2?style=for-the-badge&logo=xfce&logoColor=white)
![Chrome](https://img.shields.io/badge/Browser-Google_Chrome-4285F4?style=for-the-badge&logo=googlechrome&logoColor=white)
![Railway](https://img.shields.io/badge/Deploy-Railway-0B0D0E?style=for-the-badge&logo=railway&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)

**Developer: SHADOW HEX ~ REAL**

[![Telegram](https://img.shields.io/badge/Telegram-@SHADOW__HEX__REAL-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/SHADOW_HEX_REAL)
[![Channel](https://img.shields.io/badge/Channel-Shadow_Hex_Official-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Shadow_Hex_Official)

</div>

---

## ✨ Features

| | Feature | Details |
|---|---|---|
| 🖥️ | **Full Desktop** | Debian 11 + XFCE4, RDP se direct access |
| 🌐 | **Google Chrome** | Firefox hata diya, Chrome pehle se configured (`--no-sandbox` etc.) |
| ⚡ | **Fast RDP** | Fastpath, compression, `tcp_nodelay`, bade buffers, 16-bit color |
| 🪶 | **Light Image** | `--no-install-recommends`, bina `xfce4-goodies` ke, compositor band |
| 🍷 | **Wine** | Windows `.exe` apps chalane ke liye Wine + wine32 |
| 🔊 | **Audio** | PulseAudio included |
| 🔁 | **Restart Safe** | Purani pid files auto-clean, container restart par crash nahi |

---

## 🔐 Login Details

| Field | Value |
|---|---|
| **Username** | `root` |
| **Password** | `root` |
| **Port** | `3389` (RDP) |
| **Host** | Railway TCP Proxy se milega (neeche step 4) |

> ⚠️ **Security:** `root / root` sabko pata hai. Public deploy karne se pehle password badlo.
> `Dockerfile` me ye line dhundo aur apna strong password likho:
> ```dockerfile
> RUN echo "root:APNA_STRONG_PASSWORD" | chpasswd
> ```

---

## 📁 Files

```
debianxrdp-main/
├── Dockerfile          # Poora setup (Chrome, XFCE, xrdp, tuning)
├── start.sh            # Container start script
├── pulse-client.conf   # Audio config
└── README.md           # Ye file
```

---

## 🚂 Railway Par Deploy Kaise Karein

**1️⃣ GitHub par upload karo**
Is poore folder ki files apni nayi GitHub repository me upload karo (`Dockerfile`, `start.sh`, `pulse-client.conf`, `README.md`).

**2️⃣ Railway par project banao**
[railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo** → apni repo select karo.
Railway `Dockerfile` khud detect karke build shuru kar dega.

**3️⃣ Build complete hone do**
Pehli build me kuch minute lagte hain (Wine aur Chrome bade packages hain). Status **Active / Success** hone tak wait karo.

**4️⃣ TCP Proxy add karo (sabse zaroori)**
Service → **Settings** → **Networking** → **TCP Proxy** → **Add**
Target port me likho:

```
3389
```

Railway aapko aisa address dega:

```
something.proxy.rlwy.net:12345
```

Yehi aapka RDP host aur port hai (port `12345` jaisa alag hoga, `3389` nahi).

---

## 🔌 RDP Se Connect Kaise Karein

Railway ka diya address use karo, jaise `something.proxy.rlwy.net:12345`.

### 🪟 Windows
1. `Win + R` → `mstsc` → Enter
2. **Computer** me `something.proxy.rlwy.net:12345` daalo
3. **Connect** → Username `root`, Password `root`

### 🤖 Android
1. Play Store se **Microsoft Remote Desktop / RD Client** install karo
2. **Add PC** → host aur port daalo (`host:port`)
3. User account: `root` / `root`

### 🍎 Mac / 🐧 Linux
- Mac: **Windows App / Microsoft Remote Desktop**
- Linux: **Remmina** ya `xfreerdp /v:host:port /u:root /p:root`

Login screen par agar **Session** poochhe to **Xorg** select karo.

---

## 🏎️ Aur Zyada Speed Ke Liye Tips

- RDP client me **Experience** → **Low-speed broadband** ya **Modem** choose karo
- Client me **Color depth 16-bit** rakho
- Wallpaper aur animations band rakho
- Railway me service ko zyada **RAM / CPU** do (Chrome RAM kaafi leta hai)
- Quality chahiye to `Dockerfile` me `max_bpp=16` ko `24` kar do (speed thodi kam hogi)

---

## 🐳 Local Docker Par Chalana (Optional)

```bash
docker build -t xrdp .

docker run -d -p 3389:3389 -v xrdp-root-home:/root --name xrdp-root-wine-audio xrdp
```

Phir RDP client me `localhost:3389` par connect karo.

---

## 🛠️ Troubleshooting

| Problem | Solution |
|---|---|
| Build me `404 Not Found` | Debian 11 purana hai, isliye `Dockerfile` apt ko `archive.debian.org` par point karta hai. Latest `Dockerfile` use karo |
| RDP connect nahi ho raha | Railway me **TCP Proxy** (port `3389`) add kiya hai ya nahi check karo |
| Galat port | `3389` nahi, Railway ka diya hua proxy port use karo |
| Chrome crash ho raha hai | Railway plan me RAM badhao |
| Black screen / session band | Disconnect karke dobara login karo, session **Xorg** rakho |
| Login fail | Username `root`, password wahi jo `Dockerfile` me set kiya hai |

---

## 👨‍💻 Developer

<div align="center">

### **SHADOW HEX ~ REAL**

[![Telegram](https://img.shields.io/badge/Contact-@SHADOW__HEX__REAL-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/SHADOW_HEX_REAL)
[![Channel](https://img.shields.io/badge/Join-Shadow_Hex_Official-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Shadow_Hex_Official)

📩 **Telegram:** [@SHADOW_HEX_REAL](https://t.me/SHADOW_HEX_REAL)
📢 **Channel:** [t.me/Shadow_Hex_Official](https://t.me/Shadow_Hex_Official)

*Project pasand aaye to channel join karo aur share karo* ⭐

</div>

---

<div align="center">

**Made with ❤️ by SHADOW HEX ~ REAL**

</div>
