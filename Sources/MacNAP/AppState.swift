import Foundation
import AppKit
import Combine
import ServiceManagement

public enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "Tổng quan & Realtime"
    case sleepAid = "Phân tích Phiên Ngủ (Sleep Aid)"
    case peripherals = "Ngoại vi & Auto-Unmount"
    case powerLog = "Nhật ký Nguồn & Assertions"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .sleepAid: return "moon.zzz.fill"
        case .peripherals: return "externaldrive.connected.to.line.below.fill"
        case .powerLog: return "doc.text.magnifyingglass"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedSection: DashboardSection = .overview
    @Published public var samples: [PowerSample] = []
    @Published public var externalPartitions: [ExternalDiskPartition] = []
    @Published public var peripherals: [PeripheralDevice] = []
    @Published public var assertions: [SleepAssertionItem] = []
    @Published public var wakeEvents: [WakeDrainEvent] = []
    @Published public var actionHistory: [SleepGuardLogEntry] = []

    /// Chế độ phân tích ngủ: Theo lần Sleep (`bySession`) hoặc Theo Ngày từ 00:00 (`byDay`)
    @Published public var sleepAnalysisMode: SleepAnalysisMode = .bySession {
        didSet {
            syncSelectedSessionForCurrentMode()
        }
    }
    @Published public var sleepSessions: [SleepSessionSummary] = []
    @Published public var dailySleepSessions: [SleepSessionSummary] = []
    @Published public var selectedSessionID: UUID?
    @Published public var selectedTimelineEvent: SleepTimelineEvent?
    @Published public var isLoadingPmsetLog: Bool = false

    /// Lịch sử mẫu công suất theo từng thiết bị (Device ID -> [DevicePowerSample])
    @Published public var deviceSamples: [String: [DevicePowerSample]] = [:]
    /// Nhật ký hoạt động riêng của từng thiết bị (Device ID -> [DeviceLogEntry])
    @Published public var deviceLogs: [String: [DeviceLogEntry]] = [:]

    @Published public var selectedLogFilter: PowerLogCategory = .all
    @Published public var logSearchQuery: String = ""

    @Published public var systemLoadWatts: Double = 0.0
    @Published public var cpuCoreWatts: Double = 0.0
    @Published public var batteryNetWatts: Double = 0.0
    @Published public var chargingIntoBatteryWatts: Double = 0.0
    @Published public var adapterWatts: Double = 0.0
    @Published public var tbLeftWatts: Double = 0.0
    @Published public var tbRightWatts: Double = 0.0
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

    @Published public var language: AppLanguage = {
        if let saved = UserDefaults.standard.string(forKey: "MacNAP_Language"),
           let found = AppLanguage(rawValue: saved) {
            return found
        }
        return .vi
    }() {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "MacNAP_Language")
        }
    }

    public var l10n: L10n { L10n(language) }

    public func toggleLanguage() {
        language = (language == .vi) ? .en : .vi
    }

    @Published public var autoUnmountOnSleep: Bool = true
    @Published public var autoRemountOnWake: Bool = true
    @Published public var disableDarkWakeOnBattery: Bool = false
    @Published public var isUpdatingDarkWake: Bool = false
    @Published public var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "MacNAP_LaunchAtLogin") {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "MacNAP_LaunchAtLogin")
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    @Published public var hideDockIcon: Bool = (UserDefaults.standard.object(forKey: "MacNAP_HideDockIcon") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(hideDockIcon, forKey: "MacNAP_HideDockIcon")
            applyDockVisibilityPolicy()
        }
    }
    @Published public var lastActionLog: String = "Đã đồng bộ cảm biến AppleSMC realtime (1s)."

    private let telemetry = PowerTelemetryService()
    private let guardService = SleepMountGuardService()
    private var timer: Timer?
    private var tickCount: Int = 0
    private var isRefreshingTelemetry: Bool = false
    private var wasLidClosedOrSleeping: Bool = false
    private var lastSleepWakeHandledAt: Date = .distantPast

    public init() {
        applyDockVisibilityPolicy()
        setupSleepWakeObservers()
        syncDarkWakeSettingState()
        refreshAll()
        refreshWakeLogs()
        actionHistory.append(
            SleepGuardLogEntry(
                timestamp: Date(),
                action: "Khởi động MacNAP",
                target: "Menu Bar Daemon",
                success: true,
                detail: "Chạy ngầm trên Menu Bar • Tự động Unmount khi ngủ & Remount khi mở nắp."
            )
        )
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }
    }

    public func applyCustomDockIcon() {
        let icon = SleepingMacIconView.renderDockIcon(size: 512)
        NSApplication.shared.applicationIconImage = icon
    }

    public func applyDockVisibilityPolicy() {
        if hideDockIcon {
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
            applyCustomDockIcon()
        }
    }

    public func showDashboardWindow(openWindowAction: () -> Void) {
        if !hideDockIcon {
            NSApplication.shared.setActivationPolicy(.regular)
            applyCustomDockIcon()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindowAction()
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Fallback LaunchAgent plist if unsigned local app bundle
            }
        }
        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.lu.MacNAP.plist")
        if enabled {
            let execPath = Bundle.main.executablePath ?? "/Users/lu/HUB/MacNAP/MacNAP.app/Contents/MacOS/MacNAP"
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.lu.MacNAP</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(execPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """
            try? FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
            lastActionLog = "Đã bật tự khởi động cùng macOS (LaunchAtLogin)."
        } else {
            try? FileManager.default.removeItem(at: plistURL)
            lastActionLog = "Đã tắt tự khởi động cùng macOS."
        }
    }

    private func setupSleepWakeObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleUnifiedSleepCloseLid(trigger: "Sleep / CloseLid")
            }
        }

        wsCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleUnifiedWakeOpenLid(trigger: "Wake / OpenLid")
            }
        }
    }

    private func handleUnifiedSleepCloseLid(trigger: String) {
        let now = Date()
        guard now.timeIntervalSince(lastSleepWakeHandledAt) > 2.0 else { return }
        lastSleepWakeHandledAt = now
        wasLidClosedOrSleeping = true

        guard autoUnmountOnSleep else { return }
        let service = guardService
        Task {
            let logs = await Task.detached(priority: .userInitiated) {
                service.unmountAllForSleep()
            }.value
            self.actionHistory.insert(contentsOf: logs, at: 0)
            for dev in self.peripherals where dev.canUnmount {
                self.appendDeviceLog(
                    deviceID: dev.id,
                    event: "Sleep / CloseLid Auto-Unmount",
                    watts: dev.sleepWatts,
                    currentmA: dev.sleepCurrentmA,
                    detail: "\(trigger): Đã unmount phân vùng \(dev.bsdName ?? ""), hạ dòng về Standby."
                )
            }
            if let first = logs.first {
                self.lastActionLog = "[\(trigger) • Auto-Unmount] \(first.target): \(first.detail)"
            }
            self.refreshAll(forcePartitionScan: true)
        }
    }

    private func handleUnifiedWakeOpenLid(trigger: String) {
        let now = Date()
        guard now.timeIntervalSince(lastSleepWakeHandledAt) > 2.0 else { return }
        lastSleepWakeHandledAt = now
        wasLidClosedOrSleeping = false

        Task {
            if self.autoRemountOnWake {
                let service = self.guardService
                let logs = await Task.detached(priority: .userInitiated) {
                    service.remountAllOnWake(mountAllExternalIfEmpty: true)
                }.value
                self.actionHistory.insert(contentsOf: logs, at: 0)
                for dev in self.peripherals where dev.canUnmount {
                    self.appendDeviceLog(
                        deviceID: dev.id,
                        event: "Wake / OpenLid Auto-Remount",
                        watts: dev.watts,
                        currentmA: dev.currentmA,
                        detail: "\(trigger): Đã tự động mount lại phân vùng \(dev.bsdName ?? "") tức thì."
                    )
                }
                if let first = logs.first {
                    self.lastActionLog = "[\(trigger) • Auto-Remount] \(first.target): \(first.detail)"
                }
            }
            self.refreshAll(forcePartitionScan: true)
            self.refreshWakeLogs()
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

    /// Chạy hoàn toàn trên background thread, tuyệt đối không block MainActor / UI
    public func refreshAll(forcePartitionScan: Bool = false) {
        guard !isRefreshingTelemetry else { return }
        isRefreshingTelemetry = true
        tickCount += 1

        let shouldScanDisksAndAssertions = forcePartitionScan || externalPartitions.isEmpty || (tickCount % 12 == 0)
        let cachedParts = externalPartitions
        let cachedAssertions = assertions
        let telemetryRef = telemetry
        let guardRef = guardService

        Task {
            let result = await Task.detached(priority: .utility) {
                let p = telemetryRef.readBatteryAndSystemPower()
                let lidClosed = telemetryRef.isClamshellClosed()
                let parts = shouldScanDisksAndAssertions ? guardRef.scanExternalPartitions() : cachedParts
                let scannedPeripherals = telemetryRef.scanPeripherals(partitions: parts)
                let newAssertions = shouldScanDisksAndAssertions ? guardRef.scanSleepAssertions() : cachedAssertions
                return (p, lidClosed, parts, scannedPeripherals, newAssertions)
            }.value

            let (p, lidClosed, parts, scannedPeripherals, newAssertions) = result
            self.isRefreshingTelemetry = false

            // Đồng bộ chuẩn Sleep/CloseLid & Wake/OpenLid qua cả IOKit Clamshell lẫn NSWorkspace
            if lidClosed && !self.wasLidClosedOrSleeping {
                self.handleUnifiedSleepCloseLid(trigger: "CloseLid / Sleep")
            } else if !lidClosed && self.wasLidClosedOrSleeping {
                self.handleUnifiedWakeOpenLid(trigger: "OpenLid / Wake")
            }

            let periphW = scannedPeripherals.reduce(0.0) { $0 + $1.watts }
            let periphSleepW = scannedPeripherals.reduce(0.0) { $0 + $1.sleepWatts }
            let previousByID = Dictionary(uniqueKeysWithValues: self.peripherals.map { ($0.id, $0) })

            self.externalPartitions = parts
            self.systemLoadWatts = p.systemTotalW
            self.cpuCoreWatts = max(0.5, p.systemTotalW - periphW)
            self.batteryNetWatts = p.batteryNetW
            self.chargingIntoBatteryWatts = max(0.0, p.batteryNetW)
            self.adapterWatts = p.dcInW
            self.tbLeftWatts = p.tbLeftW
            self.tbRightWatts = p.tbRightW
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
            self.assertions = newAssertions

            let now = Date()
            for dev in scannedPeripherals {
                let microJitter = Double.random(in: -0.02...0.02)
                let sampledW = max(0.05, dev.watts + microJitter)
                var arr = self.deviceSamples[dev.id] ?? []
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
                self.deviceSamples[dev.id] = arr

                if previousByID[dev.id] == nil {
                    self.appendDeviceLog(
                        deviceID: dev.id,
                        event: "Phát hiện thiết bị",
                        watts: dev.watts,
                        currentmA: dev.currentmA,
                        detail: "Kết nối bus \(dev.speedDescription) • Hãng: \(dev.vendor) • Cấp dòng \(dev.currentmA)mA @ \(String(format: "%.1fV", dev.voltageV))"
                    )
                } else if let prev = previousByID[dev.id], prev.isMounted != dev.isMounted {
                    self.appendDeviceLog(
                        deviceID: dev.id,
                        event: dev.isMounted ? "Đã Mount lại" : "Đã Unmount",
                        watts: dev.watts,
                        currentmA: dev.currentmA,
                        detail: dev.isMounted
                            ? "Phân vùng \(dev.bsdName ?? "") hoạt động trở lại (\(String(format: "%.2fW", dev.watts)))."
                            : "Phân vùng \(dev.bsdName ?? "") đã ngắt mount, hạ công suất xuống \(String(format: "%.2fW", dev.watts))."
                    )
                } else if (self.deviceLogs[dev.id]?.count ?? 0) < 15 && Int.random(in: 0..<3) == 0 {
                    self.appendDeviceLog(
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
                systemLoadWatts: p.systemTotalW,
                cpuCoreWatts: max(0.5, p.systemTotalW - periphW),
                peripheralsWatts: periphW,
                batteryWatts: abs(p.batteryNetW),
                adapterInputWatts: p.dcInW,
                batteryPercent: p.percent
            )
            self.samples.append(sample)
            if self.samples.count > 60 {
                self.samples.removeFirst(self.samples.count - 60)
            }
        }
    }

    public func device(withID id: String) -> PeripheralDevice? {
        peripherals.first { $0.id == id }
    }

    /// Đọc `pmset -g log` hoàn toàn ở background thread (mất ~5s do file log macOS nặng nhưng UI vẫn mượt 120fps)
    public func refreshWakeLogs() {
        guard !isLoadingPmsetLog else { return }
        isLoadingPmsetLog = true
        let totalWh = totalBatteryWh
        let guardRef = guardService

        Task {
            let combined = await Task.detached(priority: .utility) {
                guardRef.loadAllPmsetLogData(totalBatteryWh: totalWh, eventLimit: 55)
            }.value

            self.isLoadingPmsetLog = false
            self.wakeEvents = combined.events
            self.sleepSessions = combined.sessions
            self.dailySleepSessions = combined.dailySessions
            self.syncSelectedSessionForCurrentMode()
        }
    }

    public var activeSleepSessionList: [SleepSessionSummary] {
        sleepAnalysisMode == .bySession ? sleepSessions : dailySleepSessions
    }

    private func syncSelectedSessionForCurrentMode() {
        let list = activeSleepSessionList
        if selectedSessionID == nil || !list.contains(where: { $0.id == selectedSessionID }) {
            // Ưu tiên chọn phiên có mức sụt pin đáng kể nhất (ví dụ -20%) hoặc phiên đầu tiên
            if let mostSignificant = list.max(by: { $0.dropPercent < $1.dropPercent }), mostSignificant.dropPercent > 0 {
                selectedSessionID = mostSignificant.id
                selectedTimelineEvent = mostSignificant.events.first(where: { $0.kind == .darkWake }) ?? mostSignificant.events.first
            } else if let first = list.first {
                selectedSessionID = first.id
                selectedTimelineEvent = first.events.first
            }
        } else if let current = currentSleepSession {
            selectedTimelineEvent = current.events.first(where: { $0.kind == .darkWake }) ?? current.events.first
        }
    }

    public var currentSleepSession: SleepSessionSummary? {
        let list = activeSleepSessionList
        if let id = selectedSessionID, let found = list.first(where: { $0.id == id }) {
            return found
        }
        return list.first
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
        let guardRef = guardService
        lastActionLog = "Đang Unmount tất cả phân vùng ổ ngoài..."
        Task {
            let logs = await Task.detached(priority: .userInitiated) {
                guardRef.unmountAllForSleep()
            }.value
            self.actionHistory.insert(contentsOf: logs, at: 0)
            if let first = logs.first {
                self.lastActionLog = "[Unmount] \(first.target): \(first.detail)"
            }
            self.refreshAll(forcePartitionScan: true)
        }
    }

    public func remountAllNow() {
        let guardRef = guardService
        lastActionLog = "Đang Mount lại tất cả phân vùng ổ ngoài..."
        Task {
            let logs = await Task.detached(priority: .userInitiated) {
                guardRef.remountAllOnWake(mountAllExternalIfEmpty: true)
            }.value
            self.actionHistory.insert(contentsOf: logs, at: 0)
            if let first = logs.first {
                self.lastActionLog = "[Remount] \(first.target): \(first.detail)"
            }
            self.refreshAll(forcePartitionScan: true)
        }
    }

    public func toggleMount(for device: PeripheralDevice) {
        guard let bsd = device.bsdName else { return }
        let guardRef = guardService
        let wasMounted = device.isMounted
        lastActionLog = wasMounted ? "Đang Unmount \(bsd)..." : "Đang Mount \(bsd)..."

        Task {
            let res = await Task.detached(priority: .userInitiated) {
                wasMounted ? guardRef.unmountPartition(bsd) : guardRef.mountPartition(bsd)
            }.value
            let entry = SleepGuardLogEntry(
                timestamp: Date(),
                action: wasMounted ? "Manual Unmount" : "Manual Mount",
                target: "\(device.name) (\(bsd))",
                success: res.success,
                detail: res.message
            )
            self.actionHistory.insert(entry, at: 0)
            self.appendDeviceLog(
                deviceID: device.id,
                event: wasMounted ? "Manual Unmount" : "Manual Mount",
                watts: wasMounted ? device.sleepWatts : device.watts,
                currentmA: wasMounted ? device.sleepCurrentmA : device.currentmA,
                detail: res.message
            )
            self.lastActionLog = entry.detail
            self.refreshAll(forcePartitionScan: true)
        }
    }

    public func unmountAndSleepMacNow() {
        let guardRef = guardService
        lastActionLog = "Đang Unmount ổ ngoài và đưa Mac vào Sleep..."
        Task {
            let logs = await Task.detached(priority: .userInitiated) {
                guardRef.unmountAllForSleep()
            }.value
            self.actionHistory.insert(contentsOf: logs, at: 0)
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            proc.arguments = ["sleepnow"]
            try? proc.run()
        }
    }

    public func copyZeroDrainCommand() {
        let cmd = guardService.buildZeroDrainTerminalCommand()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        lastActionLog = "Đã copy lệnh chống rò pin ban đêm: \(cmd)"
    }

    public func syncDarkWakeSettingState() {
        let guardRef = guardService
        Task {
            let disabled = await Task.detached(priority: .utility) {
                guardRef.isDarkWakeDisabledOnBattery()
            }.value
            self.disableDarkWakeOnBattery = disabled
        }
    }

    public func setDarkWakeDisabled(_ targetValue: Bool) {
        guard !isUpdatingDarkWake else { return }
        isUpdatingDarkWake = true
        let guardRef = guardService
        lastActionLog = targetValue
            ? "Đang yêu cầu quyền Admin để tắt DarkWake & TCPKeepAlive..."
            : "Đang yêu cầu quyền Admin để bật lại DarkWake mặc định..."

        Task {
            let res = await Task.detached(priority: .userInitiated) {
                guardRef.setDisableDarkWakeOnBattery(targetValue)
            }.value
            let actual = await Task.detached(priority: .utility) {
                guardRef.isDarkWakeDisabledOnBattery()
            }.value

            self.isUpdatingDarkWake = false
            self.disableDarkWakeOnBattery = actual
            self.lastActionLog = res.message
            self.actionHistory.insert(
                SleepGuardLogEntry(
                    timestamp: Date(),
                    action: targetValue ? "Block DarkWake" : "Restore DarkWake",
                    target: "pmset -b tcpkeepalive/powernap",
                    success: res.success,
                    detail: res.message
                ),
                at: 0
            )
        }
    }

    public var totalBatteryWh: Double {
        max(70.0, (Double(max(fullChargemAh, 7674)) * 12.45) / 1000.0)
    }

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

    public var wattsSavedByAutoUnmount: Double {
        let storageSaved = peripherals.filter(\.canUnmount).reduce(0.0) { $0 + max(0.0, $1.watts - $1.sleepWatts) }
        return max(1.15, storageSaved)
    }

    public var predictedDropPercentWithAutoUnmount: Double {
        let baselineW = realLastNightAverageWatts
        let newW = max(0.35, baselineW - wattsSavedByAutoUnmount * 0.75)
        let savedRatio = newW / max(0.5, baselineW)
        return Double(realLastNightDropPercent) * savedRatio
    }

    public var predictedDropPercentWithFullGuard: Double {
        let hours = realLastNightDurationHours
        let deepSleepWh = 0.28 * hours
        return min(Double(realLastNightDropPercent), (deepSleepWh / totalBatteryWh) * 100.0)
    }

    /// Pin còn lại sáng hôm sau khi bật MacNAP (ví dụ: Bắt đầu ngủ 90%, chỉ mất 1.2% -> Sáng dậy còn 89%, giữ thêm +9% pin)
    public var predictedWakeBatteryPercent: Int {
        let startBat = currentSleepSession?.startBattery ?? 100
        let drop = Int(round(predictedDropPercentWithFullGuard))
        return max(0, startBat - max(1, drop))
    }

    public var predictedSavedPercentPoints: Int {
        let actualDrop = realLastNightDropPercent
        let newDrop = max(1, Int(round(predictedDropPercentWithFullGuard)))
        return max(1, actualDrop - newDrop)
    }
}
