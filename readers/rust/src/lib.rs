//! Chapter 1: The Canvas and the Color.
//!
//! A tiny renderer: colors are three floating point numbers that measure
//! light (0.0 = none, 1.0 = full), a canvas is a rectangle of colors, and
//! the PPM writer is the only place that knows about the sRGB transfer
//! function that turns light into the numbers an image file expects.

use std::cell::Cell;
use std::collections::BTreeSet;
use std::fs;
use std::ops::{Add, Div, Index, Mul, Neg, Sub};

// ---------------------------------------------------------------------
// § 1.1 Comparing numbers
// ---------------------------------------------------------------------

/// The book's default tolerance: `a = b` means `|a - b| <= 0.0001`.
pub const DEFAULT_EPSILON: f64 = 0.0001;

/// Compare two numbers within the default tolerance.
pub fn approx_eq(a: f64, b: f64) -> bool {
    approx_eq_eps(a, b, DEFAULT_EPSILON)
}

/// Compare two numbers within an explicit tolerance (`a = b ± eps`).
pub fn approx_eq_eps(a: f64, b: f64, eps: f64) -> bool {
    (a - b).abs() <= eps
}

// ---------------------------------------------------------------------
// § 1.2 A color is three numbers
// ---------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Color {
    pub red: f64,
    pub green: f64,
    pub blue: f64,
}

pub fn color(red: f64, green: f64, blue: f64) -> Color {
    Color { red, green, blue }
}

impl Add for Color {
    type Output = Color;
    fn add(self, other: Color) -> Color {
        color(self.red + other.red, self.green + other.green, self.blue + other.blue)
    }
}

impl Sub for Color {
    type Output = Color;
    fn sub(self, other: Color) -> Color {
        color(self.red - other.red, self.green - other.green, self.blue - other.blue)
    }
}

/// Scale a color by a number: `c * 2`.
impl Mul<f64> for Color {
    type Output = Color;
    fn mul(self, s: f64) -> Color {
        color(self.red * s, self.green * s, self.blue * s)
    }
}

/// The Hadamard product: `c1 * c2`, component by component.
impl Mul<Color> for Color {
    type Output = Color;
    fn mul(self, other: Color) -> Color {
        color(self.red * other.red, self.green * other.green, self.blue * other.blue)
    }
}

/// Colors compare component by component, with the usual tolerance.
pub fn colors_eq(a: Color, b: Color) -> bool {
    approx_eq(a.red, b.red) && approx_eq(a.green, b.green) && approx_eq(a.blue, b.blue)
}

/// Colors compare component by component, with an explicit tolerance
/// (used by the `± 1` file-value comparisons).
pub fn colors_eq_eps(a: Color, b: Color, eps: f64) -> bool {
    approx_eq_eps(a.red, b.red, eps)
        && approx_eq_eps(a.green, b.green, eps)
        && approx_eq_eps(a.blue, b.blue, eps)
}

// ---------------------------------------------------------------------
// § 1.3 The canvas
// ---------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct Canvas {
    pub width: usize,
    pub height: usize,
    pixels: Vec<Color>,
}

const BLACK: Color = Color { red: 0.0, green: 0.0, blue: 0.0 };

pub fn canvas(width: usize, height: usize) -> Canvas {
    Canvas { width, height, pixels: vec![BLACK; width * height] }
}

/// Write a color at (x, y). Writes outside the canvas are silently ignored.
/// x and y are signed so that out-of-range negative coordinates can be
/// expressed at all, per the "writing outside the canvas is ignored" scenario.
pub fn write_pixel(c: &mut Canvas, x: i64, y: i64, col: Color) {
    if x < 0 || y < 0 {
        return;
    }
    let (x, y) = (x as usize, y as usize);
    if x >= c.width || y >= c.height {
        return;
    }
    c.pixels[y * c.width + x] = col;
}

pub fn pixel_at(c: &Canvas, x: i64, y: i64) -> Color {
    let (x, y) = (x as usize, y as usize);
    c.pixels[y * c.width + x]
}

pub fn fill(c: &mut Canvas, col: Color) {
    for p in c.pixels.iter_mut() {
        *p = col;
    }
}

/// Test helper: true if every pixel of the canvas equals `col`.
pub fn all_pixels_are(c: &Canvas, col: Color) -> bool {
    c.pixels.iter().all(|p| colors_eq(*p, col))
}

/// Test helper: how many pixels of the canvas equal `col`.
pub fn count_pixels(c: &Canvas, col: Color) -> usize {
    c.pixels.iter().filter(|p| colors_eq(**p, col)).count()
}

// ---------------------------------------------------------------------
// § 1.4 The numbers are not the light: sRGB transfer functions
// ---------------------------------------------------------------------

/// file value -> light
pub fn decode(v: f64) -> f64 {
    if v <= 0.04045 {
        v / 12.92
    } else {
        ((v + 0.055) / 1.055).powf(2.4)
    }
}

/// light -> file value
pub fn encode(l: f64) -> f64 {
    if l <= 0.0031308 {
        l * 12.92
    } else {
        1.055 * l.powf(1.0 / 2.4) - 0.055
    }
}

/// Round to the nearest whole number. No scenario in this chapter lands on
/// a half, so the tie-breaking rule doesn't matter.
pub fn round(x: f64) -> i64 {
    x.round() as i64
}

// ---------------------------------------------------------------------
// § 1.5 Getting it out of the computer: PPM output
// ---------------------------------------------------------------------

const MAX_LINE_LEN: usize = 70;

/// Clamp to 0..1, encode, multiply by 255, round: the four steps that turn
/// one light channel into one file byte.
fn channel_to_byte(light: f64) -> i64 {
    let clamped = light.clamp(0.0, 1.0);
    round(encode(clamped) * 255.0)
}

pub fn canvas_to_ppm(c: &Canvas) -> String {
    let mut out = String::new();
    out.push_str("P3\n");
    out.push_str(&format!("{} {}\n", c.width, c.height));
    out.push_str("255\n");

    for y in 0..c.height {
        let mut line = String::new();
        for x in 0..c.width {
            let col = pixel_at(c, x as i64, y as i64);
            for value in [col.red, col.green, col.blue] {
                let token = channel_to_byte(value).to_string();
                if line.is_empty() {
                    line.push_str(&token);
                } else if line.len() + 1 + token.len() > MAX_LINE_LEN {
                    out.push_str(&line);
                    out.push('\n');
                    line.clear();
                    line.push_str(&token);
                } else {
                    line.push(' ');
                    line.push_str(&token);
                }
            }
        }
        out.push_str(&line);
        out.push('\n');
    }

    out
}

/// Reads bytes, not text: a P3 file is text that happens to be stored in
/// bytes, so nothing changes for chapter 1's tests, and a P6 file's pixel
/// data is only meaningful as bytes in the first place.
pub fn read_file(path: &str) -> Vec<u8> {
    fs::read(path).unwrap_or_else(|e| panic!("could not read {path}: {e}"))
}

/// Split a PPM's pixel data into whole numbers, skipping the four header
/// tokens (P3, width, height, maxval).
fn ppm_values(ppm: &str) -> Vec<i64> {
    ppm.split_whitespace()
        .skip(4)
        .map(|s| s.parse().unwrap_or_else(|e| panic!("bad ppm token {s:?}: {e}")))
        .collect()
}

fn ppm_width(ppm: &str) -> usize {
    ppm.split_whitespace()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .expect("ppm has no width header")
}

fn ppm_height(ppm: &str) -> usize {
    ppm.split_whitespace()
        .nth(2)
        .and_then(|s| s.parse().ok())
        .expect("ppm has no height header")
}

/// Read a P6 header: "P6", whitespace, width, whitespace, height,
/// whitespace, maxval, then exactly one whitespace byte before the raw
/// pixel bytes begin. Returns (width, height, offset of the pixel data).
fn p6_header(bytes: &[u8]) -> (usize, usize, usize) {
    fn skip_ws(bytes: &[u8], i: &mut usize) {
        while *i < bytes.len() && bytes[*i].is_ascii_whitespace() {
            *i += 1;
        }
    }
    fn read_num(bytes: &[u8], i: &mut usize) -> usize {
        let start = *i;
        while *i < bytes.len() && bytes[*i].is_ascii_digit() {
            *i += 1;
        }
        std::str::from_utf8(&bytes[start..*i])
            .unwrap()
            .parse()
            .unwrap_or_else(|e| panic!("bad p6 header number: {e}"))
    }

    let mut i = 2; // skip the "P6" magic
    skip_ws(bytes, &mut i);
    let width = read_num(bytes, &mut i);
    skip_ws(bytes, &mut i);
    let height = read_num(bytes, &mut i);
    skip_ws(bytes, &mut i);
    let _maxval = read_num(bytes, &mut i);
    i += 1; // the single whitespace byte after the last header number
    (width, height, i)
}

/// The width, height, and whole-number channel values of a PPM file, read
/// as either P3 (whitespace-separated ASCII digits) or P6 (raw bytes),
/// distinguished by the first two bytes of the file.
fn ppm_dims_and_values(ppm: &[u8]) -> (usize, usize, Vec<i64>) {
    if ppm.starts_with(b"P6") {
        let (width, height, offset) = p6_header(ppm);
        let values = ppm[offset..].iter().map(|b| *b as i64).collect();
        (width, height, values)
    } else {
        let text = std::str::from_utf8(ppm).expect("P3 ppm is not valid UTF-8");
        (ppm_width(text), ppm_height(text), ppm_values(text))
    }
}

