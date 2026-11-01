import AppKit
import MetalKit

final class HandheldRenderer: NSObject, MTKViewDelegate {
    let view: MTKView
    var state = "idle"
    var swing: Float = 0
    var pose: [String:Float] = [:]
    private let queue: MTLCommandQueue
    private let emit: MTLRenderPipelineState
    private let blur: MTLRenderPipelineState
    private let composite: MTLRenderPipelineState
    private let started = Date()
    private var textures: [MTLTexture] = []
    private static let keys: [String] = ["res0", "res1", "time", "mouth", "lift", "tilt", "skew", "open", "level", "blink", "hue", "sat", "nod", "shake", "wake", "gaze", "gazeY", "pupil", "pupilScale", "edr", "lattice", "panelFrac", "panelWFrac", "radiusFrac", "panelTopFrac", "tiltX", "tiltY", "dragX", "dragY", "focusX", "focusY", "zoom", "smoothBrow", "mask", "eyeGrow", "eyeSpread", "lcd", "lamp", "hood", "lidLow", "gape", "swing", "textShift", "btn0", "btn1", "btn2", "text0", "text1", "text2", "text3", "text4", "text5", "text6", "text7", "text8", "text9", "text10", "text11"]
    init(frame: CGRect) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(), let url = Bundle.main.url(forResource: "handheld", withExtension: "metal") else { throw NSError(domain:"RoveRenderer",code:1) }
        self.queue = queue
        let library = try device.makeLibrary(source: String(contentsOf: url, encoding:.utf8), options:nil)
        func pipeline(_ name:String) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name:"v_main")
            descriptor.fragmentFunction = library.makeFunction(name:name)
            descriptor.colorAttachments[0].pixelFormat = .rgba16Float
            return try device.makeRenderPipelineState(descriptor:descriptor)
        }
        emit = try pipeline("f_emit"); blur = try pipeline("f_blur"); composite = try pipeline("f_main")
        view = MTKView(frame:frame,device:device)
        super.init()
        view.colorPixelFormat = .rgba16Float; view.clearColor = MTLClearColorMake(0,0,0,0)
        view.layer?.isOpaque = false
        if let layer = view.layer as? CAMetalLayer {
            layer.wantsExtendedDynamicRangeContent = true
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedSRGB)
        }
        view.preferredFramesPerSecond = 30
        view.autoresizingMask = [.width,.height]; view.delegate = self
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { textures.removeAll() }
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable, let command = queue.makeCommandBuffer(), let device = view.device else { return }
        let w = max(1, drawable.texture.width / 2), h = max(1,drawable.texture.height / 2)
        if textures.first?.width != w || textures.first?.height != h {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:w,height:h,mipmapped:false)
            descriptor.usage = [.renderTarget,.shaderRead]; descriptor.storageMode = .private
            textures = (0..<2).compactMap { _ in device.makeTexture(descriptor:descriptor) }
        }
        guard textures.count == 2 else { return }
        let t = Float(Date().timeIntervalSince(started))
        let talking = state == "speaking", listening = state == "listening"
        let values: [String:Float] = ["res0":Float(drawable.texture.width),"res1":Float(drawable.texture.height),"time":t,"mouth":talking ? 0.6+sin(t*8)*0.3 : 0.4,"open":listening ? 1.15 : 0.94,"lift":state == "thinking" ? 0.5 : 0.1,"level":talking ? 0.4 : 0,"blink":fmod(t,4)<0.10 ? 1 : 0,"hue":214,"sat":0.72,"wake":1,"pupilScale":1,"edr":3,"lattice":0.012,"panelFrac":0.77,"panelWFrac":1,"radiusFrac":0.1,"panelTopFrac":0.025,"focusX":91.84,"focusY":179,"zoom":0.72,"smoothBrow":1,"mask":1,"eyeGrow":0.42,"eyeSpread":0.0801,"lcd":1,"lamp":1,"gape":talking ? 1+sin(t*12)*0.3 : 1,"swing":swing+sin(t*1.6)*0.025,"btn1":listening ? 1 : 0]
        let uniforms = Self.keys.map { key -> Float in
            if key == "lcd" { return (pose[key] ?? 1) > 0.5 ? 2 : 0 }
            if ["res0","res1","time","swing","edr"].contains(key) { return values[key] ?? 0 }
            return pose[key] ?? values[key] ?? 0
        }
        func pass(_ texture:MTLTexture,_ pipeline:MTLRenderPipelineState,_ input:MTLTexture? = nil,_ parameters:[Float]? = nil) {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = texture; descriptor.colorAttachments[0].loadAction = .clear; descriptor.colorAttachments[0].storeAction = .store
            descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0)
            guard let encoder = command.makeRenderCommandEncoder(descriptor:descriptor) else { return }
            encoder.setRenderPipelineState(pipeline)
            if let parameters { parameters.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:0) } }
            else { uniforms.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:0) } }
            if let input { encoder.setFragmentTexture(input,index:0) }
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3); encoder.endEncoding()
        }
        pass(textures[0],emit)
        pass(textures[1],blur,textures[0],[1,0,2.4,0.55])
        pass(textures[0],blur,textures[1],[0,1,2.4,0])
        pass(drawable.texture,composite,textures[0])
        command.present(drawable); command.commit()
    }
}
