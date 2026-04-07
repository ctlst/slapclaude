import CoreFoundation
import IOKit
import IOKit.hid
import Foundation

// Reads the built-in BMI286 IMU via IOKit by:
//   1. Waking the AppleSPUHIDDriver (SensorPropertyReportingState/PowerState)
//   2. Opening AppleSPUHIDDevice directly via IOHIDDeviceCreate (bypasses motionRestrictedService)
// Reports at ~800Hz; x/y/z in g-force units (Q16 raw / 65536).
final class AccelerometerSlapDetector {
    var onSlap: (() -> Void)?
    var sensitivity: Sensitivity = .medium

    private var devices: [IOHIDDevice] = []
    private var reportBuffer = [UInt8](repeating: 0, count: 4096)
    private var baseline: Double = 1.0
    private var lastSlapTime: Date = .distantPast
    private let debounce: TimeInterval = 0.6
    private let emaAlpha = 0.015

    func start() -> Bool {
        wakeDrivers()
        return openDevices()
    }

    func stop() {
        for dev in devices { IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone)) }
        devices.removeAll()
    }

    // MARK: - Private

    private func wakeDrivers() {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
              IOServiceMatching("AppleSPUHIDDriver"), &it) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(it) }
        var svc: io_service_t = IOIteratorNext(it)
        while svc != 0 {
            IORegistryEntrySetCFProperty(svc, "SensorPropertyReportingState" as CFString, 1 as CFNumber)
            IORegistryEntrySetCFProperty(svc, "SensorPropertyPowerState"    as CFString, 1 as CFNumber)
            IORegistryEntrySetCFProperty(svc, "ReportInterval"              as CFString, 1000 as CFNumber)
            IOObjectRelease(svc)
            svc = IOIteratorNext(it)
        }
        log("SPU drivers woken")
    }

    private func openDevices() -> Bool {
        var it: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
              IOServiceMatching("AppleSPUHIDDevice"), &it) == KERN_SUCCESS else {
            log("No AppleSPUHIDDevice found")
            return false
        }
        defer { IOObjectRelease(it) }

        var opened = 0
        var svc: io_service_t = IOIteratorNext(it)
        while svc != 0 {
            defer { IOObjectRelease(svc); svc = IOIteratorNext(it) }

            // Only the accelerometer (PrimaryUsage == 3)
            guard let usageRef = IORegistryEntryCreateCFProperty(
                    svc, "PrimaryUsage" as CFString, kCFAllocatorDefault, 0),
                  let usage = (usageRef.takeRetainedValue() as? Int),
                  usage == 3
            else { continue }

            guard let dev = IOHIDDeviceCreate(kCFAllocatorDefault, svc) else { continue }
            guard IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { continue }

            let ctx = Unmanaged.passUnretained(self).toOpaque()
            IOHIDDeviceRegisterInputReportCallback(
                dev, &reportBuffer, CFIndex(reportBuffer.count),
                { ctx, _, _, _, _, report, length in
                    guard let ctx, length == 22 else { return }
                    Unmanaged<AccelerometerSlapDetector>.fromOpaque(ctx)
                        .takeUnretainedValue().handleReport(report)
                }, ctx)
            IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

            devices.append(dev)
            opened += 1
            log("Accelerometer opened (usage=3)")
        }
        return opened > 0
    }

    private func handleReport(_ report: UnsafeMutablePointer<UInt8>) {
        func i32(_ offset: Int) -> Int32 {
            Int32(report[offset])
                | Int32(report[offset+1]) << 8
                | Int32(report[offset+2]) << 16
                | Int32(report[offset+3]) << 24
        }
        let x = Double(i32(6))  / 65536.0
        let y = Double(i32(10)) / 65536.0
        let z = Double(i32(14)) / 65536.0
        let mag = (x*x + y*y + z*z).squareRoot()

        let spike = mag - baseline
        if spike > sensitivity.accelThreshold {
            let now = Date()
            if now.timeIntervalSince(lastSlapTime) > debounce {
                lastSlapTime = now
                log(String(format: "SLAP (accel) mag=%.3f spike=%.3f", mag, spike))
                DispatchQueue.main.async { self.onSlap?() }
            }
        }
        if spike < sensitivity.accelThreshold {
            baseline = emaAlpha * mag + (1 - emaAlpha) * baseline
        }
    }
}
