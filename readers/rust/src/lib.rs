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

// =======================================================================
// Chapter 7: Analytic Antialiasing
// =======================================================================

// ---------------------------------------------------------------------
// § 7.1 Two numbers per cell
// ---------------------------------------------------------------------

/// A grid of two numbers per cell: `area`, what the cell itself has
/// collected, and `cover`, the signed height it carries to every cell on
/// its right. Starts all zero.
#[derive(Debug, Clone)]
pub struct Accumulator {
    pub width: usize,
    pub height: usize,
    area: Vec<f64>,
    cover: Vec<f64>,
}

pub fn accumulator(width: usize, height: usize) -> Accumulator {
    Accumulator { width, height, area: vec![0.0; width * height], cover: vec![0.0; width * height] }
}

/// Reads outside the buffer are 0, same convention as `coverage_at`.
pub fn area_at(acc: &Accumulator, x: i64, y: i64) -> f64 {
    if x < 0 || y < 0 {
        return 0.0;
    }
    let (x, y) = (x as usize, y as usize);
    if x >= acc.width || y >= acc.height {
        return 0.0;
    }
    acc.area[y * acc.width + x]
}

pub fn cover_at(acc: &Accumulator, x: i64, y: i64) -> f64 {
    if x < 0 || y < 0 {
        return 0.0;
    }
    let (x, y) = (x as usize, y as usize);
    if x >= acc.width || y >= acc.height {
        return 0.0;
    }
    acc.cover[y * acc.width + x]
}

/// Deposits one cell's worth of area and cover, adding rather than
/// overwriting so two edges of the same shape can both have a say. A
/// deposit left of the buffer folds onto column 0 as pure cover -- the
/// whole height carries in, because everything in the row is to its
/// right. A deposit right of the buffer is dropped: there's nothing to
/// its right to carry into.
pub fn add_cell(acc: &mut Accumulator, x: i64, row: i64, area: f64, cover: f64) {
    let (mut x, mut area) = (x, area);
    if x < 0 {
        x = 0;
        area = cover;
    }
    if x >= acc.width as i64 {
        return;
    }
    let idx = row as usize * acc.width + x as usize;
    acc.area[idx] += area;
    acc.cover[idx] += cover;
}

// ---------------------------------------------------------------------
// § 7.2 One edge, one row
// ---------------------------------------------------------------------

/// Deposits the piece of an edge that lies in a single row, running from
/// `x0` to `x1` across it and carrying a signed `height`. If the piece
/// stays inside one cell, that cell gets the whole height as cover, and
/// an area weighted by how far the piece sits from the cell's right edge
/// -- the exact trapezoid rule from the chapter. A piece spanning several
/// cells shares the height by the width it has in each, using the same
/// midpoint rule inside its own cell.
pub fn accumulate_row(acc: &mut Accumulator, row: i64, x0: f64, x1: f64, height: f64) {
    let xa = x0.min(x1);
    let xb = x0.max(x1);
    let ca = xa.floor() as i64;
    let cb = xb.floor() as i64;
    if ca == cb {
        let xm = (xa + xb) / 2.0 - ca as f64;
        add_cell(acc, ca, row, height * (1.0 - xm), height);
        return;
    }
    let dx = xb - xa;
    for c in ca..=cb {
        let lo = xa.max(c as f64);
        let hi = xb.min(c as f64 + 1.0);
        let share = height * (hi - lo) / dx;
        let m = (lo + hi) / 2.0 - c as f64;
        add_cell(acc, c, row, share * (1.0 - m), share);
    }
}

// ---------------------------------------------------------------------
// § 7.3 Walking the edge down its rows
// ---------------------------------------------------------------------

/// Deposits a whole edge: clips it to each row it crosses and hands each
/// piece to `accumulate_row`. Heading up the canvas (decreasing y)
/// carries a positive height, heading down a negative one -- chapter 5's
/// winding sign. A horizontal edge deposits nothing (it would also
/// divide by zero). The row range is clipped to the buffer, so an edge
/// above or below it contributes only the rows it actually crosses; an
/// edge entirely left of the buffer still covers every row it spans
/// (through the column-0 folding in `add_cell`), and one entirely right
/// deposits nothing.
pub fn accumulate(acc: &mut Accumulator, a: Tuple, b: Tuple) {
    if a.y == b.y {
        return;
    }
    let sign = if a.y > b.y { 1.0 } else { -1.0 };
    let (top, bottom) = if a.y > b.y { (b, a) } else { (a, b) };
    let slope = (bottom.x - top.x) / (bottom.y - top.y);
    let first = (top.y.floor() as i64).max(0);
    let last = (bottom.y.ceil() as i64 - 1).min(acc.height as i64 - 1);
    let mut row = first;
    while row <= last {
        let y0 = top.y.max(row as f64);
        let y1 = bottom.y.min(row as f64 + 1.0);
        accumulate_row(
            acc,
            row,
            top.x + (y0 - top.y) * slope,
            top.x + (y1 - top.y) * slope,
            sign * (y1 - y0),
        );
        row += 1;
    }
}

// ---------------------------------------------------------------------
// § 7.4 The running sum
// ---------------------------------------------------------------------

/// Turns a (possibly fractional) winding number into coverage. For
/// "nonzero" that's the winding's absolute value capped at 1. For
/// "evenodd" it's the triangle wave that folds the absolute winding back
/// and forth between 0 and 1, so an even winding reads empty and an odd
/// one full.
pub fn apply_rule(w: f64, rule: &str) -> f64 {
    match parse_rule(rule) {
        Rule::NonZero => w.abs().min(1.0),
        Rule::EvenOdd => {
            let t = w.abs() % 2.0;
            if t <= 1.0 {
                t
            } else {
                2.0 - t
            }
        }
    }
}

/// Sweeps every row left to right: a cell's winding number is the cover
/// of every cell to its left plus its own area, and `apply_rule` turns
/// that (possibly fractional) number into coverage. One addition per
/// cell.
pub fn resolve(acc: &Accumulator, rule: &str) -> CoverageBuffer {
    let mut cov = coverage_buffer(acc.width, acc.height);
    for row in 0..acc.height as i64 {
        let mut running = 0.0;
        for x in 0..acc.width as i64 {
            let idx = row as usize * acc.width + x as usize;
            let value = apply_rule(running + acc.area[idx], rule);
            set_coverage(&mut cov, x, row, value);
            running += acc.cover[idx];
        }
    }
    cov
}

// ---------------------------------------------------------------------
// § 7.5 The fill, and how you know it's right
// ---------------------------------------------------------------------

/// Deposits every edge of `p` into a fresh accumulator and resolves it:
/// the fill from here to the end of the book, replacing chapter 6's
/// `fill_path_aliased`.
pub fn fill_path(p: &Path, rule: &str, width: usize, height: usize) -> CoverageBuffer {
    let mut acc = accumulator(width, height);
    for (a, b) in edges(p) {
        accumulate(&mut acc, a, b);
    }
    resolve(&acc, rule)
}

/// The shoelace formula: twice the signed area is the sum, over every
/// edge, of `a.x * b.y - b.x * a.y`. Every scenario that uses this walks
/// a single simple polygon (or several same-oriented, non-overlapping
/// ones, as `needle_path` does), so the sign only has to be consistent
/// within the path -- the absolute value at the end is the area.
pub fn polygon_area(p: &Path) -> f64 {
    let mut area = 0.0;
    for (a, b) in edges(p) {
        area += a.x * b.y - b.x * a.y;
    }
    (area / 2.0).abs()
}

// ---------------------------------------------------------------------
// § 7.6 Putting it together
// ---------------------------------------------------------------------

const SUNBURST_PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };
const SUNBURST_INKS: [Color; 3] = [
    Color { red: 0.9, green: 0.55, blue: 0.1 },
    Color { red: 0.2, green: 0.55, blue: 0.85 },
    Color { red: 0.85, green: 0.25, blue: 0.3 },
];
const SUNBURST_PALE: Color = Color { red: 0.92, green: 0.9, blue: 0.82 };

/// Twelve thin triangular needles fanned out from (30.5, 30.5), each a
/// couple of degrees wide and 29 pixels long -- Figure 7.1's subject and
/// the render whose ink chapter 6's aliased fill gets so wrong.
pub fn needle_path() -> Path {
    let mut p = path();
    for k in 0..12 {
        let a = (30.0 * k as f64 + 7.0) * std::f64::consts::PI / 180.0;
        let half = 1.6 * std::f64::consts::PI / 180.0;
        move_to(&mut p, point(30.5, 30.5));
        line_to(&mut p, point(30.5 + 29.0 * (a - half).cos(), 30.5 + 29.0 * (a - half).sin()));
        line_to(&mut p, point(30.5 + 29.0 * (a + half).cos(), 30.5 + 29.0 * (a + half).sin()));
        close(&mut p);
    }
    p
}

/// Every third one of seventy-two thin rays from the center of a
/// 480x480 canvas, starting at ray `i` (0, 1 or 2) -- the sunburst's
/// three interleaved sets of spokes, one per ink.
pub fn rays(i: usize) -> Path {
    let mut p = path();
    let mut k = i;
    while k < 72 {
        let a = 5.0 * k as f64 * std::f64::consts::PI / 180.0;
        let half = 1.4 * std::f64::consts::PI / 180.0;
        move_to(&mut p, point(240.0, 240.0));
        line_to(&mut p, point(240.0 + 232.0 * (a - half).cos(), 240.0 + 232.0 * (a - half).sin()));
        line_to(&mut p, point(240.0 + 232.0 * (a + half).cos(), 240.0 + 232.0 * (a + half).sin()));
        close(&mut p);
        k += 3;
    }
    p
}

/// The needles, chapter 6's aliased fill on the left, this chapter's
/// exact fill on the right, each panel painted from a fresh 60x60
/// coverage buffer and magnified 4x.
pub fn needles() -> Canvas {
    let np = needle_path();
    let mut left = canvas(60, 60);
    fill(&mut left, SUNBURST_PAPER);
    paint_through(&mut left, &fill_path_aliased(&np, "nonzero", 60, 60), SUNBURST_INKS[0]);
    let mut right = canvas(60, 60);
    fill(&mut right, SUNBURST_PAPER);
    paint_through(&mut right, &fill_path(&np, "nonzero", 60, 60), SUNBURST_INKS[0]);
    magnify(&side_by_side(&left, &right), 4)
}

