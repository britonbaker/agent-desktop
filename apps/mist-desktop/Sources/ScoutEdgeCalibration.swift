import Foundation
import CoreGraphics

/// A repeating approach/reverse loop, with gentle travel along the edge.
/// Parameter derivatives vanish at the ends, so reversing never snaps the heading.
struct ScoutEdgeCalibration {
    static let period=7.2
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
