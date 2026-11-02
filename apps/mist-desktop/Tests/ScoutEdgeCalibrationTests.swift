import Foundation
import CoreGraphics
@main struct ScoutEdgeCalibrationTests {
 static func main() throws {
  let area=CGRect(x:0,y:0,width:1728,height:1080),scale=55.0
  for right in [false,true] {
   var first:CGPoint?,last:CGPoint?,minX=Double.infinity,maxX = -Double.infinity,minY=Double.infinity,maxY = -Double.infinity
   for frame in 0...Int(ScoutEdgeCalibration.period*120) {
    let p=ScoutEdgeCalibration.pose(time:Double(frame)/120,right:right,area:area,scale:scale)
    if first==nil {first=p.center}
    minX=min(minX,p.center.x);maxX=max(maxX,p.center.x);minY=min(minY,p.center.y);maxY=max(maxY,p.center.y)
    let room=ScoutWall.clearance(heading:p.heading,scale:scale)
    precondition(p.center.x-room.width>=area.minX-0.001 && p.center.x+room.width<=area.maxX+0.001)
    if let last {precondition(hypot(p.center.x-last.x,p.center.y-last.y)<4,"Continuous loop, no phase jumps")}
    last=p.center
   }
   precondition(hypot(first!.x-last!.x,first!.y-last!.y)<0.001,"Seamless repeating cycle")
   precondition(maxX-minX>280 && maxY-minY>280,"Repeated approach/reverse and along-edge travel")
  }
  let old=Data("{\"left\":12,\"radius\":0.9,\"rise\":1.3,\"fullDisplay\":true}".utf8)
  let settings=try JSONDecoder().decode(ScoutWall.Settings.self,from:old)
  precondition(settings.left==12 && settings.radius==0.9 && settings.rise==1.3 && settings.fullDisplay && settings.buffer==0.24,"Preserve existing calibration when adding wheel room")
  let base=ScoutWall.clearance(heading:.pi/2,scale:55),closer=ScoutWall.clearance(heading:.pi/2,scale:55,settings:ScoutWall.Settings(buffer:0))
  precondition(base.width-closer.width>3,"Extra wheel room can bring the tires closer without moving the physical bezel")
  print("PASS continuous left/right loops, smooth reversal, along-edge motion, confinement and calibration migration")
 }
}
