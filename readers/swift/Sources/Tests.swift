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
    scenario("Comparing two files") {
        let c1 = canvas(2, 1), c2 = canvas(2, 1)
        writePixel(c2, 0, 0, color(0.5, 0, 0))
        let ppm1 = canvasToPPM(c1), ppm2 = canvasToPPM(c2)
        try eqI(maxChannelDifference(ppm1, ppm1), 0, "max_channel_difference(ppm1, ppm1)")
        try eqI(maxChannelDifference(ppm1, ppm2), 188, "max_channel_difference(ppm1, ppm2)")
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
    scenario("The ends of a mix are its inputs either way") {
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
}
