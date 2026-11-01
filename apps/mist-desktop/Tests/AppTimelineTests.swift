import Foundation
@main struct AppTimelineTests {
    static func main() throws {
        var timeline=AppTimeline()
        timeline.record(id:"A",name:"Editor",time:1);timeline.record(id:"A",name:"Editor",time:2)
        timeline.record(id:"B",name:"Browser",time:3);timeline.record(id:"A",name:"Editor",time:4)
        timeline.record(id:"local.briton.rove",name:"Rove",time:5);timeline.record(id:"C",name:"Finder",time:6)
        precondition(timeline.visits.count==4)
        precondition(timeline.previous.map(\.id)==["A","B","A"],"count real visits, including returns, exclude current app")
        precondition(AppTimeline.historySteps(in:"switch to the app we were just using")==1)
        for text in ["switch to the app that we were just using","go to the application I was just using","bring back the one we were in","take me to the last application","switch to the one before this","go back to the app we just used"] {precondition(AppTimeline.historySteps(in:text)==1,text)}
        for text in ["take me to 3 apps ago","switch to three apps back","go back three apps","bring up the third previous app"] {precondition(AppTimeline.historySteps(in:text)==3)}
        precondition(AppTimeline.historySteps(in:"switch to Safari")==nil)
        precondition(AppTimeline.historySteps(in:"20 applications ago")==20)
        precondition(AppTimeline.historySteps(in:"100 applications ago")==nil)
        let copy=try JSONDecoder().decode(AppTimeline.self,from:JSONEncoder().encode(timeline))
        precondition(copy.previous==timeline.previous)
        for i in 0..<100 {timeline.record(id:String(i),name:String(i))}
        precondition(timeline.visits.count==40)
        print("PASS app timeline: repeat visits, Rove exclusion, ordinal references, persistence roundtrip and bounded history")
    }
}
