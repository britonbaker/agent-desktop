import AppKit
import AVFoundation
import Speech

/// No remote recognition fallback. Audio is ephemeral and not recorded.
final class LocalConversation {
    let engine = AVAudioEngine()
    let captureEngine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let voice = PhononVoice()
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
    var onHeard: ((String) -> Void)?
    var onTurn: ((String) -> Void)?
    var onInterrupt: (() -> Void)?
    var onStatus: ((String) -> Void)?
    var onDiagnostic: ((String) -> Void)?
    private var diagnosticTimer: Timer?
    private var capturedBuffers = 0
    private var peakLevel: Float = 0
    private var recognizedResults = 0
    private var recognitionError = "none"
    var onFailure: ((String) -> Void)?
    private(set) var active = false
    private(set) var speaking = false
    private var tapInstalled = false
    private var speechID = 0
    private var recognitionID = 0
    private var testProducer: Task<Void, Never>?
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var turn = TurnPolicy()
    private var spoken = ""
    private var queued = 0
    private var synthesisEnded = false
    private var retries = 0
    init() { engine.attach(player); engine.connect(player, to: engine.mainMixerNode, format: outputFormat) }
    func start() throws {
        guard !active else { return }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw NSError(domain: "Aural", code: 1, userInfo: [NSLocalizedDescriptionKey:"On-device English recognition is unavailable. No cloud fallback was used."])
        }
        interruptSpeech(); engine.stop()
        // Keep microphone capture independent of playback; reconfiguring VoiceProcessingIO
        // stalls Core Audio on the test Mac and can leave recognition with no usable speech.
        let format = captureEngine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw NSError(domain:"Aural",code:2,userInfo:[NSLocalizedDescriptionKey:"Connect a microphone to begin. A Mac mini needs an external microphone."]) }
        active = true; retries = 0
        capturedBuffers = 0; peakLevel = 0; recognizedResults = 0; recognitionError = "none"
        captureEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // Recognition requests are thread safe for appending audio. Serialize request swaps with this lock.
            guard let self else { return }
            var peak: Float = 0
            if let channel = buffer.floatChannelData?[0] {
                for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channel[i])) }
            }
            self.audioLock.lock()
            self.capturedBuffers += 1; self.peakLevel = max(self.peakLevel, peak)
            self.request?.append(buffer)
            self.audioLock.unlock()
        }
        tapInstalled = true
        diagnosticTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.active else { return }
            self.audioLock.lock(); let count = self.capturedBuffers; let peak = self.peakLevel; self.peakLevel = 0; self.audioLock.unlock()
            let level = peak > 0 ? String(format: "%.0f dB", 20 * log10(peak)) : "silent"
            self.onDiagnostic?("Microphone: \(level) · input: \(format.sampleRate) Hz / \(format.channelCount) channels · audio buffers: \(count) · recognition results: \(self.recognizedResults) · last error: \(self.recognitionError)")
        }
        do { beginRecognition(); try captureEngine.start(); try engine.start(); player.play(); onStatus?("Listening on this Mac. You can speak, or say end conversation.") }
        catch { end(); throw error }
    }
    private let audioLock = NSLock()
    func end() {
        active = false; recognitionID += 1
        testProducer?.cancel(); testProducer = nil
        diagnosticTimer?.invalidate(); diagnosticTimer = nil; onDiagnostic?("Microphone off.")
        interruptSpeech(); task?.cancel(); task = nil
        audioLock.lock(); request = nil; audioLock.unlock()
        if tapInstalled { captureEngine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        captureEngine.stop(); engine.stop(); turn.reset(); onStatus?("Conversation off. Microphone stopped.")
    }
    func interruptSpeech() {
        speechID += 1; speaking = false; spoken = ""; voice.cancel(); player.stop(); queued = 0; synthesisEnded = false
        if active && engine.isRunning { player.play() }
    }
    func cancelTurn() {
        interruptSpeech(); turn.reset()
        if active { beginRecognition(); onStatus?("Listening on this Mac…") }
        else { engine.stop(); onStatus?("Stopped. Microphone off.") }
    }
    func speak(_ text: String) {
        interruptSpeech(); turn.reset()
        do { if !engine.isRunning { try engine.start() } } catch { onStatus?("Audio output unavailable: \(error.localizedDescription)"); return }
        spoken = text; speaking = true; let ticket = speechID
        let started = Date(); var first = true
        onStatus?(active ? "Preparing local Phonon stream. Speak to interrupt." : "Preparing local Phonon stream. Microphone off.")
        voice.stream(text, onChunk: { [weak self] samples in
            guard let self, self.speechID == ticket, !samples.isEmpty else { return }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: self.outputFormat, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { source in buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count) }
            self.queued += 1
            self.player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.async { guard let self, self.speechID == ticket else { return }; self.queued -= 1; self.finishedIfReady() }
            }
            if !self.player.isPlaying { self.player.play() }
            if first {
                first = false
                NSLog("Phonon first scheduled audio: %.3f seconds", Date().timeIntervalSince(started))
                self.onStatus?(self.active ? "Streaming Phonon on this Mac. Speak to interrupt." : "Streaming Phonon on this Mac. Microphone off.")
            }
        }, completion: { [weak self] error in
            guard let self, self.speechID == ticket else { return }
            if let error {
                self.interruptSpeech()
                self.onStatus?("Phonon voice unavailable: \(error). Reply remains available as text.")
            } else { self.synthesisEnded = true; self.finishedIfReady() }
        })
    }
    private func finishedIfReady() {
        guard synthesisEnded, queued == 0 else { return }
        speaking = false; onStatus?(active ? "Listening on this Mac…" : "Phonon ready. Microphone off.")
        if !active { player.stop(); engine.stop() }
        // Retain the spoken text briefly to reject a delayed echo transcript.
        let id = speechID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in guard let self, self.speechID == id, !self.speaking else { return }; self.spoken = "" }
    }
    private func beginRecognition() {
        guard active else { return }
        recognitionID += 1; let id = recognitionID
        audioLock.lock(); request?.endAudio(); audioLock.unlock()
        task?.cancel(); turn.reset()
        let req = SFSpeechAudioBufferRecognitionRequest(); req.requiresOnDeviceRecognition = true; req.shouldReportPartialResults = true; req.taskHint = .dictation
        req.contextualStrings = ["apps", "list apps", "what apps are running", "where am I", "read", "controls", "switch to", "repeat", "stop", "wait", "end conversation"] + NSWorkspace.shared.runningApplications.compactMap(\.localizedName)
        audioLock.lock(); request = req; audioLock.unlock()
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.active, self.recognitionID == id else { return }
                if let error { self.recognitionError = "\((error as NSError).domain) \((error as NSError).code)" }
                if let result {
                    self.recognizedResults += 1
                    let words = result.bestTranscription.formattedString
                    if TurnPolicy.isEcho(words, spoken: self.spoken) { if result.isFinal { self.beginRecognition() }; return }
                    if self.speaking && TurnPolicy.interrupts(words) { self.interruptSpeech(); self.onInterrupt?() }
                    guard !self.speaking else { return }
                    self.retries = 0
                    let changed = self.turn.update(words)
                    if result.isFinal { self.deliver(); return }
                    if changed {
                        self.onStatus?("Heard: \(words)")
                        let revision = self.turn.revision
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            guard let self, self.active, self.recognitionID == id, self.turn.revision == revision else { return }; self.deliver()
                        }
                    }
                } else if error != nil {
                    self.retries += 1
                    if self.retries > 2 { self.fail("Local speech recognition stopped. Check the microphone and downloaded recognition language, then start conversation again.") }
                    else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in guard let self, self.active, self.recognitionID == id else { return }; self.beginRecognition() } }
                }
            }
        }
        // Rotate idle recognizers before their platform time limit. Never cut an active partial utterance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self] in
            guard let self, self.active, self.recognitionID == id else { return }
            if self.turn.text.isEmpty { self.beginRecognition() } else { self.deliver() }
        }
    }
    private func deliver() {
        let text = turn.text
        guard !text.isEmpty else { beginRecognition(); return }
        onHeard?(text); beginRecognition(); onTurn?(text)
    }
    func testRecognition() {
        end()
        guard let recognizer, recognizer.supportsOnDeviceRecognition else { onStatus?("TEST FAIL: on-device recognition unavailable"); return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true; req.shouldReportPartialResults = true
        let id = recognitionID
        onStatus?("Testing local recognition with generated audio. Microphone off.")
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.recognitionID == id else { return }
                if let result { self.onStatus?("Recognition test: \(result.bestTranscription.formattedString)") }
                if let error { self.onDiagnostic?("Recognition test error: \(error)") }
            }
        }
        testProducer = Task { @MainActor [weak self] in
            do {
                let model = try await PhononModel.shared.get()
                for try await samples in model.stream("What applications are running on my computer?") {
                    try Task.checkCancellation()
                    guard let self, self.recognitionID == id else { return }
                    let buffer = AVAudioPCMBuffer(pcmFormat: self.outputFormat, frameCapacity: AVAudioFrameCount(samples.count))!
                    buffer.frameLength = AVAudioFrameCount(samples.count)
                    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
                    req.append(buffer)
                    try await Task.sleep(nanoseconds: UInt64(Double(samples.count) / 24000 * 1e9))
                }
                req.endAudio()
            } catch { self?.onDiagnostic?("Recognition test failed: \(error)") }
        }
    }
    private func fail(_ message: String) { end(); onFailure?(message) }
}
