import Foundation

let args = CommandLine.arguments

func render() {
    let jobs: [(String, () -> Canvas)] = [
        ("out/gray-match.ppm", grayMatch),
        ("out/quarter-match.ppm", quarterMatch),
        ("out/ramp.ppm", ramp),
        ("out/clamp-pair.ppm", clampPair),
        ("out/plate-01.ppm", plate01),
    ]
    try? FileManager.default.createDirectory(atPath: "out", withIntermediateDirectories: true)
    for (path, make) in jobs {
        let ppm = canvasToPPM(make())
        try! ppm.write(toFile: path, atomically: true, encoding: .utf8)
        print("wrote \(path)")
    }
}

if args.count > 1 && args[1] == "render" {
    render()
} else {
    let t0 = Date()
    runTests()
    let dt = Date().timeIntervalSince(t0)
    for f in failureLog { print(f) }
    print("")
    print("scenarios: \(passedCount + failedCount)  passed: \(passedCount)  failed: \(failedCount)")
    print(String(format: "time: %.3fs", dt))
    print("slowest scenarios:")
    for (n, t) in timings.sorted(by: { $0.1 > $1.1 }).prefix(6) {
        print(String(format: "  %6.1f ms  %@", t * 1000, n))
    }
    exit(failedCount == 0 ? 0 : 1)
}
