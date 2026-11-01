import Foundation

struct ActionElement:Equatable {
    let ref:String,role:String,name:String,value:String,path:String
    let protected:Bool
    var selected=false
    var focused=false
    var identity:String {[role,name,value,path].joined(separator:"\u{1f}")}
}
enum ActionRisk:Equatable {case ordinary,confirmation,blocked}
enum DesktopActionPolicy {
    static let keys:Set<String>=["tab","shift+tab","escape","up","down","left","right","pageup","pagedown","home","end","cmd+f","cmd+l","cmd+[","cmd+]","return","enter","backspace","delete","cmd+w"]
    static func normalized(_ text:String)->String {text.lowercased().split {!$0.isLetter && !$0.isNumber}.joined(separator:" ")}
    static func risk(kind:String,text:String,key:String,element:ActionElement?,goal:String,appID:String,modelRisk:Bool,compositionDestinationExplicit:Bool=false)->ActionRisk {
        if ["com.apple.Terminal","com.googlecode.iterm2","com.apple.ScriptEditor2","com.apple.keychainaccess"].contains(appID) {return .blocked}
        let context=normalized([element?.role ?? "",element?.name ?? "",element?.path ?? ""].joined(separator:" "))
        let targetContext=normalized([element?.role ?? "",element?.name ?? ""].joined(separator:" "))
        let forbidden=["password","terminal","console","run script","execute code","allow access","grant access","install profile","payment card","credit card","security code"]
        if element?.protected==true || element?.role.lowercased().contains("secure")==true || forbidden.contains(where:targetContext.contains) {return .blocked}
        if appID=="com.apple.systempreferences" && ["accessibility","screen recording","full disk","input monitoring","privacy","security","permissions"].contains(where:context.contains) {return .blocked}
        if kind=="key" && !keys.contains(key.lowercased()) {return .blocked}
        if kind=="type" && (text.count>2000 || ["javascript:","data:","file://"].contains(where:text.lowercased().hasPrefix)) {return .blocked}
        let sensitive=["delete","trash","remove","erase","empty","wipe","destroy","reset","overwrite","replace","discard","send","submit","post","publish","purchase","buy","pay","transfer","unsubscribe","close","quit","save","accept","agree","authorize","confirm","continue","proceed","commit","finish","complete","yes","ok","done","apply","install","run"]
        let labels=Set(normalized(element?.name ?? "").split(separator:" ").map(String.init))
        let requested=Set(normalized(goal).split(separator:" ").map(String.init))
        if kind=="type" {
            let goalText=" "+normalized(goal)+" ",payload=normalized(text)
            let literal = !payload.isEmpty && goalText.contains(" "+payload+" ")
            let typingWords:Set<String>=["type","enter","write","draft","compose","fill","search","find","look","navigate","go"]
            let compose = !requested.isDisjoint(with:["write","draft","compose"])
            let addressLike=["address","location","url","search"].contains(where:targetContext.contains)
            let fieldName=normalized(element?.name ?? "")
            let namedDestination = !fieldName.isEmpty && [" into "," in "].contains {goalText.contains($0+fieldName+" ")}
            let generated=compose && !addressLike && (compositionDestinationExplicit || namedDestination)
            let clearing=payload.isEmpty && !requested.isDisjoint(with:["clear","erase","delete"])
            if requested.isDisjoint(with:typingWords) && !clearing {return .blocked}
            if !literal && !generated && !clearing {return .blocked}
        }
        let riskyKey=kind=="key" && ["return","enter","backspace","delete","cmd+w"].contains(key.lowercased())
        let editing=kind=="type" && !(element?.value ?? "").isEmpty
        if modelRisk || riskyKey || editing || !labels.isDisjoint(with:sensitive) || !requested.isDisjoint(with:sensitive) {return .confirmation}
        return .ordinary
    }
    static func elements(from envelope:[String:Any]) -> [ActionElement] {
        guard let data=envelope["data"] as? [String:Any],let tree=data["tree"] as? [String:Any] else {return []}
        let snapshot=data["snapshot_id"] as? String ?? ""
        var result:[ActionElement]=[]
        func visit(_ node:[String:Any],path:String) {
            let role=node["role"] as? String ?? "",name=node["name"] as? String ?? ""
            let route=String((path+"/"+role+":"+name).suffix(600))
            let raw=(node["ref_id"] as? String) ?? (node["ref"] as? String) ?? (node["id"] as? String) ?? ""
            let ref=raw.hasPrefix("@s") ? raw : (!raw.isEmpty && !snapshot.isEmpty ? "@\(snapshot):\(raw.replacingOccurrences(of:"@",with:""))" : "")
            if ref.range(of:"^@[A-Za-z0-9_-]+:e[0-9]+$",options:.regularExpression) != nil {
                let value=(node["value"] as? String) ?? ""
                let states=node["states"] as? [String] ?? []
                result.append(ActionElement(ref:ref,role:role,name:name,value:value,path:route,protected:(node["protected"] as? Bool ?? false) || states.contains("protected"),selected:states.contains("selected"),focused:states.contains("focused")))
            }
            for child in node["children"] as? [[String:Any]] ?? [] {visit(child,path:route)}
        }
        visit(tree,path:"");return result
    }
}
