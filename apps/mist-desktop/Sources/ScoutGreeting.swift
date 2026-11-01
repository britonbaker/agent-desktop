import Foundation

/// Reach a side bezel before lifting the front wheels against it.
struct ScoutGreeting {
    let origin:CGPoint
    let destination:CGPoint
    let initialHeading:Double
    var pointsPerUnit=55.0
    var edgeHeading:Double?=nil
    var heading:Double {edgeHeading ?? (destination.x<origin.x ? -.pi/2 : .pi/2)}
    var travel:Double {hypot(destination.x-origin.x,destination.y-origin.y)}
    var approach:Double {max(0.55,travel/480)}
    var duration:Double {0.3+approach+2.5}
    static func smooth(_ value:Double) -> Double {
        let t=min(1,max(0,value));return t*t*(3-2*t)
    }
    static func destination(from origin:CGPoint,in area:CGRect,pointsPerUnit:Double) -> CGPoint {
        let inset=pointsPerUnit*0.726+2
        let center=origin.x+150
        let left=area.minX+inset-150,right=area.maxX-inset-150
        return CGPoint(x:center<area.midX ? left : right,y:origin.y)
    }
    func pose(at time:Double,holdAtEdge:Bool=false) -> (position:CGPoint,heading:Double,pitch:Double,distance:Double,moving:Bool) {
        let roll=Self.smooth((time-0.3)/approach)
        let contact=holdAtEdge ? min(1.35,time-0.3-approach) : time-0.3-approach
        var turn=heading-initialHeading
        while turn > .pi {turn-=2 * .pi}
        while turn < -.pi {turn+=2 * .pi}
        let direction=heading<0 ? -1.0 : 1.0
        let pitch=0.62*Self.smooth(contact/0.42)*(1-Self.smooth((contact-1.45)/0.6))
        let push=(1-cos(pitch))*0.862*pointsPerUnit
        let retreat=16*Self.smooth((contact-2.05)/0.45)
        let position=CGPoint(x:origin.x+(destination.x-origin.x)*roll+direction*(push-retreat),y:origin.y)
        return (position,initialHeading+turn*Self.smooth(time/0.3),pitch,travel*roll+min(2,max(0,contact))*7-retreat,(time>0.3 && contact<0) || retreat>0 && retreat<16)
    }
}
