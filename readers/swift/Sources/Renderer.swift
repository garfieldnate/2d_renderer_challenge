import Foundation

// ---------------------------------------------------------------- equality
// § 1.1  "a = b between two numbers means within 0.0001 of each other"
let EPSILON = 0.0001

func equal(_ a: Double, _ b: Double, _ eps: Double = EPSILON) -> Bool {
    return abs(a - b) <= eps
}

// ---------------------------------------------------------------- § 1.2 color
struct Color {
    var red: Double
    var green: Double
    var blue: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        red = r; green = g; blue = b
    }
}

func color(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(r, g, b) }

extension Color {
    func equals(_ o: Color, _ eps: Double = EPSILON) -> Bool {
        equal(red, o.red, eps) && equal(green, o.green, eps) && equal(blue, o.blue, eps)
    }
}

func + (a: Color, b: Color) -> Color { Color(a.red + b.red, a.green + b.green, a.blue + b.blue) }
func - (a: Color, b: Color) -> Color { Color(a.red - b.red, a.green - b.green, a.blue - b.blue) }
func * (a: Color, s: Double) -> Color { Color(a.red * s, a.green * s, a.blue * s) }
func * (s: Double, a: Color) -> Color { a * s }
// Hadamard product: one color filtering another
func * (a: Color, b: Color) -> Color { Color(a.red * b.red, a.green * b.green, a.blue * b.blue) }

let BLACK = color(0, 0, 0)

// ---------------------------------------------------------------- § 1.3 canvas
final class Canvas {
    let width: Int
    let height: Int
    private var pixels: [Color]

    init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: BLACK, count: max(0, width * height))
    }

    func writePixel(_ x: Int, _ y: Int, _ c: Color) {
        // Writes outside the canvas are silently dropped.
        guard x >= 0, x < width, y >= 0, y < height else { return }
        pixels[y * width + x] = c
    }

    func pixelAt(_ x: Int, _ y: Int) -> Color {
        pixels[y * width + x]
    }

    func fill(_ c: Color) {
        for i in 0..<pixels.count { pixels[i] = c }
    }

    /// Number of pixels equal (within tolerance) to the given color.
    func count(of c: Color) -> Int {
        pixels.reduce(0) { $0 + ($1.equals(c) ? 1 : 0) }
    }
}

func canvas(_ w: Int, _ h: Int) -> Canvas { Canvas(w, h) }
func writePixel(_ c: Canvas, _ x: Int, _ y: Int, _ col: Color) { c.writePixel(x, y, col) }
func pixelAt(_ c: Canvas, _ x: Int, _ y: Int) -> Color { c.pixelAt(x, y) }
func fill(_ c: Canvas, _ col: Color) { c.fill(col) }

// ---------------------------------------------------------------- § 1.4 sRGB
// file value -> light
func decode(_ v: Double) -> Double {
    v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
}

// light -> file value
func encode(_ l: Double) -> Double {
    l <= 0.0031308 ? l * 12.92 : 1.055 * pow(l, 1.0 / 2.4) - 0.055
}

func decode(_ c: Color) -> Color { Color(decode(c.red), decode(c.green), decode(c.blue)) }
func encode(_ c: Color) -> Color { Color(encode(c.red), encode(c.green), encode(c.blue)) }

// ---------------------------------------------------------------- § 1.5 PPM
func clamp01(_ v: Double) -> Double { min(1.0, max(0.0, v)) }

/// Clamp, encode, scale, round -- in that order.
func channelToByte(_ light: Double) -> Int {
    Int((encode(clamp01(light)) * 255).rounded())
}

func canvasToPPM(_ c: Canvas) -> String {
    var out = "P3\n\(c.width) \(c.height)\n255\n"
    for y in 0..<c.height {
        var line = ""
        for x in 0..<c.width {
            let p = c.pixelAt(x, y)
            for v in [p.red, p.green, p.blue] {
                let tok = String(channelToByte(v))
                if line.isEmpty {
                    line = tok
                } else if line.count + 1 + tok.count > 70 {
                    out += line + "\n"
                    line = tok
                } else {
                    line += " " + tok
                }
            }
        }
        out += line + "\n"
    }
    return out
}

// -- § 2.2  a faster file: P6, and readers that take either format ---------

/// P6 is P3 with the numbers written as bytes: the same three header lines
/// with a 6 in place of the 3, exactly one newline, then one byte per channel.
func canvasToP6(_ c: Canvas) -> [UInt8] {
    var out = Array("P6\n\(c.width) \(c.height)\n255\n".utf8)
    out.reserveCapacity(out.count + c.width * c.height * 3)
    for y in 0..<c.height {
        for x in 0..<c.width {
            let p = c.pixelAt(x, y)
            // the same numbers the P3 writer computes: clamp, encode, scale, round
            out.append(UInt8(channelToByte(p.red)))
            out.append(UInt8(channelToByte(p.green)))
            out.append(UInt8(channelToByte(p.blue)))
        }
    }
    return out
}

