//! Chapter 1: The Canvas and the Color.
//!
//! A tiny renderer: colors are three floating point numbers that measure
//! light (0.0 = none, 1.0 = full), a canvas is a rectangle of colors, and
//! the PPM writer is the only place that knows about the sRGB transfer
//! function that turns light into the numbers an image file expects.

use std::cell::Cell;
use std::collections::BTreeSet;
use std::collections::HashMap;
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

/// Round to the nearest whole number, ties up (`floor(x + 0.5)`): a half
/// rounds toward positive infinity, not away from zero, which only
/// differs from Rust's own `f64::round` on a negative half. No scenario in
/// this chapter lands on a half -- chapter 14's outline coordinates are
/// the ones that do, and pin `round(-17.5) = -17`, not -18.
pub fn round(x: f64) -> i64 {
    (x + 0.5).floor() as i64
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
    write_pixel(c, x, y, mix_with(old, col, weight, true));
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
///
/// `PartialEq` compares exactly, component by component -- fine (and
/// needed) for chapter 22's grid points, which are always whole numbers;
/// everywhere else, use `tuples_eq` for the book's usual tolerance.
#[derive(Debug, Clone, Copy, PartialEq)]
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
    determinant(m) != 0.0
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
    add_cell_to(acc, x, row, area, cover);
}

/// Where deposits go. Chapter 7's `Accumulator` is one (a dense grid);
/// chapter 21's tiled fill keeps a sparse map of only the cells that were
/// deposited into. The folding and dropping rules live in `add_cell_to`,
/// once, so both stores see bit-for-bit the same deposits.
pub(crate) trait CellSink {
    fn sink_width(&self) -> usize;
    fn sink_height(&self) -> usize;
    fn put(&mut self, x: usize, row: usize, area: f64, cover: f64);
}

impl CellSink for Accumulator {
    fn sink_width(&self) -> usize {
        self.width
    }
    fn sink_height(&self) -> usize {
        self.height
    }
    fn put(&mut self, x: usize, row: usize, area: f64, cover: f64) {
        let idx = row * self.width + x;
        self.area[idx] += area;
        self.cover[idx] += cover;
    }
}

pub(crate) fn add_cell_to<S: CellSink>(acc: &mut S, x: i64, row: i64, area: f64, cover: f64) {
    let (mut x, mut area) = (x, area);
    if x < 0 {
        x = 0;
        area = cover;
    }
    if x >= acc.sink_width() as i64 {
        return;
    }
    acc.put(x as usize, row as usize, area, cover);
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
    accumulate_row_to(acc, row, x0, x1, height);
}

