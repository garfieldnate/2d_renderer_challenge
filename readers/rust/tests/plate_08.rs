// features/chapter08-plate.feature

use renderer::{canvas_to_p6, drops, flower, max_channel_difference, plate_08, ppm_pixel, read_file};

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
fn the_teardrop_coarse_against_fine() {
    let c = drops();
    let reference = read_file("reference/chapter-08/drops.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 480);
    assert_eq!(c.height, 240);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_flowers() {
    let c = flower();
    let reference = read_file("reference/chapter-08/flower.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 360);
    assert_eq!(c.height, 360);
    assert_pixel_within(&p6, 200, 105, (124, 196, 237), 1);
    assert_pixel_within(&p6, 200, 145, (39, 39, 44), 1);
    assert_pixel_within(&p6, 108, 212, (243, 196, 89), 1);
    assert_pixel_within(&p6, 108, 250, (39, 39, 44), 1);
    assert_pixel_within(&p6, 286, 214, (237, 137, 149), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_8() {
    let c = plate_08();
    let reference = read_file("reference/chapter-08/plate-08.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 720);
    assert_eq!(c.height, 720);
    assert_pixel_within(&p6, 400, 210, (124, 196, 237), 1);
    assert_pixel_within(&p6, 216, 424, (243, 196, 89), 1);
    assert_pixel_within(&p6, 572, 428, (237, 137, 149), 1);
    assert_pixel_within(&p6, 20, 20, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