// -- test helpers that read a PPM back out, in either format ---------------

/// Anything the readers accept: P3 text, or the bytes of either format.
protocol PPMSource { var ppmBytes: [UInt8] { get } }
extension String: PPMSource { var ppmBytes: [UInt8] { Array(utf8) } }
extension Array: PPMSource where Element == UInt8 { var ppmBytes: [UInt8] { self } }

private func isSpaceByte(_ b: UInt8) -> Bool {
    b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09
}

/// Width, height, and every channel value in order -- from P3 or P6.
private func ppmParse(_ src: PPMSource) -> (width: Int, height: Int, values: [Int]) {
    let b = src.ppmBytes
    // look at the first two bytes
    if !(b.count >= 2 && b[0] == 0x50 && b[1] == 0x36) {
        // P3: whitespace-separated text. Drop "P3", width, height, maxval.
        let s = String(decoding: b, as: UTF8.self)
        let toks = s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" || $0 == "\t" })
        let w = Int(toks[1])!, h = Int(toks[2])!
        return (w, h, toks.dropFirst(4).compactMap { Int($0) })
    }
    // P6: read the three header numbers ...
    var i = 2
    var nums: [Int] = []
    while nums.count < 3 {
        while i < b.count && isSpaceByte(b[i]) { i += 1 }
        var n = 0
        while i < b.count && b[i] >= 0x30 && b[i] <= 0x39 { n = n * 10 + Int(b[i] - 0x30); i += 1 }
        nums.append(n)
    }
    i += 1                      // ... skip the single whitespace byte after the last ...
    return (nums[0], nums[1], b[i...].map { Int($0) })   // ... and take the rest as pixels.
}

func ppmPixel(_ src: PPMSource, _ x: Int, _ y: Int) -> (Int, Int, Int) {
    let p = ppmParse(src)
    let i = (y * p.width + x) * 3
    return (p.values[i], p.values[i + 1], p.values[i + 2])
}

func maxChannelDifference(_ a: PPMSource, _ b: PPMSource) -> Int {
    let pa = ppmParse(a), pb = ppmParse(b)
    // different sizes: not comparable. 2x1 and 1x2 hold the same number of
    // bytes, so the dimensions have to be compared, not just the counts.
    if pa.width != pb.width || pa.height != pb.height || pa.values.count != pb.values.count {
        return 255
    }
    var m = 0
    for i in 0..<pa.values.count { m = max(m, abs(pa.values[i] - pb.values[i])) }
    return m
}

func distinctValues(_ src: PPMSource) -> Int {
    Set(ppmParse(src).values).count
}

/// Bytes, now: a P3 file is text that happens to be stored in bytes.
func readFile(_ path: String) -> [UInt8] {
    [UInt8](try! Data(contentsOf: URL(fileURLWithPath: path)))
}

// ---------------------------------------------------------------- § 1.7 mix
var linearBlending = true

/// clamp01, applied to every channel of a color
func clamp01(_ c: Color) -> Color { Color(clamp01(c.red), clamp01(c.green), clamp01(c.blue)) }

/// The fourth argument, when given, overrides the linearBlending switch for
/// this call only -- the switch itself is left untouched.
func mix(_ a: Color, _ b: Color, _ t: Double, _ linear: Bool? = nil) -> Color {
    if linear ?? linearBlending {
        return a + (b - a) * t
    }
    // The browser's way: clamp each end to 0-1 before encoding it, not the
    // lerp's result -- clamping the result instead would agree with this at
    // t = 0 and t = 1 and only disagree in between.
    let ea = encode(clamp01(a)), eb = encode(clamp01(b))
    return decode(ea + (eb - ea) * t)
}

// ---------------------------------------------------------------- pictures
func grayMatch() -> Canvas {
    let c = canvas(300, 100)
    for y in 0...99 {
        for x in 0...99 {
            writePixel(c, x, y, (x + y) % 2 == 0 ? color(1, 1, 1) : color(0, 0, 0))
        }
    }
    let g = decode(128.0 / 255.0)
    for y in 0...99 { for x in 100...199 { writePixel(c, x, y, color(g, g, g)) } }
    for y in 0...99 { for x in 200...299 { writePixel(c, x, y, color(0.5, 0.5, 0.5)) } }
    return c
}

