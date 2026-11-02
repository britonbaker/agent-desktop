import AppKit
import MetalKit

/// The original Scout SDF rendered directly into an extended-range Metal layer.
final class ScoutRenderer: NSObject, MTKViewDelegate {
    let view: MTKView
    var state = "idle" { didSet { if oldValue != state { entered = Date() } } }
    var heading: Float = 0
    var distance: Float = 0
    var optics=UserDefaults.standard.object(forKey:"scoutOptics") as? Int ?? 4
    var paint=UserDefaults.standard.integer(forKey:"scoutPaint")
    var face=UserDefaults.standard.integer(forKey:"scoutFace")
    var lamps=UserDefaults.standard.object(forKey:"scoutLamps") as? Bool ?? true
    var shadow=UserDefaults.standard.object(forKey:"scoutShadow") as? Bool ?? true
    var windowSteps=UserDefaults.standard.object(forKey:"scoutWindowSteps") as? Bool ?? true
    var tracks=UserDefaults.standard.object(forKey:"scoutTracks") as? Bool ?? true
    var lampLift:Float=UserDefaults.standard.object(forKey:"scoutLampLift") as? Float ?? 1
    var desktopPosition:CGPoint?
    private var suspension=ScoutSuspension()
    var moving = false
    var calibrationActive=false
    var calibrationClimb:Float=0
    var greetingClimb:Float=0
    var wheeliePitch:Float=0
    var faceRequested = false
    var roofFace = false
    var viewingDistance: Double = 550
    private var lid: LidAngle?
    private var baselineAngle: Double?
    private var hingeDelta=0.0
    private var lastLidRead=Date.distantPast
    func followLid(_ enabled: Bool) -> Bool {
        lid=enabled ? LidAngle() : nil;baselineAngle=lid?.read() == nil ? nil : 90;hingeDelta=0
        return baselineAngle != nil
    }
    private var renderedWheelie:Float=0
    private var wheelieVelocity:Float=0
    private var lift: Float = 0
    private var balance=ScoutBalance()
    func nudgeBalance() {balance.tap()}
    private var previous = Date()
    private var entered = Date()
    private let started = Date()
    private let queue: MTLCommandQueue
    private let library:MTLLibrary
    private let pipeline: MTLRenderPipelineState
    private let trackPipeline:MTLRenderPipelineState
    private var trackOverlay:ScoutTrackOverlay?
    private var groundOverlay:ScoutGroundOverlay?
    private let desktopSurfaces=ScoutDesktopSurfaces()
    private var terrain=ScoutWindowSteps()
    private var terrainPitch=0.0,terrainRoll=0.0,pitchSpeed=0.0,rollSpeed=0.0
    private var terrainPose=ScoutWindowSteps.Pose()
    private var trackTextureAttempted=false

