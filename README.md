# 💤 MacNAP

**[🇻🇳 Tiếng Việt](README.md) • [🇬🇧 English](README_EN.md)**

> **Ứng dụng trị dứt điểm chứng hao pin qua đêm trên MacBook.**

Tôi dùng MacBook cắm USB Hub, chuột bàn phím và ổ cứng ngoài SSD. Cứ tối gập nắp đi ngủ là sáng dậy thấy máy nóng ran, pin tụt 15% – 30%, nhiều hôm cạn sạch pin sập nguồn vì macOS vẫn tiếp tục cấp điện cho cổng Type-C và liên tục thức ngầm (DarkWake).

Tôi viết ra **MacNAP** cho chính mình để chấm dứt tình trạng khó chịu này.

---

## 🎯 3 Tính năng cốt lõi

1. **🔌 Tự ngắt ổ cứng ngoài khi Sleep / Gập nắp (Auto-Unmount)**
   Ngay khi bạn gập nắp máy hoặc máy vào Sleep, MacNAP tự động unmount toàn bộ ổ cứng ngoài, đưa ổ đĩa về trạng thái nghỉ (Standby) để ngắt dòng điện rò rỉ và triệt tiêu thông báo phiền phức *"Disk not ejected properly"*.

2. **⚡️ Tự gắn lại ổ cứng khi Mở nắp / Thức dậy (Auto-Remount)**
   Vừa mở nắp máy và đăng nhập, MacNAP tự động đánh thức controller và mount lại toàn bộ ổ cứng ngoài trong tích tắc (có cơ chế quét đệm sau 1.5s). Bạn tiếp tục làm việc bình thường mà không cần rút cắm lại dây cáp.

3. **🌙 Chặn thức ngầm DarkWake khi chạy Pin**
   Vô hiệu hóa việc macOS âm thầm thức máy nửa đêm để gửi nhận gói tin mạng Wi-Fi/Bluetooth vô nghĩa (`TCPKeepAlive`). Pin để qua đêm chỉ mất 1% – 2%.

*(Kèm theo: Biểu đồ theo dõi từng phiên ngủ từ log hệ thống `pmset` để bạn tự kiểm chứng số % pin thực tế).*

---

## 📥 Tải về & Cài đặt

1. Vào mục [**Releases**](https://github.com/lucifer208/MacNAP/releases/latest) tải file **`MacNAP-v1.0.1.dmg`**.
2. Mở file DMG, kéo icon **MacNAP** vào thư mục **Applications**.
3. Mở app lần đầu: MacNAP chạy gọn gàng trên thanh Menu Bar.
4. Mọi cơ chế bảo vệ pin đã được kích hoạt sẵn mặc định.

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
- **Ủng hộ tách cà phê (VietQR):**
  - **Ngân hàng:** VPBank
  - **Số tài khoản:** `8888071992`
  - **Chủ tài khoản:** HUYNH TUAN HUY

---

**Giấy phép:** MIT License. Miễn phí và mã nguồn mở trọn đời.
