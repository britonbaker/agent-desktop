import AppKit

/// Uses a disposable native fixture only. No microphone, audio or real document mutations.
@MainActor func runScreenActionTests(statePath:String) async throws {
    func check(_ condition:Bool,_ message:String) throws {if !condition {throw NSError(domain:"ScreenActionTest",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
    guard let fixture=NSWorkspace.shared.runningApplications.first(where:{$0.bundleIdentifier=="local.briton.rove.actionfixture"}),let url=fixture.bundleURL else {throw NSError(domain:"ScreenActionTest",code:2)}
    if VisionConfiguration.installed {try await LocalVision.shared.prepare()}
    let configuration=NSWorkspace.OpenConfiguration();configuration.activates=true;configuration.createsNewApplicationInstance=false
    _=try await NSWorkspace.shared.openApplication(at:url,configuration:configuration)
    for _ in 0..<30 {if NSWorkspace.shared.frontmostApplication?.processIdentifier==fixture.processIdentifier {break};try await Task.sleep(for:.milliseconds(50))}
    func state()->[String:Any] {(try? JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:statePath)))) as? [String:Any] ?? [:]}
    func until(_ predicate:([String:Any])->Bool) async throws {
        for _ in 0..<40 {if predicate(state()) {return};try await Task.sleep(for:.milliseconds(50))}
        throw NSError(domain:"ScreenActionTest",code:3,userInfo:[NSLocalizedDescriptionKey:"Fixture state did not reach the requested result."])
    }
    try check(state()["details"] as? String=="Details closed" && state()["draft"] as? String=="" && state()["deleted"] as? Int==0,"Start with a fresh fixture")
    if let window=FrontWindow.find(pid:fixture.processIdentifier),ScreenImage.permitted {try await ScreenImage.capture(window:window.id).write(to:URL(fileURLWithPath:"/tmp/rove-screen-action-fixture.png"))}
    let agent=DesktopAgent();agent.onStatus={print($0)}
    let explanation=try await agent.answer("What's on my screen? Explain this window and the controls I can use.",front:"Rove Action Fixture",recent:"",frontPID:fixture.processIdentifier,authorized:{true})
    print("SCREEN EXPLANATION:",explanation)
    print("CAPTURE SOURCE:",agent.lastSource)
    try check(explanation.contains("Rove Action Fixture"),"Identify the actual host application")
    let open=try await agent.answer("Now do it",front:"Rove Action Fixture",recent:"",frontPID:fixture.processIdentifier,authorized:{true})
    print("NATURAL FOLLOWUP:",open)
    try await until {$0["details"] as? String=="Details open"}
    let typed=try await agent.answer("Can you type hello rover into the Draft field?",front:"Rove Action Fixture",recent:"",frontPID:fixture.processIdentifier,authorized:{true})
    print("NATURAL TYPE:",typed)
    try await until {$0["draft"] as? String=="hello rover"}
    let focus=try await agent.answer("Focus the empty text box directly below Draft",front:"Rove Action Fixture",recent:"",frontPID:fixture.processIdentifier,authorized:{true})
    print("VISUAL SPATIAL TARGET:",focus)
    try await until {$0["focused"] as? String=="Search"}
    let prompt=try await agent.answer("Delete the test item",front:"Rove Action Fixture",recent:"",frontPID:fixture.processIdentifier,authorized:{true})
    print("DESTRUCTIVE REVIEW:",prompt)
    try check(agent.awaitingConfirmation && state()["deleted"] as? Int==0,"Deletion must be held for human confirmation")
    print("FIRST CONFIRMATION:",try await agent.answer("confirm action",front:"Rove Action Fixture",recent:"",frontPID:fixture.processIdentifier,authorized:{true}))
    try check(agent.awaitingConfirmation && state()["deleted"] as? Int==0,"First confirmation cannot mutate")
    agent.cancelActions()
    try check(!agent.awaitingConfirmation && state()["deleted"] as? Int==0,"Interruption cancels the pending action")
    print("PASS live local screen-to-action conversation: source-aware visual explanation, natural followup click, typing, independent readback, destructive review and cancellation")
}
