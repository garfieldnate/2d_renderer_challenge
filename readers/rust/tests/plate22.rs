// features/chapter22-plate.feature

use renderer::{canvas_to_p6, max_channel_difference, plate_22, ppm_pixel, read_file, seal};

fn assert_pixel(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} +/- {tol}, got {actual:?}"
    );
}

#[test]
fn plate_22_test() {
    let c = plate_22();
    let ref_ppm = read_file("reference/chapter-22/plate-22.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 800);
    assert_eq!(c.height, 200);
    assert_pixel(&p6, 129, 75, (243, 196, 89), 1);
    assert_pixel(&p6, 129, 114, (243, 196, 89), 1);
    assert_pixel(&p6, 156, 96, (243, 196, 89), 1);
    assert_pixel(&p6, 329, 75, (243, 196, 89), 1);
    assert_pixel(&p6, 329, 114, (39, 39, 44), 1);
    assert_pixel(&p6, 356, 96, (39, 39, 44), 1);
    assert_pixel(&p6, 529, 75, (39, 39, 44), 1);
    assert_pixel(&p6, 529, 114, (243, 196, 89), 1);
    assert_pixel(&p6, 556, 96, (39, 39, 44), 1);
    assert_pixel(&p6, 729, 75, (39, 39, 44), 1);
    assert_pixel(&p6, 729, 114, (243, 196, 89), 1);
    assert_pixel(&p6, 756, 96, (243, 196, 89), 1);
    assert_pixel(&p6, 5, 5, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &ref_ppm) <= 1);
}

#[test]
fn the_seal_test() {
    let c = seal();
    let ref_ppm = read_file("reference/chapter-22/seal.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 480);
    assert_eq!(c.height, 480);
    assert_pixel(&p6, 240, 452, (243, 196, 89), 1);
    assert_pixel(&p6, 240, 40, (39, 39, 44), 1);
    assert_pixel(&p6, 240, 200, (243, 196, 89), 1);
    assert_pixel(&p6, 76, 215, (39, 39, 44), 1);
    assert_pixel(&p6, 430, 240, (243, 196, 89), 1);
    assert_pixel(&p6, 240, 352, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &ref_ppm) <= 1);
}
