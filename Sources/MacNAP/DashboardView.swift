import SwiftUI
import Charts

public struct DashboardView: View {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerBar
                kpiGrid
                sleepAidTimelineSection
                chartsGridSection
                peripheralsSection
                deepLogsAndAssertionsSection
            }
            .padding(20)
        }
        .frame(minWidth: 1040, minHeight: 800)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            SleepingMacIconView(size: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("MacNAP — Auto-Unmount & Sleep Aid Watt Profiler")
                        .font(.title2.bold())
                    Text("Zzz Guard Active")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.indigo.opacity(0.2), in: Capsule())
                        .foregroundStyle(.indigo)
                }
                Text(state.lastActionLog)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Toggle("Tự Unmount khi gập nắp / Sleep", isOn: $state.autoUnmountOnSleep)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Toggle("Tự Mount lại ngay khi mở nắp", isOn: $state.autoRemountOnWake)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Button {
                state.unmountAllNow()
            } label: {
                Label("Unmount tất cả", systemImage: "arrow.down.doc.fill")
            }
            .buttonStyle(.bordered)

            Button {
                state.remountAllNow()
            } label: {
                Label("Mount lại ngay", systemImage: "arrow.up.doc.fill")
            }
            .buttonStyle(.bordered)
            .tint(.green)

            Button {
                state.unmountAndSleepMacNow()
            } label: {
                Label("Unmount & Ngủ ngay (Zzz)", systemImage: "moon.zzz.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var kpiGrid: some View {
        let lastSession = state.currentSleepSession
        return HStack(spacing: 12) {
            kpiCard(
                title: "System Total (Công suất tiêu thụ)",
                value: String(format: "%.2f W", state.systemLoadWatts),
                subtitle: String(format: "Core: %.2fW • Ngoại vi: %.2fW • Pin: %d%%", state.cpuCoreWatts, state.peripheralsTotalWatts, state.batteryPercent),
                icon: "bolt.fill"
            )

            kpiCard(
                title: "DC In (Công suất nguồn sạc vào)",
                value: state.externalConnected
                    ? String(format: "%.2f W", state.adapterWatts)
                    : "0.00 W (Dùng Pin)",
                subtitle: state.externalConnected
                    ? String(
                        format: "Adapter Max %dW • Pin: %@",
                        state.adapterMaxWatts,
                        state.chargingIntoBatteryWatts > 0.05 ? String(format: "Đang nạp +%.1fW", state.chargingIntoBatteryWatts) : "Bypass (Giữ Pin)"
                    )
                    : String(format: "Đang xả từ Pin: -%.2f W", abs(state.batteryNetWatts)),
                icon: state.externalConnected ? "powerplug.fill" : "battery.75percent"
            )

            kpiCard(
                title: "Đêm qua (Chưa bật App)",
                value: lastSession != nil
                    ? "-\(lastSession!.dropPercent)% (\(lastSession!.startBattery)%→\(lastSession!.endBattery)%)"
                    : "-\(state.realLastNightDropPercent)%",
                subtitle: lastSession != nil
                    ? String(format: "%.1fh ngủ • %d DarkWake • Rò %.2f W", lastSession!.durationHours, lastSession!.darkWakeCount, lastSession!.averageDrainWatts)
                    : "Đọc chuẩn từ pmset -g log",
                icon: "bed.double.fill"
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
                icon: "sparkles"
            )
        }
    }

    private func kpiCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sleep Aid Style Interactive Timeline (Theo ngày giờ thực tế từ pmset log, nhấn vào hiện chi tiết)
    private var sleepAidTimelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Biểu đồ Phiên Ngủ Thực Tế kiểu Sleep Aid (Trích xuất chuẩn từ pmset log theo ngày giờ)", systemImage: "moon.stars.fill")
                    .font(.headline)

                Spacer()

                if !state.sleepSessions.isEmpty {
                    Picker("Chọn phiên ngủ:", selection: $state.selectedSessionID) {
                        ForEach(state.sleepSessions) { session in
                            Text("\(session.titleLabel) (-\(session.dropPercent)% • \(session.darkWakeCount) DarkWake)")
                                .tag(Optional(session.id))
                        }
                    }
                    .frame(width: 340)
                }

                Button("Đọc lại pmset log") {
                    state.refreshWakeLogs()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let session = state.currentSleepSession {
                HStack(spacing: 14) {
                    Text("Thời gian: **\(session.titleLabel)** (\(String(format: "%.1f giờ", session.durationHours)))")
                    Text("Đêm qua (Không bật app): **\(session.startBattery)% → \(session.endBattery)% (-\(session.dropPercent)%)**")
                        .foregroundStyle(.red)
                    Text(String(format: "Dự đoán khi bật Auto-Unmount: **-%0.1f%%** (còn ~%d%%)", state.predictedDropPercentWithAutoUnmount, max(0, session.startBattery - Int(round(state.predictedDropPercentWithAutoUnmount)))))
                        .foregroundStyle(.green)
                    Text(String(format: "Khi bật Auto-Unmount + Tắt DarkWake: **-%0.1f%%** (còn ~%d%%)", state.predictedDropPercentWithFullGuard, max(0, session.startBattery - Int(round(state.predictedDropPercentWithFullGuard)))))
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

                        // Đường % Pin thực tế theo ngày giờ (Chưa dùng app)
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

                        // Đường dự đoán % Pin khi bật MacNAP Auto-Unmount
                        LineMark(
                            x: .value("Giờ", ev.timestamp),
                            y: .value("Dự đoán Auto-Unmount (%)", predictedAutoUnmountPct),
                            series: .value("Kịch bản", "Bật Auto-Unmount")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, dash: [6, 3]))

                        // Đường dự đoán % Pin khi bật Auto-Unmount + Tắt DarkWake
                        LineMark(
                            x: .value("Giờ", ev.timestamp),
                            y: .value("Dự đoán Full Guard (%)", predictedFullGuardPct),
                            series: .value("Kịch bản", "Auto-Unmount + Tắt DarkWake")
                        )
                        .foregroundStyle(.mint)
                        .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [3, 3]))

                        // Các vạch DarkWake / Wake giống hệt Sleep Aid
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
                .frame(height: 185)
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
                    legendDot(color: .green, label: String(format: "Dự đoán khi bật Auto-Unmount ổ ngoài (-%.1f%% • còn ~%d%%)", state.predictedDropPercentWithAutoUnmount, max(0, session.startBattery - Int(round(state.predictedDropPercentWithAutoUnmount)))))
                    legendDot(color: .mint, label: String(format: "Dự đoán khi bật Auto-Unmount + Tắt DarkWake (-%.1f%% • còn ~%d%%)", state.predictedDropPercentWithFullGuard, max(0, session.startBattery - Int(round(state.predictedDropPercentWithFullGuard)))))
                    Spacer()
                    Text("💡 Nhấn vào vạch cam trên biểu đồ để xem chi tiết nguyên nhân thức")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)

                // Thanh chọn nhanh các mốc DarkWake/Sleep hoặc chi tiết mốc vừa nhấn vào
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
                    .padding(10)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Text("Đang phân tích dữ liệu phiên ngủ từ pmset log...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var selectedTimelineEventID: UUID? {
        state.selectedTimelineEvent?.id
    }

    private var chartsGridSection: some View {
        HStack(spacing: 14) {
            // Chart 1: Multi-series Realtime Watt Telemetry (Out vs In vs Peripherals)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Công suất Realtime: Tiêu thụ (W) vs Đang sạc vào (W) vs Ngoại vi", systemImage: "waveform.path.ecg")
                        .font(.headline)
                    Spacer()
                    Text("Cập nhật 2.5s")
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
                                colors: [.orange.opacity(0.25), .orange.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Thời gian", sample.timestamp),
                            y: .value("Tiêu thụ (W)", sample.systemLoadWatts),
                            series: .value("Loại", "Tiêu thụ")
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        LineMark(
                            x: .value("Thời gian", sample.timestamp),
                            y: .value("Sạc vào (W)", sample.adapterInputWatts),
                            series: .value("Loại", "Sạc vào")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [5, 3]))

                        LineMark(
                            x: .value("Thời gian", sample.timestamp),
                            y: .value("Ngoại vi (W)", sample.peripheralsWatts),
                            series: .value("Loại", "Ngoại vi")
                        )
                        .foregroundStyle(.pink)
                        .lineStyle(StrokeStyle(lineWidth: 2.0))
                    }
                }
                .chartYAxisLabel("Watts (W)")
                .frame(height: 185)

                HStack(spacing: 16) {
                    legendDot(color: .orange, label: String(format: "System Total: %.2fW", state.systemLoadWatts))
                    legendDot(color: .green, label: String(format: "DC In: %.2fW", state.externalConnected ? state.adapterWatts : 0.0))
                    legendDot(color: .pink, label: String(format: "Ngoại vi: %.2fW", state.peripheralsTotalWatts))
                }
                .font(.caption2)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Chart 2: Per-device Active Watts vs Unmounted Sleep Watts
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Công suất từng thiết bị: Đang chạy vs Sau khi Auto-Unmount", systemImage: "chart.bar.xaxis")
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
                            Text(String(format: "%.2fW (%dmA)", dev.watts, dev.currentmA))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        BarMark(
                            x: .value("Watts", dev.sleepWatts),
                            y: .value("Thiết bị", dev.name)
                        )
                        .foregroundStyle(.indigo.opacity(0.8))
                        .position(by: .value("Chế độ", "Khi Unmount/Ngủ"))
                    }
                }
                .chartXAxisLabel("Watts (W)")
                .frame(height: 185)

                HStack(spacing: 16) {
                    legendDot(color: .pink, label: "Đang hoạt động (Active)")
                    legendDot(color: .indigo, label: "Sau khi Auto-Unmount (Standby)")
                }
                .font(.caption2)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Danh sách thiết bị ngoại vi (Nhấn vào bất kỳ thiết bị nào để mở cửa sổ Chart & Log riêng)", systemImage: "externaldrive.connected.to.line.below.fill")
                    .font(.headline)
                Spacer()
                Button("Quét lại") {
                    state.refreshAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(state.peripherals) { dev in
                HStack(spacing: 12) {
                    Image(systemName: dev.kind.iconName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

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
                                Text(dev.isMounted ? "Đang Mount" : "Đã Unmount (Ngủ)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((dev.isMounted ? Color.orange : Color.green).opacity(0.2), in: Capsule())
                                    .foregroundStyle(dev.isMounted ? .orange : .green)
                            }
                        }
                        Text("Hãng: \(dev.vendor) • Chuẩn: \(dev.speedDescription) • Dòng thực: \(dev.currentmA)mA (Standby: \(dev.sleepCurrentmA)mA) @ \(String(format: "%.1fV", dev.voltageV))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f W", dev.watts))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(dev.watts >= 1.2 ? .pink : .primary)
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
                        .frame(width: 90)
                    } else {
                        Text("USB Bus")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .trailing)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    openWindow(id: "device-detail", value: dev.id)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var deepLogsAndAssertionsSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.secondary)
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

                ForEach(state.actionHistory.prefix(6)) { log in
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
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text("Nhật ký Nguồn chi tiết (pmset Power Log)")
                        .font(.headline)
                    Spacer()
                    Button("Làm mới") {
                        state.refreshWakeLogs()
                    }
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
                            .padding(7)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(height: 250)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
