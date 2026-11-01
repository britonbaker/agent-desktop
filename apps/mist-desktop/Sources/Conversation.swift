import Foundation

/// Pure turn policy shared by live recognition and regression tests.
struct TurnPolicy {
    private(set) var text = ""
    private(set) var revision = 0
    mutating func update(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value != text else { return false }
        text = value; revision += 1; return true
    }
    mutating func reset() { text = ""; revision += 1 }
    static func normalized(_ text: String) -> String {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    static func isEcho(_ heard: String, spoken: String) -> Bool {
        let h = normalized(heard), s = normalized(spoken)
        if ["stop", "wait", "pause", "cancel", "quiet"].contains(h) { return false }
        return !h.isEmpty && !s.isEmpty && (" " + s + " ").contains(" " + h + " ")
    }
    static func interrupts(_ text: String) -> Bool {
        let words = normalized(text).split(separator: " ")
        return words.contains { !["um", "uh", "hmm", "ah", "er"].contains(String($0)) }
    }
    static func canonical(_ raw: String) -> String {
        var q = normalized(raw)
        for prefix in ["hey aural ", "aural ", "could you ", "can you ", "would you ", "please "] {
            if q.hasPrefix(prefix) { q = String(q.dropFirst(prefix.count)) }
        }
        if q.hasSuffix(" please") { q = String(q.dropLast(7)) }
        let aliases = ["tell me where i am":"where am i", "what app am i in":"where am i", "what am i looking at":"where am i", "read that to me":"read", "read this to me":"read", "read that":"read", "read it out loud":"read", "what apps are running":"apps", "what applications are running":"apps", "what applications are running on my computer":"apps", "list running apps":"apps", "list applications":"apps", "show me my apps":"apps", "tell me what apps are running":"apps", "what is open":"apps", "say that again":"repeat", "repeat that":"repeat", "take me back":"back", "go back to the previous app":"back", "what can i do here":"controls", "be quiet":"stop", "wait":"stop", "pause":"stop", "quiet":"stop"]
        return aliases[q] ?? q
    }
}

func runConversationTests() {
    func check(_ ok: Bool, _ name: String) { precondition(ok, name); print("PASS: \(name)") }
    var turn = TurnPolicy()
    check(turn.update("switch to"), "partial starts a turn")
    let old = turn.revision
    check(turn.update("switch to Finder") && turn.revision != old, "new words invalidate earlier silence timer")
    check(!turn.update("switch to Finder"), "duplicate callback does not extend turn")
    turn.reset(); check(turn.text.isEmpty && turn.revision != old, "cancel invalidates pending turn")
    check(TurnPolicy.isEcho("you are in finder", spoken: "You are in Finder. Say read."), "reject assistant transcript echo")
    check(TurnPolicy.isEcho("finder", spoken: "You are in Finder."), "reject short echo before first-word interruption")
    check(!TurnPolicy.isEcho("stop", spoken: "You are in Finder."), "allow interruption")
    check(TurnPolicy.interrupts("wait") && TurnPolicy.interrupts("actually open"), "interrupt words and new phrases")
    check(TurnPolicy.interrupts("read") && TurnPolicy.interrupts("actually"), "first meaningful word interrupts without a wake word")
    check(!TurnPolicy.interrupts("um"), "ignore isolated filler for interruption")
    check(TurnPolicy.canonical("Could you read that to me, please?") == "read", "natural reading request")
    check(TurnPolicy.canonical("What apps are running?") == "apps", "natural app list")
    check(TurnPolicy.canonical("What applications are running on my computer?") == "apps", "route recognized application wording")
    check(TurnPolicy.canonical("Please delete my files") == "delete my files", "unsupported actions remain unsupported")
}
