import Foundation
@main struct Capture {
    static func main() throws {
        setbuf(stdout, nil)
        let sensor = MotionSensor()
        var rows: [[Double]] = []
        let start = ProcessInfo.processInfo.systemUptime
        sensor.onSample = { time, strength, age in
            rows.append([time - start, strength, age])
        }
        try sensor.start()
        print("CAPTURE READY")
        CFRunLoopRunInMode(.defaultMode, Double(CommandLine.arguments.dropFirst(2).first ?? "35") ?? 35, false)
        sensor.stop()
        let path = CommandLine.arguments[1]
        try JSONSerialization.data(withJSONObject: rows).write(to: URL(fileURLWithPath: path))
        print("SAVED \(rows.count) samples to \(path)")
    }
}
