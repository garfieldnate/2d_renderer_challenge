// features/chapter16-plate.feature

use renderer::{
    canvas_to_p6, composite_demo, flip_trap, glyph_plate, max_channel_difference, plate_16,
    ppm_pixel, read_file, sizes,
};

fn assert_pixel_within(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} ± {tol}, got {actual:?}"
    );
}

#[test]
fn the_glyph_and_its_control_points() {
    let c = glyph_plate();
    let reference = read_file("reference/chapter-16/glyph.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 160, 160, (206, 206, 212), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_16_test() {
    let c = plate_16();
    let reference = read_file("reference/chapter-16/plate-16.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 640);
    assert_eq!(c.height, 640);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn a_composite_in_two_inks() {
    let c = composite_demo();
    let reference = read_file("reference/chapter-16/composite.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 240);
    assert_eq!(c.height, 240);
    assert_pixel_within(&p6, 120, 120, (243, 196, 89), 1);
    assert_pixel_within(&p6, 120, 30, (124, 196, 237), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn one_glyph_at_four_sizes() {
    let c = sizes();
    let reference = read_file("reference/chapter-16/sizes.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 240);
    assert_eq!(c.height, 120);
    assert_pixel_within(&p6, 95, 40, (199, 199, 204), 1);
    assert_pixel_within(&p6, 230, 110, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_flip_forgotten() {
    let c = flip_trap();
    let reference = read_file("reference/chapter-16/flip.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 240);
    assert_eq!(c.height, 120);
    assert_pixel_within(&p6, 50, 40, (206, 206, 212), 1);
    assert_pixel_within(&p6, 170, 80, (237, 124, 196), 1);
    assert_pixel_within(&p6, 60, 100, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

