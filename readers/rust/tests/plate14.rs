// features/chapter14-plate.feature

use renderer::{
    canvas_to_p6, fold_demo, max_channel_difference, offsets_plate, plate_14, ppm_pixel, read_file,
    two_strokes,
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
fn two_strokes_test() {
    let c = two_strokes();
    let reference = read_file("reference/chapter-14/two-strokes.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 80, 40, (206, 206, 212), 1);
    assert_pixel_within(&p6, 240, 40, (206, 206, 212), 1);
    assert_pixel_within(&p6, 80, 100, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_fold_under_two_rules() {
    let c = fold_demo();
    let reference = read_file("reference/chapter-14/fold.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 80, 40, (206, 206, 212), 1);
    assert_pixel_within(&p6, 240, 40, (206, 206, 212), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_offsets() {
    let c = offsets_plate();
    let reference = read_file("reference/chapter-14/offsets.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 270);
    assert_pixel_within(&p6, 160, 66, (243, 243, 246), 1);
    assert_pixel_within(&p6, 160, 36, (137, 203, 243), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_14_test() {
    let c = plate_14();
    let reference = read_file("reference/chapter-14/plate-14.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 640);
    assert_eq!(c.height, 540);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