/// The three whole numbers at pixel (x, y) of a PPM, as a test helper for
/// reading files back. Accepts either P3 or P6.
pub fn ppm_pixel<T: AsRef<[u8]>>(ppm: T, x: usize, y: usize) -> (i64, i64, i64) {
    let (width, _height, values) = ppm_dims_and_values(ppm.as_ref());
    let idx = (y * width + x) * 3;
    (values[idx], values[idx + 1], values[idx + 2])
}

/// The largest difference between any pair of corresponding numbers in two
/// PPM files. Files of different dimensions can't be compared pixel for
/// pixel, so they're treated as maximally different.
pub fn max_channel_difference<A: AsRef<[u8]>, B: AsRef<[u8]>>(a: A, b: B) -> i64 {
    let (wa, ha, va) = ppm_dims_and_values(a.as_ref());
    let (wb, hb, vb) = ppm_dims_and_values(b.as_ref());
    if wa != wb || ha != hb {
        return 255;
    }
    va.iter()
        .zip(vb.iter())
        .map(|(x, y)| (x - y).abs())
        .max()
        .unwrap_or(0)
}

/// The set of all distinct whole numbers after the header.
pub fn distinct_values<T: AsRef<[u8]>>(ppm: T) -> usize {
    let (_width, _height, values) = ppm_dims_and_values(ppm.as_ref());
    let set: BTreeSet<i64> = values.into_iter().collect();
    set.len()
}

/// Chapter 2's binary sibling of `canvas_to_ppm`: the same header, with a
/// 6 in place of the 3, and the pixel bytes written raw -- clamp, encode,
/// scale, round, same as the P3 writer, just not turned into decimal text.
pub fn canvas_to_p6(c: &Canvas) -> Vec<u8> {
    let mut out = Vec::with_capacity(11 + c.width * c.height * 3);
    out.extend_from_slice(format!("P6\n{} {}\n255\n", c.width, c.height).as_bytes());
    for y in 0..c.height {
        for x in 0..c.width {
            let col = pixel_at(c, x as i64, y as i64);
            for value in [col.red, col.green, col.blue] {
                out.push(channel_to_byte(value) as u8);
            }
        }
    }
    out
}

/// Test helper: the lines of a ppm, 0-indexed.
pub fn ppm_lines(ppm: &str) -> Vec<&str> {
    ppm.lines().collect()
}

// ---------------------------------------------------------------------
// § 1.7 Two ways to mix
// ---------------------------------------------------------------------

// Global state, scoped per test thread: Rust's built-in test harness runs
// every #[test] on its own OS thread, so a thread-local defaulting to "on"
// gives each scenario a fresh switch for free and satisfies the chapter's
// rule ("every scenario that doesn't say otherwise expects it on") without
// an explicit reset step, while staying safe under parallel test execution.
thread_local! {
    static LINEAR_BLENDING: Cell<bool> = const { Cell::new(true) };
}

pub fn set_linear_blending(on: bool) {
    LINEAR_BLENDING.with(|f| f.set(on));
}

pub fn is_linear_blending() -> bool {
    LINEAR_BLENDING.with(|f| f.get())
}

/// The color a fraction `t` of the way from `a` to `b`, using the switch's
/// current setting.
pub fn mix(a: Color, b: Color, t: f64) -> Color {
    mix_with(a, b, t, is_linear_blending())
}

/// `mix`, with the switch passed explicitly instead of read from the
/// thread-local: lets a caller (`paint_through`, for one) force linear
/// blending regardless of what the reader last set, and lets a scenario
/// pass the switch instead of setting it.
pub fn mix_with(a: Color, b: Color, t: f64, linear: bool) -> Color {
    if linear {
        a + (b - a) * t
    } else {
        // The browser's way clamps each end to 0..1 *before* encoding it,
        // not the mixed result afterward -- otherwise an out-of-range
        // input would encode nonsense (negative light, say) instead of
        // landing wherever a browser would have clamped it first.
        let ca = color(a.red.clamp(0.0, 1.0), a.green.clamp(0.0, 1.0), a.blue.clamp(0.0, 1.0));
        let cb = color(b.red.clamp(0.0, 1.0), b.green.clamp(0.0, 1.0), b.blue.clamp(0.0, 1.0));
        let ea = color(encode(ca.red), encode(ca.green), encode(ca.blue));
        let eb = color(encode(cb.red), encode(cb.green), encode(cb.blue));
        let mixed = ea + (eb - ea) * t;
        color(decode(mixed.red), decode(mixed.green), decode(mixed.blue))
    }
}

// ---------------------------------------------------------------------
// § 1.6 / § 1.8 / § 1.9 The figures
// ---------------------------------------------------------------------

/// Figure 1.1: a checkerboard half the light of white, next to two solid
/// grays: file value 128 and file value 188.
pub fn gray_match() -> Canvas {
    let mut c = canvas(300, 100);

    for y in 0..100i64 {
        for x in 0..100i64 {
            let on = (x + y) % 2 == 0;
            let col = if on { color(1.0, 1.0, 1.0) } else { color(0.0, 0.0, 0.0) };
            write_pixel(&mut c, x, y, col);
        }
    }

    let g = decode(128.0 / 255.0);
    for y in 0..100i64 {
        for x in 100..200i64 {
            write_pixel(&mut c, x, y, color(g, g, g));
        }
    }

    for y in 0..100i64 {
        for x in 200..300i64 {
            write_pixel(&mut c, x, y, color(0.5, 0.5, 0.5));
        }
    }

    c
}

/// One pixel in four on: a quarter of the light, next to a solid quarter-gray.
pub fn quarter_match() -> Canvas {
    let mut c = canvas(200, 100);

    for y in 0..100i64 {
        for x in 0..100i64 {
            let on = (x + y) % 4 == 0;
            let col = if on { color(1.0, 1.0, 1.0) } else { color(0.0, 0.0, 0.0) };
            write_pixel(&mut c, x, y, col);
        }
    }

    for y in 0..100i64 {
        for x in 100..200i64 {
            write_pixel(&mut c, x, y, color(0.25, 0.25, 0.25));
        }
    }

    c
}

/// A black-to-white ramp, one column per light level, 256 wide.
pub fn ramp() -> Canvas {
    let mut c = canvas(256, 32);
    for x in 0..256i64 {
        let g = x as f64 / 255.0;
        for y in 0..32i64 {
            write_pixel(&mut c, x, y, color(g, g, g));
        }
    }
    c
}

/// Two patches: a color and exactly half its brightness, both clamped at
/// the top end.
pub fn clamp_pair() -> Canvas {
    let mut c = canvas(200, 100);
    for y in 0..100i64 {
        for x in 0..100i64 {
            write_pixel(&mut c, x, y, color(2.0, 0.5, 0.5));
        }
        for x in 100..200i64 {
            write_pixel(&mut c, x, y, color(1.0, 0.25, 0.25));
        }
    }
    c
}

/// Two ramps, black-to-white and red-to-green, each mixed both ways: the
/// browser's way (encoded space) on top, the light's way beneath.
pub fn plate_01() -> Canvas {
    let mut c = canvas(400, 180);
    let ramps = [
        (color(0.0, 0.0, 0.0), color(1.0, 1.0, 1.0)),
        (color(0.7, 0.0, 0.0), color(0.0, 0.3, 0.02)),
    ];

    for (i, (a, b)) in ramps.iter().enumerate() {
        let top = i as i64 * 90;
        for x in 0..400i64 {
            let t = x as f64 / 399.0;

            set_linear_blending(false);
            let naive = mix(*a, *b, t);
            set_linear_blending(true);
            let light = mix(*a, *b, t);

            for y in top..=(top + 39) {
                write_pixel(&mut c, x, y, naive);
            }
            for y in (top + 45)..=(top + 84) {
                write_pixel(&mut c, x, y, light);
            }
        }
    }

    c
}

// ---------------------------------------------------------------------
// Chapter 2: Coverage
// ---------------------------------------------------------------------
//
// § 2.1 Shapes are questions
// ---------------------------------------------------------------------

/// A shape answers one question: is this point inside you? Coordinates
/// are real numbers, not pixel indices -- (3, 3) is a mathematical point,
/// not the pixel whose top-left corner sits there.
///
/// Chapter 4 adds `Union` and `Transformed`, both of which hold other
/// `Shape`s, so from here on `Shape` is `Clone` rather than `Copy` (a
/// `Vec<Shape>` and a `Box<Shape>` can't be `Copy`). Every function that
/// asks a shape a question -- `inside`, `coverage`, `rasterize` and their
/// kin -- takes `&Shape` rather than `Shape` by value, which is actually
/// less friction than the old by-value convention: a shape used more than
/// once just gets borrowed again, no clone required.
#[derive(Debug, Clone)]
pub enum Shape {
    Circle { cx: f64, cy: f64, r: f64 },
    Rectangle { x0: f64, y0: f64, x1: f64, y1: f64 },
    HalfPlane { px: f64, py: f64, nx: f64, ny: f64 },
    /// Inside all of four half-planes at once (each a (px, py, nx, ny)
    /// tuple, same layout as `HalfPlane`). `segment` (and, through it,
    /// `thick_line`) is the only thing that builds one.
    Intersection([(f64, f64, f64, f64); 4]),
    /// Inside when any of its shapes is. `union` builds one.
    Union(Vec<Shape>),
    /// A shape seen through a matrix: stores the shape and the matrix's
    /// *inverse*, so that `inside` can send a device point backwards into
    /// the shape's own coordinates. `transformed` builds one -- or, if the
    /// matrix has no inverse, an `Empty` instead.
    Transformed(Box<Shape>, Matrix3),
    /// Nothing is ever inside this. What `transformed` returns for a
    /// matrix that collapses the plane, since there's no inverse to send a
    /// point back through.
    Empty,
    /// The inside of a path under a fill rule. `filled` builds one.
    Filled(Box<Path>, Rule),
}

