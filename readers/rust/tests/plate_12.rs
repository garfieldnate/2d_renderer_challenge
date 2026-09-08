// features/chapter12-plate.feature

use renderer::{canvas_to_p6, clip_demo, max_channel_difference, opacity_plate, plate_12, ppm_pixel, read_file};

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
fn a_single_circle_looks_the_same_either_way_but_the_overlap_does_not() {
    let c = opacity_plate();
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 300);
    assert_eq!(c.height, 150);
    assert_pixel_within(&p6, 40, 62, (185, 145, 71), 1);
    assert_pixel_within(&p6, 190, 62, (185, 145, 71), 1);
    assert_pixel_within(&p6, 75, 72, (203, 156, 165), 1);
    assert_pixel_within(&p6, 225, 72, (176, 103, 112), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
}

#[test]
fn the_opacity_plate() {
    let c = opacity_plate();
    let reference = read_file("reference/chapter-12/opacity.ppm");
    let p6 = canvas_to_p6(&c);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_12_test() {
    let c = plate_12();
    let reference = read_file("reference/chapter-12/plate-12.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 600);
    assert_eq!(c.height, 300);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_clip_demo_hard_against_soft() {
    let c = clip_demo();
    let reference = read_file("reference/chapter-12/clip-demo.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 300);
    assert_eq!(c.height, 150);
    assert_pixel_within(&p6, 225, 45, (197, 155, 74), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
