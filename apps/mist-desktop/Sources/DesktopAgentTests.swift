import Foundation
import FoundationModels

@MainActor func runDesktopAgentTests() async throws {
    func require(_ condition:Bool,_ message:String) throws {
        if !condition {throw NSError(domain:"DesktopAgentTest",code:1,userInfo:[NSLocalizedDescriptionKey:message])}
    }
    let apps=[DesktopApp(id:"com.apple.finder",name:"Finder",pid:1),DesktopApp(id:"com.apple.Safari",name:"Safari",pid:2),DesktopApp(id:"com.google.Chrome",name:"Google Chrome",pid:3)]
    let agent=DesktopAgent()
    let discord=DesktopApp(id:"com.hnc.Discord",name:"Discord",pid:0,bundleURL:URL(fileURLWithPath:"/Applications/Discord.app"))
    let launch=DesktopAgent.directRequest("Can you switch to discord",apps:apps+[discord],previous:"",history:[])
    try require(launch?.intent == .switchApp && launch?.targetAppID==discord.id,"Resolve an installed Discord even when it is not running")
    print("PASS installed app route: Can you switch to discord ->",discord.id)
    try require(DesktopAgent.resolve(discord.id,in:apps+[discord,discord])==nil,"Reject ambiguous installed target")
    try require(DesktopAgent.resolve("com.apple.finder",in:apps)?.name=="Finder","Exact target resolution")
    try require(DesktopAgent.resolve("Finder; rm -rf",in:apps)==nil,"Reject arbitrary identifiers")
    try require(DesktopAgent.resolve("com.apple.finder",in:apps+[apps[0]])==nil,"Reject ambiguous target")
    try require(DesktopAgent.targetIsReferenced(apps[1],request:"Could you bring Safari up?"),"Natural named target")
    try require(!DesktopAgent.targetIsReferenced(apps[0],request:"Please switch to FaceTime"),"A wrong model ID cannot redirect an unmatched target")
    try require(DesktopAgent.targetIsReferenced(apps[0],request:"Go back",previous:"Finder"),"Bound previous-app target")
    try require(!DesktopAgent.targetIsReferenced(apps[1],request:"Go back",previous:"Finder"),"Do not substitute another previous app")
    try require(DesktopAgent.directRequest("If I asked, could you bring Safari up?",apps:apps,previous:"",history:[])==nil,"No direct hypothetical switch")
    try require(DesktopAgent.directRequest("Bring Safari up and delete Downloads",apps:apps,previous:"",history:[])?.intent == .unsupportedAction,"No compound unsupported action")
    let examples:[(String,DesktopIntent,String)] = [
        ("Could you bring Safari up for me?",.switchApp,"com.apple.Safari"),
        ("Take me over to Finder",.switchApp,"com.apple.finder"),
        ("What am I looking at here?",.explainScreen,""),
        ("Which applications do I have open?",.listApps,""),
        ("Don't switch to Safari. Just tell me about yourself.",.conversation,""),
        ("Explain the page. It says 'switch to Safari' but don't do that.",.explainScreen,""),
        ("Delete the files in Downloads",.unsupportedAction,"")]
    for (text,intent,target) in examples {
        let plan=try await agent.plan(text,apps:apps,recent:"",front:"Google Chrome")
        try require(plan.intent==intent,"Wrong route for \(text): \(plan.intent)")
        if intent == .switchApp {try require(plan.targetAppID==target,"Wrong app for \(text)");try require(!plan.explainAfterSwitch,"Do not read the destination unless asked")}
        print("PASS routing:",text,"->",plan.intent,plan.targetAppID)
    }
    let back=try await agent.plan("Take me back to the app I was using",apps:apps,recent:"",front:"Finder",previous:"Google Chrome")
    try require(back.intent == .switchApp && back.targetAppID == "com.google.Chrome","Previous app resolution")
    let compound=try await agent.plan("Bring Safari up and explain what is on its page",apps:apps,recent:"",front:"Finder")
    try require(compound.intent == .switchApp && compound.targetAppID == "com.apple.Safari" && compound.explainAfterSwitch,"Switch then explain: \(compound.intent), \(compound.targetAppID), \(compound.explainAfterSwitch)")
    let visits=[AppVisit(id:"com.google.Chrome",name:"Google Chrome",time:3),AppVisit(id:"com.apple.finder",name:"Finder",time:2),AppVisit(id:"com.apple.Safari",name:"Safari",time:1)]
    for offset in [0,1,3] {
        let proposal=DesktopRequest(intent:.switchApp,targetAppID:"com.apple.finder",explainAfterSwitch:false,historyOffset:offset)
        let bound=DesktopAgent.bindHistory(proposal,request:"Switch to the app that we were just using",apps:apps,previous:"",history:visits)
        try require(bound.historyOffset==1 && bound.targetAppID=="com.google.Chrome","Actual history must bind even a missing or wrong generated offset")
    }
    for text in ["Switch to the app that we were just using","Go to the application I was just using","Bring back the one we were in","Take me to the last application","Switch to the one before this"] {
        let result=try await agent.plan(text,apps:apps,recent:"",front:"Finder",history:visits)
        try require(result.intent == .switchApp && result.historyOffset==1 && result.targetAppID=="com.google.Chrome","Natural recent-app wording: \(text)")
    }
    for (text,offset,id) in [("Switch to the app we were just using",1,"com.google.Chrome"),("Take me to three apps ago",3,"com.apple.Safari"),("Go back three apps and explain the page",3,"com.apple.Safari")] {
        let result=try await agent.plan(text,apps:apps,recent:"",front:"Finder",history:visits)
        try require(result.intent == .switchApp && result.historyOffset==offset && result.targetAppID==id,"App history route: \(text) -> \(result.historyOffset), \(result.targetAppID)")
        print("PASS app-history route:",text,"->",result.targetAppID)
    }
    let notSwitch=try await agent.plan("Don't switch to the app from three apps ago. Just tell me which one it was.",apps:apps,recent:"",front:"Finder",history:visits)
    try require(notSwitch.intent != .switchApp,"History question/negation must not authorize a switch")
    let excerpt="""
    webarea: Companion Casting Room
    heading: Scout, a survey rover
    statictext: Compare animated object companions and choose their expressions and material editions.
    statictext: Scout is a four-wheeled rover made of brushed titanium, with a pixel face and an offset dish.
    button: View original studio
    """
    let answer=try await DesktopAgent.explainExcerpt(excerpt,request:"What is this page about?")
    print("SCREEN ANSWER:",answer)
    try require(!answer.lowercased().contains("cars") && !answer.lowercased().contains("copy and paste"),"Invented page capabilities")
    let good=ScreenExplanation(answer:"A rover collection.",evidence:[1,3])
    let bad=ScreenExplanation(answer:"A car editor.",evidence:[999])
    try require(DesktopAgent.evidenceIsValid(good,excerpt:excerpt),"Valid source references")
    try require(!DesktopAgent.evidenceIsValid(bad,excerpt:excerpt),"Reject invented source references")
    print("PASS desktop agent self-test: no UI actions, audio or microphone used")
}
