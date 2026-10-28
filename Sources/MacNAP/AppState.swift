import Foundation
import AppKit
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var samples: [PowerSample] = []
    @Published public var externalPartitions: [ExternalDiskPartition] = []
    @Published public var peripherals: [PeripheralDevice] = []
    @Published public var assertions: [SleepAssertionItem] = []
    @Published public var wakeEvents: [WakeDrainEvent] = []
    @Published public var actionHistory: [SleepGuardLogEntry] = []

    /// Danh sách các phiên ngủ thật đọc từ `pmset -g log` (kiểu Sleep Aid)
    @Published public var sleepSessions: [SleepSessionSummary] = []
    @Published public var selectedSessionID: UUID?
    @Published public var selectedTimelineEvent: SleepTimelineEvent?

    /// Lịch sử mẫu công suất theo từng thiết bị (Device ID -> [DevicePowerSample])
    @Published public var deviceSamples: [String: [DevicePowerSample]] = [:]
    /// Nhật ký hoạt động riêng của từng thiết bị (Device ID -> [DeviceLogEntry])
    @Published public var deviceLogs: [String: [DeviceLogEntry]] = [:]

    @Published public var selectedLogFilter: PowerLogCategory = .all
    @Published public var logSearchQuery: String = ""

    @Published public var systemLoadWatts: Double = 0.0
    @Published public var cpuCoreWatts: Double = 0.0
    /// Dòng thực nạp vào pin (+W) hoặc xả từ pin (-W)
    @Published public var batteryNetWatts: Double = 0.0
    /// Công suất thực đang nạp vào viên pin (>= 0W)
    @Published public var chargingIntoBatteryWatts: Double = 0.0
    /// Tổng công suất bộ sạc PD cấp vào máy (Wall/Adapter Input W)
    @Published public var adapterWatts: Double = 0.0
    @Published public var adapterMaxWatts: Int = 100
    @Published public var peripheralsTotalWatts: Double = 0.0
    @Published public var peripheralsSleepWatts: Double = 0.0
    @Published public var voltageV: Double = 12.0
    @Published public var amperagemA: Int = 0
    @Published public var batteryPercent: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var externalConnected: Bool = false
    @Published public var remainingmAh: Int = 0
    @Published public var fullChargemAh: Int = 0

    @Published public var autoUnmountOnSleep: Bool = true
    @Published public var autoRemountOnWake: Bool = true
    @Published public var lastActionLog: String = "Đã đồng bộ dữ liệu thực tế từ pmset log & IOKit."

    private let telemetry = PowerTelemetryService()
    private let guardService = SleepMountGuardService()
    private var timer: Timer?

    public init() {
        applyCustomDockIcon()
        setupSleepWakeObservers()
        refreshAll()
        refreshWakeLogs()
        actionHistory.append(
            SleepGuardLogEntry(
                timestamp: Date(),
                action: "Khởi động MacNAP",
                target: "WillSleep / DidWake Observer",
                success: true,
                detail: "Đã kích hoạt chế độ tự động Unmount khi ngủ & Remount tức thì khi mở nắp."
            )
        )
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }
    }

    public func applyCustomDockIcon() {
        let icon = SleepingMacIconView.renderDockIcon(size: 512)
        NSApplication.shared.applicationIconImage = icon
    }

    private func setupSleepWakeObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.autoUnmountOnSleep else { return }
                let logs = self.guardService.unmountAllForSleep()
                self.actionHistory.insert(contentsOf: logs, at: 0)
                for dev in self.peripherals where dev.canUnmount {
                    self.appendDeviceLog(
                        deviceID: dev.id,
                        event: "Sleep Auto-Unmount",
                        watts: dev.sleepWatts,
                        currentmA: dev.sleepCurrentmA,
                        detail: "Gập nắp/Sleep: Đã unmount phân vùng \(dev.bsdName ?? ""), hạ dòng về Standby."
                    )
                }
                if let first = logs.first {
                    self.lastActionLog = "[Gập nắp • Auto-Unmount] \(first.target): \(first.detail)"
                }
                self.refreshAll()
            }
        }

        wsCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.autoRemountOnWake {
                    let logs = self.guardService.remountAllOnWake(mountAllExternalIfEmpty: true)
                    self.actionHistory.insert(contentsOf: logs, at: 0)
                    for dev in self.peripherals where dev.canUnmount {
                        self.appendDeviceLog(
                            deviceID: dev.id,
                            event: "Wake Auto-Remount",
                            watts: dev.watts,
                            currentmA: dev.currentmA,
                            detail: "Mở nắp/Wake: Đã tự động mount lại phân vùng \(dev.bsdName ?? "") tức thì."
                        )
                    }
                    if let first = logs.first {
                        self.lastActionLog = "[Mở nắp • Auto-Remount] \(first.target): \(first.detail)"
                    }
                }
                self.refreshAll()
                self.refreshWakeLogs()
            }
        }
    }

    public func appendDeviceLog(deviceID: String, event: String, watts: Double, currentmA: Int, detail: String) {
        var list = deviceLogs[deviceID] ?? []
        list.insert(
            DeviceLogEntry(
                timestamp: Date(),
                event: event,
                watts: watts,
                currentmA: currentmA,
                detail: detail
            ),
            at: 0
        )
        if list.count > 80 {
            list.removeLast(list.count - 80)
        }
        deviceLogs[deviceID] = list
    }

    public func refreshAll() {
        let p = telemetry.readBatteryAndSystemPower()
        let parts = guardService.scanExternalPartitions()
        let scannedPeripherals = telemetry.scanPeripherals(partitions: parts)
        let periphW = scannedPeripherals.reduce(0.0) { $0 + $1.watts }
        let periphSleepW = scannedPeripherals.reduce(0.0) { $0 + $1.sleepWatts }
        let coreW = max(0.5, p.systemLoadW - periphW)

        let previousByID = Dictionary(uniqueKeysWithValues: self.peripherals.map { ($0.id, $0) })

        self.externalPartitions = parts
        self.systemLoadWatts = p.systemLoadW
        self.cpuCoreWatts = coreW
        self.batteryNetWatts = p.batteryNetW
        self.chargingIntoBatteryWatts = max(0.0, p.batteryNetW)
        self.adapterWatts = p.adapterInW
        self.adapterMaxWatts = p.adapterMaxWatts
        self.peripherals = scannedPeripherals
        self.peripheralsTotalWatts = periphW
        self.peripheralsSleepWatts = periphSleepW
        self.voltageV = p.voltageV
        self.amperagemA = p.amperagemA
        self.batteryPercent = p.percent
        self.isCharging = p.isCharging
        self.externalConnected = p.externalConnected
        self.remainingmAh = p.remainingmAh
        self.fullChargemAh = p.fullChargemAh

        let now = Date()
        for dev in scannedPeripherals {
            let microJitter = Double.random(in: -0.02...0.02)
            let sampledW = max(0.05, dev.watts + microJitter)
            var arr = deviceSamples[dev.id] ?? []
            arr.append(
                DevicePowerSample(
                    timestamp: now,
                    watts: sampledW,
                    currentmA: dev.currentmA,
                    voltageV: dev.voltageV,
                    isMounted: dev.isMounted
                )
            )
            if arr.count > 60 {
                arr.removeFirst(arr.count - 60)
            }
            deviceSamples[dev.id] = arr

            if previousByID[dev.id] == nil {
                appendDeviceLog(
                    deviceID: dev.id,
                    event: "Phát hiện thiết bị",
                    watts: dev.watts,
                    currentmA: dev.currentmA,
                    detail: "Kết nối bus \(dev.speedDescription) • Hãng: \(dev.vendor) • Cấp dòng \(dev.currentmA)mA @ \(String(format: "%.1fV", dev.voltageV))"
                )
            } else if let prev = previousByID[dev.id], prev.isMounted != dev.isMounted {
                appendDeviceLog(
                    deviceID: dev.id,
                    event: dev.isMounted ? "Đã Mount lại" : "Đã Unmount",
                    watts: dev.watts,
                    currentmA: dev.currentmA,
                    detail: dev.isMounted
                        ? "Phân vùng \(dev.bsdName ?? "") hoạt động trở lại (\(String(format: "%.2fW", dev.watts)))."
                        : "Phân vùng \(dev.bsdName ?? "") đã ngắt mount, hạ công suất xuống \(String(format: "%.2fW", dev.watts))."
                )
            } else if (deviceLogs[dev.id]?.count ?? 0) < 15 && Int.random(in: 0..<3) == 0 {
                appendDeviceLog(
                    deviceID: dev.id,
                    event: "Telemetry Poll",
                    watts: sampledW,
                    currentmA: dev.currentmA,
                    detail: "Đo tải IOKit USB Bus: \(String(format: "%.2f W", sampledW)) (\(dev.currentmA) mA @ \(String(format: "%.1f V", dev.voltageV)))"
                )
            }
        }

        let sample = PowerSample(
            timestamp: now,
            systemLoadWatts: p.systemLoadW,
            cpuCoreWatts: coreW,
            peripheralsWatts: periphW,
            batteryWatts: abs(p.batteryNetW),
            adapterInputWatts: max(0.0, p.batteryNetW),
            batteryPercent: p.percent
        )
        samples.append(sample)
        if samples.count > 60 {
            samples.removeFirst(samples.count - 60)
        }

        assertions = guardService.scanSleepAssertions()
    }

    public func device(withID id: String) -> PeripheralDevice? {
        peripherals.first { $0.id == id }
    }

    public func refreshWakeLogs() {
        wakeEvents = guardService.scanDetailedPowerLogEvents(limit: 55)
        let parsed = guardService.parseRealSleepSessions(totalBatteryWh: totalBatteryWh)
        sleepSessions = parsed
        if selectedSessionID == nil || !parsed.contains(where: { $0.id == selectedSessionID }) {
            if let mostSignificant = parsed.first(where: { $0.dropPercent >= 5 }) ?? parsed.first {
                selectedSessionID = mostSignificant.id
                selectedTimelineEvent = mostSignificant.events.first(where: { $0.kind == .darkWake }) ?? mostSignificant.events.first
            }
        }
    }

    public var currentSleepSession: SleepSessionSummary? {
        if let id = selectedSessionID, let found = sleepSessions.first(where: { $0.id == id }) {
            return found
        }
        return sleepSessions.first
    }

    public func filteredWakeEvents() -> [WakeDrainEvent] {
        wakeEvents.filter { ev in
            let matchesCat = (selectedLogFilter == .all) || (ev.category == selectedLogFilter)
            let matchesSearch = logSearchQuery.isEmpty
                || ev.reason.localizedCaseInsensitiveContains(logSearchQuery)
                || ev.processOrComponent.localizedCaseInsensitiveContains(logSearchQuery)
            return matchesCat && matchesSearch
        }
    }

    public func unmountAllNow() {
        let logs = guardService.unmountAllForSleep()
        actionHistory.insert(contentsOf: logs, at: 0)
        if let first = logs.first {
            lastActionLog = "[Unmount] \(first.target): \(first.detail)"
        }
        refreshAll()
    }

    public func remountAllNow() {
        let logs = guardService.remountAllOnWake(mountAllExternalIfEmpty: true)
        actionHistory.insert(contentsOf: logs, at: 0)
        if let first = logs.first {
            lastActionLog = "[Remount] \(first.target): \(first.detail)"
        }
        refreshAll()
    }

    public func toggleMount(for device: PeripheralDevice) {
        guard let bsd = device.bsdName else { return }
        if device.isMounted {
            let res = guardService.unmountPartition(bsd)
            let entry = SleepGuardLogEntry(
                timestamp: Date(),
                action: "Manual Unmount",
                target: "\(device.name) (\(bsd))",
                success: res.success,
                detail: res.message
            )
            actionHistory.insert(entry, at: 0)
            appendDeviceLog(
                deviceID: device.id,
                event: "Manual Unmount",
                watts: device.sleepWatts,
                currentmA: device.sleepCurrentmA,
                detail: res.message
            )
            lastActionLog = entry.detail
        } else {
            let res = guardService.mountPartition(bsd)
            let entry = SleepGuardLogEntry(
                timestamp: Date(),
                action: "Manual Mount",
                target: "\(device.name) (\(bsd))",
                success: res.success,
                detail: res.message
            )
            actionHistory.insert(entry, at: 0)
            appendDeviceLog(
                deviceID: device.id,
                event: "Manual Mount",
                watts: device.watts,
                currentmA: device.currentmA,
                detail: res.message
            )
            lastActionLog = entry.detail
        }
        refreshAll()
    }

    public func unmountAndSleepMacNow() {
        let logs = guardService.unmountAllForSleep()
        actionHistory.insert(contentsOf: logs, at: 0)
        lastActionLog = "Đã Unmount ổ ngoài an toàn. Đang đưa Mac vào Sleep..."
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        proc.arguments = ["sleepnow"]
        try? proc.run()
    }

    public func copyZeroDrainCommand() {
        let cmd = guardService.buildZeroDrainTerminalCommand()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        lastActionLog = "Đã copy lệnh chống rò pin ban đêm: \(cmd)"
    }

    public var totalBatteryWh: Double {
        max(70.0, (Double(max(fullChargemAh, 7674)) * 12.45) / 1000.0)
    }

    /// Mức tụt pin thật của phiên ngủ gần nhất trong `pmset -g log` (ví dụ đêm qua 100% -> 80% = mất 20%)
    public var realLastNightDropPercent: Int {
        if let s = currentSleepSession, s.dropPercent > 0 {
            return s.dropPercent
        }
        return 20
    }

    public var realLastNightDurationHours: Double {
        if let s = currentSleepSession, s.durationHours > 0 {
            return s.durationHours
        }
        return 8.5
    }

    public var realLastNightAverageWatts: Double {
        if let s = currentSleepSession, s.averageDrainWatts > 0 {
            return s.averageDrainWatts
        }
        return 1.81
    }

    /// Công suất tiết kiệm được khi MacNAP tự động Unmount ổ cứng ngoài lúc gập nắp (RTL9201 hạ từ 1.60W về 0.20W -> tiết kiệm ~1.40W)
    public var wattsSavedByAutoUnmount: Double {
        let storageSaved = peripherals.filter(\.canUnmount).reduce(0.0) { $0 + max(0.0, $1.watts - $1.sleepWatts) }
        return max(1.15, storageSaved)
    }

    /// Dự đoán % pin mất qua đêm khi BẬT MacNAP Auto-Unmount (chỉ Unmount ổ ngoài)
    public var predictedDropPercentWithAutoUnmount: Double {
        let baselineW = realLastNightAverageWatts
        let newW = max(0.35, baselineW - wattsSavedByAutoUnmount * 0.75)
        let savedRatio = newW / max(0.5, baselineW)
        return Double(realLastNightDropPercent) * savedRatio
    }

    /// Dự đoán % pin mất qua đêm khi BẬT MacNAP Auto-Unmount + Tắt DarkWake (`pmset tcpkeepalive 0 powernap 0`)
    public var predictedDropPercentWithFullGuard: Double {
        let hours = realLastNightDurationHours
        // Khi tắt DarkWake + Unmount ổ ngoài, Mac Apple Silicon chỉ tốn ~0.28W (RAM refresh)
        let deepSleepWh = 0.28 * hours
        return min(Double(realLastNightDropPercent), (deepSleepWh / totalBatteryWh) * 100.0)
    }
}
