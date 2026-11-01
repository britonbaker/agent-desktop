import Foundation
import PhononTTS

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
            return try await Phonon.load(models: installed, language: .english)
        }
        loading = task
        do { return try await task.value } catch { loading = nil; throw error }
    }
}

final class PhononVoice {
    private var task: Task<Void, Never>?
    private var revision = 0
    func cancel() { revision += 1; task?.cancel(); task = nil }
    func stream(_ text: String, onChunk: @escaping ([Float]) -> Void, completion: @escaping (Error?) -> Void) {
        cancel(); let ticket = revision
        task = Task { @MainActor [weak self] in
            do {
                let model = try await PhononModel.shared.get()
                try Task.checkCancellation()
                for try await chunk in model.stream(text) {
                    try Task.checkCancellation()
                    guard let self, self.revision == ticket else { return }
                    onChunk(chunk)
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