pub(crate) fn accumulate_row_to<S: CellSink>(acc: &mut S, row: i64, x0: f64, x1: f64, height: f64) {
    let xa = x0.min(x1);
    let xb = x0.max(x1);
    let ca = xa.floor() as i64;
    let cb = xb.floor() as i64;
    if ca == cb {
        let xm = (xa + xb) / 2.0 - ca as f64;
        add_cell_to(acc, ca, row, height * (1.0 - xm), height);
        return;
    }
    let dx = xb - xa;
    for c in ca..=cb {
        let lo = xa.max(c as f64);
        let hi = xb.min(c as f64 + 1.0);
        let share = height * (hi - lo) / dx;
        let m = (lo + hi) / 2.0 - c as f64;
        add_cell_to(acc, c, row, share * (1.0 - m), share);
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
    accumulate_to(acc, a, b);
}

pub(crate) fn accumulate_to<S: CellSink>(acc: &mut S, a: Tuple, b: Tuple) {
    if a.y == b.y {
        return;
    }
    let sign = if a.y > b.y { 1.0 } else { -1.0 };
    let (top, bottom) = if a.y > b.y { (b, a) } else { (a, b) };
    let slope = (bottom.x - top.x) / (bottom.y - top.y);
    let first = (top.y.floor() as i64).max(0);
    let last = (bottom.y.ceil() as i64 - 1).min(acc.sink_height() as i64 - 1);
    let mut row = first;
    while row <= last {
        let y0 = top.y.max(row as f64);
        let y1 = bottom.y.min(row as f64 + 1.0);
        accumulate_row_to(
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
/// edge, of `a.x * b.y - b.x * a.y`. The sign tells you which way the
/// path winds: positive is clockwise on screen (the same sign convention
/// as `cross`), negative is counterclockwise. Chapter 13 relies on the
/// sign directly (every stroked piece must come out counterclockwise, so
/// negative), so this returns the signed value, not its absolute value --
/// callers from chapter 7 on that only want the area take `.abs()`
/// themselves, and every shape those callers use is already wound
/// clockwise, so the sign was always positive there anyway.
pub fn polygon_area(p: &Path) -> f64 {
    let mut area = 0.0;
    for (a, b) in edges(p) {
        area += a.x * b.y - b.x * a.y;
    }
    area / 2.0
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
    /// Chapter 20: any paint seen through a matrix (`transformed_paint`).
    Transformed { inner: Box<Paint>, inv: Matrix3 },
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
            let r1 = (-b + s) / (2.0 * a);
            let r2 = (-b - s) / (2.0 * a);
            // largest first, whatever the sign of a
            let roots = if r1 >= r2 { [r1, r2] } else { [r2, r1] };
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
        Paint::Transformed { inner, inv } => {
            let q = *inv * point(x, y);
            paint_at(inner, q.x, q.y)
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

// =======================================================================
// Chapter 13: Stroking is Filling
// =======================================================================

// ---------------------------------------------------------------------
// § 13.1-13.2 The pieces, and the stroker that assembles them
// ---------------------------------------------------------------------

/// The vector turned a quarter turn: `(x, y)` becomes `(-y, x)`.
fn perp(v: Tuple) -> Tuple {
    vector(-v.y, v.x)
}

/// The signed angle from `from` to `to`, wrapped to `(-pi, pi]` -- the
/// short way round, whichever direction that is.
fn ang_between(from: f64, to: f64) -> f64 {
    let two_pi = 2.0 * std::f64::consts::PI;
    let mut d = (to - from) % two_pi;
    if d > std::f64::consts::PI {
        d -= two_pi;
    }
    if d <= -std::f64::consts::PI {
        d += two_pi;
    }
    d
}

/// How many steps an arc from `a0` to `a1` needs, one every eighth of a
/// radian's sixteenth-turn (`pi/16`, 11.25 degrees), at least two.
fn arc_steps(a0: f64, a1: f64) -> usize {
    (((a1 - a0).abs() / (std::f64::consts::PI / 16.0) - 0.000000001).ceil() as usize).max(2)
}

/// Appends `steps + 1` points of the arc centred on `c`, radius `r`, from
/// angle `a0` to `a1` inclusive of both ends.
fn arc_into(pts: &mut Vec<Tuple>, c: Tuple, a0: f64, a1: f64, r: f64, steps: usize) {
    for k in 0..=steps {
        let a = a0 + (a1 - a0) * k as f64 / steps as f64;
        pts.push(point(c.x + r * a.cos(), c.y + r * a.sin()));
    }
}

/// The rectangle of half-width `h` centred on the segment `a..b`: the
/// ends offset by `h` along the segment's perpendicular, on both sides.
fn seg_rect(a: Tuple, b: Tuple, h: f64) -> Vec<Tuple> {
    let d = normalize(b - a);
    let n = perp(d);
    vec![a + n * h, b + n * h, b + n * -h, a + n * -h]
}

/// Where the line through `p1` along `d1` crosses the line through `p2`
/// along `d2`, or `None` if the two directions are parallel.
fn intersect_lines(p1: Tuple, d1: Tuple, p2: Tuple, d2: Tuple) -> Option<Tuple> {
    let den = cross(d1, d2);
    if den.abs() < 1e-12 {
        return None;
    }
    let t = cross(p2 - p1, d2) / den;
    Some(p1 + d1 * t)
}

/// `h / sin(theta / 2)`, where `theta` is the interior angle at a vertex
/// between the segment arriving along `d_in` and the one leaving along
/// `d_out` -- the distance a miter join's tip sits past the vertex. The
/// interior angle is the one between the *reversed* incoming direction
/// (vertex back to the previous point) and the outgoing one, so a
/// straight-through vertex (`d_in == d_out`) scores 180 degrees and a
/// dead-on reversal scores 0.
pub fn miter_length(d_in: Tuple, d_out: Tuple, h: f64) -> f64 {
    let neg_in = -d_in;
    let sin_theta = cross(neg_in, d_out).abs();
    let cos_theta = dot(neg_in, d_out);
    let theta = sin_theta.atan2(cos_theta);
    h / (theta / 2.0).sin()
}

/// The wedge that fills the outer gap at one interior vertex, or `None`
/// when the path doesn't actually turn there (`d_in` and `d_out`
/// parallel -- no gap to fill). `s` picks the outer side of the turn: the
/// side the offset normals point away from the turn's own curvature.
/// Bevel is the straight-across triangle; round is the arc between the
/// two offset points; miter extends both offset edges to their
/// intersection and falls back to bevel when that tip would land past
/// `miter_limit` half-widths from the vertex.
fn join_shape(v: Tuple, din: Tuple, dout: Tuple, h: f64, join: &str, miter_limit: f64) -> Option<Vec<Tuple>> {
    let turn = cross(din, dout);
    if turn.abs() < 1e-12 {
        return None;
    }
    let s = if turn > 0.0 { -1.0 } else { 1.0 };
    let nin = perp(din) * s;
    let nout = perp(dout) * s;
    let a = v + nin * h;
    let b = v + nout * h;
    match join {
        "bevel" => Some(vec![v, a, b]),
        "round" => {
            // The arc has to cross the outer gap the short way round: the
            // long way sweeps back across the inside of the turn and
            // leaves a notch where the gap should have been filled.
            let a0 = (a.y - v.y).atan2(a.x - v.x);
            let b0 = (b.y - v.y).atan2(b.x - v.x);
            let a1 = a0 + ang_between(a0, b0);
            let mut pts = vec![v];
            arc_into(&mut pts, v, a0, a1, h, arc_steps(a0, a1));
            Some(pts)
        }
        _ => {
            if let Some(m) = intersect_lines(a, din, b, dout) {
                if magnitude(m - v) <= miter_limit * h {
                    return Some(vec![v, a, m, b]);
                }
            }
            Some(vec![v, a, b])
        }
    }
}

/// The shape that closes one open end of a stroke, or `None` for a butt
/// cap (which closes nothing -- the segment rectangle's own flat end is
/// the whole story). `dout` points away from the path, out of the end.
fn cap_shape(p: Tuple, dout: Tuple, h: f64, cap: &str) -> Option<Vec<Tuple>> {
    let n = perp(dout);
    match cap {
        "square" => {
            let l = p + n * h;
            let r = p + n * -h;
            Some(vec![l, l + dout * h, r + dout * h, r])
        }
        "round" => {
            let a0 = n.y.atan2(n.x);
            let outw = dout.y.atan2(dout.x);
            let two_pi = 2.0 * std::f64::consts::PI;
            let mut d = ((outw - a0) % two_pi + two_pi) % two_pi;
            if d > std::f64::consts::PI {
                d -= two_pi;
            }
            let a1 = a0 + if d > 0.0 { std::f64::consts::PI } else { -std::f64::consts::PI };
            let mut pts = Vec::new();
            arc_into(&mut pts, p, a0, a1, h, arc_steps(a0, a1));
            Some(pts)
        }
        _ => None,
    }
}

/// Drops every point that's within `1e-9` of the one before it, so a
/// doubled point from a sloppy export never becomes a zero-length
/// segment. The first point always survives.
fn dedupe_points(points: &[Tuple]) -> Vec<Tuple> {
    let mut out = vec![points[0]];
    for &pt in &points[1..] {
        let last = *out.last().unwrap();
        if magnitude(pt - last) > 1e-9 {
            out.push(pt);
        }
    }
    out
}

/// Appends a new closed subpath through `pts` to `out` (empty `pts`
/// appends nothing): every piece a stroke emits -- rectangle, join,
/// cap, dot -- fills as its own little closed shape, and nonzero winding
/// merges the overlaps for free. Free on one condition: every piece has
/// to wind the same way, or a piece wound backwards cancels its neighbour
/// where they overlap instead of adding to it. So every piece is oriented
/// counterclockwise on screen before it's emitted -- `polygon_area`
/// negative -- and any piece that comes out clockwise (positive) has its
/// points reversed first.
fn push_closed_subpath(out: &mut Path, pts: &[Tuple]) {
    if pts.is_empty() {
        return;
    }
    let mut pts = pts.to_vec();
    if polygon_area(&polygon(&pts)) > 0.0 {
        pts.reverse();
    }
    move_to(out, pts[0]);
    for &pt in &pts[1..] {
        line_to(out, pt);
    }
    close(out);
}

/// Turns a stroked path into a fillable outline: one rectangle per
/// segment, one join wedge per interior vertex, one cap shape per open
/// end, all as subpaths of one path. There's no new rasterizer -- fill
/// the result nonzero (chapter 7's `fill_path`) and the overlaps on the
/// inside of every turn, wound twice, vanish into the fill.
///
/// Consecutive duplicate points are dropped before anything else, so a
/// doubled point never divides by zero building a segment's direction. A
/// subpath left with a single point is a dot: a filled disc of radius
/// `h` for a round cap, a square of side `width` for a square cap, and
/// nothing at all for a butt cap.
pub fn stroke_to_path(p: &Path, width: f64, cap: &str, join: &str, miter_limit: f64) -> Path {
    let h = width / 2.0;
    let mut out = path();
    for sp in subpaths(p) {
        if sp.points.is_empty() {
            continue;
        }
        let mut pts = dedupe_points(&sp.points);
        // A closed subpath that ends where it began (the reader wrote an
        // explicit line back to the start before calling `close`) has no
        // zero-length closing segment: `closed` already implies the edge
        // from the last point back to the first, so an explicit duplicate
        // of the first point at the end would otherwise become a second,
        // zero-length closing segment with an undefined direction.
        if sp.closed && pts.len() > 2 && magnitude(pts[pts.len() - 1] - pts[0]) <= 1e-9 {
            pts.pop();
        }
        if pts.len() < 2 {
            let c = pts[0];
            match cap {
                "round" => {
                    let mut d = Vec::new();
                    arc_into(&mut d, c, 0.0, 2.0 * std::f64::consts::PI, h, 48);
                    push_closed_subpath(&mut out, &d);
                }
                "square" => {
                    let sq = [
                        point(c.x - h, c.y - h),
                        point(c.x + h, c.y - h),
                        point(c.x + h, c.y + h),
                        point(c.x - h, c.y + h),
                    ];
                    push_closed_subpath(&mut out, &sq);
                }
                _ => {}
            }
            continue;
        }

        let closed = sp.closed;
        let n = pts.len();
        let mut segs: Vec<(Tuple, Tuple)> = Vec::with_capacity(n);
        for i in 0..n - 1 {
            segs.push((pts[i], pts[i + 1]));
        }
        if closed {
            segs.push((pts[n - 1], pts[0]));
        }
        for &(a, b) in &segs {
            push_closed_subpath(&mut out, &seg_rect(a, b, h));
        }

        let dirs: Vec<Tuple> = segs.iter().map(|&(a, b)| normalize(b - a)).collect();
        let nj = if closed { segs.len() } else { segs.len() - 1 };
        for k in 0..nj {
            let v = segs[(k + 1) % segs.len()].0;
            let din = dirs[k];
            let dout = dirs[(k + 1) % segs.len()];
            if let Some(j) = join_shape(v, din, dout, h, join, miter_limit) {
                push_closed_subpath(&mut out, &j);
            }
        }

        if !closed {
            if let Some(sc) = cap_shape(pts[0], -dirs[0], h, cap) {
                push_closed_subpath(&mut out, &sc);
            }
            if let Some(ec) = cap_shape(pts[n - 1], dirs[dirs.len() - 1], h, cap) {
                push_closed_subpath(&mut out, &ec);
            }
        }
    }
    out
}

// ---------------------------------------------------------------------
// § 13.5 Putting it together
// ---------------------------------------------------------------------

const CH13_PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };
const CH13_GRAY: Color = Color { red: 0.62, green: 0.62, blue: 0.66 };
const CH13_MAGENTA: Color = Color { red: 0.85, green: 0.2, blue: 0.55 };
const CH13_SIZE: usize = 160;

/// The plate's chevron: a V of three points, open (never closed).
pub fn chevron() -> Path {
    let mut p = path();
    move_to(&mut p, point(30.0, 40.0));
    line_to(&mut p, point(80.0, 120.0));
    line_to(&mut p, point(130.0, 40.0));
    p
}

/// Nine points on the upper half of a circle of radius 10 about
/// (50, 50), from 180 to 360 degrees in steps of 22.5 -- a tight hairpin
/// bend, open, used to check that a wide stroke around a sharp turn
/// overlaps itself solidly instead of winding into a hole.
pub fn u_turn() -> Path {
    let mut p = path();
    for k in 0..9 {
        let deg = 180.0 + k as f64 * 22.5;
        let a = deg * std::f64::consts::PI / 180.0;
        let q = point(50.0 + 10.0 * a.cos(), 50.0 + 10.0 * a.sin());
        if k == 0 {
            move_to(&mut p, q);
        } else {
            line_to(&mut p, q);
        }
    }
    p
}

/// A panel showing `outline`'s gray fill with its own edges traced over
/// it in magenta (chapter 3's `line_wu`, which wants integer endpoints,
/// so the outline's coordinates are rounded to the nearest pixel first,
/// halves up -- chapter 1's `round`, the same rule chapter 1's byte
/// conversion uses).
fn stroke_panel(width: usize, height: usize, outline: &Path) -> Canvas {
    let mut c = canvas(width, height);
    fill(&mut c, CH13_PAPER);
    let cov = fill_path(outline, "nonzero", width, height);
    paint_through(&mut c, &cov, CH13_GRAY);
    for (a, b) in edges(outline) {
        line_wu(
            &mut c,
            round(a.x),
            round(a.y),
            round(b.x),
            round(b.y),
            CH13_MAGENTA,
        );
    }
    c
}

fn blit_panel(out: &mut Canvas, panel: &Canvas, x0: i64, y0: i64) {
    for y in 0..panel.height as i64 {
        for x in 0..panel.width as i64 {
            write_pixel(out, x0 + x, y0 + y, pixel_at(panel, x, y));
        }
    }
}

/// A chevron stroked three ways -- miter, round, bevel -- each panel the
/// generated outline in magenta over the gray fill of it.
pub fn joins_plate() -> Canvas {
    let mut out = canvas(3 * CH13_SIZE, CH13_SIZE);
    for (i, join) in ["miter", "round", "bevel"].iter().enumerate() {
        let outline = stroke_to_path(&chevron(), 26.0, "butt", join, 4.0);
        let panel = stroke_panel(CH13_SIZE, CH13_SIZE, &outline);
        blit_panel(&mut out, &panel, i as i64 * CH13_SIZE as i64, 0);
    }
    out
}

/// Plate 13: `joins_plate`, magnified by 2.
pub fn plate_13() -> Canvas {
    magnify(&joins_plate(), 2)
}

/// One horizontal segment stroked with butt, round and square caps.
pub fn caps_demo() -> Canvas {
    let mut seg = path();
    move_to(&mut seg, point(45.0, 40.0));
    line_to(&mut seg, point(115.0, 40.0));

    let mut out = canvas(3 * CH13_SIZE, 80);
    for (i, cap) in ["butt", "round", "square"].iter().enumerate() {
        let outline = stroke_to_path(&seg, 30.0, cap, "miter", 4.0);
        let panel = stroke_panel(CH13_SIZE, 80, &outline);
        blit_panel(&mut out, &panel, i as i64 * CH13_SIZE as i64, 0);
    }
    out
}

// =======================================================================
// Chapter 14: Offsetting Curves
// =======================================================================

// ---------------------------------------------------------------------
// § 14.1 The offset point
// ---------------------------------------------------------------------

/// `t`, nudged a hair further into the curve (`+0.0001` unless that would
/// leave `[0, 1]`, in which case `-0.0001`) when the derivative vanishes
/// there -- a handle sitting exactly on its anchor still leaves in a
/// definite direction, just at zero speed, so a plain `derivative` can't
/// be normalized there.
fn live_t(c: &Curve, t: f64) -> f64 {
    if magnitude(derivative(c, t)) < 1e-9 {
        if t + 0.0001 <= 1.0 {
            t + 0.0001
        } else {
            t - 0.0001
        }
    } else {
        t
    }
}

/// The unit tangent at `t`.
pub fn tangent_at(c: &Curve, t: f64) -> Tuple {
    normalize(derivative(c, live_t(c, t)))
}

/// The tangent turned a quarter turn toward `+y` -- on the y-down canvas
/// that's the right-hand side of travel, the same side chapter 13's
/// rectangles offset by `+h`.
pub fn normal_at(c: &Curve, t: f64) -> Tuple {
    perp(tangent_at(c, t))
}

/// The point at `t`, stepped `d` along the normal. Positive `d` is the
/// right-hand side of travel; negative is the left.
pub fn offset_point(c: &Curve, t: f64, d: f64) -> Tuple {
    point_at(c, t) + normal_at(c, t) * d
}

// ---------------------------------------------------------------------
// § 14.2 Curvature, and where the offset stalls
// ---------------------------------------------------------------------

/// The Bezier of second differences: the derivative's own derivative, one
/// degree lower still. A quadratic's is the constant `2*(P0-2P1+P2)`; a
/// cubic's is the straight-line blend between the two second differences
/// of its four points. Built generically (repeat the degree-reduction a
/// second time) so it agrees with both closed forms without special
/// casing either.
pub fn second_derivative(c: &Curve, t: f64) -> Tuple {
    let n = (c.points.len() - 1) as f64;
    let d1: Vec<Tuple> = c.points.windows(2).map(|w| (w[1] - w[0]) * n).collect();
    if d1.len() < 2 {
        return vector(0.0, 0.0);
    }
    let n2 = (d1.len() - 1) as f64;
    let d2: Vec<Tuple> = d1.windows(2).map(|w| (w[1] - w[0]) * n2).collect();
    de_casteljau(&d2, t).0
}

/// `cross(v, a) / |v|^3`, `v` the derivative and `a` the second
/// derivative: signed the same way as `cross`, positive where the curve
/// turns clockwise on screen -- the same side positive `d` points to.
/// `1 / |curvature|` is the radius of the circle hugging the curve there.
pub fn curvature(c: &Curve, t: f64) -> f64 {
    let t = live_t(c, t);
    let v = derivative(c, t);
    let a = second_derivative(c, t);
    let s = magnitude(v);
    cross(v, a) / (s * s * s)
}

/// The parameters where `1 - curvature(c, t) * d` changes sign -- where
/// the offset at distance `d` stalls and turns back on itself. Sampled at
/// 64 evenly spaced parameters and bisected 40 times between any pair of
/// neighbours that disagree in sign.
pub fn cusps(c: &Curve, d: f64) -> Vec<f64> {
    let f = |t: f64| 1.0 - curvature(c, t) * d;
    let mut out = Vec::new();
    let mut prev = f(0.0);
    for i in 1..=64 {
        let t = i as f64 / 64.0;
        let cur = f(t);
        if (prev < 0.0) != (cur < 0.0) {
            let mut lo = (i as f64 - 1.0) / 64.0;
            let mut hi = t;
            let mut flo = prev;
            for _ in 0..40 {
                let mid = (lo + hi) / 2.0;
                let fm = f(mid);
                if (fm < 0.0) == (flo < 0.0) {
                    lo = mid;
                    flo = fm;
                } else {
                    hi = mid;
                }
            }
            out.push((lo + hi) / 2.0);
        }
        prev = cur;
    }
    out
}

// ---------------------------------------------------------------------
// § 14.3 Fitting one cubic, and admitting the miss
// ---------------------------------------------------------------------

/// One cubic through the offset's two endpoints, with the curve's own end
/// tangents, whose midpoint lands on the true offset point at `t = 0.5`.
/// The two handle lengths solve `a*T0 - b*T1 = R` by crossing each side
/// with the other tangent; parallel end tangents leave no unique answer,
/// so both handles fall back to a third of the chord.
pub fn fit_offset(c: &Curve, d: f64) -> Curve {
    let p0 = offset_point(c, 0.0, d);
    let p3 = offset_point(c, 1.0, d);
    let t0 = tangent_at(c, 0.0);
    let t1 = tangent_at(c, 1.0);
    let m = offset_point(c, 0.5, d);
    let r = (m * 8.0 - p0 * 4.0 - p3 * 4.0) / 3.0;
    let den = cross(t0, t1);
    let (a, b) = if den.abs() < 1e-9 {
        let v = magnitude(p3 - p0) / 3.0;
        (v, v)
    } else {
        (cross(r, t1) / den, cross(r, t0) / den)
    };
    cubic(p0, p0 + t0 * a, p3 - t1 * b, p3)
}

/// The largest miss between the fitted cubic and the true offset, over 17
/// matched parameters `t = i / 16`. Cheap, deterministic, and pessimistic
/// (the two curves don't run at the same speed), but a genuine bound.
pub fn offset_error(c: &Curve, d: f64, f: &Curve) -> f64 {
    let mut worst = 0.0;
    for i in 0..=16 {
        let t = i as f64 / 16.0;
        let miss = magnitude(point_at(f, t) - offset_point(c, t, d));
        worst = f64::max(worst, miss);
    }
    worst
}

/// The distance from `p` to the nearest point on `c`: the closest of 65
/// samples at `t = i / 64`, refined by 32 rounds of ternary search
/// between that sample's two neighbours. There's no closed form (it's a
/// quintic for a cubic), so this is sampling, honestly.
pub fn distance_to_curve(c: &Curve, p: Tuple) -> f64 {
    const N: usize = 64;
    let mut best_i = 0usize;
    let mut best_d = f64::INFINITY;
    for i in 0..=N {
        let t = i as f64 / N as f64;
        let d = magnitude(point_at(c, t) - p);
        if d < best_d {
            best_d = d;
            best_i = i;
        }
    }
    let mut lo = ((best_i as f64 - 1.0) / N as f64).max(0.0);
    let mut hi = ((best_i as f64 + 1.0) / N as f64).min(1.0);
    for _ in 0..32 {
        let m1 = lo + (hi - lo) / 3.0;
        let m2 = hi - (hi - lo) / 3.0;
        let d1 = magnitude(point_at(c, m1) - p);
        let d2 = magnitude(point_at(c, m2) - p);
        if d1 < d2 {
            hi = m2;
        } else {
            lo = m1;
        }
    }
    let t_best = (lo + hi) / 2.0;
    magnitude(point_at(c, t_best) - p)
}

// ---------------------------------------------------------------------
// § 14.4 The offset curve
// ---------------------------------------------------------------------

/// The piece of `c` between two parameters, by splitting twice: once at
/// `t0` to drop everything before it, once more at the rescaled `t1` to
/// drop everything after.
pub fn sub_curve(c: &Curve, t0: f64, t1: f64) -> Curve {
    let right = if t0 > 0.0 { split_at(c, t0).1 } else { c.clone() };
    if t1 < 1.0 {
        split_at(&right, (t1 - t0) / (1.0 - t0)).0
    } else {
        right
    }
}

fn offset_into(c: &Curve, d: f64, tolerance: f64, out: &mut Vec<Curve>, depth: u32) {
    let f = fit_offset(c, d);
    if offset_error(c, d, &f) <= tolerance || depth >= 16 {
        out.push(f);
        return;
    }
    let (left, right) = split_at(c, 0.5);
    offset_into(&left, d, tolerance, out, depth + 1);
    offset_into(&right, d, tolerance, out, depth + 1);
}

/// The offset of `c` at distance `d`, as a list of cubics in order,
/// chaining end to end from the first offset point to the last: split at
/// every cusp so no piece contains a flip, then fit each piece, halving
/// and re-fitting until `offset_error` is within `tolerance`, capped at
/// sixteen halvings.
pub fn offset_curve(c: &Curve, d: f64, tolerance: f64) -> Vec<Curve> {
    let mut ts = vec![0.0];
    for t in cusps(c, d) {
        if t - ts.last().unwrap() > 1e-9 && 1.0 - t > 1e-9 {
            ts.push(t);
        }
    }
    ts.push(1.0);
    let mut out = Vec::new();
    for w in ts.windows(2) {
        offset_into(&sub_curve(c, w[0], w[1]), d, tolerance, &mut out, 0);
    }
    out
}

/// The honest check on `offset_curve`'s result: how far 100 points spread
/// evenly along the assembled pieces stray from distance `|d|` to `c`.
/// Within tolerance on the outside of a bend; past the radius on the
/// inside, the offset folds back through itself and comes much closer
/// than `d` -- that's the fold, not an error in the fit.
pub fn offset_distance_error(c: &Curve, d: f64, tolerance: f64) -> f64 {
    let pieces = offset_curve(c, d, tolerance);
    if pieces.is_empty() {
        return 0.0;
    }
    let n = pieces.len() as f64;
    let mut worst: f64 = 0.0;
    for i in 0..100 {
        let u = i as f64 / 99.0 * n;
        let idx = (u.floor() as usize).min(pieces.len() - 1);
        let local_t = (u - idx as f64).min(1.0);
        let p = point_at(&pieces[idx], local_t);
        let miss = (distance_to_curve(c, p) - d.abs()).abs();
        worst = worst.max(miss);
    }
    worst
}

// ---------------------------------------------------------------------
// § 14.5 Stroking a curve: one outline
// ---------------------------------------------------------------------

/// Builds an open `Path` through `pts` with no closing segment -- the
/// input to chapter 13's stroker when what you have is a bare polyline,
/// not a `Path` already.
fn open_path_from_points(pts: &[Tuple]) -> Path {
    let mut p = path();
    if pts.is_empty() {
        return p;
    }
    move_to(&mut p, pts[0]);
    for &q in &pts[1..] {
        line_to(&mut p, q);
    }
    p
}

/// The stroke of a curve as one closed subpath: the offset at `+h`
/// flattened forward, the end cap's points, the offset at `-h` flattened
/// backward, the start cap's points, with consecutive duplicates dropped
/// (and the last point dropped too if it lands back on the first). Fill
/// it nonzero -- there's no new rasterizer, same as chapter 13.
pub fn stroke_curve_to_path(c: &Curve, width: f64, cap: &str, tolerance: f64) -> Path {
    let h = width / 2.0;
    let mut pts: Vec<Tuple> = Vec::new();

    for piece in offset_curve(c, h, tolerance) {
        pts.extend(flatten(&piece, tolerance));
    }
    if let Some(capped) = cap_shape(point_at(c, 1.0), tangent_at(c, 1.0), h, cap) {
        pts.extend(capped);
    }
    for piece in offset_curve(c, -h, tolerance).iter().rev() {
        let mut f = flatten(piece, tolerance);
        f.reverse();
        pts.extend(f);
    }
    let t0 = tangent_at(c, 0.0);
    if let Some(capped) = cap_shape(point_at(c, 0.0), -t0, h, cap) {
        pts.extend(capped);
    }

    let mut pts = dedupe_points(&pts);
    if pts.len() > 1 && magnitude(*pts.last().unwrap() - pts[0]) < 1e-9 {
        pts.pop();
    }

    let mut out = path();
    if !pts.is_empty() {
        move_to(&mut out, pts[0]);
        for &p in &pts[1..] {
            line_to(&mut out, p);
        }
        close(&mut out);
    }
    out
}

/// The way you were stroking curves until this morning: flatten at
/// `tolerance`, then chapter 13's stroker with round joins and a miter
/// limit of 4. Both pictures agree; only the point count gives it away.
pub fn flatten_then_stroke(c: &Curve, width: f64, cap: &str, tolerance: f64) -> Path {
    let pts = flatten(c, tolerance);
    let p = open_path_from_points(&pts);
    stroke_to_path(&p, width, cap, "round", 4.0)
}

/// The total number of points in a path, over every subpath.
pub fn point_count(p: &Path) -> usize {
    subpaths(p).iter().map(|sp| sp.points.len()).sum()
}

// ---------------------------------------------------------------------
// § 14.6 Putting it together
// ---------------------------------------------------------------------

/// A cubic bending back on itself with a tightest radius of about 8;
/// stroked 60 wide, its inner offset (at +30) folds into a loop.
pub fn hairpin() -> Curve {
    cubic(point(35.0, 140.0), point(65.0, -30.0), point(95.0, -30.0), point(125.0, 140.0))
}

/// The plate's arch: a cubic whose tightest radius is about 26.
pub fn arch() -> Curve {
    cubic(point(60.0, 250.0), point(130.0, 5.0), point(190.0, 5.0), point(260.0, 250.0))
}

/// The offset of `c` at `d`, as one flattened polyline: each piece of
/// `offset_curve` flattened and appended, dropping a piece's first point
/// when it repeats the point the previous piece just ended on.
fn offset_path_points(c: &Curve, d: f64, tolerance: f64) -> Vec<Tuple> {
    let mut pts: Vec<Tuple> = Vec::new();
    for piece in offset_curve(c, d, tolerance) {
        let mut f = flatten(&piece, tolerance);
        if let Some(&last) = pts.last() {
            if !f.is_empty() && f[0].x == last.x && f[0].y == last.y {
                f.remove(0);
            }
        }
        pts.extend(f);
    }
    pts
}

const CH14_WHITE: Color = Color { red: 0.9, green: 0.9, blue: 0.92 };
const CH14_COOL: [Color; 4] = [
    Color { red: 0.35, green: 0.8, blue: 0.9 },
    Color { red: 0.25, green: 0.6, blue: 0.9 },
    Color { red: 0.3, green: 0.4, blue: 0.85 },
    Color { red: 0.45, green: 0.3, blue: 0.8 },
];
const CH14_WARM: [Color; 4] = [
    Color { red: 0.95, green: 0.75, blue: 0.2 },
    Color { red: 0.95, green: 0.55, blue: 0.15 },
    Color { red: 0.9, green: 0.35, blue: 0.15 },
    Color { red: 0.8, green: 0.2, blue: 0.2 },
];

/// Strokes the open polyline `pts` hairline-thin with chapter 13's
/// stroker (butt caps, round joins) and paints the result through
/// `color`.
fn hairline(c: &mut Canvas, pts: &[Tuple], color: Color, width: f64) {
    if pts.len() < 2 {
        return;
    }
    let p = open_path_from_points(pts);
    let outline = stroke_to_path(&p, width, "butt", "round", 4.0);
    let cov = fill_path(&outline, "nonzero", c.width, c.height);
    paint_through(c, &cov, color);
}

/// A panel showing `outline`'s fill (under `rule`) in gray with its own
/// edges traced over it in magenta -- chapter 13's `stroke_panel`,
/// parameterized by fill rule for the fold demo.
fn outline_panel_rule(width: usize, height: usize, outline: &Path, rule: &str) -> Canvas {
    let mut c = canvas(width, height);
    fill(&mut c, CH13_PAPER);
    let cov = fill_path(outline, rule, width, height);
    paint_through(&mut c, &cov, CH13_GRAY);
    for (a, b) in edges(outline) {
        line_wu(
            &mut c,
            round(a.x),
            round(a.y),
            round(b.x),
            round(b.y),
            CH13_MAGENTA,
        );
    }
    c
}

/// The hairpin stroked two ways, side by side: chapter 13's stroker on
/// the flattened polyline (left), one outline from the offset curves
/// (right), each drawn in magenta over its gray fill.
pub fn two_strokes() -> Canvas {
    let left = flatten_then_stroke(&hairpin(), 60.0, "butt", 0.25);
    let right = stroke_curve_to_path(&hairpin(), 60.0, "butt", 0.25);
    let panel_l = stroke_panel(CH13_SIZE, CH13_SIZE, &left);
    let panel_r = stroke_panel(CH13_SIZE, CH13_SIZE, &right);
    let mut out = canvas(2 * CH13_SIZE, CH13_SIZE);
    blit_panel(&mut out, &panel_l, 0, 0);
    blit_panel(&mut out, &panel_r, CH13_SIZE as i64, 0);
    out
}

/// The offset-curve outline of the hairpin's stroke, filled nonzero
/// (left) and even-odd (right): the fold is ink on the left and a hole on
/// the right, exactly where the pen swept through the inside of the
/// bend.
pub fn fold_demo() -> Canvas {
    let o = stroke_curve_to_path(&hairpin(), 60.0, "butt", 0.25);
    let panel_nz = outline_panel_rule(CH13_SIZE, CH13_SIZE, &o, "nonzero");
    let panel_eo = outline_panel_rule(CH13_SIZE, CH13_SIZE, &o, "evenodd");
    let mut out = canvas(2 * CH13_SIZE, CH13_SIZE);
    blit_panel(&mut out, &panel_nz, 0, 0);
    blit_panel(&mut out, &panel_eo, CH13_SIZE as i64, 0);
    out
}

/// The whole chapter in one picture: the arch, its offsets at 15, 30, 45
/// and 60 on both sides (cool outside, warm on the inside where they
/// fold), the curve itself in white, and every cusp marked with a
/// magenta dot.
pub fn offsets_plate() -> Canvas {
    let w = 320usize;
    let h = 270usize;
    let mut c = canvas(w, h);
    fill(&mut c, CH13_PAPER);
    let curve = arch();
    let ds = [15.0, 30.0, 45.0, 60.0];

    for (k, &d) in ds.iter().enumerate() {
        let pts = offset_path_points(&curve, -d, 0.1);
        hairline(&mut c, &pts, CH14_COOL[k], 1.5);
    }
    for (k, &d) in ds.iter().enumerate() {
        let pts = offset_path_points(&curve, d, 0.1);
        hairline(&mut c, &pts, CH14_WARM[k], 1.5);
    }
    hairline(&mut c, &flatten(&curve, 0.1), CH14_WHITE, 2.0);

    for &d in &ds {
        for t in cusps(&curve, d) {
            let q = offset_point(&curve, t, d);
            let dot = circle_path(q.x, q.y, 2.5, 24);
            let cov = fill_path(&dot, "nonzero", w, h);
            paint_through(&mut c, &cov, CH13_MAGENTA);
        }
    }
    c
}

/// Plate 14: `offsets_plate`, magnified by 2.
pub fn plate_14() -> Canvas {
    magnify(&offsets_plate(), 2)
}

// =======================================================================
// Chapter 15: Dashes
// =======================================================================

// ---------------------------------------------------------------------
// § 15.1 How long is a curve
// ---------------------------------------------------------------------

/// The sum of a path's segments: every subpath's own segments, plus (for
/// a closed one) the segment from its last point back to its first. Unlike
/// `edges`, which treats every subpath as closed for filling's sake, an
/// open subpath here gets no closing segment.
pub fn path_length(p: &Path) -> f64 {
    let mut total = 0.0;
    for sp in subpaths(p) {
        let pts = &sp.points;
        if pts.len() < 2 {
            continue;
        }
        for w in pts.windows(2) {
            total += magnitude(w[1] - w[0]);
        }
        if sp.closed {
            total += magnitude(pts[0] - *pts.last().unwrap());
        }
    }
    total
}

/// `n + 1` running lengths of the polyline through `point_at(c, i / n)`:
/// `table[0]` is 0 and `table[n]` is that polyline's whole length, a
/// little short of the curve's true length because chords cut corners.
pub fn arc_length_table(c: &Curve, n: usize) -> Vec<f64> {
    let mut table = vec![0.0];
    let mut prev = point_at(c, 0.0);
    for i in 1..=n {
        let t = i as f64 / n as f64;
        let q = point_at(c, t);
        let last = *table.last().unwrap();
        table.push(last + magnitude(q - prev));
        prev = q;
    }
    table
}

/// `arc_length_table(c, n)`'s last entry: the curve's length, approximated
/// by `n` chords, more closely the bigger `n` is.
pub fn arc_length(c: &Curve, n: usize) -> f64 {
    *arc_length_table(c, n).last().unwrap()
}

/// The parameter where the running length in `table` reaches `s`: 0
/// before the start, 1 past the end, and inside the table a binary search
/// for the chord that spans `s` followed by an exact linear interpolation
/// within that one (straight) chord.
pub fn t_at_length(table: &[f64], s: f64) -> f64 {
    let n = table.len() - 1;
    if s <= 0.0 {
        return 0.0;
    }
    if s >= table[n] {
        return 1.0;
    }
    let mut lo = 0usize;
    let mut hi = n;
    while hi - lo > 1 {
        let mid = (lo + hi) / 2;
        if table[mid] <= s {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    let span = table[lo + 1] - table[lo];
    let frac = if span > 0.0 { (s - table[lo]) / span } else { 0.0 };
    (lo as f64 + frac) / n as f64
}

/// The point at running length `s` along `c`, approximated with `n`
/// chords.
pub fn point_at_length(c: &Curve, s: f64, n: usize) -> Tuple {
    point_at(c, t_at_length(&arc_length_table(c, n), s))
}

/// Splits `c` at the parameter that reaches running length `s`,
/// approximated with `n` chords -- `split_at` handed the parameter the
/// arc-length table found instead of a raw `t`.
pub fn split_at_length(c: &Curve, s: f64, n: usize) -> (Curve, Curve) {
    split_at(c, t_at_length(&arc_length_table(c, n), s))
}

// ---------------------------------------------------------------------
// § 15.2 The pattern
// ---------------------------------------------------------------------

/// Turns a raw dash pattern into the one the walk uses: an odd number of
/// entries is doubled so on and off alternate the same way every cycle. A
/// negative entry, or one that sums to zero or less, is no pattern at all
/// -- comes back empty, which `dash` treats as "draw it solid".
pub fn normalize_pattern(pattern: &[f64]) -> Vec<f64> {
    let sum: f64 = pattern.iter().sum();
    let neg = pattern.iter().any(|&v| v < 0.0);
    if neg || sum <= 0.0 {
        Vec::new()
    } else if pattern.len() % 2 == 1 {
        let mut v = pattern.to_vec();
        v.extend_from_slice(pattern);
        v
    } else {
        pattern.to_vec()
    }
}

// ---------------------------------------------------------------------
// § 15.3-15.4 The walk, and closed subpaths
// ---------------------------------------------------------------------

/// Cuts `p` into dashes: a path-to-path transform, like the stroker and
/// the offset. Every subpath starts the pattern over from `phase` (taken
/// modulo the pattern's sum, so a negative phase wraps and a phase of the
/// whole sum is no phase at all), and walks its own segments in order,
/// straight through every vertex -- a dash that reaches a corner turns
/// it. On-stretches become open subpaths of the result; a pattern that
/// normalizes to nothing (see `normalize_pattern`) leaves `p` untouched.
///
/// A closed subpath is walked around its closing segment too. If the walk
/// is still "on" when it gets back to the start, and it was "on" when it
/// left, the last dash and the first are touching: they're joined into
/// one dash that turns the starting corner, or, if a single dash covers
/// the whole loop, that dash comes back closed.
pub fn dash(p: &Path, pattern: &[f64], phase: f64) -> Path {
    let pat = normalize_pattern(pattern);
    if pat.is_empty() {
        return p.clone();
    }
    let n = pat.len();
    let total: f64 = pat.iter().sum();
    let mut out = path();

    for sp in subpaths(p) {
        let mut pts = sp.points.clone();
        if sp.closed && pts.len() > 1 {
            pts.push(pts[0]);
        }

        let mut i = 0usize;
        let mut remaining = pat[0];
        let mut on = true;
        let mut ph = ((phase % total) + total) % total;
        while ph > 0.0 {
            if ph >= remaining {
                ph -= remaining;
                i = (i + 1) % n;
                remaining = pat[i];
                on = !on;
            } else {
                remaining -= ph;
                ph = 0.0;
            }
        }

        let mut dashes: Vec<(Vec<Tuple>, bool)> = Vec::new();
        let mut cur: Option<usize> = None;

        if pts.len() >= 2 {
            for k in 0..pts.len() - 1 {
                let a = pts[k];
                let b = pts[k + 1];
                let seg = magnitude(b - a);
                if seg < 1e-9 {
                    continue;
                }
                let mut pos = 0.0;
                while pos < seg {
                    let step = remaining.min(seg - pos);
                    if on {
                        if cur.is_none() {
                            dashes.push((vec![lerp_tuple(a, b, pos / seg)], false));
                            cur = Some(dashes.len() - 1);
                        }
                        if step > 0.0 {
                            dashes[cur.unwrap()].0.push(lerp_tuple(a, b, (pos + step) / seg));
                        }
                    }
                    pos += step;
                    remaining -= step;
                    if remaining <= 1e-9 {
                        i = (i + 1) % n;
                        remaining = pat[i];
                        on = !on;
                        cur = None;
                    }
                }
            }
        }

        if sp.closed && !dashes.is_empty() {
            let head_start = dashes[0].0[0];
            let tail_end = *dashes[dashes.len() - 1].0.last().unwrap();
            if magnitude(head_start - pts[0]) < 1e-9 && magnitude(tail_end - pts[0]) < 1e-9 {
                if dashes.len() == 1 {
                    dashes[0].0.pop();
                    dashes[0].1 = true;
                } else {
                    let head_rest: Vec<Tuple> = dashes[0].0[1..].to_vec();
                    let last = dashes.len() - 1;
                    dashes[last].0.extend(head_rest);
                    dashes.remove(0);
                }
            }
        }

        for (dpts, closed) in dashes {
            if dpts.is_empty() {
                continue;
            }
            move_to(&mut out, dpts[0]);
            for &q in &dpts[1..] {
                line_to(&mut out, q);
            }
            if closed {
                close(&mut out);
            }
        }
    }

    out
}

/// The number of dashes `dash(p, pattern, phase)` produces.
pub fn dash_count(p: &Path, pattern: &[f64], phase: f64) -> usize {
    subpaths(&dash(p, pattern, phase)).len()
}

// ---------------------------------------------------------------------
// § 15.5 Putting it together
// ---------------------------------------------------------------------

const CH15_DIM: Color = Color { red: 0.25, green: 0.25, blue: 0.28 };
const CH15_INKS: [Color; 3] = [
    Color { red: 0.9, green: 0.55, blue: 0.1 },
    Color { red: 0.2, green: 0.55, blue: 0.85 },
    Color { red: 0.85, green: 0.25, blue: 0.3 },
];

/// The lopsided cubic Figure 15.1 uses: one short handle and one long
/// one, so the parameter's speed changes by a factor of five along it.
pub fn lopsided() -> Curve {
    cubic(point(15.0, 100.0), point(25.0, 85.0), point(100.0, 5.0), point(185.0, 95.0))
}

/// Paints a filled disc of radius `r` about `q` (a 24-gon, chapter 5's
/// `circle_path`, filled nonzero) through `color`.
fn paint_dot(c: &mut Canvas, q: Tuple, r: f64, color: Color) {
    let disc = circle_path(q.x, q.y, r, 24);
    let cov = fill_path(&disc, "nonzero", c.width, c.height);
    paint_through(c, &cov, color);
}

/// `lopsided()`, twice: eleven marks at equal steps of the parameter on
/// the left, eleven at equal steps of arc length on the right, over the
/// same faint spine.
pub fn even_marks() -> Canvas {
    let w = 200usize;
    let h = 120usize;
    let curve = lopsided();

    let mut spine = path();
    flatten_into_path(&mut spine, &curve, 0.1);
    let outline = stroke_to_path(&spine, 1.5, "butt", "round", 4.0);
    let cov = fill_path(&outline, "nonzero", w, h);

    let mut left = canvas(w, h);
    fill(&mut left, CH13_PAPER);
    paint_through(&mut left, &cov, CH15_DIM);
    let mut right = canvas(w, h);
    fill(&mut right, CH13_PAPER);
    paint_through(&mut right, &cov, CH15_DIM);

    let total = arc_length(&curve, 256);
    for i in 0..=10 {
        let t = i as f64 / 10.0;
        paint_dot(&mut left, point_at(&curve, t), 3.0, CH15_INKS[0]);
        paint_dot(&mut right, point_at_length(&curve, total * t, 256), 3.0, CH15_INKS[1]);
    }

    let mut out = canvas(2 * w, h);
    blit_panel(&mut out, &left, 0, 0);
    blit_panel(&mut out, &right, w as i64, 0);
    out
}

/// The flattened cubic `[(20,20+dy), (120,-20+dy), (200,60+dy),
/// (300,20+dy)]`, as one open subpath -- the strip's wave, shifted down
/// by `dy` for each row.
fn wave(dy: f64) -> Path {
    let c = cubic(
        point(20.0, 20.0 + dy),
        point(120.0, -20.0 + dy),
        point(200.0, 60.0 + dy),
        point(300.0, 20.0 + dy),
    );
    let mut p = path();
    flatten_into_path(&mut p, &c, 0.1);
    p
}

/// One wave, four ways: solid, `[12, 6]`, the same at phase 9, and `[0,
/// 9]` with round caps -- the dots are chapter 13's single-point
/// subpaths.
pub fn dash_strip() -> Canvas {
    let mut c = canvas(320, 160);
    fill(&mut c, CH13_PAPER);
    let rows: [(&[f64], f64, &str, Color); 4] = [
        (&[], 0.0, "butt", CH13_GRAY),
        (&[12.0, 6.0], 0.0, "butt", CH15_INKS[0]),
        (&[12.0, 6.0], 9.0, "butt", CH15_INKS[1]),
        (&[0.0, 9.0], 0.0, "round", CH15_INKS[2]),
    ];
    for (k, (pattern, phase, cap, color)) in rows.iter().enumerate() {
        let w = wave(40.0 * k as f64);
        let d = dash(&w, pattern, *phase);
        let outline = stroke_to_path(&d, 5.0, cap, "round", 4.0);
        let cov = fill_path(&outline, "nonzero", c.width, c.height);
        paint_through(&mut c, &cov, *color);
    }
    c
}

/// Seven quarter circles, each `phi` times the radius of the last and
/// tangent to it -- the golden spiral -- each quarter a cubic with the
/// usual 0.5523 handles, all flattened into one open subpath so the dash
/// walk carries the pattern from the innermost turn to the outermost
/// without a reset.
pub fn golden_spiral() -> Path {
    let phi = (1.0 + 5.0_f64.sqrt()) / 2.0;
    let kappa = 0.5522847498;
    let mut p = path();
    let mut r = 6.0;
    let mut cx = 148.0;
    let mut cy = 130.0;
    let mut theta = std::f64::consts::PI;
    for _ in 0..7 {
        let a0 = theta;
        let a1 = theta + std::f64::consts::PI / 2.0;
        let d0 = vector(a0.cos(), a0.sin());
        let d1 = vector(a1.cos(), a1.sin());
        let p0 = point(cx + r * d0.x, cy + r * d0.y);
        let p3 = point(cx + r * d1.x, cy + r * d1.y);
        let p1 = p0 + d1 * (kappa * r);
        let p2 = p3 + d0 * (kappa * r);
        flatten_into_path(&mut p, &cubic(p0, p1, p2, p3), 0.05);
        let nr = r * phi;
        cx = p3.x - nr * d1.x;
        cy = p3.y - nr * d1.y;
        r = nr;
        theta = a1;
    }
    p
}

/// Builds a fresh one-subpath `Path` through a subpath's own points, so
/// each of `dash`'s results can be stroked and painted in its own color.
fn subpath_as_path(sp: &Subpath) -> Path {
    let mut p = path();
    move_to(&mut p, sp.points[0]);
    for &pt in &sp.points[1..] {
        line_to(&mut p, pt);
    }
    if sp.closed {
        close(&mut p);
    }
    p
}

/// The golden spiral, drawn faintly, dashed 16 on 10 off and stroked
/// every dash 7 wide with round caps, in the next of three inks.
pub fn spiral_dashes() -> Canvas {
    let w = 340usize;
    let h = 340usize;
    let mut c = canvas(w, h);
    fill(&mut c, CH13_PAPER);

    let sp = golden_spiral();
    let outline = stroke_to_path(&sp, 1.0, "butt", "round", 4.0);
    let cov = fill_path(&outline, "nonzero", w, h);
    paint_through(&mut c, &cov, CH15_DIM);

    let dashed = dash(&sp, &[16.0, 10.0], 0.0);
    for (k, one) in subpaths(&dashed).iter().enumerate() {
        let one_path = subpath_as_path(one);
        let outline = stroke_to_path(&one_path, 7.0, "round", "round", 4.0);
        let cov = fill_path(&outline, "nonzero", w, h);
        paint_through(&mut c, &cov, CH15_INKS[k % 3]);
    }
    c
}

/// Plate 15: `spiral_dashes`, magnified by 2.
pub fn plate_15() -> Canvas {
    magnify(&spiral_dashes(), 2)
}

// =======================================================================
// Chapter 16: What a Glyph Is
// =======================================================================

// ---------------------------------------------------------------------
// A tiny hand-written JSON reader, just enough for the font schema:
// objects, arrays, strings, numbers and booleans. Nothing in this file's
// schema ever uses `null`, but the parser accepts it anyway since it
// costs nothing.
// ---------------------------------------------------------------------

#[derive(Debug, Clone)]
enum Json {
    Bool(bool),
    Number(f64),
    Str(String),
    Array(Vec<Json>),
    Object(HashMap<String, Json>),
}

impl Json {
    fn as_f64(&self) -> f64 {
        match self {
            Json::Number(n) => *n,
            other => panic!("expected a number, found {other:?}"),
        }
    }
    /// A point's on-curve flag: written as a JSON boolean everywhere in the
    /// current schema, in both the real font file and the chapter's own
    /// hand-written-font scenario. A bare `0`/`1` number is still accepted
    /// as a lenient fallback (no scenario exercises it any more).
    fn as_flag(&self) -> bool {
        match self {
            Json::Bool(b) => *b,
            Json::Number(n) => *n != 0.0,
            other => panic!("expected a bool or a 0/1 number, found {other:?}"),
        }
    }
    fn as_str(&self) -> &str {
        match self {
            Json::Str(s) => s,
            other => panic!("expected a string, found {other:?}"),
        }
    }
    fn as_array(&self) -> &[Json] {
        match self {
            Json::Array(a) => a,
            other => panic!("expected an array, found {other:?}"),
        }
    }
    fn as_object(&self) -> &HashMap<String, Json> {
        match self {
            Json::Object(o) => o,
            other => panic!("expected an object, found {other:?}"),
        }
    }
    fn get(&self, key: &str) -> &Json {
        self.as_object().get(key).unwrap_or_else(|| panic!("missing key {key:?}"))
    }
    /// A key that may not be present: chapter 18's `kern`/`ligatures` and
    /// chapter 19's `joining`/`forms`/`marks`/`anchors` are all optional
    /// sections of the schema, present only in the fonts that need them.
    fn get_opt(&self, key: &str) -> Option<&Json> {
        self.as_object().get(key)
    }
}

struct JsonParser<'a> {
    chars: std::iter::Peekable<std::str::Chars<'a>>,
}

impl<'a> JsonParser<'a> {
    fn new(s: &'a str) -> Self {
        JsonParser { chars: s.chars().peekable() }
    }

    fn skip_ws(&mut self) {
        while matches!(self.chars.peek(), Some(c) if c.is_whitespace()) {
            self.chars.next();
        }
    }

    fn expect_char(&mut self, expected: char) {
        self.skip_ws();
        let c = self.chars.next();
        assert_eq!(c, Some(expected), "expected {expected:?}, found {c:?}");
    }

    fn expect_lit(&mut self, lit: &str) {
        for expected in lit.chars() {
            let c = self.chars.next().unwrap_or_else(|| panic!("expected literal {lit:?}"));
            assert_eq!(c, expected, "expected literal {lit:?}");
        }
    }

    fn parse_value(&mut self) -> Json {
        self.skip_ws();
        match self.chars.peek() {
            Some('{') => self.parse_object(),
            Some('[') => self.parse_array(),
            Some('"') => Json::Str(self.parse_string()),
            Some('t') => {
                self.expect_lit("true");
                Json::Bool(true)
            }
            Some('f') => {
                self.expect_lit("false");
                Json::Bool(false)
            }
            Some('n') => {
                self.expect_lit("null");
                Json::Bool(false) // never used by this schema
            }
            _ => self.parse_number(),
        }
    }

    fn parse_object(&mut self) -> Json {
        let mut map = HashMap::new();
        self.expect_char('{');
        self.skip_ws();
        if self.chars.peek() == Some(&'}') {
            self.chars.next();
            return Json::Object(map);
        }
        loop {
            self.skip_ws();
            let key = self.parse_string();
            self.expect_char(':');
            let val = self.parse_value();
            map.insert(key, val);
            self.skip_ws();
            match self.chars.next() {
                Some(',') => continue,
                Some('}') => break,
                other => panic!("expected ',' or '}}', found {other:?}"),
            }
        }
        Json::Object(map)
    }

    fn parse_array(&mut self) -> Json {
        let mut arr = Vec::new();
        self.expect_char('[');
        self.skip_ws();
        if self.chars.peek() == Some(&']') {
            self.chars.next();
            return Json::Array(arr);
        }
        loop {
            let val = self.parse_value();
            arr.push(val);
            self.skip_ws();
            match self.chars.next() {
                Some(',') => continue,
                Some(']') => break,
                other => panic!("expected ',' or ']', found {other:?}"),
            }
        }
        Json::Array(arr)
    }

    fn parse_string(&mut self) -> String {
        self.skip_ws();
        self.expect_char('"');
        let mut s = String::new();
        loop {
            match self.chars.next() {
                Some('"') => break,
                Some('\\') => match self.chars.next() {
                    Some('"') => s.push('"'),
                    Some('\\') => s.push('\\'),
                    Some('/') => s.push('/'),
                    Some('n') => s.push('\n'),
                    Some('t') => s.push('\t'),
                    Some('r') => s.push('\r'),
                    Some('b') => s.push('\u{8}'),
                    Some('f') => s.push('\u{c}'),
                    Some('u') => {
                        let hex: String = (0..4)
                            .map(|_| self.chars.next().unwrap_or_else(|| panic!("bad \\u escape")))
                            .collect();
                        let code = u32::from_str_radix(&hex, 16).unwrap_or_else(|_| panic!("bad \\u escape {hex:?}"));
                        if let Some(c) = char::from_u32(code) {
                            s.push(c);
                        }
                    }
                    other => panic!("bad escape {other:?}"),
                },
                Some(c) => s.push(c),
                None => panic!("unterminated string"),
            }
        }
        s
    }

    fn parse_number(&mut self) -> Json {
        self.skip_ws();
        let mut s = String::new();
        if self.chars.peek() == Some(&'-') {
            s.push(self.chars.next().unwrap());
        }
        while let Some(&c) = self.chars.peek() {
            if c.is_ascii_digit() || c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-' {
                s.push(c);
                self.chars.next();
            } else {
                break;
            }
        }
        Json::Number(s.parse().unwrap_or_else(|_| panic!("bad number {s:?}")))
    }
}

fn parse_json(text: &str) -> Json {
    let mut p = JsonParser::new(text);
    p.parse_value()
}

// ---------------------------------------------------------------------
// § 16.1 The font file
// ---------------------------------------------------------------------

/// One component of a composite glyph: another glyph's name, placed
/// through a six-number transform `[a, b, c, d, dx, dy]` that TrueType
/// applies as `x' = a*x + c*y + dx`, `y' = b*x + d*y + dy`.
#[derive(Debug, Clone)]
pub struct Component {
    pub glyph: String,
    pub transform: [f64; 6],
}

/// A glyph's own contours (each a closed loop of `(x, y, on_curve)`
/// points in font units, y up) plus, for a composite, the other glyphs
/// it's built from. A glyph with contours has no components and vice
/// versa, but nothing enforces that; both are simply empty when unused.
#[derive(Debug, Clone)]
pub struct Glyph {
    pub advance: f64,
    pub contours: Vec<Vec<(f64, f64, bool)>>,
    pub components: Vec<Component>,
}

/// A font: vertical metrics in font units, a codepoint-to-name `cmap`,
/// and every glyph by name, plus the optional sections later chapters
/// read when a font file carries them. `units_per_em` is the design grid
/// every coordinate in the file is a whole number on.
///
/// `kern` (chapter 18) is a pair of glyph names to a font-unit value.
/// `ligatures` (chapters 18-19) is a list of rules, each a sequence of
/// glyph names and the one glyph that replaces them. `joining` (chapter
/// 19) is Unicode's joining type per codepoint, keyed the same way as
/// `cmap`. `forms` is, for a glyph with positional forms, its
/// `"init"`/`"medi"`/`"fina"` glyph names. `marks` is, for a mark glyph,
/// its anchor class (`"above"`/`"below"`) and its own anchor point in
/// font units. `anchors` is, for a base glyph, its anchor point per
/// class. All six are empty when the file doesn't carry the section.
#[derive(Debug, Clone)]
pub struct Font {
    pub units_per_em: f64,
    pub ascender: f64,
    pub descender: f64,
    pub line_gap: f64,
    pub cmap: HashMap<String, String>,
    pub glyphs: HashMap<String, Glyph>,
    pub kern: HashMap<(String, String), f64>,
    pub ligatures: Vec<(Vec<String>, String)>,
    pub joining: HashMap<String, String>,
    pub forms: HashMap<String, HashMap<String, String>>,
    pub marks: HashMap<String, (String, f64, f64)>,
    pub anchors: HashMap<String, HashMap<String, (f64, f64)>>,
}

/// Reads the book's JSON font schema: `units_per_em`/`ascender`/
/// `descender`/`line_gap` in font units, `cmap` (codepoint string to
/// glyph name), and `glyphs` by name, plus six optional sections read
/// when present: `kern`, `ligatures`, `joining`, `forms`, `marks` and
/// `anchors` (chapters 18-19's field guide).
pub fn load_font<T: AsRef<[u8]>>(data: T) -> Font {
    let text = std::str::from_utf8(data.as_ref()).expect("font JSON is not valid UTF-8");
    let root = parse_json(text);

    let units_per_em = root.get("units_per_em").as_f64();
    let ascender = root.get("ascender").as_f64();
    let descender = root.get("descender").as_f64();
    let line_gap = root.get("line_gap").as_f64();

    let mut cmap = HashMap::new();
    for (k, v) in root.get("cmap").as_object() {
        cmap.insert(k.clone(), v.as_str().to_string());
    }

    let mut glyphs = HashMap::new();
    for (name, g) in root.get("glyphs").as_object() {
        let advance = g.get("advance").as_f64();
        let mut contours = Vec::new();
        for contour in g.get("contours").as_array() {
            let mut pts = Vec::new();
            for pt in contour.as_array() {
                let arr = pt.as_array();
                pts.push((arr[0].as_f64(), arr[1].as_f64(), arr[2].as_flag()));
            }
            contours.push(pts);
        }
        let mut components = Vec::new();
        for comp in g.get("components").as_array() {
            let glyph_name = comp.get("glyph").as_str().to_string();
            let t = comp.get("transform").as_array();
            let transform =
                [t[0].as_f64(), t[1].as_f64(), t[2].as_f64(), t[3].as_f64(), t[4].as_f64(), t[5].as_f64()];
            components.push(Component { glyph: glyph_name, transform });
        }
        glyphs.insert(name.clone(), Glyph { advance, contours, components });
    }

    let mut kern = HashMap::new();
    if let Some(arr) = root.get_opt("kern") {
        for entry in arr.as_array() {
            let e = entry.as_array();
            kern.insert((e[0].as_str().to_string(), e[1].as_str().to_string()), e[2].as_f64());
        }
    }

    let mut ligatures = Vec::new();
    if let Some(arr) = root.get_opt("ligatures") {
        for entry in arr.as_array() {
            let e = entry.as_array();
            let parts: Vec<String> = e[0].as_array().iter().map(|p| p.as_str().to_string()).collect();
            ligatures.push((parts, e[1].as_str().to_string()));
        }
    }

    let mut joining = HashMap::new();
    if let Some(obj) = root.get_opt("joining") {
        for (k, v) in obj.as_object() {
            joining.insert(k.clone(), v.as_str().to_string());
        }
    }

    let mut forms = HashMap::new();
    if let Some(obj) = root.get_opt("forms") {
        for (glyph, table) in obj.as_object() {
            let mut m = HashMap::new();
            for (form, name) in table.as_object() {
                m.insert(form.clone(), name.as_str().to_string());
            }
            forms.insert(glyph.clone(), m);
        }
    }

    let mut marks = HashMap::new();
    if let Some(obj) = root.get_opt("marks") {
        for (glyph, arr) in obj.as_object() {
            let a = arr.as_array();
            marks.insert(glyph.clone(), (a[0].as_str().to_string(), a[1].as_f64(), a[2].as_f64()));
        }
    }

    let mut anchors = HashMap::new();
    if let Some(obj) = root.get_opt("anchors") {
        for (glyph, table) in obj.as_object() {
            let mut m = HashMap::new();
            for (class, arr) in table.as_object() {
                let a = arr.as_array();
                m.insert(class.clone(), (a[0].as_f64(), a[1].as_f64()));
            }
            anchors.insert(glyph.clone(), m);
        }
    }

    Font { units_per_em, ascender, descender, line_gap, cmap, glyphs, kern, ligatures, joining, forms, marks, anchors }
}

/// Looks a character up in the font's `cmap`; `.notdef` for one the font
/// doesn't have.
pub fn glyph_name(font: &Font, codepoint: i64) -> String {
    font.cmap.get(&codepoint.to_string()).cloned().unwrap_or_else(|| ".notdef".to_string())
}

pub fn glyph_advance(font: &Font, name: &str) -> f64 {
    font.glyphs.get(name).unwrap_or_else(|| panic!("no such glyph {name:?}")).advance
}

pub fn glyph_count(font: &Font) -> usize {
    font.glyphs.len()
}

// ---------------------------------------------------------------------
// § 16.2 Contours, and the points that aren't there
// ---------------------------------------------------------------------

/// Makes every implied on-curve point explicit -- one at the midpoint of
/// every pair of consecutive off-curve points, the loop wrapping so the
/// last and first count as consecutive too -- and rotates the result to
/// start on an on-curve point.
pub fn implied_points(contour: &[(f64, f64, bool)]) -> Vec<(f64, f64, bool)> {
    let n = contour.len();
    let mut out: Vec<(f64, f64, bool)> = Vec::with_capacity(n + 1);
    for i in 0..n {
        let cur = contour[i];
        let nxt = contour[(i + 1) % n];
        out.push(cur);
        if !cur.2 && !nxt.2 {
            out.push(((cur.0 + nxt.0) / 2.0, (cur.1 + nxt.1) / 2.0, true));
        }
    }
    if let Some(k) = out.iter().position(|p| p.2) {
        let mut rotated = out[k..].to_vec();
        rotated.extend_from_slice(&out[..k]);
        rotated
    } else {
        out
    }
}

/// The loop as quadratics: from each on-curve point through the
/// off-curve point after it to the next on-curve point, or -- for two
/// on-curve points in a row -- a straight edge written as a quadratic
/// through their own midpoint, the same line exactly.
pub fn contour_curves(contour: &[(f64, f64, bool)]) -> Vec<Curve> {
    let pts = implied_points(contour);
    let n = pts.len();
    let mut curves = Vec::new();
    let mut i = 0;
    while i < n {
        let a = pts[i];
        let b = pts[(i + 1) % n];
        if b.2 {
            let mid = point((a.0 + b.0) / 2.0, (a.1 + b.1) / 2.0);
            curves.push(quadratic(point(a.0, a.1), mid, point(b.0, b.1)));
            i += 1;
        } else {
            let c = pts[(i + 2) % n];
            curves.push(quadratic(point(a.0, a.1), point(b.0, b.1), point(c.0, c.1)));
            i += 2;
        }
    }
    curves
}

// ---------------------------------------------------------------------
// § 16.3 Composites
// ---------------------------------------------------------------------

/// A component's six-number transform as a `matrix3`: TrueType's
/// `x' = a*x + c*y + dx`, `y' = b*x + d*y + dy` in the letters-by-row
/// arrangement `matrix3` expects.
pub fn component_matrix(t: [f64; 6]) -> Matrix3 {
    matrix3(t[0], t[2], t[4], t[1], t[3], t[5], 0.0, 0.0, 1.0)
}

/// Every contour of a glyph as quadratics, in font units, components
/// included: each component's own outline recursively, taken through its
/// matrix.
pub fn glyph_outline(font: &Font, name: &str) -> Vec<Vec<Curve>> {
    let g = font.glyphs.get(name).unwrap_or_else(|| panic!("no such glyph {name:?}"));
    let mut out: Vec<Vec<Curve>> = g.contours.iter().map(|c| contour_curves(c)).collect();
    for comp in &g.components {
        let m = component_matrix(comp.transform);
        for contour in glyph_outline(font, &comp.glyph) {
            out.push(contour.iter().map(|c| transform_curve(c, m)).collect());
        }
    }
    out
}

/// The tight box of the outline, from `curve_bounds` on every quadratic
/// -- not the box of the control points. An empty glyph's is
/// `(0, 0, 0, 0)`.
pub fn glyph_bounds(font: &Font, name: &str) -> (f64, f64, f64, f64) {
    let mut min_x = f64::INFINITY;
    let mut min_y = f64::INFINITY;
    let mut max_x = f64::NEG_INFINITY;
    let mut max_y = f64::NEG_INFINITY;
    let mut any = false;
    for contour in glyph_outline(font, name) {
        for c in &contour {
            any = true;
            let (x0, y0, x1, y1) = curve_bounds(c);
            min_x = min_x.min(x0);
            min_y = min_y.min(y0);
            max_x = max_x.max(x1);
            max_y = max_y.max(y1);
        }
    }
    if !any {
        (0.0, 0.0, 0.0, 0.0)
    } else {
        (min_x, min_y, max_x, max_y)
    }
}

// ---------------------------------------------------------------------
// § 16.4 The flip, in one place
// ---------------------------------------------------------------------

/// The one place fonts' y-up, baseline-origin coordinates turn into the
/// canvas's y-down, corner-origin ones: scale by `size / units_per_em`
/// with the y scale negated, then put the glyph's origin at `(x, y)`.
pub fn text_matrix(font: &Font, size: f64, x: f64, y: f64) -> Matrix3 {
    let s = size / font.units_per_em;
    translation(x, y) * scaling(s, -s)
}

/// One contour of a glyph as a closed subpath: every quadratic through
/// `m`, flattened in device space at `tolerance`.
pub fn contour_path(font: &Font, name: &str, i: usize, m: Matrix3, tolerance: f64) -> Path {
    let outline = glyph_outline(font, name);
    let contour = &outline[i];
    let mut p = path();
    for c in contour {
        let tc = transform_curve(c, m);
        flatten_into_path(&mut p, &tc, tolerance);
    }
    close(&mut p);
    p
}

/// A glyph's whole outline as a path: one closed subpath per contour.
pub fn glyph_path(font: &Font, name: &str, m: Matrix3, tolerance: f64) -> Path {
    let mut p = path();
    for contour in glyph_outline(font, name) {
        for c in &contour {
            let tc = transform_curve(c, m);
            flatten_into_path(&mut p, &tc, tolerance);
        }
        close(&mut p);
    }
    p
}

// ---------------------------------------------------------------------
// § 16.5 Putting it together
// ---------------------------------------------------------------------

const CH16_PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };
const CH16_GRAY: Color = Color { red: 0.62, green: 0.62, blue: 0.66 };
const CH16_DIM: Color = Color { red: 0.3, green: 0.3, blue: 0.34 };
const CH16_MAGENTA: Color = Color { red: 0.85, green: 0.2, blue: 0.55 };
const CH16_CYAN: Color = Color { red: 0.2, green: 0.75, blue: 0.9 };
const CH16_INKS: [Color; 3] = [
    Color { red: 0.9, green: 0.55, blue: 0.1 },
    Color { red: 0.2, green: 0.55, blue: 0.85 },
    Color { red: 0.85, green: 0.25, blue: 0.3 },
];

fn ch16_load_font() -> Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

fn paint_fill_path(c: &mut Canvas, p: &Path, rule: &str, col: Color) {
    let cov = fill_path(p, rule, c.width, c.height);
    paint_through(c, &cov, col);
}

fn paint_hairline(c: &mut Canvas, p: &Path, width: f64, col: Color) {
    let outline = stroke_to_path(p, width, "butt", "round", 4.0);
    paint_fill_path(c, &outline, "nonzero", col);
}

fn tiny_square(q: Tuple, half: f64) -> Path {
    polygon(&[
        point(q.x - half, q.y - half),
        point(q.x + half, q.y - half),
        point(q.x + half, q.y + half),
        point(q.x - half, q.y + half),
    ])
}

/// The plate's letter `a`, filled, with its control polygon and points
/// drawn over it: on-curve points as filled squares, off-curve points as
/// hollow circles, implied on-curve points as smaller squares.
pub fn glyph_plate() -> Canvas {
    let font = ch16_load_font();
    let mut c = canvas(320, 320);
    fill(&mut c, CH16_PAPER);
    let m = text_matrix(&font, 300.0, 40.0, 250.0);

    paint_fill_path(&mut c, &glyph_path(&font, "a", m, 0.1), "nonzero", CH16_GRAY);

    let contours = &font.glyphs["a"].contours;
    for contour in contours {
        let pts: Vec<Tuple> = contour.iter().map(|&(x, y, _)| m * point(x, y)).collect();
        let poly = polygon(&pts);
        paint_hairline(&mut c, &poly, 1.0, CH16_DIM);
    }
    for contour in contours {
        let explicit: std::collections::HashSet<(i64, i64)> =
            contour.iter().map(|&(x, y, _)| ((x * 1000.0).round() as i64, (y * 1000.0).round() as i64)).collect();
        for (x, y, on) in implied_points(contour) {
            let q = m * point(x, y);
            if !on {
                paint_hairline(&mut c, &circle_path(q.x, q.y, 4.0, 24), 1.5, CH16_MAGENTA);
            } else if explicit.contains(&((x * 1000.0).round() as i64, (y * 1000.0).round() as i64)) {
                paint_fill_path(&mut c, &tiny_square(q, 3.0), "nonzero", CH16_CYAN);
            } else {
                paint_fill_path(&mut c, &tiny_square(q, 2.0), "nonzero", CH16_CYAN);
            }
        }
    }
    c
}

/// Plate 16: `glyph_plate`, magnified by 2.
pub fn plate_16() -> Canvas {
    magnify(&glyph_plate(), 2)
}

/// `eacute`'s two components, each in its own ink, with `glyph_bounds`
/// drawn as a hairline box.
pub fn composite_demo() -> Canvas {
    let font = ch16_load_font();
    let mut c = canvas(240, 240);
    fill(&mut c, CH16_PAPER);
    let m = text_matrix(&font, 240.0, 50.0, 190.0);

    let components = font.glyphs["eacute"].components.clone();
    for (k, comp) in components.iter().enumerate() {
        let cm = m * component_matrix(comp.transform);
        paint_fill_path(&mut c, &glyph_path(&font, &comp.glyph, cm, 0.1), "nonzero", CH16_INKS[k % 3]);
    }

    let bb = glyph_bounds(&font, "eacute");
    let a = m * point(bb.0, bb.1);
    let b = m * point(bb.2, bb.3);
    let box_path = polygon(&[point(a.x, a.y), point(b.x, a.y), point(b.x, b.y), point(a.x, b.y)]);
    paint_hairline(&mut c, &box_path, 1.0, CH16_MAGENTA);
    c
}

/// `g` at 12, 24, 48 and 96 pixels on one baseline.
pub fn sizes() -> Canvas {
    let font = ch16_load_font();
    let mut c = canvas(240, 120);
    fill(&mut c, CH16_PAPER);
    let mut x = 8.0;
    for &size in &[12.0, 24.0, 48.0, 96.0] {
        let m = text_matrix(&font, size, x, 80.0);
        paint_fill_path(&mut c, &glyph_path(&font, "g", m, 0.1), "nonzero", CH16_GRAY);
        x += glyph_advance(&font, "g") * size / font.units_per_em + 8.0;
    }
    c
}

/// `R` through `text_matrix` on the left, through a scale that forgot to
/// turn y over on the right.
pub fn flip_trap() -> Canvas {
    let font = ch16_load_font();
    let w = 120;
    let h = 120;
    let mut left = canvas(w, h);
    fill(&mut left, CH16_PAPER);
    let mut right = canvas(w, h);
    fill(&mut right, CH16_PAPER);

    let good = text_matrix(&font, 60.0, 35.0, 60.0);
    paint_fill_path(&mut left, &glyph_path(&font, "R", good, 0.1), "nonzero", CH16_GRAY);

    let s = 60.0 / font.units_per_em;
    let bad = translation(35.0, 60.0) * scaling(s, s);
    paint_fill_path(&mut right, &glyph_path(&font, "R", bad, 0.1), "nonzero", CH16_MAGENTA);

    for canv in [&mut left, &mut right] {
        let mut line = path();
        move_to(&mut line, point(0.0, 60.0));
        line_to(&mut line, point(w as f64, 60.0));
        paint_hairline(canv, &line, 1.0, CH16_DIM);
    }
    side_by_side(&left, &right)
}

// =======================================================================
// Chapter 17: Rasterizing Type Well
// =======================================================================

const SUBPIXELS: i64 = 4;

// ---------------------------------------------------------------------
// § 17.1 A quarter of a pixel
// ---------------------------------------------------------------------

/// Splits a pen position into a whole pixel and one of four quarters,
/// the fraction rounded to the nearest quarter and carried into the next
/// pixel when it rounds all the way up.
pub fn subpixel_of(x: f64) -> (i64, i64) {
    let whole = x.floor();
    let frac = x - whole;
    let q = ((frac * SUBPIXELS as f64) + 0.5).floor() as i64;
    if q == SUBPIXELS {
        (whole as i64 + 1, 0)
    } else {
        (whole as i64, q)
    }
}

/// A glyph's coverage in a buffer of its own, no bigger than it needs,
/// plus the buffer's top-left corner relative to the pen.
#[derive(Debug, Clone)]
pub struct Bitmap {
    pub coverage: CoverageBuffer,
    pub width: usize,
    pub height: usize,
    pub left: i64,
    pub top: i64,
}

pub fn bitmap(coverage: CoverageBuffer, left: i64, top: i64) -> Bitmap {
    let width = coverage.width;
    let height = coverage.height;
    Bitmap { coverage, width, height, left, top }
}

/// Renders the glyph with its origin at `x = subpixel / 4` into a
/// coverage buffer just big enough for it: columns `floor(xmin)` to
/// `ceil(xmax) - 1` of its device bounds shifted by that quarter, rows
/// `floor(-ymax)` to `ceil(-ymin) - 1`.
pub fn glyph_bitmap(font: &Font, name: &str, size: f64, subpixel: i64) -> Bitmap {
    let s = size / font.units_per_em;
    let bb = glyph_bounds(font, name);
    if bb == (0.0, 0.0, 0.0, 0.0) {
        return Bitmap { coverage: coverage_buffer(0, 0), width: 0, height: 0, left: 0, top: 0 };
    }
    let dx = subpixel as f64 / SUBPIXELS as f64;
    let left = (bb.0 * s + dx).floor() as i64;
    let right = (bb.2 * s + dx).ceil() as i64;
    let top = (-bb.3 * s).floor() as i64;
    let bottom = (-bb.1 * s).ceil() as i64;
    let w = (right - left).max(1) as usize;
    let h = (bottom - top).max(1) as usize;
    let m = text_matrix(font, size, dx - left as f64, -(top as f64));
    let p = glyph_path(font, name, m, 0.1);
    let cov = fill_path(&p, "nonzero", w, h);
    Bitmap { coverage: cov, width: w, height: h, left, top }
}

/// Composites a bitmap with its pen at whole pixel `(x, y)`: each covered
/// pixel mixed toward `col` by that pixel's coverage, through chapter 1's
/// switch.
pub fn paint_bitmap(c: &mut Canvas, b: &Bitmap, x: i64, y: i64, col: Color, linear: bool) {
    for j in 0..b.height as i64 {
        for i in 0..b.width as i64 {
            let k = coverage_at(&b.coverage, i, j);
            if k > 0.0 {
                let px = x + b.left + i;
                let py = y + b.top + j;
                if px >= 0 && py >= 0 && (px as usize) < c.width && (py as usize) < c.height {
                    let old = pixel_at(c, px, py);
                    write_pixel(c, px, py, mix_with(old, col, k, linear));
                }
            }
        }
    }
}

// ---------------------------------------------------------------------
// § 17.2 The cache and the atlas
// ---------------------------------------------------------------------

/// Bitmaps keyed by `(glyph name, size, subpixel)`: rendered on the first
/// request, handed back unchanged after.
#[derive(Debug, Clone, Default)]
pub struct GlyphCache {
    entries: HashMap<(String, u64, i64), Bitmap>,
}

pub fn glyph_cache() -> GlyphCache {
    GlyphCache { entries: HashMap::new() }
}

pub fn cached_bitmap(cache: &mut GlyphCache, font: &Font, name: &str, size: f64, subpixel: i64) -> Bitmap {
    let key = (name.to_string(), size.to_bits(), subpixel);
    if let Some(b) = cache.entries.get(&key) {
        return b.clone();
    }
    let b = glyph_bitmap(font, name, size, subpixel);
    cache.entries.insert(key, b.clone());
    b
}

pub fn cache_size(cache: &GlyphCache) -> usize {
    cache.entries.len()
}

/// One big coverage buffer bitmaps are packed into, shelf by shelf:
/// bitmaps go left to right along a shelf whose height is set by its
/// first bitmap; when the next one doesn't fit, a new shelf opens below
/// the one just closed.
#[derive(Debug, Clone)]
pub struct Atlas {
    pub coverage: CoverageBuffer,
    pub width: usize,
    pub height: usize,
    shelf_top: usize,
    shelf_height: usize,
    cursor_x: usize,
}

pub fn atlas(width: usize, height: usize) -> Atlas {
    Atlas { coverage: coverage_buffer(width, height), width, height, shelf_top: 0, shelf_height: 0, cursor_x: 0 }
}

/// Copies `b`'s coverage into the atlas and answers where its top-left
/// corner landed, or `None` when there's no room: too wide or tall for
/// the atlas ever, or too tall for what's left below the current shelf.
/// Follows chapter-17.html §17.2's `atlas_add` pseudocode order exactly:
/// the "can never fit" check comes first and returns before touching the
/// shelf, so a bitmap wider than the whole atlas doesn't close the
/// current shelf on its way to failing.
pub fn atlas_add(a: &mut Atlas, b: &Bitmap) -> Option<(usize, usize)> {
    if b.width > a.width || b.height > a.height {
        return None;
    }
    if a.cursor_x + b.width > a.width {
        a.shelf_top += a.shelf_height;
        a.cursor_x = 0;
        a.shelf_height = 0;
    }
    if a.shelf_top + b.height.max(a.shelf_height) > a.height {
        return None;
    }
    let pos = (a.cursor_x, a.shelf_top);
    atlas_blit(a, b, pos.0, pos.1);
    a.cursor_x += b.width;
    a.shelf_height = a.shelf_height.max(b.height);
    Some(pos)
}

fn atlas_blit(a: &mut Atlas, b: &Bitmap, x0: usize, y0: usize) {
    for j in 0..b.height as i64 {
        for i in 0..b.width as i64 {
            let v = coverage_at(&b.coverage, i, j);
            set_coverage(&mut a.coverage, x0 as i64 + i, y0 as i64 + j, v);
        }
    }
}

// ---------------------------------------------------------------------
// § 17.3 The fudge, named
// ---------------------------------------------------------------------

/// Stem darkening: the glyph's fill plus chapter 13's stroke of its own
/// outline, `amount` wide, the two coverages added and clamped to 1, in
/// a bitmap grown a pixel all round to make room.
pub fn embolden(font: &Font, name: &str, size: f64, amount: f64) -> Bitmap {
    let s = size / font.units_per_em;
    let bb = glyph_bounds(font, name);
    let left = (bb.0 * s).floor() as i64 - 1;
    let top = (-bb.3 * s).floor() as i64 - 1;
    let w = ((bb.2 * s).ceil() as i64 + 1 - left) as usize;
    let h = ((-bb.1 * s).ceil() as i64 + 1 - top) as usize;
    let m = text_matrix(font, size, -(left as f64), -(top as f64));
    let p = glyph_path(font, name, m, 0.1);
    let fill_cov = fill_path(&p, "nonzero", w, h);
    let stroked = stroke_to_path(&p, amount, "butt", "round", 4.0);
    let edge_cov = fill_path(&stroked, "nonzero", w, h);
    let mut cov = coverage_buffer(w, h);
    for y in 0..h as i64 {
        for x in 0..w as i64 {
            let v = (coverage_at(&fill_cov, x, y) + coverage_at(&edge_cov, x, y)).min(1.0);
            set_coverage(&mut cov, x, y, v);
        }
    }
    Bitmap { coverage: cov, width: w, height: h, left, top }
}

// ---------------------------------------------------------------------
// § 17.4 Three coverages per pixel
// ---------------------------------------------------------------------

pub const LCD_TAPS: (f64, f64, f64) = (1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0);

/// Replaces every value with the average of itself and its two
/// neighbors, zero beyond the ends: three taps that sum to one, so ink
/// spreads across neighboring stripes but is never lost.
pub fn lcd_filter(v: &[f64]) -> Vec<f64> {
    let n = v.len();
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let a = if i > 0 { v[i - 1] } else { 0.0 };
        let b = v[i];
        let c = if i + 1 < n { v[i + 1] } else { 0.0 };
        out.push(LCD_TAPS.0 * a + LCD_TAPS.1 * b + LCD_TAPS.2 * c);
    }
    out
}

/// The glyph rasterized three times wider -- one coverage per LCD
/// stripe -- into a buffer `3w` wide and `h` tall, every row run through
/// `lcd_filter`.
pub fn lcd_coverage(font: &Font, name: &str, size: f64, x: f64, y: f64, w: usize, h: usize) -> CoverageBuffer {
    let m = scaling(3.0, 1.0) * text_matrix(font, size, x, y);
    let p = glyph_path(font, name, m, 0.1);
    let raw = fill_path(&p, "nonzero", 3 * w, h);
    let mut out = coverage_buffer(3 * w, h);
    for row in 0..h as i64 {
        let vals: Vec<f64> = (0..(3 * w) as i64).map(|x| coverage_at(&raw, x, row)).collect();
        let filtered = lcd_filter(&vals);
        for (x, v) in filtered.into_iter().enumerate() {
            set_coverage(&mut out, x as i64, row, v);
        }
    }
    out
}

/// Composites a 3-wide-per-pixel coverage buffer: red through the first
/// stripe of each pixel, green the second, blue the third, each channel
/// mixed on its own, always in linear light.
pub fn paint_lcd(c: &mut Canvas, cov3: &CoverageBuffer, col: Color) {
    let w = cov3.width / 3;
    let h = cov3.height;
    for y in 0..h.min(c.height) as i64 {
        for x in 0..w.min(c.width) as i64 {
            let kr = coverage_at(cov3, 3 * x, y);
            let kg = coverage_at(cov3, 3 * x + 1, y);
            let kb = coverage_at(cov3, 3 * x + 2, y);
            if kr > 0.0 || kg > 0.0 || kb > 0.0 {
                let old = pixel_at(c, x, y);
                let mixed = color(
                    old.red + (col.red - old.red) * kr,
                    old.green + (col.green - old.green) * kg,
                    old.blue + (col.blue - old.blue) * kb,
                );
                write_pixel(c, x, y, mixed);
            }
        }
    }
}

// ---------------------------------------------------------------------
// § 17.5 Putting it together
// ---------------------------------------------------------------------

/// A glyph's advance in pixels, at `size`.
pub fn pen_advance(font: &Font, name: &str, size: f64) -> f64 {
    glyph_advance(font, name) * size / font.units_per_em
}

/// Steps the pen across `text`, each glyph painted at its nearest
/// quarter pixel; returns the pen's final position.
pub fn draw_text(c: &mut Canvas, font: &Font, text: &str, size: f64, x: f64, y: f64, col: Color, linear: bool) -> f64 {
    let mut pen = x;
    for ch in text.chars() {
        let name = glyph_name(font, ch as i64);
        let (whole, sub) = subpixel_of(pen);
        let b = glyph_bitmap(font, &name, size, sub);
        paint_bitmap(c, &b, whole, y.floor() as i64, col, linear);
        pen += pen_advance(font, &name, size);
    }
    pen
}

fn ch17_load_font() -> Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

const CH17_WHITE: Color = Color { red: 1.0, green: 1.0, blue: 1.0 };
const CH17_BLACK: Color = Color { red: 0.0, green: 0.0, blue: 0.0 };

/// The same stem (`l`) at four quarters, side by side, magnified by 8.
pub fn subpixel_strip() -> Canvas {
    let font = ch17_load_font();
    let mut panels: Vec<Canvas> = Vec::new();
    for k in 0..4 {
        let mut b = canvas(10, 14);
        fill(&mut b, CH17_WHITE);
        let (whole, sub) = subpixel_of(4.0 + (k as f64) / 4.0);
        let bm = glyph_bitmap(&font, "l", 11.0, sub);
        paint_bitmap(&mut b, &bm, whole, 11, CH17_BLACK, true);
        panels.push(b);
    }
    let left = side_by_side(&panels[0], &panels[1]);
    let right = side_by_side(&panels[2], &panels[3]);
    let row = side_by_side(&left, &right);
    magnify(&row, 8)
}

/// "Hamburg" at 11 pixels three ways: linear light, encoded-space
/// blending, and linear light with the stems emboldened by a third of a
/// pixel. Magnified by 4.
pub fn smoothing_demo() -> Canvas {
    let font = ch17_load_font();
    let mut c = canvas(72, 42);
    fill(&mut c, CH17_WHITE);
    draw_text(&mut c, &font, "Hamburg", 11.0, 2.0, 11.0, CH17_BLACK, true);
    draw_text(&mut c, &font, "Hamburg", 11.0, 2.0, 25.0, CH17_BLACK, false);

    let mut pen = 2.0;
    for ch in "Hamburg".chars() {
        let name = glyph_name(&font, ch as i64);
        let (whole, sub) = subpixel_of(pen);
        let _ = sub; // embolden always renders at subpixel 0
        let b = embolden(&font, &name, 11.0, 1.0 / 3.0);
        paint_bitmap(&mut c, &b, whole, 39, CH17_BLACK, true);
        pen += pen_advance(&font, &name, 11.0);
    }
    magnify(&c, 4)
}

/// `ea` at 13 pixels twice: grayscale above, LCD below. Magnified by 6.
pub fn lcd_plate() -> Canvas {
    let font = ch17_load_font();
    let w = 24;
    let h = 16;
    let mut top = canvas(w, h);
    fill(&mut top, CH17_WHITE);
    let mut bottom = canvas(w, h);
    fill(&mut bottom, CH17_WHITE);

    let mut pen = 2.0;
    for ch in "ea".chars() {
        let name = glyph_name(&font, ch as i64);
        let m = text_matrix(&font, 13.0, pen, 12.0);
        paint_fill_path(&mut top, &glyph_path(&font, &name, m, 0.1), "nonzero", CH17_BLACK);
        let cov3 = lcd_coverage(&font, &name, 13.0, pen, 12.0, w, h);
        paint_lcd(&mut bottom, &cov3, CH17_BLACK);
        pen += pen_advance(&font, &name, 13.0);
    }

    let mut stacked = canvas(w, 2 * h);
    for y in 0..h {
        for x in 0..w {
            write_pixel(&mut stacked, x as i64, y as i64, pixel_at(&top, x as i64, y as i64));
            write_pixel(&mut stacked, x as i64, (h + y) as i64, pixel_at(&bottom, x as i64, y as i64));
        }
    }
    magnify(&stacked, 6)
}

/// Plate 17: `lcd_plate`, magnified by 2.
pub fn plate_17() -> Canvas {
    magnify(&lcd_plate(), 2)
}

// =======================================================================
// Chapter 18: Setting a Line of Text
// =======================================================================

// ---------------------------------------------------------------------
// § 18.1 The pen, and the lines around it
// ---------------------------------------------------------------------

/// One glyph's name and the fractional-pixel position of its origin.
#[derive(Debug, Clone, PartialEq)]
pub struct Placement {
    pub name: String,
    pub x: f64,
    pub y: f64,
}

fn placement(name: &str, x: f64, y: f64) -> Placement {
    Placement { name: name.to_string(), x, y }
}

/// How far the font reaches above the baseline, in pixels.
pub fn ascent(font: &Font, size: f64) -> f64 {
    font.ascender * size / font.units_per_em
}

/// How far the font reaches below the baseline, in pixels -- a positive
/// number, even though the file stores the descender as a negative one.
pub fn descent(font: &Font, size: f64) -> f64 {
    -font.descender * size / font.units_per_em
}

/// The distance from one baseline to the next: ascent plus descent plus
/// the file's own line gap.
pub fn line_height(font: &Font, size: f64) -> f64 {
    (font.ascender - font.descender + font.line_gap) * size / font.units_per_em
}

/// Walks the pen along a baseline, one placement per character in order,
/// each an advance further along than the last; a character the font
/// lacks places `.notdef`. Kerning, when `true`, is folded in before
/// § 18.2 explains it.
pub fn layout_run(font: &Font, text: &str, size: f64, x: f64, y: f64, kerning: bool) -> Vec<Placement> {
    let s = size / font.units_per_em;
    let mut out = Vec::new();
    let mut pen = x;
    let mut prev: Option<String> = None;
    for ch in text.chars() {
        let name = glyph_name(font, ch as i64);
        if kerning {
            if let Some(p) = &prev {
                pen += kern(font, p, &name) * s;
            }
        }
        out.push(placement(&name, pen, y));
        pen += glyph_advance(font, &name) * s;
        prev = Some(name);
    }
    out
}

/// How far the pen moved in all, laying `text` out the way `layout_run`
/// would.
pub fn run_advance(font: &Font, text: &str, size: f64, kerning: bool) -> f64 {
    let s = size / font.units_per_em;
    let mut total = 0.0;
    let mut prev: Option<String> = None;
    for ch in text.chars() {
        let name = glyph_name(font, ch as i64);
        if kerning {
            if let Some(p) = &prev {
                total += kern(font, p, &name) * s;
            }
        }
        total += glyph_advance(font, &name) * s;
        prev = Some(name);
    }
    total
}

// ---------------------------------------------------------------------
// § 18.2 Kerning
// ---------------------------------------------------------------------

/// The font's kern table, in font units: 0 for a pair it doesn't list
/// (nearly all of them). The order matters -- `kern(f, "A", "T")` and
/// `kern(f, "T", "A")` are different entries.
pub fn kern(font: &Font, left: &str, right: &str) -> f64 {
    *font.kern.get(&(left.to_string(), right.to_string())).unwrap_or(&0.0)
}

// ---------------------------------------------------------------------
// § 18.3 Breaking lines
// ---------------------------------------------------------------------

/// Greedy line breaking: the words are the runs of non-space characters,
/// and each in turn joins the current line if the line with it (one
/// space between) still fits the measure; otherwise it starts a new
/// line. A word wider than the measure sits alone and overflows. Only
/// spaces are break opportunities, so runs of them collapse to one
/// break and a text of nothing but words has no lines.
pub fn break_lines(font: &Font, text: &str, size: f64, measure: f64, kerning: bool) -> Vec<String> {
    let words: Vec<&str> = text.split(' ').filter(|w| !w.is_empty()).collect();
    let mut lines = Vec::new();
    let mut current = String::new();
    for word in words {
        let candidate = if current.is_empty() { word.to_string() } else { format!("{current} {word}") };
        if !current.is_empty() && run_advance(font, &candidate, size, kerning) > measure {
            lines.push(current.clone());
            current = word.to_string();
        } else {
            current = candidate;
        }
    }
    if !current.is_empty() {
        lines.push(current);
    }
    lines
}

// ---------------------------------------------------------------------
// § 18.4 Four alignments
// ---------------------------------------------------------------------

/// `layout_run` plus one of four rules for the slack (the measure minus
/// the line's own `run_advance`): `"left"` leaves it on the right,
/// `"right"` puts it on the left, `"center"` splits it, and `"justify"`
/// spreads it over the line's spaces so the line ends exactly at the
/// measure -- unless the line has no space, which can't be stretched and
/// is laid out left instead.
pub fn layout_line(
    font: &Font,
    text: &str,
    size: f64,
    x: f64,
    y: f64,
    measure: f64,
    align: &str,
    kerning: bool,
) -> Vec<Placement> {
    let mut run = layout_run(font, text, size, x, y, kerning);
    let slack = measure - run_advance(font, text, size, kerning);
    let gaps = text.matches(' ').count();
    if align == "justify" && gaps > 0 {
        let extra = slack / gaps as f64;
        let mut seen = 0usize;
        for (i, ch) in text.chars().enumerate() {
            run[i].x += seen as f64 * extra;
            if ch == ' ' {
                seen += 1;
            }
        }
    } else {
        let shift = match align {
            "right" => slack,
            "center" => slack / 2.0,
            _ => 0.0,
        };
        for p in &mut run {
            p.x += shift;
        }
    }
    run
}

/// Breaks `text` and lays out every line with the same alignment, the
/// first baseline at `y` and each next one `line_height` lower, as one
/// flat list of placements. A justified paragraph's last line is laid
/// out left, since stretching a short last line across the whole measure
/// is how you can tell a text engine was written in a weekend.
pub fn layout_paragraph(
    font: &Font,
    text: &str,
    size: f64,
    x: f64,
    y: f64,
    measure: f64,
    align: &str,
    kerning: bool,
) -> Vec<Placement> {
    let lines = break_lines(font, text, size, measure, kerning);
    let lh = line_height(font, size);
    let mut out = Vec::new();
    for (i, line) in lines.iter().enumerate() {
        let mode = if align == "justify" && i == lines.len() - 1 { "left" } else { align };
        out.extend(layout_line(font, line, size, x, y + i as f64 * lh, measure, mode, kerning));
    }
    out
}

// ---------------------------------------------------------------------
// § 18.5 The seam
// ---------------------------------------------------------------------

/// The seam between layout and rendering: every placement's `x` split by
/// chapter 17's `subpixel_of`, its glyph's bitmap for that quarter
/// painted with the pen at that whole pixel, and the baseline rounded to
/// the nearest pixel row, halves up (chapter 1's `round`).
pub fn draw_run(c: &mut Canvas, font: &Font, run: &[Placement], size: f64, col: Color, linear: bool) {
    for p in run {
        let (whole, sub) = subpixel_of(p.x);
        let b = glyph_bitmap(font, &p.name, size, sub);
        paint_bitmap(c, &b, whole, round(p.y), col, linear);
    }
}

/// The trap: rounding the pen to a whole pixel after every glyph instead
/// of keeping it fractional. Each rounding is off by at most half a
/// pixel, and the errors don't cancel.
fn layout_run_rounded(font: &Font, text: &str, size: f64, x: f64, y: f64) -> Vec<Placement> {
    let s = size / font.units_per_em;
    let mut out = Vec::new();
    let mut pen = x;
    for ch in text.chars() {
        let name = glyph_name(font, ch as i64);
        out.push(placement(&name, pen, y));
        pen = round(pen + glyph_advance(font, &name) * s) as f64;
    }
    out
}

// ---------------------------------------------------------------------
// § 18.6 Putting it together
// ---------------------------------------------------------------------

fn ch18_load_font() -> Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

fn ch18_line(c: &mut Canvas, x0: f64, y0: f64, x1: f64, y1: f64, col: Color, width: f64) {
    let mut p = path();
    move_to(&mut p, point(x0, y0));
    line_to(&mut p, point(x1, y1));
    paint_hairline(c, &p, width, col);
}

fn ch18_vline(c: &mut Canvas, x: f64, y0: f64, y1: f64, col: Color, width: f64) {
    ch18_line(c, x, y0, x, y1, col, width);
}

fn ch18_hline(c: &mut Canvas, x0: f64, x1: f64, y: f64, col: Color, width: f64) {
    ch18_line(c, x0, y, x1, y, col, width);
}

const THROUGH_LINE: &str = "Rasterization computes coverage. Painting composites paint through coverage. Once you hold a coverage buffer, a stroke is a fill of a different outline, a clip is a multiplication of two buffers, and a glyph is a path somebody else drew.";

/// TAVERN at a 64 pixel em, kerned on one baseline and not on the other,
/// with a tick at every pen position and a magenta bracket over what the
/// two runs' widths differ by.
pub fn kern_demo() -> Canvas {
    let font = ch18_load_font();
    let (w, h) = (320usize, 190usize);
    let mut c = canvas(w, h);
    fill(&mut c, CH16_PAPER);
    let size = 64.0;
    let x = 12.0;
    for &(y, kerning) in &[(70.0, true), (160.0, false)] {
        let run = layout_run(&font, "TAVERN", size, x, y, kerning);
        draw_run(&mut c, &font, &run, size, CH16_GRAY, true);
        ch18_hline(&mut c, 4.0, w as f64 - 4.0, y, CH16_DIM, 1.0);
        let end = x + run_advance(&font, "TAVERN", size, kerning);
        let tick_col = if kerning { CH16_CYAN } else { CH16_DIM };
        for p in &run {
            ch18_vline(&mut c, p.x, y + 3.0, y + 12.0, tick_col, 1.0);
        }
        ch18_vline(&mut c, end, y + 3.0, y + 12.0, tick_col, 1.0);
    }
    let kerned_end = x + run_advance(&font, "TAVERN", size, true);
    let plain_end = x + run_advance(&font, "TAVERN", size, false);
    ch18_vline(&mut c, kerned_end, 84.0, 180.0, CH16_MAGENTA, 1.0);
    ch18_vline(&mut c, plain_end, 84.0, 180.0, CH16_MAGENTA, 1.0);
    ch18_hline(&mut c, kerned_end, plain_end, 180.0, CH16_MAGENTA, 1.0);
    c
}

/// The through-line greedily broken into a 300-pixel measure at 16
/// pixels, set left.
pub fn break_demo() -> Canvas {
    let font = ch18_load_font();
    let (w, h) = (340usize, 150usize);
    let mut c = canvas(w, h);
    fill(&mut c, CH16_PAPER);
    let (x, y, measure, size) = (20.0, 30.0, 300.0, 16.0);
    let run = layout_paragraph(&font, THROUGH_LINE, size, x, y, measure, "left", true);
    draw_run(&mut c, &font, &run, size, CH16_GRAY, true);
    ch18_vline(&mut c, x, 10.0, h as f64 - 10.0, CH16_CYAN, 1.0);
    ch18_vline(&mut c, x + measure, 10.0, h as f64 - 10.0, CH16_CYAN, 1.0);
    c
}

/// One line set twice: the pen kept fractional above, rounded to a
/// whole pixel after every glyph below. Magnified by 3.
pub fn drift_demo() -> Canvas {
    let font = ch18_load_font();
    let text = "little illicit lilies fill the hill until it is still";
    let (w, h) = (260usize, 44usize);
    let mut c = canvas(w, h);
    fill(&mut c, color(1.0, 1.0, 1.0));
    let size = 11.0;
    let x = 6.0;
    let exact = layout_run(&font, text, size, x, 14.0, false);
    let rounded = layout_run_rounded(&font, text, size, x, 34.0);
    draw_run(&mut c, &font, &exact, size, color(0.0, 0.0, 0.0), true);
    draw_run(&mut c, &font, &rounded, size, color(0.0, 0.0, 0.0), true);
    let end_exact = x + run_advance(&font, text, size, false);
    let last = rounded.last().expect("text is not empty");
    let end_rounded = last.x + pen_advance(&font, &last.name, size);
    ch18_vline(&mut c, end_exact, 3.0, 18.0, CH16_CYAN, 2.0);
    ch18_vline(&mut c, end_exact, 23.0, 38.0, CH16_CYAN, 2.0);
    ch18_vline(&mut c, end_rounded, 23.0, 38.0, CH16_MAGENTA, 2.0);
    ch18_hline(&mut c, end_exact, end_rounded, 40.0, CH16_MAGENTA, 2.0);
    magnify(&c, 3)
}

/// The through-line at 14 pixels in a 300-pixel measure, set all four
/// ways.
pub fn alignment_plate() -> Canvas {
    let font = ch18_load_font();
    let (w, h) = (660usize, 236usize);
    let mut c = canvas(w, h);
    fill(&mut c, CH16_PAPER);
    let size = 14.0;
    let measure = 300.0;
    let aligns = ["left", "right", "center", "justify"];
    for (k, &align) in aligns.iter().enumerate() {
        let x = 20.0 + (k % 2) as f64 * (measure + 20.0);
        let y = 24.0 + (k / 2) as f64 * 108.0;
        let run = layout_paragraph(&font, THROUGH_LINE, size, x, y, measure, align, true);
        let n = break_lines(&font, THROUGH_LINE, size, measure, true).len();
        let lh = line_height(&font, size);
        for i in 0..n {
            ch18_hline(&mut c, x, x + measure, y + i as f64 * lh, CH16_DIM, 0.5);
        }
        let bottom = y + (n as f64 - 1.0) * lh + 5.0;
        ch18_vline(&mut c, x, y - 14.0, bottom, CH16_CYAN, 0.5);
        ch18_vline(&mut c, x + measure, y - 14.0, bottom, CH16_CYAN, 0.5);
        draw_run(&mut c, &font, &run, size, CH16_GRAY, true);
    }
    c
}

/// Plate 18: `alignment_plate`.
pub fn plate_18() -> Canvas {
    alignment_plate()
}

// =======================================================================
// Chapter 19: Shaping, a Field Guide
// =======================================================================

// ---------------------------------------------------------------------
// § 19.1 Itemizing
// ---------------------------------------------------------------------

/// `"arabic"` for U+0600-U+06FF, `"latin"` for A-Z, a-z and U+00C0-U+024F,
/// `"common"` for everything else (spaces, digits, punctuation), which
/// has no script of its own.
pub fn script_of(codepoint: i64) -> String {
    if (0x600..=0x6FF).contains(&codepoint) {
        "arabic".to_string()
    } else if (0x41..=0x5A).contains(&codepoint)
        || (0x61..=0x7A).contains(&codepoint)
        || (0xC0..=0x24F).contains(&codepoint)
    {
        "latin".to_string()
    } else {
        "common".to_string()
    }
}

/// One run of a single script and direction.
#[derive(Debug, Clone, PartialEq)]
pub struct Item {
    pub start: usize,
    pub end: usize,
    pub text: String,
    pub script: String,
    pub direction: String,
}

fn direction_of(script: &str) -> &'static str {
    if script == "arabic" { "rtl" } else { "ltr" }
}

fn make_item(chars: &[char], start: usize, end: usize, script: &str) -> Item {
    Item {
        start,
        end,
        text: chars[start..end].iter().collect(),
        script: script.to_string(),
        direction: direction_of(script).to_string(),
    }
}

/// Cuts `text` where the script changes; a common character joins the
/// run before it (common characters at the very start join the first
/// run), and text of nothing but common characters is one Latin run.
pub fn itemize(text: &str) -> Vec<Item> {
    let chars: Vec<char> = text.chars().collect();
    let mut items = Vec::new();
    let mut start = 0usize;
    let mut script: Option<String> = None;
    for i in 0..chars.len() {
        let s = script_of(chars[i] as i64);
        if s == "common" {
            continue;
        }
        match &script {
            None => script = Some(s),
            Some(cur) if *cur != s => {
                items.push(make_item(&chars, start, i, cur));
                start = i;
                script = Some(s);
            }
            _ => {}
        }
    }
    if !chars.is_empty() {
        let sc = script.unwrap_or_else(|| "latin".to_string());
        items.push(make_item(&chars, start, chars.len(), &sc));
    }
    items
}

// ---------------------------------------------------------------------
// § 19.2 The glyph buffer, and clusters
// ---------------------------------------------------------------------

/// One glyph in a shaping buffer, carrying the index of the character it
/// came from (its cluster) and a positioning offset in font units, set
/// by mark attachment.
#[derive(Debug, Clone, PartialEq)]
pub struct GlyphEntry {
    pub glyph: String,
    pub cluster: usize,
    pub dx: f64,
    pub dy: f64,
}

fn glyph_entry(glyph: &str, cluster: usize) -> GlyphEntry {
    GlyphEntry { glyph: glyph.to_string(), cluster, dx: 0.0, dy: 0.0 }
}

/// The starting buffer: one entry per character, through the cmap, each
/// its own cluster.
pub fn glyph_buffer(font: &Font, text: &str) -> Vec<GlyphEntry> {
    text.chars().enumerate().map(|(i, ch)| glyph_entry(&glyph_name(font, ch as i64), i)).collect()
}

/// The distinct clusters in the buffer, in order.
pub fn clusters(buffer: &[GlyphEntry]) -> Vec<usize> {
    let mut out: Vec<usize> = Vec::new();
    for e in buffer {
        if !out.contains(&e.cluster) {
            out.push(e.cluster);
        }
    }
    out.sort_unstable();
    out
}

/// Whether `name` is one of the font's mark glyphs.
pub fn is_mark(font: &Font, name: &str) -> bool {
    font.marks.contains_key(name)
}

// ---------------------------------------------------------------------
// § 19.3 Ligatures: substitution
// ---------------------------------------------------------------------

/// Walks the buffer from the left; at each position tries the font's
/// rules, longest first, and when the glyphs there match a rule's parts
/// replaces them with the result, which takes the first part's cluster.
/// The result is never fed back into another rule.
pub fn apply_ligatures(font: &Font, buffer: &[GlyphEntry]) -> Vec<GlyphEntry> {
    let mut rules: Vec<&(Vec<String>, String)> = font.ligatures.iter().collect();
    rules.sort_by(|a, b| b.0.len().cmp(&a.0.len()));
    let mut out = Vec::new();
    let mut i = 0;
    while i < buffer.len() {
        let hit = rules.iter().find(|rule| {
            let parts = &rule.0;
            parts.len() <= buffer.len() - i && parts.iter().enumerate().all(|(k, p)| buffer[i + k].glyph == *p)
        });
        match hit {
            Some(rule) => {
                out.push(glyph_entry(&rule.1, buffer[i].cluster));
                i += rule.0.len();
            }
            None => {
                out.push(buffer[i].clone());
                i += 1;
            }
        }
    }
    out
}

// ---------------------------------------------------------------------
// § 19.4 Arabic: joining, and the four forms
// ---------------------------------------------------------------------

/// Unicode's joining type for a codepoint, `"none"` for one the font
/// doesn't list.
pub fn joining_type(font: &Font, codepoint: i64) -> String {
    font.joining.get(&codepoint.to_string()).cloned().unwrap_or_else(|| "none".to_string())
}

/// A character joins backward when it's dual or right-joining and the
/// nearest non-transparent character before it is dual; forward when
/// it's dual and the nearest non-transparent character after it is dual
/// or right-joining. Both is medial, backward alone final, forward alone
/// initial, neither isolated.
fn form_of(types: &[String], i: usize) -> &'static str {
    let t = &types[i];
    if t == "none" || t == "transparent" {
        return "isol";
    }
    let mut j = i as isize - 1;
    while j >= 0 && types[j as usize] == "transparent" {
        j -= 1;
    }
    let back = (t == "dual" || t == "right") && j >= 0 && types[j as usize] == "dual";
    let mut k = i + 1;
    while k < types.len() && types[k] == "transparent" {
        k += 1;
    }
    let fwd = t == "dual" && k < types.len() && (types[k] == "dual" || types[k] == "right");
    match (back, fwd) {
        (true, true) => "medi",
        (true, false) => "fina",
        (false, true) => "init",
        (false, false) => "isol",
    }
}

/// The form ("isol"/"init"/"medi"/"fina") of every character of `text`.
pub fn arabic_forms(font: &Font, text: &str) -> Vec<String> {
    let types: Vec<String> = text.chars().map(|c| joining_type(font, c as i64)).collect();
    (0..types.len()).map(|i| form_of(&types, i).to_string()).collect()
}

/// Swaps each glyph for its form's glyph when the font's `forms` table
/// has one, leaving it alone otherwise.
pub fn apply_forms(font: &Font, text: &str, buffer: &[GlyphEntry]) -> Vec<GlyphEntry> {
    let forms = arabic_forms(font, text);
    buffer
        .iter()
        .map(|e| {
            let swapped = font
                .forms
                .get(&e.glyph)
                .and_then(|table| forms.get(e.cluster).and_then(|f| table.get(f)))
                .cloned()
                .unwrap_or_else(|| e.glyph.clone());
            GlyphEntry { glyph: swapped, cluster: e.cluster, dx: e.dx, dy: e.dy }
        })
        .collect()
}

// ---------------------------------------------------------------------
// § 19.5 Marks: positioning
// ---------------------------------------------------------------------

/// Finds each mark's base (the nearest non-mark before it), sets the
/// mark's offset to the base's anchor of the mark's class minus the
/// mark's own anchor, and gives the mark the base's cluster. A mark
/// whose base has no anchor of its class, or with no base before it,
/// keeps its own cluster at offset (0, 0).
pub fn attach_marks(font: &Font, buffer: &[GlyphEntry]) -> Vec<GlyphEntry> {
    let mut out = Vec::new();
    let mut base: Option<&GlyphEntry> = None;
    for e in buffer {
        if is_mark(font, &e.glyph) {
            let m = &font.marks[&e.glyph];
            let anchor = base.and_then(|b| font.anchors.get(&b.glyph)).and_then(|t| t.get(&m.0));
            match (base, anchor) {
                (Some(b), Some(a)) => {
                    out.push(GlyphEntry { glyph: e.glyph.clone(), cluster: b.cluster, dx: a.0 - m.1, dy: a.1 - m.2 })
                }
                _ => out.push(glyph_entry(&e.glyph, e.cluster)),
            }
        } else {
            base = Some(e);
            out.push(e.clone());
        }
    }
    out
}

/// The pipeline for one run: the buffer, then forms when the font has a
/// forms table, then ligatures, then marks when the font has a marks
/// table. Roboto has neither, so shaping Latin is ligatures alone.
pub fn shape(font: &Font, text: &str) -> Vec<GlyphEntry> {
    let mut b = glyph_buffer(font, text);
    if !font.forms.is_empty() {
        b = apply_forms(font, text, &b);
    }
    b = apply_ligatures(font, &b);
    if !font.marks.is_empty() {
        b = attach_marks(font, &b);
    }
    b
}

// ---------------------------------------------------------------------
// § 19.6 Positioning, in either direction
// ---------------------------------------------------------------------

/// The pen's total movement laying `buffer` out: every non-mark's
/// advance, plus the kern pair between consecutive non-marks.
pub fn buffer_advance(font: &Font, buffer: &[GlyphEntry], size: f64, kerning: bool) -> f64 {
    let s = size / font.units_per_em;
    let mut total = 0.0;
    let mut prev: Option<&str> = None;
    for e in buffer {
        if is_mark(font, &e.glyph) {
            continue;
        }
        if kerning {
            if let Some(p) = prev {
                total += kern(font, p, &e.glyph) * s;
            }
        }
        total += glyph_advance(font, &e.glyph) * s;
        prev = Some(&e.glyph);
    }
    total
}

/// Turns a shaped buffer into chapter 18's placements, one per entry in
/// the buffer's own order. For `"ltr"` the pen starts at `x` and walks
/// right, kern pairs included; for `"rtl"` it starts at `x` plus the
/// buffer's advance and walks left, so the first entry lands at the
/// right end and the run still occupies `x` to `x + advance`. A mark
/// never moves the pen: it's placed at its base's origin plus its
/// offset, scaled to pixels, `dy` turned over.
pub fn position(
    font: &Font,
    buffer: &[GlyphEntry],
    size: f64,
    x: f64,
    y: f64,
    direction: &str,
    kerning: bool,
) -> Vec<Placement> {
    let s = size / font.units_per_em;
    let mut out = Vec::with_capacity(buffer.len());
    let mut pen = if direction == "ltr" { x } else { x + buffer_advance(font, buffer, size, kerning) };
    let mut base_x = x;
    let mut prev: Option<&str> = None;
    for e in buffer {
        if is_mark(font, &e.glyph) {
            out.push(placement(&e.glyph, base_x + e.dx * s, y - e.dy * s));
            continue;
        }
        let adv = glyph_advance(font, &e.glyph) * s;
        let k = if kerning { prev.map(|p| kern(font, p, &e.glyph) * s).unwrap_or(0.0) } else { 0.0 };
        if direction == "ltr" {
            pen += k;
            base_x = pen;
            pen += adv;
        } else {
            pen -= k;
            pen -= adv;
            base_x = pen;
        }
        out.push(placement(&e.glyph, base_x, y));
        prev = Some(&e.glyph);
    }
    out
}

/// The character offsets a cursor may stand at: every cluster start,
/// then the text's own length.
pub fn caret_offsets(buffer: &[GlyphEntry], length: usize) -> Vec<usize> {
    let mut out = clusters(buffer);
    out.push(length);
    out
}

/// The `x` of each caret offset, in the same order: the pen where each
/// cluster's first (non-mark) glyph was placed, then the pen after the
/// last glyph. For `"rtl"` the first position is the run's right end and
/// the last is `x`.
pub fn caret_positions(
    font: &Font,
    buffer: &[GlyphEntry],
    _length: usize,
    size: f64,
    x: f64,
    direction: &str,
    kerning: bool,
) -> Vec<f64> {
    let run = position(font, buffer, size, x, 0.0, direction, kerning);
    let s = size / font.units_per_em;
    let mut out = Vec::new();
    for cl in clusters(buffer) {
        let non_mark = buffer.iter().position(|e| e.cluster == cl && !is_mark(font, &e.glyph));
        if let Some(i) = non_mark {
            let v = if direction == "ltr" { run[i].x } else { run[i].x + glyph_advance(font, &buffer[i].glyph) * s };
            out.push(v);
        } else if let Some(j) = buffer.iter().position(|e| e.cluster == cl) {
            out.push(run[j].x);
        }
    }
    let total = buffer_advance(font, buffer, size, kerning);
    out.push(if direction == "ltr" { x + total } else { x });
    out
}

// ---------------------------------------------------------------------
// § 19.8 Putting it together
// ---------------------------------------------------------------------

fn ch19_load_arabic() -> Font {
    load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
}

const KITAB: &str = "كِتاب";

fn ch19_box(c: &mut Canvas, x0: f64, y0: f64, x1: f64, y1: f64, col: Color, width: f64) {
    let poly = polygon(&[point(x0, y0), point(x1, y0), point(x1, y1), point(x0, y1)]);
    paint_hairline(c, &poly, width, col);
}

fn draw_shaped(
    c: &mut Canvas,
    font: &Font,
    buffer: &[GlyphEntry],
    size: f64,
    x: f64,
    y: f64,
    direction: &str,
    kerning: bool,
    col: Color,
    mark_col: Color,
) -> Vec<Placement> {
    let run = position(font, buffer, size, x, y, direction, kerning);
    for (e, p) in buffer.iter().zip(run.iter()) {
        let ink = if is_mark(font, &e.glyph) { mark_col } else { col };
        draw_run(c, font, std::slice::from_ref(p), size, ink, true);
    }
    run
}

fn draw_carets(
    c: &mut Canvas,
    font: &Font,
    buffer: &[GlyphEntry],
    size: f64,
    x: f64,
    direction: &str,
    kerning: bool,
    length: usize,
    y0: f64,
    y1: f64,
    col: Color,
) {
    for cx in caret_positions(font, buffer, length, size, x, direction, kerning) {
        ch18_vline(c, cx, y0, y1, col, 1.0);
    }
}

fn cluster_of_char(buffer: &[GlyphEntry], i: usize) -> usize {
    buffer.iter().filter(|e| e.cluster <= i).map(|e| e.cluster).max().expect("buffer is not empty")
}

/// `office` shaped in Roboto and positioned, the `f_i` ligature in
/// magenta, with a cyan tick at every caret position.
pub fn ligature_demo() -> Canvas {
    let font = ch18_load_font();
    let (w, h) = (260usize, 100usize);
    let mut c = canvas(w, h);
    fill(&mut c, CH16_PAPER);
    let (size, x, y) = (64.0, 20.0, 70.0);
    let text = "office";
    let buffer = shape(&font, text);
    let run = position(&font, &buffer, size, x, y, "ltr", true);
    ch18_hline(&mut c, 4.0, w as f64 - 4.0, y, CH16_DIM, 1.0);
    for (e, p) in buffer.iter().zip(run.iter()) {
        let col = if e.glyph == "f_i" { CH16_MAGENTA } else { CH16_GRAY };
        draw_run(&mut c, &font, std::slice::from_ref(p), size, col, true);
    }
    draw_carets(&mut c, &font, &buffer, size, x, "ltr", true, text.chars().count(), y + 4.0, y + 16.0, CH16_CYAN);
    c
}

/// `beh` in its four forms, each captioned by chapter 18's `layout_run`
/// in Roboto.
pub fn forms_demo() -> Canvas {
    let ar = ch19_load_arabic();
    let lat = ch18_load_font();
    let (w, h) = (320usize, 110usize);
    let mut c = canvas(w, h);
    fill(&mut c, CH16_PAPER);
    let size = 64.0;
    let y = 60.0;
    let names = ["beh", "beh.init", "beh.medi", "beh.fina"];
    let labels = ["isol", "init", "medi", "fina"];
    for k in 0..names.len() {
        let x = 16.0 + k as f64 * 76.0;
        ch18_hline(&mut c, x - 4.0, x + 68.0, y, CH16_DIM, 1.0);
        let p = placement(names[k], x, y);
        draw_run(&mut c, &ar, std::slice::from_ref(&p), size, CH16_GRAY, true);
        let run = layout_run(&lat, labels[k], 11.0, x, y + 30.0, true);
        draw_run(&mut c, &lat, &run, 11.0, CH16_CYAN, true);
    }
    c
}

/// كِتاب, shaped in DejaVu Sans and positioned right to left, the letters
/// gray and the mark magenta.
pub fn word_demo() -> Canvas {
    let font = ch19_load_arabic();
    let (w, h) = (260usize, 100usize);
    let mut c = canvas(w, h);
    fill(&mut c, CH16_PAPER);
    let (size, x, y) = (64.0, 20.0, 64.0);
    let buffer = shape(&font, KITAB);
    ch18_hline(&mut c, 4.0, w as f64 - 4.0, y, CH16_DIM, 1.0);
    draw_shaped(&mut c, &font, &buffer, size, x, y, "rtl", false, CH16_GRAY, CH16_MAGENTA);
    draw_carets(&mut c, &font, &buffer, size, x, "rtl", false, KITAB.chars().count(), y + 4.0, y + 16.0, CH16_CYAN);
    c
}

/// "Book: كِتاب, again." itemized, each item shaped in its own script's
/// font and placed one after another -- the trap: the comma follows the
/// Arabic word and comes out on its left.
pub fn mixed_demo() -> Canvas {
    let lat = ch18_load_font();
    let ar = ch19_load_arabic();
    let (w, h) = (300usize, 60usize);
    let mut c = canvas(w, h);
    fill(&mut c, CH16_PAPER);
    let size = 28.0;
    let y = 40.0;
    let text = format!("Book: {KITAB}, again.");
    ch18_hline(&mut c, 4.0, w as f64 - 4.0, y, CH16_DIM, 1.0);
    let mut pen = 12.0;
    for item in itemize(&text) {
        let font = if item.script == "arabic" { &ar } else { &lat };
        let buffer = shape(font, &item.text);
        ch18_vline(&mut c, pen, y + 3.0, y + 10.0, CH16_CYAN, 1.0);
        draw_shaped(&mut c, font, &buffer, size, pen, y, &item.direction, true, CH16_GRAY, CH16_MAGENTA);
        pen += buffer_advance(font, &buffer, size, true);
    }
    c
}

/// Characters in on top, one glyph each straight from the cmap; glyphs
/// out on the bottom, shaped and positioned; a line from each character
/// to the cluster it ended up in.
pub fn cluster_plate() -> Canvas {
    let lat = ch18_load_font();
    let ar = ch19_load_arabic();
    let (w, h) = (540usize, 210usize);
    let mut c = canvas(w, h);
    fill(&mut c, CH16_PAPER);
    let size = 52.0;
    let bands: [(&Font, &str, &str, f64); 2] = [(&lat, "office", "ltr", 20.0), (&ar, KITAB, "rtl", 290.0)];
    for (font, text, direction, x) in bands {
        let (y_top, y_bot) = (80.0, 180.0);
        let s = size / font.units_per_em;
        let raw = glyph_buffer(font, text);
        let mut centers = Vec::new();
        let mut pen = x;
        for e in &raw {
            let adv = glyph_advance(font, &e.glyph) * s;
            let width = adv.max(12.0);
            ch19_box(&mut c, pen, y_top - 46.0, pen + width, y_top + 12.0, CH16_DIM, 1.0);
            let p = placement(&e.glyph, pen + (width - adv) / 2.0, y_top);
            draw_run(&mut c, font, std::slice::from_ref(&p), size, CH16_GRAY, true);
            centers.push(pen + width / 2.0);
            pen += width + 14.0;
        }

        let buffer = shape(font, text);
        let run = position(font, &buffer, size, x, y_bot, direction, true);
        let mut boxes: HashMap<usize, (f64, f64)> = HashMap::new();
        for (e, p) in buffer.iter().zip(run.iter()) {
            if is_mark(font, &e.glyph) {
                continue;
            }
            let adv = glyph_advance(font, &e.glyph) * s;
            let entry = boxes.entry(e.cluster).or_insert((p.x, p.x + adv));
            entry.0 = entry.0.min(p.x);
            entry.1 = entry.1.max(p.x + adv);
        }

        let raw_names: Vec<&str> = raw.iter().map(|e| e.glyph.as_str()).collect();
        for (e, p) in buffer.iter().zip(run.iter()) {
            let changed = is_mark(font, &e.glyph) || !raw_names.contains(&e.glyph.as_str());
            let ink = if changed { CH16_MAGENTA } else { CH16_GRAY };
            draw_run(&mut c, font, std::slice::from_ref(p), size, ink, true);
        }

        let mut cluster_keys: Vec<usize> = boxes.keys().copied().collect();
        cluster_keys.sort_unstable();
        for cl in &cluster_keys {
            let (lo, hi) = boxes[cl];
            ch19_box(&mut c, lo, y_bot - 46.0, hi, y_bot + 12.0, CH16_CYAN, 1.0);
        }

        for i in 0..text.chars().count() {
            let cl = cluster_of_char(&buffer, i);
            let (lo, hi) = boxes[&cl];
            ch18_line(&mut c, centers[i], y_top + 12.0, (lo + hi) / 2.0, y_bot - 46.0, CH16_MAGENTA, 0.75);
        }
    }
    c
}

/// Plate 19: `cluster_plate`.
pub fn plate_19() -> Canvas {
    cluster_plate()
}

// =======================================================================
// Chapter 20: Rendering SVG
// =======================================================================

// ---------------------------------------------------------------------
// § 20.1 The document
// ---------------------------------------------------------------------

/// One XML element, owned: its local name (namespace prefix taken off),
/// its attributes as written (in document order, local names), and its
/// child elements in order -- text and comments between them dropped.
/// roxmltree does the parsing; this is the four things the chapter asks
/// of what it hands back, in a form that outlives the text.
#[derive(Debug, Clone)]
pub struct Element {
    pub name: String,
    pub attributes: Vec<(String, String)>,
    pub children: Vec<Element>,
}

fn element_from_node(node: roxmltree::Node) -> Element {
    Element {
        name: node.tag_name().name().to_string(),
        attributes: node.attributes().map(|a| (a.name().to_string(), a.value().to_string())).collect(),
        children: node.children().filter(|c| c.is_element()).map(element_from_node).collect(),
    }
}

/// The document's root element. Panics on text that isn't XML: every
/// document the book parses is well-formed, and a renderer handed garbage
/// has nothing sensible to draw.
pub fn parse_xml(text: &str) -> Element {
    let doc = roxmltree::Document::parse(text).unwrap_or_else(|e| panic!("parse_xml: {e}"));
    element_from_node(doc.root_element())
}

/// An attribute's text exactly as written, or `None`.
pub fn attribute<'a>(el: &'a Element, name: &str) -> Option<&'a str> {
    el.attributes.iter().find(|(n, _)| n == name).map(|(_, v)| v.as_str())
}

