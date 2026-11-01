import Foundation

struct RoverDrive {
    var position: CGPoint
    var target: CGPoint?
    var heading = 0.0
    var speed = 0.0
    var distance = 0.0
    mutating func park() { target = nil; speed = 0 }
    mutating func step(_ elapsed: Double) -> Bool {
        guard let target else { return false }
        let dt = min(0.05, max(0, elapsed))
        let dx = target.x - position.x, dy = target.y - position.y
        let remaining = hypot(dx, dy)
        if remaining < 2 { position = target; self.target = nil; speed = 0; return false }
        let desired = atan2(dx, dy)
        var turn = desired - heading
        while turn > .pi { turn -= 2 * .pi }
        while turn < -.pi { turn += 2 * .pi }
        heading += min(2.8 * dt, max(-2.8 * dt, turn))
        let wanted = min(125, sqrt(2 * 230 * remaining)) * max(0, cos(turn))
        speed += min(230 * dt, max(-230 * dt, wanted - speed))
        let travel = min(remaining, speed * dt)
        position.x += sin(heading) * travel
        position.y += cos(heading) * travel
        distance += travel
        return true
    }
}
