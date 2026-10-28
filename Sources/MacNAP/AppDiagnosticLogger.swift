import Foundation
import AppKit
import Darwin

public enum DiagnosticLogLevel: String, CaseIterable, Codable {
    case info = "INFO"
    case action = "ACTION"
    case sleepLid = "SLEEP/LID"
    case warn = "WARN"
    case error = "ERROR"
    case crash = "CRASH"
}

public struct AppDiagnosticLogEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let timeString: String
    public let level: DiagnosticLogLevel
    public let component: String
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        timeString: String,
        level: DiagnosticLogLevel,
        component: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.timeString = timeString
        self.level = level
        self.component = component
        self.message = message
    }
}

/// Global C-compatible file descriptor cho POSIX Signal Crash Handler
private var gCrashLogFileDescriptor: Int32 = -1

private func macnapSignalCrashHandler(_ sig: Int32) {
    let sigName: StaticString
    switch sig {
    case SIGABRT: sigName = "\n[CRASH] FATAL SIGNAL: SIGABRT (Abort)\n"
    case SIGSEGV: sigName = "\n[CRASH] FATAL SIGNAL: SIGSEGV (Segmentation Fault)\n"
    case SIGBUS:  sigName = "\n[CRASH] FATAL SIGNAL: SIGBUS (Bus Error)\n"
    case SIGILL:  sigName = "\n[CRASH] FATAL SIGNAL: SIGILL (Illegal Instruction)\n"
    case SIGTRAP: sigName = "\n[CRASH] FATAL SIGNAL: SIGTRAP (Trap)\n"
    case SIGFPE:  sigName = "\n[CRASH] FATAL SIGNAL: SIGFPE (Floating Point Exception)\n"
    default:      sigName = "\n[CRASH] FATAL SIGNAL RECEIVED\n"
    }

    if gCrashLogFileDescriptor >= 0 {
        sigName.withUTF8Buffer { buf in
            _ = Darwin.write(gCrashLogFileDescriptor, buf.baseAddress, buf.count)
        }
        var callstack = [UnsafeMutableRawPointer?](repeating: nil, count: 64)
        let frames = Darwin.backtrace(&callstack, 64)
        Darwin.backtrace_symbols_fd(&callstack, frames, gCrashLogFileDescriptor)
        Darwin.fsync(gCrashLogFileDescriptor)
    }

    // Tự động khởi động lại MacNAP ngay sau khi crash
    let appPath = Bundle.main.bundleURL.path.hasSuffix(".app") ? Bundle.main.bundleURL.path : "/Users/lu/HUB/MacNAP/MacNAP.app"
    let helperScript = "sleep 0.8; open \"\(appPath)\""
    var helperPid: pid_t = 0
    var args: [UnsafeMutablePointer<CChar>?] = [
        strdup("/bin/sh"),
        strdup("-c"),
        strdup(helperScript),
        nil
    ]
    _ = posix_spawn(&helperPid, "/bin/sh", nil, nil, &args, nil)

    Darwin.signal(sig, SIG_DFL)
    Darwin.raise(sig)
}

public final class AppDiagnosticLogger {
    public static let shared = AppDiagnosticLogger()

    private let lock = NSLock()
    private let dateFormatter: DateFormatter
    public let primaryLogURL: URL
    public let userLibraryLogURL: URL
    private let lockFileURL: URL
    private var entriesBuffer: [AppDiagnosticLogEntry] = []

    private init() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        df.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter = df