    init(frame: CGRect) throws {
        guard let device=MTLCreateSystemDefaultDevice(), let queue=device.makeCommandQueue(),
              let url=Bundle.main.url(forResource:"scout",withExtension:"metal") else { throw NSError(domain:"ScoutMetal",code:1) }
        self.queue=queue
        let lib=try device.makeLibrary(source:String(contentsOf:url,encoding:.utf8),options:nil)
        self.library=lib
        let descriptor=MTLRenderPipelineDescriptor()
        descriptor.vertexFunction=lib.makeFunction(name:"scout_vertex")
        descriptor.fragmentFunction=lib.makeFunction(name:"main0")
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        pipeline=try device.makeRenderPipelineState(descriptor:descriptor)
        descriptor.fragmentFunction=lib.makeFunction(name:"scout_track_stamp")
        trackPipeline=try device.makeRenderPipelineState(descriptor:descriptor)
        view=MTKView(frame:frame,device:device)
        super.init()
        view.colorPixelFormat = .rgba16Float
        view.clearColor=MTLClearColorMake(0,0,0,0)
        view.layer?.isOpaque=false
        if let layer=view.layer as? CAMetalLayer {
            layer.wantsExtendedDynamicRangeContent=true
            layer.colorspace=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)
        }
        view.autoresizingMask=[.width,.height]
        view.autoResizeDrawable=false
        view.drawableSize=CGSize(width:600,height:760)
        view.preferredFramesPerSecond=20
        view.delegate=self
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func uniforms(width:Int,height:Int) -> [Float] {
        let contactClimb=max(calibrationClimb,greetingClimb)
        let screen=view.window?.screen ?? NSScreen.main
        let frame=screen?.frame ?? CGRect(x:0,y:0,width:1512,height:982)
        let number=screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let physical=number.map { CGDisplayScreenSize(CGDirectDisplayID($0.uint32Value)) } ?? .zero
        // EDID may omit physical size (virtual displays). Use a nominal 110 points/inch.
        let mmPerPoint=physical.width>0 ? physical.width/frame.width : 25.4/110
        let nativeOrigin=view.window?.frame.origin ?? CGPoint(x:frame.midX-150,y:frame.midY-200)
        let origin=ScoutMotionOrigin.resolve(desired:desktopPosition,native:nativeOrigin)
        let residual=CGPoint(x:origin.x-nativeOrigin.x,y:origin.y-nativeOrigin.y)
        let center=CGPoint(x:origin.x+150-frame.minX,y:origin.y+200-frame.minY)
        if Date().timeIntervalSince(lastLidRead)>0.25 {
            lastLidRead=Date()
            if let base=baselineAngle,let angle=lid?.read() {hingeDelta=(angle-base)*Double.pi/180}
        }
        let camera=ScoutCamera(millimetersPerPoint:mmPerPoint,screenSize:frame.size,roverCenter:center,viewingDistance:viewingDistance,hingeDelta:number.map { CGDisplayIsBuiltin(CGDirectDisplayID($0.uint32Value)) != 0 } == true ? hingeDelta : 0)
        let eye=camera.eye
        let headroom=Float(max(1,min(4,screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1)))
        let wall=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? ScoutWall.Pose() : ScoutWall.pose(center:CGPoint(x:origin.x+150,y:origin.y+200),heading:Double(heading),scale:Double(camera.pointsPerUnit),area:screen.map {ScoutArena.shared.area(for:$0)} ?? frame,settings:screen.map {ScoutArena.shared.settings(for:$0)} ?? ScoutWall.Settings())
        let climbTravel=0.862*(1-cos(Double(contactClimb)))
        let rearSupport:Double
        if contactClimb>0 {
            let point=CGPoint(x:origin.x+150+sin(Double(heading))*climbTravel*Double(camera.pointsPerUnit),y:origin.y+200+cos(Double(heading))*climbTravel*Double(camera.pointsPerUnit))
            rearSupport=ScoutWall.pose(center:point,heading:Double(heading),scale:Double(camera.pointsPerUnit),area:screen.map {ScoutArena.shared.area(for:$0)} ?? frame,settings:screen.map {ScoutArena.shared.settings(for:$0)} ?? ScoutWall.Settings()).rearHeight
        } else {rearSupport=wall.height}
        let frontPresented=lift>0.08 || renderedWheelie>0.12 || wall.pitch>0.12 || contactClimb>0.12
        let showRoofFace = !frontPresented && (roofFace || ["listening","thinking","speaking"].contains(state))
        let terrainUniforms=terrain.uniforms(center:CGPoint(x:origin.x+150,y:origin.y+200),scale:Double(camera.pointsPerUnit))
        return [Float(width),Float(height),Float(camera.pointsPerUnit),Float(width)/300,
                eye.x,eye.y,eye.z,Float(Date().timeIntervalSince(started)),
                heading,distance+Float(balance.travel)*Float(camera.pointsPerUnit),["listening":Float(1),"thinking":2,"speaking":3,"error":5][state] ?? (moving ? 7 : 0),lift,
                Float(Date().timeIntervalSince(entered)),headroom,contactClimb>0 ? contactClimb : (wall.contact ? 0 : renderedWheelie),Float(balance.pitchCorrection),
                Float(min(7,max(0,optics))),Float(min(3,max(0,paint))),Float(min(4,max(0,face))),lamps ? 1 : 0,
                lampLift,shadow ? 1 : 0,tracks ? 1 : 0,showRoofFace ? 1 : 0,
                Float((contactClimb>0 ? 0 : wall.pitch)+terrainPitch),Float(wall.roll+terrainRoll),Float(rearSupport+terrainPose.height),Float(balance.travel+climbTravel),
                150+Float(residual.x),200+Float(residual.y),0,0]+terrainUniforms+[Float(suspension.pitch),Float(suspension.roll),Float(suspension.heave),0,Float(suspension.yawTravel),0,0,0]
    }
    func draw(in view: MTKView) {
        guard view.window?.isVisible == true else { return }
        let now=Date(),dt=Float(min(0.05,now.timeIntervalSince(previous)));previous=now
        let position=ScoutMotionOrigin.resolve(desired:desktopPosition,native:view.window?.frame.origin ?? .zero)
        suspension.step(position:position,heading:Double(heading),elapsed:Double(dt),reducedMotion:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        let wheelieTarget=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? Float(0) : wheeliePitch
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {renderedWheelie=0;wheelieVelocity=0}
        else {
            wheelieVelocity+=((wheelieTarget-renderedWheelie)*100-wheelieVelocity*20)*dt
            renderedWheelie=max(0,min(0.85,renderedWheelie+wheelieVelocity*dt))
        }
        let target: Float = faceRequested && !moving && !calibrationActive && ["listening","thinking","speaking"].contains(state) ? 1 : 0
        balance.step(Double(dt),engaged:target>0.5,reducedMotion:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        lift=Float(balance.presentation)
        view.preferredFramesPerSecond = moving || suspension.active || renderedWheelie>0.001 || wheeliePitch>0.001 || abs(target-lift) > 0.002 || state != "idle" ? 60 : 12
        if let window=view.window {
            let center=CGPoint(x:position.x+150,y:position.y+200)
            let scale=Double(uniforms(width:600,height:760)[2])
            if !windowSteps || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {terrain=ScoutWindowSteps();terrainPose=ScoutWindowSteps.Pose();terrainPitch=0;terrainRoll=0;pitchSpeed=0;rollSpeed=0}
            else {
                terrain=desktopSurfaces.sample(display:window.screen?.frame ?? .zero,now:ProcessInfo.processInfo.systemUptime)
                terrainPose=terrain.pose(center:center,heading:Double(heading),scale:scale)
                if lift>0.001 {
                    let h=Double(heading),presented=h+atan2(sin(Double.pi-h),cos(Double.pi-h))*Double(lift)
                    let rear=terrain.rearAxleHeight(center:center,heading:presented,scale:scale),weight=min(1,Double(lift))
                    terrainPose.height+=(rear-terrainPose.height)*weight
                    terrainPose.pitch*=1-weight
                }
                let steps=max(1,Int(ceil(Double(dt)*120))),step=Double(dt)/Double(steps)
                for _ in 0..<steps {
                    pitchSpeed+=((terrainPose.pitch-terrainPitch)*144-pitchSpeed*18)*step
                    rollSpeed+=((terrainPose.roll-terrainRoll)*144-rollSpeed*18)*step
                    terrainPitch+=pitchSpeed*step;terrainRoll+=rollSpeed*step
                }
            }
            if shadow || lamps {
                if groundOverlay==nil,let device=view.device {groundOverlay=ScoutGroundOverlay(device:device,queue:queue) {[weak self] texture,command,values in self?.encode(texture:texture,command:command,values:values)}}
                groundOverlay?.update(window:window,values:uniforms(width:600,height:760),origin:position)
            } else {groundOverlay?.clear()}
            if tracks && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                if !trackTextureAttempted {trackTextureAttempted=true;if let images=try? trackStampImages() {trackOverlay=ScoutTrackOverlay(images:images)}}
                let scale=Double(uniforms(width:600,height:760)[2])
                let wall=ScoutWall.pose(center:CGPoint(x:position.x+150,y:position.y+200),heading:Double(heading),scale:scale,area:window.screen.map {ScoutArena.shared.area(for:$0)} ?? .zero,settings:window.screen.map {ScoutArena.shared.settings(for:$0)} ?? ScoutWall.Settings())
                trackOverlay?.update(position:CGPoint(x:position.x+150,y:position.y+200),heading:Double(heading),scale:scale,frontContact:lift<0.05 && greetingClimb<0.05 && calibrationClimb<0.05 && renderedWheelie<0.05 && abs(wall.pitch+terrainPitch)<0.05,grounded:abs(wall.roll+terrainRoll)<0.05,window:window,belowWindow:(shadow || lamps) ? groundOverlay?.windowNumber : nil)
            } else {trackOverlay?.clear()}
        }
        guard let drawable=view.currentDrawable,let command=queue.makeCommandBuffer() else { return }
        encode(texture:drawable.texture,command:command,values:uniforms(width:drawable.texture.width,height:drawable.texture.height))
        command.present(drawable);command.commit()
    }
    func encode(texture:MTLTexture,command:MTLCommandBuffer,values:[Float]) {
        let pass=MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture=texture
        pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
        guard let encoder=command.makeRenderCommandEncoder(descriptor:pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        values.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:0) }
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);encoder.endEncoding()
    }
    func clearTracks() {trackOverlay?.clear();groundOverlay?.clear()}
    func trackStampImages() throws -> [CGImage] {
        var images:[CGImage]=[]
        for rear in 0...1 {
            let w=128,h=32
            let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:w,height:h,mipmapped:false)
            desc.usage=[.renderTarget];desc.storageMode = .shared
            guard let texture=view.device?.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {throw NSError(domain:"TrackStamp",code:1)}
            let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=texture;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
            guard let encoder=command.makeRenderCommandEncoder(descriptor:pass) else {throw NSError(domain:"TrackStamp",code:2)}
            encoder.setRenderPipelineState(trackPipeline)
            var tile=SIMD4<Float>(Float(w),Float(h),Float(rear),0)
            encoder.setFragmentBytes(&tile,length:16,index:1);encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);encoder.endEncoding()
            command.commit();command.waitUntilCompleted();if let error=command.error {throw error}
            var raw=[UInt16](repeating:0,count:w*h*4)
            raw.withUnsafeMutableBytes {texture.getBytes($0.baseAddress!,bytesPerRow:w*8,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)}
            let bytes=raw.map {UInt8(max(0,min(255,Float(Float16(bitPattern:$0))*255)))}
            guard let provider=CGDataProvider(data:Data(bytes) as CFData),let space=CGColorSpace(name:CGColorSpace.linearSRGB),
                  let image=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:space,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else {throw NSError(domain:"TrackStamp",code:3)}
            images.append(image)
        }
        return images
    }
    func greetingPreview(directory:String) throws {
        try FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        var wheelFrames:[Data]=[],balanceFrames:[Data]=[],stepFrames:[Data]=[]
        for (name,pitch,travel) in [("rest",Float(0),Float(0)),("lift",0.3,0),("wheelie",0.54,0),("drive-start",0,0),("drive-turned",0,20),("suspension-loaded",0,0),("greeting-left",1.12,0),("greeting-right",1.12,0),("pivot-turn",0,0),("step-approach",0,0),("step-on",0,0),("step-down",0,0),("step-corner",0,0),("balance-settled",0,0),("balance-tapped",0,0),("roof-face",0,0),("roof-face-speaking",0,0),("wall-bank",0,0),("wall-corner",0,0),("lighting-north",0,0),("lighting-east",0,0),("lighting-south",0,0),("lighting-west",0,0)] {
            let lighting=name.hasPrefix("lighting-"),w=lighting ? 1000 : 600,h=lighting ? 1000 : 760
            let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:w,height:h,mipmapped:false)
            desc.usage=[.renderTarget,.shaderRead];desc.storageMode = .shared
            guard let texture=view.device?.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {throw NSError(domain:"ScoutPreview",code:1)}
            var values=uniforms(width:w,height:h);values[8] = .pi;values[11]=0;values[14]=pitch;values[9]=travel;values[7]=1.5;values[12]=1.5
            if name.hasPrefix("drive-") {values[10]=7;values[22]=0}
            if name=="suspension-loaded" {values[76]=0.04;values[77]=0.05;values[78] = -0.01}
            if name=="pivot-turn" {values[80]=1.2;values[77]=0.025}
            if name.hasPrefix("step-") {
                let scene=ScoutWindowSteps(frontToBack:[CGRect(x:300,y:200,width:400,height:400),CGRect(x:0,y:0,width:1000,height:800)])
                let locations:[String:Double]=["step-approach":295,"step-on":400,"step-down":705,"step-corner":295]
                let x=locations[name] ?? 295
                let center=CGPoint(x:x,y:name=="step-corner" ? 205 : 400),heading=name=="step-corner" ? 0.4 : Double.pi/2
                let pose=scene.pose(center:center,heading:heading,scale:Double(values[2]))
                values[8]=Float(heading);values[24]=Float(pose.pitch);values[25]=Float(pose.roll);values[26]=Float(pose.height)
                values.replaceSubrange(32..<76,with:scene.uniforms(center:center,scale:Double(values[2])))
            }
            if name.hasPrefix("greeting-") {
                values[8]=name=="greeting-left" ? -.pi/2 : .pi/2
                values[27]=0.862*(1-cos(pitch));values[23]=0
            }
            if name.hasPrefix("balance-") {
                var motion=ScoutBalance()
                for _ in 0..<360 {motion.step(1/120,engaged:true)}
                if name=="balance-tapped" {motion.tap();for _ in 0..<12 {motion.step(1/120,engaged:true)}}
                values[11]=Float(motion.presentation);values[15]=Float(motion.pitchCorrection);values[27]=Float(motion.travel);values[9]+=Float(motion.travel)*values[2]
            }
            if name.hasPrefix("roof-face") {values[23]=1;values[10]=name=="roof-face-speaking" ? 3 : 1}
            if name.hasPrefix("wall-") {
                let corner=name=="wall-corner",angle=corner ? -0.4 : -0.6
                let wall=ScoutWall.pose(center:CGPoint(x:35,y:corner ? 947 : 400),heading:angle,scale:55,area:CGRect(x:0,y:0,width:1512,height:982))
                values[8]=Float(angle);values[14]=0;values[24]=Float(wall.pitch);values[25]=Float(wall.roll);values[26]=Float(wall.height);values[23]=1
            }
            if values[11]>0.08 || values[14]>0.12 || values[24]>0.12 {values[23]=0}
            values[31]=2
            if lighting {
                values[3]=1;values[28]=500;values[29]=500;values[16]=4
                values[8]=["lighting-north":Float(0),"lighting-east":.pi/2,"lighting-south":.pi,"lighting-west":-.pi/2][name] ?? 0
            }
            encode(texture:texture,command:command,values:values);command.commit();command.waitUntilCompleted()
            if let error=command.error {throw error}
            var raw=[UInt16](repeating:0,count:w*h*4)
            raw.withUnsafeMutableBytes {texture.getBytes($0.baseAddress!,bytesPerRow:w*8,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)}
            guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:.alphaNonpremultiplied,bytesPerRow:w*4,bitsPerPixel:32),let output=bitmap.bitmapData else {throw NSError(domain:"ScoutPreview",code:2)}
            for index in 0..<(w*h*4) {
                let value=max(0,Float(Float16(bitPattern:raw[index])))
                let alpha=min(1,max(0,Float(Float16(bitPattern:raw[(index/4)*4+3]))))
                let encoded=index%4==3 ? alpha : pow(min(1,value/max(alpha,0.00001)),1/2.2)
                output[index]=UInt8(min(255,max(0,encoded*255)))
            }
            guard let png=bitmap.representation(using:.png,properties:[:]) else {throw NSError(domain:"ScoutPreview",code:3)}
            try png.write(to:URL(fileURLWithPath:directory).appendingPathComponent(name+".png"))
            if name.hasPrefix("drive-") {wheelFrames.append(Data(bytes:output,count:w*h*4))}
            if name=="suspension-loaded" {values[76]=0.04;values[77]=0.05;values[78] = -0.01}
            if name=="pivot-turn" {values[80]=1.2;values[77]=0.025}
            if name.hasPrefix("step-") {
                let scene=ScoutWindowSteps(frontToBack:[CGRect(x:300,y:200,width:400,height:400),CGRect(x:0,y:0,width:1000,height:800)])
                let locations:[String:Double]=["step-approach":295,"step-on":400,"step-down":705,"step-corner":295]
                let x=locations[name] ?? 295
                let center=CGPoint(x:x,y:name=="step-corner" ? 205 : 400),heading=name=="step-corner" ? 0.4 : Double.pi/2
                let pose=scene.pose(center:center,heading:heading,scale:Double(values[2]))
                values[8]=Float(heading);values[24]=Float(pose.pitch);values[25]=Float(pose.roll);values[26]=Float(pose.height)
                values.replaceSubrange(32..<76,with:scene.uniforms(center:center,scale:Double(values[2])))
            }
            if name=="suspension-loaded" {values[76]=0.04;values[77]=0.05;values[78] = -0.01}
            if name=="pivot-turn" {values[80]=1.2;values[77]=0.025}
            if name.hasPrefix("step-") {stepFrames.append(Data(bytes:output,count:w*h*4))}
            if name.hasPrefix("greeting-") {
                values[8]=name=="greeting-left" ? -.pi/2 : .pi/2
                values[27]=0.862*(1-cos(pitch));values[23]=0
            }
            if name.hasPrefix("balance-") {balanceFrames.append(Data(bytes:output,count:w*h*4))}
        }
        let changed=zip(wheelFrames[0],wheelFrames[1]).filter {abs(Int($0.0)-Int($0.1))>8}.count
        guard changed>100 else {throw NSError(domain:"ScoutPreview",code:4,userInfo:[NSLocalizedDescriptionKey:"Wheel travel did not change the render"])}
        print("PASS authored wheel rotation:",changed,"channels changed from travel alone")
        let ascent=zip(stepFrames[0],stepFrames[1]).filter {abs(Int($0.0)-Int($0.1))>8}.count
        guard ascent>100 else {throw NSError(domain:"ScoutSurface",code:1)}
        print("PASS native window-step ascent, raised deck, descent and diagonal contact rendered")
        let correction=zip(balanceFrames[0],balanceFrames[1]).filter {abs(Int($0.0)-Int($0.1))>8}.count
        guard correction>100 else {throw NSError(domain:"ScoutBalance",code:1,userInfo:[NSLocalizedDescriptionKey:"Balance impulse did not affect rendered body and wheels"])}
        print("PASS rear-axle balancing impulse:",correction,"rendered channels changed")
        for style in 0...7 {
            let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:300,height:380,mipmapped:false)
            desc.usage=[.renderTarget,.shaderRead];desc.storageMode = .shared
            guard let texture=view.device?.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {throw NSError(domain:"ScoutPreset",code:1)}
            var values=uniforms(width:300,height:380);values[16]=Float(style);values[22]=1;values[9]=100
            encode(texture:texture,command:command,values:values);command.commit();command.waitUntilCompleted()
            if let error=command.error {throw error}
        }
        print("PASS all eight authored optics and roof presets compiled/rendered")
        try ScoutTrackOverlay.writeProof(images:trackStampImages(),roverPNG:URL(fileURLWithPath:directory).appendingPathComponent("rest.png"),directory:directory)
        print("Wrote rear-axle greeting previews:",directory)
        try groundLightingTests()
    }
    private func groundLightingTests() throws {
        let w=640,h=640
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:w,height:h,mipmapped:false)
        desc.usage=[.renderTarget,.shaderRead];desc.storageMode = .shared
        guard let texture=view.device?.makeTexture(descriptor:desc) else {throw NSError(domain:"GroundTest",code:1)}
        var worst=0.0
        for angle in [Float(0),Float.pi/2,Float.pi,-Float.pi/2] {
            guard let command=queue.makeCommandBuffer() else {throw NSError(domain:"GroundTest",code:2)}
            var values=uniforms(width:w,height:h)
            values[3]=Float(w)/1000;values[8]=angle;values[11]=0;values[14]=0;values[16]=4;values[19]=0;values[21]=1
            values[24]=0;values[25]=0;values[26]=0;values[28]=500;values[29]=500;values[31]=1
            encode(texture:texture,command:command,values:values);command.commit();command.waitUntilCompleted()
            if let error=command.error {throw error};worst=max(worst,(command.gpuEndTime-command.gpuStartTime)*1000)
            var raw=[UInt16](repeating:0,count:w*h*4)
            raw.withUnsafeMutableBytes {texture.getBytes($0.baseAddress!,bytesPerRow:w*8,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)}
            var mass=0.0,xMoment=0.0,yMoment=0.0
            for y in 0..<h {for x in 0..<w {
                let alpha=Double(Float16(bitPattern:raw[(y*w+x)*4+3]))
                let px=(Double(x)+0.5)/Double(values[3])-500,py=500-(Double(y)+0.5)/Double(values[3])
                mass+=alpha;xMoment+=px*alpha;yMoment+=py*alpha
            }}
            guard mass>5 else {throw NSError(domain:"GroundTest",code:3,userInfo:[NSLocalizedDescriptionKey:"Empty ground shadow"])}
            let x=xMoment/mass,y=yMoment/mass
            guard x>0,y<0,(x*0.566667-y*0.755556)>hypot(x,y)*0.75 else {throw NSError(domain:"GroundTest",code:4,userInfo:[NSLocalizedDescriptionKey:"Shadow rotated with the body: \(angle), \(x), \(y)"])}
        }
        guard let command=queue.makeCommandBuffer() else {throw NSError(domain:"GroundTest",code:5)}
        var values=uniforms(width:w,height:h);values[3]=Float(w)/1000;values[8]=0;values[16]=4;values[19]=1;values[21]=0;values[28]=500;values[29]=500;values[31]=1
        encode(texture:texture,command:command,values:values);command.commit();command.waitUntilCompleted()
        var raw=[UInt16](repeating:0,count:w*h*4)
        raw.withUnsafeMutableBytes {texture.getBytes($0.baseAddress!,bytesPerRow:w*8,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)}
        var beyond=0,edge=0.0
        for y in 0..<h {for x in 0..<w {
            let px=(Double(x)+0.5)/Double(values[3])-500,py=500-(Double(y)+0.5)/Double(values[3])
            let alpha=Double(Float16(bitPattern:raw[(y*w+x)*4+3]))
            if (abs(px)>155 || py < -205 || py>185) && alpha>0.00001 {beyond+=1}
            if hypot(px,py)>492 {edge=max(edge,alpha)}
        }}
        guard beyond>20,edge<0.00001 else {throw NSError(domain:"GroundTest",code:6,userInfo:[NSLocalizedDescriptionKey:"Beam receiver clipped or failed to fade: \(beyond), \(edge)"])}
        print("PASS fixed world-light shadow at four headings; beams extend beyond body window and fade before receiver edge; ground GPU max ms:",worst)
    }
    /// Offscreen proof of shader compilation, nonempty geometry and EDR values.
    private func suspensionContactTest() throws {
        guard let device=view.device else {throw NSError(domain:"SuspensionProbe",code:1)}
        let pipelineDescriptor=MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction=library.makeFunction(name:"scout_vertex")
        pipelineDescriptor.fragmentFunction=library.makeFunction(name:"scout_suspension_probe")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        let probe=try device.makeRenderPipelineState(descriptor:pipelineDescriptor)
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:4,height:1,mipmapped:false)
        descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .shared
        var baseline:[Float]=[]
        for loaded in [false,true] {
            guard let texture=device.makeTexture(descriptor:descriptor),let command=queue.makeCommandBuffer() else {throw NSError(domain:"SuspensionProbe",code:2)}
            let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=texture
            pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
            guard let encoder=command.makeRenderCommandEncoder(descriptor:pass) else {throw NSError(domain:"SuspensionProbe",code:3)}
            var values=uniforms(width:4,height:1)
            values[76]=loaded ? 0.04 : 0;values[77]=loaded ? 0.05 : 0;values[78]=loaded ? -0.01 : 0
            encoder.setRenderPipelineState(probe)
            values.withUnsafeBytes {encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:0)}
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);encoder.endEncoding()
            command.commit();command.waitUntilCompleted();if let error=command.error {throw error}
            var raw=[UInt16](repeating:0,count:16)
            raw.withUnsafeMutableBytes {texture.getBytes($0.baseAddress!,bytesPerRow:32,from:MTLRegionMake2D(0,0,4,1),mipmapLevel:0)}
            let contacts=(0..<4).map {Float(Float16(bitPattern:raw[$0*4]))}
            if loaded {
                guard zip(baseline,contacts).allSatisfy({abs($0-$1)<0.001}) else {throw NSError(domain:"SuspensionProbe",code:4,userInfo:[NSLocalizedDescriptionKey:"Suspension moved tire contacts: \(baseline), \(contacts)"])}
            } else {baseline=contacts}
        }
        print("PASS native shader keeps all four tire contacts fixed under combined suspension pitch, roll and compression")
    }
    private func surfaceHeightTest() throws {
        let scene=ScoutWindowSteps(frontToBack:[CGRect(x:300,y:200,width:400,height:400),CGRect(x:0,y:0,width:1000,height:800)]),center=CGPoint(x:300,y:400),scale=55.0
        let descriptor=MTLRenderPipelineDescriptor()
        descriptor.vertexFunction=library.makeFunction(name:"scout_vertex");descriptor.fragmentFunction=library.makeFunction(name:"scout_surface_probe")
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        guard let device=view.device else {throw NSError(domain:"SurfaceProbe",code:1)}
        let probe=try device.makeRenderPipelineState(descriptor:descriptor)
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:6,height:1,mipmapped:false)
        desc.usage=[.renderTarget,.shaderRead];desc.storageMode = .shared
        guard let texture=device.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {throw NSError(domain:"SurfaceProbe",code:2)}
        let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=texture;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
        guard let encoder=command.makeRenderCommandEncoder(descriptor:pass) else {throw NSError(domain:"SurfaceProbe",code:3)}
        var values=uniforms(width:6,height:1);values.replaceSubrange(32..<76,with:scene.uniforms(center:center,scale:scale))
        encoder.setRenderPipelineState(probe);values.withUnsafeBytes {encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:0)}
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);encoder.endEncoding();command.commit();command.waitUntilCompleted()
        if let error=command.error {throw error}
        var raw=[UInt16](repeating:0,count:24)
        raw.withUnsafeMutableBytes {texture.getBytes($0.baseAddress!,bytesPerRow:48,from:MTLRegionMake2D(0,0,6,1),mipmapLevel:0)}
        let points=[CGPoint(x:-1,y:0),CGPoint(x:0,y:0),CGPoint(x:1,y:0),CGPoint(x:5,y:0),CGPoint(x:0,y:-3.54545),CGPoint(x:0.2,y:-3.34545)]
        for (i,p) in points.enumerated() {
            let expected=scene.height(at:CGPoint(x:center.x+p.x*scale,y:center.y+p.y*scale),scale:scale),actual=Double(Float16(bitPattern:raw[i*4]))
            guard abs(expected-actual)<0.001 else {throw NSError(domain:"SurfaceProbe",code:4,userInfo:[NSLocalizedDescriptionKey:"CPU/GPU terrain mismatch: \(expected), \(actual)"])}
        }
        print("PASS CPU tire contacts and native shadow/light receiver agree on window deck, lip and rounded corner heights")
    }
    func wallBoundaryTest() throws {
        let area=CGRect(x:0,y:0,width:1512,height:982),w=600,h=760,scale=55.0
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:w,height:h,mipmapped:false)
        desc.usage=[.renderTarget,.shaderRead];desc.storageMode = .shared
        for index in 0..<48 {
            let heading=Double(index%12)*Double.pi/6
            let settings=index<12 ? ScoutWall.Settings() : ScoutWall.Settings(radius:index<24 ? 0.6 : 1.35,rise:index<36 ? 1.6 : 1,buffer:0.08)
            for requested in [CGPoint(x:0,y:450),CGPoint(x:1512,y:450),CGPoint(x:0,y:982)] {
                let center=ScoutWall.confinedCenter(requested,heading:heading,scale:scale,area:area,settings:settings)
                let wall=ScoutWall.pose(center:center,heading:heading,scale:scale,area:area,settings:settings)
                guard let texture=view.device?.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {throw NSError(domain:"WallBoundary",code:1)}
                var values=uniforms(width:w,height:h)
                values[2]=55;values[3]=2;values[4]=Float(center.x<area.midX ? 6 : -6);values[5]=49.23;values[6]=Float(center.y>area.midY ? -6 : 6)
                values[8]=Float(heading);values[11]=0;values[14]=0;values[24]=Float(wall.pitch);values[25]=Float(wall.roll);values[26]=Float(wall.height);values[31]=0
                encode(texture:texture,command:command,values:values);command.commit();command.waitUntilCompleted()
                var raw=[UInt16](repeating:0,count:w*h*4)
                raw.withUnsafeMutableBytes {texture.getBytes($0.baseAddress!,bytesPerRow:w*8,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)}
                for y in 0..<h {for x in 0..<w where Float(Float16(bitPattern:raw[(y*w+x)*4+3]))>0.9 {
                    let desktop=CGPoint(x:center.x+Double(x)/2-150,y:center.y+Double(h-y)/2-200)
                    guard area.contains(desktop) else {throw NSError(domain:"WallBoundary",code:2,userInfo:[NSLocalizedDescriptionKey:"Body clips display in case \(index) at heading \(heading), point \(desktop)"])}
                }}
            }
        }
        for right in [false,true] {
            let heading=right ? Double.pi/2 : -Double.pi/2
            let center=ScoutWall.confinedCenter(CGPoint(x:right ? area.maxX : area.minX,y:450),heading:heading,scale:scale,area:area)
            let climb=1.12,advance=0.862*(1-cos(climb))
            let shifted=CGPoint(x:center.x+sin(heading)*advance*scale,y:center.y)
            let support=ScoutWall.pose(center:shifted,heading:heading,scale:scale,area:area).rearHeight
            guard let texture=view.device?.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {throw NSError(domain:"WallBoundary",code:3)}
            var values=uniforms(width:w,height:h)
            values[2]=55;values[3]=2;values[4]=right ? -6 : 6;values[5]=49.23;values[6]=0
            values[8]=Float(heading);values[11]=0;values[14]=Float(climb);values[24]=0;values[25]=0;values[26]=Float(support);values[27]=Float(advance);values[31]=0
            encode(texture:texture,command:command,values:values);command.commit();command.waitUntilCompleted()
            if let error=command.error {throw error}
            var raw=[UInt16](repeating:0,count:w*h*4)
            raw.withUnsafeMutableBytes {texture.getBytes($0.baseAddress!,bytesPerRow:w*8,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)}
            for y in 0..<h {for x in 0..<w where Float(Float16(bitPattern:raw[(y*w+x)*4+3]))>0.9 {
                let desktop=CGPoint(x:center.x+Double(x)/2-150,y:center.y+Double(h-y)/2-200)
                guard area.contains(desktop) else {throw NSError(domain:"WallBoundary",code:4,userInfo:[NSLocalizedDescriptionKey:"Steep greeting clips display: \(desktop)"])}
            }}
        }
        print("PASS steep front-face greeting remains inside both side bezels")
        print("PASS actual Metal silhouette stays inside display at 12 headings with default and close/steep tuning, both side walls and corner with camera parallax")
    }
    func selfTest() throws {
        let w=600,h=760
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:w,height:h,mipmapped:false)
        desc.usage=[.renderTarget,.shaderRead];desc.storageMode = .shared
        guard let tex=view.device?.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else { throw NSError(domain:"ScoutTest",code:1) }
        var values=uniforms(width:w,height:h);values[13]=4
        // Face-up pose exposes the actual emissive front-edge lamps.
        values[11]=1
        encode(texture:tex,command:command,values:values);command.commit();command.waitUntilCompleted()
        if let error=command.error { throw error }
        var pixels=[UInt16](repeating:0,count:w*h*4)
        pixels.withUnsafeMutableBytes { tex.getBytes($0.baseAddress!,bytesPerRow:w*8,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0) }
        let bright=pixels.enumerated().filter { $0.offset%4 != 3 && Float(Float16(bitPattern:$0.element))>1 }.count
        let covered=stride(from:3,to:pixels.count,by:4).filter { Float(Float16(bitPattern:pixels[$0]))>0.9 }.count
        guard bright>0,covered>1000 else { throw NSError(domain:"ScoutTest",code:2,userInfo:[NSLocalizedDescriptionKey:"Empty or SDR render: covered=\(covered), HDR=\(bright)"]) }
        let stamps=try trackStampImages();guard stamps.count==2 else {throw NSError(domain:"TrackStamp",code:4)}
        print("PASS authored front/rear tread stamp textures")
        print("GPU render: \((command.gpuEndTime-command.gpuStartTime)*1000) ms")
        print("PASS native Scout: \(covered) solid pixels, \(bright) EDR channels above 1.0")
        greetingClimb=1.12
        let greetingValues=uniforms(width:w,height:h)
        guard greetingValues[14]>1.1,greetingValues[23]==0 else {throw NSError(domain:"ScoutTest",code:3,userInfo:[NSLocalizedDescriptionKey:"Wall greeting must expose the front face and suppress the roof face"])}
        greetingClimb=0
        print("PASS steep wall greeting selects the front face only")
        try wallBoundaryTest()
        try surfaceHeightTest()
        try suspensionContactTest()
    }
}
