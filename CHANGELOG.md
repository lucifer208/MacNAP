# Changelog

## [Unreleased] - 2026-10-28

### [10:06] feat: init MacNAP native SwiftUI Jettison clone & deep Watt profiler
- Đọc trực tiếp `AppleSmartBattery` (`PowerTelemetryData`: `SystemLoad`, `SystemPowerIn`, `BatteryPower`) và `IOUSBHostDevice` (`UsbPowerSinkAllocation` mA * 5V) qua `IOKit` để đo chính xác số Watt tiêu thụ toàn hệ thống và từng thiết bị ngoại vi (USB Hub, NVMe Box RTL9201, bàn phím, chuột).
- Tích hợp `JettisonSleepGuardService` lắng nghe `NSWorkspace.willSleepNotification` tự động eject ổ cứng ngoài (`/dev/disk4` - WORKING 2TB) khi gập nắp máy hoặc bấm Jettison & Sleep ngay.
- Hiển thị biểu đồ `Swift Charts` (Time-series System Load vs Peripherals Watts + BarChart phân bổ công suất từng thiết bị).
- Quét thủ phạm chặn Sleep (`pmset -g assertions` như `coreaudiod`, `sharingd`) và nhật ký `DarkWake`/`Wake` gây rò 20% pin qua đêm kèm lệnh tối ưu `pmset`.
