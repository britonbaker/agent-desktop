import Foundation
@main struct ScreenContextTests {
    static func main() throws {
        func summarize(_ object: [String:Any]) throws -> String { ScreenContext.summarize(try JSONSerialization.data(withJSONObject:object)) }
        let fixture: [String:Any] = ["ok":true,"data":["complete":false,"window":["title":"Article"],"tree":["role":"window","children":[["role":"text","name":"A useful page paragraph"],["role":"secureTextField","value":"private-password"],["role":"text","name":"A useful page paragraph"]]]]]
        let result = try summarize(fixture)
        precondition(result.contains("A useful page paragraph") && result.contains("Partial"))
        precondition(!result.contains("private-password"))
        precondition(result.components(separatedBy:"A useful page paragraph").count == 2)
        let denied = try summarize(["ok":false,"error":["code":"PERM_DENIED","message":"Accessibility required"]])
        precondition(denied.contains("PERM_DENIED") && !denied.contains("useful page"))
        precondition(ScreenContext.summarize(Data("invalid".utf8)).contains("did not return"))
        print("PASS: page text, partial flag, secure-field exclusion, duplicate suppression, permission and malformed errors")
    }
}
