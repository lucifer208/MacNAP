# ⚡️ MacNAP (v1.0.0)

> **Giải pháp tối ưu năng lượng & trị dứt điểm chứng tụt pin qua đêm cho MacBook.**  
> Tự động **Unmount** an toàn toàn bộ ổ cứng ngoài khi Gập máy / Đi ngủ (Sleep / Lid Close) và **Tự động Remount** ngay khi Mở nắp máy (Wake / Lid Open).

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma%20%2F%20Sequoia)-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10%20%2F%206.0-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20Swift%20Charts-007AFF?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![Release](https://img.shields.io/badge/Release-v1.0.0-success?style=flat-square)](https://github.com/lucifer208/MacNAP/releases/tag/v1.0.0)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

---

## 🎯 Vấn đề & Giải pháp

### ❌ Vấn đề
Khi sử dụng MacBook cắm thêm ổ cứng gắn ngoài (NVMe SSD, SATA SSD, HDD di động, USB Hub, Docking Station...):
1. Khi **gập màn hình (Close Lid)** hoặc máy chuyển sang chế độ **Sleep**, macOS vẫn tiếp tục cấp nguồn điện cho cổng Type-C/Thunderbolt.
2. Các ổ cứng ngoài và chip controller liên tục giữ kết nối, tiêu thụ điện năng âm thầm qua đêm từ **15% đến 40% pin**.
3. Rủi ro ngắt cáp đột ngột gây hư hỏng phân vùng dữ liệu và chai pin MacBook nhanh chóng.

### ✅ Giải pháp từ MacNAP
- **🛡️ Auto-Unmount siêu tốc**: Bắt sự kiện hệ thống `NSWorkspace.willSleepNotification` và trạng thái `ClamshellSleep` để unmount an toàn toàn bộ ổ cứng ngoài trước khi máy chìm vào giấc ngủ sâu.
- **⚡️ Auto-Remount thông minh**: Khi người dùng mở nắp máy hoặc nhấn phím thức giấc (`NSWorkspace.didWakeNotification`), MacNAP tự động dò tìm và mount lại đúng các ổ cứng đã ngắt trước đó chỉ trong tích tắc.
- **📈 Đo công suất thời gian thực (1.0s Telemetry)**: Đọc trực tiếp cảm biến **Apple SMC** (System Management Controller) và **IOKit Battery Power Service** để hiển thị công suất tiêu thụ thực tế (Watts), dòng điện (Amps), điện áp (Volts), nhiệt độ CPU & Pin.
- **🔌 Hardware Profiler chuyên sâu**: Tự động nhận diện công suất bộ sạc tối đa (ví dụ củ sạc Apple **140W USB-C GaN**), trạng thái sạc nhanh (Fast Charge) và dòng điện nạp/xả.
- **🛑 Truy lùng tiến trình chặn Sleep**: Liệt kê chi tiết các ứng dụng hoặc background daemon đang ngăn macOS đi ngủ (`pmset -g assertions`).

---

## ✨ Tính năng nổi bật

| Tính năng | Chi tiết |
| :--- | :--- |
| **Bảo vệ Ổ cứng Ngoài** | Unmount an toàn khi Sleep, tự mount lại khi Wake, loại trừ ổ đĩa hệ thống Time Machine hoặc ổ mạng. |
| **Telemetry Điện năng 1.0s** | Đo chính xác công suất (Watts) tiêu thụ tức thì, hiển thị biểu đồ động trực quan bằng Swift Charts. |
| **Phân tích Củ sạc 140W** | Nhận diện củ sạc chính hãng, công suất danh định, dòng sạc thực tế và phần trăm pin còn lại. |
| **Menu Bar Tiện dụng** | Truy cập nhanh mọi thông số ngay trên thanh trạng thái macOS mà không chiếm diện tích màn hình. |
| **Trung tâm Cập nhật** | Kiểm tra cập nhật trực tiếp từ GitHub Releases, hỗ trợ bật/tắt tự động kiểm tra và cài đặt bản mới. |
| **Báo cáo Lỗi 1 Chạm** | Tự động tổng hợp thông số máy, chip Apple Silicon, phiên bản macOS và log chẩn đoán điền sẵn vào GitHub Issues. |
| **Ủng hộ Tác giả (VietQR)** | Tích hợp mã VietQR chuẩn ngân hàng VPBank, quét mã bằng bất kỳ app ngân hàng nào để chuyển khoản ủng hộ. |

---

## 📥 Cài đặt

### Cách 1: Tải file `.dmg` (Khuyên dùng)
1. Tải bản phát hành mới nhất từ [GitHub Releases](https://github.com/lucifer208/MacNAP/releases/latest):
   - **File cài đặt macOS**: [`MacNAP-v1.0.0.dmg`](https://github.com/lucifer208/MacNAP/releases/download/v1.0.0/MacNAP-v1.0.0.dmg)
2. Mở file `.dmg` vừa tải về.
3. Kéo thả icon **MacNAP** vào thư mục **Applications**.
4. Mở app từ Applications hoặc Spotlight (Cmd + Space gõ `MacNAP`).

### Cách 2: Tải gói ZIP (.zip)
- Bản ứng dụng đóng gói sẵn: [`MacNAP-v1.0.0.zip`](https://github.com/lucifer208/MacNAP/releases/download/v1.0.0/MacNAP-v1.0.0.zip)
- Gói toàn bộ mã nguồn: [`MacNAP-v1.0.0-source.zip`](https://github.com/lucifer208/MacNAP/releases/download/v1.0.0/MacNAP-v1.0.0-source.zip)

---

## 🛠️ Biên dịch & Đóng gói từ Mã nguồn

### Yêu cầu hệ thống
- **Hệ điều hành**: macOS 14.0 (Sonoma) hoặc macOS 15.0+ (Sequoia).
- **Công cụ phát triển**: Xcode 15.0+ hoặc Swift Toolchain 5.10+.
- **Kiến trúc**: Tối ưu hoá cho Apple Silicon (M1/M2/M3/M4/Pro/Max) và tương thích Intel x86_64.

### Các bước biên dịch
```bash
# 1. Clone repository
git clone git@github.com:lucifer208/MacNAP.git
cd MacNAP

# 2. Chạy script đóng gói tự động (tạo App, DMG, Zip & Source Zip)
bash scripts/bundle.sh
```

Sau khi chạy xong, các tệp đóng gói sẽ nằm trong thư mục `releases/`:
- `MacNAP.app`: Ứng dụng hoàn chỉnh có icon native.
- `releases/MacNAP-v1.0.0.dmg`: Tệp đĩa cài đặt kéo thả vào `/Applications`.
- `releases/MacNAP-v1.0.0.zip`: Tệp nén ứng dụng.
- `releases/MacNAP-v1.0.0-source.zip`: Gói mã nguồn sạch.

---

## 📂 Cấu trúc Dự án

```text
MacNAP/
├── Sources/
│   └── MacNAP/
│       ├── main.swift                     # Entry point & vòng đời NSApplication
│       ├── AppState.swift                 # Quản lý State toàn cục & Preferences
│       ├── DriveLifecycleManager.swift    # Lắng nghe Sleep/Wake & Unmount/Remount ổ đĩa
│       ├── PowerTelemetryService.swift    # Đo công suất (W), pin, củ sạc 140W qua IOKit
│       ├── SMCReader.swift                # Giao tiếp cảm biến phần cứng qua AppleSMC
│       ├── DashboardView.swift            # Cửa sổ Dashboard chính & biểu đồ Swift Charts
│       ├── MenuBarPopoverView.swift       # Popover thanh Menu Bar
│       ├── StatusBarController.swift      # Quản lý icon trên thanh trạng thái macOS
│       ├── AppUpdateAndDonateService.swift# Tự động cập nhật, Báo lỗi GitHub & VietQR Donate
│       ├── AppDiagnosticLogger.swift      # Bộ ghi log chẩn đoán chống crash
│       └── Localization.swift             # Hỗ trợ đa ngôn ngữ (Tiếng Việt & English)
├── scripts/
│   ├── bundle.sh                          # Script build release, tạo DMG và đóng gói ZIP
│   └── generate_icon.swift                # Sinh bộ icon chuẩn macOS từ mã nguồn
├── releases/                              # Thư mục chứa file DMG, ZIP và manifest
│   ├── MacNAP-v1.0.0.dmg
│   ├── MacNAP-v1.0.0.zip
│   ├── MacNAP-v1.0.0-source.zip
│   └── latest.json
├── Package.swift                          # Định nghĩa Swift Package Manager
└── README.md
```

---

## 💖 Ủng hộ Tác giả

Nếu **MacNAP** hữu ích và giúp MacBook của bạn trị dứt điểm tình trạng tụt pin qua đêm, bạn có thể ủng hộ tác giả một ly cà phê qua tài khoản:

- **Ngân hàng**: `VPBank` (Ngân hàng TMCP Việt Nam Thịnh Vượng)
- **Số tài khoản (STK)**: `8888071992`
- **Chủ tài khoản**: `HUỲNH TUẤN HUY`
- **Nội dung chuyển khoản**: `MacNAP Donate`

Hoặc quét mã **VietQR** trực tiếp ngay trong ứng dụng tại mục **Ủng hộ**.

---

## 📄 Bản quyền (License)

Dự án được phân phối dưới giấy phép **MIT License**. Xem chi tiết tại [LICENSE](LICENSE).  
Phát triển bởi **Huỳnh Tuấn Huy** ([@lucifer208](https://github.com/lucifer208)).