/// A circle given its center and radius. Inside means within the radius,
/// boundary included.
pub fn circle(cx: f64, cy: f64, r: f64) -> Shape {
    Shape::Circle { cx, cy, r }
}

/// A rectangle given its left, top, right and bottom edges. Boundary
/// included.
pub fn rectangle(x0: f64, y0: f64, x1: f64, y1: f64) -> Shape {
    Shape::Rectangle { x0, y0, x1, y1 }
}

/// Everything on one side of a line: a point on the line, and a normal
/// vector (needn't be unit length) pointing into the half you want. A
/// point is inside when the vector from (px, py) to it has a
/// non-negative dot product with the normal.
pub fn half_plane(px: f64, py: f64, nx: f64, ny: f64) -> Shape {
    Shape::HalfPlane { px, py, nx, ny }
}

/// Is (x, y) on the side of the line through (px, py) that the normal
/// (nx, ny) points toward? Shared by `Shape::HalfPlane` and `thick_line`'s
/// four planes, so the rule lives in exactly one place.
fn half_plane_inside(px: f64, py: f64, nx: f64, ny: f64, x: f64, y: f64) -> bool {
    let dx = x - px;
    let dy = y - py;
    dx * nx + dy * ny >= 0.0
}

pub fn inside(s: &Shape, x: f64, y: f64) -> bool {
    match s {
        Shape::Circle { cx, cy, r } => {
            let dx = x - *cx;
            let dy = y - *cy;
            dx * dx + dy * dy <= r * r
        }
        Shape::Rectangle { x0, y0, x1, y1 } => x >= *x0 && x <= *x1 && y >= *y0 && y <= *y1,
        Shape::HalfPlane { px, py, nx, ny } => half_plane_inside(*px, *py, *nx, *ny, x, y),
        Shape::Intersection(planes) => planes
            .iter()
            .all(|&(px, py, nx, ny)| half_plane_inside(px, py, nx, ny, x, y)),
        Shape::Union(shapes) => shapes.iter().any(|sh| inside(sh, x, y)),
        Shape::Transformed(shape, inv) => {
            let p = *inv * point(x, y);
            inside(shape, p.x, p.y)
        }
        Shape::Empty => false,
        Shape::Filled(path, rule) => match rule {
            Rule::NonZero => inside_nonzero(path, x, y),
            Rule::EvenOdd => inside_evenodd(path, x, y),
        },
    }
}

// ---------------------------------------------------------------------
// § 2.3 A loupe: magnify
// ---------------------------------------------------------------------

/// Returns a canvas k times wider and taller, every pixel repeated into a
/// k-by-k block. No smoothing, no averaging, no cleverness.
pub fn magnify(c: &Canvas, k: usize) -> Canvas {
    let mut m = canvas(c.width * k, c.height * k);
    for y in 0..c.height {
        for x in 0..c.width {
            let col = pixel_at(c, x as i64, y as i64);
            for dy in 0..k {
                for dx in 0..k {
                    write_pixel(&mut m, (x * k + dx) as i64, (y * k + dy) as i64, col);
                }
            }
        }
    }
    m
}

// ---------------------------------------------------------------------
// § 2.4 The coverage buffer, and the first question
// ---------------------------------------------------------------------

/// A canvas of numbers instead of colors: one number per pixel, from 0
/// ("none of this pixel is inside") to 1 ("all of it"). Starts at zero.
#[derive(Debug, Clone)]
pub struct CoverageBuffer {
    pub width: usize,
    pub height: usize,
    values: Vec<f64>,
}

pub fn coverage_buffer(width: usize, height: usize) -> CoverageBuffer {
    CoverageBuffer { width, height, values: vec![0.0; width * height] }
}

/// Reads outside the buffer are 0, same rule as `write_pixel`: a negative
/// coordinate can't even be cast to `usize` without wrapping, so the
/// bounds check has to happen before the cast, not after.
pub fn coverage_at(cov: &CoverageBuffer, x: i64, y: i64) -> f64 {
    if x < 0 || y < 0 {
        return 0.0;
    }
    let (x, y) = (x as usize, y as usize);
    if x >= cov.width || y >= cov.height {
        return 0.0;
    }
    cov.values[y * cov.width + x]
}

/// Writes outside the buffer are dropped, same rule as `write_pixel`.
pub fn set_coverage(cov: &mut CoverageBuffer, x: i64, y: i64, value: f64) {
    if x < 0 || y < 0 {
        return;
    }
    let (x, y) = (x as usize, y as usize);
    if x >= cov.width || y >= cov.height {
        return;
    }
    cov.values[y * cov.width + x] = value;
}

/// The sum of every value in the buffer: the area of the shape, in
/// pixels, as the buffer sees it.
pub fn ink(cov: &CoverageBuffer) -> f64 {
    cov.values.iter().sum()
}

/// Pixel (x, y) is the square from (x, y) to (x + 1, y + 1); its center
/// is (x + 0.5, y + 0.5). This is the one thing in the chapter that's
/// easy to get wrong: test (x, y) instead and every shape drawn sits half
/// a pixel up and to the left of where it should.
pub fn center_inside(s: &Shape, x: i64, y: i64) -> bool {
    inside(s, x as f64 + 0.5, y as f64 + 0.5)
}

/// The binary question, once per pixel: is the center inside? What every
/// renderer did until the nineties, and what some still do with
/// antialiasing off.
pub fn rasterize_centers(s: &Shape, width: usize, height: usize) -> CoverageBuffer {
    let mut cov = coverage_buffer(width, height);
    for y in 0..height as i64 {
        for x in 0..width as i64 {
            let value = if center_inside(s, x, y) { 1.0 } else { 0.0 };
            set_coverage(&mut cov, x, y, value);
        }
    }
    cov
}

// ---------------------------------------------------------------------
// § 2.5 Paint through it
// ---------------------------------------------------------------------

/// Moves every pixel of the canvas toward `col` by that pixel's coverage:
/// zero coverage leaves a pixel alone, full coverage replaces it, and in
/// between it's `mix(pixel, col, coverage)`, in light. The one place the
/// renderer touches the canvas. Forces linear blending regardless of the
/// switch -- the arithmetic here is never the browser's business.
pub fn paint_through(c: &mut Canvas, cov: &CoverageBuffer, col: Color) {
    let width = c.width.min(cov.width);
    let height = c.height.min(cov.height);
    for y in 0..height as i64 {
        for x in 0..width as i64 {
            let coverage = coverage_at(cov, x, y);
            let old = pixel_at(c, x, y);
            write_pixel(c, x, y, mix_with(old, col, coverage, true));
        }
    }
}

// ---------------------------------------------------------------------
// § 2.6 The better question
// ---------------------------------------------------------------------

/// How much of pixel (x, y) is inside the shape, brute forced: an 8-by-8
/// grid of sample points, one at the center of each cell, counted and
/// divided by 64.
pub fn coverage(s: &Shape, x: i64, y: i64) -> f64 {
    let mut count = 0;
    for j in 0..8 {
        for i in 0..8 {
            let px = x as f64 + (i as f64 + 0.5) / 8.0;
            let py = y as f64 + (j as f64 + 0.5) / 8.0;
            if inside(s, px, py) {
                count += 1;
            }
        }
    }
    count as f64 / 64.0
}

/// A buffer full of `coverage`: slow (64 shape queries per pixel), but
/// correct to within 1/64 for anything with a straight edge, and simple
/// enough to trust. The reference every faster rasterizer gets checked
/// against.
pub fn rasterize(s: &Shape, width: usize, height: usize) -> CoverageBuffer {
    let mut cov = coverage_buffer(width, height);
    for y in 0..height as i64 {
        for x in 0..width as i64 {
            set_coverage(&mut cov, x, y, coverage(s, x, y));
        }
    }
    cov
}

// ---------------------------------------------------------------------
// § 2.4 / § 2.6 / § 2.7 / § 2.8 The figures
// ---------------------------------------------------------------------

const DISC: Color = Color { red: 0.9, green: 0.55, blue: 0.1 };
const PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };

/// A 40x40 canvas, a disc of radius 16 centered at (20, 20) rasterized by
/// asking each pixel's center, painted through in orange, magnified
/// eight times: every step a full pixel, drawn the way circles were
/// drawn until antialiasing.
pub fn disc_centers() -> Canvas {
    let mut c = canvas(40, 40);
    fill(&mut c, PAPER);
    let cov = rasterize_centers(&circle(20.0, 20.0, 16.0), 40, 40);
    paint_through(&mut c, &cov, DISC);
    magnify(&c, 8)
}

/// `disc_centers`, with `rasterize` in place of `rasterize_centers` and
/// nothing else changed: the same circle, asked the better question.
pub fn disc_coverage() -> Canvas {
    let mut c = canvas(40, 40);
    fill(&mut c, PAPER);
    let cov = rasterize(&circle(20.0, 20.0, 16.0), 40, 40);
    paint_through(&mut c, &cov, DISC);
    magnify(&c, 8)
}