func quarterMatch() -> Canvas {
    let c = canvas(200, 100)
    for y in 0...99 {
        for x in 0...99 {
            writePixel(c, x, y, (x + y) % 4 == 0 ? color(1, 1, 1) : color(0, 0, 0))
        }
    }
    for y in 0...99 { for x in 100...199 { writePixel(c, x, y, color(0.25, 0.25, 0.25)) } }
    return c
}

func ramp() -> Canvas {
    let c = canvas(256, 32)
    for x in 0...255 {
        let g = Double(x) / 255.0
        for y in 0...31 { writePixel(c, x, y, color(g, g, g)) }
    }
    return c
}

func clampPair() -> Canvas {
    let c = canvas(200, 100)
    for y in 0...99 {
        for x in 0...99 { writePixel(c, x, y, color(2, 0.5, 0.5)) }
        for x in 100...199 { writePixel(c, x, y, color(1, 0.25, 0.25)) }
    }
    return c
}

func plate01() -> Canvas {
    let c = canvas(400, 180)
    let ramps = [(color(0, 0, 0), color(1, 1, 1)),
                 (color(0.7, 0, 0), color(0, 0.3, 0.02))]
    for (i, pair) in ramps.enumerated() {
        let (a, b) = pair
        let top = i * 90
        for x in 0...399 {
            let t = Double(x) / 399.0
            linearBlending = false
            let naive = mix(a, b, t)
            linearBlending = true
            let light = mix(a, b, t)
            for y in top...(top + 39) { writePixel(c, x, y, naive) }
            for y in (top + 45)...(top + 84) { writePixel(c, x, y, light) }
        }
    }
    return c
}

// ---------------------------------------------------------------- § 2.1 shapes
// A shape is a function from a point to yes or no. That's the whole interface.
struct Shape {
    let test: (Double, Double) -> Bool
}

func inside(_ s: Shape, _ x: Double, _ y: Double) -> Bool { s.test(x, y) }

/// Inside means within the radius, boundary included.
func circle(_ cx: Double, _ cy: Double, _ r: Double) -> Shape {
    Shape { x, y in
        let dx = x - cx, dy = y - cy
        return dx * dx + dy * dy <= r * r
    }
}

/// Left, top, right, bottom. Boundary included.
func rectangle(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> Shape {
    Shape { x, y in x >= x0 && x <= x1 && y >= y0 && y <= y1 }
}

/// Everything on the side the normal points to. A point is inside when the
/// vector from (px, py) to it has a non-negative dot product with the normal.
/// The normal needn't have length 1.
func halfPlane(_ px: Double, _ py: Double, _ nx: Double, _ ny: Double) -> Shape {
    Shape { x, y in (x - px) * nx + (y - py) * ny >= 0 }
}

// ---------------------------------------------------------------- § 2.3 loupe
/// k times wider and taller, every pixel repeated into a k-by-k block.
/// No smoothing, no averaging, no cleverness.
func magnify(_ c: Canvas, _ k: Int) -> Canvas {
    let m = canvas(c.width * k, c.height * k)
    for y in 0..<m.height {
        for x in 0..<m.width {
            m.writePixel(x, y, c.pixelAt(x / k, y / k))
        }
    }
    return m
}

// ---------------------------------------------------------------- § 2.4 coverage buffer
/// A canvas of numbers instead of colors: one value per pixel, 0 to 1.
final class CoverageBuffer {
    let width: Int
    let height: Int
    private var values: [Double]

    init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
        self.values = Array(repeating: 0, count: max(0, width * height))
    }

    func setCoverage(_ x: Int, _ y: Int, _ v: Double) {
        // As with the canvas, writes outside the buffer are dropped.
        guard x >= 0, x < width, y >= 0, y < height else { return }
        values[y * width + x] = v
    }

    func coverageAt(_ x: Int, _ y: Int) -> Double {
        guard x >= 0, x < width, y >= 0, y < height else { return 0 }
        return values[y * width + x]
    }

    /// The total: the area of the shape, in pixels, as the buffer sees it.
    var ink: Double { values.reduce(0, +) }
}

func coverageBuffer(_ w: Int, _ h: Int) -> CoverageBuffer { CoverageBuffer(w, h) }
func setCoverage(_ cov: CoverageBuffer, _ x: Int, _ y: Int, _ v: Double) { cov.setCoverage(x, y, v) }
func coverageAt(_ cov: CoverageBuffer, _ x: Int, _ y: Int) -> Double { cov.coverageAt(x, y) }
func ink(_ cov: CoverageBuffer) -> Double { cov.ink }

/// Pixel (x, y) is the square from (x, y) to (x + 1, y + 1), so its center is
/// (x + 0.5, y + 0.5). 1 if that center is inside, 0 if not.
func centerInside(_ s: Shape, _ x: Int, _ y: Int) -> Double {
    inside(s, Double(x) + 0.5, Double(y) + 0.5) ? 1 : 0
}

