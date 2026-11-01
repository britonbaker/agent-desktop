import Foundation
import CoreGraphics

/// A rounded floor-to-bezel transition sampled at the four tire contacts.
struct ScoutWall {
    struct Pose {
        var pitch=0.0,roll=0.0,height=0.0
        var contact:Bool {height>0.0001}
    }
    static func pose(center:CGPoint,heading:Double,scale:Double,area:CGRect) -> Pose {
        guard scale>0,area.width>0,area.height>0 else {return Pose()}
        let radius=0.78*scale
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
