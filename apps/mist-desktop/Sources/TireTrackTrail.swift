import Foundation
import CoreGraphics

struct TireTrackMark {
    let position:CGPoint
    let heading:Double
    let scale:Double
    let rear:Bool
    let born:Double
    func opacity(at now:Double) -> Double {pow(max(0,1-max(0,now-born)/1.1),2)}
}

/// Tire contacts are stored in desktop coordinates, never relative to the moving panel.
struct TireTrackTrail {
    private(set) var marks:[TireTrackMark]=[]
    private var previous:(position:CGPoint,heading:Double)?
    private var residual=0.0
    mutating func clear() {marks.removeAll();previous=nil;residual=0}
    mutating func expire(at time:Double) {marks.removeAll {time-$0.born>=1.1}}
    mutating func update(position:CGPoint,heading:Double,scale:Double,time:Double,frontContact:Bool=true,grounded:Bool=true) {
        expire(at:time)
        defer {previous=(position,heading)}
        guard let old=previous else {return}
        let dx=position.x-old.position.x,dy=position.y-old.position.y,length=hypot(dx,dy)
        guard grounded,length>0.01,length<120 else {if length>=120 || !grounded {residual=0};return}
        var turn=heading-old.heading
        while turn > .pi {turn-=2 * .pi};while turn < -.pi {turn+=2 * .pi}
        var travel=2-residual
        while travel<=length {
            let fraction=travel/length,angle=old.heading+turn*fraction
            let center=CGPoint(x:old.position.x+dx*fraction,y:old.position.y+dy*fraction)
            for rear in [true,false] where rear || frontContact {
                for side in [-1.0,1.0] {
                    let across=side*0.654*scale,forward=(rear ? -0.431 : 0.431)*scale
                    let point=CGPoint(x:center.x+cos(angle)*across+sin(angle)*forward,y:center.y-sin(angle)*across+cos(angle)*forward)
                    marks.append(TireTrackMark(position:point,heading:angle,scale:scale,rear:rear,born:time))
                }
            }
            travel+=2
        }
        residual=(residual+length).truncatingRemainder(dividingBy:2)
        if marks.count>2000 {marks.removeFirst(marks.count-2000)}
    }
}
