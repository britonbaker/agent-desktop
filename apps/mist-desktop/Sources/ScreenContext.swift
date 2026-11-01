import Foundation

struct ScreenContext {
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
            let content = parts.joined(separator: " · ")
            if !content.isEmpty && seen.insert(content).inserted {
                let line = String("\(role): \(content)".prefix(min(500, remaining)))
                lines.append(line); remaining -= line.count
            }
            for child in node["children"] as? [[String: Any]] ?? [] { walk(child) }
        }
        if let tree = data["tree"] as? [String: Any] { walk(tree) }
        if lines.isEmpty { return "The window exposed no readable text. Do not guess its contents." }
        if data["complete"] as? Bool == false || remaining <= 0 { lines.append("Partial window excerpt; more content may exist.") }
        return lines.joined(separator: "\n")
    }
}
