import Foundation
import CoreGraphics

/// Damped load transfer for the sprung chassis; tire contacts stay in the base frame.
struct ScoutSuspension {
    private(set) var pitch=0.0,roll=0.0,heave=0.0,yawTravel=0.0,yawRate=0.0
    private var pitchVelocity=0.0,rollVelocity=0.0,heaveVelocity=0.0
    private var previous:(CGPoint,Double)?
    private var velocity=CGPoint.zero,forwardLoad=0.0,lateralLoad=0.0
    mutating func step(position:CGPoint,heading:Double,elapsed:Double,reducedMotion:Bool=false) {
        defer {previous=(position,heading)}
        guard let old=previous else {return}
        let dt=min(0.08,max(0.001,elapsed))
        var turn=heading-old.1
        while turn > .pi {turn-=2 * .pi};while turn < -.pi {turn+=2 * .pi}
        yawTravel+=turn
        let rate=turn/dt,yawAcceleration=(rate-yawRate)/dt;yawRate=rate
        let next=CGPoint(x:(position.x-old.0.x)/dt,y:(position.y-old.0.y)/dt)
        if reducedMotion || hypot(position.x-old.0.x,position.y-old.0.y)>120 {
            pitch=0;roll=0;heave=0;pitchVelocity=0;rollVelocity=0;heaveVelocity=0;velocity=next;forwardLoad=0;lateralLoad=0;return
        }
        let ax=(next.x-velocity.x)/dt,ay=(next.y-velocity.y)/dt;velocity=next
        let gain=1-exp(-dt*10)
        forwardLoad+=(ax*sin(heading)+ay*cos(heading)-forwardLoad)*gain
        lateralLoad+=(ax*cos(heading)-ay*sin(heading)-lateralLoad)*gain
        // Counter-rotating drive torque gives a small transient even during a pivot turn.
        let targetPitch=min(0.045,max(-0.045,-forwardLoad*0.000055+yawAcceleration*0.00010))
        let targetRoll=min(0.055,max(-0.055,-lateralLoad*0.00006-yawAcceleration*0.00028))
        let targetHeave = -min(0.014,(abs(forwardLoad)+abs(lateralLoad))*0.000007)
        let steps=max(1,Int(ceil(dt*120))),sub=dt/Double(steps)
        for _ in 0..<steps {
            pitchVelocity+=((targetPitch-pitch)*170-pitchVelocity*17)*sub
            rollVelocity+=((targetRoll-roll)*170-rollVelocity*17)*sub
            heaveVelocity+=((targetHeave-heave)*190-heaveVelocity*18)*sub
            pitch+=pitchVelocity*sub;roll+=rollVelocity*sub;heave+=heaveVelocity*sub
        }
    }
    var active:Bool {abs(yawRate)>0.08 || abs(pitch)+abs(roll)>0.003}
}

/// Preserve fractional simulation coordinates despite AppKit rounding window frames.
/// Ignore a stale simulation anchor after the OS relocates a window or display.
enum ScoutMotionOrigin {
    static func resolve(desired:CGPoint?,native:CGPoint)->CGPoint {
        guard let desired,abs(desired.x-native.x)<=2,abs(desired.y-native.y)<=2 else {return native}
        return desired
    }
}
