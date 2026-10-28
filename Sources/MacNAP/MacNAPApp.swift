import SwiftUI
import AppKit
import UserNotifications

@MainActor
public final class MacNAPAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    public let state = AppState()
    public var statusBarController: StatusBarController?
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var deviceWindows: [String: NSWindow] = [:]

    public func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        // Đóng ngay bất kỳ cửa sổ nào macOS tự ý mở lúc khởi động (đặc biệt là Settings window)
        DispatchQueue.main.async {
            for win in NSApplication.shared.windows {
                let title = win.title
                if title.contains("Settings") || title.contains("Cài đặt") {
                    win.orderOut(nil)
                }
            }
        }

        // Thiết lập UserNotifications cho cảnh báo Hao pin & Kẻ trộm giấc ngủ
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                AppDiagnosticLogger.shared.log(.info, component: "Notification", message: "Đã cấp quyền thông báo hệ thống macOS.")
            }
        }

        setupAppMainMenu()
        state.applyDockVisibilityPolicy()
        statusBarController = StatusBarController(
            state: state,
            onOpenDashboard: { [weak self] in
                self?.openDashboardWindow()
            },
            onOpenDeviceDetail: { [weak self] devID in
                self?.openDeviceWindow(deviceID: devID)
            }
        )

        // Tự động đóng Dashboard ngay khi ứng dụng mất active (nhấn ra ngoài cửa sổ khác)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dashboardWindow?.orderOut(nil)
                self?.updateDockActivationPolicy()
            }
        }

        // Khi bất kỳ cửa sổ nào đóng, thu hồi icon trên Dock ngay lập tức
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.updateDockActivationPolicy()
            }
        }
    }

    public func activateAppWithRegularPolicy() {
        if NSApplication.shared.activationPolicy() != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        state.applyCustomDockIcon()
        setupAppMainMenu()
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    public func updateDockActivationPolicy() {
        let isSettingsOpen = (settingsWindow?.isVisible == true)
        let isDashboardOpen = (dashboardWindow?.isVisible == true)
        let isDeviceOpen = deviceWindows.values.contains { $0.isVisible }
        let hasVisibleWindow = isSettingsOpen || isDashboardOpen || isDeviceOpen

        if hasVisibleWindow {
            activateAppWithRegularPolicy()
        } else {
            if state.hideDockIcon {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    public func openSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            activateAppWithRegularPolicy()
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(state: state))
        let win = NSWindow(contentViewController: hosting)
        win.title = state.language == .vi ? "MacNAP — Cài đặt" : "MacNAP — Settings"
        win.setContentSize(NSSize(width: 540, height: 440))
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        self.settingsWindow = win
        activateAppWithRegularPolicy()
    }

    public func setupAppMainMenu() {
        let mainMenu = NSMenu()

        // 1. Menu ứng dụng MacNAP
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "MacNAP")

        let aboutItem = NSMenuItem(
            title: state.language == .vi ? "Giới thiệu MacNAP" : "About MacNAP",
            action: #selector(showAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        let updateItem = NSMenuItem(
            title: state.language == .vi ? "Kiểm tra cập nhật..." : "Check for Updates...",
            action: #selector(checkForUpdatesAction),
            keyEquivalent: "u"
        )
        updateItem.keyEquivalentModifierMask = [.command]
        updateItem.target = self
        appMenu.addItem(updateItem)

        appMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: state.language == .vi ? "Cài đặt..." : "Settings...",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        appMenu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(
            title: state.language == .vi ? "Ẩn MacNAP" : "Hide MacNAP",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: state.language == .vi ? "Ẩn ứng dụng khác" : "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: state.language == .vi ? "Hiện tất cả" : "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(showAllItem)

        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: state.language == .vi ? "Thoát MacNAP" : "Quit MacNAP",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. Menu Cửa sổ (Window)
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: state.language == .vi ? "Cửa sổ" : "Window")

        let dashItem = NSMenuItem(
            title: state.language == .vi ? "Mở Dashboard" : "Open Dashboard",
            action: #selector(openDashboardAction),
            keyEquivalent: "d"
        )
        dashItem.keyEquivalentModifierMask = [.command]
        dashItem.target = self
        windowMenu.addItem(dashItem)

        let closeItem = NSMenuItem(
            title: state.language == .vi ? "Đóng cửa sổ" : "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        windowMenu.addItem(closeItem)

        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // 3. Menu Trợ giúp (Help)
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: state.language == .vi ? "Trợ giúp" : "Help")

        let reportItem = NSMenuItem(
            title: state.language == .vi ? "Báo lỗi trên GitHub..." : "Report Issue on GitHub...",
            action: #selector(openReportAction),
            keyEquivalent: ""
        )
        reportItem.target = self
        helpMenu.addItem(reportItem)

        let donateItem = NSMenuItem(
            title: state.language == .vi ? "Ủng hộ Tác giả (VietQR)..." : "Donate (VietQR)...",
            action: #selector(openDonateAction),
            keyEquivalent: ""
        )
        donateItem.target = self
        helpMenu.addItem(donateItem)

        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsAction() {
        openSettingsWindow()
    }

    @objc private func openDashboardAction() {
        openDashboardWindow()
    }

    @objc private func checkForUpdatesAction() {
        state.checkForUpdates(silentIfUpToDate: false)
    }

    @objc private func showAboutAction() {
        openSettingsWindow()
    }

    @objc private func openReportAction() {
        state.showReportSheet = true
        openDashboardWindow()
    }

    @objc private func openDonateAction() {
        state.showDonateSheet = true
        openDashboardWindow()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AppDiagnosticLogger.shared.markCleanShutdown()
    }

    public func openDashboardWindow() {
        activateAppWithRegularPolicy()
        if let win = dashboardWindow {
            win.makeKeyAndOrderFront(nil)
            win.makeMain()
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let rootView = DashboardView(
            state: state,
            onSelectDevice: { [weak self] devID in
                self?.openDeviceWindow(deviceID: devID)
            }
        )
        let hosting = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: hosting)
        win.title = "MacNAP — Quản lý Nguồn & Bảo vệ Pin"

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetWidth = min(1280, max(1160, screenFrame.width - 60))
        let targetHeight = min(850, max(760, screenFrame.height - 50))
        win.setContentSize(NSSize(width: targetWidth, height: targetHeight))
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.isReleasedWhenClosed = false
        win.center()

        // Tự đóng Dashboard khi cửa sổ Dashboard không còn là Key Window (trừ khi đang mở menu xổ xuống bên trong)
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: win,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                guard let self = self, let dashWin = self.dashboardWindow else { return }
                let anyDeviceWindowKey = self.deviceWindows.values.contains { $0.isKeyWindow }
                let isSettingsKey = (self.settingsWindow?.isKeyWindow == true)
                if !NSApp.isActive && !dashWin.isKeyWindow && !anyDeviceWindowKey && !isSettingsKey {
                    dashWin.orderOut(nil)
                    self.updateDockActivationPolicy()
                }
            }
        }

        win.makeKeyAndOrderFront(nil)
        win.makeMain()
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.dashboardWindow = win
    }

    public func openDeviceWindow(deviceID: String) {
        if let existing = deviceWindows[deviceID] {
            existing.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let detailView = DeviceDetailView(state: state, deviceID: deviceID)
        let hosting = NSHostingController(rootView: detailView)
        let win = NSWindow(contentViewController: hosting)
        let devName = state.device(withID: deviceID)?.name ?? deviceID
        win.title = "MacNAP — \(devName)"
        win.setContentSize(NSSize(width: 760, height: 580))
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        deviceWindows[deviceID] = win
    }

    // MARK: - UNUserNotificationCenterDelegate
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.openDashboardWindow()
        }
        completionHandler()
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct MacNAPApp: App {
    @NSApplicationDelegateAdaptor(MacNAPAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
