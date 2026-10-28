import SwiftUI
import Charts

public struct DashboardView: View {
    @ObservedObject var state: AppState
    public var onSelectDevice: ((String) -> Void)?

    public init(state: AppState, onSelectDevice: ((String) -> Void)? = nil) {
        self.state = state
        self.onSelectDevice = onSelectDevice
    }

    public var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 265, ideal: 275, max: 295)
        } detail: {
            VStack(spacing: 0) {
                topStatusToolbar
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch state.selectedSection {
                        case .overview:
                            overviewContent
                        case .sleepAid:
                            sleepAidContent
                        case .peripherals:
                            peripheralsContent
                        case .powerLog:
                            powerLogContent
                        }
                    }
                    .padding(24)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 1080, minHeight: 750)
    }

    // MARK: - Sidebar Navigation
    private var sidebarView: some View {
        let L = state.l10n
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                SleepingMacIconView(size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacNAP")
                        .font(.title3.bold())
                    Text("AppleSMC & Sleep Guard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            List(DashboardSection.allCases, selection: $state.selectedSection) { section in
                Label(L.sectionTitle(section), systemImage: section.icon)
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 4)
                    .tag(section)
            }
            .listStyle(.sidebar)

            Divider()

            // Grouped & Perfectly Aligned Sidebar Footer
            VStack(alignment: .leading, spacing: 10) {
                // Cluster 1: Live Power Telemetry
                VStack(spacing: 5) {
                    sidebarMetricRow(
                        icon: "bolt.fill",
                        color: .orange,
                        label: "System Total",
                        value: String(format: "%.2f W", state.systemLoadWatts)
                    )
                    sidebarMetricRow(
                        icon: "cable.connector.horizontal",
                        color: .pink,
                        label: L.t("Ngoại vi (USB/TB)", "Peripherals"),
                        value: String(format: "%.2f W", state.peripheralsTotalWatts)
                    )
                    sidebarMetricRow(
                        icon: "powerplug.fill",
                        color: .green,
                        label: "DC In (Max \(state.macMaxSupportedWatts)W)",
                        value: String(format: "%.2f W", state.externalConnected ? state.adapterWatts : 0.0)
                    )
                    sidebarMetricRow(
                        icon: state.externalConnected ? "bolt.shield.fill" : "battery.50",
                        color: state.externalConnected ? .mint : .yellow,
                        label: L.t("Chế độ nguồn", "Power Mode"),
                        value: state.powerSupplyShortLabel
                    )
                    sidebarMetricRow(
                        icon: "battery.75percent",
                        color: .cyan,
                        label: L.t("Pin hiện tại", "Battery"),
                        value: "\(state.batteryPercent)% (\(state.remainingmAh)mAh)"
                    )
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                // Cluster 2: Bảo vệ Ngủ & Ổ ngoài (Sleep & Drive Guard)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.groupSleepGuard)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)

                    sidebarToggleRow(title: L.autoUnmountSleep, isOn: $state.autoUnmountOnSleep)
                    sidebarToggleRow(title: L.autoRemountWake, isOn: $state.autoRemountOnWake)
                    sidebarActionToggleRow(
                        title: L.disableDarkWakeBattery,
                        isOn: state.disableDarkWakeOnBattery,
                        isLoading: state.isUpdatingDarkWake
                    ) { newValue in
                        state.setDarkWakeDisabled(newValue)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                // Cluster 3: Hệ thống & Giao diện (System & Interface)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.groupSystemPrefs)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)

                    sidebarToggleRow(title: L.launchAtLogin, isOn: $state.launchAtLogin)
                    sidebarToggleRow(title: L.hideDockIcon, isOn: $state.hideDockIcon)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(12)
            .background(.ultraThinMaterial)
        }
    }

    private func sidebarMetricRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16, alignment: .center)
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private func sidebarToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11.5))
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }

    private func sidebarActionToggleRow(
        title: String,
        isOn: Bool,
        isLoading: Bool,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11.5))
                .lineLimit(1)
            Spacer()
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { isOn },
                        set: { onToggle($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
    }

    // MARK: - Top Status Action Bar
    private var topStatusToolbar: some View {
        let L = state.l10n
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.sectionTitle(state.selectedSection))
                    .font(.headline)
                Text(state.lastActionLog)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("", selection: $state.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 125)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    // MARK: - Tab Contents
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            kpiGrid
            realtimeChartsRow
            sleepAidTimelineSection
        }
    }

    private var sleepAidContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            kpiGrid
            sleepAidTimelineSection
        }
    }

    private var peripheralsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            peripheralsKpiRow
            HStack(spacing: 16) {
                peripheralsRealtimeLineCard
                realtimeBarComparisonCard
            }
            peripheralsSection
        }
    }

    private var powerLogContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            deepLogsAndAssertionsSection
        }
    }

    // MARK: - Equal-Height Bento KPI Grid (4 columns, Zero Truncation)
    private var kpiGrid: some View {
        let L = state.l10n
        let s = state.currentSleepSession
        let startBat = s?.startBattery ?? 100
        let endBat = s?.endBattery ?? 80
        let dropPct = s?.dropPercent ?? state.realLastNightDropPercent
        let sleepHours = s?.durationHours ?? state.realLastNightDurationHours
        let darkWakes = s?.darkWakeCount ?? 15
        let avgW = s?.averageDrainWatts ?? state.realLastNightAverageWatts
        let wakeWithApp = state.predictedWakeBatteryPercent
        let savedPoints = state.predictedSavedPercentPoints

        return HStack(spacing: 14) {
            kpiCard(
                title: L.t("CÔNG SUẤT TIÊU THỤ (SYSTEM)", "SYSTEM TOTAL POWER"),
                mainValue: String(format: "%.2f W", state.systemLoadWatts),
                badgeText: L.t("Pin \(state.batteryPercent)%", "Bat \(state.batteryPercent)%"),
                badgeColor: .orange,
                footerLine1: L.t(
                    String(format: "🔌 Thiết bị ngoại vi: %.2f W • Core: %.2f W", state.peripheralsTotalWatts, state.cpuCoreWatts),
                    String(format: "🔌 Peripherals: %.2f W • Core: %.2f W", state.peripheralsTotalWatts, state.cpuCoreWatts)
                ),
                footerLine2: L.t(
                    String(format: "Cổng USB-C Out: %.2f W • Unmount còn: %.2f W", state.portOutWatts, state.peripheralsSleepWatts),
                    String(format: "USB-C Out: %.2f W • Standby: %.2f W", state.portOutWatts, state.peripheralsSleepWatts)
                ),
                icon: "bolt.fill",
                accent: .orange
            )

            kpiCard(
                title: L.kpiDCIn,
                mainValue: state.externalConnected
                    ? String(format: "%.2f W", state.adapterWatts)
                    : L.t("0.00 W", "0.00 W"),
                badgeText: "Max \(state.macMaxSupportedWatts)W",
                badgeColor: .green,
                footerLine1: state.powerSupplyStatusText,
                footerLine2: L.t(
                    state.externalConnected
                        ? "Máy hỗ trợ tối đa: \(state.macMaxSupportedWatts)W • Củ sạc đang cắm: \(state.adapterMaxWatts)W"
                        : "Máy hỗ trợ sạc tối đa: \(state.macMaxSupportedWatts)W (\(state.macModelSummary))",
                    state.externalConnected
                        ? "Mac Max: \(state.macMaxSupportedWatts)W • Connected Brick: \(state.adapterMaxWatts)W"
                        : "Mac Max Supported: \(state.macMaxSupportedWatts)W (\(state.macModelSummary))"
                ),
                icon: state.externalConnected ? "powerplug.fill" : "battery.75percent",
                accent: .green
            )

            kpiCard(
                title: state.sleepAnalysisMode == .bySession
                    ? L.t("HAO PIN KHI SLEEP / CLOSELID", "SLEEP / CLOSELID DRAIN")
                    : L.t("HAO PIN THEO NGÀY (TỪ 00:00)", "DAILY DRAIN (FROM 00:00)"),
                mainValue: L.t("Mất -\(dropPct)% Pin", "Lost -\(dropPct)%"),
                badgeText: "\(startBat)% → \(endBat)%",
                badgeColor: .red,
                footerLine1: L.t(
                    String(format: "Ngủ %.1f giờ • %d lần DarkWake", sleepHours, darkWakes),
                    String(format: "%.1fh sleep • %d DarkWakes", sleepHours, darkWakes)
                ),
                footerLine2: L.t(
                    String(format: "Công suất rò trung bình: %.2f W", avgW),
                    String(format: "Average sleep drain: %.2f W", avgW)
                ),
                icon: "bed.double.fill",
                accent: .red
            )

            kpiCard(
                title: L.t("DỰ ĐOÁN KHI BẬT MACNAP", "WITH MACNAP GUARD"),
                mainValue: L.t("Chỉ mất ~1% Pin", "Only ~1% Loss"),
                badgeText: "\(startBat)% → ~\(wakeWithApp)%",
                badgeColor: .cyan,
                footerLine1: L.t(
                    "Giữ lại +\(savedPoints)% pin mỗi đêm",
                    "Saves +\(savedPoints)% battery per night"
                ),
                footerLine2: L.t(
                    "Khi bật Auto-Unmount & chặn DarkWake",
                    "With Auto-Unmount & DarkWake off"
                ),
                icon: "sparkles",
                accent: .cyan
            )
        }
    }

    private func kpiCard(
        title: String,
        mainValue: String,
        badgeText: String,
        badgeColor: Color,
        footerLine1: String,
        footerLine2: String,
        icon: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))

                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(mainValue)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 4)

                Text(badgeText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(badgeColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 8)

            Divider()
                .padding(.bottom, 7)

            VStack(alignment: .leading, spacing: 3) {
                Text(footerLine1)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(footerLine2)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 142, maxHeight: 142, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
                LinearGradient(
                    colors: [accent.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Charts Row
    private var realtimeChartsRow: some View {
        let L = state.l10n
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        L.t("Biểu đồ AppleSMC Realtime (1.0s): System Total vs DC In", "Realtime AppleSMC (1.0s): System Total vs DC In"),
                        systemImage: "waveform.path.ecg"
                    )
                    .font(.headline)
                    Spacer()
                    Text(L.t("Chu kỳ 1.0 giây", "1.0s interval"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Chart {
                    ForEach(state.samples) { sample in
                        AreaMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("Watts", sample.systemLoadWatts)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange.opacity(0.28), .orange.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("System Total (W)", sample.systemLoadWatts),
                            series: .value("Type", "System Total")
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("DC In (W)", sample.adapterInputWatts),
                            series: .value("Type", "DC In")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [5, 3]))
                    }
                }
                .chartYAxisLabel("Watts (W)")
                .frame(height: 205)

                HStack(spacing: 18) {
                    legendDot(color: .orange, label: String(format: "System Total (PSTR): %.2f W", state.systemLoadWatts))
                    legendDot(color: .green, label: String(format: "DC In (PDTR): %.2f W", state.externalConnected ? state.adapterWatts : 0.0))
                    legendDot(color: .cyan, label: String(format: "TB Right: %.2f W • TB Left: %.2f W", state.tbRightWatts, state.tbLeftWatts))
                }
                .font(.caption2)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            realtimeBarComparisonCard
        }
    }

    private var realtimeBarComparisonCard: some View {
        let L = state.l10n
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    L.t("Công suất từng thiết bị: Đang chạy vs Sau khi Unmount", "Device Power: Active vs Unmounted Standby"),
                    systemImage: "chart.bar.xaxis"
                )
                .font(.headline)
                Spacer()
            }

            Chart {
                ForEach(state.peripherals.prefix(7)) { dev in
                    BarMark(
                        x: .value("Watts", dev.watts),
                        y: .value("Device", dev.name)
                    )
                    .foregroundStyle(.pink)
                    .position(by: .value("Mode", "Active"))
                    .annotation(position: .trailing) {
                        Text(String(format: "%.2fW", dev.watts))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    BarMark(
                        x: .value("Watts", dev.sleepWatts),
                        y: .value("Device", dev.name)
                    )
                    .foregroundStyle(.indigo.opacity(0.85))
                    .position(by: .value("Mode", "Standby"))
                }
            }
            .chartXAxisLabel("Watts (W)")
            .frame(height: 205)

            HStack(spacing: 16) {
                legendDot(color: .pink, label: L.t("Đang hoạt động (Active)", "Active Mounted"))
                legendDot(color: .indigo, label: L.t("Sau khi Auto-Unmount (Standby)", "Unmounted Standby"))
            }
            .font(.caption2)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Sleep Aid Interactive Timeline
    private var sleepAidTimelineSection: some View {
        let L = state.l10n
        let activeList = state.activeSleepSessionList
        return VStack(alignment: .leading, spacing: 14) {
            // Row 1: Title + Mode Switcher + Reload Button (No collision)
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.cyan)
                        .frame(width: 28, height: 28)
                        .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(
                            L.t(
                                "Biểu đồ Phiên Ngủ Thực Tế kiểu Sleep Aid (Sleep / CloseLid)",
                                "Sleep Aid Interactive Timeline (Sleep / CloseLid)"
                            )
                        )
                        .font(.headline)
                        .lineLimit(1)

                        Text(
                            L.t(
                                "Nhấn vào biểu đồ hoặc dùng nút ◀ ▶ bên dưới để soi chi tiết từng lần thức ngầm (DarkWake)",
                                "Click anywhere on the chart or use ◀ ▶ buttons below to inspect each DarkWake event"
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }

                Spacer()

                Picker("", selection: $state.sleepAnalysisMode) {
                    Text(L.t("Theo lần Sleep / CloseLid", "By Sleep / CloseLid")).tag(SleepAnalysisMode.bySession)
                    Text(L.t("Theo Ngày (Từ 00:00)", "By Day (From 00:00)")).tag(SleepAnalysisMode.byDay)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize(horizontal: true, vertical: false)

                Button {
                    state.refreshWakeLogs()
                } label: {
                    if state.isLoadingPmsetLog {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L.t("Đang đọc...", "Loading..."))
                        }
                    } else {
                        Label(L.t("Đọc lại log", "Reload log"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(state.isLoadingPmsetLog)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let session = state.currentSleepSession {
                let wakeWithApp = max(0, session.startBattery - max(1, Int(round(state.predictedDropPercentWithFullGuard))))
                let wakeAutoUnmount = max(0, session.startBattery - max(1, Int(round(state.predictedDropPercentWithAutoUnmount))))
                let autoUnmountDrop = max(1, session.startBattery - wakeAutoUnmount)
                let fullGuardDrop = max(1, session.startBattery - wakeWithApp)

                // Row 2: Session Dropdown + 3 Clean Comparison Pill Cards
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(L.t("Phiên ngủ:", "Session:"))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        if !activeList.isEmpty {
                            Picker("", selection: $state.selectedSessionID) {
                                ForEach(activeList) { item in
                                    Text("\(item.titleLabel) (\(String(format: "%.1fh", item.durationHours)) • -\(item.dropPercent)% • \(item.darkWakeCount) DarkWake)")
                                        .tag(Optional(item.id))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 320)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))

                    Spacer()

                    sleepScenarioPill(
                        dotColor: .cyan,
                        title: L.t("Thực tế (Chưa bật App)", "Actual (Unprotected)"),
                        value: "\(session.startBattery)% → \(session.endBattery)% (-\(session.dropPercent)%)",
                        valueColor: .red
                    )

                    sleepScenarioPill(
                        dotColor: .green,
                        title: L.t("Khi bật Auto-Unmount", "With Auto-Unmount"),
                        value: L.t("Còn ~\(wakeAutoUnmount)% (-\(autoUnmountDrop)%)", "~\(wakeAutoUnmount)% left (-\(autoUnmountDrop)%)"),
                        valueColor: .green
                    )

                    sleepScenarioPill(
                        dotColor: .mint,
                        title: L.t("Auto-Unmount + Chặn DarkWake", "Full Guard (No DarkWake)"),
                        value: L.t("Còn ~\(wakeWithApp)% (-\(fullGuardDrop)%)", "~\(wakeWithApp)% left (-\(fullGuardDrop)%)"),
                        valueColor: .mint
                    )
                }

                let minBat = max(0, session.endBattery - 5)
                let maxBat = min(100, session.startBattery + 2)
                let totalSpan = max(1.0, session.endTime.timeIntervalSince(session.startTime))
                let tickHeight = max(2, Int(Double(maxBat - minBat) * 0.10))

                // Row 3: Clean Interactive Chart (No chaotic prison bars)
                Chart {
                    ForEach(session.events) { ev in
                        let progress = max(0.0, min(1.0, ev.timestamp.timeIntervalSince(session.startTime) / totalSpan))
                        let predictedAutoUnmountPct = Double(session.startBattery) - (progress * state.predictedDropPercentWithAutoUnmount)
                        let predictedFullGuardPct = Double(session.startBattery) - (progress * state.predictedDropPercentWithFullGuard)
                        let isSelected = (selectedTimelineEventID == ev.id)

                        AreaMark(
                            x: .value("Time", ev.timestamp),
                            yStart: .value("Min", minBat),
                            yEnd: .value("Pin %", ev.batteryPercent)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan.opacity(0.22), .cyan.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Time", ev.timestamp),
                            y: .value("Actual (%)", ev.batteryPercent),
                            series: .value("Scenario", "Actual")
                        )
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2.6))

                        LineMark(
                            x: .value("Time", ev.timestamp),
                            y: .value("Auto-Unmount (%)", predictedAutoUnmountPct),
                            series: .value("Scenario", "Auto-Unmount")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [6, 4]))

                        LineMark(
                            x: .value("Time", ev.timestamp),
                            y: .value("Full Guard (%)", predictedFullGuardPct),
                            series: .value("Scenario", "Full Guard")
                        )
                        .foregroundStyle(.mint)
                        .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [3, 3]))

                        // Thanh vạch nhỏ gọn ở đáy biểu đồ thể hiện mật độ DarkWake mà không che khuất đường Pin
                        if ev.kind != .sleep {
                            RuleMark(
                                x: .value("Time", ev.timestamp),
                                yStart: .value("TickStart", minBat),
                                yEnd: .value("TickEnd", minBat + tickHeight)
                            )
                            .foregroundStyle(ev.kind == .darkWake ? Color.orange.opacity(0.55) : Color.red.opacity(0.75))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }

                        // Chỉ vẽ đường gióng thẳng đứng (Crosshair) cho đúng sự kiện đang được chọn
                        if isSelected {
                            RuleMark(x: .value("Time", ev.timestamp))
                                .foregroundStyle(ev.kind == .darkWake ? Color.orange : Color.cyan)
                                .lineStyle(StrokeStyle(lineWidth: 2.2, dash: [4, 3]))

                            PointMark(
                                x: .value("Time", ev.timestamp),
                                y: .value("Actual (%)", ev.batteryPercent)
                            )
                            .symbolSize(130)
                            .foregroundStyle(ev.kind == .darkWake ? .orange : (ev.kind == .fullWake ? .red : .cyan))
                        } else if ev.kind != .sleep {
                            PointMark(
                                x: .value("Time", ev.timestamp),
                                y: .value("Actual (%)", ev.batteryPercent)
                            )
                            .symbolSize(28)
                            .foregroundStyle(ev.kind == .darkWake ? Color.orange.opacity(0.85) : Color.red)
                        }
                    }
                }
                .chartYScale(domain: minBat...maxBat)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 9)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxisLabel("% Pin")
                .frame(height: 205)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let xPos = location.x - geo[plotFrame].origin.x
                                if let tappedDate: Date = proxy.value(atX: xPos) {
                                    if let nearest = session.events.min(by: {
                                        abs($0.timestamp.timeIntervalSince(tappedDate)) < abs($1.timestamp.timeIntervalSince(tappedDate))
                                    }) {
                                        state.selectedTimelineEvent = nearest
                                    }
                                }
                            }
                    }
                }

                // Row 4: Clean Structured Event Inspector Bar
                if let ev = state.selectedTimelineEvent {
                    let curIndex = (session.events.firstIndex(where: { $0.id == ev.id }) ?? 0) + 1
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text(ev.kind.rawValue.uppercased())
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background((ev.kind == .darkWake ? Color.orange : (ev.kind == .fullWake ? Color.red : Color.cyan)).opacity(0.2), in: Capsule())
                                .foregroundStyle(ev.kind == .darkWake ? .orange : (ev.kind == .fullWake ? .red : .cyan))

                            Label(ev.dateLabel, systemImage: "clock.fill")
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))

                            Text(L.t("Pin \(ev.batteryPercent)%", "Bat \(ev.batteryPercent)%"))
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2.5)
                                .background(Color.green.opacity(0.16), in: Capsule())
                                .foregroundStyle(.green)

                            if ev.durationSeconds > 0 {
                                Text(L.t("Thức ngầm: \(ev.durationSeconds) giây", "Awake: \(ev.durationSeconds)s"))
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2.5)
                                    .background(Color.primary.opacity(0.07), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(L.t("Sự kiện \(curIndex)/\(session.events.count)", "Event \(curIndex)/\(session.events.count)"))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Button {
                                    state.stepTimelineEvent(delta: -1)
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button {
                                    state.stepTimelineEvent(delta: 1)
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .foregroundStyle(ev.kind == .darkWake ? .orange : .cyan)
                            Text(L.t("Nguyên nhân:", "Trigger:"))
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(ev.triggerReason)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                        }

                        HStack(spacing: 6) {
                            Text("pmset:")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(ev.rawLine)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                }
            } else {
                Text(L.t("Đang phân tích dữ liệu phiên ngủ từ pmset log ở luồng ngầm...", "Parsing sleep sessions from pmset log in background..."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func sleepScenarioPill(
        dotColor: Color,
        title: String,
        value: String,
        valueColor: Color
    ) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
    }

    private var selectedTimelineEventID: UUID? {
        state.selectedTimelineEvent?.id
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Peripherals Realtime KPI & Live Chart
    private var peripheralsKpiRow: some View {
        let L = state.l10n
        let totalPeriphmA = state.peripherals.reduce(0) { $0 + $1.currentmA }
        let savedW = max(0.0, state.peripheralsTotalWatts - state.peripheralsSleepWatts)
        let pctOfSystem = Int(round((state.peripheralsTotalWatts / max(1.0, state.systemLoadWatts)) * 100.0))

        return HStack(spacing: 14) {
            kpiCard(
                title: L.t("TỔNG TIÊU THỤ NGOẠI VI (REALTIME 1.0S)", "TOTAL PERIPHERALS POWER (LIVE 1.0S)"),
                mainValue: String(format: "%.2f W", state.peripheralsTotalWatts),
                badgeText: "● LIVE 1.0s",
                badgeColor: .pink,
                footerLine1: L.t(
                    "Tổng dòng tải USB/TB: \(totalPeriphmA) mA (\(state.peripherals.count) thiết bị)",
                    "Total USB/TB current: \(totalPeriphmA) mA (\(state.peripherals.count) devices)"
                ),
                footerLine2: L.t(
                    String(format: "Cổng USB-C Out (Hardware): %.2f W • TB R/L: %.2f W", state.portOutWatts, state.tbLeftWatts + state.tbRightWatts),
                    String(format: "USB-C Port Out: %.2f W • TB R/L: %.2f W", state.portOutWatts, state.tbLeftWatts + state.tbRightWatts)
                ),
                icon: "cable.connector.horizontal",
                accent: .pink
            )

            kpiCard(
                title: L.t("SAU KHI AUTO-UNMOUNT (STANDBY)", "AFTER AUTO-UNMOUNT (STANDBY)"),
                mainValue: String(format: "%.2f W", state.peripheralsSleepWatts),
                badgeText: String(format: "-%.2f W", savedW),
                badgeColor: .green,
                footerLine1: L.t(
                    String(format: "Tiết kiệm ngay %.2f W khi Sleep / CloseLid", savedW),
                    String(format: "Saves %.2f W immediately on Sleep / CloseLid", savedW)
                ),
                footerLine2: L.t(
                    "Tự động ngắt phân vùng ổ ngoài, đưa NVMe/SSD về Standby",
                    "Auto-unmounts external partitions into low-power Standby"
                ),
                icon: "leaf.fill",
                accent: .green
            )

            kpiCard(
                title: L.t("TỶ TRỌNG NGOẠI VI / SYSTEM TOTAL", "PERIPHERALS VS SYSTEM TOTAL"),
                mainValue: "\(pctOfSystem)% System",
                badgeText: String(format: "%.2fW / %.2fW", state.peripheralsTotalWatts, state.systemLoadWatts),
                badgeColor: .cyan,
                footerLine1: L.t(
                    String(format: "Ngoại vi: %.2f W • Hệ thống Core: %.2f W", state.peripheralsTotalWatts, state.cpuCoreWatts),
                    String(format: "Peripherals: %.2f W • Core System: %.2f W", state.peripheralsTotalWatts, state.cpuCoreWatts)
                ),
                footerLine2: state.powerSupplyStatusText,
                icon: "gauge.with.dots.needle.67percent",
                accent: .cyan
            )
        }
    }

    private var peripheralsRealtimeLineCard: some View {
        let L = state.l10n
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    L.t("Biểu đồ Công suất Ngoại vi Realtime (1.0s)", "Realtime Peripherals Power (1.0s)"),
                    systemImage: "waveform.path.ecg"
                )
                .font(.headline)
                Spacer()
                Text("● LIVE 1.0s")
                    .font(.caption2.bold())
                    .foregroundStyle(.pink)
            }

            Chart {
                ForEach(state.samples) { sample in
                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Peripherals (W)", sample.peripheralsWatts)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink.opacity(0.30), .pink.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Peripherals (W)", sample.peripheralsWatts),
                        series: .value("Type", "Peripherals")
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .chartYAxisLabel("Watts (W)")
            .frame(height: 205)

            HStack(spacing: 16) {
                legendDot(color: .pink, label: String(format: "Ngoại vi Realtime: %.2f W", state.peripheralsTotalWatts))
                legendDot(color: .cyan, label: String(format: "USB-C Port Out: %.2f W", state.portOutWatts))
                legendDot(color: .green, label: String(format: "Standby sau Unmount: %.2f W", state.peripheralsSleepWatts))
            }
            .font(.caption2)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Peripherals List
    private var peripheralsSection: some View {
        let L = state.l10n
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    L.t(
                        "Danh sách Thiết bị Ngoại vi & Công suất Tiêu thụ Realtime (Nhấn vào thiết bị để mở Chart & Log riêng)",
                        "Connected Peripherals & Realtime Watt Telemetry (Click any device for dedicated Chart & Log)"
                    ),
                    systemImage: "externaldrive.connected.to.line.below.fill"
                )
                .font(.headline)
                Spacer()
                Text(L.t("● Đang đo Realtime 1.0s", "● Live 1.0s Telemetry"))
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Button(L.t("Quét lại", "Rescan")) {
                    state.refreshAll(forcePartitionScan: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(state.peripherals) { dev in
                HStack(spacing: 14) {
                    Image(systemName: dev.kind.iconName)
                        .font(.title3)
                        .foregroundStyle(dev.canUnmount ? (dev.isMounted ? .pink : .green) : .cyan)
                        .frame(width: 34, height: 34)
                        .background((dev.canUnmount ? Color.pink : Color.cyan).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(dev.name)
                                .font(.subheadline.bold())
                            Text(dev.kind.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                            if dev.canUnmount {
                                Text(dev.isMounted ? L.t("Đang Mount", "Mounted") : L.t("Đã Unmount (Standby)", "Unmounted (Standby)"))
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((dev.isMounted ? Color.orange : Color.green).opacity(0.2), in: Capsule())
                                    .foregroundStyle(dev.isMounted ? .orange : .green)
                            }
                            Text("● LIVE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.green.opacity(0.16), in: Capsule())
                                .foregroundStyle(.green)
                        }
                        Text("Vendor: \(dev.vendor) • \(dev.speedDescription) • Realtime: \(dev.currentmA) mA @ \(String(format: "%.2fV", dev.voltageV)) (Standby: \(dev.sleepCurrentmA) mA)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f W", dev.watts))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(dev.watts >= 2.0 ? .pink : .cyan)
                        Text(String(format: "%d mA • Standby: %.2f W", dev.currentmA, dev.sleepWatts))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        onSelectDevice?(dev.id)
                    } label: {
                        Label("Chart & Log", systemImage: "chart.xyaxis.line")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if dev.canUnmount, dev.bsdName != nil {
                        Button(dev.isMounted ? "Unmount" : L.t("Mount lại", "Mount")) {
                            state.toggleMount(for: dev)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(dev.isMounted ? .pink : .green)
                        .controlSize(.small)
                        .frame(width: 92)
                    } else {
                        Text("SMC / USB Bus")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 92, alignment: .trailing)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectDevice?(dev.id)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Power Log, Assertions & Crash Diagnostic Logger
    private var deepLogsAndAssertionsSection: some View {
        let L = state.l10n
        let totalWasteW = state.assertions.reduce(0.0) { $0 + $1.estimatedWasteWatts }
        let culpritCount = state.assertions.filter(\.isCulprit).count

        return VStack(alignment: .leading, spacing: 16) {
            // 1. Top 3 Equal-Height Diagnostic KPI Cards
            HStack(spacing: 14) {
                kpiCard(
                    title: L.t("TIẾN TRÌNH GIỮ MÁY THỨC (ASSERTIONS)", "ACTIVE SLEEP ASSERTIONS"),
                    mainValue: L.t("\(state.assertions.count) Tiến trình", "\(state.assertions.count) Processes"),
                    badgeText: String(format: "+%.2f W", totalWasteW),
                    badgeColor: culpritCount > 0 ? .red : .green,
                    footerLine1: culpritCount > 0
                        ? L.t("Phát hiện \(culpritCount) tiến trình ngăn máy vào Deep Sleep", "\(culpritCount) processes preventing Deep Sleep")
                        : L.t("Không có tiến trình nào chặn Deep Sleep", "No processes blocking Deep Sleep"),
                    footerLine2: L.t("Tự động làm sạch mô tả XPC từ pmset assertions", "Cleaned process assertions from pmset"),
                    icon: "exclamationmark.triangle.fill",
                    accent: culpritCount > 0 ? .red : .green
                )

                kpiCard(
                    title: L.t("BẢO VỆ SLEEP / CLOSELID & DARKWAKE", "SLEEP / CLOSELID & DARKWAKE GUARD"),
                    mainValue: state.disableDarkWakeOnBattery
                        ? L.t("Đã chặn DarkWake", "DarkWake Blocked")
                        : L.t("DarkWake Đang mở", "DarkWake Active"),
                    badgeText: state.autoUnmountOnSleep ? "Auto-Unmount ON" : "Manual",
                    badgeColor: state.disableDarkWakeOnBattery ? .green : .orange,
                    footerLine1: L.t(
                        "Đã ghi nhận \(state.actionHistory.count) thao tác Unmount / Remount",
                        "\(state.actionHistory.count) Unmount / Remount actions recorded"
                    ),
                    footerLine2: L.t(
                        "Gập nắp (CloseLid) & Sleep luôn đồng bộ tức thì",
                        "CloseLid & Sleep hardware transitions unified"
                    ),
                    icon: "shield.lefthalf.filled",
                    accent: .cyan
                )

                kpiCard(
                    title: L.t("NHẬT KÝ HOẠT ĐỘNG & BẪY LỖI CRASH", "ACTIVITY & CRASH DIAGNOSTIC LOG"),
                    mainValue: L.t("\(state.appDiagnosticLogs.count) Dòng Log", "\(state.appDiagnosticLogs.count) Log Entries"),
                    badgeText: "● Crash Guard ON",
                    badgeColor: .mint,
                    footerLine1: L.t(
                        "Ghi trực tiếp xuống: logs/macnap-activity.log",
                        "Synced to disk: logs/macnap-activity.log"
                    ),
                    footerLine2: L.t(
                        "Bắt tự động NSException + SIGABRT / SIGSEGV / SIGBUS",
                        "Captures NSException + SIGABRT / SIGSEGV / SIGBUS"
                    ),
                    icon: "doc.badge.gearshape.fill",
                    accent: .mint
                )
            }

            // 2. Quick Diagnostic File Toolbar
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.mint)
                Text(L.t("File Log Chẩn đoán:", "Diagnostic Log File:"))
                    .font(.caption.bold())
                Text(AppDiagnosticLogger.shared.primaryLogURL.path)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    state.openDiagnosticLogInFinder()
                } label: {
                    Label(L.t("Mở file Log (Finder)", "Show Log in Finder"), systemImage: "folder.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.small)

                Button {
                    state.copyDiagnosticLogPath()
                } label: {
                    Label(L.t("Copy đường dẫn Log", "Copy Log Path"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    state.copyZeroDrainCommand()
                } label: {
                    Label(L.t("Copy lệnh tắt DarkWake", "Copy Zero-Drain Cmd"), systemImage: "bolt.slash.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // 3. Symmetrical 2-Column Equal-Height (470pt) Panels
            HStack(alignment: .top, spacing: 16) {
                // LEFT PANEL: Clean Assertions + Auto-Unmount History
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(
                            L.t("Tiến trình giữ máy thức & Lịch sử Bảo vệ", "Active Sleep Blockers & Guard History"),
                            systemImage: "cpu.fill"
                        )
                        .font(.headline)
                        Spacer()
                        Button {
                            state.refreshAll(forcePartitionScan: true)
                        } label: {
                            Label(L.t("Quét lại", "Rescan"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if state.assertions.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                    Text(L.t("Không có tiến trình nào đang giữ máy thức.", "No active sleep assertions."))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            } else {
                                ForEach(state.assertions) { item in
                                    HStack(spacing: 10) {
                                        Image(systemName: iconForAssertionProcess(item.processName))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(item.isCulprit ? .orange : .cyan)
                                            .frame(width: 28, height: 28)
                                            .background(
                                                (item.isCulprit ? Color.orange : Color.cyan).opacity(0.14),
                                                in: RoundedRectangle(cornerRadius: 7)
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(item.processName)
                                                    .font(.system(size: 12.5, weight: .bold))
                                                    .foregroundStyle(.primary)
                                                Text("PID \(item.pid)")
                                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1.5)
                                                    .background(Color.primary.opacity(0.08), in: Capsule())
                                                    .foregroundStyle(.secondary)
                                                Text(item.duration)
                                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(item.detail)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(String(format: "+%.2f W", item.estimatedWasteWatts))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background((item.isCulprit ? Color.red : Color.orange).opacity(0.15), in: Capsule())
                                            .foregroundStyle(item.isCulprit ? .red : .orange)
                                    }
                                    .padding(10)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                                }
                            }

                            Divider()
                                .padding(.vertical, 4)

                            Text(L.t("LỊCH SỬ AUTO-UNMOUNT / REMOUNT GẦN ĐÂY", "RECENT AUTO-UNMOUNT / REMOUNT HISTORY"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)

                            ForEach(state.actionHistory.prefix(10)) { log in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(log.success ? Color.green : Color.red)
                                        .frame(width: 7, height: 7)
                                    Text(log.timestamp, style: .time)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(log.action)
                                        .font(.system(size: 11, weight: .bold))
                                    Text("• \(log.target):")
                                        .font(.system(size: 11, weight: .medium))
                                    Text(log.detail)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 7))
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 465, maxHeight: 465, alignment: .topLeading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // RIGHT PANEL: Dual Mode Viewer (MacNAP Activity & Crash Log vs pmset Power Log)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Picker("", selection: $state.selectedRightLogMode) {
                            Text(L.t("🛠 Nhật ký App & Crash Guard", "🛠 App Activity & Crash Log")).tag(0)
                            Text(L.t("⚡ Nhật ký Nguồn (pmset)", "⚡ pmset Power Log")).tag(1)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)

                        Spacer()

                        if state.selectedRightLogMode == 0 {
                            Button {
                                state.clearDiagnosticLogs()
                            } label: {
                                Label(L.t("Xoá Log", "Clear"), systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button {
                                state.refreshWakeLogs()
                            } label: {
                                Text(state.isLoadingPmsetLog ? L.t("Đang tải...", "Loading...") : L.t("Làm mới", "Refresh"))
                            }
                            .disabled(state.isLoadingPmsetLog)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if state.selectedRightLogMode == 0 {
                        // Mode 0: MacNAP Persistent Activity & Crash Log
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(state.appDiagnosticLogs) { entry in
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 7) {
                                            Text(entry.level.rawValue)
                                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1.5)
                                                .background(diagnosticLevelColor(entry.level).opacity(0.18), in: Capsule())
                                                .foregroundStyle(diagnosticLevelColor(entry.level))

                                            Text("[\(entry.component)]")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.cyan)

                                            Spacer()

                                            Text(entry.timeString)
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(entry.message)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.primary.opacity(0.9))
                                            .textSelection(.enabled)
                                    }
                                    .padding(8)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                                }
                            }
                        }
                    } else {
                        // Mode 1: Clean pmset Power Log
                        HStack(spacing: 8) {
                            Picker("", selection: $state.selectedLogFilter) {
                                ForEach(PowerLogCategory.allCases, id: \.self) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)

                            TextField(L.t("Tìm process/lý do...", "Search..."), text: $state.logSearchQuery)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 145)
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(state.filteredWakeEvents()) { ev in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 7) {
                                            Text(ev.category.rawValue)
                                                .font(.system(size: 9.5, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1.5)
                                                .background(badgeColor(for: ev.category).opacity(0.2), in: Capsule())
                                                .foregroundStyle(badgeColor(for: ev.category))

                                            Text(ev.processOrComponent)
                                                .font(.system(size: 11, weight: .bold))

                                            Spacer()

                                            if let pct = ev.batteryPercent {
                                                Text("Pin \(pct)%")
                                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.green)
                                            }

                                            Text(ev.timestamp)
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(ev.reason)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .textSelection(.enabled)
                                    }
                                    .padding(8)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 465, maxHeight: 465, alignment: .topLeading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func iconForAssertionProcess(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("audio") { return "speaker.wave.2.fill" }
        if lower.contains("safari") || lower.contains("webkit") { return "safari.fill" }
        if lower.contains("windowserver") { return "display" }
        if lower.contains("sharing") || lower.contains("handoff") { return "antenna.radiowaves.left.and.right" }
        if lower.contains("powerd") { return "bolt.shield.fill" }
        return "cpu"
    }

    private func diagnosticLevelColor(_ level: DiagnosticLogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .action: return .green
        case .sleepLid: return .cyan
        case .warn: return .orange
        case .error, .crash: return .red
        }
    }

    private func badgeColor(for category: PowerLogCategory) -> Color {
        switch category {
        case .darkWake: return .orange
        case .wake: return .red
        case .sleep: return .green
        case .assertion: return .yellow
        case .all: return .blue
        }
    }
}