/// The same disc painted once (left half) and painted again through the
/// same coverage (right half): coverage is not opacity, and the second
/// pass pushes every partial pixel further toward the paint, fattening
/// the edge.
pub fn painted_twice() -> Canvas {
    let mut c = canvas(80, 40);
    fill(&mut c, PAPER);
    let cov = rasterize(&circle(20.0, 20.0, 16.0), 40, 40);

    let mut once = coverage_buffer(80, 40);
    for y in 0..40i64 {
        for x in 0..40i64 {
            let v = coverage_at(&cov, x, y);
            set_coverage(&mut once, x, y, v);
            set_coverage(&mut once, x + 40, y, v);
        }
    }
    paint_through(&mut c, &once, DISC);

    let mut twice = coverage_buffer(80, 40);
    for y in 0..40i64 {
        for x in 0..40i64 {
            set_coverage(&mut twice, x + 40, y, coverage_at(&cov, x, y));
        }
    }
    paint_through(&mut c, &twice, DISC);

    magnify(&c, 6)
}

/// Plate 2: the same circle on the same grid, asked two different
/// questions. Left: centers. Right: coverage.
pub fn plate_02() -> Canvas {
    let mut c = canvas(80, 40);
    fill(&mut c, PAPER);
    let shape = circle(20.0, 20.0, 16.0);
    let left = rasterize_centers(&shape, 40, 40);
    let right = rasterize(&shape, 40, 40);

    let mut both = coverage_buffer(80, 40);
    for y in 0..40i64 {
        for x in 0..40i64 {
            set_coverage(&mut both, x, y, coverage_at(&left, x, y));
            set_coverage(&mut both, x + 40, y, coverage_at(&right, x, y));
        }
    }
    paint_through(&mut c, &both, DISC);
    magnify(&c, 6)
}

// ---------------------------------------------------------------------
// Chapter 3: Lines
//
// § 3.1 Bresenham
// ---------------------------------------------------------------------

/// Every pixel of the canvas that isn't black, in reading order: top row
/// first, left to right within a row. A test helper, not a renderer
/// function.
pub fn lit_pixels(c: &Canvas) -> Vec<(i64, i64)> {
    let mut pts = Vec::new();
    for y in 0..c.height as i64 {
        for x in 0..c.width as i64 {
            if !colors_eq(pixel_at(c, x, y), BLACK) {
                pts.push((x, y));
            }
        }
    }
    pts
}

/// Bresenham's line, 1962: one pixel per step along the longer axis,
/// chosen with integer-only arithmetic. The steep swap keeps a
/// more-vertical-than-horizontal line stepping along y instead of x (else
/// it has gaps); the left-to-right swap makes the result independent of
/// which end was called the start. `err` starts at `dx / 2` (integer
/// division) -- the tie rule the tests pin: at exactly half a pixel of
/// drift, this stays on the current row for one more step.
pub fn line_bresenham(c: &mut Canvas, x0: i64, y0: i64, x1: i64, y1: i64, col: Color) {
    let steep = (y1 - y0).abs() > (x1 - x0).abs();
    let (mut x0, mut y0, mut x1, mut y1) = (x0, y0, x1, y1);
    if steep {
        std::mem::swap(&mut x0, &mut y0);
        std::mem::swap(&mut x1, &mut y1);
    }
    if x0 > x1 {
        std::mem::swap(&mut x0, &mut x1);
        std::mem::swap(&mut y0, &mut y1);
    }

    let dx = x1 - x0;
    let dy = (y1 - y0).abs();
    let ystep = if y0 < y1 { 1 } else { -1 };
    let mut err = dx / 2;
    let mut y = y0;

    for x in x0..=x1 {
        if steep {
            write_pixel(c, y, x, col);
        } else {
            write_pixel(c, x, y, col);
        }
        err -= dy;
        if err < 0 {
            y += ystep;
            err += dx;
        }
    }
}

/// The twelve points 72 pixels from (80, 80), one every 30 degrees,
/// rounded to integers. Shared by every figure in this chapter so the
/// tests can pin the endpoints once.
pub fn ray_ends() -> Vec<(i64, i64)> {
    let mut ends = Vec::with_capacity(12);
    for k in 0..12 {
        let a = k as f64 * 30.0 * std::f64::consts::PI / 180.0;
        ends.push((round(80.0 + 72.0 * a.cos()), round(80.0 + 72.0 * a.sin())));
    }
    ends
}

const PAPER_3: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };
const RAY: Color = Color { red: 0.92, green: 0.92, blue: 0.88 };

/// Twelve rays out of Bresenham's line, on a near-black paper. The
/// slanted ones are a repeating pattern of short runs -- a texture the
/// eye reads as flicker, though every ray is drawn with the same rule.
pub fn fan_bresenham() -> Canvas {
    let mut c = canvas(160, 160);
    fill(&mut c, PAPER_3);
    for (x, y) in ray_ends() {
        line_bresenham(&mut c, 80, 80, x, y, RAY);
    }
    c
}

// ---------------------------------------------------------------------
// § 3.2 Wu
// ---------------------------------------------------------------------

/// Paint through one pixel at a weight: `mix(pixel_at(c, x, y), col,
/// weight)`, written back. `paint_through` for a single pixel, dropping
/// writes off the canvas and skipping a weight of zero (nothing to do,
/// and it keeps `pixel_at` from being asked about an out-of-range pixel).
pub fn plot(c: &mut Canvas, x: i64, y: i64, col: Color, weight: f64) {
    if weight <= 0.0 || x < 0 || y < 0 {
        return;
    }
    if x as usize >= c.width || y as usize >= c.height {
        return;
    }
    let old = pixel_at(c, x, y);
    write_pixel(c, x, y, mix(old, col, weight));
}

/// Xiaolin Wu's line, 1991: two pixels per column instead of one, weighted
/// by how far the ideal `y` falls past its floor. Same steep swap and
/// left-to-right swap as Bresenham, for the same reasons; unlike
/// Bresenham the endpoints must be integers, since this chapter doesn't
/// give partial end-cap weights to fractional ones.
pub fn line_wu(c: &mut Canvas, x0: i64, y0: i64, x1: i64, y1: i64, col: Color) {
    let steep = (y1 - y0).abs() > (x1 - x0).abs();
    let (mut x0, mut y0, mut x1, mut y1) = (x0, y0, x1, y1);
    if steep {
        std::mem::swap(&mut x0, &mut y0);
        std::mem::swap(&mut x1, &mut y1);
    }
    if x0 > x1 {
        std::mem::swap(&mut x0, &mut x1);
        std::mem::swap(&mut y0, &mut y1);
    }

    let dx = x1 - x0;
    let slope = if dx == 0 { 0.0 } else { (y1 - y0) as f64 / dx as f64 };

    for x in x0..=x1 {
        let y = y0 as f64 + (x - x0) as f64 * slope;
        let yi = y.floor();
        let f = y - yi;
        let yi = yi as i64;
        if steep {
            plot(c, yi, x, col, 1.0 - f);
            plot(c, yi + 1, x, col, f);
        } else {
            plot(c, x, yi, col, 1.0 - f);
            plot(c, x, yi + 1, col, f);
        }
    }
}

/// The sum of every pixel's red channel: for a white line on black, how
/// much paint went down. For Wu it's always the number of columns
/// touched, since each column's two weights sum to 1.
pub fn total_ink(c: &Canvas) -> f64 {
    let mut sum = 0.0;
    for y in 0..c.height as i64 {
        for x in 0..c.width as i64 {
            sum += pixel_at(c, x, y).red;
        }
    }
    sum
}

/// `fan_bresenham`, with `line_wu` in place of `line_bresenham` and
/// nothing else changed.
pub fn fan_wu() -> Canvas {
    let mut c = canvas(160, 160);
    fill(&mut c, PAPER_3);
    for (x, y) in ray_ends() {
        line_wu(&mut c, 80, 80, x, y, RAY);
    }
    c
}

// ---------------------------------------------------------------------
// § 3.3 The reveal: a line is a thin rectangle
// ---------------------------------------------------------------------

/// The rectangle of `width` centered on the segment from the center of
/// pixel (x0, y0) to the center of pixel (x1, y1), with square ends: four
/// half-planes, through chapter 2's `inside`. Two face along the segment
/// (the end caps), two face inward along the normal, offset by half the
/// width (the sides).
///
/// Chapter 4 (§4.5) pulls the actual rectangle-building logic out into
/// `segment`, which takes real points instead of pixel indices; this is
/// now that one-liner, with the `+ 0.5` that used to live here moved into
/// the call.
pub fn thick_line(x0: i64, y0: i64, x1: i64, y1: i64, width: f64) -> Shape {
    segment(point(x0 as f64 + 0.5, y0 as f64 + 0.5), point(x1 as f64 + 0.5, y1 as f64 + 0.5), width)
}

/// The fan a third time: each ray a `thick_line` of width 1, rasterized
/// and painted through, then magnified by 2 so the edges are visible.
/// Slow -- twelve 160x160 rasterizations at 64 samples a pixel -- because
/// chapter 2's rasterizer knows nothing about lines; it asks every pixel
/// on the canvas whether the shape is anywhere near it.
pub fn fan_coverage() -> Canvas {
    let mut c = canvas(160, 160);
    fill(&mut c, PAPER_3);
    for (x, y) in ray_ends() {
        let cov = rasterize(&thick_line(80, 80, x, y, 1.0), 160, 160);
        paint_through(&mut c, &cov, RAY);
    }
    magnify(&c, 2)
}

