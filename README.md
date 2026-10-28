# 💤 MacNAP

**[🇻🇳 Tiếng Việt](README.md) • [🇬🇧 English](README_EN.md)**

> **Ứng dụng trị dứt điểm chứng hao pin qua đêm trên MacBook.**

Tôi dùng MacBook cắm USB Hub, chuột bàn phím và ổ cứng ngoài SSD. Cứ tối gập nắp đi ngủ là sáng dậy thấy máy nóng ran, pin tụt 15% – 30%, nhiều hôm cạn sạch pin sập nguồn vì macOS vẫn tiếp tục cấp điện cho cổng Type-C và liên tục thức ngầm (DarkWake).

Tôi viết ra **MacNAP** cho chính mình để chấm dứt tình trạng khó chịu này.

---

## ✨ Tính năng nổi bật

### 1. 🔌 Tự ngắt ổ ngoài khi Sleep / Gập nắp (Auto-Unmount)
Ngay khi bạn gập nắp máy hoặc máy vào Sleep, MacNAP tự động unmount toàn bộ ổ cứng ngoài, đưa ổ đĩa về trạng thái nghỉ (Standby) để ngắt dòng điện rò rỉ và triệt tiêu hoàn toàn thông báo phiền phức *"Disk not ejected properly"*.

### 2. ⚡️ Tự gắn lại ổ ngoài 2 đợt khi Mở nắp (Auto-Remount)
Vừa mở nắp máy và đăng nhập, MacNAP tự động đánh thức controller ổ đĩa và mount lại toàn bộ ổ cứng ngoài tức thì. Cơ chế quét đệm đợt 2 sau 1.5s đảm bảo mọi USB Hub hay ổ SSD đọc chậm đều được nhận diện 100% mà không cần rút cắm lại cáp.

### 3. 🌙 Chặn thức ngầm DarkWake khi dùng Pin
Vô hiệu hóa việc macOS âm thầm thức máy nửa đêm để gửi nhận gói tin mạng Wi-Fi/Bluetooth vô nghĩa (`tcpkeepalive 0` & `powernap 0`). Pin để qua đêm chỉ tiêu hao 1% – 2%.

### 4. 🔋 Tự động bật Low Power Mode khi Gập nắp trên Pin
Tự động kích hoạt `pmset -b powermode 1` ngay khi gập nắp chạy pin để ép CPU/GPU Apple Silicon về xung nhịp tối thiểu, triệt tiêu điện áp rò rỉ khi máy thức ngầm và tự trả về xung nhịp bình thường (`powermode 0`) ngay khi mở máy.

### 5. 🕵️ Săn "Kẻ trộm giấc ngủ" (Sleep Insomnia Hunter & Alert)
Tự động phát hiện các tiến trình chạy ngầm (Docker, Google Chrome Helper, qBittorrent, luồng âm thanh...) đang cản trở Mac đi ngủ. Bắn macOS Notification cảnh báo ngay khi bạn gập nắp để tránh tình trạng máy chạy ngầm nóng ran trong balo.

### 6. 🚨 Báo động Tụt Pin Sáng Dậy (Morning Drain Alert)
Mỗi sáng mở máy, MacNAP tự động soi phiên ngủ đêm qua. Nếu pin tụt vượt quá hạn mức an toàn (mặc định: ≥ 3%), app sẽ gửi thông báo hệ thống chi tiết số % pin bị tụt và số lần DarkWake. Bấm vào thông báo sẽ mở Dashboard soi biểu đồ từng phút.

### 7. 📊 Biểu đồ Phân tích Pin & Đo công suất SMC thời gian thực (1.0s)
Đọc trực tiếp cảm biến phần cứng Apple Silicon (SMC & IOKit) với chu kỳ 1.0 giây: đo chính xác công suất củ sạc (nhận diện sạc nhanh 140W), công suất từng cổng USB, và biểu đồ Sleep Aid thực tế từ log `pmset`.

---

## 📥 Tải về & Cài đặt

1. Vào mục [**Releases**](https://github.com/lucifer208/MacNAP/releases/latest) tải file **`MacNAP-v1.0.1.dmg`**.
2. Mở file DMG, kéo icon **MacNAP** vào thư mục **Applications**.
3. Mở app lần đầu: MacNAP chạy gọn gàng trên thanh Menu Bar, không chiếm diện tích màn hình.
4. Mọi cơ chế bảo vệ pin cốt lõi đã được bật sẵn mặc định.

---

## 🛠️ Biên dịch từ Mã nguồn

Yêu cầu: macOS 14.0+ (Apple Silicon M1/M2/M3/M4 hoặc Intel), Xcode 15+.

```bash
git clone https://github.com/lucifer208/MacNAP.git
cd MacNAP
bash scripts/bundle.sh
```

---

## 💖 Tác giả & Ủng hộ

- **Tác giả:** Huỳnh Tuấn Huy ([@lucifer208](https://github.com/lucifer208))
- **Báo lỗi & Góp ý:** [GitHub Issues](https://github.com/lucifer208/MacNAP/issues)
- **Ủng hộ Tác giả tách cà phê (VietQR):**
  - **Ngân hàng:** VPBank
  - **Số tài khoản:** `8888071992`
  - **Chủ tài khoản:** HUYNH TUAN HUY

---

**Giấy phép:** MIT License. Miễn phí và mã nguồn mở trọn đời.