        // 1. Tạo thư mục logs ngay trong workspace /Users/lu/HUB/MacNAP/logs
        let workspaceLogsDir = URL(fileURLWithPath: "/Users/lu/HUB/MacNAP/logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: workspaceLogsDir, withIntermediateDirectories: true)
        self.primaryLogURL = workspaceLogsDir.appendingPathComponent("macnap-activity.log")
        self.lockFileURL = workspaceLogsDir.appendingPathComponent(".macnap-running.lock")

        // 2. Tạo bản sao trong ~/Library/Logs/MacNAP
        let libLogsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacNAP", isDirectory: true)
        try? FileManager.default.createDirectory(at: libLogsDir, withIntermediateDirectories: true)
        self.userLibraryLogURL = libLogsDir.appendingPathComponent("macnap-activity.log")

        rotateLogIfNeeded(at: primaryLogURL)
        rotateLogIfNeeded(at: userLibraryLogURL)

        // Mở file descriptor cho signal crash handler
        gCrashLogFileDescriptor = Darwin.open(
            primaryLogURL.path,
            O_WRONLY | O_CREAT | O_APPEND,
            0o644
        )

        loadRecentEntriesFromDisk()
        checkPreviousCrashState()
        installCrashHandlers()
        spawnCrashWatchdogDaemon()
    }

