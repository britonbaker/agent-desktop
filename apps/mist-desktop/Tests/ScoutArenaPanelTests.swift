import AppKit
@main struct ScoutArenaPanelTests {
 static func main() {
  NSApplication.shared.setActivationPolicy(.accessory)
  let body=FloatingPanel(contentRect:CGRect(x:0,y:0,width:300,height:380),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
  body.allowTransparentOverflow=true;body.isReleasedWhenClosed=false;body.alphaValue=0;body.orderFront(nil)
  defer {body.close()}
  var checked=0
  for screen in NSScreen.screens {
   for full in [false,true] {
    var settings=ScoutWall.Settings();settings.fullDisplay=full;settings.left=8;settings.top=12
    let area=settings.area(in:full ? screen.frame : screen.visibleFrame)
    for point in [CGPoint(x:area.minX,y:area.minY),CGPoint(x:area.maxX,y:area.maxY),CGPoint(x:area.minX,y:area.maxY)] {
     let center=ScoutWall.confinedCenter(point,heading:0.4,scale:55,area:area)
     let requested=CGPoint(x:center.x-150,y:center.y-200)
     body.setFrameOrigin(requested)
     // AppKit rounds fractional window origins; tolerate less than one point.
     precondition(hypot(body.frame.minX-requested.x,body.frame.minY-requested.y)<1.0,"AppKit must not move Scout's transparent padding away from the calibrated boundary")
     checked+=1
    }
   }
  }
  print("PASS live arena panel: \(checked) corner placements, full/usable display bounds and transparent padding")
 }
}
