import AppKit

private final class ArenaOverlayPanel:NSPanel {
    override func constrainFrameRect(_ rect:NSRect,to screen:NSScreen?)->NSRect {rect}
}
private final class ArenaCanvas:NSView {
    var screenFrame=CGRect.zero,visible=CGRect.zero,arena=CGRect.zero
    var settings=ScoutWall.Settings(),scale=55.0
    var rover:(CGPoint,Double)?
    override var isOpaque:Bool {false}
    private func local(_ rect:CGRect)->CGRect {rect.offsetBy(dx:-screenFrame.minX,dy:-screenFrame.minY)}
    private func stroke(_ rect:CGRect,_ color:NSColor,_ width:CGFloat=1,_ dashed:Bool=false) {
        let path=NSBezierPath(rect:local(rect));path.lineWidth=width
        if dashed {path.setLineDash([5,5],count:2,phase:0)}
        color.setStroke();path.stroke()
    }
    override func draw(_ dirtyRect:NSRect) {
        NSGraphicsContext.current?.cgContext.clear(bounds)
        stroke(screenFrame.insetBy(dx:1,dy:1),.white.withAlphaComponent(0.7),2)
        stroke(visible,.systemGreen.withAlphaComponent(0.8),1,true)
        let width=settings.radius*scale
        for i in 0..<12 {
            let outer=arena.insetBy(dx:width*Double(i)/12,dy:width*Double(i)/12)
            let inner=arena.insetBy(dx:width*Double(i+1)/12,dy:width*Double(i+1)/12)
            guard inner.width>0,inner.height>0 else {continue}
            let band=NSBezierPath(rect:local(outer));band.append(NSBezierPath(rect:local(inner)));band.windingRule = .evenOdd
            NSColor.systemCyan.withAlphaComponent(0.025+0.035*Double(12-i)/12).setFill();band.fill()
        }
        stroke(arena,.systemCyan,2)
        stroke(arena.insetBy(dx:width,dy:width),.systemCyan.withAlphaComponent(0.7),1,true)
        for fraction in [0.25,0.5,0.75] {stroke(arena.insetBy(dx:width*fraction,dy:width*fraction),.systemCyan.withAlphaComponent(0.22))}
        if let (center,heading)=rover {
            let extent=ScoutWall.clearance(heading:heading,scale:scale,settings:settings)
            stroke(arena.insetBy(dx:extent.width,dy:extent.height),.systemYellow.withAlphaComponent(0.8),1,true)
            let c=cos(heading),s=sin(heading)
            for x in [-0.74,0.74] {for z in [-0.431,0.431] {
                let point=CGPoint(x:center.x+(c*x+s*z)*scale,y:center.y+(-s*x+c*z)*scale)
                let height=ScoutWall.height(at:point,scale:scale,area:arena,settings:settings)
                (height>0.001 ? NSColor.systemOrange : NSColor.systemGreen).setFill()
                NSBezierPath(ovalIn:CGRect(x:point.x-screenFrame.minX-4,y:point.y-screenFrame.minY-4,width:8,height:8)).fill()
            }}
        }
    }
}
private final class ArenaProfile:NSView {
    var settings=ScoutWall.Settings(),scale=55.0
    override func draw(_ rect:NSRect) {
        NSColor.controlBackgroundColor.setFill();NSBezierPath(roundedRect:bounds,xRadius:8,yRadius:8).fill()
        let width=settings.radius*scale,range=3.5*scale,maximum=range*1.6
        let path=NSBezierPath();path.move(to:CGPoint(x:14,y:16))
        for i in 0...100 {
            let t=Double(i)/100,distance=width*(1-t)
            let height=ScoutWall.height(at:CGPoint(x:distance,y:5000),scale:scale,area:CGRect(x:0,y:0,width:10000,height:10000),settings:settings)*scale
            path.line(to:CGPoint(x:bounds.width-14-distance/range*(bounds.width-28),y:16+height/max(1,maximum)*(bounds.height-38)))
        }
        NSColor.systemCyan.setStroke();path.lineWidth=2;path.stroke()
        let label="Floor → curved bezel  ·  \(Int(width)) pt wide"
        (label as NSString).draw(at:CGPoint(x:14,y:bounds.height-21),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.secondaryLabelColor])
    }
}

