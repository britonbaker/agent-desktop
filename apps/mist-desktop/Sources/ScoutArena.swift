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
    private var cachedRegions:[ScoutDesktopArena.Region]=[]
    private var cachedDesktop=ScoutDesktopArena(regions:[])
    func desktop()->ScoutDesktopArena {
        let regions=NSScreen.screens.map {ScoutDesktopArena.Region(id:Self.id($0),frame:$0.frame,area:area(for:$0),settings:settings(for:$0))}
        if regions != cachedRegions {cachedRegions=regions;cachedDesktop=ScoutDesktopArena(regions:regions)}
        return cachedDesktop
    }
    func screen(at center:CGPoint,fallback:NSScreen?=nil)->NSScreen? {
        NSScreen.screens.first {$0.frame.contains(center)} ?? fallback ?? NSScreen.main
    }
    /// Blend physical scale and parallax over the seam instead of resizing in one frame.
    func camera(at center:CGPoint,viewingDistance:Double,hingeDelta:Double)->(scale:Double,eye:SIMD3<Float>)? {
        let screens=NSScreen.screens,desktop=desktop()
        func camera(_ screen:NSScreen)->ScoutCamera {
            let physical=CGDisplayScreenSize(Self.id(screen)),frame=screen.frame
            let mm=physical.width>0 ? physical.width/frame.width : 25.4/110
            return ScoutCamera(millimetersPerPoint:mm,screenSize:frame.size,roverCenter:CGPoint(x:center.x-frame.minX,y:center.y-frame.minY),viewingDistance:viewingDistance,hingeDelta:CGDisplayIsBuiltin(Self.id(screen)) != 0 ? hingeDelta : 0)
        }
        for door in desktop.portals(margin:0) {
            let delta=CGPoint(x:center.x-door.center.x,y:center.y-door.center.y)
            let along=delta.x*door.direction.x+delta.y*door.direction.y
            let across=abs(delta.x*door.direction.y-delta.y*door.direction.x)
            guard abs(along)<120,across<door.span/2,
                  let first=screens.first(where:{Self.id($0)==desktop.regions[door.from].id}),
                  let second=screens.first(where:{Self.id($0)==desktop.regions[door.to].id}) else {continue}
            let a=camera(first),b=camera(second),t=ScoutGreeting.smooth((along+120)/240)
            return (a.pointsPerUnit*(1-t)+b.pointsPerUnit*t,a.eye*Float(1-t)+b.eye*Float(t))
        }
        guard let screen=screen(at:center) else {return nil};let value=camera(screen)
        return (value.pointsPerUnit,value.eye)
    }
    func area(for screen:NSScreen)->CGRect {
        let s=settings(for:screen)
        return s.area(in:s.fullDisplay ? screen.frame : screen.visibleFrame)
    }
}
