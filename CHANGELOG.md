# Changelog

## [Unreleased] - 2026-10-28

### [10:27] fix: display single-text lightning & plug Watts in MenuBarExtra label
- Sửa lỗi `MenuBarExtra` trên macOS chỉ render phần tử `Text` đầu tiên khi dùng nhiều `Text` trong `HStack`: Gộp thành một `Text("⚡️%.1fW 🔌%.1fW")` duy nhất để hiển thị rõ biểu tượng tia sét (Watt tiêu thụ) và phích cắm sạc (Watt sạc vào) ngay trên thanh Menu Bar.

### [10:24] feat: Sleep Aid interactive timeline from real pmset log, Dock icon fix, Menu Bar In/Out Watts & per-device popup window
- **Phân tích chuẩn từ `pmset -g log` (Loại bỏ dự báo giả định)**:
  - Tự động trích xuất các phiên ngủ thật từ `pmset -g log` (như phiên đêm qua `00:50 → 09:25`: Pin từ `100%` xuống `80%`, mất đúng `-20%`, 29 lần `DarkWake` do `rtc/SleepService`, `wifibt SMC.OutboxNotEmpty` và `ATC0.USBWakeup`, công suất rò trung bình thực tế `2.23 W`).
  - Hiệu chỉnh lại công suất thực tế của từng thiết bị USB (thay vì lấy nguyên trần Max Allocation `896mA`/`496mA`).
- **Biểu đồ tương tác kiểu Sleep Aid theo ngày giờ (`DashboardView.swift`)**:
  - Vẽ đường cong `%` pin thực tế kết hợp các vạch `RuleMark` cam/đỏ tại đúng thời điểm máy bị `DarkWake` / `Wake` trong đêm.
  - Nhấn trực tiếp vào bất kỳ điểm/vạch giờ nào trên biểu đồ sẽ hiện chi tiết nguyên nhân thức (`triggerReason`), thời lượng thức (`secs`), `%` pin lúc đó và dòng `raw pmset log`.
- **Cửa sổ mới (Popup Window) riêng cho từng thiết bị (`DeviceDetailView.swift`)**:
  - Nhấn vào bất kỳ thiết bị nào trong danh sách hoặc từ Menu Bar sẽ mở cửa sổ riêng hiển thị biểu đồ Watts realtime + lịch sử Log của riêng thiết bị đó.
- **Menu Bar & Dock Icon**:
  - Menu Bar hiển thị đồng thời công suất đang tiêu thụ và công suất đang sạc vào (`↓15.4W ↑15.4W`).
  - Gán trực tiếp `NSApplication.shared.applicationIconImage` bằng `SleepingMacIconView.renderDockIcon()` kết hợp `lsregister -f MacNAP.app` để icon Mac ngủ `Zzz` hiện chuẩn trên thanh Dock.

### [10:13] feat: auto-unmount on sleep & instant remount on wake, remove third-party brand, add Sleeping Mac Zzz icon & deep charts/logs
- Thay toàn bộ cơ chế `diskutil eject` bằng `diskutil unmount <partition>` khi gập nắp và `diskutil mount <partition>` khi mở nắp.

### [10:06] feat: init MacNAP native SwiftUI deep Watt profiler
- Đọc trực tiếp `AppleSmartBattery` và `IOUSBHostDevice` qua `IOKit`.
