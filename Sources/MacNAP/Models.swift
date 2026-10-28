import Foundation

public struct PowerSample: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let systemLoadWatts: Double
    public let batteryWatts: Double
    public let adapterInputWatts: Double
    public let peripheralsWatts: Double
    public let batteryPercent: Int
}

public enum PeripheralKind: String, CaseIterable {
    case externalDrive = "External Drive"
    case usbDevice = "USB Device"
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

public struct PeripheralDevice: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let vendor: String
    public let kind: PeripheralKind
    public let currentmA: Int
    public let voltageV: Double
    public let watts: Double
    public let canUnmount: Bool
    public let bsdName: String?
    public let isMounted: Bool
    public let sleepCapable: Bool
}

public struct SleepAssertionItem: Identifiable {
    public let id = UUID()
    public let pid: String
    public let processName: String
    public let assertionType: String
    public let duration: String
    public let detail: String
    public let isCulprit: Bool
}

public struct WakeDrainEvent: Identifiable {
    public let id = UUID()
    public let timestamp: String
    public let eventType: String
    public let reason: String
    public let batteryPercent: Int?
}
