import Foundation
import CoreGraphics

/// Visible native windows become shallow layers, ordered front to back.
/// Bounds are desktop points and heights are model units; one lip is half the authored .59 tire diameter.
struct ScoutWindowSteps {
    struct Surface {let bounds:CGRect;let height:Double}
    struct Pose {var pitch=0.0,roll=0.0,height=0.0}
    static let lip=0.295
    static let ramp=0.35
    var surfaces:[Surface]=[]
    init(frontToBack:[CGRect]=[]) {
        for rect in frontToBack.prefix(8).reversed() {
            let under=surfaces.filter {$0.bounds.intersects(rect)}.map(\.height).max()
            surfaces.append(Surface(bounds:rect,height:under.map {$0+Self.lip} ?? 0))
        }
    }
    func height(at point:CGPoint,scale:Double)->Double {
        guard scale>0 else {return 0}
        var result=0.0
        for surface in surfaces {
            let r=surface.bounds
            let radius=min(12.0,min(r.width,r.height)/2)
            let qx=abs(point.x-r.midX)-r.width/2+radius,qy=abs(point.y-r.midY)-r.height/2+radius
            let inside=radius-hypot(max(qx,0),max(qy,0))-min(max(qx,qy),0)
            let t=min(1,max(0,inside/(scale*Self.ramp)+0.5))
            let blend=t*t*(3-2*t)
            result=result*(1-blend)+surface.height*blend
        }
        return result
    }
    func pose(center:CGPoint,heading:Double,scale:Double)->Pose {
        guard scale>0 else {return Pose()}
        let c=cos(heading),s=sin(heading)
        func tire(_ x:Double,_ z:Double)->Double {height(at:CGPoint(x:center.x+(c*x+s*z)*scale,y:center.y+(-s*x+c*z)*scale),scale:scale)}
        let fl=tire(-0.74,0.431),fr=tire(0.74,0.431),rl=tire(-0.74,-0.431),rr=tire(0.74,-0.431)
        return Pose(pitch:atan(((fl+fr)-(rl+rr))/(4*0.431)),roll:atan(((fr+rr)-(fl+rl))/(4*0.74)),height:(fl+fr+rl+rr)/4)
    }
    func rearAxleHeight(center:CGPoint,heading:Double,scale:Double)->Double {
        let c=cos(heading),s=sin(heading)
        return [-0.74,0.74].map {x in height(at:CGPoint(x:center.x+(c*x-s*0.431)*scale,y:center.y+(-s*x-c*0.431)*scale),scale:scale)}.reduce(0,+)/2
    }
    func uniforms(center:CGPoint,scale:Double)->[Float] {
        var result=[Float](repeating:0,count:44)
        guard scale>0 else {return result}
        for (i,surface) in surfaces.prefix(8).enumerated() {
            let r=surface.bounds
            result[i*4]=Float((r.minX-center.x)/scale);result[i*4+1]=Float((r.minY-center.y)/scale)
            result[i*4+2]=Float((r.maxX-center.x)/scale);result[i*4+3]=Float((r.maxY-center.y)/scale)
            result[32+i]=Float(surface.height)
        }
        result[40]=Float(min(8,surfaces.count));result[41]=Float(Self.ramp);result[42]=Float(12/scale)
        return result
    }
}
