import Foundation
import CoreGraphics

/// A rounded floor-to-bezel transition sampled at the four tire contacts.
struct ScoutWall {
    struct Settings:Codable,Equatable {
        var left=0.0,right=0.0,top=0.0,bottom=0.0
        var radius=1.35,rise=1.0,buffer=0.24
        var fullDisplay=false
        enum CodingKeys:String,CodingKey {case left,right,top,bottom,radius,rise,buffer,fullDisplay}
        init(left:Double=0,right:Double=0,top:Double=0,bottom:Double=0,radius:Double=1.35,rise:Double=1,buffer:Double=0.24,fullDisplay:Bool=false) {
            self.left=left;self.right=right;self.top=top;self.bottom=bottom;self.radius=radius;self.rise=rise;self.buffer=buffer;self.fullDisplay=fullDisplay
        }
        init(from decoder:Decoder) throws {
            let c=try decoder.container(keyedBy:CodingKeys.self)
            left=try c.decodeIfPresent(Double.self,forKey:.left) ?? 0;right=try c.decodeIfPresent(Double.self,forKey:.right) ?? 0
            top=try c.decodeIfPresent(Double.self,forKey:.top) ?? 0;bottom=try c.decodeIfPresent(Double.self,forKey:.bottom) ?? 0
            radius=try c.decodeIfPresent(Double.self,forKey:.radius) ?? 1.35;rise=try c.decodeIfPresent(Double.self,forKey:.rise) ?? 1
            buffer=try c.decodeIfPresent(Double.self,forKey:.buffer) ?? 0.24;fullDisplay=try c.decodeIfPresent(Bool.self,forKey:.fullDisplay) ?? false
        }
        func sanitized()->Settings {
            var s=self
            func value(_ v:Double,_ lo:Double,_ hi:Double,_ fallback:Double)->Double {v.isFinite ? min(hi,max(lo,v)) : fallback}
            s.left=value(left,0,180,0);s.right=value(right,0,180,0);s.top=value(top,0,180,0);s.bottom=value(bottom,0,180,0)
            s.radius=value(radius,0.6,3.5,1.35);s.rise=value(rise,0.4,1.6,1);s.buffer=value(buffer,0.08,0.4,0.24)
            return s
        }
        func area(in base:CGRect)->CGRect {
            let s=sanitized(),l=min(s.left,base.width*0.3),r=min(s.right,base.width*0.3),t=min(s.top,base.height*0.3),b=min(s.bottom,base.height*0.3)
            return CGRect(x:base.minX+l,y:base.minY+b,width:base.width-l-r,height:base.height-t-b)
        }
    }
    static func height(at p:CGPoint,scale:Double,area:CGRect,settings:Settings=Settings())->Double {
        guard scale>0,area.width>0,area.height>0 else {return 0}
        let s=settings.sanitized(),radius=s.radius*scale
        let distance=min(p.x-area.minX,area.maxX-p.x,p.y-area.minY,area.maxY-p.y)
        let run=min(radius*0.995,max(0,radius-distance))
        return (radius-sqrt(max(0,radius*radius-run*run)))/scale*s.rise
    }
    struct Pose {
        var pitch=0.0,roll=0.0,height=0.0
        var contact:Bool {height>0.0001}
    }
    /// The box boundary contains the full tires, not just their axle/contact centers.
    /// Include a conservative allowance for the seven-degree camera and raised chassis.
    static func clearance(heading:Double,scale:Double,settings:Settings=Settings())->CGSize {
        let tuning=settings.sanitized()
        // Steeper contact planes need extra projected room for the outer tire.
        let bankRoom=max(0,tuning.rise-1)*tuning.radius*0.3
        let shapeRoom=max(0,tuning.radius-0.6)*0.22
        let c=abs(cos(heading)),s=abs(sin(heading)),parallax=max(tuning.buffer,bankRoom,shapeRoom)
        return CGSize(width:(c*0.84+s*0.78+parallax)*scale+3,
                      height:(s*0.84+c*0.78+parallax)*scale+3)
    }
    static func confinedCenter(_ center:CGPoint,heading:Double,scale:Double,area:CGRect,settings:Settings=Settings())->CGPoint {
        guard scale>0,area.width>0,area.height>0 else {return center}
        let extent=clearance(heading:heading,scale:scale,settings:settings)
        let x=min(extent.width,area.width/2),y=min(extent.height,area.height/2)
        return CGPoint(x:min(area.maxX-x,max(area.minX+x,center.x)),y:min(area.maxY-y,max(area.minY+y,center.y)))
    }
    static func pose(center:CGPoint,heading:Double,scale:Double,area:CGRect,settings:Settings=Settings()) -> Pose {
        guard scale>0,area.width>0,area.height>0 else {return Pose()}
        let c=cos(heading),s=sin(heading)
        func tire(_ x:Double,_ z:Double)->Double {
            height(at:CGPoint(x:center.x+(c*x+s*z)*scale,y:center.y+(-s*x+c*z)*scale),scale:scale,area:area,settings:settings)
        }
        let fl=tire(-0.74,0.431),fr=tire(0.74,0.431)
        let rl=tire(-0.74,-0.431),rr=tire(0.74,-0.431)
        // Least-squares contact plane: an oblique approach banks and pitches.
        let pitch=atan(((fl+fr)-(rl+rr))/(4*0.431))
        let roll=atan(((fr+rr)-(fl+rl))/(4*0.74))
        return Pose(pitch:pitch,roll:roll,height:(fl+fr+rl+rr)/4)
    }
}
