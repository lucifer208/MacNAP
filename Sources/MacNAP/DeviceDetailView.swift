import SwiftUI
import Charts

public struct DeviceDetailView: View {
    @ObservedObject var state: AppState
    public let deviceID: String

    public init(state: AppState, deviceID: String) {
        self.state = state
        self.deviceID = deviceID
    }

    public var body: some View {
        if let dev = state.device(withID: deviceID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection(dev)
                    metricsRow(dev)
                    realtimeChartSection(dev)
                    logsSection(dev)
                }
                .padding(20)
            }
            .frame(minWidth: 700, minHeight: 540)
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "cable.connector.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Thiết bị không còn kết nối hoặc đã thay đổi địa chỉ Bus.")
                    .font(.headline)
            }
            .frame(minWidth: 500, minHeight: 360)
        }
    }

    private func headerSection(_ dev: PeripheralDevice) -> some View {
        HStack(spacing: 14) {
            Image(systemName: dev.kind.iconName)
                .font(.system(size: 30))
                .foregroundStyle(dev.canUnmount ? .pink : .cyan)
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(dev.name)
                        .font(.title3.bold())
                    Text(dev.kind.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                Text("Vendor: \(dev.vendor) • Chuẩn kết nối: \(dev.speedDescription) • ID: \(dev.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if dev.canUnmount, dev.bsdName != nil {
                Button {
                    state.toggleMount(for: dev)
                } label: {
                    Label(
                        dev.isMounted ? "Unmount ngay" : "Mount lại ngay",
                        systemImage: dev.isMounted ? "arrow.down.doc.fill" : "arrow.up.doc.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(dev.isMounted ? .pink : .green)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metricsRow(_ dev: PeripheralDevice) -> some View {
        HStack(spacing: 12) {
            metricBox(
                title: "Công suất đang tiêu thụ",
                value: String(format: "%.2f W", dev.watts),
                sub: "Dòng thực: \(dev.currentmA) mA @ \(String(format: "%.1f V", dev.voltageV))",
                color: .pink
            )
            metricBox(
                title: "Công suất khi Unmount / Ngủ",
                value: String(format: "%.2f W", dev.sleepWatts),
                sub: "Dòng Standby: \(dev.sleepCurrentmA) mA",
                color: .green
            )
            metricBox(
                title: "Tiêu hao sau 8h gập nắp",
                value: String(format: "%.2f Wh", dev.watts * 8.0),
                sub: String(format: "Tương đương -%.1f%% viên pin", ((dev.watts * 8.0) / state.totalBatteryWh) * 100.0),
                color: .orange
            )
            metricBox(
                title: "Trạng thái phân vùng",
                value: dev.canUnmount ? (dev.isMounted ? "Mounted" : "Unmounted") : "Bus Active",
                sub: dev.bsdName ?? "Không có phân vùng",
                color: dev.isMounted ? .cyan : .secondary
            )
        }
    }

    private func metricBox(title: String, value: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(sub)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func realtimeChartSection(_ dev: PeripheralDevice) -> some View {
        let history = state.deviceSamples[dev.id] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Biểu đồ công suất thực (Watts) theo thời gian của \(dev.name)", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
                Text("Cập nhật mỗi 2.5 giây")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(history) { sample in
                    AreaMark(
                        x: .value("Thời gian", sample.timestamp),
                        y: .value("Watts", sample.watts)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink.opacity(0.35), .pink.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Thời gian", sample.timestamp),
                        y: .value("Watts", sample.watts)
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .symbol(.circle)
                }

                RuleMark(y: .value("Standby W", dev.sleepWatts))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text(String(format: "Mức Standby khi Unmount: %.2fW", dev.sleepWatts))
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
            }
            .chartYScale(domain: 0...(max(dev.watts * 1.4, 1.0)))
            .chartYAxisLabel("Watts (W)")
            .frame(height: 190)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func logsSection(_ dev: PeripheralDevice) -> some View {
        let logs = state.deviceLogs[dev.id] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Nhật ký hoạt động & Sự kiện nguồn của thiết bị", systemImage: "list.bullet.rectangle.portrait")
                    .font(.headline)
                Spacer()
                Text("\(logs.count) bản ghi")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(logs) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Text(item.timestamp, style: .time)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 65, alignment: .leading)

                            Text(item.event)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pink.opacity(0.15), in: Capsule())
                                .foregroundStyle(.pink)

                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(String(format: "%.2fW (%dmA)", item.watts, item.currentmA))
                                .font(.caption2.monospacedDigit().bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(7)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(height: 180)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
