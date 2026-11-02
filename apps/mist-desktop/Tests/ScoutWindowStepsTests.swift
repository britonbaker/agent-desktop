import Foundation
import CoreGraphics
@main struct ScoutWindowStepsTests {
 static func main() {
  let base=CGRect(x:0,y:0,width:1000,height:800),top=CGRect(x:300,y:200,width:400,height:400)
  let scene=ScoutWindowSteps(frontToBack:[top,base]),scale=55.0
  precondition(scene.height(at:CGPoint(x:200,y:400),scale:scale)==0)
  precondition(abs(scene.height(at:CGPoint(x:500,y:400),scale:scale)-ScoutWindowSteps.lip)<0.00001)
  let approach=scene.pose(center:CGPoint(x:295,y:400),heading:.pi/2,scale:scale)
  precondition(approach.pitch>0.05 && abs(approach.roll)<0.001,"Front tires climb before the rear tires")
  precondition(scene.rearAxleHeight(center:CGPoint(x:295,y:400),heading:.pi/2,scale:scale)==0,"Face-up balance stays supported by the rear axle below the lip")
  let raised=scene.pose(center:CGPoint(x:400,y:400),heading:.pi/2,scale:scale)
  precondition(abs(raised.pitch)<0.001 && abs(raised.height-ScoutWindowSteps.lip)<0.001,"Settle flat on the raised window")
  let down=scene.pose(center:CGPoint(x:705,y:400),heading:.pi/2,scale:scale)
  precondition(down.pitch < -0.05,"Front tires descend before the rear tires")
  let corner=scene.pose(center:CGPoint(x:295,y:205),heading:0.4,scale:scale)
  precondition(abs(corner.roll)>0.01,"A diagonal tire contact banks the chassis")
  let disjoint=ScoutWindowSteps(frontToBack:[top,CGRect(x:800,y:0,width:200,height:100)])
  precondition(disjoint.surfaces.allSatisfy {$0.height==0},"No step between unrelated nonoverlapping windows")
  var previous=scene.pose(center:CGPoint(x:250,y:400),heading:.pi/2,scale:scale)
  for x in stride(from:250.0,through:750,by:0.5) {
   let p=scene.pose(center:CGPoint(x:x,y:400),heading:.pi/2,scale:scale)
   precondition(abs(p.pitch-previous.pitch)<0.02 && abs(p.height-previous.height)<0.01,"Smooth contact, no snapping")
   previous=p
  }
  let uniforms=scene.uniforms(center:CGPoint(x:300,y:400),scale:scale)
  precondition(uniforms.count==44 && uniforms[40]==2 && abs(Double(uniforms[33])-ScoutWindowSteps.lip)<0.001)
  print("PASS window steps: overlap layers, half-wheel-height lip, ordered tire ascent/descent, diagonal bank, smooth edges and packed terrain")
 }
}
