import AppKit

/// One calibrated rectangle and curve per physical display, shared by drive and renderer.
final class ScoutArena {
    static let shared=ScoutArena()
    private var cache:[UInt32:ScoutWall.Settings]=[:]
    static func id(_ screen:NSScreen)->UInt32 {(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0}
    func settings(for screen:NSScreen)->ScoutWall.Settings {
        let id=Self.id(screen)
        if let value=cache[id] {return value}
        let value=UserDefaults.standard.data(forKey:"roveArena.\(id)").flatMap {try? JSONDecoder().decode(ScoutWall.Settings.self,from:$0)}?.sanitized() ?? ScoutWall.Settings()
        cache[id]=value;return value
    }
    func set(_ value:ScoutWall.Settings,for screen:NSScreen) {
        let id=Self.id(screen),clean=value.sanitized();cache[id]=clean
        if let data=try? JSONEncoder().encode(clean) {UserDefaults.standard.set(data,forKey:"roveArena.\(id)")}
    }
    func area(for screen:NSScreen)->CGRect {
        let s=settings(for:screen)
        return s.area(in:s.fullDisplay ? screen.frame : screen.visibleFrame)
    }
}
