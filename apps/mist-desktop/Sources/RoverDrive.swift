import Foundation

struct RoverDrive {
    static let cruiseSpeed=320.0,cruiseAcceleration=720.0,cruiseBraking=1000.0,cruiseJerk=5500.0
    var position: CGPoint
    var target: CGPoint?
    var heading = 0.0
    var speed = 0.0
    var distance = 0.0
    var maximumSpeed = cruiseSpeed
    var acceleration = cruiseAcceleration
    var braking = cruiseBraking
    var jerk = cruiseJerk
    private(set) var currentAcceleration=0.0
    mutating func park() {target=nil;speed=0;currentAcceleration=0}
    /// Reserve distance to reverse positive torque, apply braking and absorb controller response.
    private func stoppingDistance(speed:Double)->Double {
        let j=max(1,jerk),b=max(1,braking),a=max(0,currentAcceleration)
        let ramp=max(0,(a+b)/j),stop=(a+sqrt(max(0,a*a+2*j*speed)))/j
        let t=min(ramp,stop)
        let traveled=max(0,speed*t+a*t*t/2-j*t*t*t/6)
        let remaining=max(0,speed+a*t-j*t*t/2)
        return traveled+(stop>ramp ? remaining*remaining/(2*b) : 0)+speed*0.4
    }
    mutating func step(_ elapsed: Double) -> Bool {
        guard let destination=target else {return false}
        let duration=min(0.05,max(0,elapsed)),steps=max(1,Int(ceil(duration*120))),dt=duration/Double(steps)
        for _ in 0..<steps {
            let dx=destination.x-position.x,dy=destination.y-position.y,remaining=hypot(dx,dy)
            if remaining<2 {position=destination;park();return false}
            var turn=atan2(dx,dy)-heading
            while turn > .pi {turn-=2 * .pi}
            while turn < -.pi {turn+=2 * .pi}
            heading+=min(3.8*dt,max(-3.8*dt,turn))
            // Solve a braking envelope including the time to reverse motor torque.
            var low=0.0,high=maximumSpeed
            for _ in 0..<12 {
                let middle=(low+high)/2
                if stoppingDistance(speed:middle)<max(0,remaining-1) {low=middle} else {high=middle}
            }
            let wanted=min(maximumSpeed,low)*max(0,cos(turn))
            let torque=min(acceleration,max(-braking,(wanted-speed)*6))
            currentAcceleration+=min(jerk*dt,max(-jerk*dt,torque-currentAcceleration))
            speed=min(maximumSpeed,max(0,speed+currentAcceleration*dt))
            let travel=min(remaining,speed*dt)
            position.x+=sin(heading)*travel;position.y+=cos(heading)*travel;distance+=travel
        }
        return true
    }
}
