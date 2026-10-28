import Foundation
import IOKit

// MARK: - AppleSMC Direct Reader (Realtime PSTR / PDTR / PTRL / PTRR / VD0R / ID0R)
public final class SMCReader {
    public static let shared = SMCReader()

    private var connection: io_connect_t = 0
    private let lock = NSLock()

    private struct SMCKeyDataVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers = SMCKeyDataVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfoData()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        ) = (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    private init() {
        openConnection()
    }

    private func openConnection() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        IOServiceOpen(service, mach_task_self_, 0, &connection)
    }

    private func fourCharCode(_ str: String) -> UInt32 {
        var res: UInt32 = 0
        for ch in str.utf8.prefix(4) {
            res = (res << 8) | UInt32(ch)
        }
        return res
    }

    public func readFloat(_ key: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        if connection == 0 {
            openConnection()
            if connection == 0 { return nil }
        }

        let keyCode = fourCharCode(key)
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = keyCode
        input.data8 = 9 // kSMCGetKeyInfo

        let inSize = MemoryLayout<SMCKeyData>.stride
        var outSize = MemoryLayout<SMCKeyData>.stride

        let krInfo = IOConnectCallStructMethod(connection, 2, &input, inSize, &output, &outSize)
        guard krInfo == KERN_SUCCESS, output.keyInfo.dataSize > 0 else { return nil }

        let dataSize = output.keyInfo.dataSize
        let dataType = output.keyInfo.dataType

        input.keyInfo.dataSize = dataSize
        input.data8 = 5 // kSMCReadKey
        let krRead = IOConnectCallStructMethod(connection, 2, &input, inSize, &output, &outSize)
        guard krRead == KERN_SUCCESS else { return nil }

        let b = output.bytes
        // 'flt ' (0x666c7420)
        if dataType == fourCharCode("flt ") && dataSize == 4 {
            let raw = UInt32(b.0) | (UInt32(b.1) << 8) | (UInt32(b.2) << 16) | (UInt32(b.3) << 24)
            let val = Float(bitPattern: raw)
            if val.isFinite {
                return Double(val)
            }
        }
        // 'sp78'
        if dataType == fourCharCode("sp78") && dataSize == 2 {
            let signed = Int16(bitPattern: (UInt16(b.0) << 8) | UInt16(b.1))
            return Double(signed) / 256.0
        }
        // 'fpe2'
        if dataType == fourCharCode("fpe2") && dataSize == 2 {
            let unsigned = (UInt16(b.0) << 8) | UInt16(b.1)
            return Double(unsigned) / 4.0
        }
        return nil
    }
}