func rasterizeCenters(_ s: Shape, _ w: Int, _ h: Int) -> CoverageBuffer {
    let cov = coverageBuffer(w, h)
    for y in 0..<h {
        for x in 0..<w {
            cov.setCoverage(x, y, centerInside(s, x, y))
        }
    }
    return cov
}

// ---------------------------------------------------------------- § 2.5 paint
/// Move every pixel of the canvas toward the color by that pixel's coverage:
/// mix(pixel, color, coverage) with the switch forced to the light's way,
/// mix(pixel, color, coverage, true). The browser-style switch has no
/// business inside the rasterizer, so this does the linear arithmetic
/// directly instead of going through the switchable mix().
/// The one place the renderer touches the canvas.
func paintThrough(_ c: Canvas, _ cov: CoverageBuffer, _ col: Color) {
    for y in 0..<c.height {
        for x in 0..<c.width {
            let t = cov.coverageAt(x, y)
            if t == 0 { continue }              // zero coverage leaves a pixel alone
            let p = c.pixelAt(x, y)
            c.writePixel(x, y, p + (col - p) * t)
        }
    }
}

// ---------------------------------------------------------------- § 2.6 the better question
let SAMPLE_GRID = 8

/// Divide the pixel into an 8-by-8 grid, put one sample at the center of each
/// cell, ask the shape about all 64, and divide the count by 64.
func coverage(_ s: Shape, _ x: Int, _ y: Int) -> Double {
    let n = SAMPLE_GRID
    var count = 0
    for j in 0..<n {
        let sy = Double(y) + (Double(j) + 0.5) / Double(n)
        for i in 0..<n {
            let sx = Double(x) + (Double(i) + 0.5) / Double(n)
            if inside(s, sx, sy) { count += 1 }
        }
    }
    return Double(count) / Double(n * n)
}

func rasterize(_ s: Shape, _ w: Int, _ h: Int) -> CoverageBuffer {
    let cov = coverageBuffer(w, h)
    for y in 0..<h {
        for x in 0..<w {
            cov.setCoverage(x, y, coverage(s, x, y))
        }
    }
    return cov
}

// ---------------------------------------------------------------- pictures
func discCenters() -> Canvas {
    let c = canvas(40, 40)
    fill(c, color(0.02, 0.02, 0.025))
    let cov = rasterizeCenters(circle(20, 20, 16), 40, 40)
    paintThrough(c, cov, color(0.9, 0.55, 0.1))
    return magnify(c, 8)
}

func discCoverage() -> Canvas {
    let c = canvas(40, 40)
    fill(c, color(0.02, 0.02, 0.025))
    let cov = rasterize(circle(20, 20, 16), 40, 40)
    paintThrough(c, cov, color(0.9, 0.55, 0.1))
    return magnify(c, 8)
}

// § 2.7  the same disc, painted once on the left and twice on the right
func paintedTwice() -> Canvas {
    let c = canvas(80, 40)
    fill(c, color(0.02, 0.02, 0.025))
    let cov = rasterize(circle(20, 20, 16), 40, 40)
    let once = coverageBuffer(80, 40)           // the disc in both halves
    for y in 0...39 {
        for x in 0...39 {
            setCoverage(once, x, y, coverageAt(cov, x, y))
            setCoverage(once, x + 40, y, coverageAt(cov, x, y))
        }
    }
    paintThrough(c, once, color(0.9, 0.55, 0.1))
    let twice = coverageBuffer(80, 40)          // the disc in the right half only
    for y in 0...39 {
        for x in 0...39 {
            setCoverage(twice, x + 40, y, coverageAt(cov, x, y))
        }
    }
    paintThrough(c, twice, color(0.9, 0.55, 0.1))
    return magnify(c, 6)
}

func plate02() -> Canvas {
    let c = canvas(80, 40)
    fill(c, color(0.02, 0.02, 0.025))
    let shape = circle(20, 20, 16)
    let left = rasterizeCenters(shape, 40, 40)
    let right = rasterize(shape, 40, 40)
    let both = coverageBuffer(80, 40)
    for y in 0...39 {
        for x in 0...39 {
            setCoverage(both, x, y, coverageAt(left, x, y))
            setCoverage(both, x + 40, y, coverageAt(right, x, y))
        }
    }
    paintThrough(c, both, color(0.9, 0.55, 0.1))
    return magnify(c, 6)
}

