import Foundation

struct DoubleShift {
    private var down:Double?
    private var previousRelease:Double?
    private var blockedUntil=0.0
    mutating func typed(at time:Double) {down=nil;previousRelease=nil;blockedUntil=time+0.65}
    mutating func changed(at time:Double,held:Bool,otherModifier:Bool=false) -> Bool {
        if otherModifier {typed(at:time);return false}
        guard time>=blockedUntil else {return false}
        if held {if down==nil {down=time};return false}
        guard let pressed=down else {return false};down=nil
        guard time-pressed<=0.35 else {previousRelease=nil;return false}
        defer {previousRelease=time}
        if let last=previousRelease,time-last>=0.12,time-last<=0.55 {
            previousRelease=nil;blockedUntil=time+0.8;return true
        }
        return false
    }
}
