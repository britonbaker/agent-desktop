import AppKit
import WebKit
import Speech
import AVFoundation
import FoundationModels
import ApplicationServices

@main
struct RoveMain {
    static func main() {
        if let index=CommandLine.arguments.firstIndex(of:"--actions-self-test"),CommandLine.arguments.count>index+1 {
            setbuf(stdout,nil)
            Task { @MainActor in do {try await runDesktopActionsTests(statePath:CommandLine.arguments[index+1]);exit(0)} catch {print("FAIL:",error);exit(1)}}
            RunLoop.main.run();return
        }
        if let index=CommandLine.arguments.firstIndex(of:"--app-catalog-test"),CommandLine.arguments.count>index+1 {
            let name=CommandLine.arguments[index+1]
            let matches=DesktopAgent.availableApps().filter {$0.name.localizedCaseInsensitiveCompare(name) == .orderedSame}
            for app in matches {print(app.name,app.id,"PID",app.pid,app.bundleURL?.path ?? "running")}
            exit(matches.count==1 ? 0 : 1)
        }
        if let index=CommandLine.arguments.firstIndex(of:"--character-voice-previews"),CommandLine.arguments.count>index+1 {
            Task {do {try await writeCharacterVoicePreviews(directory:CommandLine.arguments[index+1]);exit(0)} catch {print("Voice previews failed:",error);exit(1)}}
            RunLoop.main.run();return
        }
        if let index=CommandLine.arguments.firstIndex(of:"--app-destination-test"),CommandLine.arguments.count>index+1 {
            let id=CommandLine.arguments[index+1]
            if let app=DesktopAgent.runningApps().first(where:{$0.id==id}),let target=DockDestination.anchor(for:app) {print("Destination:",app.name,target.source,target.point);exit(0)}
            print("No readable Dock tile or window for",id);exit(1)
        }
        if let index=CommandLine.arguments.firstIndex(of:"--voice-audition"),CommandLine.arguments.count>index+1 {
            Task {do {try await writeVoiceAudition(to:CommandLine.arguments[index+1]);exit(0)} catch {print("Voice audition failed:",error);exit(1)}}
            RunLoop.main.run();return
        }
        if CommandLine.arguments.contains("--vision-front-test") {
            setbuf(stdout,nil)
            Task { @MainActor in
                do {
                    let active=NSWorkspace.shared.frontmostApplication
                    let app=active?.bundleIdentifier == Bundle.main.bundleIdentifier ? FrontWindow.underlyingApp() : active
                    guard let app,let window=FrontWindow.find(pid:app.processIdentifier) else {throw NSError(domain:"RoveFrontTest",code:1)}
                    let observation=await ScreenContext.observe(app:app.localizedName ?? "Unknown",windowID:window.id)
                    let image=try await ScreenImage.capture(window:window.id)
                    if let index=CommandLine.arguments.firstIndex(of:"--save-test-image"),CommandLine.arguments.count>index+1 {
                        try image.write(to:URL(fileURLWithPath:CommandLine.arguments[index+1]))
                    }
                    let source=observation.source(app:app.localizedName ?? "Unknown",fallbackTitle:window.title)
                    print("CAPTURE SOURCE:",source,"IMAGE BYTES:",image.count)
                    let started=Date()
                    print("VISION ANSWER:",try await LocalVision.shared.explain(question:"What am I looking at? Explain the main page and what it is for.",excerpt:observation.excerpt,image:image,source:source))
                    print("ELAPSED:",Date().timeIntervalSince(started));await LocalVision.shared.stop();exit(0)
                } catch {print("FAIL:",error);await LocalVision.shared.stop();exit(1)}
            }
            RunLoop.main.run();return
        }
        if CommandLine.arguments.contains("--screen-permission-check") {
            print(ScreenImage.permitted ? "Screen capture permitted" : "Screen capture permission required");exit(0)
        }
        if CommandLine.arguments.contains("--scout-self-test") {
            do { let renderer=try ScoutRenderer(frame:CGRect(x:0,y:0,width:300,height:380));try renderer.selfTest()
                if let index=CommandLine.arguments.firstIndex(of:"--greeting-preview"),CommandLine.arguments.count>index+1 {try renderer.greetingPreview(directory:CommandLine.arguments[index+1])}
                exit(0) }
            catch { print("FAIL: \(error)");exit(1) }
        }
        if let index=CommandLine.arguments.firstIndex(of:"--vision-image-test"),CommandLine.arguments.count>index+1 {
            setbuf(stdout,nil)
            let path=CommandLine.arguments[index+1]
            Task { @MainActor in
                do {
                    let image=try Data(contentsOf:URL(fileURLWithPath:path))
                    let began=Date()
                    print("Starting offline local vision image test")
                    let answer=try await LocalVision.shared.explain(question:"What am I looking at? Explain the visible activity naturally without inventing hidden content.",excerpt:"",image:image,source:CommandLine.arguments.firstIndex(of:"--source-window").flatMap {CommandLine.arguments.count>$0+1 ? CommandLine.arguments[$0+1] : nil} ?? "Unknown app; describe only visually evident content")
                    print("VISION ANSWER:",answer);print("Elapsed seconds:",Date().timeIntervalSince(began))
                    await LocalVision.shared.stop();exit(0)
                } catch {print("FAIL:",error);await LocalVision.shared.stop();exit(1)}
            }
            RunLoop.main.run();return
        }
        if let index=CommandLine.arguments.firstIndex(of:"--screen-file-test"),CommandLine.arguments.count>index+1 {
            setbuf(stdout,nil)
            let path=CommandLine.arguments[index+1]
            Task { @MainActor in
                do {
                    let data=try Data(contentsOf:URL(fileURLWithPath:path))
                    let excerpt=ScreenContext.summarize(data)
                    print("EXCERPT CHARS:",excerpt.count)
                    print(try await DesktopAgent.explainExcerpt(excerpt,request:"Explain the page I am looking at.",diagnostics:{print($0)}))
                    exit(0)
                } catch {print("FAIL:",error);exit(1)}
            }
            RunLoop.main.run();return
        }
        if CommandLine.arguments.contains("--desktop-self-test") {
            setbuf(stdout,nil)
            Task { @MainActor in
                do {try await runDesktopAgentTests();exit(0)}
                catch {print("FAIL: \(error)");exit(1)}
            }
            RunLoop.main.run();return
        }
        if CommandLine.arguments.contains("--voice-self-test") {
            setbuf(stdout, nil)
            Task { @MainActor in
                do { try await runStreamTests(); exit(0) }
                catch { print("FAIL: \(error)"); exit(1) }
            }
            RunLoop.main.run()
            return
        }
        let app = NSApplication.shared
        let delegate = RoveDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

final class RoveDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    private var panel: NSPanel!
    private var web: WKWebView!
    private var handheld: HandheldRenderer?
    private var scout: ScoutRenderer?
    private var lidMenuItem: NSMenuItem?
    private let audio = LocalConversation()
    private let desktopAgent = DesktopAgent()
    private let motion = MotionSensor()
    private var edgeDebug:ScoutArenaDebug?
    private var edgeLoopTimer:Timer?
    private var edgeLoopPaused=false,edgeLoopRight=false
    private var detector = TapDetector()
    private var generation = 0
    private var responseTask: Task<Void, Never>?
    private let robotSounds=RobotSounds()
    private var cueTask:Task<Void,Never>?
    private var state = "idle"
    private var reply = ""
    private var lastRequest = ""
    private var recentTurns = ""
    private var statusItem: NSStatusItem!
    private var idleTimer: Timer?
    private var permissionsPending = false
    private var conversationActive = false
    private var previousExternalApp = ""
    private var appTimeline=AppTimeline.load()
    private var tossTimer: Timer?
    private var driveTimer: Timer?
    private var ambientTimer: Timer?
    private var greetingTimer:Timer?
    private var greetingRelease:Date?
    private var greetingArrival:Date?
    private var wanderHome=CGPoint.zero
    private var nextWander=Date.distantFuture
    private var isWandering=false
    private var controlCenter=150.0
    private var controlWidth=276.0
    private var scoutTyping=false
    private var scoutNear=false
    private var wanderMenuItem:NSMenuItem?
    private var wanderingEnabled=UserDefaults.standard.object(forKey:"scoutWandering") as? Bool ?? true
    private var rover = RoverDrive(position:.zero)
    private var driveRoute: [CGPoint] = []
    private var companionID = "character"
    private var velocity = NSPoint.zero
    private var lastDrag = Date()
    private var monitor: Any?
    private var globalShiftMonitor:Any?
    private var doubleShift=DoubleShift()
    private var inputEvents=0
    private var shiftEvents=0
    private var shiftActivations=0
    private var shiftTrace:[String]=[]
    private var tapPeaks:[String]=[]
    private var lastMotionSample=0.0
    private var acceptedKnocks=0
    private var dismissedKnocks=0
    private var ready = false
    private var lastExternalApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
    private var lastExternalPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
    private var appObserver: NSObjectProtocol?
    private var lockObserver:NSObjectProtocol?
    private let profileURL = URL.applicationSupportDirectory.appendingPathComponent("Rove/tap-profile.json")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.string(forKey: "companion") == nil, let previous = UserDefaults(suiteName: "local.briton.mistdesktop")?.string(forKey: "companion") {
            UserDefaults.standard.set(previous, forKey: "companion")
        }
        setupMenu()
        Task { _ = try? await PhononModel.shared.get() }
        if VisionConfiguration.installed {Task {try? await LocalVision.shared.prepare()}}
        if let front=NSWorkspace.shared.frontmostApplication {rememberApp(front)}
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] note in
            if let app=note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {self?.rememberApp(app)}
        }
        lockObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.sessionDidResignActiveNotification,object:nil,queue:.main) { [weak self] _ in self?.stop() }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "mist")
        web = WKWebView(frame: .zero, configuration: config)
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = self
        panel = FloatingPanel(contentRect: NSRect(x: 70, y: 180, width: 202, height: 490), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Rove"
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSView(frame:panel.contentView!.bounds)
        web.frame = host.bounds; web.autoresizingMask = [.width,.height]
        host.addSubview(web); panel.contentView = host
        loadCompanion()
        panel.orderFrontRegardless()
        audio.onTurn = { [weak self] text in self?.respond(text) }
        desktopAgent.onSwitch = { [weak self] target,_ in self?.driveScout(to:target) }
        audio.onFailure = { [weak self] message in self?.conversationActive=false;self?.update("error", message) }
        audio.onStatus = { [weak self] message in
            guard let self else { return }
            if message.hasPrefix("Streaming Phonon") { self.update("speaking", self.reply) }
            if message.hasPrefix("Heard:") { self.update("listening", message) }
            if message.contains("unavailable") { self.update("error", message) }
            if self.state == "speaking" && !self.audio.speaking {
                self.update("idle",self.conversationActive ? "Ready for your next question" : "Double-tap to talk")
                let ticket=self.generation
                if self.conversationActive {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for:.milliseconds(350))
                        guard let self,self.generation==ticket,self.conversationActive,self.state=="idle" else {return}
                        self.startListening()
                    }
                }
            }
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown,.flagsChanged]) { [weak self] event in
            self?.keyboardActivation(event)
            if event.type == .keyDown && event.keyCode == 53 { self?.stop(); return nil }; return event
        }
        globalShiftMonitor=NSEvent.addGlobalMonitorForEvents(matching:[.keyDown,.flagsChanged]) { [weak self] event in self?.keyboardActivation(event) }
        enableTaps()
        ambientTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in self?.ambientTick() }
    }
    private func rememberApp(_ app:NSRunningApplication) {
        guard app.activationPolicy == .regular,let id=app.bundleIdentifier,id != Bundle.main.bundleIdentifier,let name=app.localizedName else {return}
        if appTimeline.visits.last?.id != id {previousExternalApp=appTimeline.visits.last?.name ?? "";appTimeline.record(id:id,name:name);appTimeline.save()}
        lastExternalApp=name;lastExternalPID=app.processIdentifier
    }
    private func setupMenu() {
        let menu = NSMenu()
        for (title, action, key) in [("Summon / listen · double Shift", #selector(activateCompanion), "t"), ("Stop listening and speaking", #selector(stop), "."), ("Explain front window", #selector(explainWindow), "e"), ("Show last reply", #selector(showLastReply), "r"), ("Show Rove", #selector(show), ""), ("Quit Rove", #selector(quit), "q")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
        }
        let voices=NSMenuItem(title:"Speaking voice · US English",action:nil,keyEquivalent:"")
        let voiceMenu=NSMenu()
        for name in RoveSpeechVoice.available {
            let item=NSMenuItem(title:name,action:#selector(chooseSpeechVoice(_:)),keyEquivalent:"")
            item.target=self;item.representedObject=name;item.state=name==RoveSpeechVoice.selected ? .on : .off;voiceMenu.addItem(item)
        }
        voices.submenu=voiceMenu;menu.addItem(voices)
        let sounds=NSMenuItem(title:"Robot tap sounds",action:#selector(toggleRobotSounds(_:)),keyEquivalent:"")
        sounds.target=self;sounds.state=RobotSounds.enabled ? .on : .off;menu.addItem(sounds)
        let preview=NSMenuItem(title:"Preview robot tap sound",action:#selector(previewRobotSound),keyEquivalent:"")
        preview.target=self;menu.addItem(preview)
        for (title,action) in [("Screen-edge tuning…",#selector(openArenaDebug)),("Knock diagnostics…",#selector(knockDiagnostics)),("Preview Scout’s edge greeting",#selector(greetScout)),("Drive Scout in a small loop",#selector(driveScoutLoop)),("Park Scout",#selector(pauseWandering))] {
            let item = NSMenuItem(title:title,action:action,keyEquivalent:""); item.target = self; menu.addItem(item)
        }
        let wander=NSMenuItem(title:"Let Scout wander",action:#selector(toggleWandering(_:)),keyEquivalent:"")
        wander.target=self;wander.state=wanderingEnabled ? .on : .off;wanderMenuItem=wander;menu.addItem(wander)
        let camera=NSMenuItem(title:"Scout viewpoint",action:nil,keyEquivalent:"")
        let cameraMenu=NSMenu()
        for cm in [45,55,70] {
            let item=NSMenuItem(title:"Viewing distance: \(cm) cm",action:#selector(setViewingDistance(_:)),keyEquivalent:"")
            item.target=self;item.tag=cm;cameraMenu.addItem(item)
        }
        let hinge=NSMenuItem(title:"Follow lid angle (experimental)",action:#selector(toggleLid(_:)),keyEquivalent:"")
        hinge.target=self;lidMenuItem=hinge;cameraMenu.addItem(hinge);camera.submenu=cameraMenu;menu.addItem(camera)
        let companions = NSMenuItem(title: "Companion", action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for (title, id) in [("White handheld + sticky hand", "handheld"), ("Pixel face", "character"), ("Orbloom", "orb"), ("Scout · Casting Room", "scout")] {
            let item = NSMenuItem(title: title, action: #selector(chooseCompanion(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = id; choices.addItem(item)
        }
        companions.submenu = choices; menu.insertItem(companions, at: 0)
        let studio=NSMenuItem(title:"Scout studio",action:nil,keyEquivalent:"")
        let studioMenu=NSMenu();studio.submenu=studioMenu
        for (title,kind,names) in [
            ("Lights and roof","Optics",["Factory original","Rally twins","Ribbon","Survey projectors","Inset navigator + folding Ribbon","Mast gauge","Scanline","Rangefinder"]),
            ("Shell paint","Paint",["Titanium","Signal Red","Lunar Rover","Cobalt Blue"]),
            ("Pixel face","Face",["Original","Binocular","Waypoint","Sweep","Buddy"])] {
            let group=NSMenuItem(title:title,action:nil,keyEquivalent:""),sub=NSMenu();group.submenu=sub
            let selected=UserDefaults.standard.object(forKey:"scout"+kind) as? Int ?? (kind=="Optics" ? 4 : 0)
            for (index,name) in names.enumerated() {
                let item=NSMenuItem(title:name,action:#selector(chooseScoutFeature(_:)),keyEquivalent:"")
                item.target=self;item.representedObject=kind+":"+String(index);item.state=index==selected ? .on : .off;sub.addItem(item)
            }
            studioMenu.addItem(group)
        }
        for (title,kind) in [("Lights on","Lamps"),("Ground shadow","Shadow"),("Tire tracks","Tracks"),("Lightbar raised","LampLift"),("Climb window edges","WindowSteps")] {
            let item=NSMenuItem(title:title,action:#selector(chooseScoutFeature(_:)),keyEquivalent:"")
            item.target=self;item.representedObject=kind
            let value=UserDefaults.standard.object(forKey:"scout"+kind)
            item.state=(value as? Bool ?? ((value as? Float ?? 1)>0.5)) ? .on : .off;studioMenu.addItem(item)
        }
        menu.addItem(studio)
        let screenImage=NSMenuItem(title:"Screen image access…",action:#selector(screenImageAccess),keyEquivalent:"")
        screenImage.target=self;menu.addItem(screenImage)
        let access = NSMenuItem(title: "Screen reading access…", action: #selector(screenAccess), keyEquivalent: "")
        access.target = self; menu.addItem(access)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Rove"; statusItem.menu = menu
        let main = NSMenu(); let root = NSMenuItem(); root.submenu = menu; main.addItem(root); NSApplication.shared.mainMenu = main
    }
    private func loadCompanion() {
        let chosen = UserDefaults.standard.string(forKey: "companion") ?? "character"
        let id = ["character", "orb", "handheld", "scout"].contains(chosen) ? chosen : "character"
        parkRover(); companionID = id;panel.ignoresMouseEvents=false
        (panel as? FloatingPanel)?.allowTransparentOverflow = id=="scout"
        panel.setContentSize(id == "scout" ? NSSize(width:300,height:380) : NSSize(width:202,height:490))
        panel.setFrameOrigin(bounded(panel.frame.origin))
        rover.position = panel.frame.origin
        wanderHome=rover.position;scoutTyping=false;scoutNear=false
        wanderMenuItem?.isEnabled = id == "scout"
        nextWander=Date().addingTimeInterval(6)
        ready = false
        scout?.clearTracks();scout?.view.isPaused=true;scout?.view.removeFromSuperview();scout=nil;lidMenuItem?.state = .off
        handheld?.view.isPaused = true; handheld?.view.removeFromSuperview(); handheld = nil
        if id == "scout", let host=panel.contentView {
            do { let renderer=try ScoutRenderer(frame:host.bounds);host.addSubview(renderer.view,positioned:.below,relativeTo:web);scout=renderer
                let saved=UserDefaults.standard.double(forKey:"scoutViewingDistance");renderer.viewingDistance=[450.0,550,700].contains(saved) ? saved : 550
                lidMenuItem?.state=renderer.followLid(UserDefaults.standard.object(forKey:"scoutFollowLid") as? Bool ?? true) ? .on : .off }
            catch { NSLog("Rove Scout Metal unavailable: %@",error.localizedDescription) }
        }
        if id == "handheld", let host = panel.contentView {
            do { let renderer = try HandheldRenderer(frame:host.bounds); host.addSubview(renderer.view,positioned:.below,relativeTo:web); handheld = renderer }
            catch { NSLog("Rove handheld renderer unavailable: %@",error.localizedDescription) }
        }
        web.configuration.userContentController.removeAllUserScripts()
        web.configuration.userContentController.addUserScript(WKUserScript(source:"window.ROVE_NATIVE_SCOUT=\(scout != nil)",injectionTime:.atDocumentStart,forMainFrameOnly:true))
        if let url = Bundle.main.url(forResource: id, withExtension: "html") { web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
    }
    @objc private func chooseCompanion(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String else { return }
        UserDefaults.standard.set(id, forKey: "companion"); loadCompanion()
    }
    @objc private func setViewingDistance(_ item:NSMenuItem) {
        UserDefaults.standard.set(Double(item.tag)*10,forKey:"scoutViewingDistance")
        scout?.viewingDistance=Double(item.tag)*10
    }
    @objc private func toggleLid(_ item:NSMenuItem) {
        guard let scout else {return}
        let enabled=item.state != .on
        let available=scout.followLid(enabled)
        UserDefaults.standard.set(enabled,forKey:"scoutFollowLid")
        item.state=enabled && available ? .on : .off
        if enabled && !available {update("error","Lid angle unavailable. Using the fixed viewpoint.")}
    }
    @objc private func screenImageAccess() {
        if !ScreenImage.permitted {CGRequestScreenCaptureAccess()}
        if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {NSWorkspace.shared.open(url)}
    }
    @objc private func screenAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    private func enableTaps() {
        guard let data = try? Data(contentsOf: profileURL), let profile = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let threshold = profile["threshold"] as? Double, profile["keyboardVerified"] as? Bool == true, threshold.isFinite, threshold >= 0.001, threshold <= 0.2 else {
            NSLog("Rove: taps waiting for measured calibration")
            return
        }
        detector.threshold = threshold
        motion.onSample = { [weak self] time, strength, age in
            guard let self else { return }
            self.lastMotionSample=time
            if strength>=self.detector.threshold*0.5 {
                self.tapPeaks.append(String(format:"%.4f · %.2f seconds since keyboard",strength,age));self.tapPeaks=Array(self.tapPeaks.suffix(12))
            }
            if let gesture=self.detector.updateGesture(time: time, strength: strength, keyboardAge: age) {
                if gesture == .triple {
                    self.dismissedKnocks+=1
                    self.stop()
                    return
                }
                self.acceptedKnocks+=1
                NSLog("Rove: double tap accepted")
                self.activateCompanion()
            }
        }
        do { try motion.start() } catch { update("error", error.localizedDescription) }
    }
    @objc private func chooseScoutFeature(_ item:NSMenuItem) {
        guard let value=item.representedObject as? String else {return}
        let pieces=value.split(separator:":"),kind=String(pieces[0])
        if pieces.count==2,let index=Int(pieces[1]) {
            UserDefaults.standard.set(index,forKey:"scout"+kind)
            for other in item.menu?.items ?? [] {other.state=other===item ? .on : .off}
            if kind=="Optics" {scout?.optics=index};if kind=="Paint" {scout?.paint=index};if kind=="Face" {scout?.face=index}
        } else {
            let enabled=item.state != .on;item.state=enabled ? .on : .off
            if kind=="LampLift" {UserDefaults.standard.set(Float(enabled ? 1 : 0),forKey:"scout"+kind);scout?.lampLift=enabled ? 1 : 0}
            else {UserDefaults.standard.set(enabled,forKey:"scout"+kind)}
            if kind=="Lamps" {scout?.lamps=enabled};if kind=="Shadow" {scout?.shadow=enabled};if kind=="Tracks" {scout?.tracks=enabled};if kind=="WindowSteps" {scout?.windowSteps=enabled}
        }
    }
    @objc private func activateCompanion() {
        let keepGreeting=greetingTimer != nil && conversationActive && greetingRelease==nil
        beginConversation(preserveGreeting:keepGreeting)
        if conversationActive && !keepGreeting && edgeDebug==nil {greetScout()}
    }
    @objc private func chooseSpeechVoice(_ item:NSMenuItem) {
        guard let name=item.representedObject as? String,RoveSpeechVoice.available.contains(name) else {return}
        stop();UserDefaults.standard.set(name,forKey:"roveSpeechVoice")
        for other in item.menu?.items ?? [] {other.state=other===item ? .on : .off}
    }
    @objc private func toggleRobotSounds(_ item:NSMenuItem) {
        let enabled = !RobotSounds.enabled
        UserDefaults.standard.set(enabled,forKey:"roveRobotSounds");item.state=enabled ? .on : .off
        if !enabled {robotSounds.stop()}
    }
    @objc private func previewRobotSound() {stop();robotSounds.play()}
    private func keyboardActivation(_ event:NSEvent) {
        inputEvents+=1
        if event.type == .keyDown {doubleShift.typed(at:event.timestamp);return}
        guard event.keyCode==56 || event.keyCode==60 else {
            doubleShift.typed(at:event.timestamp);return
        }
        shiftEvents+=1
        let held=event.modifierFlags.contains(.shift)
        shiftTrace.append(String(format:"%.3f %@",event.timestamp,held ? "down" : "up"));shiftTrace=Array(shiftTrace.suffix(12))
        let other = !event.modifierFlags.intersection([.command,.control,.option]).isEmpty
        if doubleShift.changed(at:event.timestamp,held:held,otherModifier:other) {shiftActivations+=1;activateCompanion()}
    }
    @objc private func knockDiagnostics() {
        let age=lastMotionSample>0 ? String(format:"%.1f",ProcessInfo.processInfo.systemUptime-lastMotionSample) : "no"
        let diagnosticURL=URL.applicationSupportDirectory.appendingPathComponent("Rove/motion-diagnostics.json")
        try? motion.exportDiagnostics(to:diagnosticURL)
        let alert=NSAlert();alert.messageText="Rove knock diagnostics"
        alert.informativeText="Sensor samples: \(motion.samples)\nLast sample: \(age) seconds ago\nAccepted pairs: \(acceptedKnocks); dismiss triples: \(dismissedKnocks)\nThreshold: \(detector.threshold)\nDouble Shift monitor: \(globalShiftMonitor == nil ? "unavailable" : "installed")\nAccessibility trusted: \(AXIsProcessTrusted())\nShift events: \(shiftEvents); accepted gestures: \(shiftActivations)\nRecent motion peaks (strength and keyboard timing only):\n"+tapPeaks.joined(separator:"\n")
        alert.addButton(withTitle:"Done");alert.runModal()
    }
    @objc private func explainWindow() { respond("Explain the page or window I am looking at. Start with its main content and what I can do next.") }
    @objc private func showLastReply() {
        let alert=NSAlert();alert.messageText="Rove";alert.informativeText=reply.isEmpty ? "No spoken reply yet. Double-tap or press Talk to ask a question." : reply
        if !lastRequest.isEmpty {alert.informativeText += "\n\nRequest heard: " + lastRequest}
        alert.informativeText += "\n\nVoice actually used: \(audio.voice.lastVoiceName) · local Gradium\nSelected voice: \(RoveSpeechVoice.selected)"
        if !desktopAgent.lastSource.isEmpty {alert.informativeText += "\n\nSource: " + desktopAgent.lastSource}
        alert.addButton(withTitle:"Done");alert.runModal()
    }
    @objc private func show() { panel.orderFrontRegardless() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
    @objc private func stop() {endConversation();desktopAgent.cancelActions()}
    private func endConversation(preserveGreeting:Bool=false) {
        cueTask?.cancel();cueTask=nil;robotSounds.stop()
        conversationActive=false
        generation += 1; responseTask?.cancel(); responseTask = nil
        if !preserveGreeting && !(edgeDebug != nil && edgeLoopTimer != nil) {
            if greetingTimer != nil,let arrival=greetingArrival,Date().timeIntervalSince(arrival)>0.5 {greetingRelease=Date()}
            else {parkRover()}
        }
        idleTimer?.invalidate(); idleTimer = nil
        audio.end(); scout?.faceRequested=false; update("idle", "Microphone off")
    }
    @objc private func toggle() {
        if state == "listening" {stop();return}
        beginConversation()
    }
    private func beginConversation(preserveGreeting:Bool=false) {
        endConversation(preserveGreeting:preserveGreeting)
        guard !permissionsPending else { return }
        permissionsPending = true
        conversationActive=true
        let permissionTicket = generation
        SFSpeechRecognizer.requestAuthorization { [weak self] authorization in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.permissionsPending = false
                    guard self.generation == permissionTicket else { return }
                    guard authorization == .authorized, granted else { self.update("error", "Allow microphone and speech recognition in System Settings to talk to Rove."); return }
                    self.update("thinking","Getting ready to listen…")
                    let duration=self.robotSounds.play()
                    self.cueTask=Task { @MainActor [weak self] in
                        if duration>0 {try? await Task.sleep(for:.seconds(duration+0.04))}
                        guard let self,!Task.isCancelled,self.generation==permissionTicket,self.conversationActive else {return}
                        self.cueTask=nil;self.startListening()
                    }
                }
            }
        }
    }
    private func startListening() {
        if greetingTimer == nil && edgeLoopTimer == nil {parkRover()}
        do {
            try audio.start()
            update("listening", "Listening…")
            idleTimer = Timer.scheduledTimer(withTimeInterval: desktopAgent.awaitingConfirmation ? 120 : 35, repeats: false) { [weak self] _ in self?.stop() }
        } catch { update("error", error.localizedDescription) }
    }
    private func respond(_ text: String) {
        lastRequest=text
        let normalized = TurnPolicy.normalized(text)
        if ["stop", "cancel", "end conversation", "be quiet"].contains(normalized) { stop(); return }
        let keepFace=scout?.faceRequested ?? false, keepConversation=conversationActive
        endConversation(preserveGreeting:true);scout?.faceRequested=keepFace;conversationActive=keepConversation
        let ticket = generation
        update("thinking", text)
        guard SystemLanguageModel.default.isAvailable else { update("error", "Apple’s local model is unavailable. Nothing was sent online."); return }
        let active=NSWorkspace.shared.frontmostApplication
        let front=active?.bundleIdentifier == Bundle.main.bundleIdentifier ? FrontWindow.underlyingApp() : active
        if let front {rememberApp(front)}
        let history=appTimeline.previous
        let currentApp = lastExternalApp,currentPID=lastExternalPID
        let previousApp=previousExternalApp
        responseTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.desktopAgent.onStatus = { [weak self] message in
                guard let self,self.generation==ticket else {return};self.update("thinking",message)
            }
            do {
                let answer=try await self.desktopAgent.answer(text,front:currentApp,recent:self.recentTurns,previous:previousApp,frontPID:currentPID,history:history,authorized:{[weak self] in self?.generation==ticket})
                guard !Task.isCancelled,self.generation==ticket else {return}
                self.reply=answer
                self.recentTurns=String((self.recentTurns+"\nUser: "+text+"\nRove: "+answer).suffix(1400))
                self.update("thinking","Preparing voice…");self.audio.speak(answer)
            } catch {
                guard self.generation==ticket,!Task.isCancelled else {return}
                self.conversationActive=false
                self.update("error","Local conversation stopped. Double-tap to try again.")
            }
        }
    }
    private func update(_ next: String, _ text: String) {
        state = next
        if next != "idle",isWandering {parkRover()}
        handheld?.state = next
        scout?.state = next
        statusItem?.button?.toolTip = "Rove: \(next). \(text)"
        guard ready, let data = try? JSONSerialization.data(withJSONObject: [next, text]), let json = String(data: data, encoding: .utf8) else { return }
        web.evaluateJavaScript("window.mistState(...\(json))", completionHandler: nil)
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready": ready = true; update(state, state == "speaking" ? reply : "Double-tap or press Talk"); web.evaluateJavaScript("window.roveNativeScout?.(\(scout != nil))",completionHandler:nil); sendDrivePose()
        case "pose":
            if let u = body["u"] as? [String:Any] {
                var pose = [String:Float]()
                for (key,value) in u {
                    if let n = value as? NSNumber { pose[key] = n.floatValue }
                    if let a = value as? [NSNumber] { for (i,n) in a.enumerated() { pose[key + String(i)] = n.floatValue } }
                }
                handheld?.pose = pose
            }
        case "resize":
            if let height = body["height"] as? Double { panel.setContentSize(NSSize(width:202,height:min(700,max(300,height)))) }
        case "scoutTyping":
            scoutTyping=body["typing"] as? Bool ?? false
            nextWander=Date().addingTimeInterval(6)
            if scoutTyping && isWandering {parkRover()}
        case "scoutPause":
            if isWandering {parkRover()}
        case "toggle": toggle()
        case "scoutSummon":
            if scout?.faceRequested==true && conversationActive {
                if state=="speaking" || state=="thinking" {beginConversation();scout?.faceRequested=true}
                scout?.nudgeBalance()
            } else {
                let wasListening=state == "listening";toggle();scout?.faceRequested = !wasListening
                scout?.nudgeBalance()
            }
        case "stop": stop()
        case "text": if let text = body["text"] as? String { respond(String(text.prefix(2000))) }
        case "speak": break
        case "dragStart":
            tossTimer?.invalidate(); velocity = .zero; lastDrag = Date()
            if companionID == "scout" {if edgeLoopTimer==nil {parkRover()};rover.position=panel.frame.origin}
        case "drag":
            guard let dx = body["dx"] as? Double, let dy = body["dy"] as? Double else { return }
            if companionID == "scout" {
                if edgeLoopTimer != nil {parkRover()}
                let old = rover.target ?? rover.position
                rover.target = bounded(CGPoint(x:old.x+dx,y:old.y-dy)); startDriveTimer(); return
            }
            let dt = max(0.016, Date().timeIntervalSince(lastDrag)); lastDrag = Date()
            velocity = NSPoint(x: dx / dt, y: -dy / dt)
            handheld?.swing = Float(max(-0.5,min(0.5,dx * 0.015)))
            move(dx, -dy)
        case "dragEnd":
            if companionID == "scout" {wanderHome=rover.target ?? rover.position;return}
            tossTimer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                self.velocity.x *= 0.90; self.velocity.y *= 0.90
                self.move(self.velocity.x / 60, self.velocity.y / 60)
                if hypot(self.velocity.x, self.velocity.y) < 8 { timer.invalidate() }
            }
        default: break
        }
    }
    @objc private func parkRover() {
        edgeLoopTimer?.invalidate();edgeLoopTimer=nil;scout?.calibrationActive=false;scout?.calibrationClimb=0;edgeDebug?.setMotionPaused(true)
        scout?.roofFace=false
        greetingTimer?.invalidate();greetingTimer=nil;greetingRelease=nil;greetingArrival=nil;scout?.wheeliePitch=0;scout?.greetingClimb=0
        isWandering=false;nextWander=Date().addingTimeInterval(Double.random(in:6...11))
        rover.maximumSpeed=RoverDrive.cruiseSpeed;rover.acceleration=RoverDrive.cruiseAcceleration
        rover.braking=RoverDrive.cruiseBraking;rover.jerk=RoverDrive.cruiseJerk
        driveTimer?.invalidate(); driveTimer = nil; driveRoute.removeAll(); rover.park()
        sendDrivePose()
    }
    @objc private func pauseWandering() {
        wanderingEnabled=false;UserDefaults.standard.set(false,forKey:"scoutWandering")
        wanderMenuItem?.state = .off;parkRover()
    }
    @objc private func toggleWandering(_ item:NSMenuItem) {
        wanderingEnabled.toggle();UserDefaults.standard.set(wanderingEnabled,forKey:"scoutWandering")
        item.state=wanderingEnabled ? .on : .off
        wanderHome=panel.frame.origin;parkRover()
        if wanderingEnabled {nextWander=Date().addingTimeInterval(2)}
    }
    private func refreshControlPlacement() {
        guard companionID == "scout",let area=(panel.screen ?? NSScreen.main)?.visibleFrame else {return}
        let visible=panel.frame.intersection(area)
        guard !visible.isNull else {return}
        let x=visible.midX-panel.frame.minX,width=min(276,visible.width-24)
        guard abs(x-controlCenter)>0.5 || abs(width-controlWidth)>0.5 else {return}
        controlCenter=x;controlWidth=width
        web.evaluateJavaScript("document.documentElement.style.setProperty('--rove-control-x','\(x)px');document.documentElement.style.setProperty('--rove-control-width','\(width)px')",completionHandler:nil)
    }
    private func ambientTick() {
        guard companionID == "scout",ready,panel.isVisible else {return}
        let mouse=NSEvent.mouseLocation,origin=panel.frame.origin
        let body=NSRect(x:origin.x+85,y:origin.y+135,width:130,height:130)
        refreshControlPlacement()
        let controls=NSRect(x:origin.x+controlCenter-52,y:origin.y+84,width:104,height:54)
        let input=NSRect(x:origin.x+controlCenter-controlWidth/2,y:origin.y+84,width:controlWidth,height:54)
        let near=body.insetBy(dx:-8,dy:-8).contains(mouse) || controls.insetBy(dx:-8,dy:-8).contains(mouse)
        // Transparent padding must not block clicks on the app underneath.
        panel.ignoresMouseEvents = !(body.contains(mouse) || controls.contains(mouse) || (scoutTyping && input.contains(mouse)))
        if near != scoutNear {
            scoutNear=near
            if !near {nextWander=max(nextWander,Date().addingTimeInterval(3))}
            web.evaluateJavaScript("document.body.classList.toggle('near',\(near))",completionHandler:nil)
        }
        let busy=state != "idle" || conversationActive || scoutTyping || near || NSApp.modalWindow != nil || edgeDebug != nil
        guard wanderingEnabled,!busy,!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            if isWandering {parkRover()};return
        }
        guard driveTimer == nil,greetingTimer == nil,Date()>=nextWander else {return}
        let angle=Double.random(in:0...(2*Double.pi)),radius=Double.random(in:65...145)
        let destination=bounded(CGPoint(x:wanderHome.x+cos(angle)*radius,y:wanderHome.y+sin(angle)*radius*0.65))
        guard hypot(destination.x-panel.frame.minX,destination.y-panel.frame.minY)>30 else {
            nextWander=Date().addingTimeInterval(4);return
        }
        rover.position=panel.frame.origin;rover.target=destination
        rover.maximumSpeed=Double.random(in:20...30);rover.acceleration=45
        rover.braking=70;rover.jerk=180
        isWandering=true;startDriveTimer()
    }
    @objc private func openArenaDebug() {
        if let edgeDebug {edgeDebug.focus();return}
        guard let screen=NSScreen.screens.first(where:{CGDisplayIsBuiltin(CGDirectDisplayID(ScoutArena.id($0))) != 0}) else {
            let alert=NSAlert();alert.messageText="MacBook display unavailable";alert.informativeText="Turn on the built-in display, then open Screen-edge tuning again.";alert.runModal();return
        }
        parkRover()
        if panel.screen.map({ScoutArena.id($0)}) != ScoutArena.id(screen) {
            let area=ScoutArena.shared.area(for:screen)
            panel.setFrameOrigin(CGPoint(x:area.midX-150,y:area.midY-200));rover.position=panel.frame.origin;wanderHome=rover.position
        }
        scout?.windowSteps=false
        let debug=ScoutArenaDebug(screen:screen)
        debug.sample={ [weak self] in
            guard let self,self.panel.screen.map({ScoutArena.id($0)})==ScoutArena.id(screen) else {return nil}
            return (CGPoint(x:self.panel.frame.minX+150,y:self.panel.frame.minY+200),self.rover.heading,Double(self.scout?.uniforms(width:600,height:760)[2] ?? 55),Double(self.scout?.calibrationClimb ?? 0))
        }
        debug.onChange={ [weak self] in
            guard let self else {return};if self.edgeLoopTimer != nil {return};self.parkRover();self.panel.setFrameOrigin(self.bounded(self.panel.frame.origin));self.rover.position=self.panel.frame.origin;self.wanderHome=self.rover.position;self.sendDrivePose()
        }
        debug.onPreview={ [weak self] right in self?.startArenaLoop(right:right) }
        debug.onPause={ [weak self] paused in
            guard let self else {return};self.edgeLoopPaused=paused
            if !paused && self.edgeLoopTimer==nil {self.startArenaLoop(right:self.edgeLoopRight)}
        }
        debug.onClose={ [weak self] in
            self?.edgeLoopTimer?.invalidate();self?.edgeLoopTimer=nil;self?.scout?.calibrationActive=false;self?.scout?.calibrationClimb=0;self?.rover.park();self?.sendDrivePose()
            self?.scout?.windowSteps=UserDefaults.standard.object(forKey:"scoutWindowSteps") as? Bool ?? true
            if self?.greetingTimer != nil {self?.greetingRelease=Date()}
            self?.edgeDebug=nil
        }
        edgeDebug=debug;debug.show();startArenaLoop(right:false)
    }
    private func startArenaLoop(right:Bool) {
        guard let screen=NSScreen.screens.first(where:{CGDisplayIsBuiltin(ScoutArena.id($0)) != 0}),companionID=="scout" else {return}
        parkRover();edgeLoopRight=right;edgeLoopPaused=false;scout?.calibrationActive=true;edgeDebug?.setMotionPaused(false)
        var age=0.0,last=Date()
        let scale=Double(scout?.uniforms(width:600,height:760)[2] ?? 55)
        let initial=ScoutEdgeCalibration.pose(time:0,right:right,area:ScoutArena.shared.area(for:screen),scale:scale,settings:ScoutArena.shared.settings(for:screen))
        panel.setFrameOrigin(CGPoint(x:initial.center.x-150,y:initial.center.y-200));rover.position=panel.frame.origin;rover.heading=initial.heading
        let clock=Timer(timeInterval:1/60,repeats:true) { [weak self] timer in
            guard let self,self.edgeDebug != nil else {timer.invalidate();return}
            let now=Date(),dt=min(0.05,max(0,now.timeIntervalSince(last)));last=now
            guard !self.edgeLoopPaused,!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {self.rover.position=self.bounded(self.rover.position);self.panel.setFrameOrigin(self.rover.position);self.rover.speed=0;self.updateArenaClimb(right:right,screen:screen);self.sendDrivePose();return}
            age+=dt
            let scale=Double(self.scout?.uniforms(width:600,height:760)[2] ?? 55),settings=ScoutArena.shared.settings(for:screen),area=ScoutArena.shared.area(for:screen)
            let pose=ScoutEdgeCalibration.pose(time:age,right:right,area:area,scale:scale,settings:settings)
            let desired=CGPoint(x:pose.center.x-150,y:pose.center.y-200),old=self.rover.position,gain=1-exp(-18*dt)
            let blended=CGPoint(x:old.x+(desired.x-old.x)*gain,y:old.y+(desired.y-old.y)*gain)
            self.rover.heading=pose.heading;self.rover.position=self.bounded(blended)
            let dx=self.rover.position.x-old.x,dy=self.rover.position.y-old.y
            self.rover.distance=max(0,self.rover.distance+dx*sin(pose.heading)+dy*cos(pose.heading))
            self.rover.speed=dt>0 ? hypot(dx,dy)/dt : 0
            self.panel.setFrameOrigin(self.rover.position);self.updateArenaClimb(right:right,screen:screen);self.refreshControlPlacement();self.sendDrivePose()
        }
        edgeLoopTimer=clock;RunLoop.main.add(clock,forMode:.common)
    }
    private func updateArenaClimb(right:Bool,screen:NSScreen) {
        let scale=Double(scout?.uniforms(width:600,height:760)[2] ?? 55)
        let settings=ScoutArena.shared.settings(for:screen),previous=Double(scout?.calibrationClimb ?? 0)
        let climb=ScoutEdgeCalibration.climb(center:CGPoint(x:panel.frame.minX+150,y:panel.frame.minY+200),heading:rover.heading,right:right,area:ScoutArena.shared.area(for:screen),scale:scale,settings:settings)
        rover.distance=max(0,rover.distance+(climb-previous)*settings.radius*scale)
        scout?.calibrationClimb=Float(climb)
    }
    @objc private func greetScout() {
        guard companionID == "scout",scout != nil,!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {return}
        parkRover();scout?.faceRequested=false
        let start=panel.frame.origin
        guard let screen=panel.screen ?? NSScreen.main else {return}
        let area=ScoutArena.shared.area(for:screen)
        let scale=Double(scout?.uniforms(width:600,height:760)[2] ?? 55)
        let destination=ScoutGreeting.destination(from:start,in:area,pointsPerUnit:scale,settings:ScoutArena.shared.settings(for:screen))
        let motion=ScoutGreeting(origin:start,destination:destination,initialHeading:rover.heading,pointsPerUnit:scale,edgeHeading:destination.x+150<area.midX ? -.pi/2 : .pi/2)
        let began=Date(),initialDistance=rover.distance
        greetingRelease=nil;greetingArrival=began.addingTimeInterval(0.3+motion.approach)
        let beganAsConversation=conversationActive
        let clock=Timer(timeInterval:1/60,repeats:true) { [weak self] timer in
            guard let self else {timer.invalidate();return}
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {self.parkRover();return}
            if beganAsConversation && !self.conversationActive && self.greetingRelease==nil {self.greetingRelease=Date()}
            let age=self.greetingRelease.map {0.3+motion.approach+1.45+Date().timeIntervalSince($0)} ?? Date().timeIntervalSince(began)
            let holding=(self.conversationActive || self.edgeDebug != nil) && self.greetingRelease==nil
            let pose=motion.pose(at:age,holdAtEdge:holding)
            self.rover.position=pose.position;self.rover.heading=pose.heading
            self.rover.distance=initialDistance+pose.distance
            self.rover.speed=pose.moving ? 60 : 0
            let safe=ScoutWall.confinedCenter(CGPoint(x:pose.position.x+150,y:pose.position.y+200),heading:pose.heading,scale:scale,area:area,settings:ScoutArena.shared.settings(for:screen))
            self.rover.position=CGPoint(x:safe.x-150,y:safe.y-200)
            self.panel.setFrameOrigin(self.rover.position);self.refreshControlPlacement();self.sendDrivePose()
            let contact=ScoutWall.pose(center:safe,heading:pose.heading,scale:scale,area:area,settings:ScoutArena.shared.settings(for:screen)).contact
            self.scout?.greetingClimb=contact ? Float(pose.pitch) : 0
            self.scout?.wheeliePitch=0 // Rear-axle climb is gated by real bezel contact.
            if age>=motion.duration && !holding {
                timer.invalidate();self.greetingTimer=nil;self.greetingRelease=nil;self.greetingArrival=nil;self.scout?.greetingClimb=0;self.rover.park();self.sendDrivePose()
                self.wanderHome=self.rover.position;self.nextWander=Date().addingTimeInterval(7)
            }
        }
        greetingTimer=clock;RunLoop.main.add(clock,forMode:.common)
    }
    @objc private func driveScoutLoop() {
        guard companionID == "scout" else { return }
        parkRover(); rover.position = panel.frame.origin
        let p = rover.position
        let direction = ((panel.screen?.visibleFrame.maxX ?? 1000) - panel.frame.maxX) > 150 ? 1.0 : -1.0
        driveRoute = [bounded(CGPoint(x:p.x+140*direction,y:p.y)),bounded(CGPoint(x:p.x+140*direction,y:p.y+110)),bounded(CGPoint(x:p.x,y:p.y+110)),p]
        rover.target = driveRoute.removeFirst(); startDriveTimer()
    }
    private func driveScout(to app:DesktopApp) {
        guard companionID=="scout",edgeDebug==nil,let scout else {return}
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {return}
        guard let anchor=DockDestination.anchor(for:app)?.point,
              let screen=NSScreen.screens.first(where:{$0.frame.contains(anchor)}),screen==panel.screen else {return}
        parkRover();scout.roofFace=true
        let area=screen.visibleFrame
        // Park on the desktop side of the tile, leaving the real Dock clickable.
        let center=CGPoint(x:min(area.maxX-75,max(area.minX+75,anchor.x)),y:min(area.maxY-200,max(area.minY+200,anchor.y)))
        let destination=CGPoint(x:center.x-150,y:center.y-200)
        rover.position=panel.frame.origin;rover.target=destination
        rover.maximumSpeed=380;rover.acceleration=850;rover.braking=1100;rover.jerk=6500
        startDriveTimer()
    }
    private func bounded(_ point: CGPoint) -> CGPoint {
        guard let screen=panel.screen ?? NSScreen.main else {return point}
        let area=ScoutArena.shared.area(for:screen)
        if companionID=="scout",let scout {
            let scale=Double(scout.uniforms(width:600,height:760)[2])
            let center=ScoutWall.confinedCenter(CGPoint(x:point.x+150,y:point.y+200),heading:rover.heading,scale:scale,area:area,settings:ScoutArena.shared.settings(for:screen))
            return CGPoint(x:center.x-150,y:center.y-200)
        }
        let padding=0.0
        return CGPoint(x:min(area.maxX-panel.frame.width+padding,max(area.minX-padding,point.x)),y:min(area.maxY-panel.frame.height,max(area.minY,point.y)))
    }
    private func startDriveTimer() {
        guard driveTimer == nil else { return }
        var lastTick=ProcessInfo.processInfo.systemUptime
        let clock=Timer(timeInterval:1/60,repeats:true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let now=ProcessInfo.processInfo.systemUptime,elapsed=now-lastTick;lastTick=now
            let moving = self.rover.step(elapsed)
            self.rover.position = self.bounded(self.rover.position)
            self.panel.setFrameOrigin(self.rover.position); self.sendDrivePose()
            if !moving {
                if self.driveRoute.isEmpty {
                    timer.invalidate();self.driveTimer=nil
                    self.scout?.roofFace=false
                    if self.isWandering {self.isWandering=false;self.nextWander=Date().addingTimeInterval(Double.random(in:5...10))}
                }
                else { self.rover.target = self.driveRoute.removeFirst() }
            }
        }
        driveTimer=clock;RunLoop.main.add(clock,forMode:.common)
    }
    private func sendDrivePose() {
        guard ready,companionID == "scout" else { return }
        scout?.desktopPosition=rover.position;scout?.heading=Float(rover.heading);scout?.distance=Float(rover.distance);scout?.moving=rover.speed>1
        if scout == nil {web.evaluateJavaScript("window.roveDrive?.(\(rover.heading),\(rover.speed),\(rover.distance))",completionHandler:nil)}
    }
    private func move(_ dx: Double, _ dy: Double) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let area = screen.visibleFrame, frame = panel.frame
        panel.setFrameOrigin(NSPoint(x: min(area.maxX - frame.width, max(area.minX, frame.minX + dx)), y: min(area.maxY - frame.height, max(area.minY, frame.minY + dy))))
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
    }
    func applicationWillTerminate(_ notification: Notification) {
        edgeDebug?.close()
        scout?.clearTracks();stop(); motion.stop(); tossTimer?.invalidate(); ambientTimer?.invalidate(); parkRover()
        Task {await LocalVision.shared.stop()}
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let globalShiftMonitor {NSEvent.removeMonitor(globalShiftMonitor)}
        if let appObserver { NSWorkspace.shared.notificationCenter.removeObserver(appObserver) }
    }
}
