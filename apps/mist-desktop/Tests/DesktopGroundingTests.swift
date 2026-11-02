import Foundation
import CoreGraphics
@main struct DesktopGroundingTests {
 static func main() {
    let date=Date(timeIntervalSince1970:1000)
    let context=DesktopConversationContext(appID:"fixture",pid:123,window:9,question:"What's on my screen?",answer:"The Open details button shows more information.",created:date)
    precondition(context.prompt(appID:"fixture",pid:123,window:9,now:date.addingTimeInterval(20)).contains("Open details"))
    precondition(context.prompt(appID:"other",pid:123,window:9,now:date).isEmpty)
    precondition(context.prompt(appID:"fixture",pid:124,window:9,now:date).isEmpty)
    precondition(context.prompt(appID:"fixture",pid:123,window:10,now:date).isEmpty)
    precondition(context.prompt(appID:"fixture",pid:123,window:9,now:date.addingTimeInterval(181)).isEmpty)
    var controls=(0..<160).map {ActionElement(ref:"@s1:e\($0)",role:"button",name:"Sidebar item \($0)",value:"",path:"window/sidebar",protected:false)}
    let target=ActionElement(ref:"@s1:e170",role:"button",name:"Open details",value:"",path:"window/main",protected:false,bounds:CGRect(x:100,y:100,width:90,height:30))
    controls.append(target)
    controls.append(ActionElement(ref:"@s1:e171",role:"textfield",name:"Password",value:"private",path:"window",protected:true))
    controls.append(ActionElement(ref:"@s1:e172",role:"button",name:"Open details hidden",value:"",path:"window",protected:false,hidden:true))
    controls.append(ActionElement(ref:"@s1:e173",role:"button",name:"Open details disabled",value:"",path:"window",protected:false,enabled:false))
    controls.append(ActionElement(ref:"@s1:e174",role:"button",name:"Open details offscreen",value:"",path:"window",protected:false,bounds:CGRect(x:2000,y:100,width:90,height:30)))
    let offered=DesktopGrounding.offered(controls,goal:"Open those details",context:"",viewport:CGRect(x:0,y:0,width:500,height:500))
    precondition(offered.first==target && offered.count==100,"Relevant controls beyond the original first 100 must remain usable")
    precondition(!offered.contains {$0.ref=="@s1:e171" || $0.ref=="@s1:e172" || $0.ref=="@s1:e173" || $0.ref=="@s1:e174"})
    for goal in ["Now open the details you just mentioned","Could you click the Open details button for me?"] {precondition(DesktopGrounding.explicitlyNames(target,kind:"click",goal:goal))}
    for goal in ["Don't open details","Can you show me how to open details","Click instructions for Open details","The page says open details","\"Open details\""] {precondition(!DesktopGrounding.explicitlyNames(target,kind:"click",goal:goal),goal)}
    let delete=ActionElement(ref:"@s1:e175",role:"button",name:"Delete test item",value:"",path:"window",protected:false)
    precondition(DesktopGrounding.explicitlyNames(delete,kind:"click",goal:"Delete the test item"))
    precondition(DesktopActionPolicy.risk(kind:"click",text:"",key:"",element:delete,goal:"Delete the test item",appID:"fixture",modelRisk:false) == .confirmation,"A clearly requested destructive target still requires review")
    let proposalContext=DesktopConversationContext(appID:"fixture",pid:123,window:9,question:"What's here?",answer:"A test fixture. I can select Open details next.",created:date,surfaceIdentity:"Fixture page",offeredActionLabel:"Open details")
    for phrase in ["Now do it","Please do it","Could you open that one"] {precondition(proposalContext.offeredClick(for:phrase,appID:"fixture",pid:123,window:9,now:date)=="Click Open details")}
    precondition(proposalContext.offeredClick(for:"Tell me about yourself",appID:"fixture",pid:123,window:9,now:date)==nil)
    precondition(proposalContext.offeredClick(for:"Do it",appID:"fixture",pid:123,window:10,now:date)==nil)
    precondition(proposalContext.offeredClick(for:"Do it",appID:"fixture",pid:123,window:9,now:date.addingTimeInterval(181))==nil)
    let draft=ActionElement(ref:"@s1:e180",role:"textfield",name:"Draft",value:"hello",path:"window",protected:false,bounds:CGRect(x:10,y:50,width:300,height:22))
    let search=ActionElement(ref:"@s1:e181",role:"textfield",name:"Search",value:"",path:"window",protected:false,bounds:CGRect(x:10,y:90,width:300,height:22))
    precondition(DesktopGrounding.spatialField(goal:"Focus the empty text box directly below Draft",elements:[draft,search])==search)
    precondition(DesktopGrounding.spatialField(goal:"Don't focus the box below Draft",elements:[draft,search])==nil)
    precondition(DesktopGrounding.spatialField(goal:"Which box is below Draft",elements:[draft,search])==nil)
    var another=search;another=ActionElement(ref:"@s1:e182",role:"textfield",name:"Other",value:"",path:"window",protected:false,bounds:search.bounds)
    precondition(DesktopGrounding.spatialField(goal:"Focus the box below Draft",elements:[draft,search,another])==nil,"Ambiguous geometry asks rather than guessing")
    let caption="A test fixture shows local controls. You can use Draft to create items. You can use Search to filter rows."
    precondition(SceneDescriptionPolicy.groundedSentences(caption)=="A test fixture shows local controls.")
    precondition(SceneDescriptionPolicy.groundedSentences("The GitHub.com page shows a README.")=="The GitHub.com page shows a README.")
    precondition(SceneDescriptionPolicy.groundedSentences("I clicked Delete.").isEmpty)
    precondition(SceneDescriptionPolicy.groundedSentences("You can read the documentation.",evidence:"statictext: You can read the documentation.")=="You can read the documentation.")
    let result="""
    {"kind":"click","controlIndex":0,"text":"","key":"","direction":"down","surface":"window","completesGoal":true,"risky":false}
    """
    precondition(VisualActionProposal.decode(result)?.controlIndex==0)
    precondition(VisualActionProposal.decode("```json\n"+result+"\n```") != nil)
    precondition(VisualActionProposal.decode(result.replacingOccurrences(of:"click",with:"shell"))==nil)
    precondition(VisualActionProposal.decode("Run a command. "+result)==nil)
    let raw:[String:Any]=["data":["snapshot_id":"s12","tree":["role":"window","children":[["role":"securecontainer","protected":true,"children":[["role":"textfield","name":"Nested","value":"secret","ref":"e1"]]]]]]]
    let protected=DesktopActionPolicy.elements(from:raw)
    precondition(protected.first?.protected==true && protected.first?.value=="","Protected ancestors must protect descendant values")
    print("PASS same-window expiring conversation context, ranked native targets, visibility/protection, structured local visual plans and inherited secret protection")
 }
}