    private func rotateLogIfNeeded(at url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? UInt64,
              fileSize > 2_000_000 else {
            return
        }
        let backupURL = url.deletingLastPathComponent().appendingPathComponent("macnap-activity.prev.log")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: url, to: backupURL)
    }

    private func checkPreviousCrashState() {
        if FileManager.default.fileExists(atPath: lockFileURL.path) {
            let lastNote = (try? String(contentsOf: lockFileURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
            log(
                .warn,
                component: "CrashGuard",
                message: "Phát hiện phiên chạy trước kết thúc đột ngột (văng/force-kill). Trạng thái cuối: \(lastNote)"
            )
        }
        updateRunningLock(status: "App Launched at \(dateFormatter.string(from: Date()))")
    }

    public func updateRunningLock(status: String) {
        try? status.write(to: lockFileURL, atomically: true, encoding: .utf8)
    }

    public func markCleanShutdown() {
        log(.info, component: "AppLifecycle", message: "Người dùng thoát MacNAP bình thường (Clean Shutdown).")
        try? FileManager.default.removeItem(at: lockFileURL)
        if gCrashLogFileDescriptor >= 0 {
            Darwin.close(gCrashLogFileDescriptor)
            gCrashLogFileDescriptor = -1
        }
    }

    private func installCrashHandlers() {
        NSSetUncaughtExceptionHandler { exception in
            let stack = exception.callStackSymbols.joined(separator: "\n  ")
            let msg = "Uncaught NSException: \(exception.name.rawValue) — \(exception.reason ?? "No reason")\n  \(stack)"
            AppDiagnosticLogger.shared.log(.crash, component: "NSException", message: msg)

            // Tự động khởi động lại MacNAP ngay sau unhandled exception
            let appPath = Bundle.main.bundleURL.path.hasSuffix(".app") ? Bundle.main.bundleURL.path : "/Users/lu/HUB/MacNAP/MacNAP.app"
            let helperScript = "sleep 0.8; open \"\(appPath)\""
            var helperPid: pid_t = 0
            var args: [UnsafeMutablePointer<CChar>?] = [
                strdup("/bin/sh"),
                strdup("-c"),
                strdup(helperScript),
                nil
            ]
            _ = posix_spawn(&helperPid, "/bin/sh", nil, nil, &args, nil)
        }

        Darwin.signal(SIGABRT, macnapSignalCrashHandler)
        Darwin.signal(SIGSEGV, macnapSignalCrashHandler)
        Darwin.signal(SIGBUS, macnapSignalCrashHandler)
        Darwin.signal(SIGILL, macnapSignalCrashHandler)
        Darwin.signal(SIGTRAP, macnapSignalCrashHandler)
        Darwin.signal(SIGFPE, macnapSignalCrashHandler)
    }

    /// Giám sát ngầm độc lập: nếu MacNAP bị dừng đột ngột mà không qua Clean Shutdown, tự khởi động lại
    private func spawnCrashWatchdogDaemon() {
        let appPID = ProcessInfo.processInfo.processIdentifier
        let appBundlePath = Bundle.main.bundleURL.path.hasSuffix(".app") ? Bundle.main.bundleURL.path : "/Users/lu/HUB/MacNAP/MacNAP.app"
        let lockPath = lockFileURL.path

        let watchdogScript = """
        APP_PID=\(appPID)
        APP_PATH="\(appBundlePath)"
        LOCK_FILE="\(lockPath)"
        LAST_CRASH_FILE="/tmp/macnap_last_crash_ts"
        COUNT_FILE="/tmp/macnap_crash_streak"

        while kill -0 "$APP_PID" 2>/dev/null; do
            sleep 1.0
        done

        # Khi app dừng: Nếu Lock file vẫn còn tồn tại -> Văng/Crash đột ngột
        if [ -f "$LOCK_FILE" ]; then
            NOW=$(date +%s)
            LAST_TS=$(cat "$LAST_CRASH_FILE" 2>/dev/null || echo 0)
            COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
            DIFF=$((NOW - LAST_TS))

            if [ "$DIFF" -lt 25 ]; then
                COUNT=$((COUNT + 1))
            else
                COUNT=1
            fi
            echo "$NOW" > "$LAST_CRASH_FILE"
            echo "$COUNT" > "$COUNT_FILE"

            # Tránh vòng lặp crash vô tận (chỉ tự khởi động lại tối đa 3 lần / 25 giây)
            if [ "$COUNT" -le 3 ]; then
                sleep 0.8
                open "$APP_PATH"
            fi
        fi
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", watchdogScript]
        try? proc.run()
    }

    private func loadRecentEntriesFromDisk() {
        guard let content = try? String(contentsOf: primaryLogURL, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }.suffix(120)
        var parsed: [AppDiagnosticLogEntry] = []
        for line in lines {
            // Format: [2026-10-28 11:38:00.123] [LEVEL] [Component] Message
            let parts = line.components(separatedBy: "] [")
            if parts.count >= 3 {
                let timeStr = parts[0].replacingOccurrences(of: "[", with: "")
                let levelStr = parts[1]
                let rest = parts.dropFirst(2).joined(separator: "] [")
                let compAndMsg = rest.components(separatedBy: "] ")
                let comp = compAndMsg.first ?? "App"
                let msg = compAndMsg.dropFirst().joined(separator: "] ")
                let lvl = DiagnosticLogLevel(rawValue: levelStr) ?? .info
                parsed.append(
                    AppDiagnosticLogEntry(
                        timeString: timeStr,
                        level: lvl,
                        component: comp,
                        message: msg.isEmpty ? line : msg
                    )
                )
            } else {
                parsed.append(
                    AppDiagnosticLogEntry(
                        timeString: dateFormatter.string(from: Date()),
                        level: line.contains("CRASH") || line.contains("SIGNAL") ? .crash : .info,
                        component: "RawLog",
                        message: line
                    )
                )
            }
        }
        entriesBuffer = parsed.reversed()
    }

    public func log(_ level: DiagnosticLogLevel, component: String, message: String) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let timeStr = dateFormatter.string(from: now)
        let entry = AppDiagnosticLogEntry(
            timestamp: now,
            timeString: timeStr,
            level: level,
            component: component,
            message: message
        )

        entriesBuffer.insert(entry, at: 0)
        if entriesBuffer.count > 250 {
            entriesBuffer.removeLast(entriesBuffer.count - 250)
        }

        let formattedLine = "[\(timeStr)] [\(level.rawValue)] [\(component)] \(message)\n"
        if let data = formattedLine.data(using: .utf8) {
            appendDataSynchronously(data, to: primaryLogURL)
            appendDataSynchronously(data, to: userLibraryLogURL)
        }
    }

    private func appendDataSynchronously(_ data: Data, to url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.synchronize()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func recentEntries() -> [AppDiagnosticLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entriesBuffer
    }

    public func clearLogs() {
        lock.lock()
        entriesBuffer.removeAll()
        try? "".write(to: primaryLogURL, atomically: true, encoding: .utf8)
        try? "".write(to: userLibraryLogURL, atomically: true, encoding: .utf8)
        lock.unlock()
        log(.info, component: "Logger", message: "Đã xoá sạch nhật ký hoạt động theo yêu cầu người dùng.")
    }
}

