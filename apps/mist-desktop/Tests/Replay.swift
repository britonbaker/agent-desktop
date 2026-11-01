import Foundation
@main struct Replay {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let rows = try JSONSerialization.jsonObject(with: data) as! [[Double]]
        var detector = TapDetector(threshold: 0.006)
        var accepted: [Double] = []
        var ungated = TapDetector(threshold: 0.006)
        var raw: [Double] = []
        for row in rows {
            if detector.update(time: row[0], strength: row[1], keyboardAge: row[2]) { accepted.append(row[0]) }
            if ungated.update(time: row[0], strength: row[1], keyboardAge: 100) { raw.append(row[0]) }
        }
        let active = rows.filter { $0[2] < 0.65 }
        print("Keyboard-active samples: \(active.count)")
        print("Events ignoring keyboard: \(raw)")
        print("Events with keyboard guard: \(accepted)")
        precondition(accepted.allSatisfy { t in !rows.contains { abs($0[0] - t) < 0.01 && $0[2] < 0.65 } })
    }
}
