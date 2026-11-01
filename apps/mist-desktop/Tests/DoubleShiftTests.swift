import Foundation
@main struct DoubleShiftTests {
    static func main() {
        var d=DoubleShift()
        precondition(!d.changed(at:1,held:true));precondition(!d.changed(at:1.1,held:false))
        precondition(!d.changed(at:1.3,held:true));precondition(d.changed(at:1.4,held:false))
        precondition(!d.changed(at:1.5,held:true));precondition(!d.changed(at:1.6,held:false))
        d=DoubleShift();_=d.changed(at:1,held:true);d.typed(at:1.05)
        precondition(!d.changed(at:1.1,held:false));precondition(!d.changed(at:1.3,held:true));precondition(!d.changed(at:1.4,held:false))
        d=DoubleShift();_=d.changed(at:1,held:true);precondition(!d.changed(at:1.7,held:false))
        d=DoubleShift();_=d.changed(at:1,held:true,otherModifier:true);precondition(!d.changed(at:1.1,held:false))
        d=DoubleShift();_=d.changed(at:1,held:true);_=d.changed(at:1.1,held:false);_=d.changed(at:2,held:true);precondition(!d.changed(at:2.1,held:false))
        d=DoubleShift();d.typed(at:1)
        _=d.changed(at:1.02,held:true);_=d.changed(at:1.07,held:false)
        _=d.changed(at:1.12,held:true);precondition(d.changed(at:1.17,held:false),"immediate post-typing fast pair accepted")
        d=DoubleShift();_=d.changed(at:1,held:true);_=d.changed(at:1.2,held:false)
        d.typed(at:1.3);_=d.changed(at:1.4,held:true);precondition(!d.changed(at:1.6,held:false),"intervening typing still cancels")
        print("PASS double Shift: standalone pair, typing/chord/hold rejection, spacing and cooldown")
    }
}
