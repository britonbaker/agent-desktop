import AppKit

/// Only window bounds and stacking order are used; no titles, screenshots or AX text.
final class ScoutDesktopSurfaces {
    private var refreshed = -Double.infinity
    private var rects:[CGRect]=[]
    private var ownPID=ProcessInfo.processInfo.processIdentifier
    func sample(display:CGRect,now:Double)->ScoutWindowSteps {
        if now-refreshed>0.25 {
            refreshed=now
            let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
            let desktopTop=NSScreen.screens.first?.frame.maxY ?? 0
            rects=rows.prefix(128).compactMap {row in
                guard (row[kCGWindowLayer as String] as? NSNumber)?.intValue==0,
                      (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value != ownPID,
                      (row[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1 > 0.1,
                      let raw=row[kCGWindowBounds as String] as? [String:Any],
                      let r=CGRect(dictionaryRepresentation:raw as CFDictionary),r.width>=160,r.height>=100 else {return nil}
                return CGRect(x:r.minX,y:desktopTop-r.maxY,width:r.width,height:r.height)
            }
        }
        // Keep the same deck heights as Scout crosses a large window. A moving
        // local crop would make lower layers disappear and drop the chassis.
        return ScoutWindowSteps(frontToBack:rects.filter {$0.intersects(display)})
    }
}
