import Foundation

struct AppVisit:Codable,Equatable {
    let id:String
    let name:String
    let time:TimeInterval
}
struct AppTimeline:Codable {
    private(set) var visits:[AppVisit]=[]
    mutating func record(id:String,name:String,time:TimeInterval=Date().timeIntervalSince1970) {
        guard !id.isEmpty,id != "local.briton.rove",visits.last?.id != id else {return}
        visits.append(AppVisit(id:id,name:name,time:time))
        if visits.count>40 {visits.removeFirst(visits.count-40)}
    }
    var previous:[AppVisit] {Array(visits.dropLast().reversed())}
    static func historySteps(in request:String) -> Int? {
        let text=request.lowercased().split {!$0.isLetter && !$0.isNumber}.joined(separator:" ")
        let numbers=["one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,"nine":9,"ten":10,"first":1,"second":2,"third":3,"fourth":4,"fifth":5,"1st":1,"2nd":2,"3rd":3]
        let words=text.split(separator:" ").map(String.init)
        for i in words.indices {
            guard let count=Int(words[i]) ?? numbers[words[i]],(1...20).contains(count) else {continue}
            if i+1<words.count,["app","apps","application","applications"].contains(words[i+1]) {
                if i>0 && words[i-1]=="back" {return count}
                if i+2<words.count,["ago","back","before","earlier"].contains(words[i+2]) {return count}
            }
            if i+2<words.count,["last","previous"].contains(words[i+1]),["app","application"].contains(words[i+2]) {return count}
        }
        let phrases=["previous app","previous application","last app","app i was using","application i was using","app we were using","app we were just using","app we just used","app i just used","app from before","last used app","what we were just using","what i was just using","the one we were just in"]
        if phrases.contains(where:text.contains) || ["go back","take me back","switch back","back"].contains(text) {return 1}
        return nil
    }
    static var file:URL {URL.applicationSupportDirectory.appendingPathComponent("Rove/recent-apps.json")}
    static func load() -> AppTimeline {
        guard let data=try? Data(contentsOf:file),var timeline=try? JSONDecoder().decode(AppTimeline.self,from:data) else {return AppTimeline()}
        timeline.visits=Array(timeline.visits.filter {!$0.id.isEmpty && $0.id != "local.briton.rove" && !$0.name.isEmpty}.suffix(40));return timeline
    }
    func save() {
        guard let bytes=try? JSONEncoder().encode(self) else {return}
        try? FileManager.default.createDirectory(at:Self.file.deletingLastPathComponent(),withIntermediateDirectories:true)
        try? bytes.write(to:Self.file,options:.atomic)
        try? FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:Self.file.path)
    }
}
