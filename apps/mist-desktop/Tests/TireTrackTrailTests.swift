import Foundation
import CoreGraphics
@main struct TireTrackTrailTests {
    static func main() {
        var trail=TireTrackTrail()
        trail.update(position:CGPoint(x:100,y:100),heading:0,scale:50,time:0)
        precondition(trail.marks.isEmpty)
        trail.update(position:CGPoint(x:100,y:120),heading:0,scale:50,time:0.1)
        precondition(trail.marks.count==40)
        let first=trail.marks[0]
        trail.update(position:CGPoint(x:120,y:140),heading:.pi/2,scale:50,time:0.2)
        precondition(trail.marks[0].position==first.position && trail.marks[0].heading==first.heading,"laid marks must not translate or rotate with Scout")
        precondition(trail.marks.last!.heading>1)
        precondition(trail.marks.contains {$0.rear} && trail.marks.contains {!$0.rear})
        precondition(first.opacity(at:0.6)<0.3 && first.opacity(at:1.21)==0)
        let count=trail.marks.count
        trail.update(position:CGPoint(x:120,y:140),heading:.pi,scale:50,time:0.3)
        precondition(trail.marks.count==count,"in-place wheel spin creates no sliding trail")
        trail.update(position:CGPoint(x:900,y:900),heading:0,scale:50,time:0.4)
        precondition(trail.marks.count==count,"teleport must not draw a connecting trail")
        trail.expire(at:2);precondition(trail.marks.isEmpty)
        trail.clear();trail.update(position:.zero,heading:0,scale:50,time:3)
        trail.update(position:CGPoint(x:0,y:10),heading:0,scale:50,time:3.1,frontContact:false)
        precondition(trail.marks.count==10 && trail.marks.allSatisfy {$0.rear})
        trail.clear();trail.update(position:.zero,heading:0,scale:50,time:4)
        trail.update(position:CGPoint(x:0,y:10),heading:0,scale:50,time:4.1,grounded:false)
        precondition(trail.marks.isEmpty)
        print("PASS desktop tire contacts: fixed marks through turns, four wheel paths, independent fade, no spin/teleport/airborne trail, rear contact during climb")
    }
}
