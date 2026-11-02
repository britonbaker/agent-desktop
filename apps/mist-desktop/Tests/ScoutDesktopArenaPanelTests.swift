import AppKit
@main struct ScoutDesktopArenaPanelTests {
 static func main() {
  NSApplication.shared.setActivationPolicy(.accessory)
  let desktop=ScoutArena.shared.desktop()
  let panel=FloatingPanel(contentRect:CGRect(x:0,y:0,width:300,height:380),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
  panel.allowTransparentOverflow=true;panel.isReleasedWhenClosed=false;panel.alphaValue=0;panel.orderFront(nil)
  defer {panel.close()}
  var count=0
  for door in desktop.portals(margin:100) {
   var lastScale:Double?,lastEye:SIMD3<Float>?
   for step in -180...180 {
    let center=CGPoint(x:door.center.x+door.direction.x*Double(step),y:door.center.y+door.direction.y*Double(step))
    let requested=CGPoint(x:center.x-150,y:center.y-200)
    panel.setFrameOrigin(requested)
    precondition(hypot(panel.frame.minX-requested.x,panel.frame.minY-requested.y)<1,"AppKit must allow a continuous cross-display panel path")
    precondition(desktop.pose(center:center,heading:.pi/2,scale:55).height==0,"The real monitor seam stays flat")
    if let camera=ScoutArena.shared.camera(at:center,viewingDistance:550,hingeDelta:0) {
     if let lastScale {precondition(abs(lastScale-camera.scale)<0.2,"No physical-scale jump at seam")}
     if let lastEye {precondition(simdLength(lastEye-camera.eye)<0.2,"No perspective jump at seam")}
     lastScale=camera.scale;lastEye=camera.eye
    }
    count+=1
   }
  }
  precondition(count>0,"This live test requires connected displays")
  print("PASS native multi-monitor panel: \(count) continuous seam positions, flat wall contacts, blended physical size and camera")
 }
 static func simdLength(_ p:SIMD3<Float>)->Float {sqrt(p.x*p.x+p.y*p.y+p.z*p.z)}
}
