import Foundation
import CoreGraphics

/// The union of connected display rectangles. Shared edge spans are doors, not walls.
struct ScoutDesktopArena {
    struct Region:Equatable {var id:UInt32;var frame:CGRect;var area:CGRect;var settings=ScoutWall.Settings()}
    struct Wall {var a:CGPoint;var b:CGPoint;var inward:CGPoint;var settings:ScoutWall.Settings
        var vertical:Bool {abs(a.x-b.x)<0.5}
        func distance(to p:CGPoint)->Double {
            let dx=b.x-a.x,dy=b.y-a.y,length=dx*dx+dy*dy
            let t=length>0 ? min(1,max(0,((p.x-a.x)*dx+(p.y-a.y)*dy)/length)) : 0
            return hypot(p.x-a.x-t*dx,p.y-a.y-t*dy)
        }
    }
    struct Portal {var from:Int;var to:Int;var center:CGPoint;var direction:CGPoint;var span:Double}
    let regions:[Region]
    let walls:[Wall]
    init(regions input:[Region]) {
        // Mirror displays describe the same floor only once.
        var unique:[Region]=[]
        for r in input where !r.frame.isEmpty {if !unique.contains(where:{$0.frame==r.frame}) {unique.append(r)}}
        var floor=unique
        for i in floor.indices {for j in floor.indices where i != j {
            let a=floor[i].frame,b=floor[j].frame
            if min(a.maxY,b.maxY)-max(a.minY,b.minY)>1 {
                if abs(a.minX-b.maxX)<0.5 {let end=floor[i].area.maxX;floor[i].area.origin.x=a.minX;floor[i].area.size.width=end-a.minX}
                if abs(a.maxX-b.minX)<0.5 {floor[i].area.size.width=a.maxX-floor[i].area.minX}
            }
            if min(a.maxX,b.maxX)-max(a.minX,b.minX)>1 {
                if abs(a.minY-b.maxY)<0.5 {let end=floor[i].area.maxY;floor[i].area.origin.y=a.minY;floor[i].area.size.height=end-a.minY}
                if abs(a.maxY-b.minY)<0.5 {floor[i].area.size.height=a.maxY-floor[i].area.minY}
            }
        }}
        regions=floor
        var boundary:[Wall]=[]
        for (i,region) in floor.enumerated() {
            let r=region.area
            for side in 0..<4 {
                let vertical=side<2,coordinate=side==0 ? r.minX : side==1 ? r.maxX : side==2 ? r.minY : r.maxY
                let lo=vertical ? r.minY : r.minX,hi=vertical ? r.maxY : r.maxX
                var spans=[(lo,hi)]
                for (j,other) in floor.enumerated() where i != j {
                    let b=other.area
                    let covered=side==0 ? b.minX<coordinate && b.maxX>=coordinate-0.5 : side==1 ? b.maxX>coordinate && b.minX<=coordinate+0.5 : side==2 ? b.minY<coordinate && b.maxY>=coordinate-0.5 : b.maxY>coordinate && b.minY<=coordinate+0.5
                    guard covered else {continue}
                    let lower=vertical ? b.minY : b.minX,upper=vertical ? b.maxY : b.maxX
                    spans=spans.flatMap {s -> [(CGFloat,CGFloat)] in
                        guard lower<s.1 && upper>s.0 else {return [s]}
                        var pieces:[(CGFloat,CGFloat)]=[]
                        if lower>s.0 {pieces.append((s.0,min(s.1,lower)))}
                        if upper<s.1 {pieces.append((max(s.0,upper),s.1))};return pieces
                    }
                }
                let inward=side==0 ? CGPoint(x:1,y:0) : side==1 ? CGPoint(x:-1,y:0) : side==2 ? CGPoint(x:0,y:1) : CGPoint(x:0,y:-1)
                for (start,end) in spans where end-start>0.5 {
                    boundary.append(Wall(a:vertical ? CGPoint(x:coordinate,y:start) : CGPoint(x:start,y:coordinate),b:vertical ? CGPoint(x:coordinate,y:end) : CGPoint(x:end,y:coordinate),inward:inward,settings:region.settings))
                }
            }
        }
        walls=boundary
    }
    var bounds:CGRect {regions.reduce(CGRect.null) {$0.union($1.area)}}
    func region(at p:CGPoint)->Int? {regions.firstIndex {$0.area.insetBy(dx:-0.001,dy:-0.001).contains(p)}}
    func contains(_ p:CGPoint,extent:CGSize)->Bool {
        guard region(at:p) != nil else {return false}
        let box=CGRect(x:p.x-extent.width,y:p.y-extent.height,width:extent.width*2,height:extent.height*2)
        return !walls.contains {w in
            if w.vertical {return w.a.x>box.minX+0.001 && w.a.x<box.maxX-0.001 && min(w.b.y,box.maxY)-max(w.a.y,box.minY)>0.001}
            return w.a.y>box.minY+0.001 && w.a.y<box.maxY-0.001 && min(w.b.x,box.maxX)-max(w.a.x,box.minX)>0.001
        }
    }
    func clearance(heading:Double,scale:Double)->CGSize {
        regions.reduce(CGSize.zero) {size,r in
            let e=ScoutWall.clearance(heading:heading,scale:scale,settings:r.settings)
            return CGSize(width:max(size.width,e.width),height:max(size.height,e.height))
        }
    }
    func confinedCenter(_ p:CGPoint,heading:Double,scale:Double)->CGPoint {
        let extent=clearance(heading:heading,scale:scale)
        if contains(p,extent:extent) {return p}
        var xs=[p.x],ys=[p.y]
        for w in walls {
            if w.vertical {xs.append(w.a.x+w.inward.x*extent.width)}
            else {ys.append(w.a.y+w.inward.y*extent.height)}
        }
        var best:CGPoint?,distance=Double.infinity
        for x in xs {for y in ys {
            let d=(x-p.x)*(x-p.x)+(y-p.y)*(y-p.y)
            if d<distance,contains(CGPoint(x:x,y:y),extent:extent) {best=CGPoint(x:x,y:y);distance=d}
        }}
        return best ?? regions.first.map {CGPoint(x:$0.area.midX,y:$0.area.midY)} ?? p
    }
    func height(at p:CGPoint,scale:Double)->Double {
        guard scale>0,let wall=walls.min(by:{$0.distance(to:p)<$1.distance(to:p)}) else {return 0}
        let s=wall.settings.sanitized(),radius=s.radius*scale
        let distance=wall.distance(to:p)*(region(at:p)==nil ? -1 : 1)
        let run=min(radius*0.995,max(0,radius-distance))
        return (radius-sqrt(max(0,radius*radius-run*run)))/scale*s.rise
    }
    func pose(center:CGPoint,heading:Double,scale:Double)->ScoutWall.Pose {
        let c=cos(heading),s=sin(heading)
        func tire(_ x:Double,_ z:Double)->Double {height(at:CGPoint(x:center.x+(c*x+s*z)*scale,y:center.y+(-s*x+c*z)*scale),scale:scale)}
        let fl=tire(-0.74,0.431),fr=tire(0.74,0.431),rl=tire(-0.74,-0.431),rr=tire(0.74,-0.431)
        return ScoutWall.Pose(pitch:atan(((fl+fr)-(rl+rr))/(4*0.431)),roll:atan(((fr+rr)-(fl+rl))/(4*0.74)),height:(fl+fr+rl+rr)/4,rearHeight:(rl+rr)/2)
    }
    func portals(margin:Double)->[Portal] {
        var result:[Portal]=[]
        for i in regions.indices {for j in regions.indices where i<j {
            let a=regions[i].area,b=regions[j].area
            if abs(a.maxX-b.minX)<0.5 || abs(b.maxX-a.minX)<0.5 {
                let low=max(a.minY,b.minY),high=min(a.maxY,b.maxY)
                if high-low>2*margin+2 {result.append(Portal(from:i,to:j,center:CGPoint(x:abs(a.maxX-b.minX)<0.5 ? a.maxX : a.minX,y:(low+high)/2),direction:CGPoint(x:b.midX>a.midX ? 1 : -1,y:0),span:high-low))}
            }
            if abs(a.maxY-b.minY)<0.5 || abs(b.maxY-a.minY)<0.5 {
                let low=max(a.minX,b.minX),high=min(a.maxX,b.maxX)
                if high-low>2*margin+2 {result.append(Portal(from:i,to:j,center:CGPoint(x:(low+high)/2,y:abs(a.maxY-b.minY)<0.5 ? a.maxY : a.minY),direction:CGPoint(x:0,y:b.midY>a.midY ? 1 : -1),span:high-low))}
            }
        }}
        return result
    }
    /// Route through the middle of real shared spans, never through a missing desktop corner.
    func route(from start:CGPoint,to end:CGPoint,margin:Double)->[CGPoint] {
        guard let source=region(at:start),let target=region(at:end) else {return []}
        if source==target {return [end]}
        let doors=portals(margin:margin)
        var queue=[source],paths=[source:[CGPoint]()],cursor=0
        while cursor<queue.count {
            let current=queue[cursor];cursor+=1
            for door in doors where door.from==current || door.to==current {
                let next=door.from==current ? door.to : door.from
                guard paths[next]==nil else {continue}
                let sign=door.from==current ? 1.0 : -1.0,offset=margin+24
                let direction=CGPoint(x:door.direction.x*sign,y:door.direction.y*sign)
                let entry=CGPoint(x:door.center.x-direction.x*offset,y:door.center.y-direction.y*offset)
                let exit=CGPoint(x:door.center.x+direction.x*offset,y:door.center.y+direction.y*offset)
                let path=(paths[current] ?? [])+[entry,exit]
                if next==target {return path+[end]};paths[next]=path;queue.append(next)
            }
        }
        return []
    }
    func greetingDestination(from p:CGPoint,scale:Double)->(center:CGPoint,heading:Double)? {
        let extent=clearance(heading:.pi/2,scale:scale)
        return walls.filter {$0.vertical && p.y>=$0.a.y+extent.height && p.y<=$0.b.y-extent.height}.map {w in
            (CGPoint(x:w.a.x+w.inward.x*extent.width,y:p.y),w.inward.x>0 ? -Double.pi/2 : Double.pi/2)
        }.filter {candidate in
            guard contains(candidate.0,extent:extent) else {return false}
            let low=min(p.x,candidate.0.x),high=max(p.x,candidate.0.x)
            return !walls.contains {$0.vertical && $0.a.x>low+0.01 && $0.a.x<high-0.01 && p.y>$0.a.y && p.y<$0.b.y}
        }.min {abs($0.0.x-p.x)<abs($1.0.x-p.x)}.map {($0.0,$0.1)}
    }
}
