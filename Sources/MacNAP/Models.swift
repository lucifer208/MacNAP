import Foundation

public struct PowerSample: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let systemLoadWatts: Double
    public let cpuCoreWatts: Double
    public let peripheralsWatts: Double
    public let batteryWatts: Double
    public let adapterInputWatts: Double
    public let batteryPercent: Int
}

public struct DevicePowerSample: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let watts: Double
    public let currentmA: Int
    public let voltageV: Double
    public let isMounted: Bool
}

public struct DeviceLogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let watts: Double
    public let currentmA: Int
    public let detail: String
}

/// Một sự kiện trong phiên ngủ thực tế (lấy từ `pmset -g log`), giống kiểu Sleep Aid
public struct SleepTimelineEvent: Identifiable, Hashable {
    public let id = UUID()
    public let timestamp: Date
    public let timeLabel: String      // e.g. "03:23:44"
    public let dateLabel: String      // e.g. "2026-10-28 03:23:44"
    public let kind: SleepEventKind   // .sleep, .darkWake, .fullWake
    public let durationSeconds: Int
    public let batteryPercent: Int
    public let usingAC: Bool
    public let triggerReason: String  // e.g. "rtc/SleepService", "wifibt SMC.OutboxNotEmpty", "ATC0.USBWakeup"
    public let rawLine: String
}

public enum SleepEventKind: String, Codable, CaseIterable {
    case sleep = "Sleep"
    case darkWake = "DarkWake"
    case fullWake = "Wake"
}

/// Một phiên ngủ thực tế tổng hợp từ `pmset -g log` (Sleep Aid Session)
public struct SleepSessionSummary: Identifiable, Hashable {
    public let id = UUID()
    public let startTime: Date
    public let endTime: Date
    public let titleLabel: String         // e.g. "28/10 02:34 → 09:25"
    public let startBattery: Int          // e.g. 100%
    public let endBattery: Int            // e.g. 80%
    public let dropPercent: Int           // e.g. 20%
    public let durationHours: Double      // e.g. 6.85h
    public let averageDrainWatts: Double  // Tính chuẩn từ Wh thực tế: (drop% * totalWh) / durationHours
    public let darkWakeCount: Int
    public let usbWakeCount: Int
    public let tcpKeepAliveActive: Bool
    public let events: [SleepTimelineEvent]
}

public enum PeripheralKind: String, CaseIterable, Codable {
    case externalDrive = "Ổ cứng ngoài"
    case usbDevice = "Thiết bị USB"
    case usbHub = "USB Hub"
    case bluetooth = "Bluetooth"

    public var iconName: String {
        switch self {
        case .externalDrive: return "externaldrive.fill"
        case .usbDevice: return "cable.connector.horizontal"
        case .usbHub: return "rectangle.connected.to.line.below"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        }
    }
}

public struct ExternalDiskPartition: Identifiable, Hashable {
    public var id: String { bsdName }
    public let bsdName: String          // e.g. "disk4s1"
    public let parentWholeDisk: String  // e.g. "disk4"
    public let volumeName: String       // e.g. "WORKING"
    public let fileSystem: String       // e.g. "ExFAT"
    public let sizeDescription: String  // e.g. "2.0 TB"
    public let isMounted: Bool
    public let mountPoint: String?
}

public struct PeripheralDevice: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let vendor: String
    public let kind: PeripheralKind
    public let currentmA: Int
    public let sleepCurrentmA: Int
    public let voltageV: Double
    public let watts: Double
    public let sleepWatts: Double
    public let canUnmount: Bool
    public let bsdName: String?
    public let parentDisk: String?
    public let isMounted: Bool
    public let speedDescription: String
}

public struct SleepAssertionItem: Identifiable {
    public let id = UUID()
    public let pid: String
    public let processName: String
    public let assertionType: String
    public let duration: String
    public let detail: String
    public let isCulprit: Bool
    public let estimatedWasteWatts: Double
}

public enum PowerLogCategory: String, CaseIterable {
    case all = "Tất cả"
    case sleep = "Sleep"
    case darkWake = "DarkWake"
    case wake = "Wake"
    case assertion = "Assertions"
}

public struct WakeDrainEvent: Identifiable {
    public let id = UUID()
    public let timestamp: String
    public let category: PowerLogCategory
    public let processOrComponent: String
    public let reason: String
    public let batteryPercent: Int?
    public let estimatedImpactWatts: Double
}

public struct SleepGuardLogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let action: String
    public let target: String
    public let success: Bool
    public let detail: String
}