// ---------------------------------------------------------------- § 3.1 Bresenham
/// A test helper, not a renderer function: every pixel of the canvas that
/// isn't black, with the usual tolerance, in reading order (top row first,
/// left to right within a row).
func litPixels(_ c: Canvas) -> [(Int, Int)] {
    var result: [(Int, Int)] = []
    for y in 0..<c.height {
        for x in 0..<c.width {
            if !c.pixelAt(x, y).equals(BLACK) { result.append((x, y)) }
        }
    }
    return result
}

/// One pixel per column (or row, if steep) chosen with integer-only
/// arithmetic. Ranges are inclusive at both ends, as always.
func lineBresenham(_ c: Canvas, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ col: Color) {
    var x0 = x0, y0 = y0, x1 = x1, y1 = y1
    let steep = abs(y1 - y0) > abs(x1 - x0)
    if steep {
        swap(&x0, &y0)
        swap(&x1, &y1)
    }
    if x0 > x1 {
        swap(&x0, &x1)
        swap(&y0, &y1)
    }
    let dx = x1 - x0
    let dy = abs(y1 - y0)
    let ystep = y0 < y1 ? 1 : -1
    var err = dx / 2                      // integer division
    var y = y0
    for x in x0...x1 {
        if steep { c.writePixel(y, x, col) }  // swap back on the way out
        else     { c.writePixel(x, y, col) }
        err -= dy
        if err < 0 {
            y += ystep
            err += dx
        }
    }
}

// ---------------------------------------------------------------- pictures
/// Twelve points, 30 degrees apart, 72 pixels out from (80, 80), rounded to
/// integers.
func rayEnds() -> [(Int, Int)] {
    var ends: [(Int, Int)] = []
    for k in 0...11 {
        let a = Double(k) * 30.0 * Double.pi / 180.0
        let x = Int((80 + 72 * cos(a)).rounded())
        let y = Int((80 + 72 * sin(a)).rounded())
        ends.append((x, y))
    }
    return ends
}

func fanBresenham() -> Canvas {
    let c = canvas(160, 160)
    fill(c, color(0.02, 0.02, 0.025))
    for (x, y) in rayEnds() {
        lineBresenham(c, 80, 80, x, y, color(0.92, 0.92, 0.88))
    }
    return c
}

// ---------------------------------------------------------------- § 3.2 Wu
/// paint_through for one pixel: mixes the pixel toward col by weight, drops
/// writes off the canvas, and, as a shortcut rather than a rule, skips a
/// weight of zero.
func plot(_ c: Canvas, _ x: Int, _ y: Int, _ col: Color, _ weight: Double) {
    guard x >= 0, x < c.width, y >= 0, y < c.height else { return }
    if weight == 0 { return }
    c.writePixel(x, y, mix(c.pixelAt(x, y), col, weight))
}

/// Two pixels per column (or row, if steep), weighted by where the ideal
/// line falls between them. Integer endpoints only.
func lineWu(_ c: Canvas, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ col: Color) {
    var x0 = x0, y0 = y0, x1 = x1, y1 = y1
    let steep = abs(y1 - y0) > abs(x1 - x0)
    if steep {
        swap(&x0, &y0)
        swap(&x1, &y1)
    }
    if x0 > x1 {
        swap(&x0, &x1)
        swap(&y0, &y1)
    }
    let dx = x1 - x0
    let slope = dx == 0 ? 0.0 : Double(y1 - y0) / Double(dx)
    for x in x0...x1 {
        let y = Double(y0) + Double(x - x0) * slope
        let yi = Int(floor(y))               // floor, not truncation
        let f = y - Double(yi)
        if steep {
            plot(c, yi, x, col, 1 - f)
            plot(c, yi + 1, x, col, f)
        } else {
            plot(c, x, yi, col, 1 - f)
            plot(c, x, yi + 1, col, f)
        }
    }
}

/// Sum of every pixel's red channel: for a white line on black, exactly how
/// much paint went down.
func totalInk(_ c: Canvas) -> Double {
    var sum = 0.0
    for y in 0..<c.height {
        for x in 0..<c.width {
            sum += c.pixelAt(x, y).red
        }
    }
    return sum
}

// ---------------------------------------------------------------- pictures
func fanWu() -> Canvas {
    let c = canvas(160, 160)
    fill(c, color(0.02, 0.02, 0.025))
    for (x, y) in rayEnds() {
        lineWu(c, 80, 80, x, y, color(0.92, 0.92, 0.88))
    }
    return c
}

// ---------------------------------------------------------------- § 3.3 the reveal
/// A line is a shape. Chapter 4 factors the rectangle-of-half-planes logic
/// out into `segment`, which takes real endpoints instead of pixel indices;
/// thick_line becomes that one-liner, the pixel centers taken up front.
func thickLine(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ width: Double) -> Shape {
    segment(point(Double(x0) + 0.5, Double(y0) + 0.5),
            point(Double(x1) + 0.5, Double(y1) + 0.5),
            width)
}

