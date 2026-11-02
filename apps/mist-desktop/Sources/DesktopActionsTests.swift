import AppKit

@MainActor func runDesktopActionsTests(statePath:String) async throws {
    func check(_ value:Bool,_ message:String) throws {if !value {throw NSError(domain:"ActionTest",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
    guard let fixture=NSWorkspace.shared.runningApplications.first(where:{$0.bundleIdentifier=="local.briton.rove.actionfixture"}),let url=fixture.bundleURL else {throw NSError(domain:"ActionTest",code:2,userInfo:[NSLocalizedDescriptionKey:"Start the disposable fixture first."])}
    let configuration=NSWorkspace.OpenConfiguration();configuration.activates=true;configuration.createsNewApplicationInstance=false
    _=try await NSWorkspace.shared.openApplication(at:url,configuration:configuration)
    for _ in 0..<20 {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier==fixture.processIdentifier {break}
        try await Task.sleep(for:.milliseconds(50))
    }
    let target=DesktopApp(id:"local.briton.rove.actionfixture",name:"Rove Action Fixture",pid:fixture.processIdentifier)
    try check(NSWorkspace.shared.frontmostApplication?.processIdentifier==fixture.processIdentifier,"Fixture did not become frontmost; current app is \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown")")
    func state()->[String:Any] {(try? JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:statePath)))) as? [String:Any] ?? [:]}
    try check(state()["draft"] as? String=="" && state()["deleted"] as? Int==0 && state()["details"] as? String=="Details closed","Restart the fixture so this test begins with empty disposable controls")
    func until(_ predicate:([String:Any])->Bool) async throws {
        for _ in 0..<30 {if predicate(state()) {return};try await Task.sleep(for:.milliseconds(50))}
        throw NSError(domain:"ActionTest",code:3,userInfo:[NSLocalizedDescriptionKey:"Fixture state did not reach the expected value."])
    }
    let agent=DesktopActions();agent.onStatus={print($0)}
    print("NATURAL CLICK:",try await agent.run("Click Open details",app:target,authorized:{true}))
    try await until {$0["details"] as? String=="Details open"}
    print("TYPE:",try await agent.run("Type hello rover into the Draft field",app:target,authorized:{true}))
    try await until {$0["draft"] as? String=="hello rover"}
    print("NAVIGATE:",try await agent.run("Press tab",app:target,authorized:{true}))
    try await until {$0["focused"] as? String=="Search"}
    print("SCROLL:",try await agent.run("Scroll down in Test list",app:target,authorized:{true}))
    try await until {($0["scroll"] as? Double ?? 0)>0}
    let prompt=try await agent.run("Click Delete test item",app:target,authorized:{true});print("CONFIRMATION:",prompt)
    try check(agent.awaitingConfirmation && state()["deleted"] as? Int==0,"Destructive action must not run before confirmation")
    do {_=try await agent.run("Click Open details",app:target,authorized:{false});throw NSError(domain:"ActionTest",code:6)} catch is CancellationError {}
    try check(agent.awaitingConfirmation,"A cancelled older turn must not erase a newer pending confirmation")
    print("REVIEW:",try await agent.confirm("confirm action",authorized:{true}) ?? "missing")
    try check(agent.awaitingConfirmation && state()["deleted"] as? Int==0,"First approval must not mutate")
    print("APPROVED:",try await agent.confirm("do it now",authorized:{true}) ?? "missing")
    try await until {$0["deleted"] as? Int==1}
    try check(!agent.awaitingConfirmation,"Confirmation must be consumed")
    try check(try await agent.confirm("do it now",authorized:{true})==nil,"Approval cannot be replayed")
    _=try await agent.run("Click Delete test item",app:target,authorized:{true})
    _=try await agent.confirm("confirm action",authorized:{true})
    let external=DesktopToolBridge()
    guard let window=FrontWindow.find(pid:fixture.processIdentifier) else {throw NSError(domain:"ActionTest",code:4)}
    let snapshot=try await external.call(["snapshot","--window-id","w-\(window.id)","--compact"],authorized:{true})
    guard let change=DesktopActionPolicy.elements(from:snapshot).first(where:{$0.name=="Change selection"}) else {throw NSError(domain:"ActionTest",code:5)}
    _=try await external.call(["click",change.ref],authorized:{true})
    let denied=try await agent.confirm("do it now",authorized:{true}) ?? ""
    try check(denied.contains("changed") && state()["deleted"] as? Int==1,"Changed selection must invalidate the pending destructive action")
    print("PASS live agent-desktop fixture: click, typing, keyboard navigation, scroll, independent readback, two confirmations, no replay and changed-context cancellation")
}
