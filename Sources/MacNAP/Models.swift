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

public enum PeripheralKind: String, CaseIterable {
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

public struct PeripheralDevice: Identifiable, Hashable {
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
