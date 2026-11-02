import Foundation

enum TapGesture {case double,triple}

struct TapDetector {
    var threshold: Double = 0.012
    private var peaks: [Double] = []
    private var lastPeak = -100.0
    private var lastHigh = -100.0
    private var impactPeak = 0.0
    private var envelope=0.0,lastSampleTime:Double?
    private var blockedUntil = 0.0
    private var wasHigh = false
    mutating func reset(at time: Double) {
        peaks.removeAll(); blockedUntil = time + 0.7; wasHigh = false;impactPeak=0;lastHigh=time;envelope=0;lastSampleTime=nil
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
        let dt=min(0.05,max(0.0001,time-(lastSampleTime ?? time-0.001)))
        lastSampleTime=time
        let priorEnvelope=envelope
        envelope+=(strength-envelope)*(1-exp(-dt/0.025))
        let high = strength >= threshold
        defer { wasHigh = high }
        if high {
            // A case impact rings for hundreds of milliseconds. Quiet rearming
            // still rejects echoes, but a fresh, stronger attack can start the
            // second impact without waiting for the first one's tail to end.
            let separated = !wasHigh && time-lastHigh>=0.14
            let freshAttack = strength>impactPeak*1.10 && strength>priorEnvelope+threshold*0.20
            if time-lastPeak>=0.16 && (separated || freshAttack) {
                if let last=peaks.last,time-last>0.5 {peaks.removeAll()}
                peaks.append(time);lastPeak=time;impactPeak=strength
            } else {impactPeak=max(impactPeak,strength)}
            lastHigh=time
        }
        return nil
    }
}
