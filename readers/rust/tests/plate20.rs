// features/chapter20-plate.feature

use renderer::{canvas_to_p6, harbor, max_channel_difference, plate_20, ppm_pixel, read_file, rose};

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
fn a_harbor_at_dusk() {
    let c = harbor();
    let reference = read_file("reference/chapter-20/harbor.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 480);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 240, 20, (24, 18, 51), 1);
    assert_pixel_within(&p6, 20, 280, (67, 32, 68), 1);
    assert_pixel_within(&p6, 418, 156, (200, 50, 60), 1);
    assert_pixel_within(&p6, 418, 161, (244, 239, 230), 1);
    assert_pixel_within(&p6, 200, 262, (200, 50, 60), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn a_rose_window() {
    let c = rose();
    let reference = read_file("reference/chapter-20/rose.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 400);
    assert_eq!(c.height, 400);
    assert_pixel_within(&p6, 200, 200, (255, 248, 216), 1);
    assert_pixel_within(&p6, 385, 385, (240, 168, 24), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_tiger() {
    let c = plate_20();
    let reference = read_file("reference/chapter-20/tiger.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 450);
    assert_eq!(c.height, 450);
    assert_pixel_within(&p6, 5, 5, (255, 255, 255), 1);
    assert_pixel_within(&p6, 250, 200, (0, 0, 0), 1);
    assert_pixel_within(&p6, 170, 330, (255, 114, 127), 1);
    assert_pixel_within(&p6, 350, 100, (204, 114, 38), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
