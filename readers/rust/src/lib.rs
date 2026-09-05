//! Chapter 1: The Canvas and the Color.
//!
//! A tiny renderer: colors are three floating point numbers that measure
//! light (0.0 = none, 1.0 = full), a canvas is a rectangle of colors, and
//! the PPM writer is the only place that knows about the sRGB transfer
//! function that turns light into the numbers an image file expects.

use std::cell::Cell;
use std::collections::BTreeSet;
use std::fs;
use std::ops::{Add, Mul, Sub};

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
#[derive(Debug, Clone, Copy)]
pub enum Shape {
    Circle { cx: f64, cy: f64, r: f64 },
    Rectangle { x0: f64, y0: f64, x1: f64, y1: f64 },
    HalfPlane { px: f64, py: f64, nx: f64, ny: f64 },
    /// Inside all of four half-planes at once (each a (px, py, nx, ny)
    /// tuple, same layout as `HalfPlane`). `thick_line` is the only thing
    /// that builds one. A fixed-size array rather than `Vec<Shape>` so
    /// `Shape` stays `Copy`, which chapter 2's `inside(s: Shape, ...)`
    /// (by value, called repeatedly on the same shape) already depends on.
    Intersection([(f64, f64, f64, f64); 4]),
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

pub fn inside(s: Shape, x: f64, y: f64) -> bool {
    match s {
        Shape::Circle { cx, cy, r } => {
            let dx = x - cx;
            let dy = y - cy;
            dx * dx + dy * dy <= r * r
        }
        Shape::Rectangle { x0, y0, x1, y1 } => x >= x0 && x <= x1 && y >= y0 && y <= y1,
        Shape::HalfPlane { px, py, nx, ny } => half_plane_inside(px, py, nx, ny, x, y),
        Shape::Intersection(planes) => planes
            .iter()
            .all(|&(px, py, nx, ny)| half_plane_inside(px, py, nx, ny, x, y)),
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
pub fn center_inside(s: Shape, x: i64, y: i64) -> bool {
    inside(s, x as f64 + 0.5, y as f64 + 0.5)
}

/// The binary question, once per pixel: is the center inside? What every
/// renderer did until the nineties, and what some still do with
/// antialiasing off.
pub fn rasterize_centers(s: Shape, width: usize, height: usize) -> CoverageBuffer {
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
pub fn coverage(s: Shape, x: i64, y: i64) -> f64 {
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
pub fn rasterize(s: Shape, width: usize, height: usize) -> CoverageBuffer {
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
    let cov = rasterize_centers(circle(20.0, 20.0, 16.0), 40, 40);
    paint_through(&mut c, &cov, DISC);
    magnify(&c, 8)
}

/// `disc_centers`, with `rasterize` in place of `rasterize_centers` and
/// nothing else changed: the same circle, asked the better question.
pub fn disc_coverage() -> Canvas {
    let mut c = canvas(40, 40);
    fill(&mut c, PAPER);
    let cov = rasterize(circle(20.0, 20.0, 16.0), 40, 40);
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
    let cov = rasterize(circle(20.0, 20.0, 16.0), 40, 40);

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
    let left = rasterize_centers(shape, 40, 40);
    let right = rasterize(shape, 40, 40);

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
pub fn thick_line(x0: i64, y0: i64, x1: i64, y1: i64, width: f64) -> Shape {
    let mut ax = x0 as f64 + 0.5;
    let ay = y0 as f64 + 0.5;
    let mut bx = x1 as f64 + 0.5;
    let by = y1 as f64 + 0.5;
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

/// The fan a third time: each ray a `thick_line` of width 1, rasterized
/// and painted through, then magnified by 2 so the edges are visible.
/// Slow -- twelve 160x160 rasterizations at 64 samples a pixel -- because
/// chapter 2's rasterizer knows nothing about lines; it asks every pixel
/// on the canvas whether the shape is anywhere near it.
pub fn fan_coverage() -> Canvas {
    let mut c = canvas(160, 160);
    fill(&mut c, PAPER_3);
    for (x, y) in ray_ends() {
        let cov = rasterize(thick_line(80, 80, x, y, 1.0), 160, 160);
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
