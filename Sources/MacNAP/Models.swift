import Foundation
import AppKit

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

/// Chế độ xem thống kê Pin khi ngủ: Theo từng lần Sleep (Session) hoặc Theo Ngày (Từ 00:00 đến lúc mở máy)
public enum SleepAnalysisMode: String, CaseIterable, Identifiable {
    case bySession = "Theo lần Sleep"
    case byDay = "Theo ngày (Từ 00:00)"

    public var id: String { rawValue }
}

/// Một phiên ngủ thực tế hoặc tổng hợp theo ngày từ `pmset -g log`
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

    public var usbWakeEvents: [SleepTimelineEvent] {
        events.filter { $0.triggerReason.contains("USB") || $0.rawLine.contains("USBWakeup") }
    }

    public var wifiWakeEvents: [SleepTimelineEvent] {
        events.filter { $0.rawLine.contains("wifibt") || $0.rawLine.contains("E_RX_IP_PACKET") || $0.rawLine.contains("ARPT") }
    }

    public var maintenanceWakeEvents: [SleepTimelineEvent] {
        events.filter { $0.rawLine.contains("SleepService") || $0.rawLine.contains("Maintenance") }
    }

    public func calculateCulprits(hasPeripherals: Bool = true) -> [SleepCulpritBreakdown] {
        let totalDrop = Double(max(0, dropPercent))
        guard totalDrop > 0 else { return [] }

        let usbWakes = max(usbWakeCount, usbWakeEvents.count)
        let wifiWakes = wifiWakeEvents.count
        let maintWakes = maintenanceWakeEvents.count
        let dur = max(0.5, durationHours)

        let rawUsbWh = (Double(usbWakes) * 0.12) + (hasPeripherals ? dur * 0.55 : 0.0)
        let rawWifiWh = (Double(wifiWakes) * 0.08) + (tcpKeepAliveActive ? dur * 0.35 : 0.05)
        let rawMaintWh = (Double(maintWakes) * 0.05) + (dur * 0.15)
        let rawBaseWh = dur * 0.12

        let sumRaw = max(0.01, rawUsbWh + rawWifiWh + rawMaintWh + rawBaseWh)
        let usbPct = (rawUsbWh / sumRaw) * totalDrop
        let wifiPct = (rawWifiWh / sumRaw) * totalDrop
        let maintPct = (rawMaintWh / sumRaw) * totalDrop
        let basePct = max(0.0, totalDrop - (usbPct + wifiPct + maintPct))

        let usbShare = max(1, Int(round((usbPct / totalDrop) * 100)))
        let wifiShare = max(1, Int(round((wifiPct / totalDrop) * 100)))
        let maintShare = max(1, Int(round((maintPct / totalDrop) * 100)))
        let baseShare = max(0, 100 - (usbShare + wifiShare + maintShare))

        return [
            SleepCulpritBreakdown(
                nameVi: "Cổng USB & Ngoại vi (Hub / SSD)",
                nameEn: "USB Bus & Peripherals",
                icon: "cable.connector.horizontal",
                colorName: "orange",
                dropPercent: usbPct,
                sharePercentage: usbShare,
                eventCountText: "\(usbWakes) lần USBWakeup",
                explanationVi: "Cổng Type-C cấp nguồn 5V cho Hub/SSD ngoài và nhận tín hiệu đánh thức máy.",
                explanationEn: "Type-C ports supply 5V bus power to Hubs/SSDs and trigger wake interrupts.",
                recommendationVi: "Bật Auto-Unmount ổ đĩa & ngắt hub không sử dụng.",
                recommendationEn: "Enable Auto-Unmount and detach unused hubs."
            ),
            SleepCulpritBreakdown(
                nameVi: "Sóng Wi-Fi & Gói mạng IP (TCPKeepAlive)",
                nameEn: "Wi-Fi & TCPKeepAlive DarkWake",
                icon: "wifi.exclamationmark",
                colorName: "indigo",
                dropPercent: wifiPct,
                sharePercentage: wifiShare,
                eventCountText: "\(wifiWakes) lần nhận gói IP",
                explanationVi: "Card Wi-Fi bật ngầm nhận gói mạng khiến CPU giật mình thức giấc liên tục.",
                explanationEn: "Wi-Fi radio remains powered to receive network packets, waking the CPU.",
                recommendationVi: "Bật Chặn DarkWake trên MacNAP để tắt TCPKeepAlive khi dùng Pin.",
                recommendationEn: "Enable Block DarkWake in MacNAP to turn off TCPKeepAlive on battery."
            ),
            SleepCulpritBreakdown(
                nameVi: "Tác vụ bảo trì macOS (SleepService)",
                nameEn: "macOS Maintenance Sleep",
                icon: "gearshape.2.fill",
                colorName: "amber",
                dropPercent: maintPct,
                sharePercentage: maintShare,
                eventCountText: "\(maintWakes) lần SleepService",
                explanationVi: "Apple RTC tự hẹn giờ chạy ngầm bảo trì iCloud, Mail, Spotlight và PowerNap.",
                explanationEn: "Apple RTC timer wakes Mac periodically for iCloud, Mail, Spotlight sync.",
                recommendationVi: "Tắt PowerNap khi dùng pin (được tối ưu trong Chặn DarkWake).",
                recommendationEn: "Disable Power Nap on battery (included in Block DarkWake)."
            ),
            SleepCulpritBreakdown(
                nameVi: "Tiêu thụ phần cứng tự nhiên (Deep Sleep)",
                nameEn: "Hardware Standby Base Drain",
                icon: "shield.checkered",
                colorName: "teal",
                dropPercent: basePct,
                sharePercentage: baseShare,
                eventCountText: "\(String(format: "%.1fh", dur)) Sleep sâu",
                explanationVi: "Dòng điện tối thiểu duy trì RAM Self-Refresh và chip SMC của Apple Silicon.",
                explanationEn: "Minimal power required to maintain RAM Self-Refresh and Apple Silicon SMC.",
                recommendationVi: "Mức tiêu thụ tự nhiên lý tưởng của chip Apple Silicon.",
                recommendationEn: "Normal expected standby consumption of hardware."
            )
        ]
    }
}

