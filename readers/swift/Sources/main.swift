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
    let p6jobs: [(String, () -> Canvas)] = [
        ("out/disc-centers.ppm", discCenters),
        ("out/disc-coverage.ppm", discCoverage),
        ("out/painted-twice.ppm", paintedTwice),
        ("out/plate-02.ppm", plate02),
        ("out/fan-bresenham.ppm", fanBresenham),
        ("out/fan-wu.ppm", fanWu),
        ("out/plate-03.ppm", plate03),
        ("out/star-centers.ppm", starCenters),
    ]
    try? FileManager.default.createDirectory(atPath: "out", withIntermediateDirectories: true)
    for (path, make) in jobs {
        let ppm = canvasToPPM(make())
        try! ppm.write(toFile: path, atomically: true, encoding: .utf8)
        print("wrote \(path)")
    }
    for (path, make) in p6jobs {
        let bytes = canvasToP6(make())
        try! Data(bytes).write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
    // fan_coverage is the slow one: twelve 160x160 rasterizations at 64
    // samples a pixel. Timed on its own.
    let t0 = Date()
    let cov = fanCoverage()
    let dt = Date().timeIntervalSince(t0)
    try! Data(canvasToP6(cov)).write(to: URL(fileURLWithPath: "out/fan-coverage.ppm"))
    print("wrote out/fan-coverage.ppm")
    print(String(format: "fan_coverage() took %.3fs", dt))

    // fan_both_orders() and plate_04() are five 160x160 rasterizations
    // between them (two for the fan, three -- a ghost plus each order --
    // for the F), about the same work as fan_coverage. Timed together.
    let t1 = Date()
    let fbo = fanBothOrders()
    try! Data(canvasToP6(fbo)).write(to: URL(fileURLWithPath: "out/fan-both-orders.ppm"))
    print("wrote out/fan-both-orders.ppm")
    let p4 = plate04()
    try! Data(canvasToP6(p4)).write(to: URL(fileURLWithPath: "out/plate-04.ppm"))
    print("wrote out/plate-04.ppm")
    let dt1 = Date().timeIntervalSince(t1)
    print(String(format: "fan_both_orders() + plate_04() took %.3fs", dt1))

    // star_coverage() and plate_05() are chapter 5's stopgap reference
    // renderer: 64 samples a pixel, a winding number over five edges each
    // time. plate_05() redoes star_centers() and star_coverage() itself, so
    // this is four coverage panels' worth of work. Timed on its own.
    let t2 = Date()
    let sc = starCoverage()
    try! Data(canvasToP6(sc)).write(to: URL(fileURLWithPath: "out/star-coverage.ppm"))
    print("wrote out/star-coverage.ppm")
    let p5 = plate05()
    try! Data(canvasToP6(p5)).write(to: URL(fileURLWithPath: "out/plate-05.ppm"))
    print("wrote out/plate-05.ppm")
    let dt2 = Date().timeIntervalSince(t2)
    print(String(format: "star_coverage() + plate_05() took %.3fs", dt2))

    // spiral() and plate_06() are chapter 6's sweep: twenty-four scanline
    // fills of a 320x320 canvas, no supersampling. Timed on its own to show
    // the contrast with the chapter 5 renders above.
    let t3 = Date()
    let sp = spiral()
    try! Data(canvasToP6(sp)).write(to: URL(fileURLWithPath: "out/spiral.ppm"))
    print("wrote out/spiral.ppm")
    let p6plate = plate06()
    try! Data(canvasToP6(p6plate)).write(to: URL(fileURLWithPath: "out/plate-06.ppm"))
    print("wrote out/plate-06.ppm")
    let dt3 = Date().timeIntervalSince(t3)
    print(String(format: "spiral() + plate_06() took %.3fs", dt3))
}

if args.count > 1 && args[1] == "render" {
    render()
} else {
    let t0 = Date()
    runTests()
    let dt = Date().timeIntervalSince(t0)
    for f in failureLog { print(f) }
    print("")
    for ch in perChapter.keys.sorted() {
        let (p, f) = perChapter[ch]!
        print("chapter \(ch):  scenarios: \(p + f)  passed: \(p)  failed: \(f)")
    }
    print("scenarios: \(passedCount + failedCount)  passed: \(passedCount)  failed: \(failedCount)")
    print(String(format: "time: %.3fs", dt))
    print("slowest scenarios:")
    for (n, t) in timings.sorted(by: { $0.1 > $1.1 }).prefix(10) {
        print(String(format: "  %6.1f ms  %@", t * 1000, n))
    }
    exit(failedCount == 0 ? 0 : 1)
}