/// A small square whose edges land on pixel centers, filled exactly on
/// an 8x8 buffer and magnified 24x so the soft edge is visible.
pub fn soft_square() -> Canvas {
    let mut c = canvas(8, 8);
    fill(&mut c, SUNBURST_PAPER);
    let sq = polygon(&[point(1.5, 1.5), point(5.5, 1.5), point(5.5, 5.5), point(1.5, 5.5)]);
    let cov = fill_path(&sq, "nonzero", 8, 8);
    paint_through(&mut c, &cov, SUNBURST_INKS[0]);
    magnify(&c, 24)
}

/// Chapter 5's star, filled exactly, nonzero on the left and even-odd on
/// the right, each on a 160x160 panel.
pub fn star_exact() -> Canvas {
    let mut nz = canvas(160, 160);
    fill(&mut nz, SUNBURST_PAPER);
    paint_through(&mut nz, &fill_path(&star(), "nonzero", 160, 160), SUNBURST_INKS[0]);
    let mut eo = canvas(160, 160);
    fill(&mut eo, SUNBURST_PAPER);
    paint_through(&mut eo, &fill_path(&star(), "evenodd", 160, 160), SUNBURST_INKS[0]);
    side_by_side(&nz, &eo)
}

/// Chapter 6's spiral of stars, filled by this chapter's exact fill
/// instead of the aliased sweep -- the same picture with the staircases
/// sanded off.
pub fn spiral_smooth() -> Canvas {
    let mut c = canvas(320, 320);
    fill(&mut c, SUNBURST_PAPER);
    for k in 0..24 {
        let a = k as f64 * 25.0 * std::f64::consts::PI / 180.0;
        let r = 20.0 + 5.0 * k as f64;
        let scale = 6.0 + 1.25 * k as f64;
        let m = translation(160.5 + r * a.cos(), 160.5 + r * a.sin())
            * rotation(a)
            * scaling(scale, scale);
        let p = transform_path(&unit_star(), m);
        let cov = fill_path(&p, "nonzero", 320, 320);
        paint_through(&mut c, &cov, SUNBURST_INKS[(k % 3) as usize]);
    }
    c
}

/// Seventy-two rays in three inks, a paper-colored disc punched out of
/// the middle, and a pale even-odd star dropped into the hole so its
/// pentagram shows.
pub fn sunburst() -> Canvas {
    let mut c = canvas(480, 480);
    fill(&mut c, SUNBURST_PAPER);
    for i in 0..3 {
        let cov = fill_path(&rays(i), "nonzero", 480, 480);
        paint_through(&mut c, &cov, SUNBURST_INKS[i]);
    }
    let disc = circle_path(240.0, 240.0, 78.0, 180);
    let cov = fill_path(&disc, "nonzero", 480, 480);
    paint_through(&mut c, &cov, SUNBURST_PAPER);
    let m = translation(240.0, 240.0) * scaling(64.0, 64.0);
    let star_p = transform_path(&unit_star(), m);
    let cov = fill_path(&star_p, "evenodd", 480, 480);
    paint_through(&mut c, &cov, SUNBURST_PALE);
    c
}

/// Plate 7: the sunburst.
pub fn plate_07() -> Canvas {
    sunburst()
}

// =======================================================================
// Chapter 8: Curves
// =======================================================================

// ---------------------------------------------------------------------
// § 8.1 A curve is its control points
// ---------------------------------------------------------------------

/// A Bezier curve, quadratic (3 points) or cubic (4), held as its control
/// points in order: it starts at the first, ends at the last, and leans
/// toward the ones in between without touching them.
#[derive(Debug, Clone)]
pub struct Curve {
    pub points: Vec<Tuple>,
}

pub fn quadratic(p0: Tuple, p1: Tuple, p2: Tuple) -> Curve {
    Curve { points: vec![p0, p1, p2] }
}

pub fn cubic(p0: Tuple, p1: Tuple, p2: Tuple, p3: Tuple) -> Curve {
    Curve { points: vec![p0, p1, p2, p3] }
}

fn lerp_tuple(a: Tuple, b: Tuple, t: f64) -> Tuple {
    a + (b - a) * t
}

/// De Casteljau's construction: repeatedly interpolate neighbouring
/// pairs by `t` until one point is left. Returns that point, along with
/// the left and right edges of the pyramid -- the control points of the
/// two halves `split_at` needs.
fn de_casteljau(points: &[Tuple], t: f64) -> (Tuple, Vec<Tuple>, Vec<Tuple>) {
    let mut left = vec![points[0]];
    let mut right = vec![points[points.len() - 1]];
    let mut pts = points.to_vec();
    while pts.len() > 1 {
        let mut next = Vec::with_capacity(pts.len() - 1);
        for i in 0..pts.len() - 1 {
            next.push(lerp_tuple(pts[i], pts[i + 1], t));
        }
        pts = next;
        left.push(pts[0]);
        right.push(*pts.last().unwrap());
    }
    right.reverse();
    (pts[0], left, right)
}

/// The point on the curve at parameter `t`, by de Casteljau's
/// construction.
pub fn point_at(c: &Curve, t: f64) -> Tuple {
    de_casteljau(&c.points, t).0
}

/// Splits the curve at `t` into the piece from 0 to `t` and the piece
/// from `t` to 1, each the same degree as the original -- the left and
/// right edges of the de Casteljau pyramid.
pub fn split_at(c: &Curve, t: f64) -> (Curve, Curve) {
    let (_, left, right) = de_casteljau(&c.points, t);
    (Curve { points: left }, Curve { points: right })
}

/// The tangent vector at `t`: the curve's own derivative, which is a
/// Bezier curve one degree lower whose control points are the original
/// ones' differences, scaled by the degree. Points backward when the
/// curve is heading back the way it came.
pub fn derivative(c: &Curve, t: f64) -> Tuple {
    let n = (c.points.len() - 1) as f64;
    let deriv: Vec<Tuple> =
        c.points.windows(2).map(|w| (w[1] - w[0]) * n).collect();
    de_casteljau(&deriv, t).0
}

/// Takes every control point through `m`.
pub fn transform_curve(c: &Curve, m: Matrix3) -> Curve {
    Curve { points: c.points.iter().map(|&p| m * p).collect() }
}

// ---------------------------------------------------------------------
// § 8.2 Tight bounds
// ---------------------------------------------------------------------

/// The roots in the open interval (0, 1) of a Bezier curve (in one
/// dimension) of degree 1 or 2, given its control-point values -- the
/// only two degrees a derivative in this book ever has (a quadratic's
/// derivative is linear, a cubic's is quadratic).
fn roots_in_unit_interval(values: &[f64]) -> Vec<f64> {
    match values.len() {
        2 => {
            let (d0, d1) = (values[0], values[1]);
            let denom = d0 - d1;
            if denom.abs() > 1e-12 {
                let t = d0 / denom;
                if t > 0.0 && t < 1.0 {
                    return vec![t];
                }
            }
            vec![]
        }
        3 => {
            let (d0, d1, d2) = (values[0], values[1], values[2]);
            let a = d0 - 2.0 * d1 + d2;
            let b = 2.0 * (d1 - d0);
            let c = d0;
            if a.abs() > 1e-12 {
                let disc = b * b - 4.0 * a * c;
                if disc < 0.0 {
                    return vec![];
                }
                let sq = disc.sqrt();
                [(-b + sq) / (2.0 * a), (-b - sq) / (2.0 * a)]
                    .into_iter()
                    .filter(|&t| t > 0.0 && t < 1.0)
                    .collect()
            } else if b.abs() > 1e-12 {
                let t = -c / b;
                if t > 0.0 && t < 1.0 {
                    vec![t]
                } else {
                    vec![]
                }
            } else {
                vec![]
            }
        }
        _ => vec![],
    }
}

/// The smallest axis-aligned box that holds the curve itself, not the
/// (usually looser) box around its control points: evaluate the curve at
/// both ends and at every parameter where a component of the derivative
/// is zero, and take the smallest and largest x and y.
pub fn curve_bounds(c: &Curve) -> (f64, f64, f64, f64) {
    let n = (c.points.len() - 1) as f64;
    let dxs: Vec<f64> = c.points.windows(2).map(|w| (w[1].x - w[0].x) * n).collect();
    let dys: Vec<f64> = c.points.windows(2).map(|w| (w[1].y - w[0].y) * n).collect();
    let mut ts = vec![0.0, 1.0];
    ts.extend(roots_in_unit_interval(&dxs));
    ts.extend(roots_in_unit_interval(&dys));

    let mut min_x = f64::INFINITY;
    let mut max_x = f64::NEG_INFINITY;
    let mut min_y = f64::INFINITY;
    let mut max_y = f64::NEG_INFINITY;
    for t in ts {
        let p = point_at(c, t);
        min_x = min_x.min(p.x);
        max_x = max_x.max(p.x);
        min_y = min_y.min(p.y);
        max_y = max_y.max(p.y);
    }
    (min_x, min_y, max_x, max_y)
}

// ---------------------------------------------------------------------
// § 8.3 Flattening
// ---------------------------------------------------------------------

/// How far the curve strays from the straight chord between its ends:
/// the greatest distance of an interior control point from that chord.
/// Zero means the curve is already a line.
pub fn flatness(c: &Curve) -> f64 {
    let a = c.points[0];
    let b = *c.points.last().unwrap();
    let dx = b.x - a.x;
    let dy = b.y - a.y;
    let len = (dx * dx + dy * dy).sqrt();
    let mut worst = 0.0;
    for p in &c.points[1..c.points.len() - 1] {
        let d = if len == 0.0 {
            ((p.x - a.x).powi(2) + (p.y - a.y).powi(2)).sqrt()
        } else {
            ((p.x - a.x) * dy - (p.y - a.y) * dx).abs() / len
        };
        worst = f64::max(worst, d);
    }
    worst
}

fn flatten_into(c: &Curve, tolerance: f64, out: &mut Vec<Tuple>) {
    if flatness(c) <= tolerance {
        out.push(*c.points.last().unwrap());
    } else {
        let (left, right) = split_at(c, 0.5);
        flatten_into(&left, tolerance, out);
        flatten_into(&right, tolerance, out);
    }
}