public struct SleepCulpritBreakdown: Identifiable, Hashable {
    public let id = UUID()
    public let nameVi: String
    public let nameEn: String
    public let icon: String
    public let colorName: String
    public let dropPercent: Double
    public let sharePercentage: Int
    public let eventCountText: String
    public let explanationVi: String
    public let explanationEn: String
    public let recommendationVi: String
    public let recommendationEn: String
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

/// Ứng dụng tiêu thụ điện năng thời gian thực tính theo Watt
public struct AppProcessEnergyItem: Identifiable, Hashable {
    public var id: Int { pid }
    public let pid: Int
    public let name: String
    public let rawCommand: String
    public let cpuPercent: Double
    public let estimatedWatts: Double
    public let sharePercent: Int
    public let isFrontmost: Bool
    public let bundleID: String?
}

/// Bộ lọc cho Nhật ký tiêu hao pin
public enum BatteryDrainFilter: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case batteryOnly = "Dùng Pin"
    case sleepOnly = "Sleep"
    case highDrain = "Tụt nhanh (>10W)"

    public var id: String { rawValue }
}
public struct BatteryDrainLogEntry: Identifiable, Hashable {
    public let id = UUID()
    public let timestamp: Date
    public let timeLabel: String
    public let dateLabel: String
    public let batteryPercent: Int
    public let deltaPercent: Int
    public let watts: Double
    public let stateLabel: String
    public let topCulprit: String
    public let isSleepEvent: Bool
    public let isHighDrain: Bool
}

/// Mẫu mức pin và hoạt động theo từng giờ hoặc từng ngày (chuẩn Apple Battery Settings)
public struct BatteryChartHourlySample: Identifiable, Hashable {
    public var id: String { key }
    public let key: String             // "00:00", "01:00", ... hoặc "2026-10-28"
    public let hourIndex: Int          // 0..23 (hoặc 0..9 ngày)
    public let label: String           // "00 giờ", "03", ... hoặc "28/10"
    public let timeString: String      // "14:00" hoặc "28 thg 10"
    public let detailedTitle: String   // "14:00 - 15:00" hoặc "Thứ Tư, 28/10/2026"
    public let batteryPercent: Int     // 0..100%
    public let isCharging: Bool        // true nếu cắm sạc
    public let screenOnMinutes: Int    // 0..60 phút (24h) hoặc tổng phút (10 ngày)
    public let screenOnDisplay: String // "45 phút" hoặc "6.2 giờ"
    public let darkWakeCount: Int      // Số lần DarkWake
    public let isSleepPeriod: Bool     // true nếu đang sleep
    public let watts: Double           // Công suất ước tính
    public let powerSourceText: String // "Cắm sạc AC" hoặc "Đang dùng Pin"
}

// MARK: - Menu Bar Customization Models

