import AppKit

/// Read-only real-model checks; the fixture may stay behind the person's active apps.
@MainActor func runVisualGroundingTests() async throws {
    func check(_ condition:Bool,_ message:String) throws {if !condition {throw NSError(domain:"VisualGroundingTest",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
    guard let fixture=NSWorkspace.shared.runningApplications.first(where:{$0.bundleIdentifier=="local.briton.rove.actionfixture"}),let window=FrontWindow.find(pid:fixture.processIdentifier) else {throw NSError(domain:"VisualGroundingTest",code:2)}
    let observation=await ScreenContext.observe(app:"Rove Action Fixture",windowID:window.id)
    let image=try await ScreenImage.capture(window:window.id)
    try image.write(to:URL(fileURLWithPath:"/tmp/rove-screen-action-fixture.png"))
    let source=observation.source(app:"Rove Action Fixture",fallbackTitle:window.title)
    print("CAPTURE SOURCE:",source)
    let began=Date()
    let answer=try await DesktopAgent.groundedExplanation(question:"What's on my screen? Describe the main visible activity and a control.",excerpt:observation.excerpt,image:image,source:source,textUnavailable:false,observation:observation)
    print("GROUNDED DESCRIPTION:",answer,"ELAPSED:",Date().timeIntervalSince(began))
    try check(!answer.lowercased().contains("filter") && !answer.lowercased().contains("add new test items"),"Do not invent functionality from a field label")
    let bridge=DesktopToolBridge()
    let raw=try await bridge.call(["snapshot","--window-id","w-\(window.id)","--include-bounds","--compact"],authorized:{true})
    let elements=DesktopActionPolicy.elements(from:raw)
    let info=(raw["data"] as? [String:Any])?["window"] as? [String:Any]
    let bounds=DesktopGrounding.bounds(info?["bounds"])
    let goal="Focus the empty text box directly below Draft"
    let offered=DesktopGrounding.offered(elements,goal:goal,context:"",viewport:bounds)
    let controls=DesktopGrounding.describe(offered,viewport:bounds)
    guard let native=DesktopGrounding.spatialField(goal:goal,elements:offered) else {throw NSError(domain:"VisualGroundingTest",code:3,userInfo:[NSLocalizedDescriptionKey:"No unique native spatial target"])}
    print("NATIVE SPATIAL TARGET:",native.name)
    try check(native.name=="Search","Spatial grounding must choose Search below Draft")
    let step=UIActionStep(kind:.focus,ref:native.ref,text:"",key:"",direction:"down",surface:.window,completesGoal:true,risky:false)
    let review=try await DesktopActions.authorize(step,element:native,goal:goal,context:"",controls:controls,direct:true)
    try check(review.authorized,"A unique native spatial binding must authorize the requested focus")
    print("PASS read-only local visual grounding: source-checked capture, capability-grounded description, native spatial target and authorization; no actions or microphone")
}