/// Turns the curve into a polyline within `tolerance` of it: recurses,
/// splitting in half wherever a piece isn't yet flat enough, and returns
/// the endpoints it collects, first to last, both ends always included.
pub fn flatten(c: &Curve, tolerance: f64) -> Vec<Tuple> {
    let mut out = vec![c.points[0]];
    flatten_into(c, tolerance, &mut out);
    out
}

/// The length of a polyline: the sum of the distances between
/// consecutive points.
pub fn polyline_length(points: &[Tuple]) -> f64 {
    points.windows(2).map(|w| magnitude(w[1] - w[0])).sum()
}

/// `flatten(c, tolerance)`'s length -- climbs toward the curve's true arc
/// length as the tolerance shrinks.
pub fn flatten_length(c: &Curve, tolerance: f64) -> f64 {
    polyline_length(&flatten(c, tolerance))
}

/// Appends a flattened curve to a path with `line_to`, skipping the
/// curve's own first point when it's already where the pen is (either
/// because a previous curve just ended there, or because this is the
/// first thing added to a fresh subpath after a close).
pub fn flatten_into_path(p: &mut Path, c: &Curve, tolerance: f64) {
    let mut pts = flatten(c, tolerance);
    let start_fresh = match subpaths(p).last() {
        None => true,
        Some(last) => last.closed,
    };
    if start_fresh {
        move_to(p, pts[0]);
        pts.remove(0);
    } else {
        let cur = *subpaths(p).last().unwrap().points.last().unwrap();
        if cur.x == pts[0].x && cur.y == pts[0].y {
            pts.remove(0);
        }
    }
    for q in pts {
        line_to(p, q);
    }
}

// ---------------------------------------------------------------------
// § 8.4 The elliptical arc
// ---------------------------------------------------------------------

/// An SVG elliptical arc in center form: the center, radii, the
/// x-axis rotation `phi` (radians), a start angle `theta1` and a swept
/// angle `delta`, both radians. `corrected` says whether the radii had to
/// be grown to reach between the endpoints.
#[derive(Debug, Clone, Copy)]
pub struct Arc {
    pub cx: f64,
    pub cy: f64,
    pub rx: f64,
    pub ry: f64,
    pub phi: f64,
    pub theta1: f64,
    pub delta: f64,
    pub corrected: bool,
}

/// The signed angle from `(ux, uy)` to `(vx, vy)`, in `(-pi, pi]`.
fn angle_between(ux: f64, uy: f64, vx: f64, vy: f64) -> f64 {
    let dot = ux * vx + uy * vy;
    let len = (ux * ux + uy * uy).sqrt() * (vx * vx + vy * vy).sqrt();
    let a = (dot / len).clamp(-1.0, 1.0).acos();
    if ux * vy - uy * vx >= 0.0 {
        a
    } else {
        -a
    }
}

/// Turns SVG's endpoint form of an elliptical arc into the center form
/// `arc_point` can walk, following the spec's own construction. `None`
/// for a degenerate arc: coincident endpoints, or either radius zero.
/// Radii too small to reach between the endpoints are grown together
/// (never clamped individually) until they just do, and `corrected` is
/// set so a caller can tell.
pub fn arc(x1: f64, y1: f64, rx: f64, ry: f64, phi: f64, large_arc: bool, sweep: bool, x2: f64, y2: f64) -> Option<Arc> {
    if (x1 == x2 && y1 == y2) || rx == 0.0 || ry == 0.0 {
        return None;
    }
    let (mut rx, mut ry) = (rx.abs(), ry.abs());
    let (cphi, sphi) = (phi.cos(), phi.sin());
    let (dx, dy) = ((x1 - x2) / 2.0, (y1 - y2) / 2.0);
    let x1p = cphi * dx + sphi * dy;
    let y1p = -sphi * dx + cphi * dy;
    let mut corrected = false;

    let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
    if lambda > 1.0 {
        let s = lambda.sqrt();
        rx *= s;
        ry *= s;
        corrected = true;
    }

    let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    let mut co = (num / den).max(0.0).sqrt();
    if large_arc == sweep {
        co = -co;
    }
    let cxp = co * rx * y1p / ry;
    let cyp = -co * ry * x1p / rx;
    let cx = cphi * cxp - sphi * cyp + (x1 + x2) / 2.0;
    let cy = sphi * cxp + cphi * cyp + (y1 + y2) / 2.0;

    let theta1 = angle_between(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry);
    let mut delta = angle_between(
        (x1p - cxp) / rx,
        (y1p - cyp) / ry,
        (-x1p - cxp) / rx,
        (-y1p - cyp) / ry,
    );
    if !sweep && delta > 0.0 {
        delta -= 2.0 * std::f64::consts::PI;
    } else if sweep && delta < 0.0 {
        delta += 2.0 * std::f64::consts::PI;
    }

    Some(Arc { cx, cy, rx, ry, phi, theta1, delta, corrected })
}

/// The point at `t` (0 to 1) along the arc.
pub fn arc_point(a: &Arc, t: f64) -> Tuple {
    let theta = a.theta1 + a.delta * t;
    let (cphi, sphi) = (a.phi.cos(), a.phi.sin());
    let ex = a.rx * theta.cos();
    let ey = a.ry * theta.sin();
    point(a.cx + cphi * ex - sphi * ey, a.cy + sphi * ex + cphi * ey)
}

// ---------------------------------------------------------------------
// § 8.5 Putting it together
// ---------------------------------------------------------------------

/// A teardrop: two cubics, tip to base and back.
fn teardrop() -> (Curve, Curve) {
    (
        cubic(point(30.5, 12.0), point(58.0, 16.0), point(46.0, 52.0), point(30.5, 52.0)),
        cubic(point(30.5, 52.0), point(15.0, 52.0), point(3.0, 16.0), point(30.5, 12.0)),
    )
}

/// The same teardrop filled twice: flattened coarse on the left, fine on
/// the right, so the facets show. Two 60x60 panels, side by side, at
/// their own scale (no magnification -- the point is the facets, not the
/// pixels).
pub fn drops() -> Canvas {
    let (t0, t1) = teardrop();
    let mut left = canvas(60, 60);
    fill(&mut left, SUNBURST_PAPER);
    let mut coarse = path();
    flatten_into_path(&mut coarse, &t0, 4.0);
    flatten_into_path(&mut coarse, &t1, 4.0);
    close(&mut coarse);
    paint_through(&mut left, &fill_path(&coarse, "nonzero", 60, 60), SUNBURST_INKS[2]);

    let mut right = canvas(60, 60);
    fill(&mut right, SUNBURST_PAPER);
    let mut fine = path();
    flatten_into_path(&mut fine, &t0, 0.1);
    flatten_into_path(&mut fine, &t1, 0.1);
    close(&mut fine);
    paint_through(&mut right, &fill_path(&fine, "nonzero", 60, 60), SUNBURST_INKS[2]);

    magnify(&side_by_side(&left, &right), 4)
}

/// A petal about one unit tall, tip at the top: two cubics, out to one
/// side and back.
fn petal() -> (Curve, Curve) {
    (
        cubic(point(0.0, 0.0), point(0.55, -0.35), point(0.4, -0.92), point(0.0, -1.0)),
        cubic(point(0.0, -1.0), point(-0.4, -0.92), point(-0.55, -0.35), point(0.0, 0.0)),
    )
}

/// Adds `n` petals around the origin, placed and sized by `m`, to `p`:
/// each petal is transformed to its final place first, then flattened in
/// that device space at one shared tolerance, so a bigger flower gets
/// more segments than a small one and both come out equally smooth.
pub fn flower_at(p: &mut Path, m: Matrix3, n: usize, tolerance: f64) {
    let (right, left) = petal();
    for k in 0..n {
        let spin = m * rotation(2.0 * std::f64::consts::PI * k as f64 / n as f64);
        flatten_into_path(p, &transform_curve(&right, spin), tolerance);
        flatten_into_path(p, &transform_curve(&left, spin), tolerance);
        close(p);
    }
}

/// Three flowers of curved petals at three sizes, a disc punched out of
/// each center, on a 360x360 canvas.
pub fn flower() -> Canvas {
    let mut c = canvas(360, 360);
    fill(&mut c, SUNBURST_PAPER);
    let spots: [(f64, f64, f64, usize, f64); 3] = [
        (108.0, 250.0, 44.0, 8, 0.0),
        (200.0, 145.0, 74.0, 8, 0.39),
        (286.0, 252.0, 54.0, 7, 0.8),
    ];
    for (i, &(cx, cy, s, n, rot)) in spots.iter().enumerate() {
        let m = translation(cx, cy) * scaling(s, s) * rotation(rot);
        let mut petals = path();
        flower_at(&mut petals, m, n, 0.2);
        paint_through(&mut c, &fill_path(&petals, "nonzero", 360, 360), SUNBURST_INKS[i % 3]);
        let disc = circle_path(cx, cy, s * 0.3, 64);
        paint_through(&mut c, &fill_path(&disc, "nonzero", 360, 360), SUNBURST_PAPER);
    }
    c
}

/// Plate 8: the flowers, magnified by 2.
pub fn plate_08() -> Canvas {
    magnify(&flower(), 2)
}

// =======================================================================
// Chapter 9: Compositing
// =======================================================================

// ---------------------------------------------------------------------
// § 9.1 Premultiplied pixels
// ---------------------------------------------------------------------

/// A translucent pixel: red, green, blue and alpha, with the colour
/// already multiplied by the alpha (`r`, `g`, `b` each in `[0, a]`). This
/// is the only representation in which averaging two pixels -- what any
/// filter does -- is even defined: a fully transparent pixel contributes
/// nothing, because here nothing is what it is.
#[derive(Debug, Clone, Copy)]
pub struct Pixel {
    pub r: f64,
    pub g: f64,
    pub b: f64,
    pub a: f64,
}

pub fn pixel(r: f64, g: f64, b: f64, a: f64) -> Pixel {
    Pixel { r, g, b, a }
}

/// Premultiplies a straight colour by an alpha.
pub fn from_color(c: Color, a: f64) -> Pixel {
    pixel(c.red * a, c.green * a, c.blue * a, a)
}

