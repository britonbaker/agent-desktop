import Foundation
import CoreGraphics

struct ScreenContext {
    static func readableLines(_ excerpt:String) -> [String] {
        let preferred=["heading:","statictext:","text:","paragraph:","webarea:","link:"]
        let lines=excerpt.components(separatedBy:"\n")
        let content=lines.filter { line in
            guard preferred.contains(where:{line.lowercased().hasPrefix($0)}),let colon=line.firstIndex(of:":") else {return false}
            let value=String(line[line.index(after:colon)...]).trimmingCharacters(in:.whitespaces).lowercased()
            guard value != "site",!value.hasPrefix("loading"),!value.hasPrefix("you said"),!value.hasPrefix("chatgpt said"),!value.hasPrefix("skip to") else {return false}
            return value.count>=12 || line.hasPrefix("heading:") || line.hasPrefix("webarea:")
        }
        return content
    }
    static func semanticLines(_ excerpt:String) -> [String] {
        let controls=["button:","textfield:","combobox:","checkbox:","menuitem:","radiobutton:","slider:"]
        let namedControls=excerpt.components(separatedBy:"\n").filter {line in controls.contains(where:line.lowercased().hasPrefix)}
        return readableLines(excerpt)+namedControls
    }
    static func spokenReadout(_ excerpt:String, selected:[Int]) -> String {
        let lines=readableLines(excerpt)
        var seen=Set<Int>()
        var chosen=selected.filter {lines.indices.contains($0) && seen.insert($0).inserted}.prefix(3).map {lines[$0]}
        if chosen.isEmpty {chosen=Array(lines.prefix(3))}
        let text=chosen.map { line -> String in
            let value=line.firstIndex(of:":").map {String(line[line.index(after:$0)...]).trimmingCharacters(in:.whitespaces)} ?? line
            return String(value.prefix(240))
        }.joined(separator:". ")
        guard !text.isEmpty else {return "This window is not exposing enough page text for a reliable readout yet."}
        return "Here is text I can read from this window. " + text + (excerpt.contains("Partial window excerpt") ? ". This is a partial readout." : "")
    }
    static func describe(app:String,windowID:CGWindowID? = nil) async -> String {
        await observe(app:app,windowID:windowID).excerpt
    }
    static func observe(app:String,windowID:CGWindowID? = nil) async -> ScreenObservation {
        do {
            let output=try await Task.detached(priority:.userInitiated) { () throws -> Data in
                let tools=URL.applicationSupportDirectory.appendingPathComponent("Rove/Tools",isDirectory:true)
                try FileManager.default.createDirectory(at:tools,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
                for name in ["agent-desktop","agent-desktop-macos-helper"] {
                    guard let source=Bundle.main.url(forResource:name,withExtension:nil) else {throw NSError(domain:"RoveReaderMissing",code:1)}
                    let target=tools.appendingPathComponent(name),bytes=try Data(contentsOf:source)
                    if (try? Data(contentsOf:target)) != bytes {try bytes.write(to:target,options:.atomic)}
                    try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:target.path)
                }
                let process=Process(),pipe=Pipe()
                process.executableURL=tools.appendingPathComponent("agent-desktop")
                let target=windowID.map {["--window-id","w-\($0)"]} ?? ["--app",app]
                process.arguments=["snapshot"]+target+["--compact","--include-bounds","--max-depth","30","--timeout-ms","10000"]
                process.standardOutput=pipe;process.standardError=FileHandle.nullDevice
                try process.run()
                DispatchQueue.global().asyncAfter(deadline:.now()+12) {if process.isRunning {process.terminate()}}
                let bytes=pipe.fileHandleForReading.readDataToEndOfFile();process.waitUntilExit()
                return bytes
            }.value
            let root=try? JSONSerialization.jsonObject(with:output) as? [String:Any]
            let data=root?["data"] as? [String:Any]
            let page=(data?["tree"] as? [String:Any]).flatMap {selectedPage($0)}
            return ScreenObservation(excerpt:summarize(output),pageTitle:page?["name"] as? String,pageBounds:page.flatMap {rect($0)})
        } catch {return ScreenObservation(excerpt:"Could not read this window: \(error.localizedDescription)",pageTitle:nil,pageBounds:nil)}
    }
    private static func rect(_ node:[String:Any])->CGRect? {
        guard let b=node["bounds"] as? [String:Any],let x=b["x"] as? Double,let y=b["y"] as? Double,
              let w=b["width"] as? Double,let h=b["height"] as? Double else {return nil}
        return CGRect(x:x,y:y,width:w,height:h)
    }
    private static func allowed(_ node:[String:Any],viewport:CGRect?)->Bool {
        let role=(node["role"] as? String ?? "").lowercased()
        guard !role.contains("secure"),node["protected"] as? Bool != true else {return false}
        if role=="webarea",let bounds=rect(node) {
            guard bounds.width>1,bounds.height>1 else {return false}
            if let viewport,!viewport.intersects(bounds) {return false}
        }
        return true
    }
    private static func selectedPage(_ tree:[String:Any])->[String:Any]? {
        let viewport=rect(tree)
        var pages:[(Int,[String:Any])]=[]
        func find(_ node:[String:Any],_ depth:Int) {
            guard allowed(node,viewport:viewport) else {return}
            if node["role"] as? String=="webarea" {pages.append((depth,node))}
            for child in node["children"] as? [[String:Any]] ?? [] {find(child,depth+1)}
        }
        find(tree,0)
        return pages.sorted(by:{$0.0>$1.0}).first?.1
    }
    static func summarize(_ output:Data)->String {
        guard let root=try? JSONSerialization.jsonObject(with:output) as? [String:Any] else {return "Screen read did not return usable content."}
        guard root["ok"] as? Bool==true,let data=root["data"] as? [String:Any] else {
            let error=root["error"] as? [String:Any] ?? [:]
            return "Screen unavailable: \(error["code"] ?? "unknown"). \(error["message"] ?? "Allow Rove Accessibility access in System Settings.")"
        }
        var lines:[String]=[],seen=Set<String>(),remaining=5000
        if let window=data["window"] as? [String:Any],let title=window["title"] as? String {lines.append("Window: \(title)")}
        let tree=data["tree"] as? [String:Any] ?? [:],viewport=rect(data["tree"] as? [String:Any] ?? [:])
        func walk(_ node:[String:Any]) {
            guard remaining>0,allowed(node,viewport:viewport) else {return}
            let role=node["role"] as? String ?? ""
            let value=role=="heading" ? nil : node["value"]
            var partsSeen=Set<String>()
            let parts=[node["name"],value,node["description"]].compactMap {$0 as? String}.filter {!$0.isEmpty && partsSeen.insert($0).inserted}
            let text=parts.joined(separator:" · ")
            if !text.isEmpty,seen.insert(text).inserted {
                let line=String("\(role): \(text)".prefix(min(500,remaining)))
                lines.append(line);remaining-=line.count
            }
            for child in node["children"] as? [[String:Any]] ?? [] {walk(child)}
        }
        func readRole(_ node:[String:Any],_ role:String) {
            guard allowed(node,viewport:viewport) else {return}
            if node["role"] as? String==role {walk(node);return}
            for child in node["children"] as? [[String:Any]] ?? [] {readRole(child,role)}
        }
        if let page=selectedPage(tree) {
            if let title=page["name"] as? String,!title.isEmpty,seen.insert(title).inserted {
                let line=String("webarea: \(title)".prefix(min(500,remaining)))
                lines.append(line);remaining-=line.count
            }
            readRole(page,"article");readRole(page,"main");walk(page)
        } else {
            readRole(tree,"main");walk(tree)
        }
        if lines.isEmpty {return "The window exposed no readable text. Do not guess its contents."}
        if data["complete"] as? Bool==false || remaining<=0 {lines.append("Partial window excerpt; more content may exist.")}
        return lines.joined(separator:"\n")
    }
}

struct ScreenObservation {
    let excerpt:String
    let pageTitle:String?
    let pageBounds:CGRect?
}
