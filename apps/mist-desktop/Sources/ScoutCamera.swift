import Foundation

/// Display-plane perspective. One Scout unit is 18 mm, including the wheels.
struct ScoutCamera {
    var millimetersPerPoint: Double
    var screenSize: CGSize
    var roverCenter: CGPoint
    var viewingDistance: Double = 550
    var modelUnitMillimeters: Double = 18
    var hingeDelta: Double = 0

    var pointsPerUnit: Double { modelUnitMillimeters / millimetersPerPoint }
    var eye: SIMD3<Float> {
        let halfHeight=screenSize.height*millimetersPerPoint/2
        let normalDistance=cos(hingeDelta)*viewingDistance+sin(hingeDelta)*halfHeight
        let verticalOffset = -sin(hingeDelta)*viewingDistance+(cos(hingeDelta)-1)*halfHeight
        return SIMD3(Float((screenSize.width/2-roverCenter.x)/pointsPerUnit),
                     Float(max(150,normalDistance)/modelUnitMillimeters-0.767),
                     Float((screenSize.height/2-roverCenter.y)/pointsPerUnit+verticalOffset/modelUnitMillimeters))
    }
}
