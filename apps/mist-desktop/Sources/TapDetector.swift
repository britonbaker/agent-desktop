import Foundation

enum TapGesture {case double,triple}

struct TapDetector {
    var threshold: Double = 0.012
    private var peaks: [Double] = []
    private var lastPeak = -100.0
    private var blockedUntil = 0.0
    private var wasHigh = false
    mutating func reset(at time: Double) {
        peaks.removeAll(); blockedUntil = time + 0.7; wasHigh = false
    }
    mutating func update(time:Double,strength:Double,keyboardAge:Double)->Bool {
        updateGesture(time:time,strength:strength,keyboardAge:keyboardAge) == .double
    }
    mutating func updateGesture(time: Double, strength: Double, keyboardAge: Double) -> TapGesture? {
        if !keyboardAge.isFinite || keyboardAge < 0 { reset(at: time); return nil }
        if keyboardAge < 0.65 {
            peaks.removeAll(); wasHigh = false
            blockedUntil = max(blockedUntil, time + 0.65 - keyboardAge)
            return nil
        }
        guard time >= blockedUntil else { return nil }
        if let last = peaks.last, time - last > 0.55 {
            let accepted = (2...3).contains(peaks.count) && zip(peaks,peaks.dropFirst()).allSatisfy { $1-$0 >= 0.16 && $1-$0 <= 0.5 }
            let gesture:TapGesture = peaks.count==3 ? .triple : .double
            peaks.removeAll()
            if accepted { blockedUntil = time + 0.8; return gesture }
        }
        let high = strength >= threshold
        defer { wasHigh = high }
        if high && !wasHigh {
            if time-lastPeak>=0.14 {
                if let last=peaks.last,time-last>0.5 {peaks.removeAll()}
                peaks.append(time)
            }
            // One impact rings across the threshold many times. Extend the quiet
            // refractory period instead of invalidating the whole tap sequence.
            lastPeak=time
        }
        return nil
    }
}
