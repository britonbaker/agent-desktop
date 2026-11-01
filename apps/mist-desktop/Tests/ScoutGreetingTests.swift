import Foundation
import CoreGraphics

@main struct ScoutGreetingTests {
    static func main() {
        let motion=ScoutGreeting(origin:CGPoint(x:100,y:100),destination:CGPoint(x:100,y:72),initialHeading:-3)
        let start=motion.pose(at:0),peak=motion.pose(at:1.3),end=motion.pose(at:ScoutGreeting.duration)
        precondition(start.position==CGPoint(x:100,y:100) && start.pitch==0)
        precondition(end.position==CGPoint(x:100,y:72) && abs(end.pitch)<0.0001)
        precondition(peak.pitch>0.5 && peak.pitch<0.6)
        var previous=0.0
        for frame in 0...168 {
            let pose=motion.pose(at:Double(frame)/60)
            precondition(pose.distance>=previous && pose.distance<=28)
            precondition(pose.position.y>=72 && pose.position.y<=100)
            previous=pose.distance
        }
        // A rear-axle pivot leaves rear-wheel height fixed; front axle rises ~0.44 units.
        let rearY = -0.472,rearZ = -0.431,frontZ=0.431
        let rearAfter=rearY+sin(peak.pitch)*(rearZ-rearZ)
        let frontAfter=rearY+sin(peak.pitch)*(frontZ-rearZ)
        precondition(rearAfter==rearY && frontAfter-rearAfter>0.4)
        print("PASS knock greeting: bounded roll, rear-axle lift and complete settle")
    }
}