/// A straight colour at alpha 1: premultiplying leaves it unchanged.
pub fn opaque(c: Color) -> Pixel {
    from_color(c, 1.0)
}

/// Fully transparent: no colour, no alpha.
pub const CLEAR: Pixel = Pixel { r: 0.0, g: 0.0, b: 0.0, a: 0.0 };

/// Un-premultiplies a pixel back into a straight colour. A transparent
/// pixel has no colour to recover, so it reads black -- consistent with
/// `CLEAR`'s own channels, and never divides by zero.
pub fn pixel_color(p: Pixel) -> Color {
    if p.a == 0.0 {
        color(0.0, 0.0, 0.0)
    } else {
        color(p.r / p.a, p.g / p.a, p.b / p.a)
    }
}

pub fn pixel_alpha(p: Pixel) -> f64 {
    p.a
}

/// Pixels compare channel by channel (`r`, `g`, `b`, `a`), with the usual
/// tolerance.
pub fn pixels_eq(a: Pixel, b: Pixel) -> bool {
    approx_eq(a.r, b.r) && approx_eq(a.g, b.g) && approx_eq(a.b, b.b) && approx_eq(a.a, b.a)
}

/// Straight down the premultiplied channels: the whole reason for
/// premultiplying in the first place -- half of opaque red and half of
/// nothing comes out red at half alpha, not a muddy grey.
pub fn lerp_pixel(a: Pixel, b: Pixel, t: f64) -> Pixel {
    pixel(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
}

// ---------------------------------------------------------------------
// § 9.2 Source-over
// ---------------------------------------------------------------------

/// `src` composited over `dst`: keep all of the source, and let through
/// the fraction of the destination the source didn't cover. Every channel,
/// alpha included. What `paint_through` has been doing since chapter 2,
/// with the destination pinned opaque.
pub fn over(src: Pixel, dst: Pixel) -> Pixel {
    let t = 1.0 - src.a;
    pixel(src.r + t * dst.r, src.g + t * dst.g, src.b + t * dst.b, src.a + t * dst.a)
}

// ---------------------------------------------------------------------
// § 9.3 Twelve operators, one formula
// ---------------------------------------------------------------------

/// The two Porter-Duff coefficients (Fa, Fb) for `op`, given the source
/// and destination alphas: how much of the source survives, and how much
/// of the destination.
fn porter_duff_coeffs(op: &str, a_s: f64, a_d: f64) -> (f64, f64) {
    match op {
        "clear" => (0.0, 0.0),
        "src" => (1.0, 0.0),
        "dst" => (0.0, 1.0),
        "src-over" => (1.0, 1.0 - a_s),
        "dst-over" => (1.0 - a_d, 1.0),
        "src-in" => (a_d, 0.0),
        "dst-in" => (0.0, a_s),
        "src-out" => (1.0 - a_d, 0.0),
        "dst-out" => (0.0, 1.0 - a_s),
        "src-atop" => (a_d, 1.0 - a_s),
        "dst-atop" => (1.0 - a_d, a_s),
        "xor" => (1.0 - a_d, 1.0 - a_s),
        other => panic!("unknown porter-duff operator: {other}"),
    }
}

/// `Fa * src + Fb * dst`, every channel including alpha: one formula, and
/// an operator is nothing but its choice of the two coefficients.
pub fn composite(op: &str, src: Pixel, dst: Pixel) -> Pixel {
    let (fa, fb) = porter_duff_coeffs(op, src.a, dst.a);
    pixel(
        fa * src.r + fb * dst.r,
        fa * src.g + fb * dst.g,
        fa * src.b + fb * dst.b,
        fa * src.a + fb * dst.a,
    )
}

// ---------------------------------------------------------------------
// § 9.4 Blend modes
// ---------------------------------------------------------------------

fn blend_screen(b: f64, s: f64) -> f64 {
    b + s - b * s
}

fn blend_hard_light(b: f64, s: f64) -> f64 {
    if s <= 0.5 {
        b * 2.0 * s
    } else {
        blend_screen(b, 2.0 * s - 1.0)
    }
}

fn blend_soft_light(b: f64, s: f64) -> f64 {
    if s <= 0.5 {
        b - (1.0 - 2.0 * s) * b * (1.0 - b)
    } else {
        let d = if b <= 0.25 { ((16.0 * b - 12.0) * b + 4.0) * b } else { b.sqrt() };
        b + (2.0 * s - 1.0) * (d - b)
    }
}

fn blend_dodge(b: f64, s: f64) -> f64 {
    if b == 0.0 {
        0.0
    } else if s == 1.0 {
        1.0
    } else {
        (b / (1.0 - s)).min(1.0)
    }
}

fn blend_burn(b: f64, s: f64) -> f64 {
    if b == 1.0 {
        1.0
    } else if s == 0.0 {
        0.0
    } else {
        1.0 - ((1.0 - b) / s).min(1.0)
    }
}

/// The twelve separable modes, each a one-line function of `(backdrop,
/// source)`. `None` for a mode this table doesn't cover -- the four
/// non-separable ones, handled by `nonsep`.
fn separable_blend(mode: &str) -> Option<fn(f64, f64) -> f64> {
    match mode {
        "normal" => Some(|_b: f64, s: f64| s),
        "multiply" => Some(|b: f64, s: f64| b * s),
        "screen" => Some(blend_screen),
        "overlay" => Some(|b: f64, s: f64| blend_hard_light(s, b)),
        "darken" => Some(|b: f64, s: f64| b.min(s)),
        "lighten" => Some(|b: f64, s: f64| b.max(s)),
        "color-dodge" => Some(blend_dodge),
        "color-burn" => Some(blend_burn),
        "hard-light" => Some(blend_hard_light),
        "soft-light" => Some(blend_soft_light),
        "difference" => Some(|b: f64, s: f64| (b - s).abs()),
        "exclusion" => Some(|b: f64, s: f64| b + s - 2.0 * b * s),
        _ => None,
    }
}

// ---------------------------------------------------------------------
// § 9.5 The four that mix whole colours
// ---------------------------------------------------------------------

/// A colour's brightness: a weighted sum of its channels, not their
/// average -- green counts for more than blue.
fn lum(c: Color) -> f64 {
    0.3 * c.red + 0.59 * c.green + 0.11 * c.blue
}

/// Shifts `c`'s channels back into `[0, 1]` without changing its hue,
/// after `set_lum` has already moved it to the target brightness (which
/// can push a channel out of range in either direction).
fn clip_color(c: Color) -> Color {
    let l = lum(c);
    let n = c.red.min(c.green).min(c.blue);
    let x = c.red.max(c.green).max(c.blue);
    let mut o = c;
    if n < 0.0 {
        o = color(l + (o.red - l) * l / (l - n), l + (o.green - l) * l / (l - n), l + (o.blue - l) * l / (l - n));
    }
    if x > 1.0 {
        o = color(
            l + (o.red - l) * (1.0 - l) / (x - l),
            l + (o.green - l) * (1.0 - l) / (x - l),
            l + (o.blue - l) * (1.0 - l) / (x - l),
        );
    }
    o
}

/// Shifts `c` to brightness `l`, clipping back into range without
/// changing its hue.
fn set_lum(c: Color, l: f64) -> Color {
    let d = l - lum(c);
    clip_color(color(c.red + d, c.green + d, c.blue + d))
}

/// How far a colour's channels spread: the largest minus the smallest.
fn sat(c: Color) -> f64 {
    c.red.max(c.green).max(c.blue) - c.red.min(c.green).min(c.blue)
}

/// Stretches `c` to saturation `s`, keeping its hue and (before `set_lum`
/// fixes it up) roughly its brightness.
fn set_sat(c: Color, s: f64) -> Color {
    let v = [c.red, c.green, c.blue];
    let mut idx = [0usize, 1, 2];
    idx.sort_by(|&i, &j| v[i].partial_cmp(&v[j]).unwrap());
    let (lo, mid, hi) = (idx[0], idx[1], idx[2]);
    let mut o = [0.0; 3];
    if v[hi] > v[lo] {
        o[mid] = (v[mid] - v[lo]) * s / (v[hi] - v[lo]);
        o[hi] = s;
    }
    o[lo] = 0.0;
    color(o[0], o[1], o[2])
}

/// The four modes that mix whole colours instead of channels: `colour` is
/// the source's hue and saturation at the backdrop's brightness,
/// `luminosity` is the reverse, and `hue`/`saturation` take one property
/// from each.
fn nonseparable_blend(mode: &str, b: Color, s: Color) -> Color {
    match mode {
        "hue" => set_lum(set_sat(s, sat(b)), lum(b)),
        "saturation" => set_lum(set_sat(b, sat(s)), lum(b)),
        "color" => set_lum(s, lum(b)),
        _ => set_lum(b, lum(s)), // "luminosity"
    }
}

/// The blend function itself, `B(backdrop, source)`: the twelve separable
/// modes channel by channel, the four non-separable ones on the whole
/// colour.
pub fn blend_color(mode: &str, backdrop: Color, source: Color) -> Color {
    if let Some(f) = separable_blend(mode) {
        color(f(backdrop.red, source.red), f(backdrop.green, source.green), f(backdrop.blue, source.blue))
    } else {
        nonseparable_blend(mode, backdrop, source)
    }
}

/// Source-over, with the overlap blended first: where source and
/// destination overlap the blended colour appears, fading to plain
/// source-over where they don't. Mode `"normal"` returns the source
/// unchanged, which collapses this back to `over`.
pub fn blend(mode: &str, src: Pixel, dst: Pixel) -> Pixel {
    let a_s = src.a;
    let a_d = dst.a;
    let cs = pixel_color(src);
    let cb = pixel_color(dst);
    let b = blend_color(mode, cb, cs);
    let ch = |csx: f64, bx: f64, dx: f64| a_s * (1.0 - a_d) * csx + a_s * a_d * bx + (1.0 - a_s) * dx;
    pixel(
        ch(cs.red, b.red, dst.r),
        ch(cs.green, b.green, dst.g),
        ch(cs.blue, b.blue, dst.b),
        a_s + a_d * (1.0 - a_s),
    )
}

// ---------------------------------------------------------------------
// § 9.6 Putting it together: layers
// ---------------------------------------------------------------------

/// A buffer of premultiplied pixels, starting fully transparent.
#[derive(Debug, Clone)]
pub struct Layer {
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<Pixel>,
}

pub fn layer(width: usize, height: usize) -> Layer {
    Layer { width, height, pixels: vec![CLEAR; width * height] }
}

/// Paints a shape into a layer through its coverage, the way chapter 2's
/// `paint_through` painted a shape into a canvas -- except the untouched
/// parts stay genuinely transparent instead of paper-coloured.
pub fn paint_shape(l: &mut Layer, cov: &CoverageBuffer, col: Color) {
    for y in 0..l.height as i64 {
        for x in 0..l.width as i64 {
            let k = coverage_at(cov, x, y);
            if k > 0.0 {
                let idx = y as usize * l.width + x as usize;
                l.pixels[idx] = from_color(col, k);
            }
        }
    }
}

/// Composites `src` over `dst`, pixel by pixel, with a Porter-Duff
/// operator.
pub fn composite_layers(op: &str, src: &Layer, dst: &Layer) -> Layer {
    let mut out = layer(src.width, src.height);
    for i in 0..out.pixels.len() {
        out.pixels[i] = composite(op, src.pixels[i], dst.pixels[i]);
    }
    out
}

/// Blends `src` over `dst`, pixel by pixel, with a blend mode --
/// `composite_layers`'s sibling for §9.4/9.5.
fn blend_layers(mode: &str, src: &Layer, dst: &Layer) -> Layer {
    let mut out = layer(src.width, src.height);
    for i in 0..out.pixels.len() {
        out.pixels[i] = blend(mode, src.pixels[i], dst.pixels[i]);
    }
    out
}

/// Flattens a layer over an opaque background so it can be seen: `over`
/// against `bg`, pixel by pixel, un-premultiplied back into a canvas.
pub fn flatten_layer(l: &Layer, bg: Color) -> Canvas {
    let mut c = canvas(l.width, l.height);
    let base = opaque(bg);
    for y in 0..l.height as i64 {
        for x in 0..l.width as i64 {
            let idx = y as usize * l.width + x as usize;
            let q = over(l.pixels[idx], base);
            write_pixel(&mut c, x, y, pixel_color(q));
        }
    }
    c
}

const CH9_PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };
const CH9_DST: Color = Color { red: 0.2, green: 0.5, blue: 0.85 };
const CH9_SRC: Color = Color { red: 0.95, green: 0.55, blue: 0.1 };
const CH9_TILE: usize = 64;

