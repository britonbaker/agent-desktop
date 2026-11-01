import Foundation
import AVFoundation

func writeVoiceAudition(to path:String) async throws {
    let model=try await PhononModel.shared.get()
    let format=AVAudioFormat(standardFormatWithSampleRate:24000,channels:1)!
    let file=try AVAudioFile(forWriting:URL(fileURLWithPath:path),settings:format.settings)
    let text="Hello. I'm Rove. Ready when you are. You're looking at your project on GitHub. I can explain this page, or take you back to the app we just used."
    for try await chunk in model.stream(text) {
        guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(chunk.count)) else {continue}
        buffer.frameLength=AVAudioFrameCount(chunk.count)
        chunk.withUnsafeBufferPointer {buffer.floatChannelData![0].update(from:$0.baseAddress!,count:chunk.count)}
        try file.write(from:buffer)
    }
    print("Wrote on-device Gradium voice audition:",path)
}
