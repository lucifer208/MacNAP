# 💤 MacNAP

**[🇻🇳 Tiếng Việt](README.md) • [🇬🇧 English](README_EN.md)**

> **Fix overnight battery drain on MacBook once and for all.**

I use a MacBook connected to external SSDs, USB hubs, and peripherals. Every night I closed the lid to sleep, only to wake up finding the laptop warm and down 15% – 30% battery (sometimes completely drained) because macOS keeps powering external ports and triggers frequent background DarkWakes.

I built **MacNAP** for myself to solve this exact frustration.

---

## ✨ Highlight Features

### 1. 🔌 Auto-Unmount External Drives on Sleep / Lid-Close
The moment you close your lid or your Mac enters sleep, MacNAP cleanly unmounts all external drives, putting them into standby so they stop leeching power and eliminating the annoying *"Disk not ejected properly"* notification.

### 2. ⚡️ 2-Stage Auto-Remount on Wake / Lid-Open
As soon as you open the lid and log in, MacNAP immediately wakes up drive controllers and remounts your drives. A secondary 1.5s background scan ensures even slower USB hubs and SSD enclosures are 100% remounted without unplugging cables.

### 3. 🌙 Block DarkWake Battery Drain
Disables macOS from quietly waking up all night just to maintain background network packets (`tcpkeepalive 0` & `powernap 0`). Overnight battery drop stays at 1% – 2%.

### 4. 🔋 Auto Low Power Mode on Battery Sleep
Automatically engages `pmset -b powermode 1` when the lid closes on battery to force Apple Silicon CPU/GPU cores into minimum power states, eliminating idle leakage. Restores full performance (`powermode 0`) immediately upon wake.

### 5. 🕵️ Sleep Insomnia Hunter & Alert
Detects background processes (Docker, Google Chrome Helper, qBittorrent, audio streams...) that prevent your Mac from sleeping. Dispatches a macOS Notification when you close your lid to prevent your MacBook from running hot in your backpack.

### 6. 🚨 Morning Battery Drain Alert
Upon waking, MacNAP audits the night's sleep session. If the battery drained beyond your budget (default: ≥ 3%), you receive a notification detailing the exact drop and DarkWake count. One click opens the Dashboard to inspect minute-by-minute logs.

### 7. 📊 Real-Time Apple Silicon SMC Power Telemetry (1.0s)
Directly queries Apple Silicon SMC & IOKit hardware sensors every 1.0 second: measures exact charger input (profiling up to 140W fast charge), per-port USB power routing, and visualizes real sleep history from `pmset` logs.

---

## 📥 Download & Install

1. Download **`MacNAP-v1.0.1.dmg`** from [**Releases**](https://github.com/lucifer208/MacNAP/releases/latest).
2. Open the DMG and drag **MacNAP** into **Applications**.
3. Launch MacNAP: it lives quietly in your Menu Bar.
4. All protections are enabled by default.

---

## 🛠️ Build from Source

Requirements: macOS 14.0+ (Apple Silicon M1/M2/M3/M4 or Intel), Xcode 15+.

```bash
git clone https://github.com/lucifer208/MacNAP.git
cd MacNAP
bash scripts/bundle.sh
```

---

## 💖 Author & Support

- **Author:** Huynh Tuan Huy ([@lucifer208](https://github.com/lucifer208))
- **Issues & Feedback:** [GitHub Issues](https://github.com/lucifer208/MacNAP/issues)
- **Buy me a coffee (VietQR):**
  - **Bank:** VPBank
  - **Account Number:** `8888071992`
  - **Account Holder:** HUYNH TUAN HUY

---

**License:** MIT License. Free and open source forever.
