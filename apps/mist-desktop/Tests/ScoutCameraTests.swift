import Foundation

@main struct ScoutCameraTests {
    static func main() {
        let c=ScoutCamera(millimetersPerPoint:0.25,screenSize:CGSize(width:1400,height:900),roverCenter:CGPoint(x:700,y:450))
        precondition(abs(c.pointsPerUnit-44)<0.001)
        precondition(c.eye.x==0 && c.eye.z==0)
        precondition(abs(Double(c.eye.y)+0.767-550/11.0)<0.0001)
        var corner=c;corner.roverCenter=CGPoint(x:100,y:100)
        precondition(corner.eye.x>0 && corner.eye.z>0)
        var farther=c;farther.viewingDistance=700
        precondition(farther.eye.y>c.eye.y)
        precondition(farther.pointsPerUnit==c.pointsPerUnit, "Physical size must not change with viewing distance")
        var tilted=c;tilted.hingeDelta=Double.pi/10
        precondition(tilted.eye.z<c.eye.z && tilted.eye.y>0, "Opening the lid must reveal the rear instead of rotating the rover")
        precondition(tilted.pointsPerUnit==c.pointsPerUnit)
        var extreme=c;extreme.roverCenter=CGPoint(x:-4000,y:5000);extreme.hingeDelta=Double.pi/2
        let angle=atan2(hypot(Double(extreme.eye.x),Double(extreme.eye.z)),Double(extreme.eye.y)+0.767)
        precondition(angle<=7*Double.pi/180+0.0001, "Perspective must stay close to top down")
        print("PASS physical display scale, centered and off-axis eyes, viewing distance")
    }
}