// ---------------------------------------------------------------- pictures
func fanCoverage() -> Canvas {
    let c = canvas(160, 160)
    fill(c, color(0.02, 0.02, 0.025))
    for (x, y) in rayEnds() {
        let cov = rasterize(thickLine(80, 80, x, y, 1), 160, 160)
        paintThrough(c, cov, color(0.92, 0.92, 0.88))
    }
    return magnify(c, 2)
}

// ---------------------------------------------------------------- § 3.4 putting it together
func plate03() -> Canvas {
    let both = canvas(320, 160)
    let a = fanBresenham()
    let b = fanWu()
    for y in 0...159 {
        for x in 0...159 {
            writePixel(both, x, y, pixelAt(a, x, y))
            writePixel(both, x + 160, y, pixelAt(b, x, y))
        }
    }
    return magnify(both, 2)
}

// ==================================================================
// Chapter 4 -- Points, Vectors, Transforms
// ==================================================================

// ---------------------------------------------------------------- § 4.1 points and vectors
/// A point is a place, a vector is a displacement: both are (x, y, w) with
/// w = 1 for a point and w = 0 for a vector, so the matrices in §4.2 can
/// tell them apart from the arithmetic alone.
struct Tuple {
    var x: Double
    var y: Double
    var w: Double
}

func point(_ x: Double, _ y: Double) -> Tuple { Tuple(x: x, y: y, w: 1) }
func vector(_ x: Double, _ y: Double) -> Tuple { Tuple(x: x, y: y, w: 0) }

extension Tuple {
    func equals(_ o: Tuple, _ eps: Double = EPSILON) -> Bool {
        equal(x, o.x, eps) && equal(y, o.y, eps) && equal(w, o.w, eps)
    }
}

func + (a: Tuple, b: Tuple) -> Tuple { Tuple(x: a.x + b.x, y: a.y + b.y, w: a.w + b.w) }
func - (a: Tuple, b: Tuple) -> Tuple { Tuple(x: a.x - b.x, y: a.y - b.y, w: a.w - b.w) }
prefix func - (a: Tuple) -> Tuple { Tuple(x: -a.x, y: -a.y, w: -a.w) }
func * (a: Tuple, s: Double) -> Tuple { Tuple(x: a.x * s, y: a.y * s, w: a.w * s) }
func / (a: Tuple, s: Double) -> Tuple { Tuple(x: a.x / s, y: a.y / s, w: a.w / s) }

func magnitude(_ v: Tuple) -> Double { hypot(v.x, v.y) }
func normalize(_ v: Tuple) -> Tuple {
    let m = magnitude(v)
    return Tuple(x: v.x / m, y: v.y / m, w: v.w / m)
}
func dot(_ a: Tuple, _ b: Tuple) -> Double { a.x * b.x + a.y * b.y }
/// The 2-D cross product is a number, not a vector: the signed area of the
/// parallelogram a and b span. Positive means b is counterclockwise from a
/// in the numbers -- clockwise on a canvas, because y points down.
func cross(_ a: Tuple, _ b: Tuple) -> Double { a.x * b.y - a.y * b.x }

// ---------------------------------------------------------------- § 4.2 matrices
/// Nine numbers, row by row. M[r, c] is the entry at row r, column c, both
/// counted from zero.
struct Matrix3 {
    var cells: [Double]

    subscript(_ r: Int, _ c: Int) -> Double { cells[r * 3 + c] }
}

func matrix3(_ a: Double, _ b: Double, _ c: Double,
             _ d: Double, _ e: Double, _ f: Double,
             _ g: Double, _ h: Double, _ i: Double) -> Matrix3 {
    Matrix3(cells: [a, b, c, d, e, f, g, h, i])
}

func identity() -> Matrix3 { matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1) }

extension Matrix3 {
    func equals(_ o: Matrix3, _ eps: Double = EPSILON) -> Bool {
        zip(cells, o.cells).allSatisfy { equal($0, $1, eps) }
    }
}

/// (A * B)[r, c] is the dot product of row r of A with column c of B.
func * (a: Matrix3, b: Matrix3) -> Matrix3 {
    var cells = [Double](repeating: 0, count: 9)
    for r in 0..<3 {
        for c in 0..<3 {
            cells[r * 3 + c] = a[r, 0] * b[0, c] + a[r, 1] * b[1, c] + a[r, 2] * b[2, c]
        }
    }
    return Matrix3(cells: cells)
}