const PORTER_DUFF_OPS: [&str; 12] = [
    "clear", "src", "dst", "src-over", "dst-over", "src-in", "dst-in", "src-out", "dst-out", "src-atop",
    "dst-atop", "xor",
];

const BLEND_MODES: [&str; 16] = [
    "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge", "color-burn", "hard-light",
    "soft-light", "difference", "exclusion", "hue", "saturation", "color", "luminosity",
];

/// A blue square, the destination for every tile of the table.
fn dst_layer() -> Layer {
    let mut l = layer(CH9_TILE, CH9_TILE);
    let square = polygon(&[point(10.0, 10.0), point(42.0, 10.0), point(42.0, 42.0), point(10.0, 42.0)]);
    let cov = fill_path(&square, "nonzero", CH9_TILE, CH9_TILE);
    paint_shape(&mut l, &cov, CH9_DST);
    l
}

/// An orange circle (a 48-sided polygon standing in for one), the source
/// for every tile of the table.
fn src_layer() -> Layer {
    let mut l = layer(CH9_TILE, CH9_TILE);
    let circle = circle_path(38.0, 38.0, 20.0, 48);
    let cov = fill_path(&circle, "nonzero", CH9_TILE, CH9_TILE);
    paint_shape(&mut l, &cov, CH9_SRC);
    l
}

/// Lays out `tiles.len()` flattened layers in a grid four columns wide,
/// each `CH9_TILE` square, on paper.
fn tile_grid<F: Fn(&Layer, &Layer) -> Layer>(tiles: &[F]) -> Canvas {
    let cols = 4;
    let rows = tiles.len().div_ceil(cols);
    let mut c = canvas(cols * CH9_TILE, rows * CH9_TILE);
    fill(&mut c, CH9_PAPER);
    let src = src_layer();
    let dst = dst_layer();
    for (i, make) in tiles.iter().enumerate() {
        let flat = flatten_layer(&make(&src, &dst), CH9_PAPER);
        let ox = (i % cols) * CH9_TILE;
        let oy = (i / cols) * CH9_TILE;
        for y in 0..CH9_TILE {
            for x in 0..CH9_TILE {
                write_pixel(&mut c, (ox + x) as i64, (oy + y) as i64, pixel_at(&flat, x as i64, y as i64));
            }
        }
    }
    c
}

/// The twelve Porter-Duff operators, a blue square as destination and an
/// orange circle as source, laid out four columns by three rows.
pub fn porter_duff_table() -> Canvas {
    let tiles: Vec<_> =
        PORTER_DUFF_OPS.iter().map(|&op| move |s: &Layer, d: &Layer| composite_layers(op, s, d)).collect();
    tile_grid(&tiles)
}

/// Plate 9: the Porter-Duff table, magnified by 2.
pub fn plate_09() -> Canvas {
    magnify(&porter_duff_table(), 2)
}

/// The sixteen blend modes, same square and circle, laid out four columns
/// by four rows.
pub fn blend_strip() -> Canvas {
    let tiles: Vec<_> =
        BLEND_MODES.iter().map(|&mode| move |s: &Layer, d: &Layer| blend_layers(mode, s, d)).collect();
    tile_grid(&tiles)
}

/// The conflation trap: two opaque triangles that share a diagonal,
/// composited src-over one after the other onto opaque paper. Together
/// they cover a solid square, but the shared edge is antialiased on both
/// triangles, so the seam pixels get composited as two independent
/// translucent layers instead of one opaque surface -- coverage 0.75
/// where it should be 1.0. Magnified by 4 so the seam is visible.
pub fn seam() -> Canvas {
    let w = 80usize;
    let mut base = layer(w, w);
    for p in base.pixels.iter_mut() {
        *p = opaque(CH9_PAPER);
    }
    let tris = [
        polygon(&[point(4.0, 4.0), point(76.0, 76.0), point(4.0, 76.0)]),
        polygon(&[point(4.0, 4.0), point(76.0, 4.0), point(76.0, 76.0)]),
    ];
    for tri in &tris {
        let mut s = layer(w, w);
        let cov = fill_path(tri, "nonzero", w, w);
        paint_shape(&mut s, &cov, CH9_SRC);
        let mut next = layer(w, w);
        for j in 0..w * w {
            next.pixels[j] = composite("src-over", s.pixels[j], base.pixels[j]);
        }
        base = next;
    }
    let mut c = canvas(w, w);
    for y in 0..w as i64 {
        for x in 0..w as i64 {
            let idx = y as usize * w + x as usize;
            write_pixel(&mut c, x, y, pixel_color(base.pixels[idx]));
        }
    }
    magnify(&c, 4)
}

// =======================================================================
// Chapter 10: Paint Servers and Gradients
// =======================================================================

// ---------------------------------------------------------------------
// § 10.1 The stop table
// ---------------------------------------------------------------------

/// One colour stop: an offset in `[0, 1]` and the colour there.
#[derive(Debug, Clone, Copy)]
pub struct Stop {
    pub offset: f64,
    pub color: Color,
}

pub fn stop(offset: f64, color: Color) -> Stop {
    Stop { offset, color }
}

