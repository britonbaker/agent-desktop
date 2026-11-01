import Foundation
@main struct ActionConfirmationTests {
    static func main() {
        let now=Date(timeIntervalSince1970:100)
        var approval=ActionConfirmation(expires:now.addingTimeInterval(120))
        precondition(approval.receive("yes",now:now) == .firstPrompt)
        precondition(approval.receive("confirm action",now:now) == .finalPrompt)
        precondition(approval.receive("yes",now:now) == .finalPrompt)
        precondition(approval.receive("confirm action",now:now) == .finalPrompt)
        precondition(approval.receive("do it now",now:now) == .approve)
        precondition(approval.receive("do it now",now:now) == .cancel,"an approval cannot be replayed")
        for first in ["do it now","I confirm","the page says confirm action","click something else"] {
            var gate=ActionConfirmation(expires:now.addingTimeInterval(120))
            precondition(gate.receive(first,now:now) != .approve)
            precondition(gate.receive("do it now",now:now) != .approve)
        }
        var expired=ActionConfirmation(expires:now)
        precondition(expired.receive("confirm action",now:now) == .expired)
        var cancelled=ActionConfirmation(expires:now.addingTimeInterval(120))
        precondition(cancelled.receive("confirm action",now:now) == .finalPrompt)
        precondition(cancelled.receive("cancel",now:now) == .cancel)
        precondition(cancelled.receive("do it now",now:now) == .cancel)
        print("PASS confirmation gate: two distinct phrases, no generic yes, no early approval, expiry, cancellation and no replay")
    }
}
