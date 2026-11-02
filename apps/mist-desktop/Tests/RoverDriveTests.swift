import Foundation
import CoreGraphics
@main struct RoverDriveTests {
    static func main() {
        var drive = RoverDrive(position:CGPoint(x:0,y:0),target:CGPoint(x:100,y:0))
        var maximum = 0.0
        for _ in 0..<1800 { _ = drive.step(1/60); maximum = max(maximum,drive.speed) }
        precondition(hypot(drive.position.x-100,drive.position.y)<2)
        precondition(drive.target == nil && drive.speed == 0 && maximum <= RoverDrive.cruiseSpeed)
        precondition(drive.distance >= 99)
        let stopped = drive.position; drive.park()
        for _ in 0..<60 { _ = drive.step(1/60) }
        precondition(drive.position == stopped)
        var corner = RoverDrive(position:CGPoint(x:0,y:0),target:CGPoint(x:-100,y:0),heading:Double.pi/2)
        _ = corner.step(1/60)
        precondition(corner.speed < 0.01)
        precondition(abs(corner.heading-Double.pi/2)<=3.8/60+0.001)
        var delayed = RoverDrive(position:CGPoint(x:0,y:0),target:CGPoint(x:0,y:100))
        _ = delayed.step(1)
        precondition(delayed.speed <= RoverDrive.cruiseAcceleration*0.05+0.001)
        var idle = RoverDrive(position:.zero,target:CGPoint(x:100,y:0))
        idle.maximumSpeed=24;idle.acceleration=45;idle.braking=70;idle.jerk=180
        var idlePeak=0.0
        for _ in 0..<1800 {_ = idle.step(1/60);idlePeak=max(idlePeak,idle.speed)}
        precondition(idlePeak<=24 && idle.target==nil && abs(idle.position.x-100)<2)
        var fast=RoverDrive(position:.zero,target:CGPoint(x:0,y:800)),elapsed=0.0,previousAcceleration=0.0,arrivalSpeed=0.0
        for _ in 0..<1800 {
            arrivalSpeed=fast.speed
            let active=fast.step(1/60);elapsed+=1/60
            if !active {break}
            precondition(abs(fast.currentAcceleration-previousAcceleration)<=fast.jerk/60+0.001,"Motor torque must ramp continuously")
            previousAcceleration=fast.currentAcceleration
        }
        precondition(elapsed<4.5 && fast.target==nil && arrivalSpeed<20,"Faster long drive must still brake gently before arrival")
        var launch=RoverDrive(position:.zero,target:CGPoint(x:0,y:800))
        _=launch.step(1/60);let first=launch.currentAcceleration
        _=launch.step(1/60)
        precondition(first>0 && launch.currentAcceleration>first && launch.currentAcceleration<launch.acceleration,"Acceleration builds instead of jumping immediately to full torque")
        var retarget=RoverDrive(position:.zero,target:CGPoint(x:0,y:1600))
        for _ in 0..<60 {_=retarget.step(1/60)}
        retarget.target=CGPoint(x:0,y:-300)
        for _ in 0..<900 {_=retarget.step(1/60)}
        precondition(retarget.target==nil && hypot(retarget.position.x,retarget.position.y+300)<2,"A moving drag target can reverse direction and still arrive")
        launch.park();precondition(launch.currentAcceleration==0)
        var at30=RoverDrive(position:.zero,target:CGPoint(x:0,y:800)),at120=at30
        for _ in 0..<60 {_=at30.step(1/30)}
        for _ in 0..<240 {_=at120.step(1/120)}
        precondition(hypot(at30.position.x-at120.position.x,at30.position.y-at120.position.y)<1,"Consistent curve across frame rates")
        print("PASS: jerk-limited launch, faster cruise, anticipatory braking, frame-rate consistency; rover arrival, braking, speed cap, distance, parking, turn limit and stalled-frame bound")
    }
}
