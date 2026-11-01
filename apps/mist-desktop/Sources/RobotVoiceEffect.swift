import Foundation

/// A small shared speaker texture for words and nonverbal gestures.
/// Sample-based state survives stream chunk boundaries; no lookahead or model.
struct RobotVoiceEffect {
    private var delay=[Float](repeating:0,count:137)
    private var cursor=0
    private var previous:Float=0,high:Float=0,low:Float=0
    private var phase=0.0
    mutating func process(_ samples:[Float]) -> [Float] {
        samples.map {raw in
            let input=raw.isFinite ? raw : 0
            high=0.978*(high+input-previous);previous=input
            low += 0.81*(high-low)
            let echo=delay[cursor]
            delay[cursor]=low+echo*0.18;cursor=(cursor+1)%delay.count
            let flutter=Float(0.985+0.015*sin(phase))
            phase += 2 * .pi*21/24000
            if phase>2 * .pi {phase -= 2 * .pi}
            // Mostly dry consonants, with a quiet resonant machine layer.
            let output=(0.78*input+0.22*(0.60*low+0.40*echo))*flutter
            return max(-0.98,min(0.98,output))
        }
    }
}
