import Foundation
import IOKit
import IOKit.hid
import CoreGraphics

final class MotionSensor {
    var onSample: ((Double, Double, Double) -> Void)?
    private var devices: [IOHIDDevice] = []
    private var buffers: [UnsafeMutablePointer<UInt8>] = []
    private var changed: [(io_service_t, [(String, CFTypeRef)])] = []
    private var previous: [Double] = []
    private var keyboardCheck = 0.0
    private var keyboardAge = Double.infinity
    private(set) var samples = 0
    func start() throws {
        stop()
        var iterator: io_iterator_t = 0
        IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSPUHIDDriver"), &iterator)
        while true {
            let driver = IOIteratorNext(iterator)
            if driver == 0 { break }
            guard number(driver, "PrimaryUsagePage") == 0xFF00, number(driver, "PrimaryUsage") == 3 else { IOObjectRelease(driver); continue }
            var saved: [(String, CFTypeRef)] = []
            for (key, value) in [("SensorPropertyReportingState", 1), ("SensorPropertyPowerState", 1), ("ReportInterval", 1000)] {
                let old = IORegistryEntryCreateCFProperty(driver, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() ?? NSNumber(value: 0)
                let result = IORegistryEntrySetCFProperty(driver, key as CFString, NSNumber(value: value))
                if result == kIOReturnSuccess { saved.append((key, old)) }
            }
            changed.append((driver, saved))
        }
        IOObjectRelease(iterator)
        IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSPUHIDDevice"), &iterator)
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }
            guard number(service, "PrimaryUsagePage") == 0xFF00, number(service, "PrimaryUsage") == 3,
                  let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) else { continue }
            guard IOHIDDeviceOpen(device, 0) == kIOReturnSuccess else { continue }
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            devices.append(device); buffers.append(buffer)
            IOHIDDeviceRegisterInputReportCallback(device, buffer, 4096, { context, result, _, _, _, bytes, length in
                guard let context, result == kIOReturnSuccess, length == 22 else { return }
                Unmanaged<MotionSensor>.fromOpaque(context).takeUnretainedValue().receive(bytes, length)
            }, Unmanaged.passUnretained(self).toOpaque())
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        }
        IOObjectRelease(iterator)
        guard !devices.isEmpty else { stop(); throw NSError(domain: "RoveMotion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Motion sensor unavailable. Use the character’s Talk button."]) }
    }
    func stop() {
        for device in devices { IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue); IOHIDDeviceClose(device, 0) }
        devices.removeAll()
        buffers.forEach { $0.deallocate() }; buffers.removeAll()
        for (driver, saved) in changed {
            for (key, value) in saved.reversed() { IORegistryEntrySetCFProperty(driver, key as CFString, value) }
            IOObjectRelease(driver)
        }
        changed.removeAll(); previous.removeAll(); samples = 0
    }
    private func number(_ service: io_service_t, _ key: String) -> Int? {
        (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.intValue
    }
    private func receive(_ bytes: UnsafeMutablePointer<UInt8>, _ length: Int) {
        let data = Data(bytes: bytes, count: length)
        let xyz = [6, 10, 14].map { offset in Double(Int32(littleEndian: data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) })) / 65536 }
        samples += 1
        defer { previous = xyz }
        guard previous.count == 3 else { return }
        let strength = sqrt(zip(xyz, previous).map { pow($0 - $1, 2) }.reduce(0, +))
        let now = ProcessInfo.processInfo.systemUptime
        if now - keyboardCheck >= 0.02 {
            keyboardAge = min(CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown), CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .flagsChanged))
            keyboardCheck = now
        }
        onSample?(now, strength, keyboardAge + now - keyboardCheck)
    }
}
