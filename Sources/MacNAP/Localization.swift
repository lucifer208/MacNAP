import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable {
    case vi = "Tiếng Việt"
    case en = "English"

    public var id: String { rawValue }
    public var code: String {
        switch self {
        case .vi: return "VI"
        case .en: return "EN"
        }
    }
}

public struct L10n {
    public let lang: AppLanguage

    public init(_ lang: AppLanguage) {
        self.lang = lang
    }

    public func t(_ vi: String, _ en: String) -> String {
        lang == .vi ? vi : en
    }

    // Navigation Sections
    public func sectionTitle(_ section: DashboardSection) -> String {
        switch section {
        case .overview: return t("Dashboard Tổng quan", "Overview Dashboard")
        case .sleepAid: return t("Phân tích Sleep / CloseLid", "Sleep / CloseLid Timeline")
        case .batteryDrain: return t("Nhật ký Tiêu hao Pin", "Battery Drain History & Apps")
        case .peripherals: return t("Thiết bị Ngoại vi & USB", "Peripherals & USB")
        case .powerLog: return t("Nhật ký Nguồn (pmset)", "Power Logs & Assertions")
        }
    }

    // Common Actions
    public var openDashboard: String { t("Mở Dashboard Phân tích", "Open Analytics Dashboard") }
    public var unmountAll: String { t("Unmount ổ ngoài", "Unmount Drives") }
    public var remountAll: String { t("Mount lại ngay", "Remount Drives") }
    public var sleepNowZzz: String { t("Unmount & Sleep ngay", "Unmount & Sleep Now") }
    public var quitApp: String { t("Thoát MacNAP", "Quit MacNAP") }

    // Toggles (Sleep/CloseLid and Wake/OpenLid always unified)
    public var launchAtLogin: String { t("Khởi động cùng macOS", "Launch at Login") }
    public var hideDockIcon: String { t("Ẩn icon trên thanh Dock", "Hide Dock Icon") }
    public var autoUnmountSleep: String { t("Tự Unmount khi Sleep / CloseLid", "Auto-Unmount on Sleep / CloseLid") }
    public var autoRemountWake: String { t("Tự Mount khi Wake / OpenLid", "Auto-Remount on Wake / OpenLid") }
    public var disableDarkWakeBattery: String { t("Chặn DarkWake (Khi dùng Pin)", "Block DarkWake (On Battery)") }

    // Group Titles
    public var groupSleepGuard: String { t("BẢO VỆ SLEEP / CLOSELID & Ổ NGOÀI", "SLEEP / CLOSELID & DRIVE GUARD") }
    public var groupSystemPrefs: String { t("HỆ THỐNG & GIAO DIỆN", "SYSTEM & INTERFACE") }

    // KPI Titles
    public var kpiSystemTotal: String { t("TỔNG CÔNG SUẤT TIÊU THỤ", "TOTAL POWER CONSUMPTION") }
    public var kpiDCIn: String { t("CÔNG SUẤT SẠC VÀO (MAX 140W)", "CHARGING POWER IN") }
    public var kpiLastSleep: String { t("HAO PIN KHI SLEEP / CLOSELID", "SLEEP / CLOSELID DRAIN") }
    public var kpiWithMacNAP: String { t("ƯỚC TÍNH KHI BẬT MACNAP", "ESTIMATED WITH MACNAP") }
}
