import SwiftUI

@main
struct MacNAPApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("MacNAP — Power & Peripheral Jettison", id: "dashboard") {
            DashboardView(state: state)
        }
        .defaultSize(width: 980, height: 740)

        MenuBarExtra {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundStyle(.green)
                    Text("MacNAP Jettison")
                        .font(.headline)
                    Spacer()
                    Text("\(state.batteryPercent)%")
                        .font(.caption.bold())
                }

                Divider()

                Text(String(format: "System Load: %.2f W", state.systemLoadWatts))
                Text(String(format: "Ngoại vi (USB/SSD): %.2f W", state.peripheralsTotalWatts))
                Text(String(format: "Dự báo rò 8h đêm: -%.1f%%", state.estimatedOvernight8hDrainPercent))

                Divider()

                Toggle("Auto-Eject khi gập nắp", isOn: $state.autoEjectOnSleep)

                Button("Eject tất cả ổ cứng ngoài ngay") {
                    state.ejectNowAll()
                }

                Button("Jettison & Sleep Mac ngay") {
                    state.jettisonAndSleepMacNow()
                }

                Button("Mở bảng phân tích chuyên sâu (Charts)") {
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
                Image(systemName: "bolt.shield.fill")
                Text(String(format: "%.1fW", state.systemLoadWatts))
            }
        }
    }
}
