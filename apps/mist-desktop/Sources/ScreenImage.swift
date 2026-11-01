import AppKit
import ScreenCaptureKit
import ApplicationServices

struct FrontWindow {
    let id:CGWindowID
    let title:String
    let bounds:CGRect
    var desktopFrame:CGRect {CGRect(x:bounds.minX,y:(NSScreen.screens.first?.frame.maxY ?? 0)-bounds.maxY,width:bounds.width,height:bounds.height)}
    static func underlyingApp() -> NSRunningApplication? {
        let windows=CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]] ?? []
        for window in windows {
            guard (window[kCGWindowLayer as String] as? NSNumber)?.intValue==0,
                  let pid=(window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let app=NSRunningApplication(processIdentifier:pid),app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  app.activationPolicy == .regular else {continue}
            return app
        }
        return nil
    }
    static func find(pid:pid_t) -> FrontWindow? {
        let windows=CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]] ?? []
        let candidates=windows.filter {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==pid &&
            ($0[kCGWindowLayer as String] as? NSNumber)?.intValue==0
        }
        // Prefer the accessibility-focused window, so a browser utility overlay cannot steal capture.
        let application=AXUIElementCreateApplication(pid)
        var focusedValue:CFTypeRef?
        var focusedBounds:CGRect?
        if AXUIElementCopyAttributeValue(application,kAXFocusedWindowAttribute as CFString,&focusedValue) == .success,
           let focusedValue,CFGetTypeID(focusedValue)==AXUIElementGetTypeID() {
            let focused=focusedValue as! AXUIElement
            var positionValue:CFTypeRef?,sizeValue:CFTypeRef?
            if AXUIElementCopyAttributeValue(focused,kAXPositionAttribute as CFString,&positionValue) == .success,
               AXUIElementCopyAttributeValue(focused,kAXSizeAttribute as CFString,&sizeValue) == .success,
               let positionValue,let sizeValue,CFGetTypeID(positionValue)==AXValueGetTypeID(),CFGetTypeID(sizeValue)==AXValueGetTypeID() {
                var point=CGPoint.zero,size=CGSize.zero
                if AXValueGetValue(positionValue as! AXValue,.cgPoint,&point),AXValueGetValue(sizeValue as! AXValue,.cgSize,&size) {
                    focusedBounds=CGRect(origin:point,size:size)
                }
            }
        }
        func bounds(_ window:[String:Any]) -> CGRect? {
            guard let value=window[kCGWindowBounds as String] as? [String:Any] else {return nil}
            return CGRect(dictionaryRepresentation:value as CFDictionary)
        }
        let exact=focusedBounds.flatMap { focused in candidates.first {window in
            guard let rect=bounds(window) else {return false}
            return abs(rect.minX-focused.minX)<3 && abs(rect.minY-focused.minY)<3 && abs(rect.width-focused.width)<3 && abs(rect.height-focused.height)<3
        }}
        let chosen=exact ?? candidates.first {window in
            guard let rect=bounds(window) else {return false}
            return rect.width>=320 && rect.height>=180
        }
        if let window=chosen,let id=window[kCGWindowNumber as String] as? NSNumber,let rect=bounds(window) {
            return FrontWindow(id:id.uint32Value,title:window[kCGWindowName as String] as? String ?? "Front window",bounds:rect)
        }
        return nil
    }
}
struct ScreenImage {
    static var permitted:Bool {CGPreflightScreenCaptureAccess()}
    @MainActor static func capture(window:CGWindowID,pageBounds:CGRect? = nil) async throws -> Data {
        guard permitted else {throw NSError(domain:"RoveScreenPermission",code:1)}
        let content=try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly:true)
        guard let target=content.windows.first(where:{$0.windowID==window}) else {throw NSError(domain:"RoveScreenWindow",code:1)}
        let filter=SCContentFilter(desktopIndependentWindow:target)
        let config=SCStreamConfiguration()
        let scale=min(1.0,1600/max(1,target.frame.width),1200/max(1,target.frame.height))
        config.width=max(1,Int(target.frame.width*scale));config.height=max(1,Int(target.frame.height*scale))
        config.showsCursor=false;config.capturesAudio=false;config.ignoreShadowsSingleWindow=true
        var image=try await SCScreenshotManager.captureImage(contentFilter:filter,configuration:config)
        if let pageBounds {
            let intersection=pageBounds.intersection(target.frame)
            if intersection.width>64,intersection.height>64 {
                let sx=Double(image.width)/target.frame.width,sy=Double(image.height)/target.frame.height
                let crop=CGRect(x:(intersection.minX-target.frame.minX)*sx,y:(intersection.minY-target.frame.minY)*sy,width:intersection.width*sx,height:intersection.height*sy)
                if let cropped=image.cropping(to:crop.integral) {image=cropped}
            }
        }
        guard let data=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]) else {throw NSError(domain:"RoveScreenPNG",code:1)}
        return data
    }
}
