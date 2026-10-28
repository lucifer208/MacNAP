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
                chartsRow
                peripheralsSection
                assertionsAndOvernightSection
            }
            .padding(20)
        }
        .frame(minWidth: 920, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("MacNAP — Jettison & Deep Watt Profiler")
                        .font(.title2.bold())
                }
                Text(state.lastActionLog)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("Auto-Jettison khi gập nắp", isOn: $state.autoEjectOnSleep)
                .toggleStyle(.switch)

            Button {
                state.ejectNowAll()
            } label: {
                Label("Eject ổ ngoài", systemImage: "eject.fill")
            }
            .buttonStyle(.bordered)

            Button {
                state.jettisonAndSleepMacNow()
            } label: {
                Label("Jettison & Sleep ngay", systemImage: "moon.zzz.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var kpiGrid: some View {
        HStack(spacing: 14) {
            kpiCard(
                title: "Tổng tải hệ thống (System Load)",
                value: String(format: "%.2f W", state.systemLoadWatts),
                subtitle: String(format: "Điện áp: %.2f V • Pin: %d%% (%d mAh)", state.voltageV, state.batteryPercent, state.remainingmAh),
                icon: "cpu.fill",
                color: .orange
            )

            kpiCard(
                title: "Tiêu thụ thiết bị ngoại vi",
                value: String(format: "%.2f W", state.peripheralsTotalWatts),
                subtitle: "\(state.peripherals.count) thiết bị USB/Hub/Ổ cứng đang cấp nguồn",
                icon: "cable.connector.horizontal",
                color: .pink
            )

            kpiCard(
                title: "Dự báo rò pin 8h qua đêm",
                value: String(format: "-%.1f%% / đêm", state.estimatedOvernight8hDrainPercent),
                subtitle: state.estimatedOvernight8hDrainPercent > 8.0
                    ? "Cảnh báo: Ổ ngoài + Assertions gây rò pin cao!"
                    : "Mức rò rỉ thấp — An toàn khi gập nắp",
                icon: "moon.stars.fill",
                color: state.estimatedOvernight8hDrainPercent > 8.0 ? .red : .green
            )

            kpiCard(
                title: "Nguồn sạc / Pin thực tế",
                value: state.externalConnected
                    ? String(format: "AC %.1f W", state.adapterWatts)
                    : String(format: "Pin -%.2f W", state.batteryWatts),
                subtitle: state.externalConnected ? "Đang cắm nguồn PD" : "Đang xả trực tiếp từ Pin",
                icon: state.externalConnected ? "powerplug.fill" : "battery.75percent",
                color: .blue
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

    private var chartsRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Biểu đồ công suất thực (Watts) theo thời gian")
                        .font(.headline)
                    Spacer()
                    Text("Cập nhật mỗi 3 giây")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Chart {
                    ForEach(state.samples) { sample in
                        AreaMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("System W", sample.systemLoadWatts)
                        )
                        .foregroundStyle(.orange.opacity(0.2))

                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("System W", sample.systemLoadWatts)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("Peripherals W", sample.peripheralsWatts)
                        )
                        .foregroundStyle(.pink)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                }
                .chartYAxisLabel("Watts (W)")
                .frame(height: 190)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text("Phân bổ Watt theo từng thiết bị ngoại vi")
                    .font(.headline)

                Chart(state.peripherals.prefix(7)) { dev in
                    BarMark(
                        x: .value("Watts", dev.watts),
                        y: .value("Device", dev.name)
                    )
                    .foregroundStyle(by: .value("Loại", dev.kind.rawValue))
                    .annotation(position: .trailing) {
                        Text(String(format: "%.2fW (%dmA)", dev.watts, dev.currentmA))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxisLabel("Watts (W)")
                .frame(height: 190)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var peripheralsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Chi tiết thiết bị ngoại vi & Jettison Control")
                    .font(.headline)
                Spacer()
                Button("Quét lại thiết bị") {
                    state.refreshAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(state.peripherals) { dev in
                HStack(spacing: 12) {
                    Image(systemName: dev.kind.iconName)
                        .font(.title3)
                        .foregroundStyle(dev.canUnmount ? .pink : .blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(dev.name)
                                .font(.subheadline.bold())
                            Text(dev.kind.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                        Text("Vendor: \(dev.vendor) • Dòng cấp: \(dev.currentmA) mA @ \(String(format: "%.1fV", dev.voltageV))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f W", dev.watts))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(dev.watts >= 2.0 ? .red : .primary)
                        Text(String(format: "~%.1f Wh / 8h đêm", dev.watts * 8.0))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if dev.canUnmount, dev.bsdName != nil {
                        Button("Unmount / Eject") {
                            state.ejectSingle(dev)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        .controlSize(.small)
                    } else {
                        Text("Bus Powered")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 105, alignment: .trailing)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var assertionsAndOvernightSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Thủ phạm chặn Sleep (Active Assertions)")
                        .font(.headline)
                    Spacer()
                    Button("Copy lệnh tắt DarkWake / Deep Hibernate") {
                        state.copyZeroDrainCommand()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if state.assertions.isEmpty {
                    Text("Không có tiến trình nào đang chặn Sleep.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.assertions) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.processName) (PID \(item.pid)) — \(item.duration)")
                                    .font(.caption.bold())
                                    .foregroundStyle(item.isCulprit ? .red : .primary)
                                Text("\(item.assertionType): \(item.detail)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.isCulprit {
                                Text("Gây rò pin")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.2), in: Capsule())
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.cyan)
                    Text("Nhật ký Sleep / DarkWake (pmset log)")
                        .font(.headline)
                    Spacer()
                    Button("Làm mới log") {
                        state.refreshWakeLogs()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ForEach(state.wakeEvents.prefix(6)) { ev in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(ev.eventType)
                                .font(.caption2.bold())
                                .foregroundStyle(ev.eventType == "DarkWake" ? .orange : .cyan)
                            Text(ev.timestamp)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let pct = ev.batteryPercent {
                                Text("Pin: \(pct)%")
                                    .font(.caption2.bold())
                            }
                        }
                        Text(ev.reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(6)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