/// The child elements, in document order.
pub fn children(el: &Element) -> &[Element] {
    &el.children
}

/// The element anywhere under (and including) `root` whose id is `id`,
/// depth first in document order, or `None`.
pub fn find_by_id<'a>(root: &'a Element, id: &str) -> Option<&'a Element> {
    if attribute(root, "id") == Some(id) {
        return Some(root);
    }
    root.children.iter().find_map(|c| find_by_id(c, id))
}

// ---------------------------------------------------------------------
// § 20.2 Numbers
// ---------------------------------------------------------------------

/// Reads the number starting at byte `i` of `s`: an optional sign, digits,
/// an optional point and more digits (at least one digit somewhere), and
/// an optional exponent that counts only when a digit follows the `e`
/// (after an optional sign). Answers the number and the index just past
/// it, or `(None, i)` when there's no number there.
pub fn read_number(s: &str, i: usize) -> (Option<f64>, usize) {
    let b = s.as_bytes();
    let n = b.len();
    let mut j = i;
    if j < n && (b[j] == b'+' || b[j] == b'-') {
        j += 1;
    }
    let int_start = j;
    while j < n && b[j].is_ascii_digit() {
        j += 1;
    }
    let int_digits = j - int_start;
    let mut frac_digits = 0;
    if j < n && b[j] == b'.' {
        let mut k = j + 1;
        while k < n && b[k].is_ascii_digit() {
            k += 1;
        }
        frac_digits = k - (j + 1);
        if int_digits + frac_digits > 0 {
            j = k;
        }
    }
    if int_digits + frac_digits == 0 {
        return (None, i);
    }
    if j < n && (b[j] == b'e' || b[j] == b'E') {
        let mut k = j + 1;
        if k < n && (b[k] == b'+' || b[k] == b'-') {
            k += 1;
        }
        if k < n && b[k].is_ascii_digit() {
            while k < n && b[k].is_ascii_digit() {
                k += 1;
            }
            j = k;
        }
    }
    match s[i..j].parse::<f64>() {
        Ok(v) => (Some(v), j),
        Err(_) => (None, i),
    }
}

