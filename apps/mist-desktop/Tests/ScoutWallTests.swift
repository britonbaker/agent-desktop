import Foundation
import CoreGraphics
@main struct ScoutWallTests {
    static func main() {
        let area=CGRect(x:0,y:0,width:1512,height:982)
        let flat=ScoutWall.pose(center:CGPoint(x:500,y:500),heading:0.3,scale:55,area:area)
        precondition(!flat.contact && flat.pitch==0 && flat.roll==0)
        let left=ScoutWall.pose(center:CGPoint(x:40,y:400),heading:0,scale:55,area:area)
        let right=ScoutWall.pose(center:CGPoint(x:1472,y:400),heading:0,scale:55,area:area)
        precondition(left.roll<0 && right.roll>0 && abs(left.roll+right.roll)<0.0001)
        precondition(abs(left.pitch)<0.0001 && left.height>0)
        let angled=ScoutWall.pose(center:CGPoint(x:42,y:400),heading:-0.6,scale:55,area:area)
        precondition(angled.pitch>0 && angled.roll<0,"one leading wheel must pitch and bank the body")
        let corner=ScoutWall.pose(center:CGPoint(x:42,y:940),heading:-0.4,scale:55,area:area)
        precondition(corner.contact && corner.roll<0 && corner.pitch>0)
        let shifted=ScoutWall.pose(center:CGPoint(x:-1878,y:400),heading:-0.6,scale:55,area:CGRect(x:-1920,y:0,width:1512,height:982))
        precondition(abs(angled.pitch-shifted.pitch)<0.0001 && abs(angled.roll-shifted.roll)<0.0001)
        var previous=ScoutWall.Pose()
        for step in stride(from:100,through:25,by:-1) {
            let pose=ScoutWall.pose(center:CGPoint(x:Double(step),y:400),heading:-0.6,scale:55,area:area)
            precondition(pose.height.isFinite && abs(pose.pitch)<0.8 && abs(pose.roll)<0.8)
            precondition(abs(pose.pitch-previous.pitch)<0.08 && abs(pose.roll-previous.roll)<0.08,"continuous ramp, no edge snap")
            previous=pose
        }
        for heading in stride(from:0.0,to:2*Double.pi,by:Double.pi/12) {
            for point in [CGPoint(x:-30,y:400),CGPoint(x:1550,y:400),CGPoint(x:-20,y:1000)] {
                let safe=ScoutWall.confinedCenter(point,heading:heading,scale:55,area:area)
                let bounds=ScoutWall.clearance(heading:heading,scale:55)
                precondition(safe.x-bounds.width>=area.minX-0.001 && safe.x+bounds.width<=area.maxX+0.001)
                precondition(safe.y-bounds.height>=area.minY-0.001 && safe.y+bounds.height<=area.maxY+0.001)
                precondition(ScoutWall.pose(center:safe,heading:heading,scale:55,area:area).contact)
            }
        }
        print("PASS curved wall: tire envelope stays in bounds at 24 headings; flat floor, mirrored side bank, angled single-wheel entry, corners, offset display and continuous approach")
    }
}
