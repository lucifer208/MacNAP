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
        case .sleepAid: return t("Phân tích Ngủ (Sleep Aid)", "Sleep Aid Timeline")
        case .peripherals: return t("Thiết bị Ngoại vi & USB", "Peripherals & USB")
        case .powerLog: return t("Nhật ký Nguồn (pmset)", "Power Logs & Assertions")
        }
    }

    // Common Actions
    public var openDashboard: String { t("Mở Dashboard Phân tích", "Open Analytics Dashboard") }
    public var unmountAll: String { t("Unmount ổ ngoài", "Unmount Drives") }
    public var remountAll: String { t("Mount lại ngay", "Remount Drives") }
    public var sleepNowZzz: String { t("Unmount & Ngủ ngay", "Unmount & Sleep Now") }
    public var quitApp: String { t("Thoát MacNAP", "Quit MacNAP") }

    // Toggles
    public var launchAtLogin: String { t("Khởi động cùng máy (Login)", "Launch at Login") }
    public var hideDockIcon: String { t("Ẩn icon trên thanh Dock", "Hide Dock Icon") }
    public var autoUnmountSleep: String { t("Tự Unmount khi gập nắp / ngủ", "Auto-Unmount on Sleep") }
    public var autoRemountWake: String { t("Tự Mount lại ngay khi mở nắp", "Auto-Remount on Wake") }

    // KPI Titles
    public var kpiSystemTotal: String { t("CÔNG SUẤT TIÊU THỤ (SYSTEM TOTAL)", "SYSTEM TOTAL POWER") }
    public var kpiDCIn: String { t("NGUỒN SẠC VÀO (DC IN)", "DC IN ADAPTER POWER") }
    public var kpiLastSleep: String { t("PHIÊN NGỦ GẦN NHẤT (CHƯA BẬT APP)", "LAST SLEEP (UNPROTECTED)") }
    public var kpiWithMacNAP: String { t("ƯỚC TÍNH KHI BẬT MACNAP GUARD", "ESTIMATED WITH MACNAP GUARD") }
}
