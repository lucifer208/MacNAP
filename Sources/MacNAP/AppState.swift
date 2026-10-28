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

    @Published public var selectedLogFilter: PowerLogCategory = .all
    @Published public var logSearchQuery: String = ""

    @Published public var systemLoadWatts: Double = 0.0
    @Published public var cpuCoreWatts: Double = 0.0
    @Published public var batteryWatts: Double = 0.0
    @Published public var adapterWatts: Double = 0.0
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
    @Published public var lastActionLog: String = "Sẵn sàng: Tự Unmount khi gập nắp & tự Mount lại tức thì khi mở nắp."

    private let telemetry = PowerTelemetryService()
    private let guardService = SleepMountGuardService()
    private var timer: Timer?

    public init() {
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
                    if let first = logs.first {
                        self.lastActionLog = "[Mở nắp • Auto-Remount] \(first.target): \(first.detail)"
                    }
                }
                self.refreshAll()
                self.refreshWakeLogs()
            }
        }
    }

    public func refreshAll() {
        let p = telemetry.readBatteryAndSystemPower()
        let parts = guardService.scanExternalPartitions()
        let scannedPeripherals = telemetry.scanPeripherals(partitions: parts)
        let periphW = scannedPeripherals.reduce(0.0) { $0 + $1.watts }
        let periphSleepW = scannedPeripherals.reduce(0.0) { $0 + $1.sleepWatts }
        let coreW = max(0.5, p.systemLoadW - periphW)

        self.externalPartitions = parts
        self.systemLoadWatts = p.systemLoadW
        self.cpuCoreWatts = coreW
        self.batteryWatts = p.batteryW
        self.adapterWatts = p.adapterW
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

        let sample = PowerSample(
            timestamp: Date(),
            systemLoadWatts: p.systemLoadW,
            cpuCoreWatts: coreW,
            peripheralsWatts: periphW,
            batteryWatts: p.batteryW,
            adapterInputWatts: p.adapterW,
            batteryPercent: p.percent
        )
        samples.append(sample)
        if samples.count > 60 {
            samples.removeFirst(samples.count - 60)
        }

        assertions = guardService.scanSleepAssertions()
    }

    public func refreshWakeLogs() {
        wakeEvents = guardService.scanDetailedPowerLogEvents(limit: 45)
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
        max(55.0, (Double(max(fullChargemAh, 6800)) * 12.2) / 1000.0)
    }

    public var estimatedOvernight8hDrainPercentWithoutGuard: Double {
        let assertionWasteW = assertions.filter(\.isCulprit).reduce(0.0) { $0 + $1.estimatedWasteWatts }
        let leakWatts = peripheralsTotalWatts * 0.72 + assertionWasteW
        let drainWh = leakWatts * 8.0
        return min(100.0, (drainWh / totalBatteryWh) * 100.0)
    }

    public var estimatedOvernight8hDrainPercentWithGuard: Double {
        let standbyWatts = peripheralsSleepWatts * 0.35 + 0.35
        let drainWh = standbyWatts * 8.0
        return min(100.0, (drainWh / totalBatteryWh) * 100.0)
    }
}