// ---------------------------------------------------------------------
// § 3.4 The figures
// ---------------------------------------------------------------------

/// Plate 3: Bresenham's fan and Wu's, side by side, magnified twice.
pub fn plate_03() -> Canvas {
    let mut both = canvas(320, 160);
    let a = fan_bresenham();
    let b = fan_wu();
    for y in 0..160i64 {
        for x in 0..160i64 {
            write_pixel(&mut both, x, y, pixel_at(&a, x, y));
            write_pixel(&mut both, x + 160, y, pixel_at(&b, x, y));
        }
    }
    magnify(&both, 2)
}

// ---------------------------------------------------------------------
// Chapter 4: Points, Vectors, Transforms
//
// § 4.1 Points and vectors
// ---------------------------------------------------------------------

/// A point or a vector: (x, y, w), w = 1 for a point and w = 0 for a
/// vector. The arithmetic doesn't distinguish them beyond that: point
/// minus point comes out w = 0 (a vector), point plus vector comes out
/// w = 1 (a point), and point plus point comes out w = 2, which is
/// nobody's fault but the caller's.
#[derive(Debug, Clone, Copy)]
pub struct Tuple {
    pub x: f64,
    pub y: f64,
    pub w: f64,
}

/// A place.
pub fn point(x: f64, y: f64) -> Tuple {
    Tuple { x, y, w: 1.0 }
}

/// A displacement, with no location of its own.
pub fn vector(x: f64, y: f64) -> Tuple {
    Tuple { x, y, w: 0.0 }
}

impl Add for Tuple {
    type Output = Tuple;
    fn add(self, other: Tuple) -> Tuple {
        Tuple { x: self.x + other.x, y: self.y + other.y, w: self.w + other.w }
    }
}

impl Sub for Tuple {
    type Output = Tuple;
    fn sub(self, other: Tuple) -> Tuple {
        Tuple { x: self.x - other.x, y: self.y - other.y, w: self.w - other.w }
    }
}

impl Neg for Tuple {
    type Output = Tuple;
    fn neg(self) -> Tuple {
        Tuple { x: -self.x, y: -self.y, w: -self.w }
    }
}

/// Scale a point or vector by a number: `v * 3.5`.
impl Mul<f64> for Tuple {
    type Output = Tuple;
    fn mul(self, s: f64) -> Tuple {
        Tuple { x: self.x * s, y: self.y * s, w: self.w * s }
    }
}

impl Div<f64> for Tuple {
    type Output = Tuple;
    fn div(self, s: f64) -> Tuple {
        Tuple { x: self.x / s, y: self.y / s, w: self.w / s }
    }
}

/// Points and vectors compare component by component, `w` included, with
/// the usual tolerance -- so a point built with the wrong `w` (or a
/// translation that leaves a vector's `w` nonzero) fails here too, not
/// only on `x` and `y`.
pub fn tuples_eq(a: Tuple, b: Tuple) -> bool {
    approx_eq(a.x, b.x) && approx_eq(a.y, b.y) && approx_eq(a.w, b.w)
}

/// The length of a vector: `sqrt(x^2 + y^2)`, ignoring `w`.
pub fn magnitude(v: Tuple) -> f64 {
    (v.x * v.x + v.y * v.y).sqrt()
}

/// A vector of length 1, pointing the same way as `v`.
pub fn normalize(v: Tuple) -> Tuple {
    v / magnitude(v)
}

/// How much of `a` points along `b`: zero when they're perpendicular.
pub fn dot(a: Tuple, b: Tuple) -> f64 {
    a.x * b.x + a.y * b.y
}

/// In two dimensions there's nowhere perpendicular for a cross product to
/// point, so what's left is a single number: the signed area of the
/// parallelogram `a` and `b` span. Its sign says which way you turned
/// going from `a` to `b`.
pub fn cross(a: Tuple, b: Tuple) -> f64 {
    a.x * b.y - a.y * b.x
}

// ---------------------------------------------------------------------
// § 4.2 Matrices
// ---------------------------------------------------------------------

/// A 3 by 3 matrix of real numbers, row by row. `matrix_at(m, r, c)` is
/// the entry in row `r`, column `c`, both counted from zero.
#[derive(Debug, Clone, Copy)]
pub struct Matrix3 {
    m: [[f64; 3]; 3],
}

/// Nine numbers in reading order, row by row -- for the times a table is
/// too much ceremony.
pub fn matrix3(a: f64, b: f64, c: f64, d: f64, e: f64, f: f64, g: f64, h: f64, i: f64) -> Matrix3 {
    Matrix3 { m: [[a, b, c], [d, e, f], [g, h, i]] }
}

/// `M[r, c]`: the entry in row `r`, column `c`, both counted from zero.
pub fn matrix_at(m: &Matrix3, r: usize, c: usize) -> f64 {
    m.m[r][c]
}

/// Also available as `m[(r, c)]`.
impl Index<(usize, usize)> for Matrix3 {
    type Output = f64;
    fn index(&self, (r, c): (usize, usize)) -> &f64 {
        &self.m[r][c]
    }
}

/// Matrices compare component-wise with the usual tolerance.
pub fn matrices_eq(a: &Matrix3, b: &Matrix3) -> bool {
    for r in 0..3 {
        for c in 0..3 {
            if !approx_eq(matrix_at(a, r, c), matrix_at(b, r, c)) {
                return false;
            }
        }
    }
    true
}

/// Two matrices multiply into a third: the entry in row `r`, column `c`
/// of the product is the dot product of row `r` of the first with column
/// `c` of the second. This is exactly the arrangement that makes
/// `(A * B) * p` equal `A * (B * p)`.
impl Mul<Matrix3> for Matrix3 {
    type Output = Matrix3;
    fn mul(self, other: Matrix3) -> Matrix3 {
        let mut m = [[0.0; 3]; 3];
        for r in 0..3 {
            for c in 0..3 {
                m[r][c] = (0..3).map(|k| self.m[r][k] * other.m[k][c]).sum();
            }
        }
        Matrix3 { m }
    }
}

/// A matrix multiplies a tuple, treating (x, y, w) as a column: the
/// result's x is the dot product of the matrix's first row with the
/// tuple, its y the second row, its w the third. Every matrix in this
/// book has a bottom row of 0 0 1, so w comes out unchanged.
impl Mul<Tuple> for Matrix3 {
    type Output = Tuple;
    fn mul(self, t: Tuple) -> Tuple {
        Tuple {
            x: self.m[0][0] * t.x + self.m[0][1] * t.y + self.m[0][2] * t.w,
            y: self.m[1][0] * t.x + self.m[1][1] * t.y + self.m[1][2] * t.w,
            w: self.m[2][0] * t.x + self.m[2][1] * t.y + self.m[2][2] * t.w,
        }
    }
}

/// Ones on the diagonal, zeros elsewhere. Multiplying by it changes
/// nothing.
pub fn identity() -> Matrix3 {
    matrix3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
}

/// Flips a matrix across the diagonal: `transpose(M)[r, c] = M[c, r]`.
pub fn transpose(m: Matrix3) -> Matrix3 {
    let mut t = [[0.0; 3]; 3];
    for r in 0..3 {
        for c in 0..3 {
            t[c][r] = m.m[r][c];
        }
    }
    Matrix3 { m: t }
}

/// The 2x2 determinant left when row `r` and column `c` are deleted.
fn minor(m: &Matrix3, r: usize, c: usize) -> f64 {
    let rows: Vec<usize> = (0..3).filter(|&i| i != r).collect();
    let cols: Vec<usize> = (0..3).filter(|&i| i != c).collect();
    m.m[rows[0]][cols[0]] * m.m[rows[1]][cols[1]] - m.m[rows[0]][cols[1]] * m.m[rows[1]][cols[0]]
}

/// The minor at (r, c), sign-flipped when r + c is odd.
fn cofactor(m: &Matrix3, r: usize, c: usize) -> f64 {
    let sign = if (r + c) % 2 == 1 { -1.0 } else { 1.0 };
    sign * minor(m, r, c)
}

/// A cofactor expansion along the first row. For a transform, this is the
/// factor by which areas grow: positive for a rotation (1) or an
/// ordinary scale, negative for a reflection, zero for a matrix that's
/// squashed the whole plane onto a line.
pub fn determinant(m: Matrix3) -> f64 {
    m.m[0][0] * cofactor(&m, 0, 0) + m.m[0][1] * cofactor(&m, 0, 1) + m.m[0][2] * cofactor(&m, 0, 2)
}

/// Zero means there's no inverse: you can't un-flatten a line back into a
/// plane.
pub fn is_invertible(m: Matrix3) -> bool {
    !approx_eq(determinant(m), 0.0)
}

/// The matrix that undoes `m`: `inverse(m) * m` is the identity. The
/// matrix of cofactors, transposed, divided by the determinant -- the
/// transpose happens by writing each entry straight into its transposed
/// position, `result[c, r]`, rather than transposing afterward.
pub fn inverse(m: Matrix3) -> Matrix3 {
    let d = determinant(m);
    let mut result = [[0.0; 3]; 3];
    for r in 0..3 {
        for c in 0..3 {
            result[c][r] = cofactor(&m, r, c) / d;
        }
    }
    Matrix3 { m: result }
}

// ---------------------------------------------------------------------
// § 4.3 The transforms
// ---------------------------------------------------------------------

/// Moves everything by (tx, ty). Doesn't affect vectors: a vector's w is
/// 0, and the offsets live in the column w multiplies.
pub fn translation(tx: f64, ty: f64) -> Matrix3 {
    matrix3(1.0, 0.0, tx, 0.0, 1.0, ty, 0.0, 0.0, 1.0)
}

