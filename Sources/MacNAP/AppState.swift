import Foundation
import AppKit
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var samples: [PowerSample] = []
    @Published public var peripherals: [PeripheralDevice] = []
    @Published public var assertions: [SleepAssertionItem] = []
    @Published public var wakeEvents: [WakeDrainEvent] = []

    @Published public var systemLoadWatts: Double = 0.0
    @Published public var batteryWatts: Double = 0.0
    @Published public var adapterWatts: Double = 0.0
    @Published public var peripheralsTotalWatts: Double = 0.0
    @Published public var voltageV: Double = 12.0
    @Published public var amperagemA: Int = 0
    @Published public var batteryPercent: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var externalConnected: Bool = false
    @Published public var remainingmAh: Int = 0
    @Published public var fullChargemAh: Int = 0

    @Published public var autoEjectOnSleep: Bool = true
    @Published public var lastActionLog: String = "Sẵn sàng bảo vệ pin khi gập nắp (WillSleep listener active)."

    private let telemetry = PowerTelemetryService()
    private let guardService = JettisonSleepGuardService()
    private var timer: Timer?

    public init() {
        setupSleepWakeObservers()
        refreshAll()
        refreshWakeLogs()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
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
                guard let self = self, self.autoEjectOnSleep else { return }
                let logs = self.guardService.ejectAllExternalDisks()
                self.lastActionLog = "[Auto-Jettison @ Sleep] " + logs.joined(separator: " | ")
            }
        }

        wsCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.refreshAll()
                self.refreshWakeLogs()
            }
        }
    }

    public func refreshAll() {
        let p = telemetry.readBatteryAndSystemPower()
        let volumes = guardService.listExternalMountedVolumes()
        let scannedPeripherals = telemetry.scanPeripherals(mountedDisks: volumes)
        let periphW = scannedPeripherals.reduce(0.0) { $0 + $1.watts }

        self.systemLoadWatts = p.systemLoadW
        self.batteryWatts = p.batteryW
        self.adapterWatts = p.adapterW
        self.peripherals = scannedPeripherals
        self.peripheralsTotalWatts = periphW
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
            batteryWatts: p.batteryW,
            adapterInputWatts: p.adapterW,
            peripheralsWatts: periphW,
            batteryPercent: p.percent
        )
        samples.append(sample)
        if samples.count > 40 {
            samples.removeFirst(samples.count - 40)
        }

        assertions = guardService.scanSleepAssertions()
    }

    public func refreshWakeLogs() {
        wakeEvents = guardService.scanRecentWakeDrainEvents()
    }

    public func ejectNowAll() {
        let logs = guardService.ejectAllExternalDisks()
        lastActionLog = logs.joined(separator: " | ")
        refreshAll()
    }

    public func ejectSingle(_ device: PeripheralDevice) {
        guard let bsd = device.bsdName else { return }
        let res = guardService.ejectVolumeOrDisk(bsdOrName: bsd)
        lastActionLog = "\(device.name): \(res.message)"
        refreshAll()
    }

    public func jettisonAndSleepMacNow() {
        let logs = guardService.ejectAllExternalDisks()
        lastActionLog = "Đã ngắt ổ ngoại vi: \(logs.joined(separator: ", ")). Đang đưa Mac vào Sleep..."
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        proc.arguments = ["sleepnow"]
        try? proc.run()
    }

    public func copyZeroDrainCommand() {
        let cmd = guardService.buildZeroDrainTerminalCommand()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        lastActionLog = "Đã copy lệnh chống tụt pin ban đêm: \(cmd)"
    }

    public var estimatedOvernight8hDrainPercent: Double {
        // Full battery Wh ~ (fullChargemAh * voltageV) / 1000
        let totalWh = max(50.0, (Double(max(fullChargemAh, 6500)) * 12.0) / 1000.0)
        // If peripherals stay powered + DarkWake occurs, estimate drain over 8h
        let sleepLeakWatts = peripheralsTotalWatts * 0.65 + (assertions.contains(where: \.isCulprit) ? 2.5 : 0.4)
        let drainWh8h = sleepLeakWatts * 8.0
        return min(100.0, (drainWh8h / totalWh) * 100.0)
    }
}
