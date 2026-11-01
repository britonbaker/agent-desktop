import Foundation
@main struct RobotVoiceEffectTests {
    static func main() {
        let input:[Float]=(0..<24000).map {index in
            let t=Double(index)/24000
            let fundamental=0.4*sin(t*2*Double.pi*440)
            let consonant=0.12*sin(t*2*Double.pi*2600)
            return Float(fundamental+consonant)
        }
        var all=RobotVoiceEffect(),streamed=RobotVoiceEffect()
        let expected=all.process(input)
        var actual:[Float]=[]
        for offset in stride(from:0,to:input.count,by:197) {actual += streamed.process(Array(input[offset..<min(offset+197,input.count)]))}
        precondition(expected==actual,"chunk boundaries must not reset the texture or create clicks")
        precondition(actual.allSatisfy(\.isFinite) && actual.map {abs($0)}.max()!<0.98)
        var dot:Float=0,energyIn:Float=0,energyOut:Float=0
        for i in input.indices {dot+=input[i]*actual[i];energyIn+=input[i]*input[i];energyOut+=actual[i]*actual[i]}
        let correlation=dot/sqrt(energyIn*energyOut)
        precondition(correlation>0.98,"keep speech predominantly unaltered")
        var reset=RobotVoiceEffect();precondition(reset.process(input)==expected,"new reply starts with fresh state")
        var invalid=RobotVoiceEffect();precondition(invalid.process([.nan,.infinity,-.infinity]).allSatisfy(\.isFinite))
        print("PASS robot speech texture: continuous chunks, headroom, preserved signal, fresh replies and invalid-input handling")
    }
}