/// Bố cục hiển thị trên Menu Bar: 1 dòng ngang hoặc 2 dòng xếp chồng (nhãn trên, giá trị dưới như Stats / iStat Menus)
public enum MenuBarLayoutMode: String, Codable, CaseIterable, Identifiable {
    case inline = "inline"       // 1 dòng: ⚡ 13.3W
    case stacked = "stacked"     // 2 dòng xếp chồng: USAGE / 13.3W (chuẩn Stats app)

    public var id: String { rawValue }

    public func title(language: AppLanguage) -> String {
        switch self {
        case .inline: return language == .vi ? "1 dòng ngang (Inline)" : "Single Line (Inline)"
        case .stacked: return language == .vi ? "2 dòng xếp chồng (Label trên, Watt dưới - Kiểu Stats)" : "Two Lines Stacked (Label Top, Value Bottom)"
        }
    }
}

/// Kiểu thẻ thông số trên Menu Bar
public enum MenuBarTagType: String, Codable, CaseIterable, Identifiable {
    case usage = "usage"
    case charge = "charge"

    public var id: String { rawValue }

    public func title(language: AppLanguage) -> String {
        switch self {
        case .usage: return language == .vi ? "Tiêu thụ (Usage)" : "Power Usage"
        case .charge: return language == .vi ? "Nguồn sạc (Charge)" : "Power Charge"
        }
    }

    public var defaultIcon: String {
        switch self {
        case .usage: return "bolt.fill"
        case .charge: return "powerplug.fill"
        }
    }
}

/// Kiểu hiển thị nhãn của thẻ Menu Bar
public enum MenuBarLabelStyle: String, Codable, CaseIterable, Identifiable {
    case iconOnly = "iconOnly"           // ⚡ 25.4W
    case textOnly = "textOnly"           // usage 25.4W
    case iconAndText = "iconAndText"     // ⚡ usage 25.4W
    case numberOnly = "numberOnly"       // 25.4W

    public var id: String { rawValue }

    public func title(language: AppLanguage) -> String {
        switch self {
        case .iconOnly: return language == .vi ? "Chỉ Icon (⚡ / 🔌)" : "Icon Only (⚡ / 🔌)"
        case .textOnly: return language == .vi ? "Chữ (\"usage\" / \"charge\")" : "Text (\"usage\" / \"charge\")"
        case .iconAndText: return language == .vi ? "Cả Icon & Chữ" : "Icon & Text"
        case .numberOnly: return language == .vi ? "Chỉ số Watt" : "Watts Only"
        }
    }
}

/// Kiểu thiết kế font chữ trên Menu Bar
public enum MenuBarFontDesign: String, Codable, CaseIterable, Identifiable {
    case monospaced = "monospaced"
    case system = "system"
    case rounded = "rounded"
    case serif = "serif"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .monospaced: return "Monospaced (Số cố định)"
        case .system: return "SF Pro (Mặc định)"
        case .rounded: return "Rounded (Bo tròn)"
        case .serif: return "Serif (Có chân)"
        }
    }
}

/// Độ đậm nét của chữ trên Menu Bar
public enum MenuBarFontWeight: String, Codable, CaseIterable, Identifiable {
    case regular = "regular"
    case medium = "medium"
    case semibold = "semibold"
    case bold = "bold"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .regular: return "Regular (Bình thường)"
        case .medium: return "Medium (Vừa)"
        case .semibold: return "Semibold (Đậm vừa)"
        case .bold: return "Bold (Đậm)"
        }
    }

    public var nsWeight: NSFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

/// Ký tự ngăn cách giữa 2 thẻ khi gộp chung
public enum MenuBarSeparatorStyle: String, Codable, CaseIterable, Identifiable {
    case none = "none"           // Khoảng trắng
    case verticalBar = "bar"     // |
    case dash = "dash"           // —
    case slash = "slash"         // /
    case bullet = "bullet"       // •

    public var id: String { rawValue }

    public var displaySymbol: String {
        switch self {
        case .none: return " "
        case .verticalBar: return "|"
        case .dash: return "—"
        case .slash: return "/"
        case .bullet: return "•"
        }
    }

    public func title(language: AppLanguage) -> String {
        switch self {
        case .none: return language == .vi ? "Khoảng trống (Mặc định)" : "Space (Default)"
        case .verticalBar: return language == .vi ? "Gạch đứng ( | )" : "Vertical Bar ( | )"
        case .dash: return language == .vi ? "Gạch ngang ( — )" : "Dash ( — )"
        case .slash: return language == .vi ? "Gạch chéo ( / )" : "Slash ( / )"
        case .bullet: return language == .vi ? "Dấu chấm tròn ( • )" : "Bullet ( • )"
        }
    }
}
