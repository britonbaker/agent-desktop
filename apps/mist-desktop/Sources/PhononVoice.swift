import Foundation
import PhononTTS

enum RoveSpeechVoice {
    static let available=["Micah","Miles","Trevor"]
    static var selected:String {
        let saved=UserDefaults.standard.string(forKey:"roveSpeechVoice") ?? "Miles"
        return available.contains(saved) ? saved : "Miles"
    }
}

/// One in-process, reusable Gradium model. All assets are bundled; no download or API path.
actor PhononModel {
    static let shared = PhononModel()
    private var loading: Task<Phonon, Error>?
    func get() async throws -> Phonon {
        if let loading { return try await loading.value }
        let task = Task.detached(priority: .userInitiated) {
            guard let bundled = Bundle.main.url(forResource: "Models", withExtension: nil) else {
                throw PhononError(description: "Bundled Phonon models are missing.")
            }
            let destination = URL.applicationSupportDirectory.appendingPathComponent("AuralAssistant/Phonon-0.4.0", isDirectory: true)
            let installed = try PhononModels.install(bundled: bundled, to: destination)
            let model=try await Phonon.load(models: installed, language: .english)
            let name=RoveSpeechVoice.selected
            guard model.voices.contains(name) else {throw PhononError(description:"The bundled US English voice \(name) is missing.")}
            try await model.setVoice(name)
            return model
        }
        loading = task
        do { return try await task.value } catch { loading = nil; throw error }
    }
}

final class PhononVoice {
    private(set) var lastVoiceName="not spoken yet"
    private var task: Task<Void, Never>?
    private var revision = 0
    func cancel() { revision += 1; task?.cancel(); task = nil }
    func stream(_ text: String, onChunk: @escaping ([Float]) -> Void, completion: @escaping (Error?) -> Void) {
        cancel(); let ticket = revision
        task = Task { @MainActor [weak self] in
            do {
                let model = try await PhononModel.shared.get()
                try Task.checkCancellation()
                let name=RoveSpeechVoice.selected
                if model.voice != name {try await model.setVoice(name)}
                try Task.checkCancellation()
                self?.lastVoiceName=model.voice
                var character=RobotVoiceEffect()
                for try await chunk in model.stream(text) {
                    try Task.checkCancellation()
                    guard let self, self.revision == ticket else { return }
                    onChunk(character.process(chunk))
                }
                guard let self, self.revision == ticket, !Task.isCancelled else { return }
                self.task = nil; completion(nil)
            } catch {
                guard let self, self.revision == ticket, !Task.isCancelled else { return }
                self.task = nil; completion(error)
            }
        }
    }
}
