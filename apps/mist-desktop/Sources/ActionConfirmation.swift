import Foundation

/// Two distinct human utterances, one use, bounded lifetime. No model output calls this.
struct ActionConfirmation {
    enum Result {case firstPrompt,finalPrompt,approve,cancel,unrelated,expired}
    private enum Stage {case first,final,closed}
    private var stage=Stage.first
    let expires:Date
    init(expires:Date=Date().addingTimeInterval(120)) {self.expires=expires}
    mutating func receive(_ text:String,now:Date=Date())->Result {
        guard stage != .closed else {return .cancel}
        guard now<expires else {stage = .closed;return .expired}
        let words=DesktopActionPolicy.normalized(text)
        if ["cancel","stop","no"].contains(words) {stage = .closed;return .cancel}
        if ["yes","ok","okay","sure"].contains(words) {return stage == .first ? .firstPrompt : .finalPrompt}
        if words=="confirm action" {stage = .final;return .finalPrompt}
        if words=="do it now",stage == .final {stage = .closed;return .approve}
        stage = .closed;return .unrelated
    }
}
