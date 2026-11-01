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
        let grounded=ScreenContext.spokenReadout("heading: My article\nstatictext: Actual page fact",selected:[1,999,-1,1])
        precondition(grounded.contains("Actual page fact") && !grounded.contains("999"))
        precondition(grounded.components(separatedBy:"Actual page fact").count==2)
        precondition(ScreenContext.spokenReadout("webarea: Site\nstatictext: Loading older messages…",selected:[]).contains("not exposing enough"))
        precondition(ScreenContext.semanticLines("button: Send\ntextfield: Search").contains("button: Send"))
        let denied = try summarize(["ok":false,"error":["code":"PERM_DENIED","message":"Accessibility required"]])
        precondition(denied.contains("PERM_DENIED") && !denied.contains("useful page"))
        precondition(ScreenContext.summarize(Data("invalid".utf8)).contains("did not return"))
        print("PASS: page text, partial flag, secure-field exclusion, duplicate suppression, permission and malformed errors")
    }
}
