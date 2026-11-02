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
    private struct Sample {var time=0.0,strength=0.0,keyboardAge=0.0}
    // Three minutes at 100 Hz, capped below half a megabyte. No key codes or text.
    private var recent=[Sample](repeating:Sample(),count:18000)
    private var recentCount=0,recentNext=0
    func exportDiagnostics(to url:URL) throws {
        let start=recentCount==recent.count ? recentNext : 0
        let rows=(0..<recentCount).map {recent[(start+$0)%recent.count]}
        let epoch=rows.first?.time ?? 0
        let data=try JSONSerialization.data(withJSONObject:rows.map {[$0.time-epoch,$0.strength,$0.keyboardAge]})
        try data.write(to:url,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
    }
    private func record(time:Double,strength:Double,keyboardAge:Double) {
        guard time.isFinite,strength.isFinite,keyboardAge.isFinite else {return}
        let previous=(recentNext+recent.count-1)%recent.count
        if recentCount>0,time-recent[previous].time<0.01 {
            if strength>recent[previous].strength {recent[previous].strength=strength;recent[previous].keyboardAge=keyboardAge}
        } else {
            recent[recentNext]=Sample(time:time,strength:strength,keyboardAge:keyboardAge)
            recentNext=(recentNext+1)%recent.count;recentCount=min(recent.count,recentCount+1)
        }
    }
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
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
        IOObjectRelease(iterator)
        guard !devices.isEmpty else { stop(); throw NSError(domain: "RoveMotion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Motion sensor unavailable. Use the character’s Talk button."]) }
    }
    func stop() {
        for device in devices { IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue); IOHIDDeviceClose(device, 0) }
        devices.removeAll()
        buffers.forEach { $0.deallocate() }; buffers.removeAll()
        for (driver, saved) in changed {
            for (key, value) in saved.reversed() { IORegistryEntrySetCFProperty(driver, key as CFString, value) }
            IOObjectRelease(driver)
        }
        changed.removeAll(); previous.removeAll(); samples = 0;recentCount=0;recentNext=0
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
        let age=keyboardAge+now-keyboardCheck
        record(time:now,strength:strength,keyboardAge:age)
        onSample?(now,strength,age)
    }
}
