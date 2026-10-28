import SwiftUI

@main
struct MacNAPApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("MacNAP — Auto-Unmount & Sleep Aid Watt Profiler", id: "dashboard") {
            DashboardView(state: state)
                .onAppear {
                    state.applyCustomDockIcon()
                }
        }
        .defaultSize(width: 1080, height: 860)

        WindowGroup("Chi tiết thiết bị ngoại vi", id: "device-detail", for: String.self) { $deviceID in
            if let id = deviceID {
                DeviceDetailView(state: state, deviceID: id)
            }
        }
        .defaultSize(width: 740, height: 580)

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

                Text(String(format: "⚡️ Tiêu thụ (Out): %.2f W", state.systemLoadWatts))
                Text(String(format: "🔌 Đang sạc vào (In): %.2f W", state.externalConnected ? state.adapterWatts : 0.0))
                Text(String(format: "🖨️ Ngoại vi (Active): %.2f W (Standby: %.2f W)", state.peripheralsTotalWatts, state.peripheralsSleepWatts))
                if let s = state.currentSleepSession {
                    Text(String(format: "🌙 Đêm qua (%@): -%d%% (%d DarkWake • TB %.2fW)", s.titleLabel, s.dropPercent, s.darkWakeCount, s.averageDrainWatts))
                }

                Divider()

                Toggle("Tự Unmount khi gập nắp / Sleep", isOn: $state.autoUnmountOnSleep)
                Toggle("Tự Mount lại ngay khi mở nắp", isOn: $state.autoRemountOnWake)

                Divider()

                Text("Nhấn vào thiết bị để mở cửa sổ Chart & Log:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(state.peripherals.prefix(6)) { dev in
                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "device-detail", value: dev.id)
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

                Button("Mở bảng phân tích chính (Sleep Aid & Charts)") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "dashboard")
                }

                Divider()

                Button("Thoát MacNAP") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(10)
        } label: {
            Text(
                String(
                    format: "⚡️%.1fW 🔌%.1fW",
                    state.systemLoadWatts,
                    state.externalConnected ? state.adapterWatts : 0.0
                )
            )
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }
}
