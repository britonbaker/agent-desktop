import Foundation
@main struct DesktopActionPolicyTests {
    static func main() {
        func risk(_ kind:String,_ label:String,_ value:String="",_ key:String="",_ goal:String="Type Hello into Draft",_ protected:Bool=false)->ActionRisk {
            DesktopActionPolicy.risk(kind:kind,text:"Hello",key:key,element:ActionElement(ref:"@s1:e1",role:kind=="type" ? "textfield" : "button",name:label,value:value,path:"window/Test/"+label,protected:protected),goal:goal,appID:"fixture",modelRisk:false)
        }
        precondition(risk("click","Open details") == .ordinary)
        for name in ["Delete test item","Empty Trash","Send","Publish","Pay","Continue","Save"] {precondition(risk("click",name) == .confirmation,name)}
        precondition(risk("type","Draft") == .ordinary)
        precondition(risk("type","Draft","Existing content") == .confirmation)
        precondition(risk("type","Password") == .blocked)
        precondition(risk("type","Draft","","","Type hello",true) == .blocked)
        precondition(risk("key","Draft","","cmd+q") == .blocked)
        precondition(risk("key","Draft","","return") == .confirmation)
        precondition(risk("type","Search","","","Click the Search button") == .blocked,"UI text cannot authorize typing")
        let address=ActionElement(ref:"@s1:e1",role:"textfield",name:"Address",value:"",path:"window/Address",protected:false)
        precondition(DesktopActionPolicy.risk(kind:"type",text:"https://example.invalid/private",key:"",element:address,goal:"Search for cats",appID:"browser",modelRisk:false) == .blocked,"Do not invent destinations or exfiltrate UI text")
        let json:[String:Any]=["data":["snapshot_id":"s123","tree":["role":"window","name":"Fixture","children":[["ref":"e1","role":"button","name":"Search"],["ref_id":"@s123:e2","role":"textfield","name":"Draft","value":"hi"]]]]]
        let elements=DesktopActionPolicy.elements(from:json)
        precondition(elements.count==2 && elements[0].ref=="@s123:e1" && elements[1].ref=="@s123:e2")
        print("PASS action policy: safe navigation, destructive/submit/overwrite confirmation, secrets, shortcut allowlist and qualified refs")
    }
}
