import AppKit
import ApplicationServices

/// Read the real Dock tile. An absent or hidden tile has no guessed destination.
enum DockDestination {
    static func anchor(for app:DesktopApp) -> (point:CGPoint,source:String)? {
        if let icon=bounds(for:app) {return (CGPoint(x:icon.midX,y:icon.midY),"Dock tile")}
        if let window=FrontWindow.find(pid:app.pid)?.desktopFrame {return (CGPoint(x:window.minX+115,y:window.maxY-120),"window")}
        return nil
    }
    static func bounds(for app:DesktopApp) -> CGRect? {
        guard AXIsProcessTrusted(),let dock=NSWorkspace.shared.runningApplications.first(where:{$0.bundleIdentifier=="com.apple.dock"}) else {return nil}
        let root=AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(root,0.05)
        var queue=[root],seen=0
        let began=Date()
        func value(_ element:AXUIElement,_ name:String)->CFTypeRef? {
            var result:CFTypeRef?;guard AXUIElementCopyAttributeValue(element,name as CFString,&result) == .success else {return nil};return result
        }
        while !queue.isEmpty && seen<160 && Date().timeIntervalSince(began)<0.45 {
            let element=queue.removeFirst();seen+=1
            AXUIElementSetMessagingTimeout(element,0.05)
            let role=value(element,kAXRoleAttribute) as? String
            if role=="AXDockItem" {
                let title=value(element,kAXTitleAttribute) as? String
                let url=value(element,kAXURLAttribute) as? URL
                let bundleID=url.flatMap {Bundle(url:$0)?.bundleIdentifier}
                if bundleID==app.id || (bundleID==nil && title==app.name) {
                    guard let p=value(element,kAXPositionAttribute),let s=value(element,kAXSizeAttribute),CFGetTypeID(p)==AXValueGetTypeID(),CFGetTypeID(s)==AXValueGetTypeID() else {return nil}
                    var point=CGPoint.zero,size=CGSize.zero
                    guard AXValueGetValue(p as! AXValue,.cgPoint,&point),AXValueGetValue(s as! AXValue,.cgSize,&size),size.width>0,size.height>0 else {return nil}
                    let top=NSScreen.screens.first?.frame.maxY ?? 0
                    let rect=CGRect(x:point.x,y:top-point.y-size.height,width:size.width,height:size.height)
                    return NSScreen.screens.contains(where:{$0.frame.intersects(rect)}) ? rect : nil
                }
            }
            if let children=value(element,kAXChildrenAttribute) as? [AXUIElement] {queue.append(contentsOf:children)}
        }
        return nil
    }
}
