import AppKit

final class FloatingPanel:NSPanel {
    var allowTransparentOverflow=false
    override var canBecomeKey:Bool {true}
    override var canBecomeMain:Bool {false}
    override func constrainFrameRect(_ rect:NSRect,to screen:NSScreen?)->NSRect {
        // Scout's transparent padding can cross the bezel. Its tire envelope is
        // independently confined to the calibrated arena by the drive controller.
        allowTransparentOverflow ? rect : super.constrainFrameRect(rect,to:screen)
    }
}