/// A matrix times a tuple, treating (x, y, w) as a column. Every matrix in
/// this book has a bottom row of 0 0 1, so the third dot product always
/// comes out as w unchanged: points stay points, vectors stay vectors.
func * (a: Matrix3, t: Tuple) -> Tuple {
    Tuple(x: a[0, 0] * t.x + a[0, 1] * t.y + a[0, 2] * t.w,
          y: a[1, 0] * t.x + a[1, 1] * t.y + a[1, 2] * t.w,
          w: a[2, 0] * t.x + a[2, 1] * t.y + a[2, 2] * t.w)
}

func transpose(_ m: Matrix3) -> Matrix3 {
    matrix3(m[0, 0], m[1, 0], m[2, 0],
            m[0, 1], m[1, 1], m[2, 1],
            m[0, 2], m[1, 2], m[2, 2])
}

/// The 2x2 determinant left when row r and column c are deleted.
func minor(_ m: Matrix3, _ r: Int, _ c: Int) -> Double {
    let rows = (0..<3).filter { $0 != r }
    let cols = (0..<3).filter { $0 != c }
    return m[rows[0], cols[0]] * m[rows[1], cols[1]] - m[rows[0], cols[1]] * m[rows[1], cols[0]]
}

func cofactor(_ m: Matrix3, _ r: Int, _ c: Int) -> Double {
    (r + c) % 2 != 0 ? -minor(m, r, c) : minor(m, r, c)
}

/// A cofactor expansion along the first row.
func determinant(_ m: Matrix3) -> Double {
    m[0, 0] * cofactor(m, 0, 0) + m[0, 1] * cofactor(m, 0, 1) + m[0, 2] * cofactor(m, 0, 2)
}

func isInvertible(_ m: Matrix3) -> Bool { determinant(m) != 0 }

/// The matrix of cofactors, transposed, divided by the determinant. The
/// transpose happens in the assignment itself: result[c, r], not [r, c].
func inverse(_ m: Matrix3) -> Matrix3 {
    let d = determinant(m)
    var cells = [Double](repeating: 0, count: 9)
    for r in 0..<3 {
        for c in 0..<3 {
            cells[c * 3 + r] = cofactor(m, r, c) / d
        }
    }
    return Matrix3(cells: cells)
}

// ---------------------------------------------------------------- § 4.3 the transforms
func translation(_ tx: Double, _ ty: Double) -> Matrix3 { matrix3(1, 0, tx, 0, 1, ty, 0, 0, 1) }
func scaling(_ sx: Double, _ sy: Double) -> Matrix3 { matrix3(sx, 0, 0, 0, sy, 0, 0, 0, 1) }
/// A positive angle turns the x axis toward the y axis: counterclockwise on
/// paper, clockwise on a canvas whose y points down.
func rotation(_ r: Double) -> Matrix3 {
    let c = cos(r), s = sin(r)
    return matrix3(c, -s, 0, s, c, 0, 0, 0, 1)
}
func shearing(_ xy: Double, _ yx: Double) -> Matrix3 { matrix3(1, xy, 0, yx, 1, 0, 0, 0, 1) }

// ---------------------------------------------------------------- § 4.4 how big is a transform
/// The square root of the area factor: exact for uniform scales and
/// rotations, a compromise (the geometric mean of the axis factors) for
/// non-uniform scales and shears. The absolute value handles a reflection,
/// whose determinant is negative but which is still a scale of 1.
func approxScale(_ m: Matrix3) -> Double {
    sqrt(abs(m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0]))
}

// ---------------------------------------------------------------- § 4.5 transforming what you draw
/// The rectangle of the given width centered on the segment from a to b,
/// square ends: four half-planes. A segment of no length has no direction,
/// so it gets (1, 0) and becomes a width-by-width square -- the same rule
/// thick_line used, one dimension up (real coordinates, not pixel indices).
func segment(_ a: Tuple, _ b: Tuple, _ width: Double) -> Shape {
    var ax = a.x, ay = a.y, bx = b.x, by = b.y
    let h = width / 2
    let length = hypot(bx - ax, by - ay)
    var dx: Double, dy: Double
    if length == 0 {
        dx = 1; dy = 0
        ax -= h; bx += h
    } else {
        dx = (bx - ax) / length
        dy = (by - ay) / length
    }
    let nx = -dy, ny = dx
    let ahead  = halfPlane(ax, ay, dx, dy)
    let behind = halfPlane(bx, by, -dx, -dy)
    let left   = halfPlane(ax + nx * h, ay + ny * h, -nx, -ny)
    let right  = halfPlane(ax - nx * h, ay - ny * h, nx, ny)
    return Shape { x, y in
        inside(ahead, x, y) && inside(behind, x, y) && inside(left, x, y) && inside(right, x, y)
    }
}

