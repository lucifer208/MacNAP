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
                        icon: state.externalConnected ? "bolt.Batteryblock.fill" : "battery.50",
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
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(
                    L.t(
                        "Biểu đồ Phiên Ngủ Thực Tế kiểu Sleep Aid (Sleep / CloseLid)",
                        "Sleep Aid Interactive Timeline (Sleep / CloseLid)"
                    ),
                    systemImage: "moon.stars.fill"
                )
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

                Spacer()

                // Segmented Toggle: Theo lần Sleep / CloseLid vs Theo Ngày (Từ 00:00)
                Picker("", selection: $state.sleepAnalysisMode) {
                    Text(L.t("Theo lần Sleep / CloseLid", "By Sleep / CloseLid")).tag(SleepAnalysisMode.bySession)
                    Text(L.t("Theo Ngày (Từ 00:00)", "By Day (From 00:00)")).tag(SleepAnalysisMode.byDay)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 270)

                if !activeList.isEmpty {
                    Picker("", selection: $state.selectedSessionID) {
                        ForEach(activeList) { session in
                            Text("\(session.titleLabel) (-\(session.dropPercent)% • \(session.darkWakeCount) DarkWake)")
                                .tag(Optional(session.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 265)
                }

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
                        Text(L.t("Đọc lại log", "Reload log"))
                    }
                }
                .disabled(state.isLoadingPmsetLog)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let session = state.currentSleepSession {
                let wakeWithApp = max(0, session.startBattery - max(1, Int(round(state.predictedDropPercentWithFullGuard))))
                let wakeAutoUnmount = max(0, session.startBattery - max(1, Int(round(state.predictedDropPercentWithAutoUnmount))))

                HStack(spacing: 16) {
                    Text(L.t("Phiên ngủ: **\(session.titleLabel)** (\(String(format: "%.1fh", session.durationHours)))", "Session: **\(session.titleLabel)** (\(String(format: "%.1fh", session.durationHours)))"))
                    Text(L.t("Thực tế chưa bật App: **\(session.startBattery)% → \(session.endBattery)% (Mất -\(session.dropPercent)%)**", "Actual Unprotected: **\(session.startBattery)% → \(session.endBattery)% (-\(session.dropPercent)%)**"))
                        .foregroundStyle(.red)
                    Text(L.t("Nếu bật Auto-Unmount: **Còn ~\(wakeAutoUnmount)%**", "With Auto-Unmount: **~\(wakeAutoUnmount)% left**"))
                        .foregroundStyle(.green)
                    Text(L.t("Nếu bật Auto-Unmount + Tắt DarkWake: **Còn ~\(wakeWithApp)% (Chỉ mất ~1%)**", "With Full Guard: **~\(wakeWithApp)% left (~1% loss)**"))
                        .foregroundStyle(.cyan)
                    Spacer()
                }
                .font(.caption)

                let minBat = max(0, session.endBattery - 5)
                let maxBat = min(100, session.startBattery + 2)
                let totalSpan = max(1.0, session.endTime.timeIntervalSince(session.startTime))

                Chart {
                    ForEach(session.events) { ev in
                        let progress = max(0.0, min(1.0, ev.timestamp.timeIntervalSince(session.startTime) / totalSpan))
                        let predictedAutoUnmountPct = Double(session.startBattery) - (progress * state.predictedDropPercentWithAutoUnmount)
                        let predictedFullGuardPct = Double(session.startBattery) - (progress * state.predictedDropPercentWithFullGuard)

                        AreaMark(
                            x: .value("Time", ev.timestamp),
                            yStart: .value("Min", minBat),
                            yEnd: .value("Pin %", ev.batteryPercent)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan.opacity(0.24), .cyan.opacity(0.02)],
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
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        LineMark(
                            x: .value("Time", ev.timestamp),
                            y: .value("Auto-Unmount (%)", predictedAutoUnmountPct),
                            series: .value("Scenario", "Auto-Unmount")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, dash: [6, 3]))

                        LineMark(
                            x: .value("Time", ev.timestamp),
                            y: .value("Full Guard (%)", predictedFullGuardPct),
                            series: .value("Scenario", "Full Guard")
                        )
                        .foregroundStyle(.mint)
                        .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [3, 3]))

                        if ev.kind != .sleep {
                            RuleMark(x: .value("Time", ev.timestamp))
                                .foregroundStyle(ev.kind == .darkWake ? Color.orange.opacity(0.75) : Color.red)
                                .lineStyle(StrokeStyle(lineWidth: selectedTimelineEventID == ev.id ? 3.0 : 1.5))

                            PointMark(
                                x: .value("Time", ev.timestamp),
                                y: .value("Actual (%)", ev.batteryPercent)
                            )
                            .symbolSize(selectedTimelineEventID == ev.id ? 110 : 55)
                            .foregroundStyle(ev.kind == .darkWake ? .orange : .red)
                        } else {
                            PointMark(
                                x: .value("Time", ev.timestamp),
                                y: .value("Actual (%)", ev.batteryPercent)
                            )
                            .symbolSize(selectedTimelineEventID == ev.id ? 90 : 30)
                            .foregroundStyle(.cyan)
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
                .frame(height: 195)
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

                if let ev = state.selectedTimelineEvent {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(ev.kind.rawValue.uppercased())
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background((ev.kind == .darkWake ? Color.orange : (ev.kind == .fullWake ? Color.red : Color.cyan)).opacity(0.2), in: Capsule())
                                    .foregroundStyle(ev.kind == .darkWake ? .orange : (ev.kind == .fullWake ? .red : .cyan))

                                Text(L.t("Thời điểm: \(ev.dateLabel)", "Timestamp: \(ev.dateLabel)"))
                                    .font(.subheadline.bold().monospacedDigit())

                                Text(L.t("• Pin: \(ev.batteryPercent)%", "• Battery: \(ev.batteryPercent)%"))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)

                                if ev.durationSeconds > 0 {
                                    Text(L.t("• Thức: \(ev.durationSeconds) giây", "• Duration: \(ev.durationSeconds)s"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(L.t("Nguyên nhân đánh thức máy: \(ev.triggerReason)", "Wake Trigger: \(ev.triggerReason)"))
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Text("Raw pmset log: \(ev.rawLine)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
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

    // MARK: - Power Log & Assertions
    private var deepLogsAndAssertionsSection: some View {
        let L = state.l10n
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(L.t("Tiến trình giữ máy thức (Assertions)", "Active Sleep Assertions"))
                        .font(.headline)
                    Spacer()
                    Button(L.t("Copy lệnh tắt DarkWake", "Copy Zero-Drain Command")) {
                        state.copyZeroDrainCommand()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if state.assertions.isEmpty {
                    Text(L.t("Không có tiến trình nào đang giữ máy thức.", "No active sleep assertions."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.assertions) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.processName) (PID \(item.pid)) • \(item.duration)")
                                    .font(.caption.bold())
                                    .foregroundStyle(item.isCulprit ? .red : .primary)
                                Text("\(item.assertionType): \(item.detail)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "+%.2f W", item.estimatedWasteWatts))
                                .font(.caption.monospacedDigit().bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15), in: Capsule())
                                .foregroundStyle(.red)
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                }

                Divider()

                Label(
                    L.t("Lịch sử Auto-Unmount / Auto-Remount", "Auto-Unmount / Remount History"),
                    systemImage: "list.bullet.clipboard.fill"
                )
                .font(.headline)

                ForEach(state.actionHistory.prefix(8)) { log in
                    HStack {
                        Circle()
                            .fill(log.success ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(log.timestamp, style: .time)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(log.action)
                            .font(.caption2.bold())
                        Text("• \(log.target):")
                            .font(.caption2)
                        Text(log.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(6)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.cyan)
                    Text(L.t("Nhật ký Nguồn chi tiết (pmset Power Log)", "Detailed pmset Power Log"))
                        .font(.headline)
                    Spacer()
                    Button {
                        state.refreshWakeLogs()
                    } label: {
                        Text(state.isLoadingPmsetLog ? L.t("Đang tải...", "Loading...") : L.t("Làm mới", "Refresh"))
                    }
                    .disabled(state.isLoadingPmsetLog)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    Picker("", selection: $state.selectedLogFilter) {
                        ForEach(PowerLogCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField(L.t("Tìm process/lý do...", "Search process..."), text: $state.logSearchQuery)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.filteredWakeEvents()) { ev in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(ev.category.rawValue)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(badgeColor(for: ev.category).opacity(0.2), in: Capsule())
                                        .foregroundStyle(badgeColor(for: ev.category))

                                    Text(ev.processOrComponent)
                                        .font(.caption2.bold())

                                    Text(ev.timestamp)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text(String(format: "~%.1f W", ev.estimatedImpactWatts))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.orange)

                                    if let pct = ev.batteryPercent {
                                        Text("Pin \(pct)%")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.green)
                                    }
                                }
                                Text(ev.reason)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(8)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(height: 360)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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
