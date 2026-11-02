import Foundation
import CoreGraphics
@main struct ScoutSuspensionTests {
 static func main() {
  var load=ScoutSuspension(),position=CGPoint.zero
  load.step(position:position,heading:0,elapsed:1/60)
  for i in 1...30 {position.y+=Double(i)*0.15;load.step(position:position,heading:0,elapsed:1/60)}
  precondition(load.pitch < -0.005,"Acceleration loads the rear suspension")
  for _ in 0..<60 {load.step(position:position,heading:0,elapsed:1/60)}
  precondition(abs(load.pitch)<0.003 && abs(load.roll)<0.003,"Loads settle after stopping")
  var spin=ScoutSuspension(),peak=0.0
  spin.step(position:.zero,heading:0,elapsed:1/60)
  for i in 1...30 {spin.step(position:.zero,heading:Double(i)*0.04,elapsed:1/60);peak=max(peak,abs(spin.roll))}
  precondition(peak>0.002,"Motor torque rocks the chassis during an in-place turn")
  precondition(abs(spin.yawTravel-1.2)<0.00001,"Differential tread phase follows unwrapped yaw")
  for _ in 0..<240 {spin.step(position:.zero,heading:1.2,elapsed:1/60);precondition(abs(spin.pitch)<0.07 && abs(spin.roll)<0.07)}
  precondition(abs(spin.roll)<0.001,"Turn shock settles without endless wobble")
  spin.step(position:.zero,heading:2,elapsed:1/60,reducedMotion:true)
  precondition(spin.pitch==0 && spin.roll==0 && spin.heave==0)
  let desired=CGPoint(x:100.35,y:200.7),native=CGPoint(x:100,y:200)
  precondition(ScoutMotionOrigin.resolve(desired:desired,native:native)==desired,"Preserve diagonal subpixel motion")
  precondition(ScoutMotionOrigin.resolve(desired:desired,native:CGPoint(x:300,y:200))==CGPoint(x:300,y:200),"Handle a window relocated by the OS")
  print("PASS suspension loads, pivot-turn torque, bounded recovery, differential yaw, Reduced Motion and fractional pose")
 }
}
