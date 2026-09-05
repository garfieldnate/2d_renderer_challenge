// features/chapter02-plate.feature

use renderer::{canvas_to_p6, max_channel_difference, plate_02, ppm_pixel, read_file};

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
fn the_plate() {
    let c = plate_02();
    let reference = read_file("reference/chapter-02/plate-02.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 480);
    assert_eq!(c.height, 240);
    assert_pixel_within(&p6, 120, 120, (243, 196, 89), 1);
    assert_pixel_within(&p6, 360, 120, (243, 196, 89), 1);
    assert_pixel_within(&p6, 93, 27, (39, 39, 44), 1);
    assert_pixel_within(&p6, 333, 27, (157, 127, 64), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
