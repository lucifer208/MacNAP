import Foundation
import AppKit

public final class JettisonSleepGuardService {
    public init() {}

    public func listExternalMountedVolumes() -> [(bsdName: String, volumeName: String, mediaName: String)] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsInternalKey
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }

        var list: [(String, String, String)] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let isInternal = values.volumeIsInternal ?? true
            let isRemovable = values.volumeIsRemovable ?? false
            let isEjectable = values.volumeIsEjectable ?? false

            if !isInternal || isRemovable || isEjectable {
                let volName = values.volumeName ?? url.lastPathComponent
                let bsd = resolveBSDName(for: url.path) ?? url.lastPathComponent
                list.append((bsd, volName, "External Storage"))
            }
        }
        return list
    }

    private func resolveBSDName(for mountPath: String) -> String? {
        var statInfo = statfs()
        guard statfs(mountPath, &statInfo) == 0 else { return nil }
        let mntFrom = withUnsafePointer(to: &statInfo.f_mntfromname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        if mntFrom.hasPrefix("/dev/") {
            return String(mntFrom.dropFirst(5))
        }
        return mntFrom
    }

    public func ejectVolumeOrDisk(bsdOrName: String) -> (success: Bool, message: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        let baseDisk = bsdOrName.replacingOccurrences(of: #"s\d+$"#, with: "", options: .regularExpression)
        proc.arguments = ["eject", baseDisk]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (proc.terminationStatus == 0, out.isEmpty ? "Ejected \(baseDisk)" : out)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func ejectAllExternalDisks() -> [String] {
        let volumes = listExternalMountedVolumes()
        var logs: [String] = []
        var ejectedBaseDisks = Set<String>()

        for vol in volumes {
            let baseDisk = vol.bsdName.replacingOccurrences(of: #"s\d+$"#, with: "", options: .regularExpression)
            if ejectedBaseDisks.contains(baseDisk) { continue }
            ejectedBaseDisks.insert(baseDisk)
            let res = ejectVolumeOrDisk(bsdOrName: baseDisk)
            logs.append("\(vol.volumeName) (\(baseDisk)): \(res.message)")
        }
        if logs.isEmpty {
            logs.append("Không có ổ cứng ngoài nào đang mount.")
        }
        return logs
    }

    public func scanSleepAssertions() -> [SleepAssertionItem] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        proc.arguments = ["-g", "assertions"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        var items: [SleepAssertionItem] = []
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.components(separatedBy: .newlines)

            // Example: pid 698(sharingd): [0x0003525b000191bc] 00:00:17 PreventUserIdleSystemSleep named: "Handoff"
            let pattern = #"pid\s+(\d+)\(([^)]+)\):\s+\[[^\]]+\]\s+([0-9:]+)\s+([A-Za-z]+)\s+named:\s+"([^"]+)""#
            let regex = try? NSRegularExpression(pattern: pattern)

            for line in lines {
                let nsLine = line as NSString
                guard let match = regex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
                    continue
                }
                let pid = nsLine.substring(with: match.range(at: 1))
                let procName = nsLine.substring(with: match.range(at: 2))
                let duration = nsLine.substring(with: match.range(at: 3))
                let type = nsLine.substring(with: match.range(at: 4))
                let detail = nsLine.substring(with: match.range(at: 5))

                let isCulprit = procName.contains("coreaudiod")
                    || procName.contains("sharingd")
                    || procName.contains("bluetoothd")
                    || type.contains("PreventSystemSleep")
                    || type.contains("PreventUserIdleSystemSleep")

                items.append(
                    SleepAssertionItem(
                        pid: pid,
                        processName: procName,
                        assertionType: type,
                        duration: duration,
                        detail: detail,
                        isCulprit: isCulprit
                    )
                )
            }
        } catch {
            // ignore
        }
        return items
    }

    public func scanRecentWakeDrainEvents() -> [WakeDrainEvent] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = [
            "-c",
            "pmset -g log | grep -E 'DarkWake|Wake from|Sleep               \t|MaintenanceWake' | tail -n 18"
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        var events: [WakeDrainEvent] = []
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            for raw in output.components(separatedBy: .newlines).reversed() {
                let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty { continue }
                let timePart = String(line.prefix(19))
                let isDarkWake = line.contains("DarkWake")
                let isWake = line.contains("Wake from") || line.contains("MaintenanceWake")
                let type = isDarkWake ? "DarkWake" : (isWake ? "Wake" : "Sleep")

                var charge: Int?
                if let range = line.range(of: #"Charge:\s*(\d+)%"#, options: .regularExpression) {
                    let sub = String(line[range])
                    let digits = sub.filter(\.isNumber)
                    charge = Int(digits)
                }

                let reason = String(line.dropFirst(min(26, line.count))).trimmingCharacters(in: .whitespaces)
                events.append(
                    WakeDrainEvent(
                        timestamp: timePart,
                        eventType: type,
                        reason: reason,
                        batteryPercent: charge
                    )
                )
            }
        } catch {
            // ignore
        }
        return events
    }

    public func buildZeroDrainTerminalCommand() -> String {
        "sudo pmset -b tcpkeepalive 0 powernap 0 womp 0 proximitywake 0 ttyskeepawake 0 hibernatemode 25"
    }
}