/// The colour at parameter `t`: the first colour below the first stop,
/// the last colour above the last stop, and otherwise a straight blend
/// (in linear light) between the two stops that bracket `t`, weighted by
/// how far along it falls. `stops` is assumed sorted by offset, as every
/// gradient constructor here builds it. A binary search finds the
/// bracketing pair -- with more than a couple of stops, a linear scan
/// would mean walking the whole table for every pixel.
pub fn sample_stops(stops: &[Stop], t: f64) -> Color {
    let n = stops.len();
    if t <= stops[0].offset {
        return stops[0].color;
    }
    if t >= stops[n - 1].offset {
        return stops[n - 1].color;
    }
    let mut lo = 0usize;
    let mut hi = n - 1;
    while hi - lo > 1 {
        let mid = (lo + hi) / 2;
        if stops[mid].offset <= t {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    let a = stops[lo];
    let b = stops[hi];
    let frac = if b.offset == a.offset { 0.0 } else { (t - a.offset) / (b.offset - a.offset) };
    a.color + (b.color - a.color) * frac
}

// ---------------------------------------------------------------------
// § 10.2 Extend modes
// ---------------------------------------------------------------------

/// Folds a parameter that fell outside `[0, 1]` back in. `"pad"` clamps
/// to the ends, `"repeat"` wraps, and `"reflect"` bounces back and forth
/// so the gradient mirrors every unit.
pub fn extend(t: f64, mode: &str) -> f64 {
    match mode {
        "pad" => t.clamp(0.0, 1.0),
        "repeat" => t - t.floor(),
        "reflect" => {
            let u = t.abs() % 2.0;
            if u <= 1.0 {
                u
            } else {
                2.0 - u
            }
        }
        other => panic!("unknown extend mode: {other}"),
    }
}

// ---------------------------------------------------------------------
// § 10.3 The three gradients, and § 10.4 painting with a paint
// ---------------------------------------------------------------------

/// Anything that turns a device point into a colour. A solid paint
/// ignores the point; the three gradients project it down to a number
/// and look that up in a stop table. Chapter 11 adds a fifth kind, an
/// image sampled through the inverse of the matrix that places it.
#[derive(Debug, Clone)]
pub enum Paint {
    Solid(Color),
    Linear { p0: Tuple, p1: Tuple, stops: Vec<Stop>, extend: String },
    Radial { c0: Tuple, r0: f64, c1: Tuple, r1: f64, stops: Vec<Stop>, extend: String },
    Conic { center: Tuple, angle0: f64, stops: Vec<Stop>, extend: String },
    Image { img: Image, inv: Matrix3, filter: String, extend: String },
}

/// A paint that ignores the point and always returns `c`.
pub fn solid(c: Color) -> Paint {
    Paint::Solid(c)
}

/// An axis from `p0` to `p1`: the parameter of a point is how far it
/// projects onto that axis, as a fraction of the axis's length.
pub fn linear_gradient(p0: Tuple, p1: Tuple, stops: Vec<Stop>, extend: &str) -> Paint {
    Paint::Linear { p0, p1, stops, extend: extend.to_string() }
}

/// Two circles -- a start circle at `t = 0`, an end circle at `t = 1` --
/// interpolating both center and radius. `r0 = 0` and an offset `c0` is
/// SVG's focal gradient.
pub fn radial_gradient(c0: Tuple, r0: f64, c1: Tuple, r1: f64, stops: Vec<Stop>, extend: &str) -> Paint {
    Paint::Radial { c0, r0, c1, r1, stops, extend: extend.to_string() }
}

/// The angle from `center` to the point, swept around a full turn
/// starting at `angle0`.
pub fn conic_gradient(center: Tuple, angle0: f64, stops: Vec<Stop>, extend: &str) -> Paint {
    Paint::Conic { center, angle0, stops, extend: extend.to_string() }
}

/// The parameter of `(x, y)` along a linear gradient's axis: a dot
/// product over the squared length of the axis. On the axis this is
/// exactly the fraction of the way from `p0` to `p1`; perpendicular to
/// it, unchanged.
pub fn linear_t(g: &Paint, x: f64, y: f64) -> f64 {
    match g {
        Paint::Linear { p0, p1, .. } => {
            let dx = p1.x - p0.x;
            let dy = p1.y - p0.y;
            ((x - p0.x) * dx + (y - p0.y) * dy) / (dx * dx + dy * dy)
        }
        _ => panic!("linear_t: not a linear gradient"),
    }
}

/// The `t` of the interpolated circle (between the start and end circles)
/// that passes through `(x, y)`: solve the quadratic in `t` and return the
/// first root (checked in this order, not sorted by size) whose radius
/// isn't negative. `None` when neither root has a valid radius -- the
/// focal gradient's unreachable cone.
pub fn radial_t(g: &Paint, x: f64, y: f64) -> Option<f64> {
    match g {
        Paint::Radial { c0, r0, c1, r1, .. } => {
            let cdx = c1.x - c0.x;
            let cdy = c1.y - c0.y;
            let dr = r1 - r0;
            let pdx = x - c0.x;
            let pdy = y - c0.y;
            let a = cdx * cdx + cdy * cdy - dr * dr;
            let b = -2.0 * (pdx * cdx + pdy * cdy + r0 * dr);
            let c = pdx * pdx + pdy * pdy - r0 * r0;
            if a.abs() < 1e-9 {
                if b.abs() < 1e-12 {
                    return None;
                }
                let t0 = -c / b;
                return if r0 + t0 * dr >= 0.0 { Some(t0) } else { None };
            }
            let disc = b * b - 4.0 * a * c;
            if disc < 0.0 {
                return None;
            }
            let s = disc.sqrt();
            let roots = [(-b + s) / (2.0 * a), (-b - s) / (2.0 * a)];
            for t in roots {
                if r0 + t * dr >= 0.0 {
                    return Some(t);
                }
            }
            None
        }
        _ => panic!("radial_t: not a radial gradient"),
    }
}

/// The angle from the conic gradient's center to `(x, y)`, as a fraction
/// of a full turn starting at `angle0`, wrapped once around into `[0, 1)`.
pub fn conic_t(g: &Paint, x: f64, y: f64) -> f64 {
    match g {
        Paint::Conic { center, angle0, .. } => {
            let a = (y - center.y).atan2(x - center.x) - angle0;
            let t = a / (2.0 * std::f64::consts::PI);
            t - t.floor()
        }
        _ => panic!("conic_t: not a conic gradient"),
    }
}

/// The colour a paint hands back at `(x, y)`. A solid paint ignores the
/// point. Each gradient projects the point to a parameter, folds it back
/// into range with its extend mode, and looks it up in its stop table --
/// except a focal radial's unreachable cone, which has no parameter at
/// all and takes the last stop's colour instead of a black hole.
pub fn paint_at(g: &Paint, x: f64, y: f64) -> Color {
    match g {
        Paint::Solid(c) => *c,
        Paint::Linear { stops, extend: ext, .. } => sample_stops(stops, extend(linear_t(g, x, y), ext)),
        Paint::Radial { stops, extend: ext, .. } => match radial_t(g, x, y) {
            Some(t) => sample_stops(stops, extend(t, ext)),
            None => sample_stops(stops, 1.0),
        },
        Paint::Conic { stops, extend: ext, .. } => sample_stops(stops, extend(conic_t(g, x, y), ext)),
        Paint::Image { img, inv, filter, extend: ext } => {
            let src = *inv * point(x, y);
            let p = match filter.as_str() {
                "nearest" => nearest_at(img, src.x, src.y, ext),
                "bilinear" => bilinear_at(img, src.x, src.y, ext),
                "bicubic" => bicubic_at(img, src.x, src.y, ext),
                other => panic!("unknown filter: {other}"),
            };
            pixel_color(p)
        }
    }
}

/// `paint_through`, with the colour replaced by a function: samples
/// `paint_at` at each pixel's center and blends that colour in through
/// the coverage, in linear light. A solid paint makes this exactly
/// `paint_through`.
pub fn paint_fill(c: &mut Canvas, cov: &CoverageBuffer, paint: &Paint) {
    let width = c.width.min(cov.width);
    let height = c.height.min(cov.height);
    for y in 0..height as i64 {
        for x in 0..width as i64 {
            let coverage = coverage_at(cov, x, y);
            let old = pixel_at(c, x, y);
            let col = paint_at(paint, x as f64 + 0.5, y as f64 + 0.5);
            write_pixel(c, x, y, mix_with(old, col, coverage, true));
        }
    }
}

// ---------------------------------------------------------------------
// § 10.5 Eight bits isn't enough: ordered dithering
// ---------------------------------------------------------------------

/// `channel_to_byte`, exposed under the chapter's own name: clamp,
/// encode, scale to 255, round to nearest.
pub fn to_byte(light: f64) -> i64 {
    channel_to_byte(light)
}

/// The 4x4 Bayer matrix: `BAYER4[y][x]` is the dither order at that cell,
/// 0 to 15.
pub const BAYER4: [[i64; 4]; 4] =
    [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];

/// The nudge ordered dithering adds before rounding down, in `[0, 1)`:
/// the Bayer matrix entry for `(x, y)`'s position in the tile, over 16.
pub fn dither_threshold(x: i64, y: i64) -> f64 {
    let xi = x.rem_euclid(4) as usize;
    let yi = y.rem_euclid(4) as usize;
    BAYER4[yi][xi] as f64 / 16.0
}

/// `to_byte`, with the Bayer threshold for `(x, y)` added before the
/// floor instead of `0.5` added before it -- so a value that sits, say,
/// 0.3 of the way between two bytes rounds up in 30% of a tile's
/// positions and down in the rest, instead of snapping to one byte
/// everywhere.
pub fn to_byte_dithered(light: f64, x: i64, y: i64) -> i64 {
    let clamped = light.clamp(0.0, 1.0);
    (encode(clamped) * 255.0 + dither_threshold(x, y)).floor() as i64
}

/// `canvas_to_p6`, dithered: same header, same channel order, each byte
/// through `to_byte_dithered` at its own pixel's position instead of
/// `channel_to_byte`.
pub fn canvas_to_p6_dithered(c: &Canvas) -> Vec<u8> {
    let mut out = Vec::with_capacity(11 + c.width * c.height * 3);
    out.extend_from_slice(format!("P6\n{} {}\n255\n", c.width, c.height).as_bytes());
    for y in 0..c.height {
        for x in 0..c.width {
            let col = pixel_at(c, x as i64, y as i64);
            for value in [col.red, col.green, col.blue] {
                out.push(to_byte_dithered(value, x as i64, y as i64) as u8);
            }
        }
    }
    out
}

// ---------------------------------------------------------------------
// § 10.6 Putting it together
// ---------------------------------------------------------------------

const CH10_PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };

/// A sunset: dark purple, warm red, bright orange, pale cream.
fn sunset_stops() -> Vec<Stop> {
    vec![
        stop(0.0, color(0.05, 0.02, 0.15)),
        stop(0.35, color(0.75, 0.15, 0.25)),
        stop(0.7, color(0.98, 0.6, 0.15)),
        stop(1.0, color(1.0, 0.95, 0.75)),
    ]
}

/// One stop table, addressed three ways: a linear ramp across the
/// diagonal, a focal radial with its highlight up and to the left, and a
/// conic sweep -- three 150x150 panels, left to right, on paper.
pub fn three_gradients() -> Canvas {
    let p = 150usize;
    let gap = 4usize;
    let w = p * 3 + gap * 2;
    let h = p;
    let mut c = canvas(w, h);
    fill(&mut c, CH10_PAPER);

    let stops = sunset_stops();
    let paints = [
        linear_gradient(point(10.0, 10.0), point(140.0, 140.0), stops.clone(), "pad"),
        radial_gradient(point(55.0, 55.0), 0.0, point(75.0, 75.0), 85.0, stops.clone(), "pad"),
        conic_gradient(point(75.0, 75.0), -std::f64::consts::PI / 2.0, stops, "pad"),
    ];

    for (i, paint) in paints.iter().enumerate() {
        let ox = i * (p + gap);
        for y in 0..p {
            for x in 0..p {
                let col = paint_at(paint, x as f64 + 0.5, y as f64 + 0.5);
                write_pixel(&mut c, (ox + x) as i64, y as i64, col);
            }
        }
    }
    c
}

/// Plate 10: the three gradients, unmagnified -- the picture is the
/// point, not the pixels.
pub fn plate_10() -> Canvas {
    three_gradients()
}

/// One short gradient (blue to orange) under the three extend modes,
/// stacked in three 30-pixel-tall bands on a 180x90 canvas, magnified by
/// 2. The axis (60 to 100) is only the middle third of the strip, so pad,
/// repeat and reflect all have room on both sides to show what they do.
pub fn extend_strip() -> Canvas {
    let w = 180usize;
    let h = 90usize;
    let stops = vec![stop(0.0, color(0.1, 0.15, 0.5)), stop(1.0, color(1.0, 0.7, 0.1))];
    let modes = ["pad", "repeat", "reflect"];

    let mut c = canvas(w, h);
    for (r, mode) in modes.iter().enumerate() {
        let g = linear_gradient(point(60.0, 0.0), point(100.0, 0.0), stops.clone(), mode);
        for y in (r * 30)..(r * 30 + 30) {
            for x in 0..w {
                let col = paint_at(&g, x as f64 + 0.5, y as f64 + 0.5);
                write_pixel(&mut c, x as i64, y as i64, col);
            }
        }
    }
    magnify(&c, 2)
}

// =======================================================================
// Chapter 11: Images and Resampling
// =======================================================================

// ---------------------------------------------------------------------
// § 11.1 An image is a grid of pixels
// ---------------------------------------------------------------------

/// A grid of premultiplied linear-light pixels -- chapter 9's
/// representation, because every sampler below is a weighted average and
/// only premultiplied colour averages correctly.
#[derive(Debug, Clone)]
pub struct Image {
    pub width: usize,
    pub height: usize,
    pub px: Vec<Pixel>,
}

pub fn image(width: usize, height: usize, px: Vec<Pixel>) -> Image {
    Image { width, height, px }
}

/// Chapter 1's PPM writer, run backwards: parses the header (P3 or P6,
/// same as `ppm_pixel`), decodes each byte from sRGB back to linear
/// light, and stores an opaque premultiplied pixel -- a photo saved in
/// chapter 2 comes back in the space the renderer works in.
pub fn read_image<T: AsRef<[u8]>>(ppm: T) -> Image {
    let (width, height, values) = ppm_dims_and_values(ppm.as_ref());
    let mut px = Vec::with_capacity(width * height);
    for chunk in values.chunks(3) {
        let r = decode(chunk[0] as f64 / 255.0);
        let g = decode(chunk[1] as f64 / 255.0);
        let b = decode(chunk[2] as f64 / 255.0);
        px.push(opaque(color(r, g, b)));
    }
    Image { width, height, px }
}

/// Folds a texel index that fell outside `[0, n)` back in: `"clamp"`
/// holds the edge, `"repeat"` wraps, `"reflect"` bounces so the tile
/// meets itself without a seam. Same three modes as a gradient's extend,
/// one dimension up.
fn wrap_index(i: i64, n: i64, extend: &str) -> i64 {
    if i >= 0 && i < n {
        return i;
    }
    match extend {
        "clamp" => {
            if i < 0 {
                0
            } else {
                n - 1
            }
        }
        "repeat" => {
            let m = i % n;
            if m < 0 {
                m + n
            } else {
                m
            }
        }
        "reflect" => {
            let p = 2 * n;
            let i = ((i % p) + p) % p;
            if i < n {
                i
            } else {
                p - 1 - i
            }
        }
        other => panic!("unknown extend mode: {other}"),
    }
}

/// The pixel at integer texel `(ix, iy)`, with an index outside the image
/// folded back in by `extend`.
pub fn image_texel(img: &Image, ix: i64, iy: i64, extend: &str) -> Pixel {
    let x = wrap_index(ix, img.width as i64, extend);
    let y = wrap_index(iy, img.height as i64, extend);
    img.px[y as usize * img.width + x as usize]
}

// ---------------------------------------------------------------------
// § 11.2 Sampling, and the half-pixel offset
// ---------------------------------------------------------------------

/// Nearest takes the texel the point falls in -- no half-pixel offset,
/// because there's no blending to get wrong: the answer is just
/// `floor(sx), floor(sy)`.
fn nearest_at(img: &Image, sx: f64, sy: f64, extend: &str) -> Pixel {
    image_texel(img, sx.floor() as i64, sy.floor() as i64, extend)
}

pub fn sample_nearest(img: &Image, sx: f64, sy: f64) -> Pixel {
    nearest_at(img, sx, sy, "clamp")
}

/// Bilinear blends the four texels around the point by distance. The
/// trap: a texel's centre is at `tx + 0.5`, not `tx`, so the source
/// coordinate is shifted back by half a pixel first -- texel-centre
/// space -- and only then split into an integer texel and a fractional
/// blend.
fn bilinear_at(img: &Image, sx: f64, sy: f64, extend: &str) -> Pixel {
    let gx = sx - 0.5;
    let gy = sy - 0.5;
    let x0 = gx.floor() as i64;
    let y0 = gy.floor() as i64;
    let fx = gx - x0 as f64;
    let fy = gy - y0 as f64;
    let top = lerp_pixel(image_texel(img, x0, y0, extend), image_texel(img, x0 + 1, y0, extend), fx);
    let bot =
        lerp_pixel(image_texel(img, x0, y0 + 1, extend), image_texel(img, x0 + 1, y0 + 1, extend), fx);
    lerp_pixel(top, bot, fy)
}

pub fn sample_bilinear(img: &Image, sx: f64, sy: f64) -> Pixel {
    bilinear_at(img, sx, sy, "clamp")
}

/// The Catmull-Rom weights for the four texels centred on a fractional
/// position `t` in `[0, 1)`: they sum to one and, at `t = 0`, pick out
/// the second texel exactly (weight 1, the rest 0) -- the curve passes
/// through its samples.
pub fn catmull(t: f64) -> [f64; 4] {
    let t2 = t * t;
    let t3 = t2 * t;
    [
        -0.5 * t3 + t2 - 0.5 * t,
        1.5 * t3 - 2.5 * t2 + 1.0,
        -1.5 * t3 + 2.0 * t2 + 0.5 * t,
        0.5 * t3 - 0.5 * t2,
    ]
}

/// Bicubic fits a little curve through sixteen texels with Catmull-Rom
/// weights, sharper than bilinear -- same texel-centre shift as bilinear,
/// then a weighted sum over a 4x4 neighbourhood instead of a 2x2 one.
fn bicubic_at(img: &Image, sx: f64, sy: f64, extend: &str) -> Pixel {
    let gx = sx - 0.5;
    let gy = sy - 0.5;
    let x0 = gx.floor() as i64;
    let y0 = gy.floor() as i64;
    let wx = catmull(gx - x0 as f64);
    let wy = catmull(gy - y0 as f64);
    let mut r = 0.0;
    let mut g = 0.0;
    let mut b = 0.0;
    let mut a = 0.0;
    for j in 0..4i64 {
        for i in 0..4i64 {
            let p = image_texel(img, x0 - 1 + i, y0 - 1 + j, extend);
            let w = wx[i as usize] * wy[j as usize];
            r += w * p.r;
            g += w * p.g;
            b += w * p.b;
            a += w * p.a;
        }
    }
    pixel(r, g, b, a)
}

pub fn sample_bicubic(img: &Image, sx: f64, sy: f64) -> Pixel {
    bicubic_at(img, sx, sy, "clamp")
}

// ---------------------------------------------------------------------
// § 11.3 The image as a paint, and which way you walk
// ---------------------------------------------------------------------

/// A paint that samples `img`, placed on the canvas by `m`: at device
/// `(x, y)`, walk backward through the inverse of `m` to the point in the
/// image to sample, so every output pixel is filled exactly once no
/// matter how `m` magnifies or rotates.
pub fn image_paint(img: Image, m: Matrix3, filter: &str, extend: &str) -> Paint {
    Paint::Image { img, inv: inverse(m), filter: filter.to_string(), extend: extend.to_string() }
}

// ---------------------------------------------------------------------
// § 11.4 Making it smaller is a different problem
// ---------------------------------------------------------------------

/// Halves the image: each output texel the box average of the 2x2 block
/// above it. Premultiplied channels average alongside alpha, the same
/// reason chapter 9 premultiplied in the first place.
pub fn downsample(img: &Image) -> Image {
    let nw = (img.width + 1) / 2;
    let nh = (img.height + 1) / 2;
    let mut px = Vec::with_capacity(nw * nh);
    for oy in 0..nh as i64 {
        for ox in 0..nw as i64 {
            let a = image_texel(img, ox * 2, oy * 2, "clamp");
            let b = image_texel(img, ox * 2 + 1, oy * 2, "clamp");
            let c = image_texel(img, ox * 2, oy * 2 + 1, "clamp");
            let d = image_texel(img, ox * 2 + 1, oy * 2 + 1, "clamp");
            px.push(pixel(
                (a.r + b.r + c.r + d.r) / 4.0,
                (a.g + b.g + c.g + d.g) / 4.0,
                (a.b + b.b + c.b + d.b) / 4.0,
                (a.a + b.a + c.a + d.a) / 4.0,
            ));
        }
    }
    Image { width: nw, height: nh, px }
}

/// The mip pyramid: `img` itself, then `downsample` repeated down to a
/// single pixel.
pub fn mip_chain(img: &Image) -> Vec<Image> {
    let mut chain = vec![img.clone()];
    while chain.last().unwrap().width > 1 || chain.last().unwrap().height > 1 {
        let next = downsample(chain.last().unwrap());
        chain.push(next);
    }
    chain
}

/// The mip level whose texels are about the size of an output pixel: the
/// number of halvings implied by how much `scale` shrinks the image. A
/// scale of 1 or more -- no shrinking, or outright magnifying -- is level
/// 0.
pub fn mip_level_for(scale: f64) -> usize {
    if scale >= 1.0 {
        return 0;
    }
    (-scale.log2()).floor().max(0.0) as usize
}

// ---------------------------------------------------------------------
// § 11.5 Putting it together
// ---------------------------------------------------------------------

/// The 8x8 sprite: four inks (black, blue, orange, white) laid out as a
/// tiny fox-like face, built as a canvas, written to a PPM and read
/// straight back so the round trip through chapter 1's encode/decode is
/// real.
pub fn sprite() -> Image {
    let o = color(0.95, 0.55, 0.1);
    let b = color(0.15, 0.45, 0.85);
    let w = color(0.95, 0.93, 0.85);
    let k = color(0.06, 0.06, 0.08);
    let grid = [
        k, k, b, b, b, b, k, k, //
        k, b, b, b, b, b, b, k, //
        b, b, w, b, b, w, b, b, //
        b, b, w, b, b, w, b, b, //
        b, b, b, b, b, b, b, b, //
        o, b, b, o, o, b, b, o, //
        k, o, o, b, b, o, o, k, //
        k, k, o, o, o, o, k, k, //
    ];
    let mut c = canvas(8, 8);
    for y in 0..8i64 {
        for x in 0..8i64 {
            write_pixel(&mut c, x, y, grid[(y * 8 + x) as usize]);
        }
    }
    read_image(canvas_to_p6(&c))
}

/// `img`, magnified `k` times through `filter`, clamped at the edges.
fn magnified(img: &Image, k: usize, filter: &str) -> Canvas {
    let w = img.width * k;
    let h = img.height * k;
    let paint = image_paint(img.clone(), scaling(k as f64, k as f64), filter, "clamp");
    let mut c = canvas(w, h);
    for y in 0..h as i64 {
        for x in 0..w as i64 {
            let col = paint_at(&paint, x as f64 + 0.5, y as f64 + 0.5);
            write_pixel(&mut c, x, y, col);
        }
    }
    c
}

/// The sprite magnified 20x, nearest on the left and bilinear on the
/// right.
pub fn two_filters() -> Canvas {
    let s = sprite();
    side_by_side(&magnified(&s, 20, "nearest"), &magnified(&s, 20, "bilinear"))
}

/// Plate 11: `two_filters`, unmagnified further -- the picture is the
/// point.
pub fn plate_11() -> Canvas {
    two_filters()
}

/// The sprite magnified 16x, nearest, bilinear and bicubic side by side.
pub fn three_filters() -> Canvas {
    let s = sprite();
    side_by_side(&side_by_side(&magnified(&s, 16, "nearest"), &magnified(&s, 16, "bilinear")), &magnified(&s, 16, "bicubic"))
}

// =======================================================================
// Chapter 12: Clipping, Masks and Groups
// =======================================================================

// ---------------------------------------------------------------------
// § 12.1 A clip is a coverage buffer
// ---------------------------------------------------------------------

/// Two coverage buffers, multiplied cell by cell: the whole of clipping.
pub fn multiply_coverage(a: &CoverageBuffer, b: &CoverageBuffer) -> CoverageBuffer {
    let width = a.width.min(b.width);
    let height = a.height.min(b.height);
    let mut out = coverage_buffer(width, height);
    for y in 0..height as i64 {
        for x in 0..width as i64 {
            set_coverage(&mut out, x, y, coverage_at(a, x, y) * coverage_at(b, x, y));
        }
    }
    out
}

/// Coverage 1 everywhere: clipping to this is a no-op, since multiplying
/// by it changes nothing.
pub fn full_clip(width: usize, height: usize) -> CoverageBuffer {
    let mut cov = coverage_buffer(width, height);
    for y in 0..height as i64 {
        for x in 0..width as i64 {
            set_coverage(&mut cov, x, y, 1.0);
        }
    }
    cov
}

/// A rectangular clip, built as an ordinary fill of a four-cornered path.
pub fn clip_rect(x0: f64, y0: f64, x1: f64, y1: f64, width: usize, height: usize) -> CoverageBuffer {
    let r = polygon(&[point(x0, y0), point(x1, y0), point(x1, y1), point(x0, y1)]);
    fill_path(&r, "nonzero", width, height)
}

/// A clip built from any path, the same fill that draws it.
pub fn clip_path(p: &Path, rule: &str, width: usize, height: usize) -> CoverageBuffer {
    fill_path(p, rule, width, height)
}

// ---------------------------------------------------------------------
// § 12.2 Soft masks
// ---------------------------------------------------------------------

/// A radial falloff: coverage 1 at `(cx, cy)`, dropping off linearly with
/// distance to 0 at radius `r`. Multiplying a shape by this fades its
/// edge into the background instead of cutting it hard -- the same
/// multiplication as a clip, with softer numbers.
pub fn soft_mask(cx: f64, cy: f64, r: f64, width: usize, height: usize) -> CoverageBuffer {
    let mut cov = coverage_buffer(width, height);
    for y in 0..height as i64 {
        for x in 0..width as i64 {
            let px = x as f64 + 0.5;
            let py = y as f64 + 0.5;
            let d = ((px - cx).powi(2) + (py - cy).powi(2)).sqrt();
            set_coverage(&mut cov, x, y, (1.0 - d / r).clamp(0.0, 1.0));
        }
    }
    cov
}

// ---------------------------------------------------------------------
// § 12.3 Groups, and the opacity that isn't what you think
// ---------------------------------------------------------------------

/// The pixel at `(x, y)` of a layer -- chapter 9's `Layer`, given the
/// same kind of accessor `Canvas` has had since chapter 1.
pub fn layer_pixel(l: &Layer, x: i64, y: i64) -> Pixel {
    l.pixels[y as usize * l.width + x as usize]
}

/// Writes one pixel of a layer directly, for building small layers by
/// hand in tests.
pub fn set_layer_pixel(l: &mut Layer, x: i64, y: i64, p: Pixel) {
    let idx = y as usize * l.width + x as usize;
    l.pixels[idx] = p;
}

/// A fresh transparent layer to draw a group's children into -- chapter
/// 9's premultiplied buffer, under this chapter's name for it.
pub fn push_group(width: usize, height: usize) -> Layer {
    layer(width, height)
}

/// Draws one child into `l` through its coverage and opacity, source-over
/// the layer's existing content, and returns the result as a new layer --
/// draw the whole stack of children this way and overlaps inside the
/// group composite exactly the way they would straight onto the canvas.
pub fn paint_into(l: &Layer, cov: &CoverageBuffer, col: Color, alpha: f64) -> Layer {
    let mut out = layer(l.width, l.height);
    for y in 0..l.height as i64 {
        for x in 0..l.width as i64 {
            let idx = y as usize * l.width + x as usize;
            let k = coverage_at(cov, x, y) * alpha;
            let src = if k > 0.0 { from_color(col, k) } else { CLEAR };
            out.pixels[idx] = over(src, l.pixels[idx]);
        }
    }
    out
}

/// Every premultiplied channel of `l`, scaled by `opacity` together --
/// colour and alpha alike, so a fully transparent pixel stays fully
/// transparent and an opaque one becomes exactly `opacity` opaque.
pub fn scale_opacity(l: &Layer, opacity: f64) -> Layer {
    let mut out = layer(l.width, l.height);
    for i in 0..l.pixels.len() {
        let p = l.pixels[i];
        out.pixels[i] = pixel(p.r * opacity, p.g * opacity, p.b * opacity, p.a * opacity);
    }
    out
}

/// Flattens a group at one opacity: scale its whole premultiplied buffer
/// by `opacity`, then composite that flattened result over `base` once.
/// The group's own overlaps are already resolved before the opacity is
/// applied, which is exactly why this differs from fading each child by
/// the same amount -- at `opacity = 1` this is pixel-identical to
/// drawing the children straight onto `base`.
pub fn pop_group_with_opacity(group: &Layer, base: &Layer, opacity: f64) -> Layer {
    let faded = scale_opacity(group, opacity);
    composite_layers("src-over", &faded, base)
}

// ---------------------------------------------------------------------
// § 12.4 Putting it together
// ---------------------------------------------------------------------

const PLATE12_PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };

