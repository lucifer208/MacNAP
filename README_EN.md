# 💤 MacNAP

**[🇻🇳 Tiếng Việt](README.md) • [🇬🇧 English](README_EN.md)**

> **Fix overnight battery drain on MacBook once and for all.**

I use a MacBook connected to external SSDs, USB hubs, and peripherals. Every night I closed the lid to sleep, only to wake up finding the laptop warm and down 15% – 30% battery (sometimes completely drained) because macOS keeps powering external ports and triggers frequent background DarkWakes.

I built **MacNAP** for myself to solve this exact frustration.

---

## 🎯 3 Core Features

1. **🔌 Auto-Unmount External Drives on Sleep / Lid-Close**
   The moment you close your lid or your Mac enters sleep, MacNAP cleanly unmounts all external drives, putting them into standby so they stop leeching power and preventing *"Disk not ejected properly"* warnings.

2. **⚡️ Auto-Remount on Wake / Lid-Open**
   As soon as you open the lid and log in, MacNAP immediately wakes up the USB controllers and remounts your drives within seconds (with a 1.5s multi-stage retry). You can get straight back to work without unplugging and replugging cables.

3. **🌙 Block DarkWake Battery Drain**
   Stops macOS from quietly waking up all night just to maintain background network packets (`TCPKeepAlive`) on battery. Overnight battery drop stays at 1% – 2%.

*(Bonus: An interactive timeline chart parsed from real `pmset` logs so you can verify overnight battery usage).*

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
