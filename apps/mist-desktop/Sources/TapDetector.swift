import Foundation

struct TapDetector {
    var threshold: Double = 0.012
    private var peaks: [Double] = []
    private var lastPeak = -100.0
    private var blockedUntil = 0.0
    private var wasHigh = false
    mutating func reset(at time: Double) {
        peaks.removeAll(); blockedUntil = time + 0.7; wasHigh = false
    }
    mutating func update(time: Double, strength: Double, keyboardAge: Double) -> Bool {
        if !keyboardAge.isFinite || keyboardAge < 0 { reset(at: time); return false }
        if keyboardAge < 0.65 {
            peaks.removeAll(); wasHigh = false
            blockedUntil = max(blockedUntil, time + 0.65 - keyboardAge)
            return false
        }
        guard time >= blockedUntil else { return false }
        if let last = peaks.last, time - last > 0.55 {
            let accepted = peaks.count == 2 && peaks[1] - peaks[0] >= 0.16 && peaks[1] - peaks[0] <= 0.5
            peaks.removeAll()
            if accepted { blockedUntil = time + 0.8; return true }
        }
        let high = strength >= threshold
        defer { wasHigh = high }
        if high && !wasHigh && time - lastPeak >= 0.14 {
            if let last = peaks.last, time - last > 0.5 { peaks.removeAll() }
            peaks.append(time); lastPeak = time
        }
        return false
    }
}
