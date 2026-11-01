import Foundation

/// A short roll, rear-axle lift, and settle. Speech recognition runs independently.
struct ScoutGreeting {
    static let duration=2.8
    let origin:CGPoint
    let destination:CGPoint
    let initialHeading:Double
    static func smooth(_ value:Double) -> Double {
        let t=min(1,max(0,value));return t*t*(3-2*t)
    }
    func pose(at time:Double) -> (position:CGPoint,heading:Double,pitch:Double,distance:Double) {
        let roll=Self.smooth((time-0.22)/0.48)
        var turn=Double.pi-initialHeading
        while turn > .pi {turn-=2 * .pi}
        while turn < -.pi {turn+=2 * .pi}
        let heading=initialHeading+turn*Self.smooth(time/0.3)
        let pitch=0.54*Self.smooth((time-0.48)/0.38)*(1-Self.smooth((time-2.15)/0.65))
        let position=CGPoint(x:origin.x+(destination.x-origin.x)*roll,y:origin.y+(destination.y-origin.y)*roll)
        return (position,heading,pitch,hypot(destination.x-origin.x,destination.y-origin.y)*roll)
    }
}
