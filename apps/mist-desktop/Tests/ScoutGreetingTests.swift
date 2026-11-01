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
            precondition(abs(end.pitch)<0.0001 && abs(end.position.x-(destination.x-expected*20))<0.001)
            precondition(peak.pitch>0.5 && peak.pitch<0.6)
            precondition(abs(sin(peak.heading)-expected)<0.001)
            let before=motion.pose(at:contact-0.01)
            precondition(before.pitch==0)
            let front=peak.position.x+150+expected*(0.726*55-(1-cos(peak.pitch))*0.862*55)
            precondition(abs(front-(expected<0 ? area.minX+2 : area.maxX-2))<0.001)
            for frame in 0...Int(motion.duration*60) {
                let pose=motion.pose(at:Double(frame)/60)
                precondition(pose.position.y==origin.y && pose.position.x.isFinite)
                precondition(pose.position.x+150>20 && pose.position.x+150<area.maxX-20)
            }
        }
        let offset=CGRect(x:-1920,y:0,width:1920,height:1080)
        precondition(ScoutGreeting.destination(from:CGPoint(x:-1700,y:200),in:offset,pointsPerUnit:55).x < -1700)
        print("PASS edge greeting: nearest side, arrival before lift, bezel contact, backdown, safe center and offset display")
    }
}
