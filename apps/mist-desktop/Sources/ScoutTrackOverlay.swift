import AppKit
import ImageIO

private final class TrackCanvas:NSView {
    var marks:[TireTrackMark]=[]
    var images:[CGImage]=[]
    var desktopOrigin=CGPoint.zero
    var now=0.0
    override var isOpaque:Bool {false}
    override func draw(_ dirtyRect:NSRect) {
        guard let context=NSGraphicsContext.current?.cgContext else {return}
        context.clear(bounds);context.interpolationQuality = .high
        for mark in marks {
            context.saveGState()
            context.translateBy(x:mark.position.x-desktopOrigin.x,y:mark.position.y-desktopOrigin.y)
            context.rotate(by:-mark.heading)
            context.setAlpha(mark.opacity(at:now))
            let width=0.306*mark.scale,height=(2 * Double.pi * 0.295/24)*mark.scale
            context.draw(images[mark.rear ? 1 : 0],in:CGRect(x:-width/2,y:-height/2,width:width,height:height))
            context.restoreGState()
        }
    }
}

/// A small, click-through receiver below Rove's window, including its shadow.
final class ScoutTrackOverlay {
    private let panel:NSPanel
    private let canvas=TrackCanvas()
    private var trail=TireTrackTrail()
    private var timer:Timer?
    private weak var roverWindow:NSWindow?
    private var orderedWindow:Int?
    init(images:[CGImage]) {
        canvas.images=images
        panel=NSPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title="Rove tire tracks";panel.isReleasedWhenClosed=false
        panel.level = .floating;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false
        panel.ignoresMouseEvents=true;panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        panel.contentView=canvas
    }
    func update(position:CGPoint,heading:Double,scale:Double,frontContact:Bool,grounded:Bool,window:NSWindow) {
        roverWindow=window
        trail.update(position:position,heading:heading,scale:scale,time:ProcessInfo.processInfo.systemUptime,frontContact:frontContact,grounded:grounded)
        if !trail.marks.isEmpty,timer==nil {
            let clock=Timer(timeInterval:1/30,repeats:true) { [weak self] _ in self?.refresh() }
            timer=clock;RunLoop.main.add(clock,forMode:.common)
            refresh()
        }
    }
    func clear() {trail.clear();timer?.invalidate();timer=nil;panel.orderOut(nil)}
    private func refresh() {
        let now=ProcessInfo.processInfo.systemUptime;trail.expire(at:now)
        guard let window=roverWindow,window.isVisible else {clear();return}
        guard !trail.marks.isEmpty else {timer?.invalidate();timer=nil;panel.orderOut(nil);return}
        var rectangle=CGRect.null
        for mark in trail.marks {
            let radius=mark.scale*0.2+3
            rectangle=rectangle.union(CGRect(x:mark.position.x-radius,y:mark.position.y-radius,width:radius*2,height:radius*2))
        }
        rectangle=rectangle.integral
        if panel.frame != rectangle {panel.setFrame(rectangle,display:false)}
        canvas.desktopOrigin=rectangle.origin;canvas.marks=trail.marks;canvas.now=now;canvas.needsDisplay=true
        if !panel.isVisible || orderedWindow != window.windowNumber {panel.order(.below,relativeTo:window.windowNumber);orderedWindow=window.windowNumber}
    }
    static func writeProof(images:[CGImage],roverPNG:URL,directory:String) throws {
        let url=URL(fileURLWithPath:directory).appendingPathComponent("desktop-tracks.gif")
        guard let source=CGImageSourceCreateWithURL(roverPNG as CFURL,nil),let rover=CGImageSourceCreateImageAtIndex(source,0,nil),let output=CGImageDestinationCreateWithURL(url as CFURL,"com.compuserve.gif" as CFString,41,nil) else {throw NSError(domain:"TrackProof",code:1)}
        CGImageDestinationSetProperties(output,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        let canvas=TrackCanvas(frame:CGRect(x:0,y:0,width:600,height:760));canvas.images=images
        var trail=TireTrackTrail()
        for index in 0...40 {
            let time=Double(index)/20,position=CGPoint(x:300,y:460-min(1,time/0.7)*95)
            trail.update(position:position,heading:Double.pi,scale:55,time:time)
            guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:600,pixelsHigh:760,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:2400,bitsPerPixel:32),let graphics=NSGraphicsContext(bitmapImageRep:bitmap) else {throw NSError(domain:"TrackProof",code:2)}
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=graphics
            canvas.marks=trail.marks;canvas.now=time;canvas.draw(canvas.bounds)
            let context=graphics.cgContext
            context.setBlendMode(.destinationOver);context.setFillColor(NSColor.white.cgColor);context.fill(canvas.bounds)
            context.setBlendMode(.normal)
            // This is the same drawing order as the two live windows: tracks, then Rove and shadow.
            context.draw(rover,in:CGRect(x:position.x-150,y:position.y-200,width:300,height:380))
            NSGraphicsContext.restoreGraphicsState()
            guard let frame=bitmap.cgImage else {throw NSError(domain:"TrackProof",code:3)}
            CGImageDestinationAddImage(output,frame,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.05]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(output) else {throw NSError(domain:"TrackProof",code:4)}
        print("Wrote desktop-anchored track and shadow proof:",url.path)
    }
    deinit {timer?.invalidate();panel.close()}
}
