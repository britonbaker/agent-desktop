import Foundation

/// Display-plane perspective. One Scout unit is 11 mm, including the wheels.
struct ScoutCamera {
    var millimetersPerPoint: Double
    var screenSize: CGSize
    var roverCenter: CGPoint
    var viewingDistance: Double = 550
    var modelUnitMillimeters: Double = 11
    var hingeDelta: Double = 0

    var pointsPerUnit: Double { modelUnitMillimeters / millimetersPerPoint }
    var eye: SIMD3<Float> {
        // Keep a top-down survey view. Position and hinge add at most 7 degrees
        // of parallax, rather than turning the view into a portrait camera.
        let normalDistance=viewingDistance/modelUnitMillimeters
        let x=(screenSize.width/2-roverCenter.x)/pointsPerUnit*0.20
        let z=(screenSize.height/2-roverCenter.y)/pointsPerUnit*0.20
              - sin(hingeDelta)*normalDistance*0.12
        let radius=hypot(x,z), limit=normalDistance*tan(7*Double.pi/180)
        let gain=radius>limit ? limit/radius : 1
        return SIMD3(Float(x*gain),Float(normalDistance-0.767),Float(z*gain))
    }
}