fn is_wsp(c: u8) -> bool {
    c == b' ' || c == b'\t' || c == b'\r' || c == b'\n'
}

fn skip_wsp(b: &[u8], i: &mut usize) {
    while *i < b.len() && is_wsp(b[*i]) {
        *i += 1;
    }
}

/// Whitespace, at most one comma, whitespace.
fn skip_comma_wsp(b: &[u8], i: &mut usize) {
    skip_wsp(b, i);
    if *i < b.len() && b[*i] == b',' {
        *i += 1;
        skip_wsp(b, i);
    }
}

/// `number_list`, also answering where it stopped, so a caller can tell
/// whether the whole string was numbers.
fn number_list_end(s: &str) -> (Vec<f64>, usize) {
    let b = s.as_bytes();
    let mut out = Vec::new();
    let mut i = 0;
    skip_wsp(b, &mut i);
    let mut end = i;
    loop {
        let mut j = i;
        if !out.is_empty() {
            skip_comma_wsp(b, &mut j);
        }
        match read_number(s, j) {
            (Some(v), k) => {
                out.push(v);
                i = k;
                end = k;
            }
            (None, _) => break,
        }
    }
    let mut e = end;
    skip_wsp(b, &mut e);
    (out, e)
}

/// As many numbers as can be read, separated by whitespace and at most one
/// comma, stopping at the first thing that isn't one.
pub fn number_list(s: &str) -> Vec<f64> {
    number_list_end(s).0
}

/// An arc flag: exactly one character, `0` or `1`, needing no separator
/// after it.
pub fn read_flag(s: &str, i: usize) -> (Option<f64>, usize) {
    match s.as_bytes().get(i) {
        Some(b'0') => (Some(0.0), i + 1),
        Some(b'1') => (Some(1.0), i + 1),
        _ => (None, i),
    }
}

// ---------------------------------------------------------------------
// § 20.3 Path data
// ---------------------------------------------------------------------

/// One path command in the chapter's normal form: `op` is one of `M L C Q
/// A Z`, every coordinate absolute.
#[derive(Debug, Clone)]
pub struct Command {
    pub op: &'static str,
    pub args: Vec<f64>,
}

fn is_command_letter(c: u8) -> bool {
    b"MmLlHhVvCcSsQqTtAaZz".contains(&c)
}

fn starts_number(c: u8) -> bool {
    c.is_ascii_digit() || c == b'+' || c == b'-' || c == b'.'
}

/// Reads one argument group: `kinds` is one byte per argument, `n` for a
/// number and `f` for a flag. The first argument of the first group after
/// a letter may be preceded by whitespace only; every other by
/// comma-whitespace (the caller has already skipped it for the first
/// argument of a repeat).
fn read_group(d: &str, i: &mut usize, kinds: &[u8], first_group: bool) -> Option<Vec<f64>> {
    let b = d.as_bytes();
    let mut j = *i;
    let mut args = Vec::with_capacity(kinds.len());
    for (k, &kind) in kinds.iter().enumerate() {
        if k == 0 {
            if first_group {
                skip_wsp(b, &mut j);
            }
        } else {
            skip_comma_wsp(b, &mut j);
        }
        let (v, next) = if kind == b'f' { read_flag(d, j) } else { read_number(d, j) };
        args.push(v?);
        j = next;
    }
    *i = j;
    Some(args)
}

/// Turns a `d` attribute into commands, absolute, in six ops only. H/V
/// become L, S/T become C/Q with the borrowed control point filled in,
/// repeats are spelled out (repeats of M are L), Z returns the current
/// point to the subpath's start, arc radii come back as absolute values.
/// At the first thing that can't be read, the commands so far are the
/// answer; a path that doesn't start with M/m is no path.
pub fn path_commands(d: &str) -> Vec<Command> {
    let b = d.as_bytes();
    let n = b.len();
    let mut out: Vec<Command> = Vec::new();
    let mut i = 0;
    skip_wsp(b, &mut i);
    if i >= n || !(b[i] == b'M' || b[i] == b'm') {
        return out;
    }
    let (mut cx, mut cy, mut sx, mut sy) = (0.0f64, 0.0f64, 0.0f64, 0.0f64);
    let mut prev_cubic: Option<(f64, f64)> = None;
    let mut prev_quad: Option<(f64, f64)> = None;
    loop {
        skip_wsp(b, &mut i);
        if i >= n || !is_command_letter(b[i]) {
            break;
        }
        let letter = b[i];
        i += 1;
        let rel = letter.is_ascii_lowercase();
        let mut up = letter.to_ascii_uppercase();
        if up == b'Z' {
            out.push(Command { op: "Z", args: vec![] });
            cx = sx;
            cy = sy;
            prev_cubic = None;
            prev_quad = None;
            continue;
        }
        let kinds: &[u8] = match up {
            b'M' | b'L' | b'T' => b"nn",
            b'H' | b'V' => b"n",
            b'C' => b"nnnnnn",
            b'S' | b'Q' => b"nnnn",
            b'A' => b"nnnffnn",
            _ => unreachable!(),
        };
        let mut first = true;
        loop {
            if !first {
                let mut j = i;
                skip_comma_wsp(b, &mut j);
                if j >= n || !starts_number(b[j]) {
                    break;
                }
                i = j;
            }
            let a = match read_group(d, &mut i, kinds, first) {
                Some(a) => a,
                None => return out,
            };
            let (ox, oy) = if rel { (cx, cy) } else { (0.0, 0.0) };
            let (mut next_cubic, mut next_quad) = (None, None);
            match up {
                b'M' => {
                    cx = a[0] + ox;
                    cy = a[1] + oy;
                    sx = cx;
                    sy = cy;
                    out.push(Command { op: "M", args: vec![cx, cy] });
                }
                b'L' => {
                    cx = a[0] + ox;
                    cy = a[1] + oy;
                    out.push(Command { op: "L", args: vec![cx, cy] });
                }
                b'H' => {
                    cx = a[0] + ox;
                    out.push(Command { op: "L", args: vec![cx, cy] });
                }
                b'V' => {
                    cy = a[0] + oy;
                    out.push(Command { op: "L", args: vec![cx, cy] });
                }
                b'C' => {
                    let args = vec![a[0] + ox, a[1] + oy, a[2] + ox, a[3] + oy, a[4] + ox, a[5] + oy];
                    next_cubic = Some((args[2], args[3]));
                    cx = args[4];
                    cy = args[5];
                    out.push(Command { op: "C", args });
                }
                b'S' => {
                    let (x1, y1) = match prev_cubic {
                        Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py),
                        None => (cx, cy),
                    };
                    let args = vec![x1, y1, a[0] + ox, a[1] + oy, a[2] + ox, a[3] + oy];
                    next_cubic = Some((args[2], args[3]));
                    cx = args[4];
                    cy = args[5];
                    out.push(Command { op: "C", args });
                }
                b'Q' => {
                    let args = vec![a[0] + ox, a[1] + oy, a[2] + ox, a[3] + oy];
                    next_quad = Some((args[0], args[1]));
                    cx = args[2];
                    cy = args[3];
                    out.push(Command { op: "Q", args });
                }
                b'T' => {
                    let (x1, y1) = match prev_quad {
                        Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py),
                        None => (cx, cy),
                    };
                    let args = vec![x1, y1, a[0] + ox, a[1] + oy];
                    next_quad = Some((x1, y1));
                    cx = args[2];
                    cy = args[3];
                    out.push(Command { op: "Q", args });
                }
                b'A' => {
                    cx = a[5] + ox;
                    cy = a[6] + oy;
                    out.push(Command { op: "A", args: vec![a[0].abs(), a[1].abs(), a[2], a[3], a[4], cx, cy] });
                }
                _ => unreachable!(),
            }
            prev_cubic = next_cubic;
            prev_quad = next_quad;
            first = false;
            if up == b'M' {
                up = b'L';
            }
        }
    }
    out
}

// ---------------------------------------------------------------------
// § 20.4 From commands to a path
// ---------------------------------------------------------------------

/// An SVG arc as cubics: chapter 8's `arc` finds the center form (the
/// angle arrives in degrees), the swept angle is cut into `n = max(1,
/// ceil(|delta| / (pi/2) - 0.000001))` equal pieces, and each piece gets
/// handles `4/3 tan(d/4)` along the tangents, on the ellipse's own axes.
/// The first cubic starts exactly at `(x1, y1)`, the last ends exactly at
/// `(x2, y2)`. Coincident endpoints give nothing; a zero radius gives one
/// straight cubic with its handles at the thirds of the chord.
pub fn arc_cubics(x1: f64, y1: f64, rx: f64, ry: f64, angle: f64, large: bool, sweep: bool, x2: f64, y2: f64) -> Vec<Curve> {
    if x1 == x2 && y1 == y2 {
        return vec![];
    }
    let p1 = point(x1, y1);
    let p2 = point(x2, y2);
    if rx == 0.0 || ry == 0.0 {
        let d = p2 - p1;
        return vec![cubic(p1, p1 + d / 3.0, p1 + d * (2.0 / 3.0), p2)];
    }
    let a = match arc(x1, y1, rx.abs(), ry.abs(), angle.to_radians(), large, sweep, x2, y2) {
        Some(a) => a,
        None => return vec![],
    };
    let n = ((a.delta.abs() / (std::f64::consts::PI / 2.0) - 0.000001).ceil() as usize).max(1);
    let d = a.delta / n as f64;
    let k = 4.0 / 3.0 * (d / 4.0).tan();
    let (cphi, sphi) = (a.phi.cos(), a.phi.sin());
    let on_ellipse = |ux: f64, uy: f64| {
        let ex = a.rx * ux;
        let ey = a.ry * uy;
        point(a.cx + cphi * ex - sphi * ey, a.cy + sphi * ex + cphi * ey)
    };
    let mut out = Vec::with_capacity(n);
    let mut start = p1;
    for i in 0..n {
        let t0 = a.theta1 + d * i as f64;
        let t1 = a.theta1 + d * (i + 1) as f64;
        let (c0, s0) = (t0.cos(), t0.sin());
        let (c1, s1) = (t1.cos(), t1.sin());
        let h1 = on_ellipse(c0 - k * s0, s0 + k * c0);
        let h2 = on_ellipse(c1 + k * s1, s1 - k * c1);
        let end = if i == n - 1 { p2 } else { on_ellipse(c1, s1) };
        out.push(cubic(start, h1, h2, end));
        start = end;
    }
    out
}

