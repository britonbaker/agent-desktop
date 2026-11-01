import Foundation
import PhononTTS

func runStreamTests() async throws {
    let loading = Date()
    let model = try await PhononModel.shared.get()
    precondition(model.voice==RoveSpeechVoice.selected && RoveSpeechVoice.available.contains(model.voice))
    print("PASS explicit bundled US English voice:",model.voice)
    print(String(format: "Local model ready in %.3fs", Date().timeIntervalSince(loading)))
    let text = "You are in Finder. I can help you explore your computer without looking at the screen. You can interrupt me whenever you need to change direction."
    let start = Date(); var first = 0.0; var chunks = 0; var samples = 0
    for try await chunk in model.stream(text) {
        if chunks == 0 { first = Date().timeIntervalSince(start) }
        precondition(!chunk.isEmpty && chunk.allSatisfy { $0.isFinite })
        chunks += 1; samples += chunk.count
    }
    let total = Date().timeIntervalSince(start)
    precondition(chunks > 3 && first < total)
    print(String(format: "PASS real stream: first %.3fs, generation %.3fs, %d chunks, %.2fs audio", first, total, chunks, Double(samples) / 24000))
    let interrupted = Task { () throws -> Int in
        var received = 0
        for try await _ in model.stream(String(repeating: text, count: 8)) {
            received += 1
            if received == 3 { withUnsafeCurrentTask { $0?.cancel() } }
            if Task.isCancelled { break }
        }
        return received
    }
    let count = try await interrupted.value
    precondition(count == 3)
    let resume = Date(); var resumed = 0
    for try await _ in model.stream("I stopped. What would you like next?") { resumed += 1 }
    precondition(resumed > 0)
    print(String(format: "PASS cancelled generation after %d chunks; next reply completed in %.3fs", count, Date().timeIntervalSince(resume)))
    try await verifyVoiceCancellation()
}

@MainActor
private func verifyVoiceCancellation() async throws {
    let voice = PhononVoice()
    var oldChunks = 0; var oldCompleted = false
    await withCheckedContinuation { (ready: CheckedContinuation<Void, Never>) in
        voice.stream(String(repeating: "This is a long response that should be interrupted. ", count: 12), onChunk: { _ in
            oldChunks += 1
            if oldChunks == 3 { voice.cancel(); ready.resume() }
        }, completion: { _ in oldCompleted = true })
    }
    var newChunks = 0
    let failure: Error? = await withCheckedContinuation { done in
        voice.stream("Ready for your next request.", onChunk: { _ in newChunks += 1 }, completion: { done.resume(returning: $0) })
    }
    if let failure { throw failure }
    precondition(oldChunks == 3 && !oldCompleted && newChunks > 0)
    print("PASS app cancellation: no stale chunks or completion; replacement stream succeeds")
}
