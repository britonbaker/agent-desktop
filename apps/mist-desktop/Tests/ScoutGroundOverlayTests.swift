import AppKit
import MetalKit

@main struct ScoutGroundOverlayTests {
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {fatalError("Metal unavailable")}
        let receiver=ScoutGroundOverlay(device:device,queue:queue) {texture,command,_ in
            let pass=MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture=texture
            pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,0)
            command.makeRenderCommandEncoder(descriptor:pass)?.endEncoding()
        }
        let body=NSPanel(contentRect:CGRect(x:0,y:0,width:300,height:380),styleMask:.borderless,backing:.buffered,defer:false)
        body.isReleasedWhenClosed=false;body.alphaValue=0;body.orderFront(nil)
        defer {receiver.clear();body.close()}
        var checked=0
        for screen in NSScreen.screens {
            let area=screen.visibleFrame
            for x in [area.minX+10,area.midX-150,area.maxX-310] {
                for y in [area.minY+10,area.midY-190,area.maxY-390] {
                    body.setFrameOrigin(CGPoint(x:x,y:y))
                    receiver.update(window:body,values:[Float](repeating:0,count:32))
                    // Compare actual AppKit frames: pure shader tests miss window constraints.
                    let groundCenter=CGPoint(x:receiver.receiverFrame.midX,y:receiver.receiverFrame.midY)
                    let tirePlaneCenter=CGPoint(x:body.frame.minX+150,y:body.frame.minY+200)
                    precondition(hypot(groundCenter.x-tirePlaneCenter.x,groundCenter.y-tirePlaneCenter.y)<0.01,"Shadow receiver shifted away from the body near a display edge")
                    checked+=1
                }
            }
        }
        precondition(checked>0)
        print("PASS live AppKit receiver alignment at \(checked) positions across \(NSScreen.screens.count) displays, including top edges and corners")
    }
}