fn arc_command_cubics(from: Tuple, a: &[f64]) -> Vec<Curve> {
    arc_cubics(from.x, from.y, a[0], a[1], a[2], a[3] != 0.0, a[4] != 0.0, a[5], a[6])
}

/// Walks the commands with a current point and builds a chapter 5 path in
/// device space: points through `m`; curves through `m` and then
/// flattened (chapter 8's order); arcs as `arc_cubics`; Z is a close. A
/// subpath that's nothing but its moveto is dropped.
pub fn build_path(cmds: &[Command], m: Matrix3, tolerance: f64) -> Path {
    let mut p = path();
    let mut cur = point(0.0, 0.0);
    let mut start = cur;
    for c in cmds {
        let a = &c.args;
        match c.op {
            "M" => {
                cur = point(a[0], a[1]);
                start = cur;
                move_to(&mut p, m * cur);
            }
            "L" => {
                cur = point(a[0], a[1]);
                line_to(&mut p, m * cur);
            }
            "C" => {
                let cv = cubic(cur, point(a[0], a[1]), point(a[2], a[3]), point(a[4], a[5]));
                flatten_into_path(&mut p, &transform_curve(&cv, m), tolerance);
                cur = point(a[4], a[5]);
            }
            "Q" => {
                let cv = quadratic(cur, point(a[0], a[1]), point(a[2], a[3]));
                flatten_into_path(&mut p, &transform_curve(&cv, m), tolerance);
                cur = point(a[2], a[3]);
            }
            "A" => {
                for cv in arc_command_cubics(cur, a) {
                    flatten_into_path(&mut p, &transform_curve(&cv, m), tolerance);
                }
                cur = point(a[5], a[6]);
            }
            "Z" => {
                close(&mut p);
                cur = start;
            }
            other => panic!("build_path: unknown op {other}"),
        }
    }
    p.subpaths.retain(|sp| sp.points.len() > 1 || sp.closed);
    p
}

/// The tight box of the geometry in user space: every M and L point and
/// chapter 8's `curve_bounds` of every curve (arcs as their cubics);
/// `(0, 0, 0, 0)` when there's nothing.
pub fn commands_bounds(cmds: &[Command]) -> (f64, f64, f64, f64) {
    let mut bb: Option<(f64, f64, f64, f64)> = None;
    let mut add = |b: (f64, f64, f64, f64)| {
        bb = Some(match bb {
            None => b,
            Some(o) => (o.0.min(b.0), o.1.min(b.1), o.2.max(b.2), o.3.max(b.3)),
        });
    };
    let mut cur = point(0.0, 0.0);
    let mut start = cur;
    for c in cmds {
        let a = &c.args;
        match c.op {
            "M" | "L" => {
                cur = point(a[0], a[1]);
                if c.op == "M" {
                    start = cur;
                }
                add((cur.x, cur.y, cur.x, cur.y));
            }
            "C" => {
                add(curve_bounds(&cubic(cur, point(a[0], a[1]), point(a[2], a[3]), point(a[4], a[5]))));
                cur = point(a[4], a[5]);
            }
            "Q" => {
                add(curve_bounds(&quadratic(cur, point(a[0], a[1]), point(a[2], a[3]))));
                cur = point(a[2], a[3]);
            }
            "A" => {
                for cv in arc_command_cubics(cur, a) {
                    add(curve_bounds(&cv));
                }
                cur = point(a[5], a[6]);
            }
            _ => cur = start,
        }
    }
    bb.unwrap_or((0.0, 0.0, 0.0, 0.0))
}

// ---------------------------------------------------------------------
// § 20.5 The transform attribute
// ---------------------------------------------------------------------

fn transform_function(name: &str, v: &[f64]) -> Option<Matrix3> {
    let rad = |d: f64| d.to_radians();
    Some(match (name, v.len()) {
        ("matrix", 6) => matrix3(v[0], v[2], v[4], v[1], v[3], v[5], 0.0, 0.0, 1.0),
        ("translate", 1) => translation(v[0], 0.0),
        ("translate", 2) => translation(v[0], v[1]),
        ("scale", 1) => scaling(v[0], v[0]),
        ("scale", 2) => scaling(v[0], v[1]),
        ("rotate", 1) => rotation(rad(v[0])),
        ("rotate", 3) => translation(v[1], v[2]) * rotation(rad(v[0])) * translation(-v[1], -v[2]),
        ("skewX", 1) => shearing(rad(v[0]).tan(), 0.0),
        ("skewY", 1) => shearing(0.0, rad(v[0]).tan()),
        _ => return None,
    })
}

/// A transform list as one matrix, the functions multiplied left to right
/// (so the rightmost touches a point first). Missing, empty, or anything
/// that doesn't parse is the identity.
pub fn parse_transform(s: Option<&str>) -> Matrix3 {
    let s = match s {
        Some(s) => s,
        None => return identity(),
    };
    let b = s.as_bytes();
    let mut i = 0;
    let mut m = identity();
    loop {
        while i < b.len() && (is_wsp(b[i]) || b[i] == b',') {
            i += 1;
        }
        if i >= b.len() {
            return m;
        }
        let name_start = i;
        while i < b.len() && b[i].is_ascii_alphabetic() {
            i += 1;
        }
        let name = &s[name_start..i];
        if name.is_empty() {
            return identity();
        }
        skip_wsp(b, &mut i);
        if i >= b.len() || b[i] != b'(' {
            return identity();
        }
        let close_at = match s[i..].find(')') {
            Some(k) => i + k,
            None => return identity(),
        };
        let inside = &s[i + 1..close_at];
        let (nums, end) = number_list_end(inside);
        if end != inside.len() {
            return identity();
        }
        match transform_function(name, &nums) {
            Some(f) => m = m * f,
            None => return identity(),
        }
        i = close_at + 1;
    }
}

// ---------------------------------------------------------------------
// § 20.6 Colours and the cascade
// ---------------------------------------------------------------------

const COLOR_NAMES: [(&str, [u8; 3]); 17] = [
    ("black", [0, 0, 0]),
    ("silver", [192, 192, 192]),
    ("gray", [128, 128, 128]),
    ("white", [255, 255, 255]),
    ("maroon", [128, 0, 0]),
    ("red", [255, 0, 0]),
    ("purple", [128, 0, 128]),
    ("fuchsia", [255, 0, 255]),
    ("green", [0, 128, 0]),
    ("lime", [0, 255, 0]),
    ("olive", [128, 128, 0]),
    ("yellow", [255, 255, 0]),
    ("navy", [0, 0, 128]),
    ("blue", [0, 0, 255]),
    ("teal", [0, 128, 128]),
    ("aqua", [0, 255, 255]),
    ("orange", [255, 165, 0]),
];

fn color_from_bytes(r: f64, g: f64, b: f64) -> Color {
    color(decode(r / 255.0), decode(g / 255.0), decode(b / 255.0))
}

/// A colour as the file writes it (sRGB bytes), answered in linear light:
/// `#rgb`, `#rrggbb`, `rgb(r, g, b)` with numbers 0-255 or percentages,
/// clamped, and the seventeen names. Anything else is `None`.
pub fn parse_color(s: &str) -> Option<Color> {
    let v = s.trim().to_ascii_lowercase();
    if let Some(hex) = v.strip_prefix('#') {
        if !hex.bytes().all(|c| c.is_ascii_hexdigit()) {
            return None;
        }
        let digit = |i: usize| u8::from_str_radix(&hex[i..i + 1], 16).unwrap() as f64;
        return match hex.len() {
            3 => Some(color_from_bytes(digit(0) * 17.0, digit(1) * 17.0, digit(2) * 17.0)),
            6 => Some(color_from_bytes(
                digit(0) * 16.0 + digit(1),
                digit(2) * 16.0 + digit(3),
                digit(4) * 16.0 + digit(5),
            )),
            _ => None,
        };
    }
    if let Some(rest) = v.strip_prefix("rgb") {
        let rest = rest.trim_start();
        let inner = rest.strip_prefix('(')?.strip_suffix(')')?;
        let parts: Vec<&str> = inner.split(',').map(|p| p.trim()).collect();
        if parts.len() != 3 {
            return None;
        }
        let mut ch = [0.0; 3];
        for (k, part) in parts.iter().enumerate() {
            let (num, end) = read_number(part, 0);
            let num = num?;
            let tail = &part[end..];
            let byte = match tail {
                "" => num,
                "%" => num / 100.0 * 255.0,
                _ => return None,
            };
            ch[k] = byte.clamp(0.0, 255.0);
        }
        return Some(color_from_bytes(ch[0], ch[1], ch[2]));
    }
    COLOR_NAMES
        .iter()
        .find(|(n, _)| *n == v)
        .map(|(_, b)| color_from_bytes(b[0] as f64, b[1] as f64, b[2] as f64))
}

/// What a fill or stroke is: nothing, a colour, or a reference to a paint
/// server elsewhere in the document, kept as the text `url(#id)`.
#[derive(Debug, Clone, PartialEq)]
pub enum SvgPaint {
    None,
    Color(Color),
    Url(String),
}

/// Every property the book reads, computed.
#[derive(Debug, Clone)]
pub struct Style {
    pub fill: SvgPaint,
    pub fill_opacity: f64,
    pub fill_rule: String,
    pub stroke: SvgPaint,
    pub stroke_width: f64,
    pub stroke_opacity: f64,
    pub stroke_linecap: String,
    pub stroke_linejoin: String,
    pub stroke_miterlimit: f64,
    pub stroke_dasharray: Option<Vec<f64>>,
    pub stroke_dashoffset: f64,
    pub clip_rule: String,
    pub opacity: f64,
    pub clip_path: Option<String>,
    pub stop_color: Color,
}

/// Every property at its initial value: the parent of the root.
pub fn initial_style() -> Style {
    Style {
        fill: SvgPaint::Color(color(0.0, 0.0, 0.0)),
        fill_opacity: 1.0,
        fill_rule: "nonzero".to_string(),
        stroke: SvgPaint::None,
        stroke_width: 1.0,
        stroke_opacity: 1.0,
        stroke_linecap: "butt".to_string(),
        stroke_linejoin: "miter".to_string(),
        stroke_miterlimit: 4.0,
        stroke_dasharray: None,
        stroke_dashoffset: 0.0,
        clip_rule: "nonzero".to_string(),
        opacity: 1.0,
        clip_path: None,
        stop_color: color(0.0, 0.0, 0.0),
    }
}

/// A number, optionally followed by `px`, and nothing else.
fn parse_length(v: &str) -> Option<f64> {
    let v = v.trim();
    match read_number(v, 0) {
        (Some(x), end) if &v[end..] == "" || &v[end..] == "px" => Some(x),
        _ => None,
    }
}

fn parse_svg_paint(v: &str) -> Option<SvgPaint> {
    if v == "none" {
        Some(SvgPaint::None)
    } else if v.starts_with("url(") {
        Some(SvgPaint::Url(v.to_string()))
    } else {
        parse_color(v).map(SvgPaint::Color)
    }
}

fn one_of(v: &str, options: &[&str]) -> Option<String> {
    options.iter().find(|o| **o == v).map(|o| o.to_string())
}

/// Applies one declaration to `s`. `inherit` copies the parent's value;
/// a value that doesn't parse leaves `s` as it was.
fn apply_property(s: &mut Style, name: &str, value: &str, parent: &Style) {
    let v = value.trim();
    let inherit = v == "inherit";
    match name {
        "fill" => {
            if inherit {
                s.fill = parent.fill.clone();
            } else if let Some(p) = parse_svg_paint(v) {
                s.fill = p;
            }
        }
        "stroke" => {
            if inherit {
                s.stroke = parent.stroke.clone();
            } else if let Some(p) = parse_svg_paint(v) {
                s.stroke = p;
            }
        }
        "fill-opacity" => {
            if inherit {
                s.fill_opacity = parent.fill_opacity;
            } else if let Some(x) = parse_length(v) {
                s.fill_opacity = x.clamp(0.0, 1.0);
            }
        }
        "stroke-opacity" => {
            if inherit {
                s.stroke_opacity = parent.stroke_opacity;
            } else if let Some(x) = parse_length(v) {
                s.stroke_opacity = x.clamp(0.0, 1.0);
            }
        }
        "opacity" => {
            if inherit {
                s.opacity = parent.opacity;
            } else if let Some(x) = parse_length(v) {
                s.opacity = x.clamp(0.0, 1.0);
            }
        }
        "fill-rule" => {
            if inherit {
                s.fill_rule = parent.fill_rule.clone();
            } else if let Some(r) = one_of(v, &["nonzero", "evenodd"]) {
                s.fill_rule = r;
            }
        }
        "clip-rule" => {
            if inherit {
                s.clip_rule = parent.clip_rule.clone();
            } else if let Some(r) = one_of(v, &["nonzero", "evenodd"]) {
                s.clip_rule = r;
            }
        }
        "stroke-width" => {
            if inherit {
                s.stroke_width = parent.stroke_width;
            } else if let Some(x) = parse_length(v) {
                if x >= 0.0 {
                    s.stroke_width = x;
                }
            }
        }
        "stroke-linecap" => {
            if inherit {
                s.stroke_linecap = parent.stroke_linecap.clone();
            } else if let Some(r) = one_of(v, &["butt", "round", "square"]) {
                s.stroke_linecap = r;
            }
        }
        "stroke-linejoin" => {
            if inherit {
                s.stroke_linejoin = parent.stroke_linejoin.clone();
            } else if let Some(r) = one_of(v, &["miter", "round", "bevel"]) {
                s.stroke_linejoin = r;
            }
        }
        "stroke-miterlimit" => {
            if inherit {
                s.stroke_miterlimit = parent.stroke_miterlimit;
            } else if let Some(x) = parse_length(v) {
                if x >= 1.0 {
                    s.stroke_miterlimit = x;
                }
            }
        }
        "stroke-dasharray" => {
            if inherit {
                s.stroke_dasharray = parent.stroke_dasharray.clone();
            } else if v == "none" {
                s.stroke_dasharray = None;
            } else {
                let (nums, end) = number_list_end(v);
                if end == v.len() && !nums.is_empty() {
                    s.stroke_dasharray = Some(nums);
                }
            }
        }
        "stroke-dashoffset" => {
            if inherit {
                s.stroke_dashoffset = parent.stroke_dashoffset;
            } else if let Some(x) = parse_length(v) {
                s.stroke_dashoffset = x;
            }
        }
        "clip-path" => {
            if inherit {
                s.clip_path = parent.clip_path.clone();
            } else if v == "none" {
                s.clip_path = None;
            } else if v.starts_with("url(") {
                s.clip_path = Some(v.to_string());
            }
        }
        "stop-color" => {
            if inherit {
                s.stop_color = parent.stop_color;
            } else if let Some(c) = parse_color(v) {
                s.stop_color = c;
            }
        }
        _ => {}
    }
}

/// The cascade: inherited properties start at the parent's value and the
/// rest (opacity, clip-path, stop-color) at their initial values; then the
/// presentation attributes; then the style attribute's declarations,
/// whatever order they were written in.
pub fn computed_style(el: &Element, parent: &Style) -> Style {
    let init = initial_style();
    let mut s = parent.clone();
    s.opacity = init.opacity;
    s.clip_path = init.clip_path;
    s.stop_color = init.stop_color;
    for (name, value) in &el.attributes {
        if name != "style" {
            apply_property(&mut s, name, value, parent);
        }
    }
    if let Some(decls) = attribute(el, "style") {
        for decl in decls.split(';') {
            if let Some((name, value)) = decl.split_once(':') {
                apply_property(&mut s, name.trim(), value, parent);
            }
        }
    }
    s
}

// ---------------------------------------------------------------------
// § 20.7 Basic shapes
// ---------------------------------------------------------------------

/// A number attribute: missing (or unreadable) is 0.
fn number_attribute(el: &Element, name: &str) -> f64 {
    attribute(el, name).and_then(parse_length).unwrap_or(0.0)
}

fn cmd(op: &'static str, args: &[f64]) -> Command {
    Command { op, args: args.to_vec() }
}

const SHAPE_NAMES: [&str; 7] = ["path", "rect", "circle", "ellipse", "line", "polyline", "polygon"];

fn is_shape(el: &Element) -> bool {
    SHAPE_NAMES.contains(&el.name.as_str())
}

/// The path commands a shape element stands for, the equivalent paths the
/// SVG specification gives. Nothing for a shape that doesn't render or an
/// element that isn't a shape.
pub fn shape_commands(el: &Element) -> Vec<Command> {
    let num = |n: &str| number_attribute(el, n);
    match el.name.as_str() {
        "path" => path_commands(attribute(el, "d").unwrap_or("")),
        "rect" => {
            let (x, y, w, h) = (num("x"), num("y"), num("width"), num("height"));
            if w <= 0.0 || h <= 0.0 {
                return vec![];
            }
            let given = |n: &str| attribute(el, n).and_then(parse_length).filter(|v| *v >= 0.0);
            let (rx, ry) = match (given("rx"), given("ry")) {
                (Some(a), Some(b)) => (a, b),
                (Some(a), None) => (a, a),
                (None, Some(b)) => (b, b),
                (None, None) => (0.0, 0.0),
            };
            let rx = rx.min(w / 2.0);
            let ry = ry.min(h / 2.0);
            if rx <= 0.0 || ry <= 0.0 {
                return vec![
                    cmd("M", &[x, y]),
                    cmd("L", &[x + w, y]),
                    cmd("L", &[x + w, y + h]),
                    cmd("L", &[x, y + h]),
                    cmd("Z", &[]),
                ];
            }
            vec![
                cmd("M", &[x + rx, y]),
                cmd("L", &[x + w - rx, y]),
                cmd("A", &[rx, ry, 0.0, 0.0, 1.0, x + w, y + ry]),
                cmd("L", &[x + w, y + h - ry]),
                cmd("A", &[rx, ry, 0.0, 0.0, 1.0, x + w - rx, y + h]),
                cmd("L", &[x + rx, y + h]),
                cmd("A", &[rx, ry, 0.0, 0.0, 1.0, x, y + h - ry]),
                cmd("L", &[x, y + ry]),
                cmd("A", &[rx, ry, 0.0, 0.0, 1.0, x + rx, y]),
                cmd("Z", &[]),
            ]
        }
        "circle" | "ellipse" => {
            let (cx, cy) = (num("cx"), num("cy"));
            let (rx, ry) = if el.name == "circle" { (num("r"), num("r")) } else { (num("rx"), num("ry")) };
            if rx <= 0.0 || ry <= 0.0 {
                return vec![];
            }
            vec![
                cmd("M", &[cx + rx, cy]),
                cmd("A", &[rx, ry, 0.0, 0.0, 1.0, cx, cy + ry]),
                cmd("A", &[rx, ry, 0.0, 0.0, 1.0, cx - rx, cy]),
                cmd("A", &[rx, ry, 0.0, 0.0, 1.0, cx, cy - ry]),
                cmd("A", &[rx, ry, 0.0, 0.0, 1.0, cx + rx, cy]),
                cmd("Z", &[]),
            ]
        }
        "line" => vec![cmd("M", &[num("x1"), num("y1")]), cmd("L", &[num("x2"), num("y2")])],
        "polyline" | "polygon" => {
            let nums = number_list(attribute(el, "points").unwrap_or(""));
            let mut out = Vec::new();
            for (k, pair) in nums.chunks_exact(2).enumerate() {
                out.push(cmd(if k == 0 { "M" } else { "L" }, pair));
            }
            if !out.is_empty() && el.name == "polygon" {
                out.push(cmd("Z", &[]));
            }
            out
        }
        _ => vec![],
    }
}

// ---------------------------------------------------------------------
// § 20.8 viewBox and preserveAspectRatio
// ---------------------------------------------------------------------

/// The matrix that carries the viewBox onto a `width` by `height`
/// viewport under `preserveAspectRatio` (absent means `xMidYMid meet`).
/// No usable viewBox is the identity.
pub fn view_box_matrix(view_box: Option<&str>, aspect: Option<&str>, width: usize, height: usize) -> Matrix3 {
    let vb = match view_box {
        Some(v) => number_list(v),
        None => return identity(),
    };
    if vb.len() != 4 || vb[2] <= 0.0 || vb[3] <= 0.0 {
        return identity();
    }
    let (w, h) = (width as f64, height as f64);
    let sx = w / vb[2];
    let sy = h / vb[3];
    let words: Vec<&str> = aspect.unwrap_or("xMidYMid meet").split_whitespace().collect();
    let align = words.first().copied().unwrap_or("xMidYMid");
    if align == "none" {
        return scaling(sx, sy) * translation(-vb[0], -vb[1]);
    }
    let slice = words.get(1).copied() == Some("slice");
    let s = if slice { sx.max(sy) } else { sx.min(sy) };
    let frac = |word: &str| match word {
        "Min" => 0.0,
        "Max" => 1.0,
        _ => 0.5,
    };
    let (fx, fy) = if align.len() == 8 && align.starts_with('x') && &align[4..5] == "Y" {
        (frac(&align[1..4]), frac(&align[5..8]))
    } else {
        (0.5, 0.5)
    };
    let ox = (w - vb[2] * s) * fx;
    let oy = (h - vb[3] * s) * fy;
    translation(ox, oy) * scaling(s, s) * translation(-vb[0], -vb[1])
}

// ---------------------------------------------------------------------
// § 20.9 Paint servers
// ---------------------------------------------------------------------

/// A paint seen through a matrix: its colour at a device point is the
/// inner paint's colour at `inverse(m)` of that point.
pub fn transformed_paint(paint: Paint, m: Matrix3) -> Paint {
    Paint::Transformed { inner: Box::new(paint), inv: inverse(m) }
}

/// A number or a percentage (divided by 100).
fn number_or_percent(v: &str) -> Option<f64> {
    let v = v.trim();
    match read_number(v, 0) {
        (Some(x), end) if end == v.len() => Some(x),
        (Some(x), end) if &v[end..] == "%" => Some(x / 100.0),
        _ => None,
    }
}

/// The stop children of a gradient element, in order: offsets clamped to
/// [0, 1] and never going backward, colours from each stop's computed
/// `stop-color`.
pub fn gradient_stops(el: &Element) -> Vec<Stop> {
    let mut out: Vec<Stop> = Vec::new();
    for child in children(el) {
        if child.name != "stop" {
            continue;
        }
        let mut offset = attribute(child, "offset").and_then(number_or_percent).unwrap_or(0.0).clamp(0.0, 1.0);
        if let Some(prev) = out.last() {
            offset = offset.max(prev.offset);
        }
        let style = computed_style(child, &initial_style());
        out.push(stop(offset, style.stop_color));
    }
    out
}

/// The id inside `url(#id)`.
fn url_id(reference: &str) -> Option<&str> {
    let r = reference.trim();
    let inner = r.strip_prefix("url(")?.strip_suffix(')')?.trim();
    let inner = inner.trim_matches(|c| c == '\'' || c == '"');
    inner.strip_prefix('#')
}

/// The paint a `url(#id)` fill or stroke names: a chapter 10 gradient,
/// seen through `ctm` times (for objectBoundingBox) the box's unit square
/// times the gradientTransform. `None` when there's nothing to paint with.
pub fn paint_server(root: &Element, reference: &str, bbox: (f64, f64, f64, f64), ctm: Matrix3) -> Option<Paint> {
    let el = find_by_id(root, url_id(reference)?)?;
    let linear = match el.name.as_str() {
        "linearGradient" => true,
        "radialGradient" => false,
        _ => return None,
    };
    let stops = gradient_stops(el);
    if stops.is_empty() {
        return None;
    }
    let last = stops[stops.len() - 1].color;
    if stops.len() == 1 {
        return Some(solid(last));
    }
    let mut m = ctm;
    if attribute(el, "gradientUnits") != Some("userSpaceOnUse") {
        let (x0, y0, x1, y1) = bbox;
        if x1 - x0 == 0.0 || y1 - y0 == 0.0 {
            return None;
        }
        m = m * translation(x0, y0) * scaling(x1 - x0, y1 - y0);
    }
    m = m * parse_transform(attribute(el, "gradientTransform"));
    let ext = match attribute(el, "spreadMethod") {
        Some("reflect") => "reflect",
        Some("repeat") => "repeat",
        _ => "pad",
    };
    let coord = |name: &str, default: f64| attribute(el, name).and_then(number_or_percent).unwrap_or(default);
    let inner = if linear {
        let (x1, y1, x2, y2) = (coord("x1", 0.0), coord("y1", 0.0), coord("x2", 1.0), coord("y2", 0.0));
        if x1 == x2 && y1 == y2 {
            return Some(solid(last));
        }
        linear_gradient(point(x1, y1), point(x2, y2), stops, ext)
    } else {
        let (cx, cy, r) = (coord("cx", 0.5), coord("cy", 0.5), coord("r", 0.5));
        let (fx, fy, fr) = (coord("fx", cx), coord("fy", cy), coord("fr", 0.0));
        if r == 0.0 {
            return Some(solid(last));
        }
        radial_gradient(point(fx, fy), fr, point(cx, cy), r, stops, ext)
    };
    Some(transformed_paint(inner, m))
}

// ---------------------------------------------------------------------
// § 20.10 The walker, and § 20.11 clips and group opacity
// ---------------------------------------------------------------------

/// Paints into a layer: at every pixel whose coverage times `alpha`, `k`,
/// is above 0, the paint's colour at the pixel center, premultiplied by
/// `k`, goes over what's there.
pub fn draw_coverage(l: &mut Layer, cov: &CoverageBuffer, paint: &Paint, alpha: f64) {
    draw_coverage_counted(l, cov, paint, alpha, &mut stats());
}

/// `1 - (1 - a)(1 - b)` at every pixel: one silhouette over the other.
pub fn union_coverage(a: &CoverageBuffer, b: &CoverageBuffer) -> CoverageBuffer {
    let mut out = coverage_buffer(a.width, a.height);
    for i in 0..out.values.len() {
        out.values[i] = 1.0 - (1.0 - a.values[i]) * (1.0 - b.values[i]);
    }
    out
}

/// Every premultiplied channel of every pixel times the coverage under it.
pub fn mask_layer(l: &Layer, cov: &CoverageBuffer) -> Layer {
    let mut out = l.clone();
    for y in 0..l.height as i64 {
        for x in 0..l.width as i64 {
            let k = coverage_at(cov, x, y);
            let idx = y as usize * l.width + x as usize;
            let p = l.pixels[idx];
            out.pixels[idx] = pixel(p.r * k, p.g * k, p.b * k, p.a * k);
        }
    }
    out
}

/// The coverage of the clipPath a `url(#id)` names: the union of the
/// fills of its shape children, each built through `m` times the
/// clipPath's transform times the child's, under the child's clip-rule.
/// `None` (clip nothing) when the reference names nothing or something
/// that isn't a clipPath.
pub fn clip_coverage(root: &Element, reference: &str, m: Matrix3, width: usize, height: usize) -> Option<CoverageBuffer> {
    let cp = find_by_id(root, url_id(reference)?)?;
    if cp.name != "clipPath" {
        return None;
    }
    let cp_style = computed_style(cp, &initial_style());
    let cm = m * parse_transform(attribute(cp, "transform"));
    let mut cov = coverage_buffer(width, height);
    for child in children(cp) {
        if !is_shape(child) {
            continue;
        }
        let cs = computed_style(child, &cp_style);
        let km = cm * parse_transform(attribute(child, "transform"));
        let cmds = shape_commands(child);
        if cmds.is_empty() || !is_invertible(km) {
            continue;
        }
        let dev = build_path(&cmds, km, 0.1);
        cov = union_coverage(&cov, &fill_path(&dev, &cs.clip_rule, width, height));
    }
    Some(cov)
}

/// The walker, shared by chapter 20's `render_svg` and chapter 21's three
/// modes.
struct Walker<'a> {
    root: &'a Element,
    width: usize,
    height: usize,
    mode: &'a str,
    st: &'a mut Stats,
    work: Option<Vec<Vec<(u32, u32)>>>,
}

impl<'a> Walker<'a> {
    fn render_element(&mut self, el: &Element, l: &mut Layer, parent: &Style, m: Matrix3) {
        let group = el.name == "svg" || el.name == "g";
        if !group && !is_shape(el) {
            return;
        }
        let style = computed_style(el, parent);
        let m = m * parse_transform(attribute(el, "transform"));
        let clip = match &style.clip_path {
            Some(r) => clip_coverage(self.root, r, m, self.width, self.height),
            None => None,
        };
        let own = style.opacity < 1.0 || (clip.is_some() && group);
        if own {
            let mut target = layer(self.width, self.height);
            if group {
                for child in children(el) {
                    self.render_element(child, &mut target, &style, m);
                }
            } else {
                self.draw_shape(el, &mut target, &style, m, None);
            }
            let masked = match &clip {
                Some(c) => mask_layer(&target, c),
                None => target,
            };
            *l = pop_group_with_opacity(&masked, l, style.opacity);
        } else if group {
            for child in children(el) {
                self.render_element(child, l, &style, m);
            }
        } else {
            self.draw_shape(el, l, &style, m, clip.as_ref());
        }
    }

    fn resolve_paint(&self, p: &SvgPaint, cmds: &[Command], m: Matrix3) -> Option<Paint> {
        match p {
            SvgPaint::None => None,
            SvgPaint::Color(c) => Some(solid(*c)),
            SvgPaint::Url(r) => paint_server(self.root, r, commands_bounds(cmds), m),
        }
    }

    fn draw_shape(&mut self, el: &Element, l: &mut Layer, style: &Style, m: Matrix3, clip: Option<&CoverageBuffer>) {
        let cmds = shape_commands(el);
        if cmds.is_empty() || !is_invertible(m) {
            return;
        }
        let dev = build_path(&cmds, m, 0.1);
        if let Some(p) = self.resolve_paint(&style.fill, &cmds, m) {
            self.fill_and_paint(l, &dev, &style.fill_rule, &p, style.fill_opacity, clip);
        }
        if style.stroke_width > 0.0 {
            if let Some(p) = self.resolve_paint(&style.stroke, &cmds, m) {
                let mut user = transform_path(&dev, inverse(m));
                if let Some(pattern) = &style.stroke_dasharray {
                    user = dash(&user, pattern, style.stroke_dashoffset);
                }
                let outline = stroke_to_path(
                    &user,
                    style.stroke_width,
                    &style.stroke_linecap,
                    &style.stroke_linejoin,
                    style.stroke_miterlimit,
                );
                let dev_outline = transform_path(&outline, m);
                self.fill_and_paint(l, &dev_outline, "nonzero", &p, style.stroke_opacity, clip);
            }
        }
    }

    /// One fill or stroke, done the way the mode says.
    fn fill_and_paint(&mut self, l: &mut Layer, p: &Path, rule: &str, paint: &Paint, alpha: f64, clip: Option<&CoverageBuffer>) {
        let (w, h) = (self.width, self.height);
        match self.mode {
            "whole" => {
                let mut cov = fill_path_counted(p, rule, w, h, self.st);
                if let Some(c) = clip {
                    cov = multiply_coverage(&cov, c);
                }
                draw_coverage_counted(l, &cov, paint, alpha, self.st);
            }
            "bounded" => {
                let mut win = fill_path_bounded(p, rule, w, h, self.st);
                if let Some(c) = clip {
                    clip_window(&mut win, c);
                }
                draw_window(l, &win, paint, alpha, self.st);
            }
            "tiled" => {
                let mut t = fill_path_tiled(p, rule, w, h, self.st);
                if let Some(work) = self.work.as_mut() {
                    for (ty, row) in t.classes.iter().enumerate() {
                        for (tx, class) in row.iter().enumerate() {
                            match *class {
                                "partial" => work[ty][tx].0 += 1,
                                "solid" => work[ty][tx].1 += 1,
                                _ => {}
                            }
                        }
                    }
                }
                if let Some(c) = clip {
                    clip_tiled(&mut t, c);
                }
                draw_tiled(l, &t, paint, alpha, self.st);
            }
            other => panic!("render_svg_with: unknown mode {other}"),
        }
    }
}

fn render_document(text: &str, width: usize, height: usize, mode: &str, st: &mut Stats, work: bool) -> (Canvas, Option<Vec<Vec<(u32, u32)>>>) {
    let root = parse_xml(text);
    let mut l = layer(width, height);
    let m = view_box_matrix(attribute(&root, "viewBox"), attribute(&root, "preserveAspectRatio"), width, height);
    let (ntx, nty) = ((width + TILE - 1) / TILE, (height + TILE - 1) / TILE);
    let mut walker = Walker {
        root: &root,
        width,
        height,
        mode,
        st,
        work: if work { Some(vec![vec![(0, 0); ntx]; nty]) } else { None },
    };
    walker.render_element(&root, &mut l, &initial_style(), m);
    let work = walker.work.take();
    (flatten_layer(&l, color(1.0, 1.0, 1.0)), work)
}

/// Draws an SVG document onto a `width` by `height` canvas: a transparent
/// layer, the tree walked from the root with the viewBox matrix, the
/// layer flattened over white paper.
pub fn render_svg(text: &str, width: usize, height: usize) -> Canvas {
    render_svg_with(text, width, height, "whole", &mut stats())
}

// ---------------------------------------------------------------------
// § 20.12 Putting it together
// ---------------------------------------------------------------------

fn read_text(path: &str) -> String {
    String::from_utf8(read_file(path)).unwrap_or_else(|e| panic!("{path} is not UTF-8: {e}"))
}

const ASPECT_SVG: &str = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 80' preserveAspectRatio='%s'><rect width='60' height='80' fill='#f4d8a8'/><circle cx='30' cy='26' r='14' fill='#e8553a'/><polygon points='0,80 22,44 36,62 44,52 60,80' fill='#3b5b7a'/><rect x='1' y='1' width='58' height='78' fill='none' stroke='#1a1a1a' stroke-width='2'/></svg>";

/// Figure 20.4: one portrait drawing in five 120 by 90 landscape
/// viewports, 130 pixels apart from x = 10, y = 10, on 660 by 110 paper.
pub fn aspect_demo() -> Canvas {
    let mut c = canvas(660, 110);
    fill(&mut c, PAPER_3);
    let aspects = ["none", "xMinYMid meet", "xMidYMid meet", "xMaxYMid meet", "xMidYMid slice"];
    for (k, a) in aspects.iter().enumerate() {
        let panel = render_svg(&ASPECT_SVG.replace("%s", a), 120, 90);
        let ox = 10 + k as i64 * 130;
        for y in 0..90 {
            for x in 0..120 {
                write_pixel(&mut c, ox + x, 10 + y, pixel_at(&panel, x, y));
            }
        }
    }
    c
}

/// harbor.svg on a 480 by 320 canvas.
pub fn harbor() -> Canvas {
    render_svg(&read_text("reference/chapter-20/harbor.svg"), 480, 320)
}

/// rose.svg on a 400 by 400 canvas.
pub fn rose() -> Canvas {
    render_svg(&read_text("reference/chapter-20/rose.svg"), 400, 400)
}

/// The Ghostscript tiger on a 450 by 450 canvas.
pub fn tiger() -> Canvas {
    render_svg(&read_text("reference/chapter-20/tiger.svg"), 450, 450)
}

/// Plate 20: the tiger.
pub fn plate_20() -> Canvas {
    tiger()
}

// =======================================================================
// Chapter 21: Making It Fast
// =======================================================================

