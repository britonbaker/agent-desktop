import Foundation
@main struct CalibrationAnalysis {
    static func main() throws {
        let inputs = try CommandLine.arguments.dropFirst().map { path -> (String, [[Double]]) in
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return (path, try JSONSerialization.jsonObject(with: data) as! [[Double]])
        }
        for threshold in [0.002,0.003,0.004,0.005,0.006,0.007,0.008,0.009,0.010,0.012,0.014,0.016,0.020] {
            print("THRESHOLD \(threshold)")
            for (path, rows) in inputs {
                var detector = TapDetector(threshold: threshold)
                let events = rows.compactMap { r in detector.update(time:r[0], strength:r[1], keyboardAge:r[2]) ? (r[0] * 100).rounded() / 100 : nil }
                print("\(URL(fileURLWithPath:path).lastPathComponent): \(events)")
            }
        }
    }
}
