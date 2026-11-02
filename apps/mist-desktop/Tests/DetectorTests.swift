import Foundation
@main struct DetectorTests {
    static func main() {
        func count(peaks: [Double], keyboard: [Double] = [], sustained: Bool = false) -> Int {
            var detector = TapDetector(threshold: 0.006)
            var hits = 0
            for n in 0...350 {
                let time = Double(n) / 100
                let high = peaks.contains { abs($0 - time) < 0.005 } || (sustained && time >= 1 && time <= 1.5)
                let lastKey = keyboard.filter { $0 <= time }.last ?? -100
                if detector.update(time: time, strength: high ? 0.01 : 0.0002, keyboardAge: time - lastKey) { hits += 1 }
            }
            return hits
        }
        precondition(count(peaks: [1, 1.3]) == 1, "pair accepted once")
        precondition(count(peaks: [1]) == 0, "single rejected")
        precondition(count(peaks: [1, 1.3, 1.6]) == 0, "triple rejected")
        precondition(count(peaks: [1, 1.1]) == 0, "ringing rejected")
        precondition(count(peaks: [1, 1.8]) == 0, "slow pair rejected")
        precondition(count(peaks: [1, 1.3], keyboard: [0.9, 1.2]) == 0, "typing rejected")
        precondition(count(peaks: [1, 1.3], keyboard: [1.5]) == 0, "typing before decision cancels pair")
        precondition(count(peaks: [1.5, 1.8], keyboard: [0.5]) == 1, "pair after typing quiet period accepted")
        precondition(count(peaks: [], sustained: true) == 0, "sustained vibration rejected")
        precondition(count(peaks: []) == 0, "quiet baseline rejected")
        func gestures(_ peaks:[Double],keys:[Double]=[])->[TapGesture] {
            var detector=TapDetector(threshold:0.006),result:[TapGesture]=[]
            for n in 0...400 {
                let time=Double(n)/100,lastKey=keys.filter {$0<=time}.last ?? -100
                if let gesture=detector.updateGesture(time:time,strength:peaks.contains {abs($0-time)<0.005} ? 0.01 : 0.0002,keyboardAge:time-lastKey) {result.append(gesture)}
            }
            return result
        }
        precondition(gestures([1,1.3]) == [.double])
        precondition(gestures([1,1.3,1.6]) == [.triple],"Triple dismiss must never first activate a double")
        precondition(gestures([1,1.3,1.6,1.9]).isEmpty,"Extra impacts are not a gesture")
        precondition(gestures([1,1.3,1.6],keys:[1.8]).isEmpty,"Typing cancels a pending dismiss")
        precondition(gestures([1,1.1,1.2]).isEmpty,"Ringing is not a dismiss gesture")
        print("PASS double/triple taps: pair activation, exclusive triple dismissal, ringing, extra impacts and keyboard suppression")
    }
}
