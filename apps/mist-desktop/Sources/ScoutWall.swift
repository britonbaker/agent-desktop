import Foundation
import CoreGraphics

/// A rounded floor-to-bezel transition sampled at the four tire contacts.
struct ScoutWall {
    struct Pose {
        var pitch=0.0,roll=0.0,height=0.0
        var contact:Bool {height>0.0001}
    }
    /// The box boundary contains the full tires, not just their axle/contact centers.
    /// Include a conservative allowance for the seven-degree camera and raised chassis.
    static func clearance(heading:Double,scale:Double)->CGSize {
        let c=abs(cos(heading)),s=abs(sin(heading)),parallax=0.24
        return CGSize(width:(c*0.84+s*0.78+parallax)*scale+3,
                      height:(s*0.84+c*0.78+parallax)*scale+3)
    }
    static func confinedCenter(_ center:CGPoint,heading:Double,scale:Double,area:CGRect)->CGPoint {
        guard scale>0,area.width>0,area.height>0 else {return center}
        let extent=clearance(heading:heading,scale:scale)
        let x=min(extent.width,area.width/2),y=min(extent.height,area.height/2)
        return CGPoint(x:min(area.maxX-x,max(area.minX+x,center.x)),y:min(area.maxY-y,max(area.minY+y,center.y)))
    }
    static func pose(center:CGPoint,heading:Double,scale:Double,area:CGRect) -> Pose {
        guard scale>0,area.width>0,area.height>0 else {return Pose()}
        let radius=1.35*scale
        func height(_ p:CGPoint)->Double {
            let distance=min(p.x-area.minX,area.maxX-p.x,p.y-area.minY,area.maxY-p.y)
            let run=min(radius*0.995,max(0,radius-distance))
            return (radius-sqrt(max(0,radius*radius-run*run)))/scale
        }
        let c=cos(heading),s=sin(heading)
        func tire(_ x:Double,_ z:Double)->Double {
            height(CGPoint(x:center.x+(c*x+s*z)*scale,y:center.y+(-s*x+c*z)*scale))
        }
        let fl=tire(-0.74,0.431),fr=tire(0.74,0.431)
        let rl=tire(-0.74,-0.431),rr=tire(0.74,-0.431)
        // Least-squares contact plane: an oblique approach banks and pitches.
        let pitch=atan(((fl+fr)-(rl+rr))/(4*0.431))
        let roll=atan(((fr+rr)-(fl+rl))/(4*0.74))
        return Pose(pitch:pitch,roll:roll,height:(fl+fr+rl+rr)/4)
    }
}