/// Three overlapping circles and the ink each is painted in -- shared by
/// `per_child` and `group_opacity` so both draw exactly the same shapes.
fn three_circles() -> [(Path, Color); 3] {
    [
        (circle_path(60.0, 62.0, 34.0, 64), color(0.95, 0.55, 0.1)),
        (circle_path(90.0, 62.0, 34.0, 64), color(0.2, 0.55, 0.85)),
        (circle_path(75.0, 92.0, 34.0, 64), color(0.85, 0.25, 0.3)),
    ]
}

fn opaque_paper(width: usize, height: usize) -> Layer {
    let mut l = layer(width, height);
    for p in l.pixels.iter_mut() {
        *p = opaque(PLATE12_PAPER);
    }
    l
}

/// Left half of the plate: each circle painted at 50% opacity in turn, so
/// the overlaps composite twice and go dark.
pub fn per_child() -> Layer {
    let mut base = opaque_paper(150, 150);
    for (p, col) in three_circles() {
        let cov = fill_path(&p, "nonzero", 150, 150);
        base = paint_into(&base, &cov, col, 0.5);
    }
    base
}

/// Right half: the three circles drawn opaque into a group, then the
/// whole group composited at 50% once -- the overlaps match the rest.
pub fn group_opacity() -> Layer {
    let base = opaque_paper(150, 150);
    let mut group = push_group(150, 150);
    for (p, col) in three_circles() {
        let cov = fill_path(&p, "nonzero", 150, 150);
        group = paint_into(&group, &cov, col, 1.0);
    }
    pop_group_with_opacity(&group, &base, 0.5)
}

