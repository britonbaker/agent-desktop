import Foundation
@main struct ScoutBalanceTests {
    static func main() {
        var balance=ScoutBalance(),peak=0.0
        for _ in 0..<120 {balance.step(1/120,engaged:true);peak=max(peak,balance.presentation)}
        precondition(peak>1 && peak<1.05,"Rise has a small bounded settling overshoot")
        for _ in 0..<360 {balance.step(1/120,engaged:true)}
        let before=balance.pitchCorrection
        balance.tap()
        for _ in 0..<12 {balance.step(1/120,engaged:true)}
        precondition(balance.pitchCorrection>before+0.01,"Tap momentum visibly disturbs balance")
        precondition(abs(balance.travel)>0.001,"Rear wheels correct the angular disturbance")
        for _ in 0..<600 {balance.step(1/120,engaged:true);precondition(abs(balance.pitchCorrection)<0.08 && abs(balance.travel)<0.071)}
        for _ in 0..<240 {balance.step(1/120,engaged:false)}
        precondition(balance.presentation==0 && balance.travel==0,"Dismissal returns to rest")
        balance.tap();balance.step(1,engaged:true,reducedMotion:true)
        precondition(balance.presentation==1 && balance.pitchCorrection==0 && balance.travel==0,"Reduced Motion has no oscillation")
        var slow=ScoutBalance(),fast=ScoutBalance()
        for _ in 0..<60 {slow.step(1/30,engaged:true)}
        for _ in 0..<240 {fast.step(1/120,engaged:true)}
        precondition(abs(slow.presentation-fast.presentation)<0.001 && abs(slow.travel-fast.travel)<0.001,"Frame-rate independent controller")
        print("PASS balance: settling, tap impulse, wheel correction, bounded recovery, dismissal and Reduced Motion")
    }
}
