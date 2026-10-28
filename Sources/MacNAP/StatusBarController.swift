import AppKit
import SwiftUI
import Combine

@MainActor
public final class StatusBarController: NSObject {
    private var primaryStatusItem: NSStatusItem
    private var secondaryStatusItem: NSStatusItem?
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
        self.primaryStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        setupPopover()
        syncStatusItems()
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

    private func configureButton(_ button: NSStatusBarButton?) {
        guard let button = button else { return }
        button.target = self
        button.action = #selector(handleStatusBarClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func syncStatusItems() {
        if state.menuBarSplitItems {
            let firstTag = state.menuBarTagOrder.first ?? .usage
            let secondTag = (state.menuBarTagOrder.count > 1) ? state.menuBarTagOrder[1] : .charge

            primaryStatusItem.autosaveName = "com.lu.MacNAP.tag.\(firstTag.rawValue)"
            configureButton(primaryStatusItem.button)

            if secondaryStatusItem == nil {
                let sec = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                configureButton(sec.button)
                secondaryStatusItem = sec
            }
            secondaryStatusItem?.autosaveName = "com.lu.MacNAP.tag.\(secondTag.rawValue)"
            configureButton(secondaryStatusItem?.button)
        } else {
            if let sec = secondaryStatusItem {
                NSStatusBar.system.removeStatusItem(sec)
                secondaryStatusItem = nil
            }
            primaryStatusItem.autosaveName = "com.lu.MacNAP.combined"
            configureButton(primaryStatusItem.button)
        }
        updateButtonImages()
    }

    private func bindTelemetryUpdates() {
        Publishers.CombineLatest3(state.$systemLoadWatts, state.$adapterWatts, state.$externalConnected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateButtonImages()
            }
            .store(in: &cancellables)

        state.menuBarConfigChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.syncStatusItems()
            }
            .store(in: &cancellables)
    }

    private func updateButtonImages() {
        let dcIn = state.externalConnected ? state.adapterWatts : 0.0
        let fontSize = CGFloat(state.menuBarFontSize)
        let fontDesign = state.menuBarFontDesign
        let fontWeight = state.menuBarFontWeight
        let labelStyle = state.menuBarLabelStyle
        let layoutMode = state.menuBarLayoutMode

        if state.menuBarSplitItems {
            let firstTag = state.menuBarTagOrder.first ?? .usage
            let secondTag = (state.menuBarTagOrder.count > 1) ? state.menuBarTagOrder[1] : .charge

            let firstWatts = (firstTag == .usage) ? state.systemLoadWatts : dcIn
            let firstCustom = (firstTag == .usage) ? state.menuBarUsageText : state.menuBarChargeText
            primaryStatusItem.button?.image = SleepingMacIconView.renderSingleTagImage(
                tagType: firstTag,
                watts: firstWatts,
                layoutMode: layoutMode,
                labelStyle: labelStyle,
                customLabel: firstCustom,
                fontSize: fontSize,
                fontDesign: fontDesign,
                fontWeight: fontWeight
            )

            let secondWatts = (secondTag == .usage) ? state.systemLoadWatts : dcIn
            let secondCustom = (secondTag == .usage) ? state.menuBarUsageText : state.menuBarChargeText
            secondaryStatusItem?.button?.image = SleepingMacIconView.renderSingleTagImage(
                tagType: secondTag,
                watts: secondWatts,
                layoutMode: layoutMode,
                labelStyle: labelStyle,
                customLabel: secondCustom,
                fontSize: fontSize,
                fontDesign: fontDesign,
                fontWeight: fontWeight
            )
        } else {
            primaryStatusItem.button?.image = SleepingMacIconView.renderCombinedMenuBarStatusImage(
                usageWatts: state.systemLoadWatts,
                chargeWatts: dcIn,
                layoutMode: layoutMode,
                tagOrder: state.menuBarTagOrder,
                labelStyle: labelStyle,
                usageText: state.menuBarUsageText,
                chargeText: state.menuBarChargeText,
                fontSize: fontSize,
                fontDesign: fontDesign,
                fontWeight: fontWeight,
                separator: state.menuBarSeparator
            )
        }
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
            guard let self = self else { return }
            self.togglePopover(sender)
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
