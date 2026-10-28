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
        win.setContentSize(NSSize(width: 1120, height: 780))
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.isReleasedWhenClosed = false
        win.center()
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
        win.setContentSize(NSSize(width: 740, height: 560))
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
