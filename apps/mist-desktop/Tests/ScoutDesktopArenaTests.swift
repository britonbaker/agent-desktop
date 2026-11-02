import Foundation
import CoreGraphics
@main struct ScoutDesktopArenaTests {
    static func region(_ id:UInt32,_ rect:CGRect)->ScoutDesktopArena.Region {.init(id:id,frame:rect,area:rect)}
    static func main() {
        let mac=region(1,CGRect(x:0,y:0,width:1728,height:1084)),studio=region(2,CGRect(x:-2560,y:-212,width:2560,height:1440))
        let arena=ScoutDesktopArena(regions:[mac,studio])
        precondition(arena.portals(margin:90).count==1)
        for x in stride(from:-200.0,through:200,by:5) {
            let center=CGPoint(x:x,y:500)
            precondition(arena.contains(center,extent:CGSize(width:90,height:90)),"Shared edge has room for the entire rover")
            precondition(arena.confinedCenter(center,heading:.pi/2,scale:55)==center,"No clamp at a connected seam")
            precondition(arena.pose(center:center,heading:.pi/2,scale:55).height==0,"No phantom wall or bank at the seam")
        }
        precondition(arena.height(at:CGPoint(x:-5,y:1200),scale:55)>0,"Exposed part of an offset edge remains a wall")
        precondition(!arena.contains(CGPoint(x:20,y:1100),extent:CGSize(width:80,height:80)),"Missing corner is not traversable")
        let outside=arena.confinedCenter(CGPoint(x:20,y:1100),heading:0.3,scale:55)
        precondition(arena.contains(outside,extent:arena.clearance(heading:0.3,scale:55)))
        let start=CGPoint(x:-1800,y:900),end=CGPoint(x:1200,y:300),route=arena.route(from:start,to:end,margin:90)
        precondition(route.count==3 && route.last==end)
        var previous=start
        for next in route {
            for i in 0...100 {
                let t=Double(i)/100,p=CGPoint(x:previous.x+(next.x-previous.x)*t,y:previous.y+(next.y-previous.y)*t)
                precondition(arena.contains(p,extent:CGSize(width:85,height:85)),"Full footprint stays on the connected desktop route")
            };previous=next
        }
        for pair in [(CGPoint(x:220,y:380),CGPoint(x:-1280,y:508)),(CGPoint(x:-2100,y:900),CGPoint(x:1000,y:400))] {
            let path=arena.route(from:pair.0,to:pair.1,margin:100)
            var drive=RoverDrive(position:pair.0)
            for target in path {
                drive.target=target
                var frames=0
                while drive.step(1/60) {
                    let previous=drive.position
                    drive.position=arena.confinedCenter(drive.position,heading:drive.heading,scale:55)
                    precondition(hypot(previous.x-drive.position.x,previous.y-drive.position.y)<2,"A planned crossing must not collide or jump at an edge")
                    frames+=1;precondition(frames<12000,"Drive route must finish without sticking to a wall")
                }
            }
            precondition(hypot(drive.position.x-pair.1.x,drive.position.y-pair.1.y)<2,"Drive controller reaches the opposite display in both directions")
        }
        let greeting=arena.greetingDestination(from:CGPoint(x:-100,y:500),scale:55)!
        precondition(greeting.center.x>1000,"Summon must reach an outer wall, not stop at the open seam")
        let stacked=ScoutDesktopArena(regions:[region(1,CGRect(x:0,y:0,width:1000,height:800)),region(2,CGRect(x:200,y:800,width:1000,height:800))])
        precondition(stacked.route(from:CGPoint(x:500,y:400),to:CGPoint(x:700,y:1200),margin:80).count==3)
        precondition(stacked.height(at:CGPoint(x:500,y:800),scale:55)==0)
        for other in [CGRect(x:1010,y:0,width:1000,height:800),CGRect(x:1000,y:800,width:1000,height:800),CGRect(x:1000,y:750,width:1000,height:800)] {
            let gap=ScoutDesktopArena(regions:[region(1,CGRect(x:0,y:0,width:1000,height:800)),region(2,other)])
            precondition(gap.route(from:CGPoint(x:500,y:400),to:CGPoint(x:other.midX,y:other.midY),margin:80).isEmpty,"No teleport through gaps, point contacts or too-narrow seams")
        }
        precondition(ScoutDesktopArena(regions:[mac,mac]).regions.count==1,"Mirrored displays share one floor")
        let disconnected=ScoutDesktopArena(regions:[region(1,CGRect(x:0,y:0,width:1000,height:800)),region(2,CGRect(x:1010,y:0,width:1000,height:800))])
        precondition(disconnected.greetingDestination(from:CGPoint(x:950,y:400),scale:55)!.center.x<1000,"A greeting cannot jump a disconnected gap")
        let middle=ScoutDesktopArena.Region(id:3,frame:CGRect(x:1000,y:0,width:1000,height:800),area:CGRect(x:1010,y:12,width:980,height:770))
        let chain=ScoutDesktopArena(regions:[middle,region(4,CGRect(x:2000,y:0,width:1000,height:800)),region(5,CGRect(x:0,y:0,width:1000,height:800))])
        precondition(chain.regions[0].area.minX==1000 && chain.regions[0].area.maxX==2000,"Restore both internal edge insets regardless of neighbor order")
        precondition(chain.route(from:CGPoint(x:500,y:400),to:CGPoint(x:2500,y:400),margin:80).count==5,"Route through a chain of displays")
        let one=ScoutDesktopArena(regions:[mac])
        for point in [CGPoint(x:40,y:400),CGPoint(x:900,y:30),CGPoint(x:900,y:500)] {
            precondition(abs(one.height(at:point,scale:55)-ScoutWall.height(at:point,scale:55,area:mac.area))<0.00001,"Single-display wall profile is preserved")
        }
        print("PASS connected display union: flat seams, exposed walls, full-footprint routes, offset/stacked layouts, disconnected and narrow gaps, outer-wall greetings and mirroring")
    }
}
