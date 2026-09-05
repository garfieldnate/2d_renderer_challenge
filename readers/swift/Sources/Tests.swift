import Foundation

// A five-line test runner. One `scenario` per Gherkin scenario; scenario
// outlines are expanded one call per Examples row.

struct StepFailure: Error { let message: String }

var passedCount = 0
var failedCount = 0
var failureLog: [String] = []
var currentFeature = ""

func feature(_ name: String) { currentFeature = name }

var timings: [(String, Double)] = []

func scenario(_ name: String, _ body: () throws -> Void) {
    let t0 = Date()
    defer { timings.append((currentFeature + " :: " + name, Date().timeIntervalSince(t0))) }
    do {
        try body()
        passedCount += 1
    } catch let f as StepFailure {
        failedCount += 1
        failureLog.append("FAIL  \(currentFeature) :: \(name)\n      \(f.message)")
    } catch {
        failedCount += 1
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

func runTests() {
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
}
