import Foundation
import CoreGraphics
@main struct RoverDriveTests {
    static func main() {
        var drive = RoverDrive(position:CGPoint(x:0,y:0),target:CGPoint(x:100,y:0))
        var maximum = 0.0
        for _ in 0..<1800 { _ = drive.step(1/60); maximum = max(maximum,drive.speed) }
        precondition(hypot(drive.position.x-100,drive.position.y)<2)
        precondition(drive.target == nil && drive.speed == 0 && maximum <= 125)
        precondition(drive.distance >= 99)
        let stopped = drive.position; drive.park()
        for _ in 0..<60 { _ = drive.step(1/60) }
        precondition(drive.position == stopped)
        var corner = RoverDrive(position:CGPoint(x:0,y:0),target:CGPoint(x:-100,y:0),heading:Double.pi/2)
        _ = corner.step(1/60)
        precondition(corner.speed < 0.01)
        precondition(abs(corner.heading-Double.pi/2)<=2.8/60+0.001)
        var delayed = RoverDrive(position:CGPoint(x:0,y:0),target:CGPoint(x:0,y:100))
        _ = delayed.step(1)
        precondition(delayed.speed <= 230*0.05+0.001)
        var idle = RoverDrive(position:.zero,target:CGPoint(x:100,y:0))
        idle.maximumSpeed=24;idle.acceleration=45
        var idlePeak=0.0
        for _ in 0..<1800 {_ = idle.step(1/60);idlePeak=max(idlePeak,idle.speed)}
        precondition(idlePeak<=24 && idle.target==nil && abs(idle.position.x-100)<2)
        print("PASS: rover arrival, braking, speed cap, distance, parking, turn limit and stalled-frame bound")
    }
}
