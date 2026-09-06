import Foundation

// A five-line test runner. One `scenario` per Gherkin scenario; scenario
// outlines are expanded one call per Examples row.

struct StepFailure: Error { let message: String }

var passedCount = 0
var failedCount = 0
var failureLog: [String] = []
var currentFeature = ""
var currentChapter = 1
var perChapter: [Int: (Int, Int)] = [:]   // chapter -> (passed, failed)

func chapter(_ n: Int) { currentChapter = n }
func feature(_ name: String) { currentFeature = name }

var timings: [(String, Double)] = []

func scenario(_ name: String, _ body: () throws -> Void) {
    let t0 = Date()
    defer { timings.append((currentFeature + " :: " + name, Date().timeIntervalSince(t0))) }
    do {
        try body()
        passedCount += 1
        perChapter[currentChapter, default: (0, 0)].0 += 1
    } catch let f as StepFailure {
        failedCount += 1
        perChapter[currentChapter, default: (0, 0)].1 += 1
        failureLog.append("FAIL  \(currentFeature) :: \(name)\n      \(f.message)")
    } catch {
        failedCount += 1
        perChapter[currentChapter, default: (0, 0)].1 += 1
        failureLog.append("FAIL  \(currentFeature) :: \(name)\n      \(error)")
    }
}

func step(_ ok: Bool, _ describe: @autoclosure () -> String) throws {
    if !ok { throw StepFailure(message: describe()) }
}

// step helpers matching the book's notation
func eq(_ a: Double, _ b: Double, _ eps: Double = EPSILON, _ label: String) throws {
    try step(equal(a, b, eps), "\(label): \(a) != \(b) (tolerance \(eps))")
}
func ne(_ a: Double, _ b: Double, _ eps: Double = EPSILON, _ label: String) throws {
    try step(!equal(a, b, eps), "\(label): \(a) unexpectedly = \(b) (tolerance \(eps))")
}
func eqC(_ a: Color, _ b: Color, _ label: String) throws {
    try step(a.equals(b), "\(label): (\(a.red), \(a.green), \(a.blue)) != (\(b.red), \(b.green), \(b.blue))")
}
func neC(_ a: Color, _ b: Color, _ label: String) throws {
    try step(!a.equals(b), "\(label): colors unexpectedly equal")
}
func eqPx(_ a: (Int, Int, Int), _ b: (Int, Int, Int), _ tol: Int = 0, _ label: String) throws {
    let ok = abs(a.0 - b.0) <= tol && abs(a.1 - b.1) <= tol && abs(a.2 - b.2) <= tol
    try step(ok, "\(label): \(a) != \(b) (±\(tol))")
}
func eqI(_ a: Int, _ b: Int, _ label: String) throws {
    try step(a == b, "\(label): \(a) != \(b)")
}
func lines(_ ppm: String) -> [String] {
    var l = ppm.components(separatedBy: "\n")
    if l.last == "" { l.removeLast() }   // trailing newline terminates, not separates
    return l
}
func everyPixel(_ c: Canvas, is col: Color) throws {
    for y in 0..<c.height {
        for x in 0..<c.width {
            try step(c.pixelAt(x, y).equals(col),
                     "pixel (\(x), \(y)) is (\(c.pixelAt(x,y).red), \(c.pixelAt(x,y).green), \(c.pixelAt(x,y).blue))")
        }
    }
}

func eqPts(_ a: [(Int, Int)], _ b: [(Int, Int)], _ label: String) throws {
    let ok = a.count == b.count && zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
    try step(ok, "\(label): \(a) != \(b)")
}
func eqBool(_ a: Bool, _ b: Bool, _ label: String) throws {
    try step(a == b, "\(label): \(a) != \(b)")
}
func beginsWith(_ bytes: [UInt8], _ prefix: String, _ label: String) throws {
    let p = Array(prefix.utf8)
    let head = Array(bytes.prefix(p.count))
    try step(head == p, "\(label): begins with \(String(decoding: head, as: UTF8.self).debugDescription)")
}
func eqT(_ a: Tuple, _ b: Tuple, _ label: String) throws {
    try step(a.equals(b), "\(label): (\(a.x), \(a.y), \(a.w)) != (\(b.x), \(b.y), \(b.w))")
}
func eqM(_ a: Matrix3, _ b: Matrix3, _ label: String) throws {
    try step(a.equals(b), "\(label): \(a.cells) != \(b.cells)")
}
func neM(_ a: Matrix3, _ b: Matrix3, _ label: String) throws {
    try step(!a.equals(b), "\(label): matrices unexpectedly equal (\(a.cells))")
}
func eqBounds(_ a: (Double, Double, Double, Double), _ b: (Double, Double, Double, Double), _ label: String) throws {
    let ok = equal(a.0, b.0) && equal(a.1, b.1) && equal(a.2, b.2) && equal(a.3, b.3)
    try step(ok, "\(label): \(a) != \(b)")
}
func eqSpans(_ a: [(Double, Double)], _ b: [(Double, Double)], _ label: String) throws {
    let ok = a.count == b.count && zip(a, b).allSatisfy { equal($0.0, $1.0) && equal($0.1, $1.1) }
    try step(ok, "\(label): \(a) != \(b)")
}
func eqXings(_ a: [(Double, Int)], _ b: [(Double, Int)], _ label: String) throws {
    let ok = a.count == b.count && zip(a, b).allSatisfy { equal($0.0, $1.0) && $0.1 == $1.1 }
    try step(ok, "\(label): \(a) != \(b)")
}

