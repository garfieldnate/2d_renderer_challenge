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

// -- test helpers that read a PPM back out of its text ---------------------

private func ppmTokens(_ ppm: String) -> [Int] {
    ppm.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" || $0 == "\t" })
       .compactMap { Int($0) }
}

/// (P3, width, height, maxval) -- P3 is not an Int so it drops out of the token
/// list above; parse the header separately to keep this honest.
private func ppmHeader(_ ppm: String) -> (width: Int, height: Int) {
    let toks = ppm.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\r" || $0 == "\t" })
    return (Int(toks[1])!, Int(toks[2])!)
}

private func ppmBody(_ ppm: String) -> [Int] {
    // skip width, height, maxval (P3 already dropped by compactMap)
    Array(ppmTokens(ppm).dropFirst(3))
}

func ppmPixel(_ ppm: String, _ x: Int, _ y: Int) -> (Int, Int, Int) {
    let (w, _) = ppmHeader(ppm)
    let body = ppmBody(ppm)
    let i = (y * w + x) * 3
    return (body[i], body[i + 1], body[i + 2])
}

func maxChannelDifference(_ a: String, _ b: String) -> Int {
    let pa = ppmBody(a), pb = ppmBody(b)
    var m = 0
    for i in 0..<min(pa.count, pb.count) { m = max(m, abs(pa[i] - pb[i])) }
    if pa.count != pb.count { m = max(m, 255) }  // different sizes: not comparable
    return m
}

func distinctValues(_ ppm: String) -> Int {
    Set(ppmBody(ppm)).count
}

func readFile(_ path: String) -> String {
    try! String(contentsOfFile: path, encoding: .utf8)
}

// ---------------------------------------------------------------- § 1.7 mix
var linearBlending = true

func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
    if linearBlending {
        return a + (b - a) * t
    }
    let ea = encode(a), eb = encode(b)
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
