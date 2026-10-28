import AppKit
import SwiftUI
import Combine

@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let state: AppState
    private let onOpenDashboard: () -> Void
    private let onOpenDeviceDetail: (String) -> Void
    private var cancellables = Set<AnyCancellable>()
    private var singleClickWorkItem: DispatchWorkItem?
    private var lastClickTimestamp: TimeInterval = 0

    public init(
        state: AppState,
        onOpenDashboard: @escaping () -> Void,
        onOpenDeviceDetail: @escaping (String) -> Void
    ) {
        self.state = state
        self.onOpenDashboard = onOpenDashboard
        self.onOpenDeviceDetail = onOpenDeviceDetail
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        setupPopover()
        setupStatusButton()
        bindTelemetryUpdates()
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 370, height: 535)
        popover.behavior = .transient
        popover.animates = true
        let rootView = MenuBarPopoverView(
            state: state,
            onOpenDashboard: { [weak self] in
                self?.popover.performClose(nil)
                self?.onOpenDashboard()
            },
            onOpenDeviceDetail: { [weak self] devID in
                self?.popover.performClose(nil)
                self?.onOpenDeviceDetail(devID)
            }
        )
        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    private func setupStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusBarClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateButtonImage()
    }

    private func bindTelemetryUpdates() {
        Publishers.CombineLatest3(state.$systemLoadWatts, state.$adapterWatts, state.$externalConnected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateButtonImage()
            }
            .store(in: &cancellables)
    }

    private func updateButtonImage() {
        guard let button = statusItem.button else { return }
        let dcIn = state.externalConnected ? state.adapterWatts : 0.0
        let img = SleepingMacIconView.renderMenuBarStatusImage(
            systemTotalW: state.systemLoadWatts,
            dcInW: dcIn
        )
        button.image = img
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }

        // Right-click hoặc Double-click mở thẳng cửa sổ Dashboard
        let now = Date().timeIntervalSince1970
        if event.type == .rightMouseUp || event.clickCount >= 2 || (now - lastClickTimestamp < 0.30) {
            singleClickWorkItem?.cancel()
            singleClickWorkItem = nil
            lastClickTimestamp = 0
            if popover.isShown {
                popover.performClose(nil)
            }
            onOpenDashboard()
            return
        }

        lastClickTimestamp = now
        singleClickWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, let btn = self.statusItem.button else { return }
            self.togglePopover(btn)
        }
        singleClickWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func togglePopover(_ sender: NSView) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

