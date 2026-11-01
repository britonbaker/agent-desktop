import Foundation

struct ScreenContext {
    static func isScreenRequest(_ text:String) -> Bool {
        let words=Set(text.lowercased().split { !$0.isLetter }.map(String.init))
        return !words.isDisjoint(with:["screen","page","window","looking","this","here","website","front","visible","selected","selection"])
    }
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
    static func describe(app: String) async -> String {
        await Task.detached(priority: .userInitiated) {
            let binary: URL
            do {
                let tools = URL.applicationSupportDirectory.appendingPathComponent("Rove/Tools",isDirectory:true)
                try FileManager.default.createDirectory(at:tools,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
                for name in ["agent-desktop","agent-desktop-macos-helper"] {
                    guard let source = Bundle.main.url(forResource:name,withExtension:nil) else { return "Screen reader is missing from the app bundle." }
                    let target = tools.appendingPathComponent(name), bytes = try Data(contentsOf:source)
                    if (try? Data(contentsOf:target)) != bytes { try bytes.write(to:target,options:.atomic) }
                    try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:target.path)
                }
                binary = tools.appendingPathComponent("agent-desktop")
            } catch { return "Could not read this window: reader installation failed." }
            let process = Process(), pipe = Pipe()
            process.executableURL = binary
            process.arguments = ["snapshot", "--app", app, "--compact", "--max-depth", "18", "--timeout-ms", "10000"]
            process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 12) { if process.isRunning { process.terminate() } }
                let output = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let summary = summarize(output)
                if process.terminationStatus != 0 || summary.hasPrefix("Screen read") {
                    let directory = URL.applicationSupportDirectory.appendingPathComponent("Rove", isDirectory:true)
                    try? FileManager.default.createDirectory(at:directory, withIntermediateDirectories:true)
                    try? summary.write(to:directory.appendingPathComponent("last-screen-error.txt"), atomically:true, encoding:.utf8)
                }
                return summary
            } catch { return "Could not read this window: \(error.localizedDescription)" }
        }.value
    }
    static func summarize(_ output: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: output) as? [String: Any] else { return "Screen read did not return usable content." }
        guard root["ok"] as? Bool == true, let data = root["data"] as? [String: Any] else {
            let error = root["error"] as? [String: Any] ?? [:]
            return "Screen unavailable: \(error["code"] ?? "unknown"). \(error["message"] ?? "Allow Rove Accessibility access in System Settings.")"
        }
        var lines: [String] = [], seen = Set<String>(), remaining = 5000
        if let window = data["window"] as? [String: Any], let title = window["title"] as? String { lines.append("Window: \(title)") }
        func walk(_ node: [String: Any]) {
            guard remaining > 0 else { return }
            let role = node["role"] as? String ?? ""
            guard !role.lowercased().contains("secure"), node["protected"] as? Bool != true else { return }
            let parts = [node["name"], node["value"], node["description"]].compactMap { $0 as? String }.filter { !$0.isEmpty }
            var partSet=Set<String>()
            let content = parts.filter {partSet.insert($0).inserted}.joined(separator: " · ")
            if !content.isEmpty && seen.insert(content).inserted {
                let line = String("\(role): \(content)".prefix(min(500, remaining)))
                lines.append(line); remaining -= line.count
            }
            for child in node["children"] as? [[String: Any]] ?? [] { walk(child) }
        }
        if let tree = data["tree"] as? [String: Any] {
            // Browser chrome and host sidebars must not consume the page budget.
            // Embedded pages are often deeper than the surrounding chat interface.
            var pages:[(Int,[String:Any])]=[], mains:[[String:Any]]=[]
            func findContent(_ node:[String:Any],_ depth:Int) {
                let role=(node["role"] as? String ?? "").lowercased()
                guard !role.contains("secure"),node["protected"] as? Bool != true else {return}
                if role=="webarea" {pages.append((depth,node))}
                if role=="main" || role=="article" {mains.append(node)}
                for child in node["children"] as? [[String:Any]] ?? [] {findContent(child,depth+1)}
            }
            findContent(tree,0)
            if !pages.isEmpty {
                for (_,page) in pages.sorted(by:{$0.0>$1.0}) {
                    func readMain(_ node:[String:Any]) {
                        let role=(node["role"] as? String ?? "").lowercased()
                        guard !role.contains("secure"),node["protected"] as? Bool != true else {return}
                        if role=="main" || role=="article" {walk(node);return}
                        for child in node["children"] as? [[String:Any]] ?? [] {readMain(child)}
                    }
                    readMain(page);walk(page)
                }
            } else if !mains.isEmpty {for main in mains {walk(main)}}
            else {walk(tree)}
        }
        if lines.isEmpty { return "The window exposed no readable text. Do not guess its contents." }
        if data["complete"] as? Bool == false || remaining <= 0 { lines.append("Partial window excerpt; more content may exist.") }
        return lines.joined(separator: "\n")
    }
}
