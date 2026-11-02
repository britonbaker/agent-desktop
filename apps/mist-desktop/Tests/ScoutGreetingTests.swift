import Foundation
import CoreGraphics
@main struct ScoutGreetingTests {
    static func main() {
        let area=CGRect(x:0,y:0,width:1512,height:982)
        for (origin,expected) in [(CGPoint(x:200,y:220),-1.0),(CGPoint(x:1100,y:220),1.0)] {
            let destination=ScoutGreeting.destination(from:origin,in:area,pointsPerUnit:55)
            let motion=ScoutGreeting(origin:origin,destination:destination,initialHeading:-3)
            let contact=0.3+motion.approach
            let start=motion.pose(at:0),peak=motion.pose(at:contact+0.7),end=motion.pose(at:motion.duration)
            precondition(start.position==origin && start.pitch==0)
            precondition(abs(end.pitch)<0.0001 && abs(end.position.x-(destination.x-expected*16))<0.001)
            precondition(peak.pitch>0.6 && peak.pitch<0.65)
            precondition(abs(sin(peak.heading)-expected)<0.001)
            let before=motion.pose(at:contact-0.01)
            precondition(before.pitch==0)
            let safe=ScoutWall.confinedCenter(CGPoint(x:peak.position.x+150,y:peak.position.y+200),heading:peak.heading,scale:55,area:area)
            let extent=ScoutWall.clearance(heading:peak.heading,scale:55)
            precondition(safe.x-extent.width>=area.minX-0.001 && safe.x+extent.width<=area.maxX+0.001)
            precondition(ScoutWall.pose(center:safe,heading:peak.heading,scale:55,area:area).contact,"Safe tire boundary must still reach the curved ramp")
            for frame in 0...Int(motion.duration*60) {
                let pose=motion.pose(at:Double(frame)/60)
                precondition(pose.position.y==origin.y && pose.position.x.isFinite)
                precondition(pose.position.x+150>20 && pose.position.x+150<area.maxX-20)
            }
        }
        let offset=CGRect(x:-1920,y:0,width:1920,height:1080)
        precondition(ScoutGreeting.destination(from:CGPoint(x:-1700,y:200),in:offset,pointsPerUnit:55).x < -1700)
        let edge=ScoutGreeting.destination(from:CGPoint(x:100,y:200),in:area,pointsPerUnit:55)
        let repeatSummon=ScoutGreeting(origin:CGPoint(x:edge.x-8,y:200),destination:edge,initialHeading:0,edgeHeading:-Double.pi/2)
        precondition(repeatSummon.heading == -Double.pi/2,"already-at-left-edge must still face left")
        let held=repeatSummon.pose(at:30,holdAtEdge:true)
        precondition(held.pitch>0.6 && abs(held.heading+Double.pi/2)<0.001,"hold climb through the voice response")
        let lowered=repeatSummon.pose(at:30,holdAtEdge:false)
        precondition(lowered.pitch==0)
        print("PASS edge greeting: nearest side, lift only after arrival, bezel contact, controlled backdown and offset display")
    }
}
