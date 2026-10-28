import SwiftUI
import AppKit

@MainActor
public final class MacNAPAppDelegate: NSObject, NSApplicationDelegate {
    public let state = AppState()
    public var statusBarController: StatusBarController?
    private var dashboardWindow: NSWindow?
    private var deviceWindows: [String: NSWindow] = [:]

    public func applicationDidFinishLaunching(_ notification: Notification) {
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
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AppDiagnosticLogger.shared.markCleanShutdown()
    }

    public func openDashboardWindow() {
        if !state.hideDockIcon {
            NSApplication.shared.setActivationPolicy(.regular)
            state.applyCustomDockIcon()
        }
        if let win = dashboardWindow {
            win.makeKeyAndOrderFront(nil)
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
        win.title = "MacNAP — AppleSMC & Sleep Aid Watt Profiler"

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
                if !NSApp.isActive && !dashWin.isKeyWindow && !anyDeviceWindowKey {
                    dashWin.orderOut(nil)
                }
            }
        }

        win.makeKeyAndOrderFront(nil)
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
