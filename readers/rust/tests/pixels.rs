// features/chapter09-pixels.feature

use renderer::{color, from_color, lerp_pixel, opaque, pixel, pixel_alpha, pixel_color, pixels_eq, colors_eq, CLEAR};

#[test]
fn a_colour_and_an_alpha_premultiply_into_a_pixel() {
    let p = from_color(color(1.0, 0.0, 0.0), 0.5);
    assert!(pixels_eq(p, pixel(0.5, 0.0, 0.0, 0.5)));
    assert!(pixel_alpha(p) == 0.5);
    assert!(colors_eq(pixel_color(p), color(1.0, 0.0, 0.0)));
}

#[test]
fn opaque_is_alpha_1_and_leaves_the_colour_alone() {
    let p = opaque(color(0.2, 0.4, 0.8));
    assert!(pixels_eq(p, pixel(0.2, 0.4, 0.8, 1.0)));
    assert!(colors_eq(pixel_color(p), color(0.2, 0.4, 0.8)));
}

#[test]
fn a_transparent_pixel_has_no_colour() {
    assert!(pixels_eq(CLEAR, pixel(0.0, 0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_color(CLEAR), color(0.0, 0.0, 0.0)));
}

#[test]
fn averaging_premultiplied_pixels_stays_clean() {
    let red = opaque(color(1.0, 0.0, 0.0));
    let half = lerp_pixel(red, CLEAR, 0.5);
    assert!(pixels_eq(half, pixel(0.5, 0.0, 0.0, 0.5)));
    assert!(colors_eq(pixel_color(half), color(1.0, 0.0, 0.0)));
}

#[test]
fn a_pixel_halfway_between_opaque_red_and_opaque_blue() {
    let m = lerp_pixel(opaque(color(1.0, 0.0, 0.0)), opaque(color(0.0, 0.0, 1.0)), 0.5);
    assert!(pixels_eq(m, pixel(0.5, 0.0, 0.5, 1.0)));
}
