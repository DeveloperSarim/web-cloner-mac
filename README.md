<div align="center">

<img src="docs/icon.png" width="120" alt="Web Cloner icon" />

# Web Cloner

**Free website downloader, site cloner and full-page screenshot tool for macOS.**

Kisi bhi website ko apne Mac par download karein, uska sitemap banayein, ya har page ka screenshot lein — ek clean native app se, bina Terminal chhue.

[![Download](https://img.shields.io/badge/Download-WebCloner.dmg-147470?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/DeveloperSarim/web-cloner-mac/releases/latest/download/WebCloner.dmg)

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?style=flat-square)](#requirements)
[![Universal](https://img.shields.io/badge/binary-Intel%20%2B%20Apple%20Silicon-147470?style=flat-square)](#requirements)
[![Swift](https://img.shields.io/badge/built%20with-SwiftUI-orange?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/DeveloperSarim/web-cloner-mac?style=flat-square&color=147470)](https://github.com/DeveloperSarim/web-cloner-mac/releases/latest)

<img src="docs/screenshot.png" width="820" alt="Web Cloner cloning a website on macOS, showing live page list with status" />

</div>

---

## Web Cloner kya hai

Web Cloner ek **native macOS app** hai jo battle-tested `wget` ko ek modern SwiftUI interface deta hai. Poori website offline save karein, sirf uske pages scan karein, ya har page ka full-page PNG screenshot banayein. Har page live list me apni status ke saath dikhta hai, is liye aapko pata rehta hai kya ho chuka hai aur kya baaki hai.

HTTrack aur command-line `wget --mirror` ka aasan, khoobsurat mac alternative.

## Features

| | |
|---|---|
| 🌐 **Clone website** | Pages, CSS, JavaScript aur images download kar ke offline browsable copy banata hai, links khud convert hote hain |
| 🔍 **Scan only** | Kuch download kiye baghair site ke saare pages discover karta hai |
| 📸 **Screenshots** | Har page ka full-page PNG (1280 / 1440 / 1920 width) |
| 🗺️ **Sitemap generator** | Har job ke baad standard `sitemap.xml` |
| 📊 **Live page list** | Downloading, Done, Failed, Redirect — status, size aur click-to-filter counters |
| ⚙️ **Auto setup** | wget na ho to app khud install kar deti hai, Homebrew ke zariye |
| 🚦 **Speed control** | Polite (rate-limited), Normal ya Fast — block hone se bachne ke liye |
| 🧭 **Depth control** | Poori site ya sirf 1–5 levels |
| 🖥️ **Universal binary** | Intel aur Apple Silicon dono par native |

## Install

### 1. DMG se (recommended)

1. **[WebCloner.dmg download karein](https://github.com/DeveloperSarim/web-cloner-mac/releases/latest/download/WebCloner.dmg)**
2. DMG kholein aur **Web Cloner** ko **Applications** folder par drag karein
3. App kholein. Pehli baar macOS roke to: **right-click → Open → Open**

### 2. wget

App ko `wget` chahiye. Agar mojood na ho to app khud **Setup** card dikhati hai:

- Homebrew mojood hai → **Install wget** button dabayein, app background me `brew install wget` chala deti hai
- Homebrew nahi hai → wahi button Terminal khol kar Homebrew + wget dono install karta hai (wahan apna Mac password dalna hoga)

Manually karna ho to:

```bash
brew install wget
```

### 3. Source se build (optional)

```bash
git clone https://github.com/DeveloperSarim/web-cloner-mac.git
cd web-cloner-mac
./build.sh          # WebCloner.app + WebCloner.dmg banata hai
```

Sirf Xcode Command Line Tools chahiye (`xcode-select --install`). Poora Xcode zaroori nahi.

## Kaise use karein

1. **Address** me website likhein — `example.com` ya poora URL
2. **Save to** se folder chunein
3. **Job** chunein: Clone, Scan ya Screenshot
4. **Start** dabayein aur neeche pages ko live aate dekhein
5. Khatam hone par **Open Folder** ya **Open Website** dabayein

### Options

| Option | Kya karta hai |
|---|---|
| **How deep** | Poori site, ya sirf 1 / 2 / 3 / 5 levels andar tak |
| **Speed** | `Polite` wait + rate limit lagata hai, `Fast` bilkul nahi rukta |
| **Width** | Screenshot ki chaurai: 1280, 1440 ya 1920 px |
| **Images aur media** | Off karein to sirf HTML, CSS, JS — bohot tez aur chhota |
| **sitemap.xml** | Save folder me sitemap likhta hai |
| **robots.txt ignore** | Sirf apni ya allowed sites ke liye |

### Files kahan jati hain

```
<save folder>/
├── example.com/          # cloned site — index.html kholein
│   └── index.html
├── screenshots/          # Screenshot job ke PNGs
└── sitemap.xml           # discovered pages
```

## Requirements

- macOS 13 Ventura ya us se naya
- Intel ya Apple Silicon Mac (universal binary)
- `wget` (app khud install kar sakti hai)

## FAQ

<details>
<summary><strong>Mac par poori website kaise download karein?</strong></summary>

Web Cloner kholein, address likhein, **Clone** chunein aur **Start Cloning** dabayein. App `wget` se site mirror karti hai aur links convert kar deti hai, taake `index.html` internet ke baghair bhi sahi chale.
</details>

<details>
<summary><strong>Kya yeh HTTrack ka alternative hai?</strong></summary>

Haan. Wahi kaam — website mirroring — lekin native macOS interface, live page list, sitemap generator aur built-in screenshots ke saath.
</details>

<details>
<summary><strong>Kya JavaScript se bani sites clone hoti hain?</strong></summary>

`wget` JavaScript run nahi karta, is liye poori tarah client-side rendered sites ka sirf shell milta hai. Aise sites ke liye **Screenshot** job behtar hai — woh asli browser engine (WebKit) use karta hai.
</details>

<details>
<summary><strong>Screenshots kis size ke hote hain?</strong></summary>

Full-page PNG, chuni hui width (1280 / 1440 / 1920) aur poori page height ke saath. Ek job me zyada se zyada 60 pages.
</details>

<details>
<summary><strong>Kya app safe hai? Signed hai?</strong></summary>

App ad-hoc signed hai, Apple notarized nahi. Is liye pehli baar **right-click → Open** karna padta hai. Poora source yahin hai — khud build kar sakte hain.
</details>

## Development

```
Sources/Engine.swift     # wget arguments, output parsing, sitemap, screenshots
Sources/UI.swift         # SwiftUI interface
Sources/makeicon.swift   # app icon generator
Tests/engine/main.swift  # parsing + sitemap checks
Tests/shot/main.swift    # real screenshot check
build.sh                 # universal build + DMG
```

Tests chalayein:

```bash
swiftc Sources/Engine.swift Tests/engine/main.swift -o /tmp/t && /tmp/t
swiftc Sources/Engine.swift Tests/shot/main.swift  -o /tmp/s && /tmp/s
```

## Contributing

Issues aur pull requests welcome hain. Bada change karne se pehle ek issue khol lein.

## License

[MIT](LICENSE) — © 2026 Sarim Yaseen

## Author

**Sarim Yaseen** — [@DeveloperSarim](https://github.com/DeveloperSarim)

<div align="center">
<sub>Agar yeh app kaam aayi to repo ko ⭐ zaroor dein.</sub>
</div>
