import Foundation
import CoreGraphics

/// A repeating approach/reverse loop, with gentle travel along the edge.
/// Parameter derivatives vanish at the ends, so reversing never snaps the heading.
struct ScoutEdgeCalibration {
    static let period=7.2
    /// Continue onto the curve once the front tire's leading tread reaches it.
    /// The rear axle remains the support pivot, rather than lifting the whole rover.
    static func climb(center:CGPoint,heading:Double,right:Bool,area:CGRect,scale:Double,settings:ScoutWall.Settings)->Double {
        guard scale>0 else {return 0}
        let s=settings.sanitized(),radius=s.radius*scale,direction=right ? 1.0 : -1.0
        let alignment=max(0,direction*sin(heading))
        guard alignment>0.6 else {return 0}
        let leading=center.x+sin(heading)*0.726*scale
        let distance=right ? area.maxX-leading : leading-area.minX
        let run=min(radius*0.96,max(0,radius-distance))
        let tangent=atan2(s.rise*run,sqrt(max(0.001,radius*radius-run*run)))
        return min(0.72,tangent)*alignment*alignment
    }
    static func pose(time:Double,right:Bool,area:CGRect,scale:Double,settings:ScoutWall.Settings=ScoutWall.Settings())->(center:CGPoint,heading:Double,forward:Bool,moving:Bool) {
        let phase=max(0,time).truncatingRemainder(dividingBy:period)
        let forward=phase<period/2
        let local=forward ? phase : phase-period/2
        let t=min(1,max(0,(local-0.1)/3.4))
        let ease=ScoutGreeting.smooth(t),p=forward ? ease : 1-ease
        let direction=right ? 1.0 : -1.0
        let travel=min(area.width*0.42,max(310,settings.radius*scale+230)),sway=min(160,area.height*0.2)
        let side=forward ? 1.0 : -1.0
        let dy=side*sway*Double.pi*sin(2*Double.pi*p)
        let heading=atan2(direction*travel,dy)
        let extent=ScoutWall.clearance(heading:right ? .pi/2 : -.pi/2,scale:scale,settings:settings)
        let near=right ? area.maxX-extent.width : area.minX+extent.width
        let x=near-direction*travel*(1-p),y=area.midY+side*sway*pow(sin(Double.pi*p),2)
        let center=ScoutWall.confinedCenter(CGPoint(x:x,y:y),heading:heading,scale:scale,area:area,settings:settings)
        return (center,heading,forward,t>0 && t<1)
    }
}