/// Multiplies x and y by independent factors. A negative factor is a
/// reflection.
pub fn scaling(sx: f64, sy: f64) -> Matrix3 {
    matrix3(sx, 0.0, 0.0, 0.0, sy, 0.0, 0.0, 0.0, 1.0)
}

/// Turns the x axis toward the y axis by `r` radians -- counterclockwise
/// on paper, clockwise on a canvas whose y points down.
pub fn rotation(r: f64) -> Matrix3 {
    matrix3(r.cos(), -r.sin(), 0.0, r.sin(), r.cos(), 0.0, 0.0, 0.0, 1.0)
}

/// Slides x in proportion to y, and y in proportion to x.
pub fn shearing(xy: f64, yx: f64) -> Matrix3 {
    matrix3(1.0, xy, 0.0, yx, 1.0, 0.0, 0.0, 0.0, 1.0)
}

// ---------------------------------------------------------------------
// § 4.4 How big is a transform?
// ---------------------------------------------------------------------

/// One number for how much `m` stretches lengths: the square root of the
/// absolute value of the determinant of its upper-left 2 by 2. Exact for
/// uniform scales and rotations (and any mix of the two with a
/// translation); the geometric mean of the two axis scales otherwise,
/// which the chapter picks as the cheapest reasonable compromise.
pub fn approx_scale(m: Matrix3) -> f64 {
    (m.m[0][0] * m.m[1][1] - m.m[0][1] * m.m[1][0]).abs().sqrt()
}

// ---------------------------------------------------------------------
// § 4.5 Transforming what you draw
// ---------------------------------------------------------------------

/// The rectangle of `width` centered on the segment from point `a` to
/// point `b`, square ends: `thick_line` with real endpoints instead of
/// pixel indices. Four half-planes, same as before -- two end caps, two
/// sides offset by half the width along the normal.
pub fn segment(a: Tuple, b: Tuple, width: f64) -> Shape {
    let mut ax = a.x;
    let ay = a.y;
    let mut bx = b.x;
    let by = b.y;
    let h = width / 2.0;

    let mut dx = bx - ax;
    let mut dy = by - ay;
    let len = (dx * dx + dy * dy).sqrt();
    if len == 0.0 {
        // No direction: make it a square by giving it one, (1, 0), and
        // pushing the two coincident ends apart by half the width each.
        dx = 1.0;
        dy = 0.0;
        ax -= h;
        bx += h;
    } else {
        dx /= len;
        dy /= len;
    }
    let (nx, ny) = (-dy, dx);

    Shape::Intersection([
        (ax, ay, dx, dy),
        (bx, by, -dx, -dy),
        (ax + nx * h, ay + ny * h, -nx, -ny),
        (ax - nx * h, ay - ny * h, nx, ny),
    ])
}

/// Inside when any of its shapes is: one more case in `inside`, a loop
/// with an early exit. Painting the union once, instead of each part
/// separately, is what keeps a corner where two parts meet from being
/// painted twice.
pub fn union(shapes: Vec<Shape>) -> Shape {
    Shape::Union(shapes)
}

/// The shape seen through `m`: to decide whether a device point is
/// inside, send the point backwards through the inverse of `m` and ask
/// the original shape about the result. A shape seen through a matrix
/// with no inverse is empty -- nothing can be inside a shape that's been
/// flattened to a line.
pub fn transformed(shape: Shape, m: Matrix3) -> Shape {
    if !is_invertible(m) {
        return Shape::Empty;
    }
    Shape::Transformed(Box::new(shape), inverse(m))
}

/// Every point of `points`, run through `m`.
pub fn transform_points(points: &[Tuple], m: Matrix3) -> Vec<Tuple> {
    points.iter().map(|&p| m * p).collect()
}

/// The closed polygon through `points` after `m`: the union of the
/// segments between consecutive points, last back to first, every edge a
/// `segment` of `width` in device space, as one shape.
pub fn outline(points: &[Tuple], m: Matrix3, width: f64) -> Shape {
    let pts = transform_points(points, m);
    let n = pts.len();
    let segments = (0..n).map(|i| segment(pts[i], pts[(i + 1) % n], width)).collect();
    union(segments)
}

// ---------------------------------------------------------------------
// § 4.6 Putting it together
// ---------------------------------------------------------------------

/// Chapter 3's fan, described as points around the origin instead of
/// pixels: the center, then twelve ends at radius 36, one every 30
/// degrees.
pub fn fan_points() -> Vec<Tuple> {
    let mut pts = vec![point(0.0, 0.0)];
    for k in 0..12 {
        let a = k as f64 * 30.0 * std::f64::consts::PI / 180.0;
        pts.push(point(36.0 * a.cos(), 36.0 * a.sin()));
    }
    pts
}

/// Ten corners, clockwise from the top left, in a box 40 wide and 60 tall
/// centered on the origin: an F, which has no symmetry at all, so a
/// wrong lean or a lost translation shows up instead of hiding behind a
/// shape that looks the same either way.
pub fn letter_f() -> Vec<Tuple> {
    vec![
        point(-20.0, -30.0),
        point(20.0, -30.0),
        point(20.0, -20.0),
        point(-10.0, -20.0),
        point(-10.0, -5.0),
        point(12.0, -5.0),
        point(12.0, 5.0),
        point(-10.0, 5.0),
        point(-10.0, 30.0),
        point(-20.0, 30.0),
    ]
}

/// Copies `a` into the left half of a wider canvas and `b` into the
/// right.
pub fn side_by_side(a: &Canvas, b: &Canvas) -> Canvas {
    let height = a.height.max(b.height);
    let mut c = canvas(a.width + b.width, height);
    for y in 0..a.height as i64 {
        for x in 0..a.width as i64 {
            write_pixel(&mut c, x, y, pixel_at(a, x, y));
        }
    }
    for y in 0..b.height as i64 {
        for x in 0..b.width as i64 {
            write_pixel(&mut c, x + a.width as i64, y, pixel_at(b, x, y));
        }
    }
    c
}

/// The fan, run through `m` and drawn as one union of segments on a
/// 160x160 canvas.
pub fn fan_transformed(m: Matrix3) -> Canvas {
    let mut c = canvas(160, 160);
    fill(&mut c, PAPER_3);
    let pts = transform_points(&fan_points(), m);
    let rays: Vec<Shape> = (1..pts.len()).map(|k| segment(pts[0], pts[k], 1.0)).collect();
    let cov = rasterize(&union(rays), 160, 160);
    paint_through(&mut c, &cov, RAY);
    c
}

/// Figure 4.4 / the left half of the argument the plate exists to make:
/// the same fan, drawn through `move * turn` and `turn * move`, side by
/// side. The order matters -- the fan ends up in two different places --
/// but a fan with a ray every 30 degrees, rotated by 30 degrees, can't
/// show whether it turned. `f_both_orders` is what shows that half.
pub fn fan_both_orders() -> Canvas {
    let turn = rotation(std::f64::consts::PI / 6.0);
    let move_ = translation(104.5, 76.5);
    side_by_side(&fan_transformed(move_ * turn), &fan_transformed(turn * move_))
}

const DIM: Color = Color { red: 0.16, green: 0.16, blue: 0.17 };

/// The letter F, drawn through `move * turn` and `turn * move` against a
/// dim copy of the untransformed letter (at `home`), side by side, so the
/// two results read as one picture.
pub fn f_both_orders() -> Canvas {
    let turn = rotation(std::f64::consts::PI / 6.0);
    let move_ = translation(104.5, 76.5);
    let home = translation(44.5, 44.5);

    let mut ghost = canvas(160, 160);
    fill(&mut ghost, PAPER_3);
    let ghost_cov = rasterize(&outline(&letter_f(), home, 1.0), 160, 160);
    paint_through(&mut ghost, &ghost_cov, DIM);

    let mut a = ghost.clone();
    let mut b = ghost.clone();
    let a_cov = rasterize(&outline(&letter_f(), move_ * turn, 1.0), 160, 160);
    paint_through(&mut a, &a_cov, RAY);
    let b_cov = rasterize(&outline(&letter_f(), turn * move_, 1.0), 160, 160);
    paint_through(&mut b, &b_cov, RAY);

    side_by_side(&a, &b)
}

/// Plate 4: `f_both_orders`, magnified by 2.
pub fn plate_04() -> Canvas {
    magnify(&f_both_orders(), 2)
}

// =======================================================================
// Chapter 5: Paths and Insideness
// =======================================================================

// ---------------------------------------------------------------------
// § 5.1 A path is a list of instructions
// ---------------------------------------------------------------------

/// One pen-down-to-pen-up run: the points visited, in order, and whether
/// `close` was called on it. The flag doesn't affect `edges` -- filling
/// treats every subpath as closed regardless -- it only matters for where
/// the *next* `line_to` starts, and (in a later chapter) for stroking.
#[derive(Debug, Clone)]
pub struct Subpath {
    pub points: Vec<Tuple>,
    pub closed: bool,
}

/// A list of subpaths: everything `move_to`, `line_to` and `close` build
/// up. Curves arrive in chapter 8; until then a subpath is just points.
#[derive(Debug, Clone)]
pub struct Path {
    subpaths: Vec<Subpath>,
}

/// An empty path: no subpaths at all.
pub fn path() -> Path {
    Path { subpaths: Vec::new() }
}

