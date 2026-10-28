import SwiftUI

@main
struct MacNAPApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Mặc định khi chạy chỉ hiện MenuBarExtra, chỉ mở cửa sổ Dashboard khi người dùng bấm chọn
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    SleepingMacIconView(size: 24)
                    Text("MacNAP Zzz Guard")
                        .font(.headline)
                    Spacer()
                    Text("\(state.batteryPercent)%")
                        .font(.caption.bold())
                }

                Divider()

                Text(String(format: "System Total (PSTR): %.2f W", state.systemLoadWatts))
                Text(String(format: "DC In (PDTR): %.2f W", state.externalConnected ? state.adapterWatts : 0.0))
                Text(String(format: "Thunderbolt Right: %.2f W • Left: %.2f W", state.tbRightWatts, state.tbLeftWatts))
                if let s = state.currentSleepSession {
                    Text(String(format: "Đêm qua: -%d%% • Dự đoán dùng App: -%.1f%% → -%.1f%%", s.dropPercent, state.predictedDropPercentWithFullGuard, state.predictedDropPercentWithAutoUnmount))
                }

                Divider()

                Toggle("Khởi động cùng máy tính (Login)", isOn: $state.launchAtLogin)
                Toggle("Ẩn icon trên thanh Dock", isOn: $state.hideDockIcon)
                Toggle("Tự Unmount khi gập nắp / Sleep", isOn: $state.autoUnmountOnSleep)
                Toggle("Tự Mount lại ngay khi mở nắp", isOn: $state.autoRemountOnWake)

                Divider()

                Text("Nhấn vào thiết bị để mở cửa sổ Chart & Log:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(state.peripherals.prefix(6)) { dev in
                    Button {
                        state.showDashboardWindow {
                            openWindow(id: "device-detail", value: dev.id)
                        }
                    } label: {
                        HStack {
                            Text(dev.name)
                            Spacer()
                            Text(String(format: "%.2fW", dev.watts))
                        }
                    }
                }

                Divider()

                Button("Unmount tất cả ổ cứng ngoài ngay") {
                    state.unmountAllNow()
                }

                Button("Mount lại tất cả ổ cứng ngoài ngay") {
                    state.remountAllNow()
                }

                Button("Unmount & Đưa Mac đi ngủ ngay (Zzz)") {
                    state.unmountAndSleepMacNow()
                }

                Button("Mở bảng phân tích chuyên sâu (Dashboard)") {
                    state.showDashboardWindow {
                        openWindow(id: "dashboard")
                    }
                }

                Divider()

                Button("Thoát MacNAP") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(10)
        } label: {
            Image(
                nsImage: SleepingMacIconView.renderMenuBarStatusImage(
                    systemTotalW: state.systemLoadWatts,
                    dcInW: state.externalConnected ? state.adapterWatts : 0.0
                )
            )
        }

        Window("MacNAP — Auto-Unmount & Sleep Aid Watt Profiler", id: "dashboard") {
            DashboardView(state: state)
                .onAppear {
                    state.applyDockVisibilityPolicy()
                }
        }
        .defaultSize(width: 1120, height: 780)

        WindowGroup("Chi tiết thiết bị ngoại vi", id: "device-detail", for: String.self) { $deviceID in
            if let id = deviceID {
                DeviceDetailView(state: state, deviceID: id)
            }
        }
        .defaultSize(width: 740, height: 580)
    }
}