/// Click-through calibration on one display; its inspector is the only interactive surface.
final class ScoutArenaDebug:NSObject,NSWindowDelegate {
    private let displayID:UInt32
    private let inspector:NSPanel
    private let overlay:ArenaOverlayPanel
    private let canvas=ArenaCanvas(),profile=ArenaProfile()
    private var sliders:[String:NSSlider]=[:],values:[String:NSTextField]=[:]
    private let fullDisplay=NSButton(checkboxWithTitle:"Include the menu bar and Dock area",target:nil,action:nil)
    private let readout=NSTextField(labelWithString:"")
    private var instructions:NSTextField?
    private let pauseButton=NSButton(title:"Pause",target:nil,action:nil)
    private var paused=false,right=false
    private var timer:Timer?
    private var scale=55.0
    var sample:(()->(center:CGPoint,heading:Double,scale:Double)?)?
    var onChange:(()->Void)?,onPreview:((Bool)->Void)?,onPause:((Bool)->Void)?,onClose:(()->Void)?
    init(screen:NSScreen) {
        displayID=ScoutArena.id(screen)
        inspector=NSPanel(contentRect:CGRect(x:0,y:0,width:400,height:650),styleMask:[.titled,.closable,.utilityWindow],backing:.buffered,defer:false)
        overlay=ArenaOverlayPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        super.init()
        inspector.title="Rove — MacBook edge tuning";inspector.isReleasedWhenClosed=false
        inspector.level=NSWindow.Level(rawValue:NSWindow.Level.floating.rawValue+1);inspector.delegate=self
        inspector.hidesOnDeactivate=false;inspector.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        overlay.title="Rove edge debug overlay";overlay.isReleasedWhenClosed=false
        overlay.level = .floating;overlay.isOpaque=false;overlay.backgroundColor = .clear;overlay.hasShadow=false;overlay.ignoresMouseEvents=true
        overlay.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];overlay.contentView=canvas
        let root=NSView(frame:CGRect(x:0,y:0,width:400,height:650));inspector.contentView=root
        func label(_ title:String,_ y:Double,_ size:Double=12)->NSTextField {
            let text=NSTextField(labelWithString:title);text.font=NSFont.systemFont(ofSize:size);text.frame=CGRect(x:20,y:y,width:360,height:36);text.lineBreakMode = .byWordWrapping;text.maximumNumberOfLines=2;root.addSubview(text);return text
        }
        instructions=label("Continuous left-edge loop · sliders apply live\nCyan: curve · Yellow: center · Orange: tires",600)
        fullDisplay.frame=CGRect(x:20,y:565,width:365,height:26);fullDisplay.target=self;fullDisplay.action=#selector(changed(_:));root.addSubview(fullDisplay)
        let rows:[(String,String,Double,Double)]=[("left","Left inset",0,180),("right","Right inset",0,180),("top","Top inset",0,180),("bottom","Bottom inset",0,180),("buffer","Extra wheel room",0.08,0.4),("radius","Curve width",0.6,3.5),("rise","Curve rise",0.4,1.6)]
        for (i,row) in rows.enumerated() {
            let y=520-Double(i)*50
            let name=NSTextField(labelWithString:row.1);name.frame=CGRect(x:20,y:y+10,width:150,height:20);root.addSubview(name)
            let value=NSTextField(labelWithString:"");value.alignment = .right;value.frame=CGRect(x:240,y:y+10,width:135,height:20);root.addSubview(value);values[row.0]=value
            let slider=NSSlider(value:0,minValue:row.2,maxValue:row.3,target:self,action:#selector(changed(_:)))
            slider.identifier=NSUserInterfaceItemIdentifier(row.0);slider.setAccessibilityLabel(row.1);slider.isContinuous=true;slider.frame=CGRect(x:20,y:y-12,width:355,height:24)
            root.addSubview(slider);sliders[row.0]=slider
        }
        profile.frame=CGRect(x:20,y:103,width:360,height:94);root.addSubview(profile)
        readout.frame=CGRect(x:20,y:62,width:360,height:30);readout.font=NSFont.monospacedDigitSystemFont(ofSize:11,weight:.regular);readout.maximumNumberOfLines=2;root.addSubview(readout)
        for (title,action,x) in [("Loop left",#selector(testLeft),20.0),("Loop right",#selector(testRight),112),("Reset",#selector(reset),296)] {
            let button=NSButton(title:title,target:self,action:action);button.frame=CGRect(x:x,y:20,width:84,height:30);button.bezelStyle = .rounded;root.addSubview(button)
        }
        pauseButton.target=self;pauseButton.action=#selector(toggleMotion);pauseButton.frame=CGRect(x:204,y:20,width:84,height:30);pauseButton.bezelStyle = .rounded;root.addSubview(pauseButton)
        let frame=screen.visibleFrame
        inspector.setFrameOrigin(CGPoint(x:frame.maxX-424,y:frame.maxY-700))
        syncControls()
    }
    private var screen:NSScreen? {NSScreen.screens.first {ScoutArena.id($0)==displayID}}
    func show() {
        refresh();overlay.orderFrontRegardless();focus()
        let clock=Timer(timeInterval:1/20,repeats:true) { [weak self] _ in self?.refresh() }
        timer=clock;RunLoop.main.add(clock,forMode:.common)
    }
    func close() {inspector.close()}
    func focus() {
        if let screen {let f=screen.visibleFrame;inspector.setFrameOrigin(CGPoint(x:f.maxX-424,y:f.maxY-700))}
        inspector.orderFrontRegardless();NSApp.activate(ignoringOtherApps:true);inspector.makeKeyAndOrderFront(nil)
    }
    func setMotionPaused(_ value:Bool) {paused=value;pauseButton.title=value ? "Resume" : "Pause";refresh()}
    private func syncControls() {
        guard let screen else {return}
        let s=ScoutArena.shared.settings(for:screen)
        for (key,value) in [("left",s.left),("right",s.right),("top",s.top),("bottom",s.bottom),("buffer",s.buffer),("radius",s.radius),("rise",s.rise)] {sliders[key]?.doubleValue=value}
        fullDisplay.state=s.fullDisplay ? .on : .off
        refresh()
    }
    @objc private func changed(_ sender:Any) {
        guard let screen else {return}
        var s=ScoutWall.Settings()
        s.left=sliders["left"]!.doubleValue;s.right=sliders["right"]!.doubleValue;s.top=sliders["top"]!.doubleValue;s.bottom=sliders["bottom"]!.doubleValue
        s.buffer=sliders["buffer"]!.doubleValue;s.radius=sliders["radius"]!.doubleValue;s.rise=sliders["rise"]!.doubleValue;s.fullDisplay=fullDisplay.state == .on
        ScoutArena.shared.set(s,for:screen);onChange?();refresh()
    }
    @objc private func reset() {guard let screen else {return};ScoutArena.shared.set(ScoutWall.Settings(),for:screen);onChange?();syncControls()}
    @objc private func testLeft() {right=false;setMotionPaused(false);onPreview?(false)}
    @objc private func testRight() {right=true;setMotionPaused(false);onPreview?(true)}
    @objc private func toggleMotion() {setMotionPaused(!paused);onPause?(paused)}
    private func refresh() {
        guard let screen else {inspector.close();return}
        let s=ScoutArena.shared.settings(for:screen),rover=sample?()
        scale=rover?.scale ?? scale
        canvas.screenFrame=screen.frame;canvas.visible=screen.visibleFrame;canvas.arena=ScoutArena.shared.area(for:screen);canvas.settings=s;canvas.scale=scale
        canvas.rover=rover.map {($0.center,$0.heading)};canvas.needsDisplay=true
        if overlay.frame != screen.frame {overlay.setFrame(screen.frame,display:false)}
        profile.settings=s;profile.scale=scale;profile.needsDisplay=true
        for key in ["left","right","top","bottom"] {values[key]?.stringValue="\(Int(sliders[key]?.doubleValue ?? 0)) pt"}
        instructions?.stringValue="\(paused ? "Paused" : "Looping") \(right ? "right" : "left") edge · sliders apply live\nCyan: curve · Yellow: center · Orange: tires"
        values["buffer"]?.stringValue="\(Int(s.buffer*scale)) pt"
        values["radius"]?.stringValue="\(Int(s.radius*scale)) pt";values["rise"]?.stringValue="\(Int(s.rise*100))%"
        if let rover {
            let p=ScoutWall.pose(center:rover.center,heading:rover.heading,scale:scale,area:canvas.arena,settings:s)
            readout.stringValue=String(format:"Pitch %.1f° · Bank %.1f° · Rise %.1f pt\nDisplay %u · %.0f × %.0f pt",p.pitch*180/Double.pi,p.roll*180/Double.pi,p.height*scale,displayID,screen.frame.width,screen.frame.height)
        }
    }
    func windowWillClose(_ notification:Notification) {timer?.invalidate();timer=nil;overlay.orderOut(nil);onClose?()}
    deinit {timer?.invalidate();overlay.close()}
}