/// A shape that's inside when any of its parts is: one more case in
/// `inside`, a loop with an early exit.
func union(_ shapes: [Shape]) -> Shape {
    Shape { x, y in shapes.contains { inside($0, x, y) } }
}

/// The shape seen through m: to test a device point, run it backwards
/// through the inverse and ask the original. A shape with no inverse can't
/// have anything inside it -- nothing can be inside a shape flattened to a
/// line.
func transformed(_ s: Shape, _ m: Matrix3) -> Shape {
    guard isInvertible(m) else { return Shape { _, _ in false } }
    let inv = inverse(m)
    return Shape { x, y in
        let p = inv * point(x, y)
        return inside(s, p.x, p.y)
    }
}

func transformPoints(_ points: [Tuple], _ m: Matrix3) -> [Tuple] {
    points.map { m * $0 }
}

/// The closed polygon through the points after m, every edge a segment of
/// that width in device space, as one shape -- so a corner shared by two
/// edges is painted once by the union's coverage, not twice by each edge.
func outline(_ points: [Tuple], _ m: Matrix3, _ width: Double) -> Shape {
    let pts = transformPoints(points, m)
    var segs: [Shape] = []
    for i in 0..<pts.count {
        segs.append(segment(pts[i], pts[(i + 1) % pts.count], width))
    }
    return union(segs)
}

// ---------------------------------------------------------------- § 4.6 putting it together
/// Copies a canvas pixel for pixel -- used to stamp the same ghost onto two
/// canvases before drawing each order of the F on top of one of them.
func copyCanvas(_ c: Canvas) -> Canvas {
    let out = canvas(c.width, c.height)
    for y in 0..<c.height { for x in 0..<c.width { out.writePixel(x, y, c.pixelAt(x, y)) } }
    return out
}

/// a into the left half of a wider canvas, b into the right.
func sideBySide(_ a: Canvas, _ b: Canvas) -> Canvas {
    let out = canvas(a.width + b.width, max(a.height, b.height))
    for y in 0..<a.height { for x in 0..<a.width { out.writePixel(x, y, a.pixelAt(x, y)) } }
    for y in 0..<b.height { for x in 0..<b.width { out.writePixel(a.width + x, y, b.pixelAt(x, y)) } }
    return out
}

/// Twelve points around the origin, real coordinates, no rounding: the
/// center first, then twelve ends at radius 36.
func fanPoints() -> [Tuple] {
    var pts = [point(0, 0)]
    for k in 0..<12 {
        let a = Double(k) * 30.0 * Double.pi / 180.0
        pts.append(point(36 * cos(a), 36 * sin(a)))
    }
    return pts
}

func fanTransformed(_ m: Matrix3) -> Canvas {
    let c = canvas(160, 160)
    fill(c, color(0.02, 0.02, 0.025))
    let pts = transformPoints(fanPoints(), m)
    var rays: [Shape] = []
    for k in 1...12 { rays.append(segment(pts[0], pts[k], 1)) }
    paintThrough(c, rasterize(union(rays), 160, 160), color(0.92, 0.92, 0.88))
    return c
}

func fanBothOrders() -> Canvas {
    let turn = rotation(Double.pi / 6)
    let move = translation(104.5, 76.5)
    return sideBySide(fanTransformed(move * turn), fanTransformed(turn * move))
}

/// Ten corners, clockwise from the top left, in a box 40 wide and 60 tall
/// centered on the origin, so a rotation about the origin is a rotation
/// about the letter's middle.
func letterF() -> [Tuple] {
    [point(-20, -30), point(20, -30), point(20, -20), point(-10, -20),
     point(-10, -5),  point(12, -5),  point(12, 5),   point(-10, 5),
     point(-10, 30),  point(-20, 30)]
}

func fGhost() -> Canvas {
    let c = canvas(160, 160)
    fill(c, color(0.02, 0.02, 0.025))
    let home = translation(44.5, 44.5)
    paintThrough(c, rasterize(outline(letterF(), home, 1), 160, 160), color(0.16, 0.16, 0.17))
    return c
}

func fBothOrders() -> Canvas {
    let turn = rotation(Double.pi / 6)
    let move = translation(104.5, 76.5)
    let ghost = fGhost()
    let a = copyCanvas(ghost), b = copyCanvas(ghost)
    let inkColor = color(0.92, 0.92, 0.88)
    paintThrough(a, rasterize(outline(letterF(), move * turn, 1), 160, 160), inkColor)
    paintThrough(b, rasterize(outline(letterF(), turn * move, 1), 160, 160), inkColor)
    return sideBySide(a, b)
}

func plate04() -> Canvas { magnify(fBothOrders(), 2) }
