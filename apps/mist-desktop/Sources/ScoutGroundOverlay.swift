import AppKit
import MetalKit

/// Ground coordinates must remain aligned even when the large receiver extends
/// past a display edge. AppKit's normal window constraint would shift its contents.
private final class ScoutGroundPanel:NSPanel {
    override func constrainFrameRect(_ frameRect:NSRect,to screen:NSScreen?)->NSRect {frameRect}
}

/// A separate EDR receiver: large enough for beams, never intercepting desktop input.
final class ScoutGroundOverlay:NSObject,MTKViewDelegate {
    private let panel:NSPanel
    private let view:MTKView
    private let queue:MTLCommandQueue
    private let encode:(MTLTexture,MTLCommandBuffer,[Float])->Void
    private var values:[Float]=[]
    private var ordered:Int?
    private var center=CGPoint(x:500,y:500)
    var windowNumber:Int {panel.windowNumber}
    var receiverFrame:CGRect {panel.frame}
    var receiverWorldCenter:CGPoint {CGPoint(x:panel.frame.minX+center.x,y:panel.frame.minY+center.y)}
    init(device:MTLDevice,queue:MTLCommandQueue,encode:@escaping (MTLTexture,MTLCommandBuffer,[Float])->Void) {
        self.queue=queue;self.encode=encode
        panel=ScoutGroundPanel(contentRect:CGRect(x:0,y:0,width:1000,height:1000),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title="Rove ground lighting";panel.isReleasedWhenClosed=false
        panel.level = .floating;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false
        panel.ignoresMouseEvents=true;panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        view=MTKView(frame:CGRect(x:0,y:0,width:1000,height:1000),device:device)
        view.colorPixelFormat = .rgba16Float;view.clearColor=MTLClearColorMake(0,0,0,0)
        view.autoResizeDrawable=false;view.drawableSize=CGSize(width:768,height:768)
        view.layer?.isOpaque=false
        if let layer=view.layer as? CAMetalLayer {layer.wantsExtendedDynamicRangeContent=true;layer.colorspace=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)}
        view.isPaused=true;view.enableSetNeedsDisplay=false
        panel.contentView=view
        super.init();view.delegate=self
    }
    func update(window:NSWindow,values:[Float],origin:CGPoint?=nil) {
        guard window.isVisible else {clear();return}
        self.values=values
        let desired=origin ?? window.frame.origin
        let worldCenter=CGPoint(x:desired.x+150,y:desired.y+200)
        panel.setFrameOrigin(CGPoint(x:worldCenter.x-500,y:worldCenter.y-500))
        center=CGPoint(x:worldCenter.x-panel.frame.minX,y:worldCenter.y-panel.frame.minY)
        if !panel.isVisible || ordered != window.windowNumber {panel.order(.below,relativeTo:window.windowNumber);ordered=window.windowNumber}
        view.draw()
    }
    func clear() {panel.orderOut(nil)}
    func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) {}
    func draw(in view:MTKView) {
        guard values.count>=32,let drawable=view.currentDrawable,let command=queue.makeCommandBuffer() else {return}
        var uniforms=values
        uniforms[0]=Float(drawable.texture.width);uniforms[1]=Float(drawable.texture.height);uniforms[3]=Float(drawable.texture.width)/1000
        uniforms[28]=Float(center.x);uniforms[29]=Float(center.y);uniforms[31]=1
        encode(drawable.texture,command,uniforms);command.present(drawable);command.commit()
    }
    deinit {panel.close()}
}
