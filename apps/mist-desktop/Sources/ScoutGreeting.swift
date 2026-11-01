import Foundation

/// Drive to a side bezel and park on all four wheels while listening.
struct ScoutGreeting {
    let origin:CGPoint
    let destination:CGPoint
    let initialHeading:Double
    var pointsPerUnit=55.0
    var heading:Double {destination.x<origin.x ? -.pi/2 : .pi/2}
    var travel:Double {hypot(destination.x-origin.x,destination.y-origin.y)}
    var approach:Double {max(0.55,travel/480)}
    var duration:Double {0.3+approach+0.15}
    static func smooth(_ value:Double) -> Double {
        let t=min(1,max(0,value));return t*t*(3-2*t)
    }
    static func destination(from origin:CGPoint,in area:CGRect,pointsPerUnit:Double) -> CGPoint {
        let inset=pointsPerUnit*0.726+2
        let center=origin.x+150
        let left=area.minX+inset-150,right=area.maxX-inset-150
        return CGPoint(x:center<area.midX ? left : right,y:origin.y)
    }
    func pose(at time:Double) -> (position:CGPoint,heading:Double,pitch:Double,distance:Double,moving:Bool) {
        let roll=Self.smooth((time-0.3)/approach)
        let contact=time-0.3-approach
        var turn=heading-initialHeading
        while turn > .pi {turn-=2 * .pi}
        while turn < -.pi {turn+=2 * .pi}
        let position=CGPoint(x:origin.x+(destination.x-origin.x)*roll,y:origin.y)
        return (position,initialHeading+turn*Self.smooth(time/0.3),0,travel*roll,time>0.3 && contact<0)
    }
}
