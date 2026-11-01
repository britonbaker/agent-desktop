import Foundation

private final class ToolProcess: @unchecked Sendable {
    private let lock=NSLock()
    private var process:Process?
    private var cancelled=false
    func attach(_ value:Process) throws {
        lock.lock();defer {lock.unlock()}
        if cancelled {throw CancellationError()}
        process=value;try value.run()
    }
    func cancel() {
        lock.lock();defer {lock.unlock()};cancelled=true
        if let process,process.isRunning {process.terminate()}
    }
}

/// Structured arguments only. The private ref store never shares another agent's snapshots.
@MainActor final class DesktopToolBridge {
    private var executable:URL?
    private let state=FileManager.default.temporaryDirectory.appendingPathComponent("RoveActions-"+UUID().uuidString)
    func clearState() {
        try? FileManager.default.removeItem(at:state)
        try? FileManager.default.createDirectory(at:state,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
    }
    private func prepare() throws -> URL {
        if let executable {return executable}
        let tools=URL.applicationSupportDirectory.appendingPathComponent("Rove/Tools")
        try FileManager.default.createDirectory(at:tools,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        try FileManager.default.createDirectory(at:state,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        for name in ["agent-desktop","agent-desktop-macos-helper"] {
            guard let source=Bundle.main.url(forResource:name,withExtension:nil) else {throw NSError(domain:"DesktopTools",code:1)}
            let destination=tools.appendingPathComponent(name),bytes=try Data(contentsOf:source)
            if (try? Data(contentsOf:destination)) != bytes {try bytes.write(to:destination,options:.atomic)}
            try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:destination.path)
        }
        let result=tools.appendingPathComponent("agent-desktop");executable=result;return result
    }
    func call(_ arguments:[String],authorized: @escaping @MainActor ()->Bool) async throws -> [String:Any] {
        guard authorized(),!Task.isCancelled else {throw CancellationError()}
        let tool=try prepare(),home=state.path,control=ToolProcess()
        let output=try await withTaskCancellationHandler {
            try await Task.detached(priority:.userInitiated) { () throws -> Data in
                let process=Process(),pipe=Pipe()
                process.executableURL=tool;process.arguments=arguments
                var environment=ProcessInfo.processInfo.environment;environment["AGENT_DESKTOP_HOME"]=home
                process.environment=environment;process.standardOutput=pipe;process.standardError=FileHandle.nullDevice
                try control.attach(process)
                DispatchQueue.global().asyncAfter(deadline:.now()+14) {control.cancel()}
                var data=Data()
                while let part=try pipe.fileHandleForReading.read(upToCount:65536),!part.isEmpty {
                    data.append(part)
                    if data.count>2_000_000 {control.cancel();throw NSError(domain:"DesktopTools",code:2)}
                }
                process.waitUntilExit();return data
            }.value
        } onCancel: {control.cancel()}
        guard authorized(),!Task.isCancelled else {throw CancellationError()}
        guard let result=try JSONSerialization.jsonObject(with:output) as? [String:Any] else {throw NSError(domain:"DesktopTools",code:3)}
        return result
    }
    deinit {try? FileManager.default.removeItem(at:state)}
}
