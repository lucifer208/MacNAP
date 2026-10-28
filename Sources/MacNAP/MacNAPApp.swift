import SwiftUI

@main
struct MacNAPApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("MacNAP — Auto-Unmount & Deep Watt Profiler", id: "dashboard") {
            DashboardView(state: state)
        }
        .defaultSize(width: 1060, height: 820)

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

                Text(String(format: "Tổng tải hệ thống: %.2f W", state.systemLoadWatts))
                Text(String(format: "Ngoại vi (Active): %.2f W (Ngủ: %.2f W)", state.peripheralsTotalWatts, state.peripheralsSleepWatts))
                Text(String(format: "Hao pin 8h đêm: -%.1f%% (Bật Guard: -%.1f%%)", state.estimatedOvernight8hDrainPercentWithoutGuard, state.estimatedOvernight8hDrainPercentWithGuard))

                Divider()

                Toggle("Tự Unmount khi gập nắp / Sleep", isOn: $state.autoUnmountOnSleep)
                Toggle("Tự Mount lại ngay khi mở nắp", isOn: $state.autoRemountOnWake)

                Button("Unmount tất cả ổ cứng ngoài ngay") {
                    state.unmountAllNow()
                }

                Button("Mount lại tất cả ổ cứng ngoài ngay") {
                    state.remountAllNow()
                }

                Button("Unmount & Đưa Mac đi ngủ ngay (Zzz)") {
                    state.unmountAndSleepMacNow()
                }

                Button("Mở bảng phân tích chuyên sâu (Charts & Logs)") {
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
            HStack(spacing: 4) {
                Image(systemName: "laptopcomputer")
                Text("Zzz")
                    .font(.caption2.bold())
                Text(String(format: "%.1fW", state.systemLoadWatts))
                    .font(.caption.monospacedDigit())
            }
        }
    }
}
