import Foundation
import IOKit

public final class PowerTelemetryService {
    public init() {}

    public func readBatteryAndSystemPower() -> (
        systemLoadW: Double,
        batteryW: Double,
        adapterW: Double,
        voltageV: Double,
        amperagemA: Int,
        percent: Int,
        isCharging: Bool,
        externalConnected: Bool,
        remainingmAh: Int,
        fullChargemAh: Int
    ) {
        let matching = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0, 0, 12.0, 0, 100, false, false, 0, 0)
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            return (0, 0, 0, 12.0, 0, 100, false, false, 0, 0)
        }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else {
            return (0, 0, 0, 12.0, 0, 100, false, false, 0, 0)
        }

        let voltageMV = (props["Voltage"] as? Int) ?? 12000
        let voltageV = Double(voltageMV) / 1000.0
        let amperage = (props["InstantAmperage"] as? Int) ?? (props["Amperage"] as? Int) ?? 0
        let percent = (props["CurrentCapacity"] as? Int) ?? 100
        let isCharging = (props["IsCharging"] as? Bool) ?? false
        let externalConnected = (props["ExternalConnected"] as? Bool) ?? false

        var systemLoadW = 0.0
        var adapterW = 0.0
        var batteryW = abs(Double(amperage) * voltageV / 1000.0)

        if let telemetry = props["PowerTelemetryData"] as? [String: Any] {
            if let sysLoadMW = telemetry["SystemLoad"] as? Int {
                systemLoadW = Double(sysLoadMW) / 1000.0
            }
            if let sysPowerInMW = telemetry["SystemPowerIn"] as? Int {
                adapterW = Double(sysPowerInMW) / 1000.0
            }
            if let batPowerMW = telemetry["BatteryPower"] as? Int, batPowerMW != 0 {
                batteryW = abs(Double(batPowerMW)) / 1000.0
            }
        }

        if systemLoadW == 0 {
            systemLoadW = batteryW > 0 ? batteryW : adapterW
        }

        var remainingmAh = 0
        var fullChargemAh = 0
        if let batteryData = props["BatteryData"] as? [String: Any] {
            remainingmAh = (batteryData["RemainingCapacity"] as? Int) ?? 0
            fullChargemAh = (batteryData["FullChargeCapacity"] as? Int) ?? 0
        }

        return (
            systemLoadW: systemLoadW,
            batteryW: batteryW,
            adapterW: adapterW,
            voltageV: voltageV,
            amperagemA: amperage,
            percent: percent,
            isCharging: isCharging,
            externalConnected: externalConnected,
            remainingmAh: remainingmAh,
            fullChargemAh: fullChargemAh
        )
    }

    public func scanPeripherals(mountedDisks: [(bsdName: String, volumeName: String, mediaName: String)]) -> [PeripheralDevice] {
        var results: [PeripheralDevice] = []
        var seenIDs = Set<String>()

        let matching = IOServiceMatching("IOUSBHostDevice")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            var entry = IOIteratorNext(iterator)
            while entry != 0 {
                defer {
                    IOObjectRelease(entry)
                    entry = IOIteratorNext(iterator)
                }

                var propsRef: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(entry, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                      let props = propsRef?.takeRetainedValue() as? [String: Any] else {
                    continue
                }

                let name = (props["USB Product Name"] as? String)
                    ?? (props["kUSBProductString"] as? String)
                    ?? "USB Device"
                let vendor = (props["USB Vendor Name"] as? String)
                    ?? (props["kUSBVendorString"] as? String)
                    ?? "Generic"
                let locationID = (props["locationID"] as? Int) ?? Int.random(in: 1000...999999)
                let idStr = "usb-\(locationID)-\(name)"
                if seenIDs.contains(idStr) { continue }
                seenIDs.insert(idStr)

                let sinkAlloc = (props["UsbPowerSinkAllocation"] as? Int) ?? 0
                let sleepAlloc = (props["SleepPowerAlloc"] as? Int) ?? 0
                let speed = (props["Device Speed"] as? Int) ?? (props["USBSpeed"] as? Int) ?? 1

                let isHub = name.localizedCaseInsensitiveContains("Hub")
                let isStorage = name.localizedCaseInsensitiveContains("Storage")
                    || name.localizedCaseInsensitiveContains("RTL92")
                    || name.localizedCaseInsensitiveContains("NVMe")
                    || name.localizedCaseInsensitiveContains("SSD")
                    || name.localizedCaseInsensitiveContains("Disk")

                let currentmA: Int
                if sinkAlloc > 0 {
                    currentmA = sinkAlloc
                } else if isHub {
                    currentmA = 150
                } else if isStorage {
                    currentmA = 900
                } else {
                    currentmA = speed >= 3 ? 500 : 200
                }

                let voltageV = 5.0
                let watts = (Double(currentmA) * voltageV) / 1000.0

                var matchedBSD: String?
                var displayName = name
                if isStorage, let firstDisk = mountedDisks.first {
                    matchedBSD = firstDisk.bsdName
                    displayName = "\(name) (\(firstDisk.volumeName))"
                }

                let kind: PeripheralKind = isStorage ? .externalDrive : (isHub ? .usbHub : .usbDevice)
                results.append(
                    PeripheralDevice(
                        id: idStr,
                        name: displayName,
                        vendor: vendor,
                        kind: kind,
                        currentmA: currentmA,
                        voltageV: voltageV,
                        watts: watts,
                        canUnmount: isStorage,
                        bsdName: matchedBSD,
                        isMounted: matchedBSD != nil,
                        sleepCapable: sleepAlloc > 0 || !isHub
                    )
                )
            }
        }

        // Fallback external disks not matched via USB product name
        for disk in mountedDisks {
            let alreadyAttached = results.contains { $0.bsdName == disk.bsdName }
            if !alreadyAttached {
                results.append(
                    PeripheralDevice(
                        id: "disk-\(disk.bsdName)",
                        name: "\(disk.volumeName) (\(disk.bsdName))",
                        vendor: disk.mediaName,
                        kind: .externalDrive,
                        currentmA: 896,
                        voltageV: 5.0,
                        watts: 4.48,
                        canUnmount: true,
                        bsdName: disk.bsdName,
                        isMounted: true,
                        sleepCapable: true
                    )
                )
            }
        }

        return results.sorted { $0.watts > $1.watts }
    }
}