/// Lifts the pen and puts it down at `pt`, starting a new subpath there.
pub fn move_to(p: &mut Path, pt: Tuple) {
    p.subpaths.push(Subpath { points: vec![pt], closed: false });
}

/// Draws a line from wherever the pen is to `pt`.
///
/// Three cases, in the order the chapter lists them: with nothing to
/// extend (no subpath yet), this behaves as `move_to`. Right after a
/// `close`, it starts a new subpath -- but at the point the *closed*
/// subpath began, because that's where `close` left the pen, not at
/// wherever its own points happened to end. Otherwise it just appends to
/// the subpath in progress.
pub fn line_to(p: &mut Path, pt: Tuple) {
    match p.subpaths.last() {
        None => move_to(p, pt),
        Some(last) if last.closed => {
            let start = last.points[0];
            p.subpaths.push(Subpath { points: vec![start, pt], closed: false });
        }
        Some(_) => {
            p.subpaths.last_mut().unwrap().points.push(pt);
        }
    }
}

/// Draws a line back to where the pen was last put down and marks the
/// subpath closed. Nothing to close does nothing; closing twice is the
/// same as closing once.
pub fn close(p: &mut Path) {
    if let Some(last) = p.subpaths.last_mut() {
        last.closed = true;
    }
}

/// The subpaths, in order, for the tests to inspect.
pub fn subpaths(p: &Path) -> &[Subpath] {
    &p.subpaths
}

/// Every edge of every subpath, as `(a, b)` pairs, treating every subpath
/// as closed whether or not `close` was called: a subpath of one point
/// contributes no edges, and every other subpath contributes one edge per
/// point, the last back to the first.
pub fn edges(p: &Path) -> Vec<(Tuple, Tuple)> {
    let mut out = Vec::new();
    for sp in &p.subpaths {
        let n = sp.points.len();
        if n < 2 {
            continue;
        }
        for i in 0..n {
            out.push((sp.points[i], sp.points[(i + 1) % n]));
        }
    }
    out
}

/// The smallest axis-aligned box around every point of every subpath, as
/// `(min x, min y, max x, max y)`. An empty path has no points, and its
/// bounds are `(0, 0, 0, 0)` rather than whatever a language's min of
/// nothing does.
pub fn bounds(p: &Path) -> (f64, f64, f64, f64) {
    let mut min_x = f64::INFINITY;
    let mut min_y = f64::INFINITY;
    let mut max_x = f64::NEG_INFINITY;
    let mut max_y = f64::NEG_INFINITY;
    let mut any = false;
    for sp in &p.subpaths {
        for pt in &sp.points {
            any = true;
            min_x = min_x.min(pt.x);
            min_y = min_y.min(pt.y);
            max_x = max_x.max(pt.x);
            max_y = max_y.max(pt.y);
        }
    }
    if !any {
        (0.0, 0.0, 0.0, 0.0)
    } else {
        (min_x, min_y, max_x, max_y)
    }
}

/// A closed subpath through `points`.
pub fn polygon(points: &[Tuple]) -> Path {
    let mut p = path();
    for (i, &pt) in points.iter().enumerate() {
        if i == 0 {
            move_to(&mut p, pt);
        } else {
            line_to(&mut p, pt);
        }
    }
    close(&mut p);
    p
}

/// A regular n-gon standing in for a circle of radius `r` about `(cx,
/// cy)`: its first point at angle 0 (on the right), going clockwise on the
/// screen as the angle increases, because the canvas's y points down.
/// Chapter 8 makes it an honest circle.
pub fn circle_path(cx: f64, cy: f64, r: f64, n: usize) -> Path {
    let mut pts = Vec::with_capacity(n);
    for k in 0..n {
        let a = k as f64 * 2.0 * std::f64::consts::PI / n as f64;
        pts.push(point(cx + r * a.cos(), cy + r * a.sin()));
    }
    polygon(&pts)
}

// ---------------------------------------------------------------------
// § 5.2 Is this point inside?
// ---------------------------------------------------------------------

/// Does the edge `a -> b` span height `y`, under the half-open rule (the
/// lower endpoint is in, the higher one out), and if so, where does it
/// cross? A horizontal edge (`a.y == b.y`) never spans anything.
fn edge_crossing(a: Tuple, b: Tuple, y: f64) -> Option<f64> {
    if (a.y <= y && y < b.y) || (b.y <= y && y < a.y) {
        let t = (y - a.y) / (b.y - a.y);
        Some(a.x + t * (b.x - a.x))
    } else {
        None
    }
}

/// How many edges a ray from `(x, y)` toward `+x`, forever, crosses.
/// Half-open at each edge's lower endpoint, so a vertex on the ray counts
/// once, not for each of its two edges.
pub fn crossings(p: &Path, x: f64, y: f64) -> i64 {
    let mut n = 0;
    for (a, b) in edges(p) {
        if let Some(x_cross) = edge_crossing(a, b, y) {
            if x_cross > x {
                n += 1;
            }
        }
    }
    n
}

/// The winding number of the path around `(x, y)`: how many times the
/// path goes around the point, net, and in which direction. An edge
/// heading down the canvas (toward larger y) that crosses the ray to the
/// right counts `+1`; one heading up counts `-1`. Positive is clockwise on
/// the screen. Uses the cross product instead of the crossing's x so it
/// never divides: `cross(b - a, q - a) > 0` means q is to the left of an
/// edge heading down, which is the same thing as the crossing being to
/// the right of q.
pub fn winding_at(p: &Path, x: f64, y: f64) -> i64 {
    let q = point(x, y);
    let mut w = 0;
    for (a, b) in edges(p) {
        if a.y <= y {
            if b.y > y && cross(b - a, q - a) > 0.0 {
                w += 1;
            }
        } else if b.y <= y && cross(b - a, q - a) < 0.0 {
            w -= 1;
        }
    }
    w
}

// ---------------------------------------------------------------------
// § 5.3 Two rules
// ---------------------------------------------------------------------

/// Nonzero: inside when the winding number isn't zero.
pub fn inside_nonzero(p: &Path, x: f64, y: f64) -> bool {
    winding_at(p, x, y) != 0
}

/// Even-odd: inside when the winding number is odd (same parity as the
/// crossing count).
pub fn inside_evenodd(p: &Path, x: f64, y: f64) -> bool {
    winding_at(p, x, y).rem_euclid(2) != 0
}

/// Which of the two fill conventions a `Shape::Filled` uses.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Rule {
    NonZero,
    EvenOdd,
}

fn parse_rule(rule: &str) -> Rule {
    match rule {
        "nonzero" => Rule::NonZero,
        "evenodd" => Rule::EvenOdd,
        other => panic!("unknown fill rule: {other}"),
    }
}

/// The shape a path encloses under `rule` (`"nonzero"` or `"evenodd"`), so
/// that chapter 2's rasterizer -- coverage, `rasterize`, all of it -- can
/// draw any path, either rule, unchanged.
pub fn filled(p: &Path, rule: &str) -> Shape {
    Shape::Filled(Box::new(p.clone()), parse_rule(rule))
}

/// Columns from `floor(min x)` up to but not including `ceil(max x)`,
/// rows likewise, clipped to the buffer: `rasterize` restricted to the
/// pixels `b` touches. Leaves every other pixel at zero. Same coverage as
/// `rasterize(s, width, height)`, less work.
pub fn rasterize_within(
    s: &Shape,
    b: (f64, f64, f64, f64),
    width: usize,
    height: usize,
) -> CoverageBuffer {
    let mut cov = coverage_buffer(width, height);
    let (min_x, min_y, max_x, max_y) = b;
    let x0 = min_x.floor().max(0.0) as i64;
    let y0 = min_y.floor().max(0.0) as i64;
    let x1 = (max_x.ceil() as i64).clamp(0, width as i64);
    let y1 = (max_y.ceil() as i64).clamp(0, height as i64);
    for y in y0..y1 {
        for x in x0..x1 {
            set_coverage(&mut cov, x, y, coverage(s, x, y));
        }
    }
    cov
}

// ---------------------------------------------------------------------
// § 5.4 Putting it together
// ---------------------------------------------------------------------

/// Five points on a circle of radius 70 about (80.5, 80.5), the first
/// straight up, visited every second one so the pen crosses itself, and
/// closed: the pentagram.
pub fn star() -> Path {
    let mut p = path();
    for k in 0..5 {
        let a = (-90.0 + 144.0 * k as f64) * std::f64::consts::PI / 180.0;
        let q = point(80.5 + 70.0 * a.cos(), 80.5 + 70.0 * a.sin());
        if k == 0 {
            move_to(&mut p, q);
        } else {
            line_to(&mut p, q);
        }
    }
    close(&mut p);
    p
}

const STAR_BG: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };
const STAR_INK: Color = Color { red: 0.9, green: 0.55, blue: 0.1 };

/// The star, filled under `rule`, by `method` (`"centers"` or
/// `"coverage"`), on a 160x160 panel.
pub fn star_panel(rule: &str, method: &str) -> Canvas {
    let mut c = canvas(160, 160);
    fill(&mut c, STAR_BG);
    let s = filled(&star(), rule);
    let cov = if method == "centers" {
        rasterize_centers(&s, 160, 160)
    } else {
        rasterize_within(&s, bounds(&star()), 160, 160)
    };
    paint_through(&mut c, &cov, STAR_INK);
    c
}

/// Both rules, by the center question, side by side.
pub fn star_centers() -> Canvas {
    side_by_side(&star_panel("nonzero", "centers"), &star_panel("evenodd", "centers"))
}