func runTests() {
    chapter(1)
    // ============================================ chapter01-equality.feature
    feature("Comparing numbers")

    scenario("Two numbers that differ by less than the tolerance are equal") {
        try eq(1.0, 1.0000001, 0.00001, "1.0 = 1.0000001 ± 0.00001")
    }
    scenario("Two numbers that differ by more than the tolerance are not") {
        try ne(1.0, 1.001, 0.00001, "1.0 != 1.001 ± 0.00001")
    }
    scenario("The default tolerance is 0.0001") {
        try eq(0.1 + 0.2, 0.3, EPSILON, "0.1 + 0.2 = 0.3")
        try eq(1.0, 1.00009, EPSILON, "1.0 = 1.00009")
        try ne(1.0, 1.0002, EPSILON, "1.0 != 1.0002")
    }

    // ============================================== chapter01-colors.feature
    feature("Colors")

    scenario("A color is a red, green, blue tuple") {
        let c = color(-0.5, 0.4, 1.7)
        try eq(c.red, -0.5, EPSILON, "c.red")
        try eq(c.green, 0.4, EPSILON, "c.green")
        try eq(c.blue, 1.7, EPSILON, "c.blue")
    }
    scenario("Adding colors") {
        let c1 = color(0.9, 0.6, 0.75), c2 = color(0.7, 0.1, 0.25)
        try eqC(c1 + c2, color(1.6, 0.7, 1.0), "c1 + c2")
    }
    scenario("Subtracting colors") {
        let c1 = color(0.9, 0.6, 0.75), c2 = color(0.7, 0.1, 0.25)
        try eqC(c1 - c2, color(0.2, 0.5, 0.5), "c1 - c2")
    }
    scenario("Scaling a color by a number") {
        let c = color(0.2, 0.3, 0.4)
        try eqC(c * 2, color(0.4, 0.6, 0.8), "c * 2")
        try eqC(c * 0.5, color(0.1, 0.15, 0.2), "c * 0.5")
    }
    scenario("Multiplying two colors filters one through the other") {
        let c1 = color(1, 0.2, 0.4), c2 = color(0.9, 1, 0.1)
        try eqC(c1 * c2, color(0.9, 0.2, 0.04), "c1 * c2")
    }
    scenario("Colors compare component by component, with the usual tolerance") {
        let c1 = color(0.1, 0.5, 1), c2 = color(0.2, 0, 0)
        try eqC(c1 + c2, color(0.3, 0.5, 1), "c1 + c2")
        try neC(c1 + c2, color(0.3, 0.5, 1.001), "c1 + c2 != ...1.001")
    }

    // ============================================== chapter01-canvas.feature
    feature("Canvas")

    scenario("A new canvas is black") {
        let c = canvas(10, 20)
        try eqI(c.width, 10, "c.width")
        try eqI(c.height, 20, "c.height")
        try everyPixel(c, is: color(0, 0, 0))
    }
    scenario("Writing a pixel") {
        let c = canvas(10, 20)
        let red = color(1, 0, 0)
        writePixel(c, 2, 3, red)
        try eqC(pixelAt(c, 2, 3), red, "pixel_at(c, 2, 3)")
    }
    scenario("x is the column and y is the row") {
        let c = canvas(10, 20)
        writePixel(c, 2, 3, color(1, 0, 0))
        try eqC(pixelAt(c, 3, 2), color(0, 0, 0), "pixel_at(c, 3, 2)")
        try eqC(pixelAt(c, 2, 3), color(1, 0, 0), "pixel_at(c, 2, 3)")
    }
    scenario("Writing outside the canvas is ignored") {
        let c = canvas(10, 20)
        writePixel(c, -1, 5, color(1, 0, 0))
        writePixel(c, 10, 5, color(1, 0, 0))
        writePixel(c, 5, -1, color(1, 0, 0))
        writePixel(c, 5, 20, color(1, 0, 0))
        try everyPixel(c, is: color(0, 0, 0))
    }
    scenario("A pixel can be written more than once") {
        let c = canvas(10, 20)
        writePixel(c, 2, 3, color(1, 0, 0))
        writePixel(c, 2, 3, color(0, 1, 0))
        try eqC(pixelAt(c, 2, 3), color(0, 1, 0), "pixel_at(c, 2, 3)")
    }
    scenario("Filling a canvas") {
        let c = canvas(10, 20)
        fill(c, color(0.1, 0.2, 0.3))
        try everyPixel(c, is: color(0.1, 0.2, 0.3))
    }

    // ================================================ chapter01-srgb.feature
    feature("sRGB transfer functions")

    let encodeRows: [(Double, Double)] = [
        (0.0, 0.0), (0.0025, 0.0323), (0.0031308, 0.0405), (0.01, 0.0999),
        (0.1, 0.3492), (0.216, 0.5021), (0.25, 0.5371), (0.5, 0.7354),
        (0.75, 0.8808), (1.0, 1.0),
    ]
    for (light, value) in encodeRows {
        scenario("Encoding light into a file value [light=\(light), value=\(value)]") {
            try eq(encode(light), value, EPSILON, "encode(\(light))")
        }
    }

    let decodeRows: [(Double, Double)] = [
        (0.0, 0.0), (0.04, 0.0031), (0.04045, 0.0031), (0.05, 0.0039),
        (0.1, 0.0100), (0.5, 0.2140), (0.75, 0.5225), (1.0, 1.0),
    ]
    for (value, light) in decodeRows {
        scenario("Decoding a file value into light [value=\(value), light=\(light)]") {
            try eq(decode(value), light, EPSILON, "decode(\(value))")
        }
    }

    scenario("Decode undoes encode") {
        try eq(decode(encode(0.2)), 0.2, 0.000000001, "decode(encode(0.2))")
    }
    scenario("Encode undoes decode") {
        try eq(encode(decode(0.7)), 0.7, 0.000000001, "encode(decode(0.7))")
    }
    scenario("The half gray that isn't 128") {
        try eqI(Int((encode(0.5) * 255).rounded()), 188, "round(encode(0.5) * 255)")
    }
    scenario("What 128 actually is") {
        try eq(decode(128.0 / 255.0), 0.2159, EPSILON, "decode(128 / 255)")
    }

    // ================================================= chapter01-ppm.feature
    feature("PPM output")

    scenario("The PPM header") {
        let ppm = canvasToPPM(canvas(5, 3))
        let l = lines(ppm)
        try step(l.count >= 3, "not enough lines")
        try step(l[0] == "P3", "line 1 is \"\(l[0])\", want \"P3\"")
        try step(l[1] == "5 3", "line 2 is \"\(l[1])\", want \"5 3\"")
        try step(l[2] == "255", "line 3 is \"\(l[2])\", want \"255\"")
    }
    scenario("Pixel values are encoded, not scaled") {
        let c = canvas(3, 1)
        writePixel(c, 0, 0, color(1, 0, 0))
        writePixel(c, 1, 0, color(0, 0.5, 0))
        writePixel(c, 2, 0, color(0, 0, 0.216))
        let l = lines(canvasToPPM(c))
        try step(l[3] == "255 0 0 0 188 0 0 0 128", "line 4 is \"\(l[3])\"")
    }
    scenario("Colors out of range are clamped, not wrapped") {
        let c = canvas(2, 1)
        writePixel(c, 0, 0, color(1.5, 0, -0.5))
        let l = lines(canvasToPPM(c))
        try step(l[3] == "255 0 0 0 0 0", "line 4 is \"\(l[3])\"")
    }
    scenario("Every row starts a new line, and no line exceeds 70 characters") {
        let c = canvas(10, 2)
        fill(c, color(1, 0.8, 0.6))
        let ppm = canvasToPPM(c)
        let l = lines(ppm)
        let want = [
            "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231",
            "203 255 231 203 255 231 203 255 231 203 255 231 203",
            "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231",
            "203 255 231 203 255 231 203 255 231 203 255 231 203",
        ]
        for i in 0..<4 {
            try step(l[3 + i] == want[i], "line \(4 + i) is \"\(l[3 + i])\", want \"\(want[i])\"")
        }
        for (i, line) in l.enumerated() {
            try step(line.count <= 70, "line \(i + 1) is \(line.count) characters")
        }
    }
    scenario("A line of exactly 70 characters is allowed") {
        let c = canvas(8, 1)
        fill(c, color(1, 0.1, 0))
        writePixel(c, 7, 0, color(1, 1, 1))
        let ppm = canvasToPPM(c)
        let l = lines(ppm)
        let want = [
            "255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 255",
            "255",
        ]
        for i in 0..<2 {
            try step(l[3 + i] == want[i], "line \(4 + i) is \"\(l[3 + i])\", want \"\(want[i])\"")
        }
        try step(l[3].count == 70, "line 4 is \(l[3].count) characters, want 70")
    }
    scenario("The file ends with a newline") {
        let ppm = canvasToPPM(canvas(5, 3))
        try step(ppm.hasSuffix("\n"), "does not end with a newline")
    }
    scenario("Reading a pixel back out of the text") {
        let c = canvas(3, 2)
        writePixel(c, 2, 1, color(0, 0.5, 1))
        let ppm = canvasToPPM(c)
        try eqPx(ppmPixel(ppm, 2, 1), (0, 188, 255), 0, "ppm_pixel(ppm, 2, 1)")
        try eqPx(ppmPixel(ppm, 1, 1), (0, 0, 0), 0, "ppm_pixel(ppm, 1, 1)")
    }
    scenario("Counting the distinct values in a file") {
        let c = canvas(3, 1)
        writePixel(c, 0, 0, color(1, 0, 0))
        writePixel(c, 1, 0, color(0, 0.5, 0))
        writePixel(c, 2, 0, color(0, 0, 0.216))
        let ppm = canvasToPPM(c)
        try eqI(distinctValues(ppm), 4, "distinct_values(ppm)")
    }
    scenario("Comparing two files") {
        let c1 = canvas(2, 1), c2 = canvas(2, 1)
        writePixel(c2, 0, 0, color(0.5, 0, 0))
        let ppm1 = canvasToPPM(c1), ppm2 = canvasToPPM(c2)
        try eqI(maxChannelDifference(ppm1, ppm1), 0, "max_channel_difference(ppm1, ppm1)")
        try eqI(maxChannelDifference(ppm1, ppm2), 188, "max_channel_difference(ppm1, ppm2)")
    }
    scenario("Files of different sizes are as different as it gets") {
        let c1 = canvas(5, 3), c2 = canvas(3, 5)
        let ppm1 = canvasToPPM(c1), ppm2 = canvasToPPM(c2)
        try eqI(maxChannelDifference(ppm1, ppm2), 255, "max_channel_difference(ppm1, ppm2)")
    }
    scenario("The same width with a different height is still a different size") {
        let c1 = canvas(5, 3), c2 = canvas(5, 4)
        let ppm1 = canvasToPPM(c1), ppm2 = canvasToPPM(c2)
        try eqI(maxChannelDifference(ppm1, ppm2), 255, "max_channel_difference(ppm1, ppm2)")
    }

    // ========================================== chapter01-gray-match.feature
    feature("The gray match")

    scenario("The gray match") {
        let c = grayMatch()
        try eqI(c.width, 300, "c.width")
        try eqI(c.height, 100, "c.height")
        try eqC(pixelAt(c, 0, 0), color(1, 1, 1), "pixel_at(c, 0, 0)")
        try eqC(pixelAt(c, 1, 0), color(0, 0, 0), "pixel_at(c, 1, 0)")
        try eqC(pixelAt(c, 0, 1), color(0, 0, 0), "pixel_at(c, 0, 1)")
        try eqC(pixelAt(c, 1, 1), color(1, 1, 1), "pixel_at(c, 1, 1)")
        try eqC(pixelAt(c, 150, 50), color(0.2159, 0.2159, 0.2159), "pixel_at(c, 150, 50)")
        try eqC(pixelAt(c, 250, 50), color(0.5, 0.5, 0.5), "pixel_at(c, 250, 50)")
        try eqI(c.count(of: color(1, 1, 1)), 5000, "pixels of c that are white")
    }
    scenario("The gray match, as a file") {
        let ppm = canvasToPPM(grayMatch())
        try eqPx(ppmPixel(ppm, 0, 0), (255, 255, 255), 0, "ppm_pixel(ppm, 0, 0)")
        try eqPx(ppmPixel(ppm, 1, 0), (0, 0, 0), 0, "ppm_pixel(ppm, 1, 0)")
        try eqPx(ppmPixel(ppm, 150, 50), (128, 128, 128), 0, "ppm_pixel(ppm, 150, 50)")
        try eqPx(ppmPixel(ppm, 250, 50), (188, 188, 188), 0, "ppm_pixel(ppm, 250, 50)")
        let ref = readFile("reference/chapter-01/gray-match.ppm")
        let d = maxChannelDifference(ppm, ref)
        try step(d <= 1, "max_channel_difference(ppm, ref) = \(d)")
    }
    scenario("One pixel in four") {
        let c = quarterMatch()
        try eqI(c.width, 200, "c.width")
        try eqI(c.height, 100, "c.height")
        try eqC(pixelAt(c, 0, 0), color(1, 1, 1), "pixel_at(c, 0, 0)")
        try eqC(pixelAt(c, 1, 0), color(0, 0, 0), "pixel_at(c, 1, 0)")
        try eqC(pixelAt(c, 2, 2), color(1, 1, 1), "pixel_at(c, 2, 2)")
        try eqC(pixelAt(c, 3, 1), color(1, 1, 1), "pixel_at(c, 3, 1)")
        try eqC(pixelAt(c, 150, 50), color(0.25, 0.25, 0.25), "pixel_at(c, 150, 50)")
        try eqI(c.count(of: color(1, 1, 1)), 2500, "pixels of c that are white")
        let ppm = canvasToPPM(c)
        try eqPx(ppmPixel(ppm, 150, 50), (137, 137, 137), 0, "ppm_pixel(ppm, 150, 50)")
        let ref = readFile("reference/chapter-01/quarter-match.ppm")
        let d = maxChannelDifference(ppm, ref)
        try step(d <= 1, "max_channel_difference(ppm, ref) = \(d)")
    }

    // ================================================= chapter01-mix.feature
    feature("Mixing two colors")

    scenario("Linear blending is on by default") {
        linearBlending = true   // reset before each scenario, per § 1.7
        try step(linearBlending, "linear blending is off")
    }
    scenario("Halfway between black and white") {
        linearBlending = true
        try eqC(mix(color(0, 0, 0), color(1, 1, 1), 0.5), color(0.5, 0.5, 0.5), "mix(a, b, 0.5)")
    }
    scenario("The ends of a mix are its inputs") {
        linearBlending = true
        let a = color(0.7, 0, 0), b = color(0, 0.3, 0.02)
        try eqC(mix(a, b, 0), a, "mix(a, b, 0)")
        try eqC(mix(a, b, 1), b, "mix(a, b, 1)")
    }
    scenario("Red to green, in light") {
        linearBlending = true
        let a = color(0.7, 0, 0), b = color(0, 0.3, 0.02)
        try eqC(mix(a, b, 0.5), color(0.35, 0.15, 0.01), "mix(a, b, 0.5)")
        try eqC(mix(a, b, 0.25), color(0.525, 0.075, 0.005), "mix(a, b, 0.25)")
    }
    scenario("Halfway between black and white, the way browsers do it") {
        linearBlending = true
        linearBlending = false
        try eqC(mix(color(0, 0, 0), color(1, 1, 1), 0.5),
                color(0.2140, 0.2140, 0.2140), "mix(a, b, 0.5)")
    }
    scenario("Red to green, the way browsers do it") {
        linearBlending = true
        linearBlending = false
        let a = color(0.7, 0, 0), b = color(0, 0.3, 0.02)
        try eqC(mix(a, b, 0.5), color(0.1527, 0.0693, 0.0067), "mix(a, b, 0.5)")
    }
    scenario("The light's way never clamps") {
        linearBlending = true
        let a = color(1.5, 0.5, -0.2), b = color(0, 0, 0)
        try eqC(mix(a, b, 0), color(1.5, 0.5, -0.2), "mix(a, b, 0)")
        try eqC(mix(a, b, 0.5), color(0.75, 0.25, -0.1), "mix(a, b, 0.5)")
    }
    scenario("The switch can be passed instead of set") {
        linearBlending = true
        let a = color(0, 0, 0), b = color(1, 1, 1)
        try eqC(mix(a, b, 0.5, true), color(0.5, 0.5, 0.5), "mix(a, b, 0.5, true)")
        try eqC(mix(a, b, 0.5, false), color(0.2140, 0.2140, 0.2140), "mix(a, b, 0.5, false)")
        try step(linearBlending, "linear blending is on")
    }
    scenario("The browser's way clamps each end before encoding it") {
        linearBlending = true
        linearBlending = false
        let a = color(1.5, 0.5, -0.2), b = color(0, 0, 0)
        try eqC(mix(a, b, 0), color(1, 0.5, 0), "mix(a, b, 0)")
        try eqC(mix(a, b, 0.5), color(0.2140, 0.1113, 0.0000), "mix(a, b, 0.5)")
    }
    scenario("The ends of a mix are its inputs either way, when they're in range") {
        linearBlending = true
        linearBlending = false
        let a = color(0.7, 0, 0), b = color(0, 0.3, 0.02)
        try eqC(mix(a, b, 0), a, "mix(a, b, 0)")
        try eqC(mix(a, b, 1), b, "mix(a, b, 1)")
    }
    linearBlending = true

    // ============================================== chapter01-limits.feature
    feature("The edges of the range")

    scenario("A 256-step ramp") {
        let c = ramp()
        try eqI(c.width, 256, "c.width")
        try eqI(c.height, 32, "c.height")
        try eqC(pixelAt(c, 0, 0), color(0, 0, 0), "pixel_at(c, 0, 0)")
        try eqC(pixelAt(c, 128, 0), color(0.5020, 0.5020, 0.5020), "pixel_at(c, 128, 0)")
        try eqC(pixelAt(c, 255, 31), color(1, 1, 1), "pixel_at(c, 255, 31)")
    }
    scenario("Encoding stretches the dark end and squeezes the bright end") {
        let ppm = canvasToPPM(ramp())
        let l = lines(ppm)
        let want = "0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46"
        try step(l[3] == want, "line 4 is \"\(l[3])\"")
        try eqPx(ppmPixel(ppm, 75, 0), (148, 148, 148), 0, "ppm_pixel(ppm, 75, 0)")
        try eqPx(ppmPixel(ppm, 76, 0), (148, 148, 148), 0, "ppm_pixel(ppm, 76, 0)")
        try eqPx(ppmPixel(ppm, 254, 0), (255, 255, 255), 0, "ppm_pixel(ppm, 254, 0)")
        try eqI(distinctValues(ppm), 183, "distinct_values(ppm)")
        let ref = readFile("reference/chapter-01/ramp.ppm")
        let d = maxChannelDifference(ppm, ref)
        try step(d <= 1, "max_channel_difference(ppm, ref) = \(d)")
    }
    scenario("Clamping changes the color, not only the brightness") {
        let c = clampPair()
        try eqI(c.width, 200, "c.width")
        try eqI(c.height, 100, "c.height")
        try eqC(pixelAt(c, 50, 50), color(2, 0.5, 0.5), "pixel_at(c, 50, 50)")
        try eqC(pixelAt(c, 150, 50), color(1, 0.25, 0.25), "pixel_at(c, 150, 50)")
        let ppm = canvasToPPM(c)
        try eqPx(ppmPixel(ppm, 50, 50), (255, 188, 188), 0, "ppm_pixel(ppm, 50, 50)")
        try eqPx(ppmPixel(ppm, 150, 50), (255, 137, 137), 0, "ppm_pixel(ppm, 150, 50)")
        let ref = readFile("reference/chapter-01/clamp-pair.ppm")
        let d = maxChannelDifference(ppm, ref)
        try step(d <= 1, "max_channel_difference(ppm, ref) = \(d)")
    }

    // =============================================== chapter01-plate.feature
    feature("Plate 1")

    scenario("The plate") {
        linearBlending = true
        let c = plate01()
        try eqI(c.width, 400, "c.width")
        try eqI(c.height, 180, "c.height")
        let ppm = canvasToPPM(c)
        try eqPx(ppmPixel(ppm, 0, 20), (0, 0, 0), 0, "ppm_pixel(ppm, 0, 20)")
        try eqPx(ppmPixel(ppm, 399, 20), (255, 255, 255), 0, "ppm_pixel(ppm, 399, 20)")
        try eqPx(ppmPixel(ppm, 200, 20), (128, 128, 128), 1, "ppm_pixel(ppm, 200, 20)")
        try eqPx(ppmPixel(ppm, 200, 65), (188, 188, 188), 1, "ppm_pixel(ppm, 200, 65)")
        try eqPx(ppmPixel(ppm, 200, 42), (0, 0, 0), 0, "ppm_pixel(ppm, 200, 42)")
        try eqPx(ppmPixel(ppm, 0, 110), (218, 0, 0), 0, "ppm_pixel(ppm, 0, 110)")
        try eqPx(ppmPixel(ppm, 399, 110), (0, 149, 39), 0, "ppm_pixel(ppm, 399, 110)")
        try eqPx(ppmPixel(ppm, 200, 110), (109, 75, 19), 1, "ppm_pixel(ppm, 200, 110)")
        try eqPx(ppmPixel(ppm, 200, 155), (160, 108, 26), 1, "ppm_pixel(ppm, 200, 155)")
        try eqPx(ppmPixel(ppm, 200, 87), (0, 0, 0), 0, "ppm_pixel(ppm, 200, 87)")
        let ref = readFile("reference/chapter-01/plate-01.ppm")
        let d = maxChannelDifference(ppm, ref)
        try step(d <= 1, "max_channel_difference(ppm, ref) = \(d)")
    }
    scenario("The switch was left on") {
        linearBlending = true
        let c = plate01()
        try step(c.width == 400, "plate_01() did not run")   // keep the call alive under -O
        try step(linearBlending, "linear blending is off after plate_01()")
    }

    chapter(2)
    // ============================================== chapter02-shapes.feature
    feature("Shapes are questions")

    scenario("A point inside a circle") {
        let s = circle(8, 8, 5)
        try eqBool(inside(s, 8, 8), true, "inside(s, 8, 8)")
        try eqBool(inside(s, 12, 8), true, "inside(s, 12, 8)")
        try eqBool(inside(s, 13, 8), true, "inside(s, 13, 8)")
        try eqBool(inside(s, 13.01, 8), false, "inside(s, 13.01, 8)")
        try eqBool(inside(s, 11.6, 11.6), false, "inside(s, 11.6, 11.6)")
    }
    scenario("A point inside a rectangle") {
        let s = rectangle(1.25, 2.0, 4.75, 5.0)
        try eqBool(inside(s, 3, 3), true, "inside(s, 3, 3)")
        try eqBool(inside(s, 1.25, 2.0), true, "inside(s, 1.25, 2.0)")
        try eqBool(inside(s, 4.75, 5.0), true, "inside(s, 4.75, 5.0)")
        try eqBool(inside(s, 1.2, 3), false, "inside(s, 1.2, 3)")
        try eqBool(inside(s, 3, 5.1), false, "inside(s, 3, 5.1)")
    }
    scenario("A point inside a half-plane") {
        let s = halfPlane(2.5, 0, 1, 0)
        try eqBool(inside(s, 2.5, 7), true, "inside(s, 2.5, 7)")
        try eqBool(inside(s, 3, -4), true, "inside(s, 3, -4)")
        try eqBool(inside(s, 2.4, 0), false, "inside(s, 2.4, 0)")
    }
    scenario("The normal picks the side") {
        let s = halfPlane(2.5, 0, -1, 0)
        try eqBool(inside(s, 2.4, 0), true, "inside(s, 2.4, 0)")
        try eqBool(inside(s, 3, 0), false, "inside(s, 3, 0)")
    }

    // ================================================= chapter02-p6.feature
    feature("Binary PPM")

    scenario("The header, then the bytes") {
        let c = canvas(2, 1)
        writePixel(c, 0, 0, color(1, 0, 0))
        writePixel(c, 1, 0, color(0, 0.5, 0))
        let p6 = canvasToP6(c)
        try beginsWith(p6, "P6\n2 1\n255\n", "p6")
        try eqI(p6.count, 17, "length(p6)")
        try eqI(Int(p6[11]), 255, "byte 12 of p6")     // the feature counts from 1
        try eqI(Int(p6[12]), 0, "byte 13 of p6")
        try eqI(Int(p6[15]), 188, "byte 16 of p6")
    }
    scenario("The same pixel comes back out of either format") {
        let c = canvas(2, 1)
        writePixel(c, 1, 0, color(0, 0.5, 0))
        let p3 = canvasToPPM(c)
        let p6 = canvasToP6(c)
        try eqPx(ppmPixel(p6, 1, 0), (0, 188, 0), 0, "ppm_pixel(p6, 1, 0)")
        try eqPx(ppmPixel(p3, 1, 0), (0, 188, 0), 0, "ppm_pixel(p3, 1, 0)")
        try eqI(maxChannelDifference(p3, p6), 0, "max_channel_difference(p3, p6)")
        try eqI(distinctValues(p6), 2, "distinct_values(p6)")
    }
    scenario("Rows go top to bottom") {
        let c = canvas(1, 2)
        writePixel(c, 0, 0, color(1, 0, 0))
        writePixel(c, 0, 1, color(0, 0, 1))
        let p6 = canvasToP6(c)
        try eqI(Int(p6[11]), 255, "byte 12 of p6")
        try eqI(Int(p6[16]), 255, "byte 17 of p6")
        try eqPx(ppmPixel(p6, 0, 0), (255, 0, 0), 0, "ppm_pixel(p6, 0, 0)")
        try eqPx(ppmPixel(p6, 0, 1), (0, 0, 255), 0, "ppm_pixel(p6, 0, 1)")
    }
    scenario("The binary writer clamps too") {
        let c = canvas(2, 1)
        writePixel(c, 0, 0, color(1.5, 0, -0.5))
        let p6 = canvasToP6(c)
        try eqI(Int(p6[11]), 255, "byte 12 of p6")
        try eqI(Int(p6[12]), 0, "byte 13 of p6")
        try eqI(Int(p6[13]), 0, "byte 14 of p6")
        try eqPx(ppmPixel(p6, 0, 0), (255, 0, 0), 0, "ppm_pixel(p6, 0, 0)")
    }
    scenario("Pixel bytes that look like whitespace are still pixel bytes") {
        let c = canvas(2, 1)
        writePixel(c, 0, 0, color(0.00304, 0.01444, 0.00304))
        writePixel(c, 1, 0, color(1, 1, 1))
        let p6 = canvasToP6(c)
        try eqI(p6.count, 17, "length(p6)")
        try eqI(Int(p6[11]), 10, "byte 12 of p6")
        try eqI(Int(p6[12]), 32, "byte 13 of p6")
        try eqPx(ppmPixel(p6, 0, 0), (10, 32, 10), 0, "ppm_pixel(p6, 0, 0)")
        try eqPx(ppmPixel(p6, 1, 0), (255, 255, 255), 0, "ppm_pixel(p6, 1, 0)")
        try eqI(maxChannelDifference(canvasToPPM(c), p6), 0, "max_channel_difference(canvas_to_ppm(c), p6)")
    }
    scenario("Sizes still have to match") {
        let p6a = canvasToP6(canvas(2, 1))
        let p6b = canvasToP6(canvas(1, 2))
        try eqI(maxChannelDifference(p6a, p6b), 255, "max_channel_difference(p6a, p6b)")
    }

    // ============================================ chapter02-magnify.feature
    feature("Magnify")

    scenario("Every pixel becomes a block") {
        let c = canvas(2, 1)
        writePixel(c, 0, 0, color(1, 0, 0))
        writePixel(c, 1, 0, color(0, 0.5, 0))
        let m = magnify(c, 3)
        try eqI(m.width, 6, "m.width")
        try eqI(m.height, 3, "m.height")
        try eqC(pixelAt(m, 0, 0), color(1, 0, 0), "pixel_at(m, 0, 0)")
        try eqC(pixelAt(m, 2, 2), color(1, 0, 0), "pixel_at(m, 2, 2)")
        try eqC(pixelAt(m, 3, 0), color(0, 0.5, 0), "pixel_at(m, 3, 0)")
        try eqC(pixelAt(m, 5, 2), color(0, 0.5, 0), "pixel_at(m, 5, 2)")
        try eqI(m.count(of: color(1, 0, 0)), 9, "pixels of m that are color(1, 0, 0)")
    }
    scenario("Magnifying by one changes nothing") {
        let c = canvas(2, 1)
        writePixel(c, 1, 0, color(0, 0.5, 0))
        let m = magnify(c, 1)
        try eqI(maxChannelDifference(canvasToP6(c), canvasToP6(m)), 0,
                "max_channel_difference(canvas_to_p6(c), canvas_to_p6(m))")
    }

    // ============================================ chapter02-centers.feature
    feature("The coverage buffer, and the first question")

    scenario("A new coverage buffer is empty") {
        let cov = coverageBuffer(4, 3)
        try eqI(cov.width, 4, "cov.width")
        try eqI(cov.height, 3, "cov.height")
        try eq(coverageAt(cov, 2, 1), 0, EPSILON, "coverage_at(cov, 2, 1)")
        try eq(ink(cov), 0, EPSILON, "ink(cov)")
    }
    scenario("Setting coverage") {
        let cov = coverageBuffer(4, 3)
        setCoverage(cov, 2, 1, 0.75)
        try eq(coverageAt(cov, 2, 1), 0.75, EPSILON, "coverage_at(cov, 2, 1)")
        try eq(coverageAt(cov, 1, 2), 0, EPSILON, "coverage_at(cov, 1, 2)")
        try eq(ink(cov), 0.75, EPSILON, "ink(cov)")
    }
    scenario("Setting coverage outside the buffer is ignored, and reading it gives 0") {
        let cov = coverageBuffer(4, 3)
        setCoverage(cov, -1, 1, 1)
        setCoverage(cov, 4, 1, 1)
        setCoverage(cov, 1, 3, 1)
        try eq(ink(cov), 0, EPSILON, "ink(cov)")
        try eq(coverageAt(cov, -1, 1), 0, EPSILON, "coverage_at(cov, -1, 1)")
        try eq(coverageAt(cov, 4, 1), 0, EPSILON, "coverage_at(cov, 4, 1)")
        try eq(coverageAt(cov, 1, 3), 0, EPSILON, "coverage_at(cov, 1, 3)")
    }
    scenario("The center of pixel (x, y) is (x + 0.5, y + 0.5)") {
        let s = halfPlane(2.5, 0, 1, 0)
        try eq(centerInside(s, 2, 4), 1, EPSILON, "center_inside(s, 2, 4)")
        try eq(centerInside(s, 1, 4), 0, EPSILON, "center_inside(s, 1, 4)")
        let t = halfPlane(2.6, 0, 1, 0)
        try eq(centerInside(t, 2, 4), 0, EPSILON, "center_inside(t, 2, 4)")
    }
    scenario("The center question is not \"at least half\"") {
        let s = halfPlane(2.55, 0, 1, 0)
        try eq(centerInside(s, 2, 4), 0, EPSILON, "center_inside(s, 2, 4)")
        try eq(coverage(s, 2, 4), 0.5, EPSILON, "coverage(s, 2, 4)")
    }
    scenario("A buffer need not be square") {
        let s = rectangle(0, 0, 2, 1)
        let cov = rasterizeCenters(s, 4, 2)
        try eqI(cov.width, 4, "cov.width")
        try eqI(cov.height, 2, "cov.height")
        try eq(coverageAt(cov, 1, 0), 1, EPSILON, "coverage_at(cov, 1, 0)")
        try eq(coverageAt(cov, 0, 1), 0, EPSILON, "coverage_at(cov, 0, 1)")
        try eq(ink(cov), 2, EPSILON, "ink(cov)")
    }
    scenario("A rectangle, by asking each center") {
        let s = rectangle(1.25, 2.0, 4.75, 5.0)
        let cov = rasterizeCenters(s, 8, 8)
        try eq(coverageAt(cov, 1, 4), 1, EPSILON, "coverage_at(cov, 1, 4)")
        try eq(coverageAt(cov, 4, 1), 0, EPSILON, "coverage_at(cov, 4, 1)")
        try eq(coverageAt(cov, 4, 4), 1, EPSILON, "coverage_at(cov, 4, 4)")
        try eq(coverageAt(cov, 0, 3), 0, EPSILON, "coverage_at(cov, 0, 3)")
        try eq(coverageAt(cov, 5, 3), 0, EPSILON, "coverage_at(cov, 5, 3)")
        try eq(coverageAt(cov, 2, 1), 0, EPSILON, "coverage_at(cov, 2, 1)")
        try eq(coverageAt(cov, 2, 5), 0, EPSILON, "coverage_at(cov, 2, 5)")
        try eq(ink(cov), 12, EPSILON, "ink(cov)")
    }
    scenario("A disc, by asking each center") {
        let s = circle(8, 8, 5)
        let cov = rasterizeCenters(s, 16, 16)
        try eqI(cov.width, 16, "cov.width")
        try eqI(cov.height, 16, "cov.height")
        try eq(coverageAt(cov, 8, 8), 1, EPSILON, "coverage_at(cov, 8, 8)")
        try eq(coverageAt(cov, 3, 8), 1, EPSILON, "coverage_at(cov, 3, 8)")
        try eq(coverageAt(cov, 12, 8), 1, EPSILON, "coverage_at(cov, 12, 8)")
        try eq(coverageAt(cov, 2, 8), 0, EPSILON, "coverage_at(cov, 2, 8)")
        try eq(coverageAt(cov, 13, 8), 0, EPSILON, "coverage_at(cov, 13, 8)")
        try eq(coverageAt(cov, 4, 4), 1, EPSILON, "coverage_at(cov, 4, 4)")
        try eq(coverageAt(cov, 3, 4), 0, EPSILON, "coverage_at(cov, 3, 4)")
        try eq(ink(cov), 80, EPSILON, "ink(cov)")
    }

    // ============================================== chapter02-paint.feature
    feature("Painting through coverage")

    scenario("Half coverage is half the paint") {
        linearBlending = true
        let c = canvas(1, 1)
        let cov = coverageBuffer(1, 1)
        setCoverage(cov, 0, 0, 0.5)
        paintThrough(c, cov, color(1, 1, 1))
        try eqC(pixelAt(c, 0, 0), color(0.5, 0.5, 0.5), "pixel_at(c, 0, 0)")
    }
    scenario("Paint over something that isn't black") {
        linearBlending = true
        let c = canvas(1, 1)
        let cov = coverageBuffer(1, 1)
        fill(c, color(0.2, 0.2, 0.2))
        setCoverage(cov, 0, 0, 0.25)
        paintThrough(c, cov, color(1, 0, 0))
        try eqC(pixelAt(c, 0, 0), color(0.4, 0.15, 0.15), "pixel_at(c, 0, 0)")
    }
    scenario("Zero leaves it alone and one replaces it") {
        linearBlending = true
        let c = canvas(2, 1)
        let cov = coverageBuffer(2, 1)
        fill(c, color(0.2, 0.2, 0.2))
        setCoverage(cov, 1, 0, 1)
        paintThrough(c, cov, color(1, 0, 0))
        try eqC(pixelAt(c, 0, 0), color(0.2, 0.2, 0.2), "pixel_at(c, 0, 0)")
        try eqC(pixelAt(c, 1, 0), color(1, 0, 0), "pixel_at(c, 1, 0)")
    }
    scenario("The arithmetic is on light, whatever the switch says") {
        linearBlending = false
        let c = canvas(1, 1)
        let cov = coverageBuffer(1, 1)
        setCoverage(cov, 0, 0, 0.5)
        paintThrough(c, cov, color(1, 1, 1))
        let ppm = canvasToPPM(c)
        try eqC(pixelAt(c, 0, 0), color(0.5, 0.5, 0.5), "pixel_at(c, 0, 0)")
        try eqPx(ppmPixel(ppm, 0, 0), (188, 188, 188), 0, "ppm_pixel(ppm, 0, 0)")
        linearBlending = true
    }
    scenario("The disc by centers") {
        linearBlending = true
        let c = discCenters()
        let ref = readFile("reference/chapter-02/disc-centers.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 320, "c.width")
        try eqI(c.height, 320, "c.height")
        try eqPx(ppmPixel(p6, 160, 160), (243, 196, 89), 1, "ppm_pixel(p6, 160, 160)")
        try eqPx(ppmPixel(p6, 124, 36), (39, 39, 44), 1, "ppm_pixel(p6, 124, 36)")
        try eqPx(ppmPixel(p6, 132, 36), (243, 196, 89), 1, "ppm_pixel(p6, 132, 36)")
        try eqI(distinctValues(p6), 5, "distinct_values(p6)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }

    // =========================================== chapter02-coverage.feature
    feature("The better question")

    scenario("The sixty-four sample points") {
        let s = halfPlane(2.5, 0, 1, 0)
        try eq(coverage(s, 2, 4), 0.5, EPSILON, "coverage(s, 2, 4)")
        try eq(coverage(s, 1, 4), 0, EPSILON, "coverage(s, 1, 4)")
        try eq(coverage(s, 3, 4), 1, EPSILON, "coverage(s, 3, 4)")
    }
    scenario("A rectangle is covered exactly, when its edges land on sample boundaries") {
        let s = rectangle(1.25, 2.0, 4.75, 5.0)
        let cov = rasterize(s, 8, 8)
        try eq(coverageAt(cov, 0, 2), 0, EPSILON, "coverage_at(cov, 0, 2)")
        try eq(coverageAt(cov, 1, 2), 0.75, EPSILON, "coverage_at(cov, 1, 2)")
        try eq(coverageAt(cov, 2, 2), 1, EPSILON, "coverage_at(cov, 2, 2)")
        try eq(coverageAt(cov, 3, 2), 1, EPSILON, "coverage_at(cov, 3, 2)")
        try eq(coverageAt(cov, 4, 2), 0.75, EPSILON, "coverage_at(cov, 4, 2)")
        try eq(coverageAt(cov, 5, 2), 0, EPSILON, "coverage_at(cov, 5, 2)")
        try eq(coverageAt(cov, 2, 1), 0, EPSILON, "coverage_at(cov, 2, 1)")
        try eq(coverageAt(cov, 2, 5), 0, EPSILON, "coverage_at(cov, 2, 5)")
        try eq(ink(cov), 10.5, EPSILON, "ink(cov)")
    }
    scenario("Neither need the buffer be square here") {
        let s = rectangle(0, 0, 2, 1)
        let cov = rasterize(s, 4, 2)
        try eqI(cov.width, 4, "cov.width")
        try eqI(cov.height, 2, "cov.height")
        try eq(coverageAt(cov, 1, 0), 1, EPSILON, "coverage_at(cov, 1, 0)")
        try eq(coverageAt(cov, 2, 0), 0, EPSILON, "coverage_at(cov, 2, 0)")
        try eq(coverageAt(cov, 0, 1), 0, EPSILON, "coverage_at(cov, 0, 1)")
        try eq(ink(cov), 2, EPSILON, "ink(cov)")
    }
    scenario("A half-plane through a pixel center covers half of it") {
        let s = halfPlane(2.5, 4.5, 0.6, 0.8)
        try eq(coverage(s, 2, 4), 0.5, EPSILON, "coverage(s, 2, 4)")
    }
    scenario("Except when the grid conspires") {
        let s = halfPlane(2.5, 4.5, 1, 1)
        try eq(coverage(s, 2, 4), 0.5625, EPSILON, "coverage(s, 2, 4)")
    }
    scenario("A disc is only ever approximately covered") {
        let s = circle(8, 8, 5)
        let cov = rasterize(s, 16, 16)
        try eq(coverageAt(cov, 8, 8), 1, EPSILON, "coverage_at(cov, 8, 8)")
        try eq(coverageAt(cov, 3, 8), 0.96875, EPSILON, "coverage_at(cov, 3, 8)")
        try eq(coverageAt(cov, 12, 8), 0.96875, EPSILON, "coverage_at(cov, 12, 8)")
        try eq(coverageAt(cov, 4, 4), 0.5625, EPSILON, "coverage_at(cov, 4, 4)")
        try eq(coverageAt(cov, 3, 4), 0, EPSILON, "coverage_at(cov, 3, 4)")
        try eq(ink(cov), 78.5, EPSILON, "ink(cov)")
        try eq(ink(cov), 78.5398, 0.1, "ink(cov) = 78.5398 ± 0.1")
    }
    scenario("The disc by coverage") {
        linearBlending = true
        let c = discCoverage()
        let ref = readFile("reference/chapter-02/disc-coverage.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 320, "c.width")
        try eqI(c.height, 320, "c.height")
        try eqPx(ppmPixel(p6, 160, 160), (243, 196, 89), 1, "ppm_pixel(p6, 160, 160)")
        try eqPx(ppmPixel(p6, 124, 36), (157, 127, 64), 1, "ppm_pixel(p6, 124, 36)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }

    // ============================================== chapter02-twice.feature
    feature("Coverage is not opacity")

    scenario("Half coverage, painted twice, is three quarters") {
        linearBlending = true
        let c = canvas(1, 1)
        let cov = coverageBuffer(1, 1)
        setCoverage(cov, 0, 0, 0.5)
        paintThrough(c, cov, color(1, 1, 1))
        paintThrough(c, cov, color(1, 1, 1))
        try eqC(pixelAt(c, 0, 0), color(0.75, 0.75, 0.75), "pixel_at(c, 0, 0)")
    }
    scenario("The disc, once and twice") {
        linearBlending = true
        let c = paintedTwice()
        let ref = readFile("reference/chapter-02/painted-twice.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 480, "c.width")
        try eqI(c.height, 240, "c.height")
        try eqPx(ppmPixel(p6, 120, 120), (243, 196, 89), 1, "ppm_pixel(p6, 120, 120)")
        try eqPx(ppmPixel(p6, 360, 120), (243, 196, 89), 1, "ppm_pixel(p6, 360, 120)")
        try eqPx(ppmPixel(p6, 93, 27), (157, 127, 64), 1, "ppm_pixel(p6, 93, 27)")
        try eqPx(ppmPixel(p6, 333, 27), (194, 156, 74), 1, "ppm_pixel(p6, 333, 27)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }

    // ============================================== chapter02-plate.feature
    feature("Plate 2")

    scenario("The plate") {
        linearBlending = true
        let c = plate02()
        let ref = readFile("reference/chapter-02/plate-02.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 480, "c.width")
        try eqI(c.height, 240, "c.height")
        try eqPx(ppmPixel(p6, 120, 120), (243, 196, 89), 1, "ppm_pixel(p6, 120, 120)")
        try eqPx(ppmPixel(p6, 360, 120), (243, 196, 89), 1, "ppm_pixel(p6, 360, 120)")
        try eqPx(ppmPixel(p6, 93, 27), (39, 39, 44), 1, "ppm_pixel(p6, 93, 27)")
        try eqPx(ppmPixel(p6, 333, 27), (157, 127, 64), 1, "ppm_pixel(p6, 333, 27)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }

    chapter(3)
    // =========================================== chapter03-bresenham.feature
    feature("Bresenham's line")

    scenario("lit_pixels reads like a page") {
        let c = canvas(10, 10)
        writePixel(c, 5, 0, color(1, 1, 1))
        writePixel(c, 0, 2, color(1, 1, 1))
        writePixel(c, 2, 2, color(0.5, 0, 0))
        try eqPts(litPixels(c), [(5, 0), (0, 2), (2, 2)], "lit_pixels(c)")
    }
    scenario("A diagonal") {
        let c = canvas(10, 10)
        lineBresenham(c, 0, 0, 5, 5, color(1, 1, 1))
        try eqPts(litPixels(c), [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)], "lit_pixels(c)")
    }
    scenario("A horizontal line lights one row and nothing else") {
        let c = canvas(10, 10)
        lineBresenham(c, 0, 3, 7, 3, color(1, 1, 1))
        try eqPts(litPixels(c), [(0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3)], "lit_pixels(c)")
    }
    scenario("A shallow line steps along x") {
        let c = canvas(10, 10)
        lineBresenham(c, 0, 0, 7, 3, color(1, 1, 1))
        try eqPts(litPixels(c), [(0, 0), (1, 0), (2, 1), (3, 1), (4, 2), (5, 2), (6, 3), (7, 3)], "lit_pixels(c)")
    }
    scenario("A steep line steps along y") {
        let c = canvas(10, 10)
        lineBresenham(c, 1, 1, 3, 7, color(1, 1, 1))
        try eqPts(litPixels(c), [(1, 1), (1, 2), (2, 3), (2, 4), (2, 5), (3, 6), (3, 7)], "lit_pixels(c)")
    }
    scenario("The pixels don't depend on which end you start from") {
        let c1 = canvas(10, 10), c2 = canvas(10, 10)
        lineBresenham(c1, 1, 1, 3, 7, color(1, 1, 1))
        lineBresenham(c2, 3, 7, 1, 1, color(1, 1, 1))
        try eqPts(litPixels(c1), litPixels(c2), "lit_pixels(c1) = lit_pixels(c2)")
        try eqI(maxChannelDifference(canvasToP6(c1), canvasToP6(c2)), 0,
                "max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2))")
    }
    scenario("A line going up and to the right") {
        let c = canvas(10, 10)
        lineBresenham(c, 0, 6, 7, 3, color(1, 1, 1))
        try eqPts(litPixels(c), [(6, 3), (7, 3), (4, 4), (5, 4), (2, 5), (3, 5), (0, 6), (1, 6)], "lit_pixels(c)")
    }
    scenario("At an exact half the line stays on its row one step longer") {
        let c = canvas(10, 10)
        lineBresenham(c, 0, 0, 4, 2, color(1, 1, 1))
        try eqPts(litPixels(c), [(0, 0), (1, 0), (2, 1), (3, 1), (4, 2)], "lit_pixels(c)")
    }
    scenario("A line of one point") {
        let c = canvas(10, 10)
        lineBresenham(c, 3, 3, 3, 3, color(1, 1, 1))
        try eqPts(litPixels(c), [(3, 3)], "lit_pixels(c)")
    }
    scenario("A line may run off the canvas") {
        let c = canvas(10, 10)
        lineBresenham(c, 0, 0, 12, 6, color(1, 1, 1))
        try eqI(litPixels(c).count, 10, "length(lit_pixels(c))")
    }

    // ================================================ chapter03-wu.feature
    feature("Wu's line")

    scenario("A half step lights two pixels equally") {
        let c = canvas(10, 10)
        lineWu(c, 0, 0, 4, 2, color(1, 1, 1))
        try eqC(pixelAt(c, 0, 0), color(1, 1, 1), "pixel_at(c, 0, 0)")
        try eqC(pixelAt(c, 1, 0), color(0.5, 0.5, 0.5), "pixel_at(c, 1, 0)")
        try eqC(pixelAt(c, 1, 1), color(0.5, 0.5, 0.5), "pixel_at(c, 1, 1)")
        try eqC(pixelAt(c, 2, 1), color(1, 1, 1), "pixel_at(c, 2, 1)")
        try eqC(pixelAt(c, 2, 2), color(0, 0, 0), "pixel_at(c, 2, 2)")
        try eqC(pixelAt(c, 4, 2), color(1, 1, 1), "pixel_at(c, 4, 2)")
        try eq(totalInk(c), 5, EPSILON, "total_ink(c)")
    }
    scenario("The weights are applied in light, whatever the switch says") {
        linearBlending = false
        let c = canvas(10, 10)
        lineWu(c, 0, 0, 4, 2, color(1, 1, 1))
        try eqC(pixelAt(c, 1, 0), color(0.5, 0.5, 0.5), "pixel_at(c, 1, 0)")
        try eqC(pixelAt(c, 1, 1), color(0.5, 0.5, 0.5), "pixel_at(c, 1, 1)")
        linearBlending = true
    }
    scenario("A diagonal has uniform weights") {
        let c = canvas(10, 10)
        lineWu(c, 0, 0, 5, 5, color(1, 1, 1))
        try eqPts(litPixels(c), [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)], "lit_pixels(c)")
        try eqC(pixelAt(c, 3, 3), color(1, 1, 1), "pixel_at(c, 3, 3)")
        try eq(totalInk(c), 6, EPSILON, "total_ink(c)")
    }
    scenario("A horizontal line has weight 1 on its row and 0 on the neighbors") {
        let c = canvas(10, 10)
        lineWu(c, 0, 3, 7, 3, color(1, 1, 1))
        try eqPts(litPixels(c), [(0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3)], "lit_pixels(c)")
        try eqC(pixelAt(c, 3, 3), color(1, 1, 1), "pixel_at(c, 3, 3)")
        try eqC(pixelAt(c, 3, 2), color(0, 0, 0), "pixel_at(c, 3, 2)")
        try eqC(pixelAt(c, 3, 4), color(0, 0, 0), "pixel_at(c, 3, 4)")
        try eq(totalInk(c), 8, EPSILON, "total_ink(c)")
    }
    scenario("A steep line weights across columns") {
        let c = canvas(10, 10)
        lineWu(c, 1, 1, 3, 7, color(1, 1, 1))
        try eqC(pixelAt(c, 1, 1), color(1, 1, 1), "pixel_at(c, 1, 1)")
        try eqC(pixelAt(c, 1, 2), color(0.6667, 0.6667, 0.6667), "pixel_at(c, 1, 2)")
        try eqC(pixelAt(c, 2, 2), color(0.3333, 0.3333, 0.3333), "pixel_at(c, 2, 2)")
        try eqC(pixelAt(c, 2, 4), color(1, 1, 1), "pixel_at(c, 2, 4)")
        try eqC(pixelAt(c, 3, 7), color(1, 1, 1), "pixel_at(c, 3, 7)")
        try eq(totalInk(c), 7, EPSILON, "total_ink(c)")
    }
    scenario("The weights don't depend on which end you start from") {
        let c1 = canvas(10, 10), c2 = canvas(10, 10)
        lineWu(c1, 1, 1, 3, 7, color(1, 1, 1))
        lineWu(c2, 3, 7, 1, 1, color(1, 1, 1))
        try eqI(maxChannelDifference(canvasToP6(c1), canvasToP6(c2)), 0,
                "max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2))")
    }
    scenario("A line that starts above the canvas") {
        let c = canvas(10, 10)
        lineWu(c, 0, -1, 8, 3, color(1, 1, 1))
        try eqC(pixelAt(c, 1, 0), color(0.5, 0.5, 0.5), "pixel_at(c, 1, 0)")
        try eqC(pixelAt(c, 2, 0), color(1, 1, 1), "pixel_at(c, 2, 0)")
        try eq(totalInk(c), 7.5, EPSILON, "total_ink(c)")
    }
    scenario("A Wu line of one point") {
        let c = canvas(10, 10)
        lineWu(c, 3, 3, 3, 3, color(1, 1, 1))
        try eqPts(litPixels(c), [(3, 3)], "lit_pixels(c)")
        try eqC(pixelAt(c, 3, 3), color(1, 1, 1), "pixel_at(c, 3, 3)")
    }
    scenario("Sevenths") {
        let c = canvas(10, 10)
        lineWu(c, 0, 0, 7, 3, color(1, 1, 1))
        try eqC(pixelAt(c, 1, 0), color(0.5714, 0.5714, 0.5714), "pixel_at(c, 1, 0)")
        try eqC(pixelAt(c, 1, 1), color(0.4286, 0.4286, 0.4286), "pixel_at(c, 1, 1)")
        try eqC(pixelAt(c, 2, 0), color(0.1429, 0.1429, 0.1429), "pixel_at(c, 2, 0)")
        try eqC(pixelAt(c, 2, 1), color(0.8571, 0.8571, 0.8571), "pixel_at(c, 2, 1)")
        try eq(totalInk(c), 8, EPSILON, "total_ink(c)")
    }
    let inkAngleRows: [(Int, Int, Double)] = [
        (12, 2, 11), (10, 8, 9), (8, 10, 9), (2, 12, 11),
    ]
    for (x1, y1, ink) in inkAngleRows {
        scenario("The ink depends on the angle [x1=\(x1), y1=\(y1), ink=\(ink)]") {
            let c = canvas(20, 20)
            lineWu(c, 2, 2, x1, y1, color(1, 1, 1))
            try eq(totalInk(c), ink, EPSILON, "total_ink(c)")
        }
    }

    // ============================================== chapter03-quad.feature
    feature("A line is a thin rectangle")

    scenario("Inside a thick line") {
        let s = thickLine(0, 0, 4, 0, 1)
        try eqBool(inside(s, 2.5, 0.5), true, "inside(s, 2.5, 0.5)")
        try eqBool(inside(s, 2.5, 1.0), true, "inside(s, 2.5, 1.0)")
        try eqBool(inside(s, 2.5, 1.01), false, "inside(s, 2.5, 1.01)")
        try eqBool(inside(s, 0.5, 0.5), true, "inside(s, 0.5, 0.5)")
        try eqBool(inside(s, 0.4, 0.5), false, "inside(s, 0.4, 0.5)")
        try eqBool(inside(s, 4.5, 0.5), true, "inside(s, 4.5, 0.5)")
        try eqBool(inside(s, 4.6, 0.5), false, "inside(s, 4.6, 0.5)")
    }
    scenario("A horizontal thick line covers its row, with half pixels at the ends") {
        let s = thickLine(0, 3, 7, 3, 1)
        let cov = rasterize(s, 10, 10)
        try eq(coverageAt(cov, 0, 3), 0.5, EPSILON, "coverage_at(cov, 0, 3)")
        try eq(coverageAt(cov, 1, 3), 1, EPSILON, "coverage_at(cov, 1, 3)")
        try eq(coverageAt(cov, 6, 3), 1, EPSILON, "coverage_at(cov, 6, 3)")
        try eq(coverageAt(cov, 7, 3), 0.5, EPSILON, "coverage_at(cov, 7, 3)")
        try eq(coverageAt(cov, 8, 3), 0, EPSILON, "coverage_at(cov, 8, 3)")
        try eq(coverageAt(cov, 3, 2), 0, EPSILON, "coverage_at(cov, 3, 2)")
        try eq(coverageAt(cov, 3, 4), 0, EPSILON, "coverage_at(cov, 3, 4)")
        try eq(ink(cov), 7, EPSILON, "ink(cov)")
    }
    scenario("A line of no length is a square") {
        let s = thickLine(3, 3, 3, 3, 1)
        let cov = rasterize(s, 8, 8)
        try eq(coverageAt(cov, 3, 3), 1, EPSILON, "coverage_at(cov, 3, 3)")
        try eq(ink(cov), 1, EPSILON, "ink(cov)")
    }
    scenario("A wider line") {
        let s = thickLine(0, 3, 7, 3, 3)
        let cov = rasterize(s, 10, 10)
        try eq(coverageAt(cov, 3, 2), 1, EPSILON, "coverage_at(cov, 3, 2)")
        try eq(coverageAt(cov, 3, 3), 1, EPSILON, "coverage_at(cov, 3, 3)")
        try eq(coverageAt(cov, 3, 4), 1, EPSILON, "coverage_at(cov, 3, 4)")
        try eq(coverageAt(cov, 3, 1), 0, EPSILON, "coverage_at(cov, 3, 1)")
        try eq(coverageAt(cov, 3, 5), 0, EPSILON, "coverage_at(cov, 3, 5)")
        try eq(coverageAt(cov, 0, 3), 0.5, EPSILON, "coverage_at(cov, 0, 3)")
        try eq(ink(cov), 21, EPSILON, "ink(cov)")
    }
    scenario("An off-axis line runs through pixel centers, not corners") {
        let s = thickLine(2, 2, 11, 5, 1)
        let cov = rasterize(s, 16, 10)
        try eq(coverageAt(cov, 2, 2), 0.484375, EPSILON, "coverage_at(cov, 2, 2)")
        try eq(coverageAt(cov, 11, 5), 0.484375, EPSILON, "coverage_at(cov, 11, 5)")
        try eq(coverageAt(cov, 6, 3), 0.6875, EPSILON, "coverage_at(cov, 6, 3)")
        try eq(coverageAt(cov, 7, 3), 0.359375, EPSILON, "coverage_at(cov, 7, 3)")
        try eq(coverageAt(cov, 2, 1), 0, EPSILON, "coverage_at(cov, 2, 1)")
        try eq(ink(cov), 9.4063, EPSILON, "ink(cov)")
    }
    let angleRows: [(Int, Int)] = [(12, 2), (10, 8), (8, 10), (2, 12)]
    for (x1, y1) in angleRows {
        scenario("The ink is the length, whatever the angle [x1=\(x1), y1=\(y1)]") {
            let s = thickLine(2, 2, x1, y1, 1)
            let cov = rasterize(s, 20, 20)
            try eq(ink(cov), 10, EPSILON, "ink(cov)")
        }
    }
    scenario("Except that the grid is blind along the diagonal") {
        let s = thickLine(2, 2, 9, 9, 1)
        let cov = rasterize(s, 20, 20)
        try eq(ink(cov), 9.71875, EPSILON, "ink(cov)")
        try eq(ink(cov), 9.8995, 0.25, "ink(cov) = 9.8995 ± 0.25")
    }

    // ============================================== chapter03-plate.feature
    feature("Plate 3")

    scenario("The ray endpoints") {
        try eqPts(rayEnds(),
                  [(152, 80), (142, 116), (116, 142), (80, 152), (44, 142), (18, 116),
                   (8, 80), (18, 44), (44, 18), (80, 8), (116, 18), (142, 44)],
                  "ray_ends()")
    }
    scenario("Bresenham's fan") {
        let c = fanBresenham()
        let ref = readFile("reference/chapter-03/fan-bresenham.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 160, "c.width")
        try eqI(c.height, 160, "c.height")
        try eqPx(ppmPixel(p6, 80, 80), (246, 246, 241), 1, "ppm_pixel(p6, 80, 80)")
        try eqPx(ppmPixel(p6, 120, 80), (246, 246, 241), 1, "ppm_pixel(p6, 120, 80)")
        try eqPx(ppmPixel(p6, 10, 10), (39, 39, 44), 1, "ppm_pixel(p6, 10, 10)")
        try eqPx(ppmPixel(p6, 100, 91), (39, 39, 44), 1, "ppm_pixel(p6, 100, 91)")
        try eqPx(ppmPixel(p6, 100, 92), (246, 246, 241), 1, "ppm_pixel(p6, 100, 92)")
        try eqPx(ppmPixel(p6, 103, 120), (246, 246, 241), 1, "ppm_pixel(p6, 103, 120)")
        try eqPx(ppmPixel(p6, 102, 120), (39, 39, 44), 1, "ppm_pixel(p6, 102, 120)")
        try eqPx(ppmPixel(p6, 104, 120), (39, 39, 44), 1, "ppm_pixel(p6, 104, 120)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }
    scenario("Wu's fan") {
        let c = fanWu()
        let ref = readFile("reference/chapter-03/fan-wu.ppm")
        let p6 = canvasToP6(c)
        try eqPx(ppmPixel(p6, 80, 80), (246, 246, 241), 1, "ppm_pixel(p6, 80, 80)")
        try eqPx(ppmPixel(p6, 120, 80), (246, 246, 241), 1, "ppm_pixel(p6, 120, 80)")
        try eqPx(ppmPixel(p6, 100, 91), (163, 163, 161), 1, "ppm_pixel(p6, 100, 91)")
        try eqPx(ppmPixel(p6, 100, 92), (199, 199, 196), 1, "ppm_pixel(p6, 100, 92)")
        try eqPx(ppmPixel(p6, 103, 120), (220, 220, 216), 1, "ppm_pixel(p6, 103, 120)")
        try eqPx(ppmPixel(p6, 104, 120), (130, 130, 129), 1, "ppm_pixel(p6, 104, 120)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }
    scenario("The fan as twelve thin rectangles") {
        let c = fanCoverage()
        let ref = readFile("reference/chapter-03/fan-coverage.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 320, "c.width")
        try eqI(c.height, 320, "c.height")
        try eqPx(ppmPixel(p6, 160, 160), (246, 246, 241), 1, "ppm_pixel(p6, 160, 160)")
        try eqPx(ppmPixel(p6, 10, 10), (39, 39, 44), 1, "ppm_pixel(p6, 10, 10)")
        try eqPx(ppmPixel(p6, 240, 160), (246, 246, 241), 1, "ppm_pixel(p6, 240, 160)")
        try eqPx(ppmPixel(p6, 240, 158), (39, 39, 44), 1, "ppm_pixel(p6, 240, 158)")
        try eqPx(ppmPixel(p6, 200, 183), (177, 177, 174), 1, "ppm_pixel(p6, 200, 183)")
        try eqPx(ppmPixel(p6, 200, 185), (209, 209, 205), 1, "ppm_pixel(p6, 200, 185)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }
    scenario("Plate 3") {
        let c = plate03()
        let ref = readFile("reference/chapter-03/plate-03.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 640, "c.width")
        try eqI(c.height, 320, "c.height")
        try eqPx(ppmPixel(p6, 160, 160), (246, 246, 241), 1, "ppm_pixel(p6, 160, 160)")
        try eqPx(ppmPixel(p6, 480, 160), (246, 246, 241), 1, "ppm_pixel(p6, 480, 160)")
        try eqPx(ppmPixel(p6, 10, 10), (39, 39, 44), 1, "ppm_pixel(p6, 10, 10)")
        try eqPx(ppmPixel(p6, 200, 183), (39, 39, 44), 1, "ppm_pixel(p6, 200, 183)")
        try eqPx(ppmPixel(p6, 200, 185), (246, 246, 241), 1, "ppm_pixel(p6, 200, 185)")
        try eqPx(ppmPixel(p6, 520, 183), (163, 163, 161), 1, "ppm_pixel(p6, 520, 183)")
        try eqPx(ppmPixel(p6, 520, 185), (199, 199, 196), 1, "ppm_pixel(p6, 520, 185)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }

    chapter(4)
    // =============================================== chapter04-tuples.feature
    feature("Points and vectors")

    scenario("A point has w = 1") {
        let p = point(4, -4)
        try eq(p.x, 4, EPSILON, "p.x")
        try eq(p.y, -4, EPSILON, "p.y")
        try eq(p.w, 1, EPSILON, "p.w")
    }
    scenario("A vector has w = 0") {
        let v = vector(4, -4)
        try eq(v.x, 4, EPSILON, "v.x")
        try eq(v.y, -4, EPSILON, "v.y")
        try eq(v.w, 0, EPSILON, "v.w")
    }
    scenario("The difference of two points is the vector between them") {
        let a = point(3, 2), b = point(5, 6)
        try eqT(b - a, vector(2, 4), "b - a")
        try eqT(a - b, vector(-2, -4), "a - b")
    }
    scenario("A point plus a vector is a point") {
        let p = point(3, -2), v = vector(-2, 3)
        try eqT(p + v, point(1, 1), "p + v")
        try eqT(p - v, point(5, -5), "p - v")
    }
    scenario("A vector plus a vector is a vector") {
        let a = vector(3, -2), b = vector(-2, 3)
        try eqT(a + b, vector(1, 1), "a + b")
        try eqT(a - b, vector(5, -5), "a - b")
    }
    scenario("Negating, scaling and dividing a vector") {
        let v = vector(1, -2)
        try eqT(-v, vector(-1, 2), "-v")
        try eqT(v * 3.5, vector(3.5, -7), "v * 3.5")
        try eqT(v * 0.5, vector(0.5, -1), "v * 0.5")
        try eqT(v / 2, vector(0.5, -1), "v / 2")
    }
    scenario("The magnitude of a vector") {
        try eq(magnitude(vector(1, 0)), 1, EPSILON, "magnitude(vector(1, 0))")
        try eq(magnitude(vector(0, 1)), 1, EPSILON, "magnitude(vector(0, 1))")
        try eq(magnitude(vector(3, 4)), 5, EPSILON, "magnitude(vector(3, 4))")
        try eq(magnitude(vector(-3, -4)), 5, EPSILON, "magnitude(vector(-3, -4))")
        try eq(magnitude(vector(-1, -2)), 2.2361, EPSILON, "magnitude(vector(-1, -2))")
    }
    scenario("Normalizing a vector") {
        try eqT(normalize(vector(4, 0)), vector(1, 0), "normalize(vector(4, 0))")
        try eqT(normalize(vector(1, 2)), vector(0.4472, 0.8944), "normalize(vector(1, 2))")
        try eq(magnitude(normalize(vector(1, 2))), 1, EPSILON, "magnitude(normalize(vector(1, 2)))")
    }
    scenario("The dot product of two vectors") {
        let a = vector(1, 2), b = vector(2, 3)
        try eq(dot(a, b), 8, EPSILON, "dot(a, b)")
        try eq(dot(a, vector(-2, 1)), 0, EPSILON, "dot(a, vector(-2, 1))")
    }
    scenario("magnitude and dot look at x and y only") {
        try eq(magnitude(point(3, 4)), 5, EPSILON, "magnitude(point(3, 4))")
        try eq(dot(point(1, 2), point(2, 3)), 8, EPSILON, "dot(point(1, 2), point(2, 3))")
    }
    scenario("The cross product of two vectors is a number") {
        let a = vector(1, 0), b = vector(0, 1)
        try eq(cross(a, b), 1, EPSILON, "cross(a, b)")
        try eq(cross(b, a), -1, EPSILON, "cross(b, a)")
        try eq(cross(a, a), 0, EPSILON, "cross(a, a)")
        try eq(cross(vector(2, 3), vector(4, 5)), -2, EPSILON, "cross(vector(2, 3), vector(4, 5))")
    }
    scenario("The sign of the cross product says which side of a line a point is on") {
        let a = point(0, 0), b = point(10, 0)
        try eq(cross(b - a, point(5, 3) - a), 30, EPSILON, "cross(b - a, point(5, 3) - a)")
        try eq(cross(b - a, point(5, -3) - a), -30, EPSILON, "cross(b - a, point(5, -3) - a)")
        try eq(cross(b - a, point(20, 0) - a), 0, EPSILON, "cross(b - a, point(20, 0) - a)")
    }

    // ============================================= chapter04-matrices.feature
    feature("Matrices")

    scenario("Constructing and inspecting a matrix") {
        let M = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
        try eq(M[0, 0], 1, EPSILON, "M[0, 0]")
        try eq(M[0, 2], 3, EPSILON, "M[0, 2]")
        try eq(M[1, 0], 4, EPSILON, "M[1, 0]")
        try eq(M[1, 1], 5, EPSILON, "M[1, 1]")
        try eq(M[2, 0], 7, EPSILON, "M[2, 0]")
        try eq(M[2, 2], 9, EPSILON, "M[2, 2]")
        try eqM(M, matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9), "M = matrix3(1..9)")
    }
    scenario("Matrix equality with identical matrices") {
        let A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
        let B = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
        try eqM(A, B, "A = B")
    }
    scenario("Matrix equality with different matrices") {
        let A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
        let B = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 8)
        try neM(A, B, "A != B")
    }
    scenario("Multiplying two matrices") {
        let A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
        let B = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2)
        try eqM(A * B, matrix3(4, 8, 8, 13, 17, 17, 22, 26, 26), "A * B")
    }
    scenario("Matrix multiplication is not commutative") {
        let A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
        let B = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2)
        try neM(A * B, B * A, "A * B != B * A")
    }
    scenario("A matrix multiplied by a point") {
        let A = matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1)
        let p = point(1, 2)
        try eqT(A * p, point(8, 20), "A * p")
    }
    scenario("A matrix multiplied by a vector ignores the last column") {
        let A = matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1)
        let v = vector(1, 2)
        try eqT(A * v, vector(5, 14), "A * v")
    }
    scenario("Multiplying by the identity matrix changes nothing") {
        let A = matrix3(0, 1, 2, 1, 2, 4, 2, 4, 8)
        let p = point(1, 2)
        try eqM(A * identity(), A, "A * identity()")
        try eqM(identity() * A, A, "identity() * A")
        try eqT(identity() * p, p, "identity() * p")
    }
    scenario("Transposing a matrix") {
        let A = matrix3(0, 9, 3, 9, 8, 0, 1, 8, 5)
        try eqM(transpose(A), matrix3(0, 9, 1, 9, 8, 8, 3, 0, 5), "transpose(A)")
    }
    scenario("Transposing the identity matrix") {
        try eqM(transpose(identity()), identity(), "transpose(identity())")
    }
    scenario("The determinant of a 3 by 3 matrix") {
        let A = matrix3(1, 2, 6, -5, 8, -4, 2, 6, 4)
        try eq(determinant(A), -196, EPSILON, "determinant(A)")
    }
    scenario("The determinant of a transform is the area factor") {
        try eq(determinant(identity()), 1, EPSILON, "determinant(identity())")
        try eq(determinant(scaling(2, 3)), 6, EPSILON, "determinant(scaling(2, 3))")
        try eq(determinant(rotation(0.7)), 1, EPSILON, "determinant(rotation(0.7))")
        try eq(determinant(translation(4, 9)), 1, EPSILON, "determinant(translation(4, 9))")
        try eq(determinant(scaling(-1, 1)), -1, EPSILON, "determinant(scaling(-1, 1))")
    }
    scenario("Testing an invertible matrix for invertibility") {
        let A = matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1)
        try eq(determinant(A), 10, EPSILON, "determinant(A)")
        try eqBool(isInvertible(A), true, "is_invertible(A)")
    }
    scenario("Testing a non-invertible matrix for invertibility") {
        let A = matrix3(1, 2, 3, 2, 4, 6, 0, 0, 1)
        try eq(determinant(A), 0, EPSILON, "determinant(A)")
        try eqBool(isInvertible(A), false, "is_invertible(A)")
    }
    scenario("Invertibility is an exact test against zero") {
        try eqBool(isInvertible(scaling(0.0001, 1)), true, "is_invertible(scaling(0.0001, 1))")
        try eq(determinant(scaling(0.0001, 1)), 0.0001, EPSILON, "determinant(scaling(0.0001, 1))")
        try eqT(inverse(scaling(0.0001, 1)) * point(0.0001, 3), point(1, 3), "inverse(scaling(0.0001, 1)) * point(0.0001, 3)")
    }
    scenario("Calculating the inverse of a matrix") {
        let A = matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1)
        let B = inverse(A)
        try eq(B[0, 0], 0.2, EPSILON, "B[0, 0]")
        try eq(B[1, 2], 1, EPSILON, "B[1, 2]")
        try eq(B[2, 1], -0.3, EPSILON, "B[2, 1]")
        try eqM(B, matrix3(0.2, 0.2, 0, -0.2, 0.3, 1, 0.2, -0.3, 0), "B is the following matrix")
        try eqM(A * B, identity(), "A * B = identity()")
    }
    scenario("Multiplying a product by its inverse") {
        let A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
        let B = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2)
        let C = A * B
        try eqM(C * inverse(B), A, "C * inverse(B)")
    }
    scenario("The inverse of a transform is a transform") {
        let A = translation(5, -3) * rotation(Double.pi / 6) * scaling(2, 3)
        let B = inverse(A)
        try eq(B[2, 0], 0, EPSILON, "B[2, 0]")
        try eq(B[2, 1], 0, EPSILON, "B[2, 1]")
        try eq(B[2, 2], 1, EPSILON, "B[2, 2]")
        try eq(B[0, 0], 0.4330, EPSILON, "B[0, 0]")
        try eq(B[0, 2], -1.4151, EPSILON, "B[0, 2]")
        try eq(B[1, 2], 1.6994, EPSILON, "B[1, 2]")
        try eqM(B * A, identity(), "B * A")
    }

    // =========================================== chapter04-transforms.feature
    feature("The transforms")

    scenario("Multiplying by a translation matrix") {
        let t = translation(5, -3), p = point(-3, 4)
        try eqT(t * p, point(2, 1), "t * p")
    }
    scenario("The inverse of a translation moves the other way") {
        let t = translation(5, -3), p = point(-3, 4)
        try eqT(inverse(t) * p, point(-8, 7), "inverse(t) * p")
    }
    scenario("Translation does not affect vectors") {
        let t = translation(5, -3), v = vector(-3, 4)
        try eqT(t * v, v, "t * v")
    }
    scenario("A scaling matrix applied to a point") {
        let s = scaling(2, 3), p = point(-4, 6)
        try eqT(s * p, point(-8, 18), "s * p")
    }
    scenario("A scaling matrix applied to a vector") {
        let s = scaling(2, 3), v = vector(-4, 6)
        try eqT(s * v, vector(-8, 18), "s * v")
    }
    scenario("The inverse of a scaling shrinks") {
        let s = scaling(2, 3), v = vector(-4, 6)
        try eqT(inverse(s) * v, vector(-2, 2), "inverse(s) * v")
    }
    scenario("Reflection is scaling by a negative value") {
        let s = scaling(-1, 1), p = point(2, 3)
        try eqT(s * p, point(-2, 3), "s * p")
    }
    scenario("A positive rotation turns x toward y") {
        let p = point(1, 0)
        try eqT(rotation(Double.pi / 4) * p, point(0.7071, 0.7071), "rotation(pi/4) * p")
        try eqT(rotation(Double.pi / 2) * p, point(0, 1), "rotation(pi/2) * p")
        try eqT(rotation(Double.pi) * p, point(-1, 0), "rotation(pi) * p")
    }
    scenario("The inverse of a rotation turns the other way") {
        let p = point(1, 0)
        try eqT(inverse(rotation(Double.pi / 4)) * p, point(0.7071, -0.7071), "inverse(rotation(pi/4)) * p")
        try eqT(rotation(-Double.pi / 4) * p, point(0.7071, -0.7071), "rotation(-pi/4) * p")
    }
    scenario("A rotation preserves length") {
        let v = vector(3, 4)
        try eq(magnitude(rotation(1.2) * v), 5, EPSILON, "magnitude(rotation(1.2) * v)")
        try eq(magnitude(rotation(-2.8) * v), 5, EPSILON, "magnitude(rotation(-2.8) * v)")
    }
    scenario("Shearing moves x in proportion to y") {
        let s = shearing(1, 0), p = point(2, 3)
        try eqT(s * p, point(5, 3), "s * p")
    }
    scenario("Shearing moves y in proportion to x") {
        let s = shearing(0, 1), p = point(2, 3)
        try eqT(s * p, point(2, 5), "s * p")
    }
    scenario("Individual transformations are applied in sequence") {
        let p = point(1, 0)
        let A = rotation(Double.pi / 2), B = scaling(5, 5), C = translation(10, 5)
        let p2 = A * p
        let p3 = B * p2
        let p4 = C * p3
        try eqT(p2, point(0, 1), "p2")
        try eqT(p3, point(0, 5), "p3")
        try eqT(p4, point(10, 10), "p4")
    }
    scenario("Chained transformations must be applied in reverse order") {
        let p = point(1, 0)
        let A = rotation(Double.pi / 2), B = scaling(5, 5), C = translation(10, 5)
        let T = C * B * A
        try eqT(T * p, point(10, 10), "T * p")
    }
    scenario("The other order is a different transform") {
        let p = point(1, 0)
        let A = rotation(Double.pi / 2), B = scaling(5, 5), C = translation(10, 5)
        let T = A * B * C
        try eqT(T * p, point(-25, 55), "T * p")
    }
    scenario("Rotating about a point that isn't the origin") {
        let T = translation(4, 4) * rotation(Double.pi / 2) * translation(-4, -4)
        try eqT(T * point(6, 4), point(4, 6), "T * point(6, 4)")
        try eqT(T * point(4, 4), point(4, 4), "T * point(4, 4)")
    }

    // =============================================== chapter04-scale.feature
    feature("How big is a transform")

    scenario("The identity, a translation and a rotation don't stretch") {
        try eq(approxScale(identity()), 1, EPSILON, "approx_scale(identity())")
        try eq(approxScale(translation(7, 9)), 1, EPSILON, "approx_scale(translation(7, 9))")
        try eq(approxScale(rotation(1.1)), 1, EPSILON, "approx_scale(rotation(1.1))")
    }
    scenario("A uniform scale is reported exactly") {
        try eq(approxScale(scaling(2, 2)), 2, EPSILON, "approx_scale(scaling(2, 2))")
        try eq(approxScale(scaling(0.5, 0.5)), 0.5, EPSILON, "approx_scale(scaling(0.5, 0.5))")
        try eq(approxScale(scaling(3, 3) * rotation(0.7)), 3, EPSILON, "approx_scale(scaling(3,3)*rotation(0.7))")
        try eq(approxScale(translation(5, 5) * scaling(3, 3)), 3, EPSILON, "approx_scale(translation(5,5)*scaling(3,3))")
    }
    scenario("A reflection is not a negative scale") {
        try eq(approxScale(scaling(-2, 2)), 2, EPSILON, "approx_scale(scaling(-2, 2))")
    }
    scenario("A non-uniform scale is reported as the geometric mean") {
        try eq(approxScale(scaling(4, 1)), 2, EPSILON, "approx_scale(scaling(4, 1))")
        try eq(approxScale(scaling(4, 1) * rotation(0.4)), 2, EPSILON, "approx_scale(scaling(4,1)*rotation(0.4))")
        try eq(approxScale(scaling(9, 1)), 3, EPSILON, "approx_scale(scaling(9, 1))")
    }
    scenario("A shear that preserves area reports 1") {
        try eq(approxScale(shearing(1, 0)), 1, EPSILON, "approx_scale(shearing(1, 0))")
        try eq(approxScale(shearing(0.5, 0.5)), 0.8660, EPSILON, "approx_scale(shearing(0.5, 0.5))")
    }
    scenario("A collapsed transform reports 0") {
        try eq(approxScale(scaling(0, 1)), 0, EPSILON, "approx_scale(scaling(0, 1))")
        try eq(approxScale(matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1)), 0, EPSILON, "approx_scale(matrix3(...))")
    }

    // ============================================== chapter04-shapes.feature
    feature("Transforming what you draw")

    scenario("A segment between pixel centers is a thick line") {
        let s = segment(point(2.5, 2.5), point(11.5, 5.5), 1)
        let cov = rasterize(s, 16, 10)
        try eq(coverageAt(cov, 2, 2), 0.484375, EPSILON, "coverage_at(cov, 2, 2)")
        try eq(coverageAt(cov, 6, 3), 0.6875, EPSILON, "coverage_at(cov, 6, 3)")
        try eq(coverageAt(cov, 7, 3), 0.359375, EPSILON, "coverage_at(cov, 7, 3)")
        try eq(ink(cov), 9.4063, EPSILON, "ink(cov)")
    }
    scenario("A segment need not start on a pixel center") {
        let s = segment(point(1, 3.5), point(7, 3.5), 1)
        let cov = rasterize(s, 10, 10)
        try eq(coverageAt(cov, 0, 3), 0, EPSILON, "coverage_at(cov, 0, 3)")
        try eq(coverageAt(cov, 1, 3), 1, EPSILON, "coverage_at(cov, 1, 3)")
        try eq(coverageAt(cov, 6, 3), 1, EPSILON, "coverage_at(cov, 6, 3)")
        try eq(coverageAt(cov, 7, 3), 0, EPSILON, "coverage_at(cov, 7, 3)")
        try eq(coverageAt(cov, 3, 2), 0, EPSILON, "coverage_at(cov, 3, 2)")
        try eq(ink(cov), 6, EPSILON, "ink(cov)")
    }
    scenario("A segment of no length is a square") {
        let s = segment(point(3.5, 3.5), point(3.5, 3.5), 1)
        let cov = rasterize(s, 8, 8)
        try eq(coverageAt(cov, 3, 3), 1, EPSILON, "coverage_at(cov, 3, 3)")
        try eq(ink(cov), 1, EPSILON, "ink(cov)")
    }
    scenario("A union of nothing is inside nowhere") {
        let s = union([])
        try eqBool(inside(s, 0, 0), false, "inside(s, 0, 0)")
        try eq(ink(rasterize(s, 4, 4)), 0, EPSILON, "ink(rasterize(s, 4, 4))")
    }
    scenario("A union is inside when any of its parts is") {
        let s = union([circle(2, 2, 1), rectangle(5, 0, 7, 4)])
        try eqBool(inside(s, 2, 2), true, "inside(s, 2, 2)")
        try eqBool(inside(s, 6, 1), true, "inside(s, 6, 1)")
        try eqBool(inside(s, 4, 2), false, "inside(s, 4, 2)")
        try eq(ink(rasterize(s, 8, 8)), 11.25, EPSILON, "ink(rasterize(s, 8, 8))")
    }
    scenario("A circle seen through a scale is an ellipse") {
        let s = transformed(circle(0, 0, 4), scaling(2, 1))
        try eqBool(inside(s, 7.9, 0), true, "inside(s, 7.9, 0)")
        try eqBool(inside(s, 8.1, 0), false, "inside(s, 8.1, 0)")
        try eqBool(inside(s, 0, 3.9), true, "inside(s, 0, 3.9)")
        try eqBool(inside(s, 0, 4.1), false, "inside(s, 0, 4.1)")
        try eqBool(inside(s, 5.6, 1.4), true, "inside(s, 5.6, 1.4)")
        try eqBool(inside(s, 5.6, 2.9), false, "inside(s, 5.6, 2.9)")
    }
    scenario("The transform is applied in the order the matrix says") {
        let s = transformed(circle(0, 0, 4), translation(10, 10) * scaling(2, 1))
        try eqBool(inside(s, 10, 10), true, "inside(s, 10, 10)")
        try eqBool(inside(s, 17.9, 10), true, "inside(s, 17.9, 10)")
        try eqBool(inside(s, 18.1, 10), false, "inside(s, 18.1, 10)")
        try eqBool(inside(s, 10, 13.9), true, "inside(s, 10, 13.9)")
        try eqBool(inside(s, 10, 14.1), false, "inside(s, 10, 14.1)")
    }
    scenario("A shape seen through a collapsed transform is empty") {
        let s = transformed(circle(0, 0, 4), scaling(0, 1))
        try eqBool(inside(s, 0, 0), false, "inside(s, 0, 0)")
        try eq(ink(rasterize(s, 10, 10)), 0, EPSILON, "ink(rasterize(s, 10, 10))")
    }
    scenario("A pen in shape space scales with the shape") {
        let s = transformed(thickLine(5, 0, 5, 9, 1), scaling(3, 1))
        let cov = rasterize(s, 24, 10)
        try eq(coverageAt(cov, 14, 4), 0, EPSILON, "coverage_at(cov, 14, 4)")
        try eq(coverageAt(cov, 15, 4), 1, EPSILON, "coverage_at(cov, 15, 4)")
        try eq(coverageAt(cov, 16, 4), 1, EPSILON, "coverage_at(cov, 16, 4)")
        try eq(coverageAt(cov, 17, 4), 1, EPSILON, "coverage_at(cov, 17, 4)")
        try eq(coverageAt(cov, 18, 4), 0, EPSILON, "coverage_at(cov, 18, 4)")
        try eq(ink(cov), 27, EPSILON, "ink(cov)")
    }
    scenario("A pen in device space does not") {
        let m = scaling(3, 1)
        let s = segment(m * point(5.5, 0.5), m * point(5.5, 9.5), 1)
        let cov = rasterize(s, 24, 10)
        try eq(coverageAt(cov, 15, 4), 0, EPSILON, "coverage_at(cov, 15, 4)")
        try eq(coverageAt(cov, 16, 4), 1, EPSILON, "coverage_at(cov, 16, 4)")
        try eq(coverageAt(cov, 17, 4), 0, EPSILON, "coverage_at(cov, 17, 4)")
        try eq(ink(cov), 9, EPSILON, "ink(cov)")
    }
    scenario("Dividing the width by approx_scale makes the two pens agree") {
        let m = scaling(2, 2)
        let s = transformed(segment(point(5.5, 0.5), point(5.5, 9.5), 1 / approxScale(m)), m)
        let cov = rasterize(s, 24, 20)
        try eq(coverageAt(cov, 9, 5), 0, EPSILON, "coverage_at(cov, 9, 5)")
        try eq(coverageAt(cov, 10, 5), 0.5, EPSILON, "coverage_at(cov, 10, 5)")
        try eq(coverageAt(cov, 11, 5), 0.5, EPSILON, "coverage_at(cov, 11, 5)")
        try eq(coverageAt(cov, 12, 5), 0, EPSILON, "coverage_at(cov, 12, 5)")
        try eq(ink(cov), 18, EPSILON, "ink(cov)")
    }
    scenario("Under a non-uniform scale the compromise shows") {
        let m = scaling(4, 1)
        let w = 1 / approxScale(m)
        let v = transformed(segment(point(2.5, 0.5), point(2.5, 9.5), w), m)
        let h = transformed(segment(point(0.5, 5.5), point(4.5, 5.5), w), m)
        let cv = rasterize(v, 24, 12)
        let ch = rasterize(h, 24, 12)
        try eq(coverageAt(cv, 8, 5), 0, EPSILON, "coverage_at(cv, 8, 5)")
        try eq(coverageAt(cv, 9, 5), 1, EPSILON, "coverage_at(cv, 9, 5)")
        try eq(coverageAt(cv, 10, 5), 1, EPSILON, "coverage_at(cv, 10, 5)")
        try eq(coverageAt(cv, 11, 5), 0, EPSILON, "coverage_at(cv, 11, 5)")
        try eq(ink(cv), 18, EPSILON, "ink(cv)")
        try eq(coverageAt(ch, 10, 4), 0, EPSILON, "coverage_at(ch, 10, 4)")
        try eq(coverageAt(ch, 10, 5), 0.5, EPSILON, "coverage_at(ch, 10, 5)")
        try eq(coverageAt(ch, 10, 6), 0, EPSILON, "coverage_at(ch, 10, 6)")
        try eq(ink(ch), 8, EPSILON, "ink(ch)")
    }
    scenario("An outline is one shape, so its corners are painted once") {
        let pts = [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)]
        let c = canvas(8, 8)
        paintThrough(c, rasterize(outline(pts, identity(), 1), 8, 8), color(1, 1, 1))
        try eqI(litPixels(c).count, 20, "length(lit_pixels(c))")
        try eqC(c.pixelAt(3, 1), color(1, 1, 1), "pixel_at(c, 3, 1)")
        try eqC(c.pixelAt(1, 3), color(1, 1, 1), "pixel_at(c, 1, 3)")
        try eqC(c.pixelAt(1, 1), color(0.75, 0.75, 0.75), "pixel_at(c, 1, 1)")
        try eqC(c.pixelAt(3, 3), color(0, 0, 0), "pixel_at(c, 3, 3)")
        try eqC(c.pixelAt(0, 1), color(0, 0, 0), "pixel_at(c, 0, 1)")
        try eq(totalInk(c), 19, EPSILON, "total_ink(c)")
    }
    scenario("An outline takes its points through the matrix first") {
        let pts = [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)]
        let c = canvas(16, 16)
        paintThrough(c, rasterize(outline(pts, scaling(2, 2), 1), 16, 16), color(1, 1, 1))
        try eqI(litPixels(c).count, 76, "length(lit_pixels(c))")
        try eqC(c.pixelAt(3, 3), color(0.75, 0.75, 0.75), "pixel_at(c, 3, 3)")
        try eqC(c.pixelAt(8, 2), color(0.5, 0.5, 0.5), "pixel_at(c, 8, 2)")
        try eqC(c.pixelAt(8, 3), color(0.5, 0.5, 0.5), "pixel_at(c, 8, 3)")
        try eqC(c.pixelAt(8, 4), color(0, 0, 0), "pixel_at(c, 8, 4)")
    }

    // =============================================== chapter04-plate.feature
    feature("Plate 4")

    scenario("The fan as points") {
        let pts = fanPoints()
        try eqI(pts.count, 13, "length(pts)")
        try eqT(pts[0], point(0, 0), "pts[0]")
        try eqT(pts[1], point(36, 0), "pts[1]")
        try eqT(pts[4], point(0, 36), "pts[4]")
        try eqT(pts[7], point(-36, 0), "pts[7]")
        try eqT(pts[2], point(31.1769, 18), "pts[2]")
    }
    scenario("Rotate, then translate: the fan turns about its own center") {
        let m = translation(104.5, 76.5) * rotation(Double.pi / 6)
        let pts = transformPoints(fanPoints(), m)
        try eqT(pts[0], point(104.5, 76.5), "pts[0]")
        try eqT(pts[1], point(135.6769, 94.5), "pts[1]")
        try eqT(pts[4], point(86.5, 107.6769), "pts[4]")
    }
    scenario("Translate, then rotate: the fan swings about the canvas corner") {
        let m = rotation(Double.pi / 6) * translation(104.5, 76.5)
        let pts = transformPoints(fanPoints(), m)
        try eqT(pts[0], point(52.2497, 118.5009), "pts[0]")
        try eqT(pts[1], point(83.4266, 136.5009), "pts[1]")
    }
    scenario("The letter F") {
        let f = letterF()
        try eqI(f.count, 10, "length(f)")
        try eqT(f[0], point(-20, -30), "f[0]")
        try eqT(f[1], point(20, -30), "f[1]")
        try eqT(f[5], point(12, -5), "f[5]")
        try eqT(f[9], point(-20, 30), "f[9]")
    }
    scenario("The F at home") {
        let f = transformPoints(letterF(), translation(44.5, 44.5))
        try eqT(f[0], point(24.5, 14.5), "f[0]")
        try eqT(f[1], point(64.5, 14.5), "f[1]")
        try eqT(f[9], point(24.5, 74.5), "f[9]")
    }
    scenario("The F, rotated then translated") {
        let m = translation(104.5, 76.5) * rotation(Double.pi / 6)
        let f = transformPoints(letterF(), m)
        try eqT(f[0], point(102.1795, 40.5192), "f[0]")
        try eqT(f[1], point(136.8205, 60.5192), "f[1]")
        try eqT(f[5], point(117.3923, 78.1699), "f[5]")
        try eqT(f[9], point(72.1795, 92.4808), "f[9]")
    }
    scenario("The F, translated then rotated") {
        let m = rotation(Double.pi / 6) * translation(104.5, 76.5)
        let f = transformPoints(letterF(), m)
        try eqT(f[0], point(49.9291, 82.5202), "f[0]")
        try eqT(f[1], point(84.5702, 102.5202), "f[1]")
        try eqT(f[5], point(65.142, 120.1708), "f[5]")
        try eqT(f[9], point(19.9291, 134.4817), "f[9]")
    }
    scenario("side_by_side puts the first canvas on the left") {
        let a = canvas(2, 3), b = canvas(4, 3)
        fill(a, color(1, 0, 0))
        fill(b, color(0, 0, 1))
        let c = sideBySide(a, b)
        try eqI(c.width, 6, "c.width")
        try eqI(c.height, 3, "c.height")
        try eqC(pixelAt(c, 0, 0), color(1, 0, 0), "pixel_at(c, 0, 0)")
        try eqC(pixelAt(c, 1, 2), color(1, 0, 0), "pixel_at(c, 1, 2)")
        try eqC(pixelAt(c, 2, 0), color(0, 0, 1), "pixel_at(c, 2, 0)")
        try eqC(pixelAt(c, 5, 2), color(0, 0, 1), "pixel_at(c, 5, 2)")
    }
    scenario("The fan, both orders") {
        let c = fanBothOrders()
        let ref = readFile("reference/chapter-04/fan-both-orders.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 320, "c.width")
        try eqI(c.height, 160, "c.height")
        try eqPx(ppmPixel(p6, 104, 76), (246, 246, 241), 1, "ppm_pixel(p6, 104, 76)")
        try eqPx(ppmPixel(p6, 124, 76), (246, 246, 241), 1, "ppm_pixel(p6, 124, 76)")
        try eqPx(ppmPixel(p6, 104, 56), (246, 246, 241), 1, "ppm_pixel(p6, 104, 56)")
        try eqPx(ppmPixel(p6, 125, 88), (236, 236, 231), 1, "ppm_pixel(p6, 125, 88)")
        try eqPx(ppmPixel(p6, 116, 97), (236, 236, 231), 1, "ppm_pixel(p6, 116, 97)")
        try eqPx(ppmPixel(p6, 141, 76), (39, 39, 44), 1, "ppm_pixel(p6, 141, 76)")
        try eqPx(ppmPixel(p6, 10, 10), (39, 39, 44), 1, "ppm_pixel(p6, 10, 10)")
        try eqPx(ppmPixel(p6, 212, 118), (246, 246, 241), 1, "ppm_pixel(p6, 212, 118)")
        try eqPx(ppmPixel(p6, 232, 118), (246, 246, 241), 1, "ppm_pixel(p6, 232, 118)")
        try eqPx(ppmPixel(p6, 233, 130), (223, 223, 219), 1, "ppm_pixel(p6, 233, 130)")
        try eqPx(ppmPixel(p6, 224, 139), (236, 236, 231), 1, "ppm_pixel(p6, 224, 139)")
        try eqPx(ppmPixel(p6, 200, 139), (211, 211, 207), 1, "ppm_pixel(p6, 200, 139)")
        try eqPx(ppmPixel(p6, 310, 10), (39, 39, 44), 1, "ppm_pixel(p6, 310, 10)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }
    scenario("Plate 4") {
        let c = plate04()
        let ref = readFile("reference/chapter-04/plate-04.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 640, "c.width")
        try eqI(c.height, 320, "c.height")
        try eqPx(ppmPixel(p6, 48, 28), (99, 99, 102), 1, "ppm_pixel(p6, 48, 28)")
        try eqPx(ppmPixel(p6, 80, 28), (111, 111, 115), 1, "ppm_pixel(p6, 80, 28)")
        try eqPx(ppmPixel(p6, 48, 100), (111, 111, 115), 1, "ppm_pixel(p6, 48, 100)")
        try eqPx(ppmPixel(p6, 10, 10), (39, 39, 44), 1, "ppm_pixel(p6, 10, 10)")
        try eqPx(ppmPixel(p6, 200, 150), (39, 39, 44), 1, "ppm_pixel(p6, 200, 150)")
        try eqPx(ppmPixel(p6, 268, 129), (237, 237, 233), 1, "ppm_pixel(p6, 268, 129)")
        try eqPx(ppmPixel(p6, 215, 145), (237, 237, 233), 1, "ppm_pixel(p6, 215, 145)")
        try eqPx(ppmPixel(p6, 239, 101), (237, 237, 233), 1, "ppm_pixel(p6, 239, 101)")
        try eqPx(ppmPixel(p6, 174, 173), (217, 217, 213), 1, "ppm_pixel(p6, 174, 173)")
        try eqPx(ppmPixel(p6, 368, 28), (99, 99, 102), 1, "ppm_pixel(p6, 368, 28)")
        try eqPx(ppmPixel(p6, 500, 60), (39, 39, 44), 1, "ppm_pixel(p6, 500, 60)")
        try eqPx(ppmPixel(p6, 453, 207), (236, 236, 231), 1, "ppm_pixel(p6, 453, 207)")
        try eqPx(ppmPixel(p6, 431, 229), (234, 234, 229), 1, "ppm_pixel(p6, 431, 229)")
        try eqPx(ppmPixel(p6, 445, 249), (234, 234, 229), 1, "ppm_pixel(p6, 445, 249)")
        try eqPx(ppmPixel(p6, 368, 273), (177, 177, 174), 1, "ppm_pixel(p6, 368, 273)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }

    chapter(5)
    // ============================================== chapter05-paths.feature
    feature("A path is a list of instructions")

    scenario("An empty path") {
        let p = path()
        try eqI(subpaths(p).count, 0, "length(subpaths(p))")
        try eqI(edges(p).count, 0, "length(edges(p))")
        try eqBounds(bounds(p), (0, 0, 0, 0), "bounds(p)")
    }
    scenario("A triangle, closed") {
        let p = path()
        moveTo(p, point(1, 1))
        lineTo(p, point(9, 1))
        lineTo(p, point(5, 8))
        close(p)
        try eqI(subpaths(p).count, 1, "length(subpaths(p))")
        try eqBool(subpaths(p)[0].closed, true, "subpaths(p)[0].closed")
        try eqI(subpaths(p)[0].points.count, 3, "length(subpaths(p)[0].points)")
        try eqT(subpaths(p)[0].points[2], point(5, 8), "subpaths(p)[0].points[2]")
        try eqI(edges(p).count, 3, "length(edges(p))")
        try eqT(edges(p)[2].0, point(5, 8), "edges(p)[2].0")
        try eqT(edges(p)[2].1, point(1, 1), "edges(p)[2].1")
        try eqBounds(bounds(p), (1, 1, 9, 8), "bounds(p)")
    }
    scenario("A triangle left open still has three edges") {
        let p = path()
        moveTo(p, point(1, 1))
        lineTo(p, point(9, 1))
        lineTo(p, point(5, 8))
        try eqBool(subpaths(p)[0].closed, false, "subpaths(p)[0].closed")
        try eqI(edges(p).count, 3, "length(edges(p))")
        try eqT(edges(p)[2].0, point(5, 8), "edges(p)[2].0")
        try eqT(edges(p)[2].1, point(1, 1), "edges(p)[2].1")
    }
    scenario("move_to starts a second subpath") {
        let p = path()
        moveTo(p, point(0, 0))
        lineTo(p, point(10, 0))
        lineTo(p, point(10, 10))
        lineTo(p, point(0, 10))
        close(p)
        moveTo(p, point(3, 3))
        lineTo(p, point(3, 7))
        lineTo(p, point(7, 7))
        lineTo(p, point(7, 3))
        close(p)
        try eqI(subpaths(p).count, 2, "length(subpaths(p))")
        try eqT(subpaths(p)[1].points[0], point(3, 3), "subpaths(p)[1].points[0]")
        try eqI(edges(p).count, 8, "length(edges(p))")
        try eqBounds(bounds(p), (0, 0, 10, 10), "bounds(p)")
    }
    scenario("line_to after a close starts a new subpath where the closed one began") {
        let p = path()
        moveTo(p, point(1, 1))
        lineTo(p, point(4, 1))
        lineTo(p, point(4, 4))
        close(p)
        lineTo(p, point(9, 9))
        try eqI(subpaths(p).count, 2, "length(subpaths(p))")
        try eqBool(subpaths(p)[1].closed, false, "subpaths(p)[1].closed")
        try eqI(subpaths(p)[1].points.count, 2, "length(subpaths(p)[1].points)")
        try eqT(subpaths(p)[1].points[0], point(1, 1), "subpaths(p)[1].points[0]")
        try eqT(subpaths(p)[1].points[1], point(9, 9), "subpaths(p)[1].points[1]")
    }
    scenario("line_to with nothing to extend behaves as move_to") {
        let p = path()
        lineTo(p, point(2, 3))
        try eqI(subpaths(p).count, 1, "length(subpaths(p))")
        try eqI(subpaths(p)[0].points.count, 1, "length(subpaths(p)[0].points)")
        try eqT(subpaths(p)[0].points[0], point(2, 3), "subpaths(p)[0].points[0]")
    }
    scenario("A subpath of one point has no edges, and closing nothing does nothing") {
        let p = path()
        close(p)
        moveTo(p, point(1, 1))
        moveTo(p, point(2, 2))
        try eqI(subpaths(p).count, 2, "length(subpaths(p))")
        try eqI(edges(p).count, 0, "length(edges(p))")
        try eqBounds(bounds(p), (1, 1, 2, 2), "bounds(p)")
    }
    scenario("A subpath of two points has two edges and encloses nothing") {
        let p = path()
        moveTo(p, point(1, 1))
        lineTo(p, point(9, 9))
        try eqI(edges(p).count, 2, "length(edges(p))")
        try eqI(windingAt(p, 3, 5), 0, "winding_at(p, 3, 5)")
    }
    scenario("polygon is a closed subpath through its points") {
        let p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
        try eqI(subpaths(p).count, 1, "length(subpaths(p))")
        try eqBool(subpaths(p)[0].closed, true, "subpaths(p)[0].closed")
        try eqI(edges(p).count, 4, "length(edges(p))")
    }
    scenario("circle_path is a polygon standing in for a circle") {
        let p = circlePath(10, 10, 5, 8)
        try eqI(subpaths(p)[0].points.count, 8, "length(subpaths(p)[0].points)")
        try eqT(subpaths(p)[0].points[0], point(15, 10), "subpaths(p)[0].points[0]")
        try eqT(subpaths(p)[0].points[1], point(13.5355, 13.5355), "subpaths(p)[0].points[1]")
        try eqT(subpaths(p)[0].points[2], point(10, 15), "subpaths(p)[0].points[2]")
        try eqBounds(bounds(p), (5, 5, 15, 15), "bounds(p)")
    }

    // ============================================ chapter05-winding.feature
    feature("Is this point inside?")

    scenario("Crossings from inside and outside a square") {
        let p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
        try eqI(crossings(p, 5, 5), 1, "crossings(p, 5, 5)")
        try eqI(crossings(p, 15, 5), 0, "crossings(p, 15, 5)")
        try eqI(crossings(p, -1, 5), 2, "crossings(p, -1, 5)")
    }
    scenario("A clockwise square winds once") {
        let p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
        try eqI(windingAt(p, 5, 5), 1, "winding_at(p, 5, 5)")
        try eqI(windingAt(p, 15, 5), 0, "winding_at(p, 15, 5)")
        try eqI(windingAt(p, -1, 5), 0, "winding_at(p, -1, 5)")
        try eqI(windingAt(p, 5, -1), 0, "winding_at(p, 5, -1)")
        try eqI(windingAt(p, 5, 11), 0, "winding_at(p, 5, 11)")
    }
    scenario("The same square the other way round winds minus once") {
        let p = polygon(point(0, 0), point(0, 10), point(10, 10), point(10, 0))
        try eqI(windingAt(p, 5, 5), -1, "winding_at(p, 5, 5)")
        try eqI(crossings(p, 5, 5), 1, "crossings(p, 5, 5)")
    }
    scenario("A ray through a vertex counts it once") {
        let p = polygon(point(5, 0), point(10, 5), point(5, 10), point(0, 5))
        try eqI(crossings(p, 2, 5), 1, "crossings(p, 2, 5)")
        try eqI(windingAt(p, 2, 5), 1, "winding_at(p, 2, 5)")
        try eqI(crossings(p, -1, 5), 2, "crossings(p, -1, 5)")
        try eqI(windingAt(p, -1, 5), 0, "winding_at(p, -1, 5)")
        try eqI(windingAt(p, 12, 5), 0, "winding_at(p, 12, 5)")
        try eqI(windingAt(p, 5, 5), 1, "winding_at(p, 5, 5)")
    }
    scenario("The boundary belongs to the top and the left") {
        let p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
        try eqI(windingAt(p, 5, 0), 1, "winding_at(p, 5, 0)")
        try eqI(windingAt(p, 0, 5), 1, "winding_at(p, 0, 5)")
        try eqI(windingAt(p, 0, 0), 1, "winding_at(p, 0, 0)")
        try eqI(windingAt(p, 5, 10), 0, "winding_at(p, 5, 10)")
        try eqI(windingAt(p, 10, 5), 0, "winding_at(p, 10, 5)")
        try eqI(windingAt(p, 10, 10), 0, "winding_at(p, 10, 10)")
    }
    scenario("Two rectangles that share an edge cover it once") {
        let p = path()
        moveTo(p, point(0, 0))
        lineTo(p, point(5, 0))
        lineTo(p, point(5, 10))
        lineTo(p, point(0, 10))
        close(p)
        moveTo(p, point(5, 0))
        lineTo(p, point(10, 0))
        lineTo(p, point(10, 10))
        lineTo(p, point(5, 10))
        close(p)
        try eqI(windingAt(p, 2, 5), 1, "winding_at(p, 2, 5)")
        try eqI(windingAt(p, 5, 5), 1, "winding_at(p, 5, 5)")
        try eqI(windingAt(p, 8, 5), 1, "winding_at(p, 8, 5)")
    }
    scenario("A diamond wound twice has winding number 2") {
        let p = path()
        moveTo(p, point(5, 0))
        lineTo(p, point(10, 5))
        lineTo(p, point(5, 10))
        lineTo(p, point(0, 5))
        lineTo(p, point(5, 0))
        lineTo(p, point(10, 5))
        lineTo(p, point(5, 10))
        lineTo(p, point(0, 5))
        close(p)
        try eqI(edges(p).count, 8, "length(edges(p))")
        try eqI(windingAt(p, 5, 5), 2, "winding_at(p, 5, 5)")
        try eqI(crossings(p, 5, 5), 2, "crossings(p, 5, 5)")
        try eqI(windingAt(p, 12, 5), 0, "winding_at(p, 12, 5)")
    }
    scenario("The polygon circle") {
        let p = circlePath(10, 10, 5, 8)
        try eqI(windingAt(p, 10, 10), 1, "winding_at(p, 10, 10)")
        try eqI(windingAt(p, 14.9, 10), 1, "winding_at(p, 14.9, 10)")
        try eqI(windingAt(p, 15, 10), 0, "winding_at(p, 15, 10)")
        try eqI(windingAt(p, 10, 5.1), 1, "winding_at(p, 10, 5.1)")
        try eqI(windingAt(p, 10, 4.9), 0, "winding_at(p, 10, 4.9)")
    }
    scenario("The pentagram's center winds twice") {
        let p = star()
        try eqI(windingAt(p, 80.5, 80.5), 2, "winding_at(p, 80.5, 80.5)")
        try eqI(crossings(p, 80.5, 80.5), 2, "crossings(p, 80.5, 80.5)")
        try eqI(windingAt(p, 80.5, 20), 1, "winding_at(p, 80.5, 20)")
        try eqI(windingAt(p, 30, 60), 1, "winding_at(p, 30, 60)")
        try eqI(crossings(p, 30, 60), 3, "crossings(p, 30, 60)")
        try eqI(windingAt(p, 80.5, 120), 0, "winding_at(p, 80.5, 120)")
        try eqI(crossings(p, 80.5, 120), 2, "crossings(p, 80.5, 120)")
        try eqI(windingAt(p, 10, 10), 0, "winding_at(p, 10, 10)")
    }

    // ============================================== chapter05-rules.feature
    feature("Two rules")

    scenario("A single loop is inside under both rules") {
        let p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
        try eqBool(insideNonzero(p, 5, 5), true, "inside_nonzero(p, 5, 5)")
        try eqBool(insideEvenOdd(p, 5, 5), true, "inside_evenodd(p, 5, 5)")
        try eqBool(insideNonzero(p, 15, 5), false, "inside_nonzero(p, 15, 5)")
        try eqBool(insideEvenOdd(p, 15, 5), false, "inside_evenodd(p, 15, 5)")
    }
    scenario("An inner loop the other way round is a hole under both rules") {
        let p = path()
        moveTo(p, point(0, 0))
        lineTo(p, point(10, 0))
        lineTo(p, point(10, 10))
        lineTo(p, point(0, 10))
        close(p)
        moveTo(p, point(3, 3))
        lineTo(p, point(3, 7))
        lineTo(p, point(7, 7))
        lineTo(p, point(7, 3))
        close(p)
        try eqI(windingAt(p, 5, 5), 0, "winding_at(p, 5, 5)")
        try eqI(windingAt(p, 1, 1), 1, "winding_at(p, 1, 1)")
        try eqBool(insideNonzero(p, 5, 5), false, "inside_nonzero(p, 5, 5)")
        try eqBool(insideEvenOdd(p, 5, 5), false, "inside_evenodd(p, 5, 5)")
        try eqBool(insideNonzero(p, 1, 1), true, "inside_nonzero(p, 1, 1)")
    }
    scenario("An inner loop the same way round is a hole only under even-odd") {
        let p = path()
        moveTo(p, point(0, 0))
        lineTo(p, point(10, 0))
        lineTo(p, point(10, 10))
        lineTo(p, point(0, 10))
        close(p)
        moveTo(p, point(3, 3))
        lineTo(p, point(7, 3))
        lineTo(p, point(7, 7))
        lineTo(p, point(3, 7))
        close(p)
        try eqI(windingAt(p, 5, 5), 2, "winding_at(p, 5, 5)")
        try eqBool(insideNonzero(p, 5, 5), true, "inside_nonzero(p, 5, 5)")
        try eqBool(insideEvenOdd(p, 5, 5), false, "inside_evenodd(p, 5, 5)")
    }
    scenario("A loop wound twice vanishes under even-odd") {
        let p = path()
        moveTo(p, point(5, 0))
        lineTo(p, point(10, 5))
        lineTo(p, point(5, 10))
        lineTo(p, point(0, 5))
        lineTo(p, point(5, 0))
        lineTo(p, point(10, 5))
        lineTo(p, point(5, 10))
        lineTo(p, point(0, 5))
        close(p)
        try eqBool(insideNonzero(p, 5, 5), true, "inside_nonzero(p, 5, 5)")
        try eqBool(insideEvenOdd(p, 5, 5), false, "inside_evenodd(p, 5, 5)")
    }
    scenario("The pentagram's center is inside under nonzero and outside under even-odd") {
        let p = star()
        try eqBool(insideNonzero(p, 80.5, 80.5), true, "inside_nonzero(p, 80.5, 80.5)")
        try eqBool(insideEvenOdd(p, 80.5, 80.5), false, "inside_evenodd(p, 80.5, 80.5)")
        try eqBool(insideNonzero(p, 80.5, 20), true, "inside_nonzero(p, 80.5, 20)")
        try eqBool(insideEvenOdd(p, 80.5, 20), true, "inside_evenodd(p, 80.5, 20)")
        try eqBool(insideNonzero(p, 80.5, 120), false, "inside_nonzero(p, 80.5, 120)")
        try eqBool(insideEvenOdd(p, 80.5, 120), false, "inside_evenodd(p, 80.5, 120)")
    }
    scenario("A filled path is a shape") {
        let s = filled(polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6)), "nonzero")
        let cov = rasterize(s, 8, 8)
        try eqBool(inside(s, 3, 3), true, "inside(s, 3, 3)")
        try eqBool(inside(s, 7, 3), false, "inside(s, 7, 3)")
        try eq(coverageAt(cov, 3, 3), 1, EPSILON, "coverage_at(cov, 3, 3)")
        try eq(coverageAt(cov, 1, 3), 0, EPSILON, "coverage_at(cov, 1, 3)")
        try eq(coverageAt(cov, 6, 3), 0, EPSILON, "coverage_at(cov, 6, 3)")
        try eq(ink(cov), 16, EPSILON, "ink(cov)")
    }
    scenario("A filled path takes the rule seriously") {
        let p = star()
        let a = filled(p, "nonzero"), b = filled(p, "evenodd")
        let ca = rasterize(a, 160, 160), cb = rasterize(b, 160, 160)
        try eq(coverageAt(ca, 80, 80), 1, EPSILON, "coverage_at(ca, 80, 80)")
        try eq(coverageAt(cb, 80, 80), 0, EPSILON, "coverage_at(cb, 80, 80)")
        try eq(coverageAt(ca, 80, 20), 1, EPSILON, "coverage_at(ca, 80, 20)")
        try eq(coverageAt(cb, 80, 20), 1, EPSILON, "coverage_at(cb, 80, 20)")
        try eq(coverageAt(ca, 80, 10), 0.0625, EPSILON, "coverage_at(ca, 80, 10)")
        try eq(coverageAt(cb, 80, 10), 0.0625, EPSILON, "coverage_at(cb, 80, 10)")
        try eq(ink(ca), 5499.9375, EPSILON, "ink(ca)")
        try eq(ink(cb), 3800.375, EPSILON, "ink(cb)")
    }
    scenario("Rasterizing within the bounds gives the same coverage") {
        let p = star()
        let s = filled(p, "evenodd")
        let full = rasterize(s, 160, 160)
        let within = rasterizeWithin(s, bounds(p), 160, 160)
        try eq(ink(within), ink(full), EPSILON, "ink(within)")
        try eq(coverageAt(within, 80, 20), coverageAt(full, 80, 20), EPSILON, "coverage_at(within, 80, 20)")
        try eq(coverageAt(within, 13, 58), coverageAt(full, 13, 58), EPSILON, "coverage_at(within, 13, 58)")
        try eq(coverageAt(within, 10, 10), 0, EPSILON, "coverage_at(within, 10, 10)")
    }
    scenario("The box is inclusive of the pixels it touches, and clipped to the buffer") {
        let s = filled(polygon(point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)), "nonzero")
        let cov = rasterizeWithin(s, (1.5, 1.5, 6.5, 6.5), 8, 8)
        let big = rasterizeWithin(s, (-5, -5, 20, 20), 8, 8)
        try eq(coverageAt(cov, 1, 1), 0.25, EPSILON, "coverage_at(cov, 1, 1)")
        try eq(coverageAt(cov, 6, 6), 0.25, EPSILON, "coverage_at(cov, 6, 6)")
        try eq(coverageAt(cov, 3, 3), 1, EPSILON, "coverage_at(cov, 3, 3)")
        try eq(ink(cov), 25, EPSILON, "ink(cov)")
        try eq(ink(big), 25, EPSILON, "ink(big)")
    }

    // ============================================== chapter05-plate.feature
    feature("Plate 5")

    scenario("The pentagram") {
        let p = star()
        try eqI(subpaths(p).count, 1, "length(subpaths(p))")
        try eqI(edges(p).count, 5, "length(edges(p))")
        try eqT(subpaths(p)[0].points[0], point(80.5, 10.5), "subpaths(p)[0].points[0]")
        try eqT(subpaths(p)[0].points[1], point(121.645, 137.1312), "subpaths(p)[0].points[1]")
        try eqT(subpaths(p)[0].points[2], point(13.926, 58.8688), "subpaths(p)[0].points[2]")
        try eqT(subpaths(p)[0].points[3], point(147.074, 58.8688), "subpaths(p)[0].points[3]")
        try eqT(subpaths(p)[0].points[4], point(39.355, 137.1312), "subpaths(p)[0].points[4]")
        try eqBounds(bounds(p), (13.926, 10.5, 147.074, 137.1312), "bounds(p)")
    }
    scenario("The star by the center question") {
        let c = starCenters()
        let ref = readFile("reference/chapter-05/star-centers.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 320, "c.width")
        try eqI(c.height, 160, "c.height")
        try eqPx(ppmPixel(p6, 80, 80), (243, 196, 89), 1, "ppm_pixel(p6, 80, 80)")
        try eqPx(ppmPixel(p6, 240, 80), (39, 39, 44), 1, "ppm_pixel(p6, 240, 80)")
        try eqPx(ppmPixel(p6, 80, 20), (243, 196, 89), 1, "ppm_pixel(p6, 80, 20)")
        try eqPx(ppmPixel(p6, 240, 20), (243, 196, 89), 1, "ppm_pixel(p6, 240, 20)")
        try eqPx(ppmPixel(p6, 30, 60), (243, 196, 89), 1, "ppm_pixel(p6, 30, 60)")
        try eqPx(ppmPixel(p6, 190, 60), (243, 196, 89), 1, "ppm_pixel(p6, 190, 60)")
        try eqPx(ppmPixel(p6, 80, 120), (39, 39, 44), 1, "ppm_pixel(p6, 80, 120)")
        try eqPx(ppmPixel(p6, 80, 10), (39, 39, 44), 1, "ppm_pixel(p6, 80, 10)")
        try eqPx(ppmPixel(p6, 10, 10), (39, 39, 44), 1, "ppm_pixel(p6, 10, 10)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }
    scenario("The star by coverage") {
        let c = starCoverage()
        let ref = readFile("reference/chapter-05/star-coverage.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 320, "c.width")
        try eqI(c.height, 160, "c.height")
        try eqPx(ppmPixel(p6, 80, 80), (243, 196, 89), 1, "ppm_pixel(p6, 80, 80)")
        try eqPx(ppmPixel(p6, 240, 80), (39, 39, 44), 1, "ppm_pixel(p6, 240, 80)")
        try eqPx(ppmPixel(p6, 80, 20), (243, 196, 89), 1, "ppm_pixel(p6, 80, 20)")
        try eqPx(ppmPixel(p6, 240, 20), (243, 196, 89), 1, "ppm_pixel(p6, 240, 20)")
        try eqPx(ppmPixel(p6, 80, 120), (39, 39, 44), 1, "ppm_pixel(p6, 80, 120)")
        try eqPx(ppmPixel(p6, 80, 10), (77, 65, 48), 1, "ppm_pixel(p6, 80, 10)")
        try eqPx(ppmPixel(p6, 240, 10), (77, 65, 48), 1, "ppm_pixel(p6, 240, 10)")
        try eqPx(ppmPixel(p6, 80, 11), (199, 160, 76), 1, "ppm_pixel(p6, 80, 11)")
        try eqPx(ppmPixel(p6, 14, 58), (101, 83, 52), 1, "ppm_pixel(p6, 14, 58)")
        try eqPx(ppmPixel(p6, 174, 58), (101, 83, 52), 1, "ppm_pixel(p6, 174, 58)")
        try eqPx(ppmPixel(p6, 10, 10), (39, 39, 44), 1, "ppm_pixel(p6, 10, 10)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }
    scenario("Plate 5") {
        let c = plate05()
        let ref = readFile("reference/chapter-05/plate-05.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 640, "c.width")
        try eqI(c.height, 640, "c.height")
        try eqPx(ppmPixel(p6, 160, 160), (243, 196, 89), 1, "ppm_pixel(p6, 160, 160)")
        try eqPx(ppmPixel(p6, 480, 160), (39, 39, 44), 1, "ppm_pixel(p6, 480, 160)")
        try eqPx(ppmPixel(p6, 160, 480), (243, 196, 89), 1, "ppm_pixel(p6, 160, 480)")
        try eqPx(ppmPixel(p6, 480, 480), (39, 39, 44), 1, "ppm_pixel(p6, 480, 480)")
        try eqPx(ppmPixel(p6, 160, 40), (243, 196, 89), 1, "ppm_pixel(p6, 160, 40)")
        try eqPx(ppmPixel(p6, 480, 360), (243, 196, 89), 1, "ppm_pixel(p6, 480, 360)")
        try eqPx(ppmPixel(p6, 160, 20), (39, 39, 44), 1, "ppm_pixel(p6, 160, 20)")
        try eqPx(ppmPixel(p6, 160, 341), (77, 65, 48), 1, "ppm_pixel(p6, 160, 341)")
        try eqPx(ppmPixel(p6, 480, 341), (77, 65, 48), 1, "ppm_pixel(p6, 480, 341)")
        try eqPx(ppmPixel(p6, 348, 437), (101, 83, 52), 1, "ppm_pixel(p6, 348, 437)")
        try eqPx(ppmPixel(p6, 20, 20), (39, 39, 44), 1, "ppm_pixel(p6, 20, 20)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }

    chapter(6)
    // ============================================== chapter06-edges.feature
    feature("The edge table")

    scenario("A rectangle has two edges in its table") {
        let p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
        let t = edgeTable(p)
        try eqI(t.count, 2, "length(t)")
        try eq(t[0].yTop, 2, EPSILON, "t[0].y_top")
        try eq(t[0].yBottom, 6, EPSILON, "t[0].y_bottom")
        try eq(t[0].xTop, 2, EPSILON, "t[0].x_top")
        try eq(t[0].slope, 0, EPSILON, "t[0].slope")
        try eqI(t[0].direction, -1, "t[0].direction")
        try eq(t[1].xTop, 6, EPSILON, "t[1].x_top")
        try eqI(t[1].direction, 1, "t[1].direction")
    }
    scenario("A triangle's edges carry their slopes") {
        let p = polygon(point(0, 0), point(10, 0), point(5, 10))
        let t = edgeTable(p)
        try eqI(t.count, 2, "length(t)")
        try eq(t[0].xTop, 0, EPSILON, "t[0].x_top")
        try eq(t[0].slope, 0.5, EPSILON, "t[0].slope")
        try eqI(t[0].direction, -1, "t[0].direction")
        try eq(t[1].xTop, 10, EPSILON, "t[1].x_top")
        try eq(t[1].slope, -0.5, EPSILON, "t[1].slope")
        try eqI(t[1].direction, 1, "t[1].direction")
    }
    scenario("The table is sorted by top, then by x at the top") {
        let p = path()
        moveTo(p, point(2, 2))
        lineTo(p, point(4, 1))
        lineTo(p, point(6, 3))
        lineTo(p, point(8, 1))
        lineTo(p, point(9, 6))
        lineTo(p, point(1, 6))
        close(p)
        let t = edgeTable(p)
        try eqI(t.count, 5, "length(t)")
        try eq(t[0].yTop, 1, EPSILON, "t[0].y_top")
        try eq(t[0].xTop, 4, EPSILON, "t[0].x_top")
        try eq(t[1].yTop, 1, EPSILON, "t[1].y_top")
        try eq(t[1].xTop, 4, EPSILON, "t[1].x_top")
        try eq(t[2].yTop, 1, EPSILON, "t[2].y_top")
        try eq(t[2].xTop, 8, EPSILON, "t[2].x_top")
        try eq(t[3].yTop, 1, EPSILON, "t[3].y_top")
        try eq(t[3].xTop, 8, EPSILON, "t[3].x_top")
        try eq(t[4].yTop, 2, EPSILON, "t[4].y_top")
        try eq(t[4].xTop, 2, EPSILON, "t[4].x_top")
    }
    scenario("A horizontal edge is dropped, not clamped") {
        let p = polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5))
        let t = edgeTable(p)
        try eqI(t.count, 2, "length(t)")
        try eq(t[0].xTop, 0, EPSILON, "t[0].x_top")
        try eq(t[1].xTop, 10, EPSILON, "t[1].x_top")
    }
    scenario("An edge knows where it crosses a height") {
        let p = polygon(point(0, 0), point(10, 0), point(5, 10))
        let t = edgeTable(p)
        try eq(xAt(t[0], 4), 2, EPSILON, "x_at(t[0], 4)")
        try eq(xAt(t[1], 4), 8, EPSILON, "x_at(t[1], 4)")
        try eq(xAt(t[0], 0.5), 0.25, EPSILON, "x_at(t[0], 0.5)")
    }
    scenario("The edge table is the same whichever way the path was drawn") {
        let a = polygon(point(0, 0), point(10, 0), point(5, 10))
        let b = polygon(point(0, 0), point(5, 10), point(10, 0))
        let ta = edgeTable(a), tb = edgeTable(b)
        try eq(ta[0].xTop, tb[0].xTop, EPSILON, "ta[0].x_top = tb[0].x_top")
        try eq(ta[0].slope, tb[0].slope, EPSILON, "ta[0].slope = tb[0].slope")
        try eqI(ta[0].direction, -1, "ta[0].direction")
        try eqI(tb[0].direction, 1, "tb[0].direction")
    }

    // ============================================== chapter06-spans.feature
    feature("Crossings on a row, and spans")

    scenario("Crossings on a row, sorted by x") {
        let p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
        let table = edgeTable(p)
        try eqXings(crossingsOnRow(table, 3.5), [(2, -1), (6, 1)], "crossings_on_row(edge_table(p), 3.5)")
        try eqXings(crossingsOnRow(table, 1.5), [], "crossings_on_row(edge_table(p), 1.5)")
        try eqXings(crossingsOnRow(table, 6), [], "crossings_on_row(edge_table(p), 6)")
        try eqI(crossingsOnRow(table, 2).count, 2, "length(crossings_on_row(edge_table(p), 2))")
    }
    scenario("The star's crossings through its middle") {
        let xs = crossingsOnRow(edgeTable(star()), 80.5)
        try eqI(xs.count, 4, "length(xs)")
        try eqXings([xs[0]], [(43.6988, -1)], "xs[0]")
        try eqXings([xs[1]], [(57.7556, -1)], "xs[1]")
        try eqXings([xs[2]], [(103.2444, 1)], "xs[2]")
        try eqXings([xs[3]], [(117.3012, 1)], "xs[3]")
    }
    scenario("Spans from crossings under each rule") {
        let xs: [(Double, Int)] = [(1, 1), (3, 1), (5, -1), (7, -1)]
        try eqSpans(spansFromCrossings(xs, "nonzero"), [(1, 7)], "spans_from_crossings(xs, \"nonzero\")")
        try eqSpans(spansFromCrossings(xs, "evenodd"), [(1, 3), (5, 7)], "spans_from_crossings(xs, \"evenodd\")")
        try eqSpans(spansFromCrossings([], "nonzero"), [], "spans_from_crossings([], \"nonzero\")")
    }
    scenario("The spans of an axis-aligned rectangle are exact") {
        let p = polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5))
        try eqSpans(spans(p, "nonzero", 1), [], "spans(p, \"nonzero\", 1)")
        try eqSpans(spans(p, "nonzero", 2), [(1.25, 4.75)], "spans(p, \"nonzero\", 2)")
        try eqSpans(spans(p, "nonzero", 4), [(1.25, 4.75)], "spans(p, \"nonzero\", 4)")
        try eqSpans(spans(p, "nonzero", 5), [], "spans(p, \"nonzero\", 5)")
    }
    scenario("A rectangle whose edges sit on sample heights") {
        let p = polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5))
        try eqSpans(spans(p, "nonzero", 1), [], "spans(p, \"nonzero\", 1)")
        try eqSpans(spans(p, "nonzero", 2), [(1.5, 4.5)], "spans(p, \"nonzero\", 2)")
        try eqSpans(spans(p, "nonzero", 4), [(1.5, 4.5)], "spans(p, \"nonzero\", 4)")
        try eqSpans(spans(p, "nonzero", 5), [], "spans(p, \"nonzero\", 5)")
    }
    let triangleSpanRows: [(Int, Double, Double)] = [
        (0, 0.25, 9.75), (1, 0.75, 9.25), (4, 2.25, 7.75), (9, 4.75, 5.25),
    ]
    for (row, x0, x1) in triangleSpanRows {
        scenario("A triangle's spans narrow by one per row [row=\(row), x0=\(x0), x1=\(x1)]") {
            let p = polygon(point(0, 0), point(10, 0), point(5, 10))
            try eqSpans(spans(p, "nonzero", row), [(x0, x1)], "spans(p, \"nonzero\", \(row))")
        }
    }
    scenario("The row past the triangle's apex has no span") {
        let p = polygon(point(0, 0), point(10, 0), point(5, 10))
        try eqSpans(spans(p, "nonzero", 10), [], "spans(p, \"nonzero\", 10)")
    }
    scenario("A flat top is not a span of its own") {
        let p = polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5))
        try eqI(edgeTable(p).count, 2, "length(edge_table(p))")
        try eqSpans(spans(p, "nonzero", 0), [(0, 10)], "spans(p, \"nonzero\", 0)")
        try eqSpans(spans(p, "nonzero", 4), [(0, 10)], "spans(p, \"nonzero\", 4)")
        try eqSpans(spans(p, "nonzero", 5), [], "spans(p, \"nonzero\", 5)")
    }
    scenario("A ring is two spans under even-odd and one under nonzero") {
        let p = path()
        moveTo(p, point(0, 0))
        lineTo(p, point(10, 0))
        lineTo(p, point(10, 10))
        lineTo(p, point(0, 10))
        close(p)
        moveTo(p, point(3, 3))
        lineTo(p, point(7, 3))
        lineTo(p, point(7, 7))
        lineTo(p, point(3, 7))
        close(p)
        try eqSpans(spans(p, "nonzero", 5), [(0, 10)], "spans(p, \"nonzero\", 5)")
        try eqSpans(spans(p, "evenodd", 5), [(0, 3), (7, 10)], "spans(p, \"evenodd\", 5)")
    }
    scenario("The star's spans through its middle") {
        let p = star()
        try eqSpans(spans(p, "nonzero", 80), [(43.6988, 117.3012)], "spans(p, \"nonzero\", 80)")
        try eqSpans(spans(p, "evenodd", 80), [(43.6988, 57.7556), (103.2444, 117.3012)], "spans(p, \"evenodd\", 80)")
    }
    scenario("fill_span fills the pixels whose centers are in the span") {
        let cov = coverageBuffer(8, 3)
        fillSpan(cov, 1, 1.25, 4.75)
        try eq(coverageAt(cov, 0, 1), 0, EPSILON, "coverage_at(cov, 0, 1)")
        try eq(coverageAt(cov, 1, 1), 1, EPSILON, "coverage_at(cov, 1, 1)")
        try eq(coverageAt(cov, 4, 1), 1, EPSILON, "coverage_at(cov, 4, 1)")
        try eq(coverageAt(cov, 5, 1), 0, EPSILON, "coverage_at(cov, 5, 1)")
        try eq(coverageAt(cov, 2, 0), 0, EPSILON, "coverage_at(cov, 2, 0)")
        try eq(ink(cov), 4, EPSILON, "ink(cov)")
    }
    scenario("The span is half-open at its right end") {
        let cov = coverageBuffer(8, 3)
        fillSpan(cov, 1, 1.5, 4.5)
        try eq(coverageAt(cov, 1, 1), 1, EPSILON, "coverage_at(cov, 1, 1)")
        try eq(coverageAt(cov, 3, 1), 1, EPSILON, "coverage_at(cov, 3, 1)")
        try eq(coverageAt(cov, 4, 1), 0, EPSILON, "coverage_at(cov, 4, 1)")
        try eq(ink(cov), 3, EPSILON, "ink(cov)")
    }
    scenario("A span may run off either side of the buffer") {
        let a = coverageBuffer(8, 3), b = coverageBuffer(8, 3), c = coverageBuffer(8, 3)
        fillSpan(a, 1, -3, 2.5)
        fillSpan(b, 1, 6.5, 20)
        fillSpan(c, 1, 2.5, 2.5)
        try eq(ink(a), 2, EPSILON, "ink(a)")
        try eq(coverageAt(a, 1, 1), 1, EPSILON, "coverage_at(a, 1, 1)")
        try eq(ink(b), 2, EPSILON, "ink(b)")
        try eq(coverageAt(b, 6, 1), 1, EPSILON, "coverage_at(b, 6, 1)")
        try eq(ink(c), 0, EPSILON, "ink(c)")
    }

    // ============================================== chapter06-sweep.feature
    feature("The sweep")

    scenario("Two buffers that differ") {
        let a = coverageBuffer(3, 3), b = coverageBuffer(3, 3)
        setCoverage(a, 1, 1, 1)
        setCoverage(b, 1, 1, 0.25)
        try eq(maxCoverageDifference(a, b), 0.75, EPSILON, "max_coverage_difference(a, b)")
        try eq(maxCoverageDifference(a, a), 0, EPSILON, "max_coverage_difference(a, a)")
    }
    scenario("Buffers of different sizes are as different as it gets") {
        let a = coverageBuffer(3, 3), b = coverageBuffer(3, 4)
        try eq(maxCoverageDifference(a, b), 1, EPSILON, "max_coverage_difference(a, b)")
    }
    scenario("A rectangle") {
        let p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
        let cov = fillPathAliased(p, "nonzero", 8, 8)
        try eq(coverageAt(cov, 2, 2), 1, EPSILON, "coverage_at(cov, 2, 2)")
        try eq(coverageAt(cov, 5, 5), 1, EPSILON, "coverage_at(cov, 5, 5)")
        try eq(coverageAt(cov, 6, 5), 0, EPSILON, "coverage_at(cov, 6, 5)")
        try eq(coverageAt(cov, 5, 6), 0, EPSILON, "coverage_at(cov, 5, 6)")
        try eq(coverageAt(cov, 1, 2), 0, EPSILON, "coverage_at(cov, 1, 2)")
        try eq(ink(cov), 16, EPSILON, "ink(cov)")
        try eq(maxCoverageDifference(cov, rasterizeCenters(filled(p, "nonzero"), 8, 8)), 0, EPSILON,
               "max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 8, 8))")
    }
    scenario("A triangle") {
        let p = polygon(point(0, 0), point(10, 0), point(5, 10))
        let cov = fillPathAliased(p, "nonzero", 20, 20)
        try eq(coverageAt(cov, 0, 0), 1, EPSILON, "coverage_at(cov, 0, 0)")
        try eq(coverageAt(cov, 9, 0), 1, EPSILON, "coverage_at(cov, 9, 0)")
        try eq(coverageAt(cov, 10, 0), 0, EPSILON, "coverage_at(cov, 10, 0)")
        try eq(coverageAt(cov, 4, 8), 1, EPSILON, "coverage_at(cov, 4, 8)")
        try eq(coverageAt(cov, 3, 8), 0, EPSILON, "coverage_at(cov, 3, 8)")
        try eq(coverageAt(cov, 5, 9), 0, EPSILON, "coverage_at(cov, 5, 9)")
        try eq(ink(cov), 50, EPSILON, "ink(cov)")
        try eq(maxCoverageDifference(cov, rasterizeCenters(filled(p, "nonzero"), 20, 20)), 0, EPSILON,
               "max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 20, 20))")
    }
    scenario("The same triangle drawn the other way round") {
        let a = polygon(point(0, 0), point(10, 0), point(5, 10))
        let b = polygon(point(0, 0), point(5, 10), point(10, 0))
        let ca = fillPathAliased(a, "nonzero", 20, 20)
        let cb = fillPathAliased(b, "nonzero", 20, 20)
        try eq(maxCoverageDifference(ca, cb), 0, EPSILON, "max_coverage_difference(ca, cb)")
    }
    scenario("A polygon circle") {
        let p = circlePath(10.3, 9.7, 7, 12)
        let cov = fillPathAliased(p, "nonzero", 20, 20)
        try eq(ink(cov), 145, EPSILON, "ink(cov)")
        try eq(maxCoverageDifference(cov, rasterizeCenters(filled(p, "nonzero"), 20, 20)), 0, EPSILON,
               "max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 20, 20))")
    }
    scenario("The star, both rules, matches chapter 5 pixel for pixel") {
        let p = star()
        let nz = fillPathAliased(p, "nonzero", 160, 160)
        let eo = fillPathAliased(p, "evenodd", 160, 160)
        try eq(ink(nz), 5480, EPSILON, "ink(nz)")
        try eq(ink(eo), 3780, EPSILON, "ink(eo)")
        try eq(coverageAt(nz, 80, 80), 1, EPSILON, "coverage_at(nz, 80, 80)")
        try eq(coverageAt(eo, 80, 80), 0, EPSILON, "coverage_at(eo, 80, 80)")
        try eq(maxCoverageDifference(nz, rasterizeCenters(filled(p, "nonzero"), 160, 160)), 0, EPSILON,
               "max_coverage_difference(nz, rasterize_centers(filled(p, \"nonzero\"), 160, 160))")
        try eq(maxCoverageDifference(eo, rasterizeCenters(filled(p, "evenodd"), 160, 160)), 0, EPSILON,
               "max_coverage_difference(eo, rasterize_centers(filled(p, \"evenodd\"), 160, 160))")
    }
    scenario("An edge that starts on a sample height is active there, and one that ends there is not") {
        let p = polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5))
        let cov = fillPathAliased(p, "nonzero", 8, 8)
        try eq(coverageAt(cov, 2, 1), 0, EPSILON, "coverage_at(cov, 2, 1)")
        try eq(coverageAt(cov, 2, 2), 1, EPSILON, "coverage_at(cov, 2, 2)")
        try eq(coverageAt(cov, 2, 4), 1, EPSILON, "coverage_at(cov, 2, 4)")
        try eq(coverageAt(cov, 2, 5), 0, EPSILON, "coverage_at(cov, 2, 5)")
        try eq(coverageAt(cov, 1, 3), 1, EPSILON, "coverage_at(cov, 1, 3)")
        try eq(coverageAt(cov, 4, 3), 0, EPSILON, "coverage_at(cov, 4, 3)")
        try eq(ink(cov), 9, EPSILON, "ink(cov)")
        try eq(maxCoverageDifference(cov, rasterizeCenters(filled(p, "nonzero"), 8, 8)), 0, EPSILON,
               "max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 8, 8))")
    }
    scenario("A polygon larger than the buffer fills it") {
        let p = polygon(point(-5, -5), point(30, -5), point(30, 30), point(-5, 30))
        let cov = fillPathAliased(p, "nonzero", 8, 8)
        try eq(ink(cov), 64, EPSILON, "ink(cov)")
    }
    scenario("An empty path fills nothing") {
        let p = path()
        let cov = fillPathAliased(p, "nonzero", 8, 8)
        try eq(ink(cov), 0, EPSILON, "ink(cov)")
    }
    scenario("transform_path takes every point through the matrix and keeps the flags") {
        let p = polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5))
        let q = transformPath(p, translation(10, 20))
        try eqI(subpaths(q).count, 1, "length(subpaths(q))")
        try eqBool(subpaths(q)[0].closed, true, "subpaths(q)[0].closed")
        try eqT(subpaths(q)[0].points[0], point(11.25, 22), "subpaths(q)[0].points[0]")
        try eqT(subpaths(q)[0].points[2], point(14.75, 25), "subpaths(q)[0].points[2]")
        try eqT(subpaths(p)[0].points[0], point(1.25, 2), "subpaths(p)[0].points[0]")
    }
    scenario("A transformed star fills where the transform put it") {
        let p = transformPath(star(), translation(10, 10) * scaling(0.11, 0.11) * translation(-80.5, -80.5))
        let nz = fillPathAliased(p, "nonzero", 20, 20)
        let eo = fillPathAliased(p, "evenodd", 20, 20)
        try eqBounds(bounds(p), (2.6769, 2.3, 17.3231, 16.2294), "bounds(p)")
        try eq(ink(nz), 60, EPSILON, "ink(nz)")
        try eq(ink(eo), 40, EPSILON, "ink(eo)")
        try eq(maxCoverageDifference(nz, rasterizeCenters(filled(p, "nonzero"), 20, 20)), 0, EPSILON,
               "max_coverage_difference(nz, rasterize_centers(filled(p, \"nonzero\"), 20, 20))")
    }

    // ============================================== chapter06-plate.feature
    feature("Plate 6")

    scenario("The unit star") {
        let p = unitStar()
        try eqI(edges(p).count, 5, "length(edges(p))")
        try eqT(subpaths(p)[0].points[0], point(0, -1), "subpaths(p)[0].points[0]")
        try eqT(subpaths(p)[0].points[1], point(0.5878, 0.809), "subpaths(p)[0].points[1]")
        try eqT(subpaths(p)[0].points[2], point(-0.9511, -0.309), "subpaths(p)[0].points[2]")
        try eqBounds(bounds(p), (-0.9511, -1, 0.9511, 0.809), "bounds(p)")
    }
    scenario("The spiral") {
        let c = spiral()
        let ref = readFile("reference/chapter-06/spiral.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 320, "c.width")
        try eqI(c.height, 320, "c.height")
        try eqPx(ppmPixel(p6, 180, 160), (243, 196, 89), 1, "ppm_pixel(p6, 180, 160)")
        try eqPx(ppmPixel(p6, 183, 171), (124, 196, 237), 1, "ppm_pixel(p6, 183, 171)")
        try eqPx(ppmPixel(p6, 179, 183), (237, 137, 149), 1, "ppm_pixel(p6, 179, 183)")
        try eqPx(ppmPixel(p6, 104, 139), (237, 137, 149), 1, "ppm_pixel(p6, 104, 139)")
        try eqPx(ppmPixel(p6, 230, 111), (124, 196, 237), 1, "ppm_pixel(p6, 230, 111)")
        try eqPx(ppmPixel(p6, 32, 137), (124, 196, 237), 1, "ppm_pixel(p6, 32, 137)")
        try eqPx(ppmPixel(p6, 34, 104), (237, 137, 149), 1, "ppm_pixel(p6, 34, 104)")
        try eqPx(ppmPixel(p6, 160, 160), (39, 39, 44), 1, "ppm_pixel(p6, 160, 160)")
        try eqPx(ppmPixel(p6, 5, 5), (39, 39, 44), 1, "ppm_pixel(p6, 5, 5)")
        try eqPx(ppmPixel(p6, 300, 20), (39, 39, 44), 1, "ppm_pixel(p6, 300, 20)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }
    scenario("Plate 6") {
        let c = plate06()
        let ref = readFile("reference/chapter-06/plate-06.ppm")
        let p6 = canvasToP6(c)
        try eqI(c.width, 640, "c.width")
        try eqI(c.height, 640, "c.height")
        try eqPx(ppmPixel(p6, 360, 320), (243, 196, 89), 1, "ppm_pixel(p6, 360, 320)")
        try eqPx(ppmPixel(p6, 68, 208), (237, 137, 149), 1, "ppm_pixel(p6, 68, 208)")
        try eqPx(ppmPixel(p6, 320, 320), (39, 39, 44), 1, "ppm_pixel(p6, 320, 320)")
        let d = maxChannelDifference(p6, ref)
        try step(d <= 1, "max_channel_difference(p6, ref) = \(d)")
    }
}