// ---------------------------------------------------------------------
// § 21.1 Counting the work
// ---------------------------------------------------------------------

/// Work, counted in units that don't depend on the machine: accumulator
/// cells resolved, pixels blended one at a time, pixels copied.
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Stats {
    pub cells: u64,
    pub blends: u64,
    pub copies: u64,
}

/// A stats record with all three counters at 0.
pub fn stats() -> Stats {
    Stats::default()
}

/// Chapter 7's `fill_path`, counting the whole canvas it resolves.
pub fn fill_path_counted(p: &Path, rule: &str, width: usize, height: usize, st: &mut Stats) -> CoverageBuffer {
    st.cells += (width * height) as u64;
    fill_path(p, rule, width, height)
}

/// One source-over of a colour at coverage `k` into a layer pixel -- the
/// same arithmetic as `over(from_color(c, k), d)`: `c·k + (1 − k)·d`.
#[inline]
fn blend_into(l: &mut Layer, idx: usize, c: Color, k: f64) {
    l.pixels[idx] = over(from_color(c, k), l.pixels[idx]);
}

/// Chapter 20's `draw_coverage`, counting every pixel it blends.
pub fn draw_coverage_counted(l: &mut Layer, cov: &CoverageBuffer, paint: &Paint, alpha: f64, st: &mut Stats) {
    let w = l.width.min(cov.width);
    let h = l.height.min(cov.height);
    for y in 0..h {
        for x in 0..w {
            let k = cov.values[y * cov.width + x] * alpha;
            if k > 0.0 {
                let c = paint_at(paint, x as f64 + 0.5, y as f64 + 0.5);
                blend_into(l, y * l.width + x, c, k);
                st.blends += 1;
            }
        }
    }
}

/// Chapter 20's walker with every fill and stroke done one of three ways
/// (`"whole"`, `"bounded"`, `"tiled"`), counting into `st`.
pub fn render_svg_with(text: &str, width: usize, height: usize, mode: &str, st: &mut Stats) -> Canvas {
    render_document(text, width, height, mode, st, false).0
}

// ---------------------------------------------------------------------
// § 21.2 Bounds
// ---------------------------------------------------------------------

/// Anything coverage can be read from at a canvas pixel: a plain buffer,
/// a window, a tiled coverage.
pub trait CoverageSource {
    fn coverage_in(&self, x: i64, y: i64) -> f64;
}

impl CoverageSource for CoverageBuffer {
    fn coverage_in(&self, x: i64, y: i64) -> f64 {
        coverage_at(self, x, y)
    }
}

/// A coverage buffer and where its corner sits on the canvas.
#[derive(Debug, Clone)]
pub struct Window {
    pub cov: CoverageBuffer,
    pub x0: i64,
    pub y0: i64,
}

impl CoverageSource for Window {
    fn coverage_in(&self, x: i64, y: i64) -> f64 {
        coverage_at(&self.cov, x - self.x0, y - self.y0)
    }
}

/// Reads any coverage at a canvas pixel, 0 outside it.
pub fn coverage_in<C: CoverageSource>(c: &C, x: i64, y: i64) -> f64 {
    c.coverage_in(x, y)
}

/// Any coverage as a canvas-sized buffer.
pub fn full_coverage<C: CoverageSource>(c: &C, width: usize, height: usize) -> CoverageBuffer {
    let mut out = coverage_buffer(width, height);
    for y in 0..height {
        for x in 0..width {
            out.values[y * width + x] = c.coverage_in(x as i64, y as i64);
        }
    }
    out
}

/// The window of whole pixels a path can reach: floors of its least x
/// and y, one more than the floors of its greatest, cut to the canvas;
/// `(0, 0, 0, 0)` when that leaves nothing.
pub fn fill_bounds(p: &Path, width: usize, height: usize) -> (i64, i64, i64, i64) {
    if p.subpaths.iter().all(|sp| sp.points.is_empty()) {
        return (0, 0, 0, 0);
    }
    let (min_x, min_y, max_x, max_y) = bounds(p);
    let (w, h) = (width as i64, height as i64);
    let clampf = |v: f64, hi: i64| -> i64 {
        if v.is_nan() {
            0
        } else {
            v.max(-1.0).min(hi as f64 + 1.0) as i64
        }
        .clamp(0, hi)
    };
    let x0 = clampf(min_x.floor(), w);
    let y0 = clampf(min_y.floor(), h);
    let x1 = clampf(max_x.floor() + 1.0, w);
    let y1 = clampf(max_y.floor() + 1.0, h);
    if x1 <= x0 || y1 <= y0 {
        return (0, 0, 0, 0);
    }
    (x0, y0, x1, y1)
}

/// Chapter 7's fill into an accumulator the window's size, with the path
/// moved so the window's corner is the origin.
pub fn fill_path_bounded(p: &Path, rule: &str, width: usize, height: usize, st: &mut Stats) -> Window {
    let (x0, y0, x1, y1) = fill_bounds(p, width, height);
    let (ww, wh) = ((x1 - x0) as usize, (y1 - y0) as usize);
    st.cells += (ww * wh) as u64;
    if ww == 0 || wh == 0 {
        return Window { cov: coverage_buffer(0, 0), x0: 0, y0: 0 };
    }
    let moved = transform_path(p, translation(-x0 as f64, -y0 as f64));
    Window { cov: fill_path(&moved, rule, ww, wh), x0, y0 }
}

/// `draw_coverage` over the window's pixels only.
pub fn draw_window(l: &mut Layer, win: &Window, paint: &Paint, alpha: f64, st: &mut Stats) {
    for wy in 0..win.cov.height {
        let y = win.y0 as usize + wy;
        if y >= l.height {
            break;
        }
        for wx in 0..win.cov.width {
            let x = win.x0 as usize + wx;
            if x >= l.width {
                break;
            }
            let k = win.cov.values[wy * win.cov.width + wx] * alpha;
            if k > 0.0 {
                let c = paint_at(paint, x as f64 + 0.5, y as f64 + 0.5);
                blend_into(l, y * l.width + x, c, k);
                st.blends += 1;
            }
        }
    }
}

/// A shape's own clip, multiplied into a window (fill first, then clip,
/// the order `multiply_coverage` uses).
fn clip_window(win: &mut Window, clip: &CoverageBuffer) {
    for wy in 0..win.cov.height {
        for wx in 0..win.cov.width {
            let i = wy * win.cov.width + wx;
            win.cov.values[i] *= coverage_at(clip, win.x0 + wx as i64, win.y0 + wy as i64);
        }
    }
}

// ---------------------------------------------------------------------
// § 21.3 Tiles
// ---------------------------------------------------------------------

/// Tiles are 16 pixels square, from the top left.
pub const TILE: usize = 16;

/// Chapter 7's deposits, kept only for the cells that got one.
struct SparseCells {
    width: usize,
    height: usize,
    cells: HashMap<(usize, usize), (f64, f64)>,
}

impl CellSink for SparseCells {
    fn sink_width(&self) -> usize {
        self.width
    }
    fn sink_height(&self) -> usize {
        self.height
    }
    fn put(&mut self, x: usize, row: usize, area: f64, cover: f64) {
        let e = self.cells.entry((x, row)).or_insert((0.0, 0.0));
        e.0 += area;
        e.1 += cover;
    }
}

/// A tiled coverage: the class of every tile and the resolved values of
/// the partial ones.
#[derive(Debug, Clone)]
pub struct Tiled {
    pub width: usize,
    pub height: usize,
    pub classes: Vec<Vec<&'static str>>,
    /// One 16x16 block per partial tile, row-major, indexed `ty * ntx + tx`.
    values: Vec<Option<Vec<f64>>>,
}

impl CoverageSource for Tiled {
    fn coverage_in(&self, x: i64, y: i64) -> f64 {
        if x < 0 || y < 0 || x as usize >= self.width || y as usize >= self.height {
            return 0.0;
        }
        let (x, y) = (x as usize, y as usize);
        let (tx, ty) = (x / TILE, y / TILE);
        match self.classes[ty][tx] {
            "solid" => 1.0,
            "partial" => {
                let ntx = self.classes[0].len();
                self.values[ty * ntx + tx].as_ref().map_or(0.0, |v| v[(y % TILE) * TILE + x % TILE])
            }
            _ => 0.0,
        }
    }
}

/// Deposits, per-row sorted cell lists, and the classes. Shared by
/// `classify_tiles` and `fill_path_tiled`.
struct TileWork {
    classes: Vec<Vec<&'static str>>,
    rows: Vec<Vec<(usize, f64, f64)>>,
    /// arriving[r][tx] for every canvas row r: the running sum arriving at
    /// the left edge of tile column tx.
    arriving: Vec<Vec<f64>>,
}

fn tile_pass(p: &Path, rule: &str, width: usize, height: usize) -> TileWork {
    let (ntx, nty) = ((width + TILE - 1) / TILE, (height + TILE - 1) / TILE);
    let mut classes = vec![vec!["empty"; ntx]; nty];
    let (x0, y0, x1, y1) = fill_bounds(p, width, height);
    if x1 <= x0 || y1 <= y0 {
        return TileWork { classes, rows: vec![], arriving: vec![] };
    }
    let mut sparse = SparseCells { width, height, cells: HashMap::new() };
    for (a, b) in edges(p) {
        accumulate_to(&mut sparse, a, b);
    }
    let mut rows: Vec<Vec<(usize, f64, f64)>> = vec![Vec::new(); height];
    let mut dirty = vec![vec![false; ntx]; nty];
    for (&(x, r), &(area, cover)) in &sparse.cells {
        rows[r].push((x, area, cover));
        if area != 0.0 || cover != 0.0 {
            dirty[r / TILE][x / TILE] = true;
        }
    }
    for row in rows.iter_mut() {
        row.sort_by_key(|c| c.0);
    }
    let (tx0, tx1) = (x0 as usize / TILE, (x1 as usize - 1) / TILE);
    let (ty0, ty1) = (y0 as usize / TILE, (y1 as usize - 1) / TILE);
    // The running sum arriving at every tile column's left edge, row by
    // row: the covers of the cells to its left, added left to right.
    let mut arriving = vec![Vec::new(); height];
    for r in ty0 * TILE..((ty1 + 1) * TILE).min(height) {
        let mut sums = vec![0.0; ntx + 1];
        let mut running = 0.0;
        let mut k = 0;
        let cells = &rows[r];
        for tx in 0..=ntx {
            let edge = tx * TILE;
            while k < cells.len() && cells[k].0 < edge {
                running += cells[k].2;
                k += 1;
            }
            sums[tx] = running;
        }
        arriving[r] = sums;
    }
    for ty in ty0..=ty1 {
        for tx in tx0..=tx1 {
            if dirty[ty][tx] {
                classes[ty][tx] = "partial";
                continue;
            }
            let r0 = ty * TILE;
            let r1 = ((ty + 1) * TILE).min(height);
            let n = arriving[r0][tx].round();
            let uniform = (r0..r1).all(|r| (arriving[r][tx] - n).abs() <= 0.000001);
            classes[ty][tx] = if !uniform {
                "partial"
            } else if apply_rule(n, rule) == 1.0 {
                "solid"
            } else {
                "empty"
            };
        }
    }
    TileWork { classes, rows, arriving }
}

/// The class of every tile: `classes[ty][tx]` is "empty", "solid" or
/// "partial", decided before resolving a single cell.
pub fn classify_tiles(p: &Path, rule: &str, width: usize, height: usize) -> Vec<Vec<&'static str>> {
    tile_pass(p, rule, width, height).classes
}

/// Resolves the partial tiles only, each row starting from the running
/// sum arriving at the tile's left edge, counting the cells it resolved.
pub fn fill_path_tiled(p: &Path, rule: &str, width: usize, height: usize, st: &mut Stats) -> Tiled {
    let work = tile_pass(p, rule, width, height);
    let nty = work.classes.len();
    let ntx = if nty > 0 { work.classes[0].len() } else { 0 };
    let mut values = vec![None; ntx * nty];
    for ty in 0..nty {
        for tx in 0..ntx {
            if work.classes[ty][tx] != "partial" {
                continue;
            }
            let mut block = vec![0.0; TILE * TILE];
            let xa = tx * TILE;
            let xb = (xa + TILE).min(width);
            for r in ty * TILE..((ty + 1) * TILE).min(height) {
                let mut running = work.arriving[r][tx];
                let cells = &work.rows[r];
                // first cell at or right of the tile's left edge
                let mut k = cells.partition_point(|c| c.0 < xa);
                for x in xa..xb {
                    let (area, cover) = if k < cells.len() && cells[k].0 == x {
                        k += 1;
                        (cells[k - 1].1, cells[k - 1].2)
                    } else {
                        (0.0, 0.0)
                    };
                    block[(r - ty * TILE) * TILE + (x - xa)] = apply_rule(running + area, rule);
                    running += cover;
                    st.cells += 1;
                }
            }
            values[ty * ntx + tx] = Some(block);
        }
    }
    Tiled { width, height, classes: work.classes, values }
}