/// Both layers here end up fully opaque, so which background
/// `flatten_layer` composites against doesn't matter -- `over` against an
/// opaque source ignores the destination entirely.
fn layer_to_canvas(l: &Layer) -> Canvas {
    flatten_layer(l, PLATE12_PAPER)
}

/// The plate: `per_child` and `group_opacity`, side by side.
pub fn opacity_plate() -> Canvas {
    side_by_side(&layer_to_canvas(&per_child()), &layer_to_canvas(&group_opacity()))
}

/// Plate 12: `opacity_plate`, magnified by 2.
pub fn plate_12() -> Canvas {
    magnify(&opacity_plate(), 2)
}

/// The clip demo: chapter 5's star, recentred on a 150x150 panel, clipped
/// two ways -- a hard circle on the left, a soft radial mask on the
/// right, both sharing the star's own centre.
pub fn clip_demo() -> Canvas {
    let ink = color(0.95, 0.55, 0.1);
    let bg = color(0.02, 0.02, 0.025);
    let star_shape = transform_path(&unit_star(), translation(75.0, 75.0) * scaling(60.0, 60.0));
    let star_cov = fill_path(&star_shape, "nonzero", 150, 150);

    let hard = multiply_coverage(&star_cov, &clip_path(&circle_path(75.0, 75.0, 45.0, 64), "nonzero", 150, 150));
    let mut left = canvas(150, 150);
    fill(&mut left, bg);
    paint_through(&mut left, &hard, ink);

    let soft = multiply_coverage(&star_cov, &soft_mask(75.0, 75.0, 70.0, 150, 150));
    let mut right = canvas(150, 150);
    fill(&mut right, bg);
    paint_through(&mut right, &soft, ink);

    side_by_side(&left, &right)
}
