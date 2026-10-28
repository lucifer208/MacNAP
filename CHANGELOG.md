# Changelog

## [Unreleased] - 2026-10-28

### [10:13] feat: auto-unmount on sleep & instant remount on wake, remove third-party brand, add Sleeping Mac Zzz icon & deep charts/logs
- Thay toàn bộ cơ chế `diskutil eject` bằng `diskutil unmount <partition>` khi gập nắp (`NSWorkspace.willSleepNotification`) và tự động `diskutil mount <partition>` ngay lập tức khi mở nắp (`NSWorkspace.didWakeNotification`) qua `SleepMountGuardService.swift`.
- Xóa toàn bộ tên thương hiệu bên thứ ba khỏi codebase và UI; đổi sang `MacNAP Zzz Guard`.
- Thiết kế icon Mac đi ngủ có mắt nhắm và chữ `Zzz` (`SleepingMacIconView.swift` + generator `scripts/generate_icon.swift` đóng gói `AppIcon.icns` vào `MacNAP.app`).
- Nâng cấp 3 biểu đồ chuyên sâu (`DashboardView.swift`):
  1. Multi-series Realtime Watt Telemetry (Tổng tải hệ thống vs Ngoại vi vs CPU/Core).
  2. Biểu đồ cột đôi so sánh công suất từng thiết bị khi Active Mount vs sau khi Auto-Unmount/Sleep.
  3. Biểu đồ mô phỏng đường cong sụt pin 8 tiếng qua đêm (Không bảo vệ vs Bật MacNAP Auto-Unmount).
- Nâng cấp trình phân tích `pmset` Power Log có bộ lọc theo danh mục (`Sleep`, `DarkWake`, `Wake`, `Assertions`), ô tìm kiếm process/lý do, ước tính số Watt hao phí của từng sự kiện và bảng lịch sử Auto-Unmount/Remount theo thời gian thực.

### [10:06] feat: init MacNAP native SwiftUI deep Watt profiler
- Đọc trực tiếp `AppleSmartBattery` (`PowerTelemetryData`: `SystemLoad`, `SystemPowerIn`, `BatteryPower`) và `IOUSBHostDevice` (`UsbPowerSinkAllocation` mA * 5V) qua `IOKit`.
