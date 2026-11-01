import AppKit
import WebKit
import Speech
import AVFoundation
import FoundationModels

@main
struct RoveMain {
    static func main() {
        if CommandLine.arguments.contains("--vision-front-test") {
            setbuf(stdout,nil)
            Task { @MainActor in
                do {
                    let active=NSWorkspace.shared.frontmostApplication
                    let app=active?.bundleIdentifier == Bundle.main.bundleIdentifier ? FrontWindow.underlyingApp() : active
                    guard let app,let window=FrontWindow.find(pid:app.processIdentifier) else {throw NSError(domain:"RoveFrontTest",code:1)}
                    let observation=await ScreenContext.observe(app:app.localizedName ?? "Unknown",windowID:window.id)
                    let image=try await ScreenImage.capture(window:window.id,pageBounds:observation.pageBounds)
                    if let index=CommandLine.arguments.firstIndex(of:"--save-test-image"),CommandLine.arguments.count>index+1 {
                        try image.write(to:URL(fileURLWithPath:CommandLine.arguments[index+1]))
                    }
                    let source=(app.localizedName ?? "Unknown")+" — "+(observation.pageTitle ?? window.title)
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

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
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
    private var detector = TapDetector()
    private var generation = 0
    private var responseTask: Task<Void, Never>?
    private var state = "idle"
    private var reply = ""
    private var recentTurns = ""
    private var statusItem: NSStatusItem!
    private var idleTimer: Timer?
    private var permissionsPending = false
    private var conversationActive = false
    private var previousExternalApp = ""
    private var tossTimer: Timer?
    private var driveTimer: Timer?
    private var ambientTimer: Timer?
    private var greetingTimer:Timer?
    private var wanderHome=CGPoint.zero
    private var nextWander=Date.distantFuture
    private var isWandering=false
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
    private var ready = false
    private var lastExternalApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
    private var lastExternalPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
    private var appObserver: NSObjectProtocol?
    private let profileURL = URL.applicationSupportDirectory.appendingPathComponent("Rove/tap-profile.json")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.string(forKey: "companion") == nil, let previous = UserDefaults(suiteName: "local.briton.mistdesktop")?.string(forKey: "companion") {
            UserDefaults.standard.set(previous, forKey: "companion")
        }
        setupMenu()
        Task { _ = try? await PhononModel.shared.get() }
        if VisionConfiguration.installed {Task {try? await LocalVision.shared.prepare()}}
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier { if let self,let name=app.localizedName,name != self.lastExternalApp {
                    self.previousExternalApp=self.lastExternalApp;self.lastExternalApp=name;self.lastExternalPID=app.processIdentifier
                } }
        }
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
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.stop(); return nil }; return event
        }
        enableTaps()
        ambientTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in self?.ambientTick() }
    }
    private func setupMenu() {
        let menu = NSMenu()
        for (title, action, key) in [("Talk / interrupt", #selector(toggle), "t"), ("Stop listening and speaking", #selector(stop), "."), ("Explain front window", #selector(explainWindow), "e"), ("Show last reply", #selector(showLastReply), "r"), ("Show Rove", #selector(show), ""), ("Quit Rove", #selector(quit), "q")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
        }
        for (title,action) in [("Preview Scout’s knock greeting",#selector(greetScout)),("Drive Scout in a small loop",#selector(driveScoutLoop)),("Park Scout",#selector(pauseWandering))] {
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
        panel.setContentSize(id == "scout" ? NSSize(width:300,height:380) : NSSize(width:202,height:490))
        panel.setFrameOrigin(bounded(panel.frame.origin))
        rover.position = panel.frame.origin
        wanderHome=rover.position;scoutTyping=false;scoutNear=false
        wanderMenuItem?.isEnabled = id == "scout"
        nextWander=Date().addingTimeInterval(6)
        ready = false
        scout?.view.isPaused=true;scout?.view.removeFromSuperview();scout=nil;lidMenuItem?.state = .off
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
            if self.detector.update(time: time, strength: strength, keyboardAge: age) {
                NSLog("Rove: double tap accepted")
                self.toggle()
                if self.conversationActive {self.greetScout()}
            }
        }
        do { try motion.start() } catch { update("error", error.localizedDescription) }
    }
    @objc private func explainWindow() { respond("Explain the page or window I am looking at. Start with its main content and what I can do next.") }
    @objc private func showLastReply() {
        let alert=NSAlert();alert.messageText="Rove";alert.informativeText=reply.isEmpty ? "No spoken reply yet. Double-tap or press Talk to ask a question." : reply
        if !desktopAgent.lastSource.isEmpty {alert.informativeText += "\n\nSource: " + desktopAgent.lastSource}
        alert.addButton(withTitle:"Done");alert.runModal()
    }
    @objc private func show() { panel.orderFrontRegardless() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
    @objc private func stop() {
        conversationActive=false
        generation += 1; responseTask?.cancel(); responseTask = nil
        parkRover()
        idleTimer?.invalidate(); idleTimer = nil
        audio.end(); scout?.faceRequested=false; update("idle", "Microphone off")
    }
    @objc private func toggle() {
        if state == "listening" { stop(); return }
        stop()
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
                    self.startListening()
                }
            }
        }
    }
    private func startListening() {
        if greetingTimer == nil {parkRover()}
        do {
            try audio.start()
            update("listening", "Listening…")
            NSSound(named: "Pop")?.play()
            idleTimer = Timer.scheduledTimer(withTimeInterval: 35, repeats: false) { [weak self] _ in self?.stop() }
        } catch { update("error", error.localizedDescription) }
    }
    private func respond(_ text: String) {
        let normalized = TurnPolicy.normalized(text)
        if ["stop", "cancel", "end conversation", "be quiet"].contains(normalized) { stop(); return }
        let keepFace=scout?.faceRequested ?? false, keepConversation=conversationActive
        stop();scout?.faceRequested=keepFace;conversationActive=keepConversation
        let ticket = generation
        update("thinking", text)
        guard SystemLanguageModel.default.isAvailable else { update("error", "Apple’s local model is unavailable. Nothing was sent online."); return }
        let active=NSWorkspace.shared.frontmostApplication
        let front=active?.bundleIdentifier == Bundle.main.bundleIdentifier ? FrontWindow.underlyingApp() : active
        if let front,front.bundleIdentifier != Bundle.main.bundleIdentifier {
            if front.localizedName != lastExternalApp {previousExternalApp=lastExternalApp}
            lastExternalApp=front.localizedName ?? lastExternalApp;lastExternalPID=front.processIdentifier
        }
        let currentApp = lastExternalApp,currentPID=lastExternalPID
        let previousApp=previousExternalApp
        responseTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.desktopAgent.onStatus = { [weak self] message in
                guard let self,self.generation==ticket else {return};self.update("thinking",message)
            }
            do {
                let answer=try await self.desktopAgent.answer(text,front:currentApp,recent:self.recentTurns,previous:previousApp,frontPID:currentPID,authorized:{[weak self] in self?.generation==ticket})
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
            let wasListening=state == "listening";toggle();scout?.faceRequested = !wasListening
        case "stop": stop()
        case "text": if let text = body["text"] as? String { respond(String(text.prefix(2000))) }
        case "speak": break
        case "dragStart":
            tossTimer?.invalidate(); velocity = .zero; lastDrag = Date()
            if companionID == "scout" { parkRover(); rover.position = panel.frame.origin }
        case "drag":
            guard let dx = body["dx"] as? Double, let dy = body["dy"] as? Double else { return }
            if companionID == "scout" {
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
        greetingTimer?.invalidate();greetingTimer=nil;scout?.wheeliePitch=0
        isWandering=false;nextWander=Date().addingTimeInterval(Double.random(in:6...11))
        rover.maximumSpeed=125;rover.acceleration=230
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
    private func ambientTick() {
        guard companionID == "scout",ready,panel.isVisible else {return}
        let mouse=NSEvent.mouseLocation,origin=panel.frame.origin
        let body=NSRect(x:origin.x+85,y:origin.y+135,width:130,height:130)
        let controls=NSRect(x:origin.x+98,y:origin.y+84,width:104,height:54)
        let input=NSRect(x:origin.x+10,y:origin.y+84,width:280,height:54)
        let near=body.insetBy(dx:-8,dy:-8).contains(mouse) || controls.insetBy(dx:-8,dy:-8).contains(mouse)
        // Transparent padding must not block clicks on the app underneath.
        panel.ignoresMouseEvents = !(body.contains(mouse) || controls.contains(mouse) || (scoutTyping && input.contains(mouse)))
        if near != scoutNear {
            scoutNear=near
            if !near {nextWander=max(nextWander,Date().addingTimeInterval(3))}
            web.evaluateJavaScript("document.body.classList.toggle('near',\(near))",completionHandler:nil)
        }
        let busy=state != "idle" || conversationActive || scoutTyping || near || NSApp.modalWindow != nil
        guard wanderingEnabled,!busy,!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            if isWandering {parkRover()};return
        }
        guard driveTimer == nil,Date()>=nextWander else {return}
        let angle=Double.random(in:0...(2*Double.pi)),radius=Double.random(in:65...145)
        let destination=bounded(CGPoint(x:wanderHome.x+cos(angle)*radius,y:wanderHome.y+sin(angle)*radius*0.65))
        guard hypot(destination.x-panel.frame.minX,destination.y-panel.frame.minY)>30 else {
            nextWander=Date().addingTimeInterval(4);return
        }
        rover.position=panel.frame.origin;rover.target=destination
        rover.maximumSpeed=Double.random(in:20...30);rover.acceleration=45
        isWandering=true;startDriveTimer()
    }
    @objc private func greetScout() {
        guard companionID == "scout",scout != nil,!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {return}
        parkRover();scout?.faceRequested=false
        let start=panel.frame.origin
        let motion=ScoutGreeting(origin:start,destination:bounded(CGPoint(x:start.x,y:start.y-28)),initialHeading:rover.heading)
        let began=Date(),initialDistance=rover.distance
        greetingTimer=Timer.scheduledTimer(withTimeInterval:1/60,repeats:true) { [weak self] timer in
            guard let self else {timer.invalidate();return}
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {self.parkRover();return}
            let age=Date().timeIntervalSince(began),pose=motion.pose(at:age)
            self.rover.position=pose.position;self.rover.heading=pose.heading
            self.rover.distance=initialDistance+pose.distance
            self.rover.speed=age>0.22 && age<0.7 ? 60 : 0
            self.panel.setFrameOrigin(pose.position);self.sendDrivePose()
            self.scout?.wheeliePitch=Float(pose.pitch)
            if age>=ScoutGreeting.duration {
                timer.invalidate();self.greetingTimer=nil;self.rover.park();self.sendDrivePose()
                self.wanderHome=pose.position;self.nextWander=Date().addingTimeInterval(7)
            }
        }
    }
    @objc private func driveScoutLoop() {
        guard companionID == "scout" else { return }
        parkRover(); rover.position = panel.frame.origin
        let p = rover.position
        let direction = ((panel.screen?.visibleFrame.maxX ?? 1000) - panel.frame.maxX) > 150 ? 1.0 : -1.0
        driveRoute = [bounded(CGPoint(x:p.x+140*direction,y:p.y)),bounded(CGPoint(x:p.x+140*direction,y:p.y+110)),bounded(CGPoint(x:p.x,y:p.y+110)),p]
        rover.target = driveRoute.removeFirst(); startDriveTimer()
    }
    private func bounded(_ point: CGPoint) -> CGPoint {
        guard let area = (panel.screen ?? NSScreen.main)?.visibleFrame else { return point }
        return CGPoint(x:min(area.maxX-panel.frame.width,max(area.minX,point.x)),y:min(area.maxY-panel.frame.height,max(area.minY,point.y)))
    }
    private func startDriveTimer() {
        guard driveTimer == nil else { return }
        driveTimer = Timer.scheduledTimer(withTimeInterval:1/60,repeats:true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let moving = self.rover.step(1/60)
            self.rover.position = self.bounded(self.rover.position)
            self.panel.setFrameOrigin(self.rover.position); self.sendDrivePose()
            if !moving {
                if self.driveRoute.isEmpty {
                    timer.invalidate();self.driveTimer=nil
                    if self.isWandering {self.isWandering=false;self.nextWander=Date().addingTimeInterval(Double.random(in:5...10))}
                }
                else { self.rover.target = self.driveRoute.removeFirst() }
            }
        }
    }
    private func sendDrivePose() {
        guard ready,companionID == "scout" else { return }
        scout?.heading=Float(rover.heading);scout?.distance=Float(rover.distance);scout?.moving=rover.speed>1
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
        stop(); motion.stop(); tossTimer?.invalidate(); ambientTimer?.invalidate(); parkRover()
        Task {await LocalVision.shared.stop()}
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let appObserver { NSWorkspace.shared.notificationCenter.removeObserver(appObserver) }
    }
}
