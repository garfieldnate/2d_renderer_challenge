// features/chapter01-plate.feature

use renderer::{canvas_to_ppm, is_linear_blending, max_channel_difference, plate_01, ppm_pixel, read_file};

fn assert_pixel_within(ppm: &str, x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(ppm, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} ± {tol}, got {actual:?}"
    );
}

#[test]
fn the_plate() {
    let c = plate_01();
    assert_eq!(c.width, 400);
    assert_eq!(c.height, 180);

    let ppm = canvas_to_ppm(&c);
    assert_eq!(ppm_pixel(&ppm, 0, 20), (0, 0, 0));
    assert_eq!(ppm_pixel(&ppm, 399, 20), (255, 255, 255));
    assert_pixel_within(&ppm, 200, 20, (128, 128, 128), 1);
    assert_pixel_within(&ppm, 200, 65, (188, 188, 188), 1);
    assert_eq!(ppm_pixel(&ppm, 200, 42), (0, 0, 0));
    assert_eq!(ppm_pixel(&ppm, 0, 110), (218, 0, 0));
    assert_eq!(ppm_pixel(&ppm, 399, 110), (0, 149, 39));
    assert_pixel_within(&ppm, 200, 110, (109, 75, 19), 1);
    assert_pixel_within(&ppm, 200, 155, (160, 108, 26), 1);
    assert_eq!(ppm_pixel(&ppm, 200, 87), (0, 0, 0));
    assert_eq!(ppm_pixel(&ppm, 200, 132), (0, 0, 0));
    assert_eq!(ppm_pixel(&ppm, 200, 177), (0, 0, 0));

    let reference = read_file("reference/chapter-01/plate-01.ppm");
    assert!(max_channel_difference(&ppm, &reference) <= 1);
}

#[test]
fn the_switch_was_left_on() {
    let _c = plate_01();
    assert!(is_linear_blending());
}
