# Changelog

## [Unreleased] - 2026-10-28

### [10:40] fix: move all pmset & diskutil subprocesses off MainActor to eliminate UI freeze
- **Triệt tiêu hoàn toàn hiện tượng đơ/freeze app khi đọc `pmset` & `diskutil` (`AppState.swift` & `SleepMountGuardService.swift`)**:
  - Đưa toàn bộ lệnh `pmset -g log`, `pmset -g assertions`, `diskutil list -plist` và `diskutil mount/unmount` sang `Task.detached(priority: .utility)` chạy ngầm ngoài luồng giao diện (`@MainActor`).
  - Đổi thứ tự `readDataToEndOfFile()` trước `waitUntilExit()` để tránh kẹt pipe buffer (deadlock) khi output của `pmset` lớn.
  - Gộp 2 lần gọi `pmset -g log` thành 1 lần duy nhất (`loadAllPmsetLogData`) và thêm trạng thái `ProgressView` ("Đang đọc log...") trên nút bấm.

### [10:36] feat: use SystemTotal vs DCIn and switch to monochrome SF Symbols & Dock/Menu Bar icons
- Đổi sang chuẩn đo **System Total** (`SystemEnergyConsumed` ~ 6.8W) và **DC In** (`SystemVoltageIn * SystemCurrentIn` ~ 24.7W).
- Thay toàn bộ emoji màu (`⚡️`, `🔌`, `🖨️`, `🌙`) và icon màu loè loẹt bằng **SF Symbols đơn sắc (monochrome)** (`bolt.fill`, `powerplug.fill`).
- Vẽ trực tiếp `NSImage(isTemplate: true)` trên Menu Bar gồm SF Symbol tia sét + Watt tiêu thụ và SF Symbol phích cắm + Watt DC In.
- Thiết kế lại icon App/Dock/Header sang phong cách Dark/Silver monochrome tối giản hiện đại.

### [10:32] fix: accurate SystemEnergyConsumed & Battery Charging Watts + predicted % battery saved with MacNAP
- **Sửa công suất tiêu thụ thực & công suất đang sạc vào Pin (`PowerTelemetryService.swift`)**:
  - Đọc `SystemEnergyConsumed` (mW) làm công suất tiêu thụ thực của máy (`~6.5W - 9W`), tách biệt với `SystemPowerIn` (tổng nguồn củ sạc PD cấp) và `InstantAmperage * Voltage` (công suất thực nạp vào viên pin: `0.00 W (Giữ Pin)` khi macOS bật Bypass ở `90%` pin, hoặc `+W` khi đang sạc).
- **Hiển thị rõ dự đoán `%` pin khi dùng MacNAP (`AppState.swift` & `DashboardView.swift`)**:
  - Thêm thẻ KPI **"Dự đoán % Pin khi dùng MacNAP"** và vẽ trực tiếp 2 đường dự đoán trên biểu đồ phiên ngủ:
    1. **Bật Auto-Unmount ổ ngoài**: Giảm hao phí từ `-20%` xuống chỉ còn **`~ -7.9%`** (tiết kiệm `+12%` pin).
    2. **Bật Auto-Unmount + Tắt DarkWake**: Giảm xuống chỉ còn **`~ -3.1%`** (giữ lại `~97%` pin sau 10.6h ngủ).

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
