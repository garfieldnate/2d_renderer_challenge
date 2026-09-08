// features/chapter13-plate.feature

use renderer::{caps_demo, canvas_to_p6, joins_plate, max_channel_difference, plate_13, ppm_pixel, read_file};

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
fn the_three_joins() {
    let c = joins_plate();
    let reference = read_file("reference/chapter-13/joins.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 480);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 55, 80, (206, 206, 212), 1);
    assert_pixel_within(&p6, 80, 128, (206, 206, 212), 1);
    assert_pixel_within(&p6, 5, 150, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_13_test() {
    let c = plate_13();
    let reference = read_file("reference/chapter-13/plate-13.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 960);
    assert_eq!(c.height, 320);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_three_caps() {
    let c = caps_demo();
    let reference = read_file("reference/chapter-13/caps.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 480);
    assert_eq!(c.height, 80);
    assert_pixel_within(&p6, 80, 40, (206, 206, 212), 1);
    assert_pixel_within(&p6, 240, 40, (206, 206, 212), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
