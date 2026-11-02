import Foundation

/// A small damped controller around a rear-axle balance pose, in model units.
/// Wheel corrections oppose angular error; a tap adds momentum, not a canned pose.
struct ScoutBalance {
    private(set) var presentation=0.0,tilt=0.0,wheelTravel=0.0
    private var presentationVelocity=0.0,angularVelocity=0.0,wheelVelocity=0.0,age=0.0
    mutating func tap() {angularVelocity += 0.34}
    mutating func step(_ elapsed:Double,engaged:Bool,reducedMotion:Bool=false) {
        let target=engaged ? 1.0 : 0.0
        if reducedMotion {presentation=target;presentationVelocity=0;tilt=0;angularVelocity=0;wheelTravel=0;wheelVelocity=0;return}
        let duration=min(0.1,max(0,elapsed)),count=max(1,Int(ceil(duration*120))),dt=duration/Double(count)
        for _ in 0..<count {
            age+=dt
            presentationVelocity+=((target-presentation)*80-presentationVelocity*12)*dt
            presentation=min(1.045,max(0,presentation+presentationVelocity*dt))
            // Small sensor/controller error keeps the balancing pose alive without a looped sway.
            let disturbance=engaged ? sin(age*1.9)*0.14+sin(age*3.7)*0.06 : 0
            angularVelocity+=(-tilt*72-angularVelocity*9+disturbance)*dt
            tilt=min(0.075,max(-0.075,tilt+angularVelocity*dt))
            wheelVelocity+=(tilt*70+angularVelocity*5-wheelTravel*24-wheelVelocity*8)*dt
            wheelTravel=min(0.07,max(-0.07,wheelTravel+wheelVelocity*dt))
        }
        if !engaged && presentation<0.001 {presentation=0;presentationVelocity=0;tilt=0;angularVelocity=0;wheelTravel=0;wheelVelocity=0}
    }
    var pitchCorrection:Double {tilt*min(1,presentation)}
    var travel:Double {wheelTravel*min(1,presentation)}
}
