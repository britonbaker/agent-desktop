import Foundation
import IOKit
import IOKit.hid

/// Read-only feature report. No driver properties or power settings are changed.
final class LidAngle {
    private var device: IOHIDDevice?
    init() {
        var iterator:io_iterator_t=0
        IOServiceGetMatchingServices(kIOMainPortDefault,IOServiceMatching("AppleSPUHIDDevice"),&iterator)
        defer { IOObjectRelease(iterator) }
        while true {
            let service=IOIteratorNext(iterator);if service==0 {break};defer{IOObjectRelease(service)}
            func number(_ key:String)->Int? {(IORegistryEntryCreateCFProperty(service,key as CFString,kCFAllocatorDefault,0)?.takeRetainedValue() as? NSNumber)?.intValue}
            guard number("PrimaryUsagePage")==32,number("PrimaryUsage")==138,let candidate=IOHIDDeviceCreate(kCFAllocatorDefault,service),IOHIDDeviceOpen(candidate,0)==kIOReturnSuccess else {continue}
            device=candidate;break
        }
    }
    func read() -> Double? {
        guard let device else {return nil}
        var bytes=[UInt8](repeating:0,count:8),length=8
        guard IOHIDDeviceGetReport(device,kIOHIDReportTypeFeature,1,&bytes,&length)==kIOReturnSuccess,length>=3 else {return nil}
        let degrees=Int(bytes[1])|Int(bytes[2])<<8
        return (0...180).contains(degrees) ? Double(degrees) : nil
    }
    deinit {if let device {IOHIDDeviceClose(device,0)}}
}
