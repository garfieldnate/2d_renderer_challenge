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

pub fn read_file(path: &str) -> String {
    fs::read_to_string(path).unwrap_or_else(|e| panic!("could not read {path}: {e}"))
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

/// The three whole numbers at pixel (x, y) of a PPM, as a test helper for
/// reading files back.
pub fn ppm_pixel(ppm: &str, x: usize, y: usize) -> (i64, i64, i64) {
    let width = ppm_width(ppm);
    let values = ppm_values(ppm);
    let idx = (y * width + x) * 3;
    (values[idx], values[idx + 1], values[idx + 2])
}

/// The largest difference between any pair of corresponding numbers in two
/// PPM files.
pub fn max_channel_difference(a: &str, b: &str) -> i64 {
    let va = ppm_values(a);
    let vb = ppm_values(b);
    va.iter()
        .zip(vb.iter())
        .map(|(x, y)| (x - y).abs())
        .max()
        .unwrap_or(0)
}

/// The set of all distinct whole numbers after the header.
pub fn distinct_values(ppm: &str) -> usize {
    let set: BTreeSet<i64> = ppm_values(ppm).into_iter().collect();
    set.len()
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

/// The color a fraction `t` of the way from `a` to `b`.
pub fn mix(a: Color, b: Color, t: f64) -> Color {
    if is_linear_blending() {
        a + (b - a) * t
    } else {
        let ea = color(encode(a.red), encode(a.green), encode(a.blue));
        let eb = color(encode(b.red), encode(b.green), encode(b.blue));
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
