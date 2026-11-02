import Foundation
@main struct ScreenContextTests {
    static func main() throws {
        func summarize(_ object: [String:Any]) throws -> String { ScreenContext.summarize(try JSONSerialization.data(withJSONObject:object)) }
        let fixture: [String:Any] = ["ok":true,"data":["complete":false,"window":["title":"Article"],"tree":["role":"window","children":[["role":"text","name":"A useful page paragraph"],["role":"secureTextField","value":"private-password"],["role":"text","name":"A useful page paragraph"]]]]]
        let result = try summarize(fixture)
        precondition(result.contains("A useful page paragraph") && result.contains("Partial"))
        precondition(!result.contains("private-password"))
        precondition(result.components(separatedBy:"A useful page paragraph").count == 2)
        let browser:[String:Any]=["ok":true,"data":["complete":true,"tree":["role":"window","children":[["role":"toolbar","name":String(repeating:"Toolbar chrome ",count:500)],["role":"webarea","name":"Page","children":[["role":"main","children":[["role":"statictext","name":"Actual article content"]]]]]]]]]
        let page=try summarize(browser)
        precondition(page.contains("Actual article content") && !page.contains("Toolbar chrome"))
        let longNavigation=(0..<15).map {index in ["role":"link","name":"Navigation item \(index) " + String(repeating:"menu ",count:100)]}
        let documentation:[String:Any]=["ok":true,"data":["tree":["role":"window","children":[["role":"webarea","name":"Rove directory · GitHub","children":[["role":"main","children":[["role":"navigation","children":longNavigation],["role":"article","children":[["role":"heading","name":"Rove voice prototype","value":"1"],["role":"statictext","name":"A local Mac companion with speech and desktop controls."]]]]]]]]]]]
        let doc=try summarize(documentation)
        precondition(doc.contains("A local Mac companion"),"Article content must precede long repository navigation")
        precondition(doc.components(separatedBy:"\n").first?.contains("GitHub")==true,"Keep page identity before the article")
        precondition(!doc.contains("Rove voice prototype · 1"),"Heading levels are not spoken content")
        let grounded=ScreenContext.spokenReadout("heading: My article\nstatictext: Actual page fact",selected:[1,999,-1,1])
        precondition(grounded.contains("Actual page fact") && !grounded.contains("999"))
        precondition(grounded.components(separatedBy:"Actual page fact").count==2)
        precondition(ScreenContext.spokenReadout("webarea: Site\nstatictext: Loading older messages…",selected:[]).contains("not exposing enough"))
        precondition(ScreenContext.semanticLines("button: Send\ntextfield: Search").contains("button: Send"))
        let denied = try summarize(["ok":false,"error":["code":"PERM_DENIED","message":"Accessibility required"]])
        precondition(denied.contains("PERM_DENIED") && !denied.contains("useful page"))
        precondition(ScreenContext.summarize(Data("invalid".utf8)).contains("did not return"))
        let nested:[String:Any]=["ok":true,"data":["window":["title":"Rove workspace"],"tree":["role":"window","children":[["role":"tab","name":"Rove desktop assistant","states":["selected"]],["role":"tab","name":"Unrelated project"],["role":"webarea","name":"Codex workspace","children":[["role":"webarea","name":"Rove repository · GitHub","children":[["role":"main","children":[["role":"statictext","name":"Repository source code"]]]]]]]]]]]
        let nestedText=try summarize(nested)
        precondition(nestedText.contains("Container: Codex workspace") && nestedText.contains("Selected context: Rove desktop assistant") && nestedText.contains("Rove repository"))
        precondition(!nestedText.contains("Unrelated project"),"Do not substitute unrelated sidebar tasks for active context")
        let identity=ScreenObservation(excerpt:nestedText,pageTitle:"GitHub",pageBounds:nil,windowTitle:"Rove workspace")
        precondition(identity.source(app:"Codex",fallbackTitle:nil).contains("Host application: Codex"))
        precondition(identity.orientation(app:"Codex",fallbackTitle:nil)=="You're in Codex, in the Rove workspace window. ")
        precondition(ScreenObservation(excerpt:"",pageTitle:nil,pageBounds:nil).orientation(app:"Codex",fallbackTitle:"Front window")=="You're in Codex. ")
        print("PASS: nested host, selected task and page identity; page text, partial flag, secure-field exclusion, duplicate suppression, permission and malformed errors")
    }
}