/// How many tiles are of a kind.
pub fn tile_count(classes: &[Vec<&'static str>], kind: &str) -> usize {
    classes.iter().flatten().filter(|c| **c == kind).count()
}

/// A shape's own clip on a tiled coverage: every tile that isn't empty
/// becomes partial, its values multiplied by the clip (fill first).
fn clip_tiled(t: &mut Tiled, clip: &CoverageBuffer) {
    let ntx = t.classes.first().map_or(0, |r| r.len());
    for ty in 0..t.classes.len() {
        for tx in 0..ntx {
            let class = t.classes[ty][tx];
            if class == "empty" {
                continue;
            }
            let mut block = match class {
                "solid" => vec![1.0; TILE * TILE],
                _ => t.values[ty * ntx + tx].take().unwrap(),
            };
            for dy in 0..TILE {
                for dx in 0..TILE {
                    block[dy * TILE + dx] *= coverage_at(clip, (tx * TILE + dx) as i64, (ty * TILE + dy) as i64);
                }
            }
            t.values[ty * ntx + tx] = Some(block);
            t.classes[ty][tx] = "partial";
        }
    }
}

// ---------------------------------------------------------------------
// § 21.4 Spans
// ---------------------------------------------------------------------

/// Paints a tiled coverage tile by tile: empty tiles skipped; a solid
/// tile under a solid paint at alpha 1 copied; everything else blended
/// where its coverage times alpha is above 0. A solid paint's colour is
/// looked up once per tile.
pub fn draw_tiled(l: &mut Layer, t: &Tiled, paint: &Paint, alpha: f64, st: &mut Stats) {
    let ntx = t.classes.first().map_or(0, |r| r.len());
    let w = l.width.min(t.width);
    let h = l.height.min(t.height);
    let mut ks = [0.0f64; TILE];
    for (ty, row) in t.classes.iter().enumerate() {
        for (tx, &class) in row.iter().enumerate() {
            if class == "empty" {
                continue;
            }
            let xa = tx * TILE;
            let xb = (xa + TILE).min(w);
            let ya = ty * TILE;
            let yb = (ya + TILE).min(h);
            if xa >= xb || ya >= yb {
                continue;
            }
            let tile_color = match paint {
                Paint::Solid(c) => Some(*c),
                _ => None,
            };
            if class == "solid" {
                if let (Some(c), true) = (tile_color, alpha == 1.0) {
                    let px = pixel(c.red, c.green, c.blue, 1.0);
                    for y in ya..yb {
                        l.pixels[y * l.width + xa..y * l.width + xb].fill(px);
                    }
                    st.copies += ((xb - xa) * (yb - ya)) as u64;
                    continue;
                }
            }
            let block = if class == "partial" { t.values[ty * ntx + tx].as_deref() } else { None };
            for y in ya..yb {
                let n = xb - xa;
                for (i, k) in ks.iter_mut().take(n).enumerate() {
                    let v = match block {
                        Some(b) => b[(y - ya) * TILE + i],
                        None => 1.0,
                    };
                    *k = v * alpha;
                }
                let lit = ks[..n].iter().filter(|k| **k > 0.0).count();
                st.blends += lit as u64;
                match tile_color {
                    Some(c) => {
                        // The four-wide span: pixels with k = 0 come back
                        // exactly as they were, so no test is needed.
                        if lit > 0 {
                            composite_span4(l, y as i64, xa as i64, &ks[..n], c);
                        }
                    }
                    None => {
                        for i in 0..n {
                            if ks[i] > 0.0 {
                                let x = xa + i;
                                let c = paint_at(paint, x as f64 + 0.5, y as f64 + 0.5);
                                blend_into(l, y * l.width + x, c, ks[i]);
                            }
                        }
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------
// § 21.5 Four pixels at a time
// ---------------------------------------------------------------------

/// Composites `c` into row `y` of a layer through a run of coverages, one
/// pixel at a time: pixel `x + i` becomes `(c·k + t·d)` per channel and
/// `k + t·a` for alpha, `k = ks[i]`, `t = 1 − k`. No test for `k = 0`.
pub fn composite_span(l: &mut Layer, y: i64, x: i64, ks: &[f64], c: Color) {
    let base = y as usize * l.width + x as usize;
    for (i, &k) in ks.iter().enumerate() {
        let t = 1.0 - k;
        let d = l.pixels[base + i];
        l.pixels[base + i] = pixel(c.red * k + t * d.r, c.green * k + t * d.g, c.blue * k + t * d.b, k + t * d.a);
    }
}

/// `composite_span` four pixels to a step: each step loads one channel of
/// four pixels into a `[f64; 4]` "register" and does the scalar
/// arithmetic in every lane, in the same order, multiply then add (Rust
/// never contracts `a * b + c` into a fused multiply-add on its own).
/// The leftover `n mod 4` pixels go one at a time. Plain arrays of four
/// are what LLVM's SLP vectorizer turns into packed instructions; no
/// `std::simd` (still unstable) or intrinsics.
pub fn composite_span4(l: &mut Layer, y: i64, x: i64, ks: &[f64], c: Color) {
    let base = y as usize * l.width + x as usize;
    let n = ks.len();
    let row = &mut l.pixels[base..base + n];
    let (cr, cg, cb) = ([c.red; 4], [c.green; 4], [c.blue; 4]);
    let mut i = 0;
    while i + 4 <= n {
        let k: [f64; 4] = [ks[i], ks[i + 1], ks[i + 2], ks[i + 3]];
        let t: [f64; 4] = [1.0 - k[0], 1.0 - k[1], 1.0 - k[2], 1.0 - k[3]];
        let dr = [row[i].r, row[i + 1].r, row[i + 2].r, row[i + 3].r];
        let dg = [row[i].g, row[i + 1].g, row[i + 2].g, row[i + 3].g];
        let db = [row[i].b, row[i + 1].b, row[i + 2].b, row[i + 3].b];
        let da = [row[i].a, row[i + 1].a, row[i + 2].a, row[i + 3].a];
        let mut r = [0.0; 4];
        let mut g = [0.0; 4];
        let mut b = [0.0; 4];
        let mut a = [0.0; 4];
        for j in 0..4 {
            r[j] = cr[j] * k[j] + t[j] * dr[j];
            g[j] = cg[j] * k[j] + t[j] * dg[j];
            b[j] = cb[j] * k[j] + t[j] * db[j];
            a[j] = k[j] + t[j] * da[j];
        }
        for j in 0..4 {
            row[i + j] = Pixel { r: r[j], g: g[j], b: b[j], a: a[j] };
        }
        i += 4;
    }
    while i < n {
        let k = ks[i];
        let t = 1.0 - k;
        let d = row[i];
        row[i] = pixel(c.red * k + t * d.r, c.green * k + t * d.g, c.blue * k + t * d.b, k + t * d.a);
        i += 1;
    }
}

/// True when every channel of every pixel is the same number (`==`, no
/// tolerance).
pub fn layers_equal(a: &Layer, b: &Layer) -> bool {
    a.width == b.width
        && a.height == b.height
        && a.pixels.iter().zip(b.pixels.iter()).all(|(p, q)| p.r == q.r && p.g == q.g && p.b == q.b && p.a == q.a)
}

// ---------------------------------------------------------------------
// § 21.7 Putting it together
// ---------------------------------------------------------------------

/// Renders in "tiled" mode and, for every tile, counts how many fills and
/// strokes found it partial and how many solid: `(partial, solid)`.
pub fn tile_work(text: &str, width: usize, height: usize) -> Vec<Vec<(u32, u32)>> {
    render_document(text, width, height, "tiled", &mut stats(), true).1.unwrap()
}

/// Plate 21: the tiled tiger at (0, 0) and, from x = 460, one square per
/// tile, inset a pixel: magenta mixed into paper by the partial count,
/// cyan at 0.6 where only solid, paper where untouched.
pub fn work_map() -> Canvas {
    let text = read_text("reference/chapter-20/tiger.svg");
    let tiger = render_svg_with(&text, 450, 450, "tiled", &mut stats());
    let work = tile_work(&text, 450, 450);
    let mut c = canvas(910, 450);
    fill(&mut c, CH16_PAPER);
    for y in 0..450 {
        for x in 0..450 {
            write_pixel(&mut c, x, y, pixel_at(&tiger, x, y));
        }
    }
    let max_partial = work.iter().flatten().map(|w| w.0).max().unwrap_or(0).max(1) as f64;
    for (ty, row) in work.iter().enumerate() {
        for (tx, &(partial, solid)) in row.iter().enumerate() {
            let col = if partial > 0 {
                mix_with(CH16_PAPER, CH16_MAGENTA, 0.15 + 0.85 * partial as f64 / max_partial, true)
            } else if solid > 0 {
                mix_with(CH16_PAPER, CH16_CYAN, 0.6, true)
            } else {
                continue;
            };
            let x0 = 460 + (tx * TILE) as i64;
            let y0 = (ty * TILE) as i64;
            // The square is the full 16-pixel tile inset by one, then cut
            // by the map's edge: a bottom tile cut short to two rows keeps
            // its second row (this is what reference/chapter-21 has).
            let x1 = (x0 + TILE as i64 - 1).min(460 + 450);
            let y1 = (y0 + TILE as i64 - 1).min(450);
            for y in y0 + 1..y1 {
                for x in x0 + 1..x1 {
                    write_pixel(&mut c, x, y, col);
                }
            }
        }
    }
    c
}

/// Plate 21: `work_map`.
pub fn plate_21() -> Canvas {
    work_map()
}

// =======================================================================
// Chapter 22: Boolean Path Operations
// =======================================================================

// ---------------------------------------------------------------------
// § 22.1 A grid
// ---------------------------------------------------------------------

/// Coordinates must lie within this many pixels of the origin, either way.
pub const GRID_RANGE_PIXELS: i64 = 1024;

/// Snaps a coordinate to a whole number of grid units, 1/256 of a pixel,
/// halves up (toward +infinity).
pub fn grid(v: f64) -> i64 {
    (v * 256.0 + 0.5).floor() as i64
}

/// Snaps a point to the grid, both coordinates.
pub fn snap_point(p: Tuple) -> Tuple {
    point(grid(p.x) as f64, grid(p.y) as f64)
}

/// Chapter 4's cross product of `b - a` and `c - a`: positive when `c` is
/// clockwise of the line from `a` to `b` on screen, negative when it's
/// counterclockwise, 0 when the three are collinear. Exact on grid points.
pub fn orient(a: Tuple, b: Tuple, c: Tuple) -> f64 {
    cross(b - a, c - a)
}

/// The sweep's order: top to bottom, then left to right.
pub fn lex_less(p: Tuple, q: Tuple) -> bool {
    p.y < q.y || (p.y == q.y && p.x < q.x)
}

fn lex_le(p: Tuple, q: Tuple) -> bool {
    lex_less(p, q) || tuples_eq(p, q)
}

fn lex_cmp(p: Tuple, q: Tuple) -> std::cmp::Ordering {
    if tuples_eq(p, q) {
        std::cmp::Ordering::Equal
    } else if lex_less(p, q) {
        std::cmp::Ordering::Less
    } else {
        std::cmp::Ordering::Greater
    }
}

// ---------------------------------------------------------------------
// § 22.2 Where two segments meet
// ---------------------------------------------------------------------

/// A segment between two grid points, carrying how much it adds to the
/// winding number of path A (`wa`) and of path B (`wb`). Its ends are
/// stored in the sweep's order, `lo` before `hi`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Seg {
    pub lo: Tuple,
    pub hi: Tuple,
    pub wa: i64,
    pub wb: i64,
}

/// Builds a segment, swapping ends (and negating both windings) if `a`
/// comes after `b` in the sweep's order.
pub fn seg(a: Tuple, b: Tuple, wa: i64, wb: i64) -> Seg {
    if lex_less(a, b) {
        Seg { lo: a, hi: b, wa, wb }
    } else {
        Seg { lo: b, hi: a, wa: -wa, wb: -wb }
    }
}

/// Snaps both ends of every edge of `p` and makes each a `Seg` with
/// winding `(1, 0)` for operand `"a"` and `(0, 1)` for `"b"`, dropping any
/// edge whose ends snap to the same point.
pub fn path_segments(p: &Path, operand: &str) -> Vec<Seg> {
    let (wa, wb) = if operand == "a" { (1, 0) } else { (0, 1) };
    let mut out = Vec::new();
    for (a, b) in edges(p) {
        let sa = snap_point(a);
        let sb = snap_point(b);
        if tuples_eq(sa, sb) {
            continue;
        }
        out.push(seg(sa, sb, wa, wb));
    }
    out
}

/// How two segments meet: `"none"`, `"end"`, `"cross"`, `"touch"` or
/// `"overlap"`, and the points each has to be split at.
#[derive(Debug, Clone)]
pub struct Meet {
    pub kind: String,
    pub on_s: Vec<Tuple>,
    pub on_t: Vec<Tuple>,
}

fn strictly_between(lo: Tuple, hi: Tuple, p: Tuple) -> bool {
    lex_less(lo, p) && lex_less(p, hi)
}

/// Says how `s` and `t` meet, as a kind and the points each has to be
/// split at. Every test is exact, with `orient`.
pub fn meet(s: &Seg, t: &Seg) -> Meet {
    let (a, b, c, d) = (s.lo, s.hi, t.lo, t.hi);
    let d1 = orient(c, d, a);
    let d2 = orient(c, d, b);
    let d3 = orient(a, b, c);
    let d4 = orient(a, b, d);

    let collinear = d1 == 0.0 && d2 == 0.0 && d3 == 0.0 && d4 == 0.0;

    if collinear {
        let range_lo = if lex_less(a, c) { c } else { a };
        let range_hi = if lex_less(b, d) { b } else { d };
        if lex_less(range_hi, range_lo) {
            return Meet { kind: "none".to_string(), on_s: vec![], on_t: vec![] };
        }
        if tuples_eq(range_lo, range_hi) {
            return Meet { kind: "end".to_string(), on_s: vec![], on_t: vec![] };
        }
        let mut on_s = Vec::new();
        for p in [c, d] {
            if strictly_between(a, b, p) {
                on_s.push(p);
            }
        }
        let mut on_t = Vec::new();
        for p in [a, b] {
            if strictly_between(c, d, p) {
                on_t.push(p);
            }
        }
        return Meet { kind: "overlap".to_string(), on_s, on_t };
    }

    let opp = |x: f64, y: f64| (x > 0.0 && y < 0.0) || (x < 0.0 && y > 0.0);
    if opp(d1, d2) && opp(d3, d4) {
        let p = crossing_point(s, t);
        let mut on_s = Vec::new();
        if !tuples_eq(p, a) && !tuples_eq(p, b) {
            on_s.push(p);
        }
        let mut on_t = Vec::new();
        if !tuples_eq(p, c) && !tuples_eq(p, d) {
            on_t.push(p);
        }
        return Meet { kind: "cross".to_string(), on_s, on_t };
    }

    let mut on_s = Vec::new();
    let mut on_t = Vec::new();
    if d1 == 0.0 && strictly_between(c, d, a) {
        on_t.push(a);
    }
    if d2 == 0.0 && strictly_between(c, d, b) {
        on_t.push(b);
    }
    if d3 == 0.0 && strictly_between(a, b, c) {
        on_s.push(c);
    }
    if d4 == 0.0 && strictly_between(a, b, d) {
        on_s.push(d);
    }
    if !on_s.is_empty() || !on_t.is_empty() {
        return Meet { kind: "touch".to_string(), on_s, on_t };
    }

    if tuples_eq(a, c) || tuples_eq(a, d) || tuples_eq(b, c) || tuples_eq(b, d) {
        return Meet { kind: "end".to_string(), on_s: vec![], on_t: vec![] };
    }
    Meet { kind: "none".to_string(), on_s: vec![], on_t: vec![] }
}

/// The exact crossing of the lines through `s` and `t`, as a whole-number
/// numerator pair over a whole-number denominator (`X, Y, D`), `D > 0`.
/// `None` when the lines are parallel.
fn exact_crossing(s: &Seg, t: &Seg) -> Option<(i128, i128, i128)> {
    let (a, b, c, d) = (s.lo, s.hi, t.lo, t.hi);
    let ax = a.x.round() as i128;
    let ay = a.y.round() as i128;
    let bx = b.x.round() as i128;
    let by = b.y.round() as i128;
    let cx = c.x.round() as i128;
    let cy = c.y.round() as i128;
    let dx = d.x.round() as i128;
    let dy = d.y.round() as i128;
    let rbx = bx - ax;
    let rby = by - ay;
    let rdx = dx - cx;
    let rdy = dy - cy;
    let mut beta = rbx * rdy - rby * rdx;
    let mut alpha = (cx - ax) * rdy - (cy - ay) * rdx;
    if beta == 0 {
        return None;
    }
    if beta < 0 {
        beta = -beta;
        alpha = -alpha;
    }
    let nx = ax * beta + rbx * alpha;
    let ny = ay * beta + rby * alpha;
    Some((nx, ny, beta))
}

fn round_frac(x: i128, d: i128) -> i64 {
    (2 * x + d).div_euclid(2 * d) as i64
}

/// The exact crossing of the lines through `s` and `t`, rounded to the
/// nearest grid point, halves up.
pub fn crossing_point(s: &Seg, t: &Seg) -> Tuple {
    let (x, y, d) = exact_crossing(s, t).expect("crossing_point: segments are parallel");
    point(round_frac(x, d) as f64, round_frac(y, d) as f64)
}

// ---------------------------------------------------------------------
// § 22.3 Splitting until nothing crosses
// ---------------------------------------------------------------------

/// A record of work done finding where segments meet, and splitting them.
#[derive(Debug, Clone, Copy, Default)]
pub struct SweepStats {
    pub tests: i64,
    pub events: i64,
    pub passes: i64,
}

pub fn sweep_stats() -> SweepStats {
    SweepStats::default()
}

fn order_key(s: &Seg, p: Tuple) -> f64 {
    dot(p - s.lo, s.hi - s.lo)
}

/// Drops a segment's own ends from its split-point list, orders what's
/// left along it from `lo` to `hi`, and drops duplicates.
fn finish_splits(points: &mut Vec<Tuple>, s: &Seg) {
    points.retain(|p| !tuples_eq(*p, s.lo) && !tuples_eq(*p, s.hi));
    points.sort_by(|p, q| {
        order_key(s, *p).partial_cmp(&order_key(s, *q)).unwrap().then_with(|| lex_cmp(*p, *q))
    });
    points.dedup_by(|a, b| tuples_eq(*a, *b));
}

fn find_splits_brute(segs: &[Seg], st: &mut SweepStats) -> Vec<Vec<Tuple>> {
    let n = segs.len();
    let mut out: Vec<Vec<Tuple>> = vec![Vec::new(); n];
    for i in 0..n {
        for j in (i + 1)..n {
            st.tests += 1;
            let m = meet(&segs[i], &segs[j]);
            out[i].extend(m.on_s.iter().copied());
            out[j].extend(m.on_t.iter().copied());
        }
    }
    for i in 0..n {
        finish_splits(&mut out[i], &segs[i]);
    }
    out
}

fn seg_order_cmp(a: &Seg, b: &Seg) -> std::cmp::Ordering {
    if tuples_eq(a.lo, b.lo) {
        lex_cmp(a.hi, b.hi)
    } else {
        lex_cmp(a.lo, b.lo)
    }
}

fn find_splits_sweep(segs: &[Seg], st: &mut SweepStats) -> Vec<Vec<Tuple>> {
    let n = segs.len();
    let mut out: Vec<Vec<Tuple>> = vec![Vec::new(); n];
    let mut order: Vec<usize> = (0..n).collect();
    order.sort_by(|&i, &j| seg_order_cmp(&segs[i], &segs[j]));
    let mut active: Vec<usize> = Vec::new();
    for &i in &order {
        let lo = segs[i].lo;
        active.retain(|&j| lex_less(lo, segs[j].hi));
        for &j in &active {
            st.tests += 1;
            let m = meet(&segs[i], &segs[j]);
            out[i].extend(m.on_s.iter().copied());
            out[j].extend(m.on_t.iter().copied());
        }
        active.push(i);
    }
    for i in 0..n {
        finish_splits(&mut out[i], &segs[i]);
    }
    out
}

/// An event point in the Bentley-Ottmann sweep: either a grid point (a
/// segment's own end) or the exact, possibly fractional, crossing of two
/// segments (`X / D, Y / D`, `D > 0`).
#[derive(Debug, Clone, Copy)]
enum EPoint {
    Grid(i64, i64),
    Frac(i128, i128, i128),
}

impl EPoint {
    fn xyd(&self) -> (i128, i128, i128) {
        match *self {
            EPoint::Grid(x, y) => (x as i128, y as i128, 1),
            EPoint::Frac(x, y, d) => (x, y, d),
        }
    }
    fn rounded(&self) -> Tuple {
        match *self {
            EPoint::Grid(x, y) => point(x as f64, y as f64),
            EPoint::Frac(x, y, d) => point(round_frac(x, d) as f64, round_frac(y, d) as f64),
        }
    }
}

fn epoint_cmp(a: &EPoint, b: &EPoint) -> std::cmp::Ordering {
    let (ax, ay, ad) = a.xyd();
    let (bx, by, bd) = b.xyd();
    let ly = ay * bd;
    let ry = by * ad;
    if ly != ry {
        return ly.cmp(&ry);
    }
    let lx = ax * bd;
    let rx = bx * ad;
    lx.cmp(&rx)
}

fn epoint_eq(a: &EPoint, b: &EPoint) -> bool {
    epoint_cmp(a, b) == std::cmp::Ordering::Equal
}

/// `orient(lo, hi, p)`'s sign, exact, for a possibly-fractional event `p`.
fn eorient(lo: Tuple, hi: Tuple, p: &EPoint) -> i128 {
    let dx = (hi.x - lo.x).round() as i128;
    let dy = (hi.y - lo.y).round() as i128;
    let (px, py, d) = p.xyd();
    let lox = lo.x.round() as i128;
    let loy = lo.y.round() as i128;
    dx * (py - d * loy) - dy * (px - d * lox)
}

fn dir_of(s: &Seg) -> Tuple {
    s.hi - s.lo
}

/// The order two segments leave a point: `a` before `b` when
/// `cross(b_dir, a_dir) > 0`, and when that's 0, the one earlier in the
/// original list first. This puts a horizontal segment (which the
/// sweep's order makes run left to right) last on its own.
fn leaving_cmp(segs: &[Seg], a: usize, b: usize) -> std::cmp::Ordering {
    let da = dir_of(&segs[a]);
    let db = dir_of(&segs[b]);
    let c = cross(db, da);
    if c > 0.0 {
        std::cmp::Ordering::Less
    } else if c < 0.0 {
        std::cmp::Ordering::Greater
    } else {
        a.cmp(&b)
    }
}

fn find_splits_bo(segs: &[Seg], st: &mut SweepStats) -> Vec<Vec<Tuple>> {
    let n = segs.len();
    let mut out: Vec<Vec<Tuple>> = vec![Vec::new(); n];

    let mut events: Vec<EPoint> = Vec::new();
    for s in segs {
        let lo_e = EPoint::Grid(s.lo.x.round() as i64, s.lo.y.round() as i64);
        let hi_e = EPoint::Grid(s.hi.x.round() as i64, s.hi.y.round() as i64);
        if !events.iter().any(|e| epoint_eq(e, &lo_e)) {
            events.push(lo_e);
        }
        if !events.iter().any(|e| epoint_eq(e, &hi_e)) {
            events.push(hi_e);
        }
    }

    let mut status: Vec<usize> = Vec::new();

    while !events.is_empty() {
        let mut min_i = 0;
        for i in 1..events.len() {
            if epoint_cmp(&events[i], &events[min_i]) == std::cmp::Ordering::Less {
                min_i = i;
            }
        }
        let p = events.remove(min_i);
        st.events += 1;

        let mut before: Vec<usize> = Vec::new();
        let mut block: Vec<usize> = Vec::new();
        let mut after: Vec<usize> = Vec::new();
        for &idx in &status {
            let o = eorient(segs[idx].lo, segs[idx].hi, &p);
            if o < 0 {
                before.push(idx);
            } else if o > 0 {
                after.push(idx);
            } else {
                block.push(idx);
            }
        }

        let mut c_list: Vec<usize> = Vec::new();
        for &idx in &block {
            let hi_e = EPoint::Grid(segs[idx].hi.x.round() as i64, segs[idx].hi.y.round() as i64);
            if !epoint_eq(&hi_e, &p) {
                c_list.push(idx);
            }
        }
        let p_rounded = p.rounded();
        for &idx in &c_list {
            out[idx].push(p_rounded);
        }

        let mut u_list: Vec<usize> = Vec::new();
        if let EPoint::Grid(gx, gy) = p {
            for (idx, s) in segs.iter().enumerate() {
                if s.lo.x.round() as i64 == gx && s.lo.y.round() as i64 == gy {
                    u_list.push(idx);
                }
            }
        }

        let mut new_list: Vec<usize> = u_list;
        new_list.extend(c_list);
        new_list.sort_by(|&a, &b| leaving_cmp(segs, a, b));

        let left_neighbor = before.last().copied();
        let right_neighbor = after.first().copied();
        let first_new = new_list.first().copied();
        let last_new = new_list.last().copied();

        {
            let mut test_pair = |a: usize, b: usize| {
                st.tests += 1;
                let m = meet(&segs[a], &segs[b]);
                if m.kind == "cross" {
                    if let Some((x, y, d)) = exact_crossing(&segs[a], &segs[b]) {
                        let ep = EPoint::Frac(x, y, d);
                        if epoint_cmp(&ep, &p) == std::cmp::Ordering::Greater
                            && !events.iter().any(|e| epoint_eq(e, &ep))
                        {
                            events.push(ep);
                        }
                    }
                }
            };

            if new_list.is_empty() {
                if let (Some(l), Some(r)) = (left_neighbor, right_neighbor) {
                    test_pair(l, r);
                }
            } else {
                if let Some(l) = left_neighbor {
                    test_pair(l, first_new.unwrap());
                }
                if let Some(r) = right_neighbor {
                    test_pair(last_new.unwrap(), r);
                }
            }
        }

        status = before;
        status.extend(new_list);
        status.extend(after);
    }

    for i in 0..n {
        finish_splits(&mut out[i], &segs[i]);
    }
    out
}

/// Finds every segment's split points, by one of three methods: `"brute"`
/// (every pair), `"sweep"` (an active list of segments in the current
/// row), or `"bentley-ottmann"` (an ordered status, tested only against
/// its neighbours). All three answer exactly the same splits.
pub fn find_splits(segs: &[Seg], method: &str, st: &mut SweepStats) -> Vec<Vec<Tuple>> {
    match method {
        "brute" => find_splits_brute(segs, st),
        "sweep" => find_splits_sweep(segs, st),
        "bentley-ottmann" => find_splits_bo(segs, st),
        _ => panic!("find_splits: unknown method {method}"),
    }
}

/// Merges segments with the same `lo` and `hi` into one, adding up their
/// windings, drops any segment whose windings are both 0, and sorts what's
/// left in the sweep's order.
pub fn merge_segments(segs: &[Seg]) -> Vec<Seg> {
    let mut merged: Vec<Seg> = Vec::new();
    for s in segs {
        if let Some(existing) =
            merged.iter_mut().find(|e: &&mut Seg| tuples_eq(e.lo, s.lo) && tuples_eq(e.hi, s.hi))
        {
            existing.wa += s.wa;
            existing.wb += s.wb;
        } else {
            merged.push(*s);
        }
    }
    merged.retain(|s| s.wa != 0 || s.wb != 0);
    merged.sort_by(seg_order_cmp);
    merged
}

/// Splits every segment until no two of them cross, going round as many
/// passes as it takes (rounding a crossing can create a new one).
pub fn split_segments(segs: &[Seg], method: &str, st: &mut SweepStats) -> Vec<Seg> {
    let mut current = merge_segments(segs);
    loop {
        st.passes += 1;
        let splits = find_splits(&current, method, st);
        if splits.iter().all(|v| v.is_empty()) {
            return current;
        }
        let mut next: Vec<Seg> = Vec::new();
        for (i, s) in current.iter().enumerate() {
            let pts = &splits[i];
            let mut prev = s.lo;
            for &p in pts {
                next.push(seg(prev, p, s.wa, s.wb));
                prev = p;
            }
            next.push(seg(prev, s.hi, s.wa, s.wb));
        }
        current = merge_segments(&next);
    }
}

// ---------------------------------------------------------------------
// § 22.4 Which side is inside
// ---------------------------------------------------------------------

/// The winding numbers of paths A and B on each side of segment `i`:
/// first the side where it doesn't count, then the side where it does
/// (its left, or below it when it's horizontal).
pub fn winding_beside(segs: &[Seg], i: usize) -> ((i64, i64), (i64, i64)) {
    let m = segs[i].lo + segs[i].hi;
    let mut sum_a = 0i64;
    let mut sum_b = 0i64;
    for (j, f) in segs.iter().enumerate() {
        if j == i {
            continue;
        }
        let flo2 = f.lo * 2.0;
        let fhi2 = f.hi * 2.0;
        let spans = lex_le(flo2, m) && lex_less(m, fhi2);
        if spans && orient(flo2, fhi2, m) > 0.0 {
            sum_a += f.wa;
            sum_b += f.wb;
        }
    }
    ((sum_a, sum_b), (sum_a + segs[i].wa, sum_b + segs[i].wb))
}

/// Whether a winding number is inside under a fill rule: nonzero when it
/// isn't 0, even-odd when it's odd.
pub fn inside_rule(w: i64, rule: &str) -> bool {
    if rule == "evenodd" {
        w.rem_euclid(2) != 0
    } else {
        w != 0
    }
}

/// What each boolean operation calls "inside".
pub fn op_inside(op: &str, in_a: bool, in_b: bool) -> bool {
    match op {
        "union" => in_a || in_b,
        "intersection" => in_a && in_b,
        "difference" => in_a && !in_b,
        "xor" => in_a != in_b,
        _ => panic!("op_inside: unknown op {op}"),
    }
}

/// Keeps the segments where `op_inside` differs between the two sides, as
/// `(from, to)` pairs with the inside on the right as you travel from `to`
/// to `to`.
pub fn keep_edges(segs: &[Seg], rule_a: &str, rule_b: &str, op: &str) -> Vec<(Tuple, Tuple)> {
    let mut out = Vec::new();
    for i in 0..segs.len() {
        let (outside, inside) = winding_beside(segs, i);
        let out_flag = op_inside(op, inside_rule(outside.0, rule_a), inside_rule(outside.1, rule_b));
        let in_flag = op_inside(op, inside_rule(inside.0, rule_a), inside_rule(inside.1, rule_b));
        if out_flag != in_flag {
            if in_flag {
                out.push((segs[i].lo, segs[i].hi));
            } else {
                out.push((segs[i].hi, segs[i].lo));
            }
        }
    }
    out
}

// ---------------------------------------------------------------------
// § 22.5 Stitching
// ---------------------------------------------------------------------

/// Which half-turn `d` is in, relative to facing back along `r`: 0 for
/// the half swept counterclockwise from just past `r`, up to and
/// including straight ahead (the reverse of `r`); 1 for the rest, up to
/// and including `r` itself (doubling back the way you came, the last
/// resort). `cross(r, d) < 0` means `d` is counterclockwise of `r`, in
/// this book's clockwise-positive convention.
fn ccw_half(r: Tuple, d: Tuple) -> i32 {
    let c = cross(r, d);
    if c < 0.0 {
        0
    } else if c > 0.0 {
        1
    } else if dot(r, d) < 0.0 {
        0
    } else {
        1
    }
}

/// Orders directions by angle swept counterclockwise starting just past
/// `r` (facing back the way you came): the smallest is the sharpest right
/// turn from `r`.
fn cmp_ccw_from(r: Tuple, d1: Tuple, d2: Tuple) -> std::cmp::Ordering {
    let h1 = ccw_half(r, d1);
    let h2 = ccw_half(r, d2);
    if h1 != h2 {
        return h1.cmp(&h2);
    }
    let c = cross(d1, d2);
    if c < 0.0 {
        std::cmp::Ordering::Less
    } else if c > 0.0 {
        std::cmp::Ordering::Greater
    } else {
        std::cmp::Ordering::Equal
    }
}

fn drop_collinear(pts: &mut Vec<Tuple>) {
    loop {
        let n = pts.len();
        if n < 3 {
            return;
        }
        let mut remove_idx = None;
        for i in 0..n {
            let prev = pts[(i + n - 1) % n];
            let cur = pts[i];
            let next = pts[(i + 1) % n];
            if orient(prev, cur, next) == 0.0 {
                remove_idx = Some(i);
                break;
            }
        }
        match remove_idx {
            Some(i) => {
                pts.remove(i);
            }
            None => return,
        }
    }
}

fn rotate_to_top_left(pts: &mut Vec<Tuple>) {
    if pts.is_empty() {
        return;
    }
    let mut best = 0;
    for i in 1..pts.len() {
        if lex_less(pts[i], pts[best]) {
            best = i;
        }
    }
    pts.rotate_left(best);
}

fn cmp_point_list(a: &[Tuple], b: &[Tuple]) -> std::cmp::Ordering {
    for i in 0..a.len().min(b.len()) {
        if !tuples_eq(a[i], b[i]) {
            return lex_cmp(a[i], b[i]);
        }
    }
    a.len().cmp(&b.len())
}

/// Links `(from, to)` pairs into closed contours: from the first unused
/// pair in the sweep's order, follow it, and at each vertex take the
/// unused pair leaving it that turns furthest right, until back at the
/// start. Drops collinear vertices, starts each contour at its
/// topmost-then-leftmost point, and sorts the contours.
pub fn stitch(kept: &[(Tuple, Tuple)]) -> Vec<Vec<Tuple>> {
    let n = kept.len();
    let mut used = vec![false; n];
    let mut order: Vec<usize> = (0..n).collect();
    order.sort_by(|&i, &j| {
        let (fi, ti) = kept[i];
        let (fj, tj) = kept[j];
        if tuples_eq(fi, fj) {
            lex_cmp(ti, tj)
        } else {
            lex_cmp(fi, fj)
        }
    });

    let mut contours: Vec<Vec<Tuple>> = Vec::new();

    loop {
        let start_idx = match order.iter().find(|&&i| !used[i]) {
            Some(&i) => i,
            None => break,
        };
        let start_from = kept[start_idx].0;
        let mut pts: Vec<Tuple> = vec![start_from];
        used[start_idx] = true;
        let mut came_from_dir = kept[start_idx].0 - kept[start_idx].1;
        let mut at = kept[start_idx].1;
        pts.push(at);

        while !tuples_eq(at, start_from) {
            let candidates: Vec<usize> =
                (0..n).filter(|&i| !used[i] && tuples_eq(kept[i].0, at)).collect();
            let mut best: Option<usize> = None;
            for &c in &candidates {
                let dc = kept[c].1 - kept[c].0;
                match best {
                    None => best = Some(c),
                    Some(b) => {
                        let db = kept[b].1 - kept[b].0;
                        if cmp_ccw_from(came_from_dir, dc, db) == std::cmp::Ordering::Less {
                            best = Some(c);
                        }
                    }
                }
            }
            let chosen = best.expect("stitch: dead end -- an odd vertex");
            used[chosen] = true;
            came_from_dir = kept[chosen].0 - kept[chosen].1;
            at = kept[chosen].1;
            pts.push(at);
        }
        pts.pop();
        contours.push(pts);
    }

    for c in contours.iter_mut() {
        drop_collinear(c);
        rotate_to_top_left(c);
    }
    contours.sort_by(|a, b| cmp_point_list(a, b));
    contours
}

// ---------------------------------------------------------------------
// § 22.6 Putting it together
// ---------------------------------------------------------------------

/// The whole boolean pipeline: splits both paths' edges against each
/// other, classifies which side of each piece is inside, and stitches the
/// kept pieces into an outline path.
pub fn combine(a: &Path, rule_a: &str, b: &Path, rule_b: &str, op: &str) -> Path {
    let mut st = sweep_stats();
    let mut segs = path_segments(a, "a");
    segs.extend(path_segments(b, "b"));
    let segs = split_segments(&segs, "bentley-ottmann", &mut st);
    let kept = keep_edges(&segs, rule_a, rule_b, op);
    let contours = stitch(&kept);
    let mut result = path();
    for c in contours {
        if c.is_empty() {
            continue;
        }
        move_to(&mut result, point(c[0].x / 256.0, c[0].y / 256.0));
        for p in &c[1..] {
            line_to(&mut result, point(p.x / 256.0, p.y / 256.0));
        }
        close(&mut result);
    }
    result
}

/// One path's own self-crossings resolved by its fill rule, as a plain
/// outline: `combine` against an empty second path.
pub fn simplify(p: &Path, rule: &str) -> Path {
    combine(p, rule, &path(), "nonzero", "union")
}

/// Each subpath's points, in order.
pub fn point_lists(p: &Path) -> Vec<Vec<Tuple>> {
    subpaths(p).iter().map(|sp| sp.points.clone()).collect()
}

// ---------------------------------------------------------------------
// § 22.7 A faster way to find crossings -- the benchmark
// ---------------------------------------------------------------------

fn ch22_font() -> Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

/// Roboto, loaded once per call: the font chapters 16-19's plates and
/// chapters 22-23's fields and bakes share.
pub fn roboto() -> Font {
    ch22_font()
}

/// One path holding, in order, the subpaths of every placed glyph of a
/// run of text.
pub fn text_path(font: &Font, text: &str, size: f64, x: f64, y: f64) -> Path {
    let mut out = path();
    for pl in layout_run(font, text, size, x, y, true) {
        let gp = glyph_path(font, &pl.name, text_matrix(font, size, pl.x, pl.y), 0.1);
        for sp in subpaths(&gp) {
            if sp.points.is_empty() {
                continue;
            }
            move_to(&mut out, sp.points[0]);
            for p in &sp.points[1..] {
                line_to(&mut out, *p);
            }
            if sp.closed {
                close(&mut out);
            }
        }
    }
    out
}

fn struck_text(n: usize) -> Path {
    let font = roboto();
    let text = std::iter::repeat("Pathfinder").take(n).collect::<Vec<_>>().join(" ");
    text_path(&font, &text, 120.0 / n as f64, 20.0, 160.0)
}

fn struck_bars(n: usize) -> Path {
    let mut p = path();
    for k in 0..(14 * n) {
        let x = -40.0 + 48.0 * k as f64 / n as f64;
        let pts = [
            point(x, 100.0),
            point(x + 22.0 / n as f64, 100.0),
            point(x - 40.0 / n as f64, 200.0),
            point(x - 62.0 / n as f64, 200.0),
        ];
        move_to(&mut p, pts[0]);
        for pt in &pts[1..] {
            line_to(&mut p, *pt);
        }
        close(&mut p);
    }
    p
}

/// The chapter's benchmark: the word "Pathfinder" `n` times with a space
/// between, struck through by `14 n` slanting bars.
pub fn struck_line(n: usize) -> (Path, Path) {
    (struck_text(n), struck_bars(n))
}

/// `merge_segments` of `path_segments(text, "a")` and
/// `path_segments(bars, "b")` for `struck_line(n)`.
pub fn struck_segments(n: usize) -> Vec<Seg> {
    let (text, bars) = struck_line(n);
    let mut segs = path_segments(&text, "a");
    segs.extend(path_segments(&bars, "b"));
    merge_segments(&segs)
}

// ---------------------------------------------------------------------
// § 22.9 Putting it together -- the plate
// ---------------------------------------------------------------------

const CH22_PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };
const CH22_DIM: Color = Color { red: 0.3, green: 0.3, blue: 0.34 };
const CH22_MAGENTA: Color = Color { red: 0.85, green: 0.2, blue: 0.55 };
const CH22_ORANGE: Color = Color { red: 0.9, green: 0.55, blue: 0.1 };

fn ch22_hairline(c: &mut Canvas, p: &Path, width: f64, col: Color) {
    let outline = stroke_to_path(p, width, "butt", "round", 4.0);
    let cov = fill_path(&outline, "nonzero", c.width, c.height);
    paint_through(c, &cov, col);
}

/// Path A: Roboto's `g`, through `text_matrix(font, 200, 40, 140)`.
pub fn plate_glyph() -> Path {
    let font = roboto();
    glyph_path(&font, "g", text_matrix(&font, 200.0, 40.0, 140.0), 0.1)
}

/// Path B: chapter 5's star, scaled by 0.85 about its own center and
/// moved so that center lands at (130, 104).
pub fn plate_star() -> Path {
    let m = translation(49.5, 23.5)
        * translation(80.5, 80.5)
        * scaling(0.85, 0.85)
        * translation(-80.5, -80.5);
    transform_path(&star(), m)
}

/// One panel of Plate 22: `combine(A, "nonzero", B, "evenodd", op)`
/// filled and painted orange, with A, B and the result's hairlines over
/// it.
pub fn op_panel(op: &str) -> Canvas {
    let a = plate_glyph();
    let b = plate_star();
    let mut c = canvas(200, 200);
    fill(&mut c, CH22_PAPER);
    let result = combine(&a, "nonzero", &b, "evenodd", op);
    let cov = fill_path(&result, "nonzero", 200, 200);
    paint_through(&mut c, &cov, CH22_ORANGE);
    ch22_hairline(&mut c, &a, 1.0, CH22_DIM);
    ch22_hairline(&mut c, &b, 1.0, CH22_DIM);
    ch22_hairline(&mut c, &result, 1.0, CH22_MAGENTA);
    c
}

/// The four panels side by side: union, intersection, difference, xor.
pub fn plate_22() -> Canvas {
    let ops = ["union", "intersection", "difference", "xor"];
    let mut result = op_panel(ops[0]);
    for op in &ops[1..] {
        result = side_by_side(&result, &op_panel(op));
    }
    result
}

/// `n` circles of radius `r` spaced `d` from `(cx, cy)`, each XOR'ed into
/// the last.
pub fn rosette(cx: f64, cy: f64, n: usize, r: f64, d: f64) -> Path {
    let mut p = path();
    for k in 0..n {
        let theta = 2.0 * std::f64::consts::PI * k as f64 / n as f64;
        let circle = circle_path(cx + d * theta.cos(), cy + d * theta.sin(), r, 72);
        p = combine(&p, "nonzero", &circle, "nonzero", "xor");
    }
    p
}

/// Sixty-one calls to `combine`, and one fill: a scalloped ring, a band,
/// the word BOOLEAN, chapter 5's star, and a rosette, each XOR'ed or
/// unioned or subtracted into the last.
pub fn seal() -> Canvas {
    let font = roboto();
    let mut rim = circle_path(240.0, 240.0, 200.0, 120);
    for k in 0..40 {
        let theta = 2.0 * std::f64::consts::PI * k as f64 / 40.0;
        let notch =
            circle_path(240.0 + 200.0 * theta.cos(), 240.0 + 200.0 * theta.sin(), 16.0, 24);
        rim = combine(&rim, "nonzero", &notch, "nonzero", "union");
    }
    let inner = circle_path(240.0, 240.0, 168.0, 120);
    let ring = combine(&rim, "nonzero", &inner, "nonzero", "difference");
    let band = polygon(&[
        point(20.0, 196.0),
        point(460.0, 196.0),
        point(460.0, 284.0),
        point(20.0, 284.0),
    ]);
    let mut s = combine(&ring, "nonzero", &band, "nonzero", "union");
    let text = text_path(&font, "BOOLEAN", 84.0, 52.0, 270.0);
    s = combine(&s, "nonzero", &text, "nonzero", "xor");
    let moved_star = transform_path(&star(), translation(159.5, 23.5));
    s = combine(&s, "nonzero", &moved_star, "evenodd", "xor");
    let rose = rosette(240.0, 352.0, 16, 44.0, 36.0);
    s = combine(&s, "nonzero", &rose, "nonzero", "xor");

    let mut c = canvas(480, 480);
    fill(&mut c, CH22_PAPER);
    let cov = fill_path(&s, "nonzero", 480, 480);
    paint_through(&mut c, &cov, CH22_ORANGE);
    ch22_hairline(&mut c, &s, 0.75, CH22_MAGENTA);
    c
}

// =======================================================================
// Chapter 23: Distance Fields
// =======================================================================

// ---------------------------------------------------------------------
// § 23.1 Exact fields for primitives
// ---------------------------------------------------------------------

/// A signed distance: negative inside a shape, positive outside, its size
/// the distance to the nearest point of the shape's edge.
pub fn sd_circle(p: Tuple, c: Tuple, r: f64) -> f64 {
    magnitude(p - c) - r
}

/// The distance from `p` to the segment `a`-`b`: no sign, since a segment
/// has no inside.
pub fn distance_to_segment(p: Tuple, a: Tuple, b: Tuple) -> f64 {
    let ab = b - a;
    let denom = dot(ab, ab);
    let t = if denom == 0.0 { 0.0 } else { (dot(p - a, ab) / denom).clamp(0.0, 1.0) };
    magnitude(p - (a + ab * t))
}

/// A box centered on `c`, `hw` and `hh` from the center to its sides.
pub fn sd_box(p: Tuple, c: Tuple, hw: f64, hh: f64) -> f64 {
    let qx = (p.x - c.x).abs() - hw;
    let qy = (p.y - c.y).abs() - hh;
    let ax = qx.max(0.0);
    let ay = qy.max(0.0);
    (ax * ax + ay * ay).sqrt() + qx.max(qy).min(0.0)
}

/// A box with its corners rounded by `r`: shrink the box by `r`, then
/// subtract `r`.
pub fn sd_rounded_box(p: Tuple, c: Tuple, hw: f64, hh: f64, r: f64) -> f64 {
    sd_box(p, c, hw - r, hh - r) - r
}

/// The least distance to any edge of `path`, made negative where chapter
/// 5's `winding_at` says `p` is inside under `rule`.
pub fn sd_polygon(p: Tuple, path: &Path, rule: &str) -> f64 {
    let mut best = f64::INFINITY;
    for (a, b) in edges(path) {
        let d = distance_to_segment(p, a, b);
        if d < best {
            best = d;
        }
    }
    let w = winding_at(path, p.x, p.y);
    if inside_rule(w, rule) {
        -best
    } else {
        best
    }
}

// ---------------------------------------------------------------------
// § 23.2 Fields for curves
// ---------------------------------------------------------------------

fn solve_linear(c: f64, d: f64) -> Vec<f64> {
    if c.abs() < 1e-12 {
        vec![]
    } else {
        vec![-d / c]
    }
}

fn solve_quadratic(b: f64, c: f64, d: f64) -> Vec<f64> {
    if b.abs() < 1e-12 {
        return solve_linear(c, d);
    }
    let disc = c * c - 4.0 * b * d;
    if disc < 0.0 {
        return vec![];
    }
    let sq = disc.sqrt();
    let mut r = vec![(-c - sq) / (2.0 * b), (-c + sq) / (2.0 * b)];
    r.sort_by(|x, y| x.partial_cmp(y).unwrap());
    r
}

/// The real roots of `a t^3 + b t^2 + c t + d = 0`, in increasing order.
/// Falls back to the quadratic (then linear) when the leading
/// coefficients vanish. Cardano's formula for one real root, the cosine
/// formula for three.
pub fn solve_cubic(a: f64, b: f64, c: f64, d: f64) -> Vec<f64> {
    if a.abs() < 1e-12 {
        return solve_quadratic(b, c, d);
    }
    let bb = b / a;
    let cc = c / a;
    let dd = d / a;
    let shift = bb / 3.0;
    let p = cc - bb * bb / 3.0;
    let q = 2.0 * bb * bb * bb / 27.0 - bb * cc / 3.0 + dd;
    let disc = (q * q) / 4.0 + (p * p * p) / 27.0;
    if disc > 0.0 {
        let sq = disc.sqrt();
        let u = (-q / 2.0 + sq).cbrt();
        let v = (-q / 2.0 - sq).cbrt();
        vec![u + v - shift]
    } else if p.abs() < 1e-12 {
        vec![-shift]
    } else {
        let r = 2.0 * (-p / 3.0).sqrt();
        let arg = (3.0 * q / (p * r)).clamp(-1.0, 1.0);
        let theta = arg.acos() / 3.0;
        let two_pi_3 = 2.0 * std::f64::consts::PI / 3.0;
        let mut roots = vec![
            r * theta.cos() - shift,
            r * (theta - two_pi_3).cos() - shift,
            r * (theta - 2.0 * two_pi_3).cos() - shift,
        ];
        roots.sort_by(|x, y| x.partial_cmp(y).unwrap());
        roots
    }
}

fn nearest_t_quadratic(p: Tuple, c: &Curve) -> f64 {
    let p0 = c.points[0];
    let p1 = c.points[1];
    let p2 = c.points[2];
    let a0 = p0 - p;
    let a1 = (p1 - p0) * 2.0;
    let a2 = p0 - p1 * 2.0 + p2;
    let roots =
        solve_cubic(2.0 * dot(a2, a2), 3.0 * dot(a1, a2), dot(a1, a1) + 2.0 * dot(a0, a2), dot(a0, a1));
    let mut ts = vec![0.0, 1.0];
    for r in roots {
        if r > 0.0 && r < 1.0 {
            ts.push(r);
        }
    }
    let mut best_t = ts[0];
    let mut best_d = magnitude(point_at(c, best_t) - p);
    for &t in &ts[1..] {
        let d = magnitude(point_at(c, t) - p);
        if d < best_d {
            best_d = d;
            best_t = t;
        }
    }
    best_t
}

/// The distance from `p` to the nearest point of quadratic `c`: the
/// perpendicular-foot condition is a cubic in `t`, solved exactly.
pub fn distance_to_quadratic(p: Tuple, c: &Curve) -> f64 {
    magnitude(point_at(c, nearest_t_quadratic(p, c)) - p)
}

/// The `t` of the nearest point of cubic `c` to `p`: both ends, and nine
/// seeds refined by eight Newton steps each on the perpendicular-foot
/// condition. The nearest wins; ties keep the earlier candidate (the ends
/// first, then the seeds in order).
pub fn nearest_t_cubic(p: Tuple, c: &Curve) -> f64 {
    let mut candidates: Vec<f64> = vec![0.0, 1.0];
    for i in 0..=8 {
        let mut t = i as f64 / 8.0;
        for _ in 0..8 {
            let bt = point_at(c, t);
            let d1 = derivative(c, t);
            let d2 = second_derivative(c, t);
            let f = dot(bt - p, d1);
            let fp = dot(d1, d1) + dot(bt - p, d2);
            if fp == 0.0 {
                break;
            }
            t = (t - f / fp).clamp(0.0, 1.0);
        }
        candidates.push(t);
    }
    let mut best_t = candidates[0];
    let mut best_d = magnitude(point_at(c, best_t) - p);
    for &t in &candidates[1..] {
        let d = magnitude(point_at(c, t) - p);
        if d < best_d {
            best_d = d;
            best_t = t;
        }
    }
    best_t
}

/// The distance from `p` to the nearest point of cubic `c`.
pub fn distance_to_cubic(p: Tuple, c: &Curve) -> f64 {
    let t = nearest_t_cubic(p, c);
    magnitude(point_at(c, t) - p)
}

/// The ground truth by search: 129 samples, ternary search around every
/// sample no farther than its neighbours.
pub fn brute_distance(c: &Curve, p: Tuple) -> f64 {
    let n = 128usize;
    let dist = |t: f64| magnitude(point_at(c, t) - p);
    let ts: Vec<f64> = (0..=n).map(|i| i as f64 / n as f64).collect();
    let ds: Vec<f64> = ts.iter().map(|&t| dist(t)).collect();
    let mut best = f64::INFINITY;
    for i in 0..=n {
        let left_ok = i == 0 || ds[i] <= ds[i - 1];
        let right_ok = i == n || ds[i] <= ds[i + 1];
        if !(left_ok && right_ok) {
            continue;
        }
        let mut a = if i == 0 { ts[i] } else { ts[i - 1] };
        let mut b = if i == n { ts[i] } else { ts[i + 1] };
        for _ in 0..40 {
            let m1 = a + (b - a) / 3.0;
            let m2 = b - (b - a) / 3.0;
            if dist(m1) < dist(m2) {
                b = m2;
            } else {
                a = m1;
            }
        }
        let d = dist((a + b) / 2.0);
        if d < best {
            best = d;
        }
    }
    best
}

/// `n` points spread over a box the same way in every language, by two
/// low-discrepancy (Weyl) sequences.
pub fn weyl_points(n: usize, x0: f64, y0: f64, w: f64, h: f64) -> Vec<Tuple> {
    const A: f64 = 0.7548776662466927;
    const B: f64 = 0.5698402909980532;
    (1..=n)
        .map(|k| {
            let ka = k as f64 * A;
            let kb = k as f64 * B;
            point(x0 + w * (ka - ka.floor()), y0 + h * (kb - kb.floor()))
        })
        .collect()
}

/// The greatest `|distance - brute_distance|` over `pts`, using the
/// quadratic or cubic distance as `c` has three or four control points.
pub fn max_curve_error(c: &Curve, pts: &[Tuple]) -> f64 {
    let mut worst: f64 = 0.0;
    for &p in pts {
        let d = if c.points.len() == 3 { distance_to_quadratic(p, c) } else { distance_to_cubic(p, c) };
        let b = brute_distance(c, p);
        let e = (d - b).abs();
        if e > worst {
            worst = e;
        }
    }
    worst
}

// ---------------------------------------------------------------------
// § 23.3 Render it
// ---------------------------------------------------------------------

/// A width, a height and one number per pixel, row by row.
#[derive(Debug, Clone)]
pub struct Field {
    pub width: usize,
    pub height: usize,
    pub values: Vec<f64>,
}

/// Samples `f` at every pixel center, `point(x + 0.5, y + 0.5)`.
pub fn field<F: Fn(Tuple) -> f64>(width: usize, height: usize, f: F) -> Field {
    let mut values = Vec::with_capacity(width * height);
    for y in 0..height {
        for x in 0..width {
            values.push(f(point(x as f64 + 0.5, y as f64 + 0.5)));
        }
    }
    Field { width, height, values }
}

/// A field built directly from a list of values, row by row.
pub fn field_of(width: usize, height: usize, values: Vec<f64>) -> Field {
    Field { width, height, values }
}

pub fn field_at(f: &Field, x: i64, y: i64) -> f64 {
    f.values[y as usize * f.width + x as usize]
}

/// The least and greatest values in the field.
pub fn field_range(f: &Field) -> (f64, f64) {
    let mut lo = f64::INFINITY;
    let mut hi = f64::NEG_INFINITY;
    for &v in &f.values {
        if v < lo {
            lo = v;
        }
        if v > hi {
            hi = v;
        }
    }
    (lo, hi)
}

/// Chapter 2's coverage buffer from a field: `clamp(0.5 - d, 0, 1)` at
/// every pixel.
pub fn field_coverage(f: &Field) -> CoverageBuffer {
    let mut cov = coverage_buffer(f.width, f.height);
    for y in 0..f.height {
        for x in 0..f.width {
            let d = field_at(f, x as i64, y as i64);
            set_coverage(&mut cov, x as i64, y as i64, (0.5 - d).clamp(0.0, 1.0));
        }
    }
    cov
}

/// The field of `sd_polygon`.
pub fn polygon_field(p: &Path, rule: &str, width: usize, height: usize) -> Field {
    let rule = rule.to_string();
    field(width, height, move |q| sd_polygon(q, p, &rule))
}

/// A coverage buffer of `|cov - exact|` at each pixel.
pub fn coverage_error(cov: &CoverageBuffer, exact: &CoverageBuffer) -> CoverageBuffer {
    let mut out = coverage_buffer(cov.width, cov.height);
    for y in 0..cov.height {
        for x in 0..cov.width {
            let v = (coverage_at(cov, x as i64, y as i64) - coverage_at(exact, x as i64, y as i64)).abs();
            set_coverage(&mut out, x as i64, y as i64, v);
        }
    }
    out
}

// ---------------------------------------------------------------------
// § 23.4 Chapters 13, 14 and 22 for free
// ---------------------------------------------------------------------

fn field_zip<F: Fn(f64, f64) -> f64>(a: &Field, b: &Field, f: F) -> Field {
    let values = a.values.iter().zip(b.values.iter()).map(|(&x, &y)| f(x, y)).collect();
    Field { width: a.width, height: a.height, values }
}

/// The shape grown by `r` (shrunk when `r` is negative): `d - r`.
pub fn field_offset(f: &Field, r: f64) -> Field {
    Field { width: f.width, height: f.height, values: f.values.iter().map(|&d| d - r).collect() }
}

/// A band `width` wide centered on the edge: `|d| - width / 2`.
pub fn field_stroke(f: &Field, width: f64) -> Field {
    Field {
        width: f.width,
        height: f.height,
        values: f.values.iter().map(|&d| d.abs() - width / 2.0).collect(),
    }
}

pub fn field_union(a: &Field, b: &Field) -> Field {
    field_zip(a, b, |x, y| x.min(y))
}

pub fn field_intersection(a: &Field, b: &Field) -> Field {
    field_zip(a, b, |x, y| x.max(y))
}

pub fn field_difference(a: &Field, b: &Field) -> Field {
    field_zip(a, b, |x, y| x.max(-y))
}

pub fn field_xor(a: &Field, b: &Field) -> Field {
    field_zip(a, b, |x, y| x.min(y).max(-(x.max(y))))
}

/// The field of `distance_to_cubic`: no sign, since one curve has no
/// inside.
pub fn cubic_field(c: &Curve, width: usize, height: usize) -> Field {
    field(width, height, |p| distance_to_cubic(p, c))
}

/// `cubic((30, 150), (40, 20), (160, 180), (170, 50))`, the plate's curve.
pub fn s_curve() -> Curve {
    cubic(point(30.0, 150.0), point(40.0, 20.0), point(160.0, 180.0), point(170.0, 50.0))
}

fn quadratics_of_glyph(font: &Font, name: &str, m: Matrix3) -> Vec<Curve> {
    let mut curves = Vec::new();
    for contour in glyph_outline(font, name) {
        for c in contour {
            curves.push(transform_curve(&c, m));
        }
    }
    curves
}

/// The field of chapter 22's `plate_glyph()` on a 200 by 200 canvas.
pub fn plate_glyph_field() -> Field {
    let font = roboto();
    let m = text_matrix(&font, 200.0, 40.0, 140.0);
    let curves = quadratics_of_glyph(&font, "g", m);
    let outline = glyph_path(&font, "g", m, 0.01);
    field(200, 200, move |p| {
        let mut best = f64::INFINITY;
        for c in &curves {
            let d = distance_to_quadratic(p, c);
            if d < best {
                best = d;
            }
        }
        let w = winding_at(&outline, p.x, p.y);
        if inside_rule(w, "nonzero") {
            -best
        } else {
            best
        }
    })
}

// ---------------------------------------------------------------------
// § 23.5 Something paths can't do
// ---------------------------------------------------------------------

/// `min(a, b)` when `k` is 0 or less; otherwise dips below both by up to
/// `k / 4` where they're within `k` of each other, rounding the crease
/// where two shapes meet into a fillet.
pub fn smooth_min(a: f64, b: f64, k: f64) -> f64 {
    if k <= 0.0 {
        return a.min(b);
    }
    let h = (k - (a - b).abs()).max(0.0) / k;
    a.min(b) - h * h * k / 4.0
}

pub fn field_smooth_union(a: &Field, b: &Field, k: f64) -> Field {
    field_zip(a, b, move |x, y| smooth_min(x, y, k))
}

/// A 160 by 160 field: a circle and a rounded box, smooth-unioned by `k`.
pub fn fillet_field(k: f64) -> Field {
    field(160, 160, move |p| {
        smooth_min(
            sd_circle(p, point(60.0, 70.0), 36.0),
            sd_rounded_box(p, point(105.0, 95.0), 40.0, 25.0, 4.0),
            k,
        )
    })
}

// ---------------------------------------------------------------------
// § 23.6 The distance transform
// ---------------------------------------------------------------------

/// More than any squared distance on the grid, so "far" stays a whole
/// number and infinity-minus-infinity never comes up.
pub fn far_value(w: usize, h: usize) -> f64 {
    (w * w + h * h) as f64
}

fn parabola_cross(f: &[f64], q: usize, p: usize) -> f64 {
    ((f[q] + (q * q) as f64) - (f[p] + (p * p) as f64)) / (2.0 * q as f64 - 2.0 * p as f64)
}

/// The lower envelope of a row of parabolas, one foot per pixel:
/// Felzenszwalb and Huttenlocher's one-dimensional squared distance
/// transform.
pub fn edt_1d(f: &[f64]) -> Vec<f64> {
    let n = f.len();
    let mut v = vec![0usize; n];
    let mut z = vec![0.0f64; n + 2];
    z[0] = f64::NEG_INFINITY;
    z[1] = f64::INFINITY;
    let mut k = 0usize;
    for q in 1..n {
        let mut s = parabola_cross(f, q, v[k]);
        while s <= z[k] {
            k -= 1;
            s = parabola_cross(f, q, v[k]);
        }
        k += 1;
        v[k] = q;
        z[k] = s;
        z[k + 1] = f64::INFINITY;
    }
    let mut d = vec![0.0; n];
    let mut k2 = 0usize;
    for q in 0..n {
        while z[k2 + 1] < q as f64 {
            k2 += 1;
        }
        let dq = q as f64 - v[k2] as f64;
        d[q] = dq * dq + f[v[k2]];
    }
    d
}

/// For every pixel of a bitmap, the squared distance from its center to
/// the nearest "on" center: `edt_1d` down every column, then along every
/// row of the result.
pub fn distance_transform(bits: &[bool], w: usize, h: usize) -> Vec<f64> {
    let far = far_value(w, h);
    let mut cols_done = vec![0.0; w * h];
    for x in 0..w {
        let col: Vec<f64> = (0..h).map(|y| if bits[y * w + x] { 0.0 } else { far }).collect();
        let d = edt_1d(&col);
        for y in 0..h {
            cols_done[y * w + x] = d[y];
        }
    }
    let mut out = vec![0.0; w * h];
    for y in 0..h {
        let row: Vec<f64> = (0..w).map(|x| cols_done[y * w + x]).collect();
        let d = edt_1d(&row);
        for x in 0..w {
            out[y * w + x] = d[x];
        }
    }
    out
}

/// The same, by trying every pixel that's on.
pub fn brute_distance_transform(bits: &[bool], w: usize, h: usize) -> Vec<f64> {
    let far = far_value(w, h);
    let on: Vec<(usize, usize)> = (0..h)
        .flat_map(|y| (0..w).filter(move |&x| bits[y * w + x]).map(move |x| (x, y)))
        .collect();
    let mut out = vec![far; w * h];
    for y in 0..h {
        for x in 0..w {
            let mut best = far;
            for &(ox, oy) in &on {
                let dx = x as f64 - ox as f64;
                let dy = y as f64 - oy as f64;
                let d = dx * dx + dy * dy;
                if d < best {
                    best = d;
                }
            }
            out[y * w + x] = best;
        }
    }
    out
}

/// On where the coverage is at least 0.5.
pub fn bits_of(cov: &CoverageBuffer) -> Vec<bool> {
    (0..cov.height)
        .flat_map(|y| (0..cov.width).map(move |x| coverage_at(cov, x as i64, y as i64) >= 0.5))
        .collect()
}

/// A coverage buffer built directly from a list of values, row by row.
pub fn coverage_of(w: usize, h: usize, values: &[f64]) -> CoverageBuffer {
    let mut cov = coverage_buffer(w, h);
    for y in 0..h {
        for x in 0..w {
            set_coverage(&mut cov, x as i64, y as i64, values[y * w + x]);
        }
    }
    cov
}

/// Any coverage buffer, turned into a field: two distance transforms,
/// one to the nearest "on" pixel and one to the nearest "off", less half
/// a pixel each, which puts the edge between the centers.
pub fn field_from_coverage(cov: &CoverageBuffer) -> Field {
    let w = cov.width;
    let h = cov.height;
    let bits = bits_of(cov);
    let not_bits: Vec<bool> = bits.iter().map(|&b| !b).collect();
    let d_on = distance_transform(&bits, w, h);
    let d_off = distance_transform(&not_bits, w, h);
    let mut values = vec![0.0; w * h];
    for i in 0..w * h {
        values[i] = if bits[i] { -(d_off[i].sqrt() - 0.5) } else { d_on[i].sqrt() - 0.5 };
    }
    Field { width: w, height: h, values }
}

/// Roboto's `g` at 48 pixels to the em, origin `(14, 44)`, filled by
/// chapter 7 into a 64 by 64 buffer.
pub fn transform_bitmap() -> CoverageBuffer {
    let font = roboto();
    let m = text_matrix(&font, 48.0, 14.0, 44.0);
    let p = glyph_path(&font, "g", m, 0.1);
    fill_path(&p, "nonzero", 64, 64)
}

// ---------------------------------------------------------------------
// § 23.7 Glyph atlases
// ---------------------------------------------------------------------

/// A baked glyph: one or more fields (channels) over a texel box, with
/// the box's own corner (`left`, `top`) in device pixels at the baked
/// size.
#[derive(Debug, Clone)]
pub struct Baked {
    pub channels: Vec<Field>,
    pub left: i64,
    pub top: i64,
    pub width: usize,
    pub height: usize,
}

/// Chapter 17's bitmap box at the quarter 0, grown by `spread` texels on
/// every side, and the matrix that puts the box's own corner at the
/// origin.
pub fn bake_box(font: &Font, name: &str, size: f64, spread: f64) -> (i64, i64, usize, usize, Matrix3) {
    let s = size / font.units_per_em;
    let (x0, y0, x1, y1) = glyph_bounds(font, name);
    let spread_i = spread.round() as i64;
    let left = (x0 * s).floor() as i64 - spread_i;
    let right = (x1 * s).ceil() as i64 + spread_i;
    let top = (-y1 * s).floor() as i64 - spread_i;
    let bottom = (-y0 * s).ceil() as i64 + spread_i;
    let m = text_matrix(font, size, -left as f64, -top as f64);
    (left, top, (right - left).max(0) as usize, (bottom - top).max(0) as usize, m)
}

/// A baked glyph: one field over the box, the glyph's signed distance at
/// every texel center, clamped to `+/- spread`.
pub fn bake_sdf(font: &Font, name: &str, size: f64, spread: f64) -> Baked {
    let (left, top, width, height, m) = bake_box(font, name, size, spread);
    let curves = quadratics_of_glyph(font, name, m);
    let outline = glyph_path(font, name, m, 0.01);
    let f = field(width, height, move |p| {
        let mut best = f64::INFINITY;
        for c in &curves {
            let d = distance_to_quadratic(p, c);
            if d < best {
                best = d;
            }
        }
        let w = winding_at(&outline, p.x, p.y);
        let signed = if inside_rule(w, "nonzero") { -best } else { best };
        signed.clamp(-spread, spread)
    });
    Baked { channels: vec![f], left, top, width, height }
}

/// Chapter 11's bilinear sample, in texel-center space.
pub fn sample_field(f: &Field, sx: f64, sy: f64) -> f64 {
    let gx = sx - 0.5;
    let gy = sy - 0.5;
    let x0 = gx.floor() as i64;
    let y0 = gy.floor() as i64;
    let fx = gx - x0 as f64;
    let fy = gy - y0 as f64;
    let get = |xi: i64, yi: i64| -> f64 {
        let cx = xi.clamp(0, f.width as i64 - 1) as usize;
        let cy = yi.clamp(0, f.height as i64 - 1) as usize;
        f.values[cy * f.width + cx]
    };
    let v00 = get(x0, y0);
    let v10 = get(x0 + 1, y0);
    let v01 = get(x0, y0 + 1);
    let v11 = get(x0 + 1, y0 + 1);
    let top = v00 * (1.0 - fx) + v10 * fx;
    let bottom = v01 * (1.0 - fx) + v11 * fx;
    top * (1.0 - fy) + bottom * fy
}

pub fn median3(a: f64, b: f64, c: f64) -> f64 {
    let lo = a.min(b);
    let hi = a.max(b);
    lo.max(hi.min(c))
}

fn baked_bounds(baked: &Baked, scale: f64, x: f64, y: f64) -> (i64, i64, i64, i64) {
    let x0 = (x + baked.left as f64 * scale).floor() as i64;
    let y0 = (y + baked.top as f64 * scale).floor() as i64;
    let x1 = (x + (baked.left as f64 + baked.width as f64) * scale).ceil() as i64;
    let y1 = (y + (baked.top as f64 + baked.height as f64) * scale).ceil() as i64;
    (x0, y0, x1, y1)
}

/// Draws a baked glyph with its origin at `(x, y)`, each texel `scale`
/// pixels wide: samples every channel, turns the one channel (or the
/// median of the first three) into coverage by `clamp(0.5 - scale *
/// distance, 0, 1)`, and mixes toward `col` in linear light.
pub fn draw_baked(c: &mut Canvas, baked: &Baked, scale: f64, x: f64, y: f64, col: Color) {
    let (x0, y0, x1, y1) = baked_bounds(baked, scale, x, y);
    for py in y0..y1 {
        if py < 0 || py as usize >= c.height {
            continue;
        }
        for px in x0..x1 {
            if px < 0 || px as usize >= c.width {
                continue;
            }
            let u = (px as f64 + 0.5 - x) / scale - baked.left as f64;
            let v = (py as f64 + 0.5 - y) / scale - baked.top as f64;
            let samples: Vec<f64> = baked.channels.iter().map(|ch| sample_field(ch, u, v)).collect();
            let distance =
                if samples.len() == 1 { samples[0] } else { median3(samples[0], samples[1], samples[2]) };
            let m = (0.5 - scale * distance).clamp(0.0, 1.0);
            if m > 0.0 {
                let existing = pixel_at(c, px, py);
                write_pixel(c, px, py, mix_with(existing, col, m, true));
            }
        }
    }
}

/// Draws a baked glyph the way `draw_baked` does, but with the distance
/// (in pixels: `scale` times the fourth channel when `use_true_channel`,
/// else `scale` times the median of the first three) turned into a mix
/// by `k_of` instead of `clamp(0.5 - d, 0, 1)`.
pub fn draw_effect<K: Fn(f64) -> f64>(
    c: &mut Canvas,
    baked: &Baked,
    scale: f64,
    x: f64,
    y: f64,
    col: Color,
    use_true_channel: bool,
    k_of: K,
) {
    let (x0, y0, x1, y1) = baked_bounds(baked, scale, x, y);
    for py in y0..y1 {
        if py < 0 || py as usize >= c.height {
            continue;
        }
        for px in x0..x1 {
            if px < 0 || px as usize >= c.width {
                continue;
            }
            let u = (px as f64 + 0.5 - x) / scale - baked.left as f64;
            let v = (py as f64 + 0.5 - y) / scale - baked.top as f64;
            let samples: Vec<f64> = baked.channels.iter().map(|ch| sample_field(ch, u, v)).collect();
            let distance_texels =
                if use_true_channel { samples[3] } else { median3(samples[0], samples[1], samples[2]) };
            let m = k_of(scale * distance_texels).clamp(0.0, 1.0);
            if m > 0.0 {
                let existing = pixel_at(c, px, py);
                write_pixel(c, px, py, mix_with(existing, col, m, true));
            }
        }
    }
}

/// Whether unit directions `a` (incoming) and `b` (outgoing) make a
/// corner: turned by more than about eight degrees.
pub fn is_corner(a: Tuple, b: Tuple) -> bool {
    dot(a, b) <= 0.0 || cross(a, b).abs() > (3.0_f64).sin()
}

fn curve_chord_dir(c: &Curve) -> Tuple {
    normalize(c.points[c.points.len() - 1] - c.points[0])
}

fn direction_at(c: &Curve, t: f64) -> Tuple {
    let d = derivative(c, t);
    if magnitude(d) < 1e-12 {
        curve_chord_dir(c)
    } else {
        normalize(d)
    }
}

const RED: i32 = 1;
const GREEN: i32 = 2;
const BLUE: i32 = 4;
const CH23_YELLOW_MASK: i32 = 3;
const CH23_MAGENTA_MASK: i32 = 5;
const CH23_CYAN_MASK: i32 = 6;
const CH23_WHITE_MASK: i32 = 7;

/// One closed contour's curves, coloured for a multi-channel field:
/// (curves, masks), rotated to start at the first corner. No corners:
/// every mask white. One corner: split until there are at least three
/// curves, then a third each of cyan, white, magenta. More corners: runs
/// alternate cyan and magenta, the last yellow when the count is odd.
pub fn color_edges(contour: &[Curve]) -> (Vec<Curve>, Vec<i32>) {
    let m = contour.len();
    let mut corner_idx: Vec<usize> = Vec::new();
    for j in 0..m {
        let prev = (j + m - 1) % m;
        if is_corner(direction_at(&contour[prev], 1.0), direction_at(&contour[j], 0.0)) {
            corner_idx.push(j);
        }
    }
    if corner_idx.is_empty() {
        return (contour.to_vec(), vec![CH23_WHITE_MASK; m]);
    }

    let start = corner_idx[0];
    let mut curves: Vec<Curve> = (0..m).map(|i| contour[(start + i) % m].clone()).collect();
    let mut rel_corners: Vec<usize> = corner_idx.iter().map(|&c| (c + m - start) % m).collect();
    rel_corners.sort_unstable();

    if rel_corners.len() == 1 {
        while curves.len() < 3 {
            let mut next = Vec::new();
            for c in &curves {
                let (a, b) = split_at(c, 0.5);
                next.push(a);
                next.push(b);
            }
            curves = next;
        }
        let mm = curves.len();
        let masks: Vec<i32> = (0..mm)
            .map(|j| match (3 * j) / mm {
                0 => CH23_CYAN_MASK,
                1 => CH23_WHITE_MASK,
                _ => CH23_MAGENTA_MASK,
            })
            .collect();
        (curves, masks)
    } else {
        let runs = rel_corners.len();
        let mut masks = vec![0; curves.len()];
        for (run_i, &c0) in rel_corners.iter().enumerate() {
            let c1 = if run_i + 1 < runs { rel_corners[run_i + 1] } else { curves.len() };
            let color = if run_i == runs - 1 && runs % 2 == 1 {
                CH23_YELLOW_MASK
            } else if run_i % 2 == 0 {
                CH23_CYAN_MASK
            } else {
                CH23_MAGENTA_MASK
            };
            for k in c0..c1 {
                masks[k] = color;
            }
        }
        (curves, masks)
    }
}

/// A straight edge as chapter 16 makes one: a quadratic with its control
/// point at the chord's own midpoint.
pub fn line_curve(a: Tuple, b: Tuple) -> Curve {
    quadratic(a, (a + b) * 0.5, b)
}

/// Eight quadratics approximating a circle, ends on it at `2 pi i / 8`.
pub fn circle_curves(cx: f64, cy: f64, r: f64) -> Vec<Curve> {
    let n = 8;
    let cr = r / (std::f64::consts::PI / 8.0).cos();
    (0..n)
        .map(|i| {
            let a0 = 2.0 * std::f64::consts::PI * i as f64 / n as f64;
            let a1 = 2.0 * std::f64::consts::PI * (i as f64 + 1.0) / n as f64;
            let am = (a0 + a1) / 2.0;
            let p0 = point(cx + r * a0.cos(), cy + r * a0.sin());
            let p1 = point(cx + cr * am.cos(), cy + cr * am.sin());
            let p2 = point(cx + r * a1.cos(), cy + r * a1.sin());
            quadratic(p0, p1, p2)
        })
        .collect()
}

/// The distance from `p` to curve `c`'s nearest point at `t`, except past
/// an end: there it's the distance to the line the edge would carry on
/// along (its pseudo-distance), so a corner's two private channels see
/// only their own edge, extended straight.
pub fn pseudo_distance(p: Tuple, c: &Curve, t: f64, d: f64) -> f64 {
    let start = c.points[0];
    let end = c.points[c.points.len() - 1];
    let start_dir = direction_at(c, 0.0);
    let end_dir = direction_at(c, 1.0);
    if (t == 0.0 && dot(p - start, start_dir) < 0.0) || (t == 1.0 && dot(p - end, end_dir) > 0.0) {
        let (dir, anchor) = if t == 0.0 { (start_dir, start) } else { (end_dir, end) };
        let side = cross(dir, p - anchor);
        return if side > 0.0 { -side.abs() } else { side.abs() };
    }
    let dir = direction_at(c, t);
    let side = cross(dir, p - point_at(c, t));
    if side > 0.0 {
        -d
    } else {
        d
    }
}

/// A multi-channel field over the box: at each texel center, per channel,
/// the least distance among the coloured edges carrying it (ties at an
/// end broken by whichever edge meets `p` closer to a right angle), as
/// that edge's `pseudo_distance`, clamped to `+/- spread`.
pub fn bake_msdf(font: &Font, name: &str, size: f64, spread: f64) -> Baked {
    let (left, top, width, height, m) = bake_box(font, name, size, spread);
    let mut edges: Vec<(Curve, i32)> = Vec::new();
    for contour in glyph_outline(font, name) {
        let transformed: Vec<Curve> = contour.iter().map(|c| transform_curve(c, m)).collect();
        let (colored, masks) = color_edges(&transformed);
        for (c, mask) in colored.into_iter().zip(masks.into_iter()) {
            edges.push((c, mask));
        }
    }
    let edges = std::rc::Rc::new(edges);
    let channel_bits = [RED, GREEN, BLUE];
    let channels: Vec<Field> = channel_bits
        .iter()
        .map(|&ch| {
            let edges = edges.clone();
            field(width, height, move |p| {
                let mut best: Option<(usize, f64, f64, f64)> = None; // (idx, d, t, o)
                for (idx, (c, mask)) in edges.iter().enumerate() {
                    if mask & ch == 0 {
                        continue;
                    }
                    let t = nearest_t_quadratic(p, c);
                    let d = magnitude(point_at(c, t) - p);
                    let o = if t == 0.0 || t == 1.0 {
                        let dir = direction_at(c, t);
                        dot(dir, normalize(p - point_at(c, t))).abs()
                    } else {
                        0.0
                    };
                    let better = match best {
                        None => true,
                        Some((_, bd, _, bo)) => {
                            if d < bd - 1e-12 {
                                true
                            } else {
                                (d - bd).abs() <= 1e-12 && o < bo
                            }
                        }
                    };
                    if better {
                        best = Some((idx, d, t, o));
                    }
                }
                match best {
                    Some((idx, d, t, _o)) => {
                        let (c, _mask) = &edges[idx];
                        pseudo_distance(p, c, t, d).clamp(-spread, spread)
                    }
                    None => spread,
                }
            })
        })
        .collect();
    Baked { channels, left, top, width, height }
}

/// `bake_msdf` with `bake_sdf`'s ordinary signed distance as a fourth
/// channel, for effects that reach away from the edge.
pub fn bake_mtsdf(font: &Font, name: &str, size: f64, spread: f64) -> Baked {
    let mut b = bake_msdf(font, name, size, spread);
    let sdf = bake_sdf(font, name, size, spread);
    b.channels.push(sdf.channels.into_iter().next().unwrap());
    b
}

// ---------------------------------------------------------------------
// § 23.8 Fields compose approximately
// ---------------------------------------------------------------------

/// Two circles of radius 40, overlapping in a waist.
pub fn peanut() -> (Path, Path) {
    (circle_path(60.0, 80.0, 40.0, 96), circle_path(110.0, 80.0, 40.0, 96))
}

pub fn min_of(a: f64, b: f64) -> f64 {
    a.min(b)
}

// ---------------------------------------------------------------------
// § 23.9 Putting it together -- the plate
// ---------------------------------------------------------------------

const CH23_PAPER: Color = Color { red: 0.02, green: 0.02, blue: 0.025 };
const CH23_ORANGE: Color = Color { red: 0.9, green: 0.55, blue: 0.1 };
const CH23_CYAN: Color = Color { red: 0.2, green: 0.75, blue: 0.9 };
const CH23_MAGENTA: Color = Color { red: 0.85, green: 0.2, blue: 0.55 };
const CH23_DIM: Color = Color { red: 0.3, green: 0.3, blue: 0.34 };
const CH23_PALE: Color = Color { red: 0.92, green: 0.9, blue: 0.82 };
const CH23_BLACK: Color = Color { red: 0.0, green: 0.0, blue: 0.0 };

fn stack_below(a: &Canvas, b: &Canvas) -> Canvas {
    let width = a.width.max(b.width);
    let mut c = canvas(width, a.height + b.height);
    for y in 0..a.height as i64 {
        for x in 0..a.width as i64 {
            write_pixel(&mut c, x, y, pixel_at(a, x, y));
        }
    }
    for y in 0..b.height as i64 {
        for x in 0..b.width as i64 {
            write_pixel(&mut c, x, y + a.height as i64, pixel_at(b, x, y));
        }
    }
    c
}

/// `paint_through` sampling the field's coverage.
pub fn paint_field(c: &mut Canvas, f: &Field, col: Color) {
    let cov = field_coverage(f);
    paint_through(c, &cov, col);
}

/// Orange outside, cyan inside, banded every six pixels, pale near the
/// zero line.
fn band_color(d: f64) -> Color {
    let tint = if d > 0.0 { CH23_ORANGE } else { CH23_CYAN };
    let band_idx = (d.abs() / 6.0).floor() as i64;
    let alpha = if band_idx.rem_euclid(2) == 0 { 0.12 } else { 0.3 };
    let mut col = mix_with(CH23_PAPER, tint, alpha, true);
    if d.abs() < 1.0 {
        col = mix_with(col, CH23_PALE, 1.0 - d.abs(), true);
    }
    col
}

pub fn band_canvas(f: &Field) -> Canvas {
    let mut c = canvas(f.width, f.height);
    for y in 0..f.height {
        for x in 0..f.width {
            write_pixel(&mut c, x as i64, y as i64, band_color(field_at(f, x as i64, y as i64)));
        }
    }
    c
}

/// Four 160 by 160 fields, banded: a circle, a box, a rounded box, and
/// the star filled even-odd.
pub fn primitive_fields() -> Canvas {
    let f1 = field(160, 160, |p| sd_circle(p, point(80.0, 80.0), 50.0));
    let f2 = field(160, 160, |p| sd_box(p, point(80.0, 80.0), 55.0, 35.0));
    let f3 = field(160, 160, |p| sd_rounded_box(p, point(80.0, 80.0), 55.0, 35.0, 20.0));
    let f4 = polygon_field(&star(), "evenodd", 160, 160);
    let mut result = band_canvas(&f1);
    for f in [&f2, &f3, &f4] {
        result = side_by_side(&result, &band_canvas(f));
    }
    result
}

fn error_panel(err: &CoverageBuffer) -> Canvas {
    let mut c = canvas(err.width, err.height);
    for y in 0..err.height {
        for x in 0..err.width {
            let e = coverage_at(err, x as i64, y as i64);
            let col = mix_with(CH23_PAPER, CH23_MAGENTA, (4.0 * e).min(1.0), true);
            write_pixel(&mut c, x as i64, y as i64, col);
        }
    }
    c
}

/// The star's field painted orange, then its error against chapter 7's
/// exact fill, raw and after chapter 22's `simplify`.
pub fn error_map() -> Canvas {
    let s = star();
    let exact = fill_path(&s, "nonzero", 160, 160);

    let mut panel1 = canvas(160, 160);
    fill(&mut panel1, CH23_PAPER);
    let raw_field = polygon_field(&s, "nonzero", 160, 160);
    paint_field(&mut panel1, &raw_field, CH23_ORANGE);

    let raw_err = coverage_error(&field_coverage(&raw_field), &exact);
    let panel2 = error_panel(&raw_err);

    let clean_field = polygon_field(&simplify(&s, "nonzero"), "nonzero", 160, 160);
    let clean_err = coverage_error(&field_coverage(&clean_field), &exact);
    let panel3 = error_panel(&clean_err);

    side_by_side(&side_by_side(&panel1, &panel2), &panel3)
}

fn path_panel(p: &Path) -> Canvas {
    let mut c = canvas(200, 200);
    fill(&mut c, CH23_PAPER);
    paint_through(&mut c, &fill_path(p, "nonzero", 200, 200), CH23_ORANGE);
    c
}

fn field_panel(f: &Field) -> Canvas {
    let mut c = canvas(200, 200);
    fill(&mut c, CH23_PAPER);
    paint_field(&mut c, f, CH23_ORANGE);
    c
}

/// Chapters 13, 14 and 22's work, by path (top row) and by field (bottom
/// row): a stroke, a curve's stroke, and a boolean xor.
pub fn fields_vs_paths() -> Canvas {
    let moved_star = transform_path(&star(), translation(19.5, 19.5));

    let p1 = path_panel(&stroke_to_path(&moved_star, 10.0, "round", "round", 4.0));
    let p2 = path_panel(&stroke_curve_to_path(&s_curve(), 20.0, "round", 0.05));
    let p3 = path_panel(&combine(&plate_glyph(), "nonzero", &plate_star(), "evenodd", "xor"));
    let top = side_by_side(&side_by_side(&p1, &p2), &p3);

    let q1 = field_panel(&field_stroke(&polygon_field(&moved_star, "nonzero", 200, 200), 10.0));
    let q2 = field_panel(&field_stroke(&cubic_field(&s_curve(), 200, 200), 20.0));
    let q3 = field_panel(&field_xor(&plate_glyph_field(), &polygon_field(&plate_star(), "evenodd", 200, 200)));
    let bottom = side_by_side(&side_by_side(&q1, &q2), &q3);

    stack_below(&top, &bottom)
}

fn fillet_panel(k: f64) -> Canvas {
    let mut c = canvas(160, 160);
    fill(&mut c, CH23_PAPER);
    let f = fillet_field(k);
    paint_field(&mut c, &f, CH23_ORANGE);
    paint_field(&mut c, &field_stroke(&f, 1.5), CH23_PALE);
    c
}

/// `fillet_field(k)` for `k = 0, 8, 16, 32`, side by side.
pub fn fillets() -> Canvas {
    let ks = [0.0, 8.0, 16.0, 32.0];
    let mut result = fillet_panel(ks[0]);
    for &k in &ks[1..] {
        result = side_by_side(&result, &fillet_panel(k));
    }
    result
}

/// A bitmap, its field by the distance transform, and that field offset
/// by 6, 3 and 0, each magnified 3 times.
pub fn transform_demo() -> Canvas {
    let bitmap = transform_bitmap();
    let f = field_from_coverage(&bitmap);

    let mut p1 = canvas(64, 64);
    fill(&mut p1, CH23_PAPER);
    paint_through(&mut p1, &bitmap, CH23_ORANGE);

    let p2 = band_canvas(&f);

    let mut p3 = canvas(64, 64);
    fill(&mut p3, CH23_PAPER);
    for (r, col) in [(6.0, CH23_MAGENTA), (3.0, CH23_CYAN), (0.0, CH23_ORANGE)] {
        let offset = field_offset(&f, r);
        paint_field(&mut p3, &field_stroke(&offset, 1.5), col);
    }

    let m1 = magnify(&p1, 3);
    let m2 = magnify(&p2, 3);
    let m3 = magnify(&p3, 3);
    side_by_side(&side_by_side(&m1, &m2), &m3)
}

fn atlas_panel(baked: &Baked, scale: f64) -> Canvas {
    let mut c = canvas(300, 400);
    fill(&mut c, CH23_PAPER);
    let x = 10.0 - baked.left as f64 * scale;
    let y = 10.0 - baked.top as f64 * scale;
    draw_baked(&mut c, baked, scale, x, y, CH23_ORANGE);
    c
}

/// Four baked glyphs, single- then multi-channel, at two bake sizes.
pub fn atlas_corners() -> Canvas {
    let font = roboto();
    let e_name = glyph_name(&font, 69);
    let k_name = glyph_name(&font, 107);
    let p1 = atlas_panel(&bake_sdf(&font, &e_name, 16.0, 3.0), 20.0);
    let p2 = atlas_panel(&bake_msdf(&font, &e_name, 16.0, 3.0), 20.0);
    let p3 = atlas_panel(&bake_msdf(&font, &k_name, 16.0, 3.0), 20.0);
    let p4 = atlas_panel(&bake_msdf(&font, &k_name, 32.0, 3.0), 10.0);
    side_by_side(&side_by_side(&side_by_side(&p1, &p2), &p3), &p4)
}

fn trap_panel(f: &Field) -> Canvas {
    let mut c = canvas(170, 160);
    fill(&mut c, CH23_PAPER);
    paint_field(&mut c, &field_offset(f, -20.0), CH23_ORANGE);
    paint_field(&mut c, &field_stroke(f, 1.5), CH23_DIM);
    c
}

/// The peanut's union by `min` (wrong inside) and by chapter 22's
/// `combine` (right), each shrunk by 20.
pub fn trap_shrink() -> Canvas {
    let (a, b) = peanut();
    let fa = polygon_field(&a, "nonzero", 170, 160);
    let fb = polygon_field(&b, "nonzero", 170, 160);
    let min_field = field_union(&fa, &fb);
    let union_path = combine(&a, "nonzero", &b, "nonzero", "union");
    let true_field = polygon_field(&union_path, "nonzero", 170, 160);
    side_by_side(&trap_panel(&min_field), &trap_panel(&true_field))
}

fn ampersand_field() -> Field {
    let font = roboto();
    let name = glyph_name(&font, 38);
    let m = text_matrix(&font, 170.0, 38.0, 164.0);
    let curves = quadratics_of_glyph(&font, &name, m);
    let outline = glyph_path(&font, &name, m, 0.01);
    field(200, 200, move |p| {
        let mut best = f64::INFINITY;
        for c in &curves {
            let d = distance_to_quadratic(p, c);
            if d < best {
                best = d;
            }
        }
        let w = winding_at(&outline, p.x, p.y);
        if inside_rule(w, "nonzero") {
            -best
        } else {
            best
        }
    })
}

/// One field, four ways: banded, filled, stroked, and glowing.
pub fn plate_23() -> Canvas {
    let f = ampersand_field();
    let p1 = band_canvas(&f);

    let mut p2 = canvas(200, 200);
    fill(&mut p2, CH23_PAPER);
    paint_field(&mut p2, &f, CH23_ORANGE);

    let mut p3 = canvas(200, 200);
    fill(&mut p3, CH23_PAPER);
    paint_field(&mut p3, &field_stroke(&f, 4.0), CH23_CYAN);

    let mut p4 = canvas(200, 200);
    for y in 0..200i64 {
        for x in 0..200i64 {
            let d = field_at(&f, x, y);
            let col =
                if d > 0.0 { mix_with(CH23_PAPER, CH23_MAGENTA, 0.8 * (-d / 10.0).exp(), true) } else { CH23_PAPER };
            write_pixel(&mut p4, x, y, col);
        }
    }
    paint_field(&mut p4, &f, CH23_ORANGE);

    side_by_side(&side_by_side(&side_by_side(&p1, &p2), &p3), &p4)
}

/// The word DISTANCE, each glyph baked `mtsdf` at 32 with spread 4, drawn
/// at scale 5: a moved black shadow, a magenta glow, an orange fill and a
/// pale outline, each its own formula on its own channel(s).
pub fn title() -> Canvas {
    let font = roboto();
    let mut c = canvas(900, 220);
    fill(&mut c, CH23_PAPER);
    let placements = layout_run(&font, "DISTANCE", 160.0, 78.0, 172.0, true);
    let baked: Vec<Baked> = placements.iter().map(|pl| bake_mtsdf(&font, &pl.name, 32.0, 4.0)).collect();
    let scale = 5.0;
    for (pl, b) in placements.iter().zip(baked.iter()) {
        draw_effect(&mut c, b, scale, pl.x + 8.0, pl.y + 8.0, CH23_BLACK, true, |d| {
            0.6 * ((10.0 - d) / 20.0).clamp(0.0, 1.0)
        });
    }
    for (pl, b) in placements.iter().zip(baked.iter()) {
        draw_effect(&mut c, b, scale, pl.x, pl.y, CH23_MAGENTA, true, |d| {
            0.8 * (1.0 - (d / 20.0).clamp(0.0, 1.0)).powi(2)
        });
    }
    for (pl, b) in placements.iter().zip(baked.iter()) {
        draw_effect(&mut c, b, scale, pl.x, pl.y, CH23_ORANGE, false, |d| (0.5 - d).clamp(0.0, 1.0));
    }
    for (pl, b) in placements.iter().zip(baked.iter()) {
        draw_effect(&mut c, b, scale, pl.x, pl.y, CH23_PALE, false, |d| {
            (0.5 - (d.abs() - 1.5)).clamp(0.0, 1.0)
        });
    }
    c
}
