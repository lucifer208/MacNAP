import SwiftUI
import Charts

public struct DashboardView: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerBar
                kpiGrid
                chartsGridSection
                peripheralsSection
                deepLogsAndAssertionsSection
            }
            .padding(20)
        }
        .frame(minWidth: 1020, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            SleepingMacIconView(size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("MacNAP — Auto-Unmount & Deep Watt Profiler")
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
        HStack(spacing: 14) {
            kpiCard(
                title: "Tổng công suất máy (System Load)",
                value: String(format: "%.2f W", state.systemLoadWatts),
                subtitle: String(format: "Core: %.2fW • Áp: %.2fV • Pin: %d%% (%d mAh)", state.cpuCoreWatts, state.voltageV, state.batteryPercent, state.remainingmAh),
                icon: "cpu.fill",
                color: .orange
            )

            kpiCard(
                title: "Công suất ngoại vi (Active vs Standby)",
                value: String(format: "%.2f W", state.peripheralsTotalWatts),
                subtitle: String(format: "Khi Unmount/Sleep giảm còn ~%.2f W (%d thiết bị)", state.peripheralsSleepWatts, state.peripherals.count),
                icon: "cable.connector.horizontal",
                color: .pink
            )

            kpiCard(
                title: "Dự báo hao pin 8h đêm (Không bảo vệ)",
                value: String(format: "-%.1f%% / đêm", state.estimatedOvernight8hDrainPercentWithoutGuard),
                subtitle: String(format: "Khi bật MacNAP Zzz Guard chỉ mất ~ -%.1f%% / đêm", state.estimatedOvernight8hDrainPercentWithGuard),
                icon: "moon.zzz.fill",
                color: state.estimatedOvernight8hDrainPercentWithoutGuard > 8.0 ? .red : .green
            )

            kpiCard(
                title: "Trạng thái nguồn (AC / Battery)",
                value: state.externalConnected
                    ? String(format: "AC %.1f W", state.adapterWatts)
                    : String(format: "Xả -%.2f W", state.batteryWatts),
                subtitle: state.externalConnected ? "Đang cấp nguồn từ sạc PD" : "Đang dùng trực tiếp từ viên pin (\(Int(state.totalBatteryWh)) Wh)",
                icon: state.externalConnected ? "powerplug.fill" : "battery.75percent",
                color: .cyan
            )
        }
    }

    private func kpiCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var chartsGridSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Chart 1: Multi-series Realtime Watt Telemetry
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Biểu đồ công suất Realtime: Tổng tải vs Core vs Ngoại vi (W)", systemImage: "waveform.path.ecg")
                            .font(.headline)
                        Spacer()
                        Text("Chu kỳ 2.5s • 60 mẫu")
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
                                    colors: [.orange.opacity(0.30), .orange.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Thời gian", sample.timestamp),
                                y: .value("Tổng tải (W)", sample.systemLoadWatts),
                                series: .value("Loại", "Tổng tải")
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                            LineMark(
                                x: .value("Thời gian", sample.timestamp),
                                y: .value("Ngoại vi (W)", sample.peripheralsWatts),
                                series: .value("Loại", "Ngoại vi")
                            )
                            .foregroundStyle(.pink)
                            .lineStyle(StrokeStyle(lineWidth: 2.2))

                            LineMark(
                                x: .value("Thời gian", sample.timestamp),
                                y: .value("CPU/Hệ thống (W)", sample.cpuCoreWatts),
                                series: .value("Loại", "CPU/Core")
                            )
                            .foregroundStyle(.cyan)
                            .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [4, 3]))
                        }
                    }
                    .chartYAxisLabel("Watts (W)")
                    .frame(height: 200)

                    HStack(spacing: 16) {
                        legendDot(color: .orange, label: String(format: "Tổng tải: %.2fW", state.systemLoadWatts))
                        legendDot(color: .pink, label: String(format: "Ngoại vi: %.2fW", state.peripheralsTotalWatts))
                        legendDot(color: .cyan, label: String(format: "CPU/Core: %.2fW", state.cpuCoreWatts))
                    }
                    .font(.caption2)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Chart 2: Per-device Active Watts vs Unmounted Sleep Watts
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("So sánh Watt từng thiết bị: Đang chạy vs Khi Unmount/Ngủ", systemImage: "chart.bar.xaxis")
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
                            .position(by: .value("Chế độ", "Đang hoạt động"))
                            .annotation(position: .trailing) {
                                Text(String(format: "%.2fW (%dmA)", dev.watts, dev.currentmA))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            BarMark(
                                x: .value("Watts", dev.sleepWatts),
                                y: .value("Thiết bị", dev.name)
                            )
                            .foregroundStyle(.indigo.opacity(0.75))
                            .position(by: .value("Chế độ", "Khi Unmount/Sleep"))
                        }
                    }
                    .chartXAxisLabel("Watts (W)")
                    .frame(height: 200)

                    HStack(spacing: 16) {
                        legendDot(color: .pink, label: "Đang hoạt động (Active Mount)")
                        legendDot(color: .indigo, label: "Sau khi Auto-Unmount / Standby")
                    }
                    .font(.caption2)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // Chart 3: 8-Hour Overnight Simulation Curve (Unprotected vs MacNAP Auto-Unmount)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Mô phỏng đường cong sụt pin 8 tiếng ban đêm (Từ \(state.batteryPercent)% pin hiện tại)", systemImage: "bed.double.fill")
                        .font(.headline)
                    Spacer()
                    Text("So sánh thực tế: Để nguyên ổ ngoài + DarkWake vs Bật MacNAP Auto-Unmount")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let startPct = Double(state.batteryPercent)
                let noGuardDropPerHour = state.estimatedOvernight8hDrainPercentWithoutGuard / 8.0
                let guardedDropPerHour = state.estimatedOvernight8hDrainPercentWithGuard / 8.0
                let hours = Array(0...8)

                Chart {
                    ForEach(hours, id: \.self) { h in
                        let pctNoGuard = max(0.0, startPct - Double(h) * noGuardDropPerHour)
                        let pctGuarded = max(0.0, startPct - Double(h) * guardedDropPerHour)

                        LineMark(
                            x: .value("Giờ ngủ", "+\(h)h"),
                            y: .value("Pin (%)", pctNoGuard),
                            series: .value("Kịch bản", "Không Unmount")
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 3]))
                        .symbol(.circle)

                        LineMark(
                            x: .value("Giờ ngủ", "+\(h)h"),
                            y: .value("Pin (%)", pctGuarded),
                            series: .value("Kịch bản", "Bật MacNAP Auto-Unmount")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .symbol(.square)
                    }
                }
                .chartYScale(domain: max(0, state.batteryPercent - 30)...100)
                .chartYAxisLabel("% Pin còn lại")
                .frame(height: 140)

                HStack(spacing: 20) {
                    legendDot(color: .red, label: String(format: "Không Unmount ổ ngoài: Mất -%.1f%% sau 8h (còn %.0f%%)", state.estimatedOvernight8hDrainPercentWithoutGuard, max(0, startPct - state.estimatedOvernight8hDrainPercentWithoutGuard)))
                    legendDot(color: .green, label: String(format: "Bật MacNAP Auto-Unmount: Chỉ mất -%.1f%% sau 8h (còn %.0f%%)", state.estimatedOvernight8hDrainPercentWithGuard, max(0, startPct - state.estimatedOvernight8hDrainPercentWithGuard)))
                }
                .font(.caption)
            }
            .padding(14)
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
                Label("Danh sách thiết bị ngoại vi & Điều khiển Unmount / Remount tức thì", systemImage: "externaldrive.connected.to.line.below.fill")
                    .font(.headline)
                Spacer()
                Text("Lưu ý: Chỉ Unmount phân vùng (không cắt bus USB), giúp tự động Mount lại 100% khi mở nắp")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(dev.canUnmount ? (dev.isMounted ? .pink : .green) : .blue)
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
                        Text("Hãng: \(dev.vendor) • Chuẩn: \(dev.speedDescription) • Dòng Active: \(dev.currentmA)mA (Sleep: \(dev.sleepCurrentmA)mA) @ \(String(format: "%.1fV", dev.voltageV))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f W", dev.watts))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(dev.watts >= 2.0 ? .red : .primary)
                        Text(String(format: "8h đêm: %.1f Wh (Sleep: %.1f Wh)", dev.watts * 8.0, dev.sleepWatts * 8.0))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if dev.canUnmount, dev.bsdName != nil {
                        Button(dev.isMounted ? "Unmount" : "Mount lại") {
                            state.toggleMount(for: dev)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(dev.isMounted ? .pink : .green)
                        .controlSize(.small)
                        .frame(width: 95)
                    } else {
                        Text("USB Bus")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 95, alignment: .trailing)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var deepLogsAndAssertionsSection: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left column: Assertions + Sleep/Wake Auto-Unmount History
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Tiến trình giữ máy thức (Assertions & Watt hao phí)")
                        .font(.headline)
                    Spacer()
                    Button("Copy lệnh tắt DarkWake") {
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

            // Right column: Deep Power Log Inspector with Filter & Search
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.cyan)
                    Text("Phân tích chuyên sâu Nhật ký Nguồn (pmset Power Log)")
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
                .frame(height: 260)
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
