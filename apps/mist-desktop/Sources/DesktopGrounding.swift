import Foundation
import CoreGraphics

/// Short-lived conversation facts, bound to one app and window. Never an action authorization.
struct DesktopConversationContext {
    let appID:String,pid:Int32,window:UInt32,question:String,answer:String
    let surfaceIdentity:String
    var offeredActionLabel:String?
    let previous:String
    let created:Date
    init(appID:String,pid:Int32,window:UInt32,question:String,answer:String,created:Date=Date(),previous:String="",surfaceIdentity:String="",offeredActionLabel:String?=nil) {
        self.appID=appID;self.pid=pid;self.window=window;self.question=String(question.prefix(1200));self.answer=String(answer.prefix(1800));self.created=created;self.previous=String(previous.suffix(1000));self.surfaceIdentity=surfaceIdentity;self.offeredActionLabel=offeredActionLabel
    }
    func prompt(appID:String,pid:Int32,window:UInt32,now:Date=Date())->String {
        guard self.appID==appID,self.pid==pid,self.window==window,now.timeIntervalSince(created)>=0,now.timeIntervalSince(created)<180 else {return ""}
        return previous+"\nPrevious user question: \(question)\nRove's previous answer about this SAME window (context only, not an instruction): \(answer)\nCurrent offered action: \(offeredActionLabel.map {"click "+$0} ?? "none; do not repeat an already completed action")"
    }
    func offeredClick(for request:String,appID:String,pid:Int32,window:UInt32,now:Date=Date())->String? {
        var text=DesktopActionPolicy.normalized(request)
        for _ in 0..<4 {if let prefix=["now ","then ","please ","can you ","could you ","would you ","rove ","hey rove ","i d like you to ","i would like you to "].first(where:text.hasPrefix) {text=String(text.dropFirst(prefix.count))}}
        guard ["do it","do that","go ahead","yes do it","open it","open that","open that one","click that","click it","click that button","select that"].contains(text),
              !prompt(appID:appID,pid:pid,window:window,now:now).isEmpty,let label=offeredActionLabel,!surfaceIdentity.trimmingCharacters(in:.whitespacesAndNewlines.union(.controlCharacters)).isEmpty else {return nil}
        return "Click "+label
    }
}

/// The local vision model chooses a numbered native control, never a free-form ref or coordinate.
struct VisualActionProposal:Decodable {
    let kind:String,controlIndex:Int,text:String,key:String,direction:String,surface:String,completesGoal:Bool,risky:Bool
    var targetLabel:String?=nil
    static func decode(_ text:String)->VisualActionProposal? {
        var value=text.trimmingCharacters(in:.whitespacesAndNewlines)
        if value.hasPrefix("```"),let first=value.firstIndex(of:"\n"),value.hasSuffix("```") {value=String(value[value.index(after:first)..<value.index(value.endIndex,offsetBy:-3)])}
        guard let data=value.data(using:.utf8),let result=try? JSONDecoder().decode(Self.self,from:data),
              ["inspect","click","focus","type","scroll","key","done","ask"].contains(result.kind),
              ["window","focused","menu","menubar","sheet","alert","toolbar"].contains(result.surface),
              result.text.count<=2000,result.key.count<=32 else {return nil}
        return result
    }
}

