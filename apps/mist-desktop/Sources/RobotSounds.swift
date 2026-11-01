import Foundation
import AVFoundation

/// Original short robot gestures. No recordings, model, network or runtime files.
enum RobotChirp {
    static let sampleRate=24000
    static func samples(variant:Int) -> [Float] {
        let kind=((variant%3)+3)%3,duration=0.43
        var phase=0.0,servoPhase=0.0
        let dry:[Float]=(0..<Int(duration*Double(sampleRate))).map {index in
            let t=Double(index)/Double(sampleRate),second=t>=0.19
            let local=second ? t-0.21 : t,length=second ? 0.22 : 0.17
            guard local>=0,local<length else {return 0}
            let u=local/length
            let shape=sin(.pi*u)
            let envelope=pow(max(0,shape),0.65)
            // Two vowel-like gestures with expressive glides, a little clock flutter
            // and a quiet motor undertone rather than a notification sine beep.
            let bases=[(240.0,410.0),(280.0,355.0),(225.0,460.0)]
            let base=second ? bases[kind].1 : bases[kind].0
            let glide=second ? (kind==1 ? 0.23-0.35*u : -0.16+0.34*sin(.pi*u*0.8)) : 0.20*u
            let f0=base*(1+glide+0.012*sin(t*2 * .pi*21))
            phase += 2 * .pi*f0/Double(sampleRate)
            servoPhase += 2 * .pi*(76+30*u)/Double(sampleRate)
            let f1=second ? 680-240*u : 390+160*u
            let f2=second ? 1550-250*u : 1050+300*u
            var body=0.0
            for harmonic in 1...10 {
                let f=f0*Double(harmonic)
                let resonances=exp(-pow((f-f1)/260,2))+0.55*exp(-pow((f-f2)/400,2))
                let amplitude=(0.13+resonances)/Double(harmonic)
                body += sin(phase*Double(harmonic)+0.22*sin(phase*0.5))*amplitude
            }
            let texture=0.94+0.06*sin(t*2 * .pi*36)
            let signal=tanh(1.4*body)*0.25*texture+sin(servoPhase)*0.015
            return Float(signal*envelope)
        }
        var character=RobotVoiceEffect()
        return character.process(dry)
    }
    static func wav(variant:Int) -> Data {
        let pcm=samples(variant:variant)
        var bytes=Data()
        func word<T:FixedWidthInteger>(_ value:T) {var v=value.littleEndian;withUnsafeBytes(of:&v){bytes.append(contentsOf:$0)}}
        bytes.append(contentsOf:"RIFF".utf8);word(UInt32(36+pcm.count*2));bytes.append(contentsOf:"WAVEfmt ".utf8)
        word(UInt32(16));word(UInt16(1));word(UInt16(1));word(UInt32(sampleRate));word(UInt32(sampleRate*2));word(UInt16(2));word(UInt16(16))
        bytes.append(contentsOf:"data".utf8);word(UInt32(pcm.count*2))
        for sample in pcm {word(Int16(max(-32767,min(32767,Int(sample*32767)))))}
        return bytes
    }
}

final class RobotSounds {
    private var player:AVAudioPlayer?
    private let gestures=(0..<3).map {RobotChirp.wav(variant:$0)}
    private var next=0
    static var enabled:Bool {UserDefaults.standard.object(forKey:"roveRobotSounds") as? Bool ?? true}
    func stop() {player?.stop();player=nil}
    @discardableResult func play() -> TimeInterval {
        stop();guard Self.enabled else {return 0}
        do {
            let audio=try AVAudioPlayer(data:gestures[next]);next=(next+1)%3
            audio.volume=0.75;audio.prepareToPlay()
            guard audio.play() else {return 0}
            player=audio;return audio.duration
        } catch {return 0}
    }
}
