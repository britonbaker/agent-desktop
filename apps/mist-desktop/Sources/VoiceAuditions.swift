import Foundation
import AVFoundation

func writeVoiceAudition(to path:String,voiceName:String?=nil,character:Bool=false,text:String="Hello. I'm Rove. Ready when you are. You're looking at your project on GitHub. I can explain this page, or take you back to the app we just used.") async throws {
    let model=try await PhononModel.shared.get()
    if let voiceName {try await model.setVoice(voiceName)}
    let format=AVAudioFormat(standardFormatWithSampleRate:24000,channels:1)!
    let file=try AVAudioFile(forWriting:URL(fileURLWithPath:path),settings:format.settings)
    var effect=RobotVoiceEffect()
    for try await raw in model.stream(text) {
        let chunk=character ? effect.process(raw) : raw
        guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(chunk.count)) else {continue}
        buffer.frameLength=AVAudioFrameCount(chunk.count)
        chunk.withUnsafeBufferPointer {buffer.floatChannelData![0].update(from:$0.baseAddress!,count:chunk.count)}
        try file.write(from:buffer)
    }
    print("Wrote on-device Gradium voice audition:",model.voice,path)
}

func writeCharacterVoicePreviews(directory:String) async throws {
    let folder=URL(fileURLWithPath:directory,isDirectory:true)
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    for variant in 0..<3 {try RobotChirp.wav(variant:variant).write(to:folder.appendingPathComponent("tap-\(variant+1).wav"))}
    for name in ["Micah","Miles"] {
        try await writeVoiceAudition(to:folder.appendingPathComponent("\(name.lowercased())-us-english.wav").path,voiceName:name,character:true,text:"Hey, I'm Rove. I'm here. Google Chrome is in front. That was three app switches ago. Want me to explain this page?")
    }
}