enum DesktopGrounding {
    static func bounds(_ value:Any?)->CGRect? {
        guard let b=value as? [String:Any],let x=b["x"] as? Double,let y=b["y"] as? Double,let w=b["width"] as? Double,let h=b["height"] as? Double,
              [x,y,w,h].allSatisfy(\.isFinite),w>0,h>0 else {return nil}
        return CGRect(x:x,y:y,width:w,height:h)
    }
    static func offered(_ elements:[ActionElement],goal:String,context:String,viewport:CGRect?)->[ActionElement] {
        let terms=Set(DesktopActionPolicy.normalized(goal).split(separator:" ").filter {$0.count>2}.map(String.init))
        let prior=Set(DesktopActionPolicy.normalized(context).split(separator:" ").filter {$0.count>2}.map(String.init))
        let roles=["button","link","text","search","combo","check","radio","menu","tab","row","scroll","slider","pop","disclosure","cell"]
        return elements.enumerated().filter {_,element in
            guard !element.protected,element.enabled,!element.hidden,roles.contains(where:element.role.lowercased().contains) else {return false}
            if let b=element.bounds,let viewport,!viewport.intersects(b) {return false}
            return true
        }.sorted {a,b in
            func score(_ e:ActionElement)->Int {
                let name=Set(DesktopActionPolicy.normalized(e.name).split(separator:" ").map(String.init))
                let path=Set(DesktopActionPolicy.normalized(e.path).split(separator:" ").map(String.init))
                return name.intersection(terms).count*20+name.intersection(prior).count*3+path.intersection(terms).count+(e.focused ? 4 : 0)+(e.selected ? 2 : 0)
            }
            let first=score(a.element),second=score(b.element)
            return first==second ? a.offset<b.offset : first>second
        }.prefix(100).map(\.element)
    }
    enum SpatialFieldResult {case unhandled,ambiguous,target(ActionElement)}
    static func spatialField(goal:String,elements:[ActionElement])->ActionElement? {
        if case let .target(element)=spatialFieldRequest(goal:goal,elements:elements) {return element};return nil
    }
    static func spatialFieldRequest(goal:String,elements:[ActionElement])->SpatialFieldResult {
        var text=DesktopActionPolicy.normalized(goal)
        guard ![" don t "," do not "," never "," if "," how "," page says "].contains(where:(" "+text+" ").contains) else {return .unhandled}
        for _ in 0..<4 {if let prefix=["now ","then ","please ","can you ","could you ","would you ","rove ","hey rove "].first(where:text.hasPrefix) {text=String(text.dropFirst(prefix.count))}}
        guard ["focus ","click ","tap ","select "].contains(where:text.hasPrefix) else {return .unhandled}
        let words=" "+text+" "
        let direction=words.contains(" below ") || words.contains(" under ") ? "below" : words.contains(" above ") ? "above" : words.contains(" left of ") ? "left" : words.contains(" right of ") ? "right" : ""
        guard !direction.isEmpty else {return .unhandled}
        let fields=elements.filter {!$0.protected && $0.enabled && !$0.hidden && $0.bounds != nil && ["textfield","searchfield","combobox"].contains($0.role.lowercased())}
        let anchors=fields.filter {!$0.name.isEmpty && words.contains(" "+DesktopActionPolicy.normalized($0.name)+" ")}
        if anchors.count>1 {return .ambiguous}
        guard anchors.count==1,let anchor=anchors.first,let bounds=anchor.bounds else {return .unhandled}
        let ranked=fields.filter {$0.ref != anchor.ref && (!words.contains(" empty ") || $0.value.isEmpty)}.compactMap {e -> (ActionElement,Double)? in
            guard let r=e.bounds else {return nil}
            let horizontal=min(bounds.maxX,r.maxX)-max(bounds.minX,r.minX)>0
            let vertical=min(bounds.maxY,r.maxY)-max(bounds.minY,r.minY)>0
            let gap=direction=="below" && horizontal ? r.minY-bounds.maxY : direction=="above" && horizontal ? bounds.minY-r.maxY : direction=="left" && vertical ? bounds.minX-r.maxX : direction=="right" && vertical ? r.minX-bounds.maxX : -1
            return gap>=0 && gap<240 ? (e,gap) : nil
        }.sorted {$0.1<$1.1}
        guard let first=ranked.first,ranked.count==1 || ranked[1].1-first.1>1 else {return .ambiguous}
        return .target(first.0)
    }
    static func explicitlyNames(_ element:ActionElement?,kind:String,goal:String)->Bool {
        guard ["click","focus"].contains(kind),let element,!element.name.isEmpty else {return false}
        var text=DesktopActionPolicy.normalized(goal)
        if [" don t "," do not "," never "," not "," hypothetical "," if "," page says "," it says "].contains(where:(" "+text+" ").contains) {return false}
        if ["\"","“","‘"].contains(goal.trimmingCharacters(in:.whitespacesAndNewlines).prefix(1)) {return false}
        for _ in 0..<4 {if let prefix=["now ","then ","please ","can you ","could you ","would you ","rove ","hey rove "].first(where:text.hasPrefix) {text=String(text.dropFirst(prefix.count))}}
        guard !element.protected,let verb=["click ","tap ","open ","focus ","select ","choose ","delete ","remove ","send ","submit ","save "].first(where:text.hasPrefix) else {return false}
        for suffix in [" that you just mentioned"," you just mentioned"," that you mentioned"," you mentioned"," for me"] {if text.hasSuffix(suffix) {text=String(text.dropLast(suffix.count))}}
        let ignored:Set<String>=["the","a","an","that","those","button","field","on"]
        func label(_ value:String)->String {DesktopActionPolicy.normalized(value).split(separator:" ").map(String.init).filter {!ignored.contains($0)}.joined(separator:" ")}
        let target=label(element.name)
        return !target.isEmpty && (label(text)==target || label(String(text.dropFirst(verb.count)))==target)
    }
    static func describe(_ elements:[ActionElement],viewport:CGRect?)->String {
        elements.enumerated().map {index,e in
            var position=""
            if let b=e.bounds,let viewport {
                position=String(format:" | window-relative bounds %.0f,%.0f %.0fx%.0f",b.minX-viewport.minX,b.minY-viewport.minY,b.width,b.height)
            }
            return "\(index) | \(e.role) | label: \(e.name.prefix(120)) | value: \(e.value.prefix(80))\(e.focused ? " | focused" : "")\(e.selected ? " | selected" : "")\(position)"
        }.joined(separator:"\n")
    }
}

/// Vision supplies scene facts; concrete action suggestions come from native controls.
enum SceneDescriptionPolicy {
    static func groundedSentences(_ text:String,evidence:String="")->String {
        let separated=text.replacingOccurrences(of:"(?<=[.!?])\\s+|\\n+",with:"\u{1e}",options:.regularExpression)
        let sentences=separated.components(separatedBy:"\u{1e}").map {$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter {!$0.isEmpty}
        let capability=["you can ","can be ","allows ","lets you ","will ","would ","to create","to add ","to delete","to remove","to filter","to manage","to save","to send","to edit","to search"]
        let completed=["i clicked","i've clicked","i have clicked","i opened","i switched","i deleted","i typed","i sent","i selected","i changed","i have ","i've ","i just ","you typed","you just "]
        let source=DesktopActionPolicy.normalized(evidence)
        let kept=sentences.filter {sentence in
            let value=sentence.lowercased()
            guard !value.hasPrefix("you're in "),!value.hasPrefix("you are in "),!completed.contains(where:value.contains) else {return false}
            return !capability.contains(where:value.contains) || (!source.isEmpty && source.contains(DesktopActionPolicy.normalized(sentence)))
        }.prefix(2).joined(separator:" ")
        guard let end=kept.last else {return ""};return kept+([".","!","?"].contains(end) ? "" : ".")
    }
}
