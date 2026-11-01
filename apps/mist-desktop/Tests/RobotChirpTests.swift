import Foundation
@main struct RobotChirpTests {
    static func main() {
        var previous:[Float]=[]
        for variant in 0..<3 {
            let samples=RobotChirp.samples(variant:variant)
            precondition(samples.count==10320 && samples.allSatisfy(\.isFinite))
            let peak=samples.map {abs($0)}.max() ?? 0
            precondition(peak>0.08 && peak<0.3,"audible but not clipped")
            precondition(abs(samples.first ?? 1)<0.001 && abs(samples.last ?? 1)<0.01,"soft start and finish")
            if !previous.isEmpty {precondition(zip(previous,samples).filter {abs($0-$1)>0.01}.count>1000,"distinct gestures")}
            let wav=RobotChirp.wav(variant:variant)
            precondition(String(data:wav.prefix(4),encoding:.utf8)=="RIFF" && wav.count==44+samples.count*2)
            previous=samples
        }
        print("PASS robot gestures: duration, finite samples, headroom, fades, variation and PCM WAV export")
    }
}
