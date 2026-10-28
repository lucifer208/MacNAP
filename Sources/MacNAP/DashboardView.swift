import SwiftUI
import Charts

public struct DashboardView: View {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 235, ideal: 250, max: 270)
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
        .frame(minWidth: 1060, minHeight: 740)
    }

    // MARK: - Sidebar Navigation
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                SleepingMacIconView(size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacNAP")
                        .font(.title3.bold())
                    Text("SMC & Sleep Guard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            List(DashboardSection.allCases, selection: $state.selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 4)
                    .tag(section)
            }
            .listStyle(.sidebar)

            Divider()

            // Live Mini Telemetry & Quick Settings inside Sidebar footer
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("System Total", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(String(format: "%.2f W", state.systemLoadWatts))
                        .font(.caption.monospacedDigit().bold())
                }

                HStack {
                    Label("DC In (Adapter)", systemImage: "powerplug.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Text(String(format: "%.2f W", state.externalConnected ? state.adapterWatts : 0.0))
                        .font(.caption.monospacedDigit().bold())
                }

                HStack {
                    Label("Pin hiện tại", systemImage: "battery.75percent")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Spacer()
                    Text("\(state.batteryPercent)% (\(state.remainingmAh) mAh)")
                        .font(.caption.monospacedDigit().bold())
                }

                Divider()

                Toggle("Khởi động cùng máy", isOn: $state.launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)

                Toggle("Ẩn icon trên thanh Dock", isOn: $state.hideDockIcon)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)

                Toggle("Tự Unmount khi ngủ", isOn: $state.autoUnmountOnSleep)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)

                Toggle("Tự Mount khi mở nắp", isOn: $state.autoRemountOnWake)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)
            }
            .padding(14)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Top Status Action Bar
    private var topStatusToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.selectedSection.rawValue)
                    .font(.headline)
                Text(state.lastActionLog)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                state.unmountAllNow()
            } label: {
                Label("Unmount ổ ngoài", systemImage: "arrow.down.doc.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button {
                state.remountAllNow()
            } label: {
                Label("Mount lại ngay", systemImage: "arrow.up.doc.fill")
            }
            .buttonStyle(.bordered)
            .tint(.green)
            .controlSize(.regular)

            Button {
                state.unmountAndSleepMacNow()
            } label: {
                Label("Unmount & Ngủ ngay (Zzz)", systemImage: "moon.zzz.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .controlSize(.regular)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    // MARK: - Tab 1: Overview & Realtime SMC
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            kpiGrid
            realtimeChartsRow
            sleepAidCompactPreview
        }
    }

    // MARK: - Tab 2: Sleep Aid Full Timeline
    private var sleepAidContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            kpiGrid
            sleepAidTimelineSection
        }
    }

    // MARK: - Tab 3: Peripherals & Auto-Unmount
    private var peripheralsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            peripheralsSection
            realtimeBarComparisonCard
        }
    }

    // MARK: - Tab 4: Power Log & Assertions
    private var powerLogContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            deepLogsAndAssertionsSection
        }
    }

    // MARK: - Shared KPI Cards
    private var kpiGrid: some View {
        let lastSession = state.currentSleepSession
        return HStack(spacing: 14) {
            kpiCard(
                title: "System Total (SMC PSTR)",
                value: String(format: "%.2f W", state.systemLoadWatts),
                subtitle: String(format: "TB Right: %.2fW • TB Left: %.2fW • Pin: %d%%", state.tbRightWatts, state.tbLeftWatts, state.batteryPercent),
                icon: "bolt.fill",
                color: .orange
            )

            kpiCard(
                title: "DC In (SMC PDTR)",
                value: state.externalConnected
                    ? String(format: "%.2f W", state.adapterWatts)
                    : "0.00 W (Dùng Pin)",
                subtitle: state.externalConnected
                    ? String(format: "Adapter Max %dW • Battery Rail: %.2fW", state.adapterMaxWatts, state.batteryNetWatts)
                    : String(format: "Đang xả từ Pin: -%.2f W", abs(state.batteryNetWatts)),
                icon: state.externalConnected ? "powerplug.fill" : "battery.75percent",
                color: .green
            )

            kpiCard(
                title: "Đêm qua (Từ pmset log thật)",
                value: lastSession != nil
                    ? "-\(lastSession!.dropPercent)% (\(lastSession!.startBattery)%→\(lastSession!.endBattery)%)"
                    : "-\(state.realLastNightDropPercent)%",
                subtitle: lastSession != nil
                    ? String(format: "%.1fh ngủ • %d DarkWake • Rò %.2f W", lastSession!.durationHours, lastSession!.darkWakeCount, lastSession!.averageDrainWatts)
                    : "Đọc chuẩn từ pmset -g log",
                icon: "bed.double.fill",
                color: .red
            )

            kpiCard(
                title: "Dự đoán % Pin khi dùng MacNAP",
                value: String(
                    format: "-%.1f%% → -%.1f%%",
                    state.predictedDropPercentWithFullGuard,
                    state.predictedDropPercentWithAutoUnmount
                ),
                subtitle: String(
                    format: "Tiết kiệm +%d%% đến +%d%% pin/đêm (Còn ~%d%% sáng hôm sau)",
                    max(1, state.realLastNightDropPercent - Int(round(state.predictedDropPercentWithAutoUnmount))),
                    max(1, state.realLastNightDropPercent - Int(round(state.predictedDropPercentWithFullGuard))),
                    max(0, 100 - Int(round(state.predictedDropPercentWithFullGuard)))
                ),
                icon: "sparkles",
                color: .cyan
            )
        }
    }

    private func kpiCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded).monospacedDigit())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var realtimeChartsRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Biểu đồ AppleSMC Realtime (1.0s): System Total vs DC In", systemImage: "waveform.path.ecg")
                        .font(.headline)
                    Spacer()
                    Text("Chu kỳ 1.0 giây • Khớp 100% cảm biến SMC")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Chart {
                    ForEach(state.samples) { sample in
                        AreaMark(
                            x: .value("Thời gian", sample.timestamp),
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
                            x: .value("Thời gian", sample.timestamp),
                            y: .value("System Total (W)", sample.systemLoadWatts),
                            series: .value("Loại", "System Total")
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        LineMark(
                            x: .value("Thời gian", sample.timestamp),
                            y: .value("DC In (W)", sample.adapterInputWatts),
                            series: .value("Loại", "DC In")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [5, 3]))
                    }
                }
                .chartYAxisLabel("Watts (W)")
                .frame(height: 210)

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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Công suất từng cổng / thiết bị: Active vs Sau khi Unmount", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
            }

            Chart {
                ForEach(state.peripherals.prefix(7)) { dev in
                    BarMark(
                        x: .value("Watts", dev.watts),
                        y: .value("Thiết bị", dev.name)
                    )
                    .foregroundStyle(.pink)
                    .position(by: .value("Chế độ", "Đang chạy"))
                    .annotation(position: .trailing) {
                        Text(String(format: "%.2fW", dev.watts))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    BarMark(
                        x: .value("Watts", dev.sleepWatts),
                        y: .value("Thiết bị", dev.name)
                    )
                    .foregroundStyle(.indigo.opacity(0.85))
                    .position(by: .value("Chế độ", "Khi Unmount/Ngủ"))
                }
            }
            .chartXAxisLabel("Watts (W)")
            .frame(height: 210)

            HStack(spacing: 16) {
                legendDot(color: .pink, label: "Đang hoạt động (Active)")
                legendDot(color: .indigo, label: "Sau khi Auto-Unmount (Standby)")
            }
            .font(.caption2)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var sleepAidCompactPreview: some View {
        sleepAidTimelineSection
    }

    private var sleepAidTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Biểu đồ Phiên Ngủ Thực Tế kiểu Sleep Aid (Theo ngày giờ thực tế từ pmset log)", systemImage: "moon.stars.fill")
                    .font(.headline)

                Spacer()

                if !state.sleepSessions.isEmpty {
                    Picker("Phiên ngủ:", selection: $state.selectedSessionID) {
                        ForEach(state.sleepSessions) { session in
                            Text("\(session.titleLabel) (-\(session.dropPercent)% • \(session.darkWakeCount) DarkWake)")
                                .tag(Optional(session.id))
                        }
                    }
                    .frame(width: 330)
                }

                Button {
                    state.refreshWakeLogs()
                } label: {
                    if state.isLoadingPmsetLog {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Đang đọc log...")
                        }
                    } else {
                        Text("Đọc lại pmset log")
                    }
                }
                .disabled(state.isLoadingPmsetLog)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let session = state.currentSleepSession {
                HStack(spacing: 16) {
                    Text("Thời gian: **\(session.titleLabel)** (\(String(format: "%.1f giờ", session.durationHours)))")
                    Text("Đêm qua (Chưa bật app): **\(session.startBattery)% → \(session.endBattery)% (-\(session.dropPercent)%)**")
                        .foregroundStyle(.red)
                    Text(String(format: "Dự đoán bật Auto-Unmount: **-%0.1f%%** (còn ~%d%%)", state.predictedDropPercentWithAutoUnmount, max(0, session.startBattery - Int(round(state.predictedDropPercentWithAutoUnmount)))))
                        .foregroundStyle(.green)
                    Text(String(format: "Bật Auto-Unmount + Tắt DarkWake: **-%0.1f%%** (còn ~%d%%)", state.predictedDropPercentWithFullGuard, max(0, session.startBattery - Int(round(state.predictedDropPercentWithFullGuard)))))
                        .foregroundStyle(.mint)
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
                            x: .value("Giờ", ev.timestamp),
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
                            x: .value("Giờ", ev.timestamp),
                            y: .value("Pin thực tế (%)", ev.batteryPercent),
                            series: .value("Kịch bản", "Thực tế đêm qua")
                        )
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        LineMark(
                            x: .value("Giờ", ev.timestamp),
                            y: .value("Dự đoán Auto-Unmount (%)", predictedAutoUnmountPct),
                            series: .value("Kịch bản", "Bật Auto-Unmount")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, dash: [6, 3]))

                        LineMark(
                            x: .value("Giờ", ev.timestamp),
                            y: .value("Dự đoán Full Guard (%)", predictedFullGuardPct),
                            series: .value("Kịch bản", "Auto-Unmount + Tắt DarkWake")
                        )
                        .foregroundStyle(.mint)
                        .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [3, 3]))

                        if ev.kind != .sleep {
                            RuleMark(x: .value("Giờ", ev.timestamp))
                                .foregroundStyle(ev.kind == .darkWake ? Color.orange.opacity(0.75) : Color.red)
                                .lineStyle(StrokeStyle(lineWidth: selectedTimelineEventID == ev.id ? 3.0 : 1.5))

                            PointMark(
                                x: .value("Giờ", ev.timestamp),
                                y: .value("Pin thực tế (%)", ev.batteryPercent)
                            )
                            .symbolSize(selectedTimelineEventID == ev.id ? 110 : 55)
                            .foregroundStyle(ev.kind == .darkWake ? .orange : .red)
                        } else {
                            PointMark(
                                x: .value("Giờ", ev.timestamp),
                                y: .value("Pin thực tế (%)", ev.batteryPercent)
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

                HStack(spacing: 18) {
                    legendDot(color: .cyan, label: "Thực tế đêm qua (-\(session.dropPercent)% • còn \(session.endBattery)%)")
                    legendDot(color: .green, label: String(format: "Dự đoán bật Auto-Unmount (-%.1f%% • còn ~%d%%)", state.predictedDropPercentWithAutoUnmount, max(0, session.startBattery - Int(round(state.predictedDropPercentWithAutoUnmount)))))
                    legendDot(color: .mint, label: String(format: "Dự đoán bật Auto-Unmount + Tắt DarkWake (-%.1f%% • còn ~%d%%)", state.predictedDropPercentWithFullGuard, max(0, session.startBattery - Int(round(state.predictedDropPercentWithFullGuard)))))
                    Spacer()
                    Text("Nhấn vào vạch cam trên biểu đồ để xem chi tiết nguyên nhân thức")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

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

                                Text("Mốc thời gian: \(ev.dateLabel)")
                                    .font(.subheadline.bold().monospacedDigit())

                                Text("• Mức Pin: \(ev.batteryPercent)%")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)

                                if ev.durationSeconds > 0 {
                                    Text("• Kéo dài: \(ev.durationSeconds) giây")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text("Nguyên nhân / Trigger: \(ev.triggerReason)")
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
                Text("Đang phân tích dữ liệu phiên ngủ từ pmset log ở luồng ngầm...")
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

    private var peripheralsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Danh sách thiết bị ngoại vi & Cổng Thunderbolt (Nhấn vào thiết bị để mở cửa sổ Chart & Log riêng)", systemImage: "externaldrive.connected.to.line.below.fill")
                    .font(.headline)
                Spacer()
                Button("Quét lại") {
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
                                Text(dev.isMounted ? "Đang Mount" : "Đã Unmount (Standby)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((dev.isMounted ? Color.orange : Color.green).opacity(0.2), in: Capsule())
                                    .foregroundStyle(dev.isMounted ? .orange : .green)
                            }
                        }
                        Text("Hãng: \(dev.vendor) • Chuẩn: \(dev.speedDescription) • Dòng: \(dev.currentmA)mA (Standby: \(dev.sleepCurrentmA)mA) @ \(String(format: "%.1fV", dev.voltageV))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f W", dev.watts))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(dev.watts >= 2.0 ? .pink : .primary)
                        Text(String(format: "Standby: %.2f W", dev.sleepWatts))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        openWindow(id: "device-detail", value: dev.id)
                    } label: {
                        Label("Chart & Log", systemImage: "chart.xyaxis.line")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if dev.canUnmount, dev.bsdName != nil {
                        Button(dev.isMounted ? "Unmount" : "Mount lại") {
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
                    openWindow(id: "device-detail", value: dev.id)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var deepLogsAndAssertionsSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Tiến trình giữ máy thức (Assertions & Watt hao phí)")
                        .font(.headline)
                    Spacer()
                    Button("Copy lệnh tắt DarkWake / TCPKeepAlive") {
                        state.copyZeroDrainCommand()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if state.assertions.isEmpty {
                    Text("Không có tiến trình nào đang giữ máy thức.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.assertions) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.processName) (PID \(item.pid)) • Giữ suốt \(item.duration)")
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

                Label("Lịch sử Auto-Unmount / Auto-Remount khi đóng mở nắp", systemImage: "list.bullet.clipboard.fill")
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
                    Text("Nhật ký Nguồn chi tiết (pmset Power Log)")
                        .font(.headline)
                    Spacer()
                    Button {
                        state.refreshWakeLogs()
                    } label: {
                        Text(state.isLoadingPmsetLog ? "Đang tải..." : "Làm mới")
                    }
                    .disabled(state.isLoadingPmsetLog)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    Picker("Bộ lọc", selection: $state.selectedLogFilter) {
                        ForEach(PowerLogCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Tìm process/lý do...", text: $state.logSearchQuery)
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