/// Both rules, by coverage, side by side.
pub fn star_coverage() -> Canvas {
    side_by_side(&star_panel("nonzero", "coverage"), &star_panel("evenodd", "coverage"))
}

/// Plate 5: the center-question pair over the coverage pair, magnified by
/// 2.
pub fn plate_05() -> Canvas {
    let top = star_centers();
    let bottom = star_coverage();
    let mut both = canvas(320, 320);
    for y in 0..160i64 {
        for x in 0..320i64 {
            write_pixel(&mut both, x, y, pixel_at(&top, x, y));
            write_pixel(&mut both, x, y + 160, pixel_at(&bottom, x, y));
        }
    }
    magnify(&both, 2)
}

// =======================================================================
// Chapter 6: Filling a Polygon
// =======================================================================

// ---------------------------------------------------------------------
// § 6.1 The edge table
// ---------------------------------------------------------------------

/// One non-horizontal edge, reshaped for the sweep: which end is higher on
/// the canvas (`y_top`, `x_top`), where the lower end is (`y_bottom`), how
/// far x moves for each unit of descending y (`slope`), and which way the
/// path went along it -- `+1` heading down the canvas (from `a` to `b`
/// with `a.y < b.y`), `-1` heading up. The same sign chapter 5's winding
/// number gave a crossing.
#[derive(Debug, Clone, Copy)]
pub struct Edge {
    pub y_top: f64,
    pub y_bottom: f64,
    pub x_top: f64,
    pub slope: f64,
    pub direction: i64,
}

/// Where `edge` crosses height `y`.
pub fn x_at(edge: &Edge, y: f64) -> f64 {
    edge.x_top + (y - edge.y_top) * edge.slope
}

/// Every non-horizontal edge of `p`, reshaped into an `Edge` and sorted by
/// `y_top`, then by `x_top`. A horizontal edge (`a.y == b.y` exactly) is
/// dropped, not clamped: chapter 5's half-open rule already says it never
/// crosses a sample height, and its slope would be a division by zero.
pub fn edge_table(p: &Path) -> Vec<Edge> {
    let mut table: Vec<Edge> = edges(p)
        .into_iter()
        .filter_map(|(a, b)| {
            if a.y == b.y {
                None
            } else if a.y < b.y {
                Some(Edge {
                    y_top: a.y,
                    y_bottom: b.y,
                    x_top: a.x,
                    slope: (b.x - a.x) / (b.y - a.y),
                    direction: 1,
                })
            } else {
                Some(Edge {
                    y_top: b.y,
                    y_bottom: a.y,
                    x_top: b.x,
                    slope: (a.x - b.x) / (a.y - b.y),
                    direction: -1,
                })
            }
        })
        .collect();
    table.sort_by(|a, b| {
        a.y_top.partial_cmp(&b.y_top).unwrap().then(a.x_top.partial_cmp(&b.x_top).unwrap())
    });
    table
}

// ---------------------------------------------------------------------
// § 6.2 Crossings on a row, and spans
// ---------------------------------------------------------------------

/// `(x, direction)` for every edge of `table` that spans height `y` --
/// `y_top <= y < y_bottom`, half-open, chapter 5's rule again -- sorted by
/// x. The slow version: it looks at every edge of the table.
pub fn crossings_on_row(table: &[Edge], y: f64) -> Vec<(f64, i64)> {
    let mut xs: Vec<(f64, i64)> = table
        .iter()
        .filter(|e| e.y_top <= y && y < e.y_bottom)
        .map(|e| (x_at(e, y), e.direction))
        .collect();
    xs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
    xs
}

/// Walks sorted crossings left to right, accumulating the winding number,
/// and returns the maximal `(x_start, x_end)` intervals where `rule`
/// ("nonzero" or "evenodd") says inside. Two inside stretches that touch
/// merge into one span, because the rule never turned false between them.
pub fn spans_from_crossings(xs: &[(f64, i64)], rule: &str) -> Vec<(f64, f64)> {
    let mut out = Vec::new();
    let mut w: i64 = 0;
    let mut start: Option<f64> = None;
    for &(x, d) in xs {
        w += d;
        let inside = if rule == "nonzero" { w != 0 } else { w.rem_euclid(2) != 0 };
        if inside && start.is_none() {
            start = Some(x);
        }
        if !inside {
            if let Some(s) = start.take() {
                out.push((s, x));
            }
        }
    }
    out
}

/// `crossings_on_row` and `spans_from_crossings` together, for one pixel
/// row: the row's crossings under `p`'s edge table, turned into spans
/// under `rule`, sampled at height `row + 0.5`.
pub fn spans(p: &Path, rule: &str, row: i64) -> Vec<(f64, f64)> {
    let table = edge_table(p);
    let y = row as f64 + 0.5;
    spans_from_crossings(&crossings_on_row(&table, y), rule)
}

/// Sets to 1 every pixel of `row` whose center lies in `[x0, x1)`: the
/// first is `ceil(x0 - 0.5)`, the last is `ceil(x1 - 0.5) - 1`, clipped to
/// the buffer. Half-open at the right end, so two spans that meet at a
/// pixel center fill that pixel exactly once.
pub fn fill_span(cov: &mut CoverageBuffer, row: i64, x0: f64, x1: f64) {
    let first = (x0 - 0.5).ceil() as i64;
    let last = (x1 - 0.5).ceil() as i64 - 1;
    let lo = first.max(0);
    let hi = last.min(cov.width as i64 - 1);
    for x in lo..=hi {
        set_coverage(cov, x, row, 1.0);
    }
}

// ---------------------------------------------------------------------
// § 6.3 The sweep
// ---------------------------------------------------------------------

/// The scanline fill: sweeps the rows top to bottom, keeping the list of
/// edges that span the current row's sample height (the table is read
/// once, front to back, since it's sorted by `y_top`), sorts their
/// crossings, and fills the spans. Its result is a coverage buffer of 0s
/// and 1s, exactly the one chapter 5's `rasterize_centers(filled(p,
/// rule), w, h)` produces -- but without asking every pixel about every
/// edge.
pub fn fill_path_aliased(p: &Path, rule: &str, width: usize, height: usize) -> CoverageBuffer {
    let mut cov = coverage_buffer(width, height);
    let table = edge_table(p);
    let mut active: Vec<Edge> = Vec::new();
    let mut next = 0;
    for row in 0..height as i64 {
        let y = row as f64 + 0.5;
        while next < table.len() && table[next].y_top <= y {
            active.push(table[next]);
            next += 1;
        }
        active.retain(|e| e.y_bottom > y);
        let mut xs: Vec<(f64, i64)> =
            active.iter().map(|e| (x_at(e, y), e.direction)).collect();
        xs.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
        for (x0, x1) in spans_from_crossings(&xs, rule) {
            fill_span(&mut cov, row, x0, x1);
        }
    }
    cov
}

/// The largest difference between corresponding entries of two coverage
/// buffers -- chapter 1's `max_channel_difference`, for coverage buffers
/// instead of pixels -- or `1` when their sizes differ, because two
/// buffers of different sizes can't be the same picture.
pub fn max_coverage_difference(a: &CoverageBuffer, b: &CoverageBuffer) -> f64 {
    if a.width != b.width || a.height != b.height {
        return 1.0;
    }
    a.values
        .iter()
        .zip(b.values.iter())
        .map(|(x, y)| (x - y).abs())
        .fold(0.0, f64::max)
}

// ---------------------------------------------------------------------
// § 6.4 Paths through matrices
// ---------------------------------------------------------------------

/// A new path with every point of every subpath taken through `m`, closed
/// flags and all -- `transform_points` with the subpath structure kept.
/// The original is untouched.
pub fn transform_path(p: &Path, m: Matrix3) -> Path {
    Path {
        subpaths: p
            .subpaths
            .iter()
            .map(|sp| Subpath { points: transform_points(&sp.points, m), closed: sp.closed })
            .collect(),
    }
}

// ---------------------------------------------------------------------
// § 6.5 Putting it together
// ---------------------------------------------------------------------

/// Chapter 5's star, moved to the origin and shrunk to radius 1, so one
/// matrix can put it anywhere at any size.
pub fn unit_star() -> Path {
    transform_path(&star(), scaling(1.0 / 70.0, 1.0 / 70.0) * translation(-80.5, -80.5))
}

/// Twenty-four unit stars along a spiral, each bigger and turned a little
/// further than the last, in three inks, filled nonzero by the sweep into
/// a 320x320 canvas.
pub fn spiral() -> Canvas {
    let mut c = canvas(320, 320);
    fill(&mut c, STAR_BG);
    let inks = [
        color(0.9, 0.55, 0.1),
        color(0.2, 0.55, 0.85),
        color(0.85, 0.25, 0.3),
    ];
    for k in 0..24 {
        let a = k as f64 * 25.0 * std::f64::consts::PI / 180.0;
        let r = 20.0 + 5.0 * k as f64;
        let scale = 6.0 + 1.25 * k as f64;
        let m = translation(160.5 + r * a.cos(), 160.5 + r * a.sin())
            * rotation(a)
            * scaling(scale, scale);
        let p = transform_path(&unit_star(), m);
        let cov = fill_path_aliased(&p, "nonzero", 320, 320);
        paint_through(&mut c, &cov, inks[(k % 3) as usize]);
    }
    c
}

/// Plate 6: `spiral`, magnified by 2.
pub fn plate_06() -> Canvas {
    magnify(&spiral(), 2)
}
