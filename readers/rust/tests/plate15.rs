// features/chapter15-plate.feature

use renderer::{
    canvas_to_p6, dash, dash_count, dash_strip, even_marks, golden_spiral, max_channel_difference,
    path_length, plate_15, ppm_pixel, read_file, spiral_dashes, subpaths, tuples_eq,
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
fn marks_by_parameter_and_by_length() {
    let c = even_marks();
    let reference = read_file("reference/chapter-15/even-marks.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 400);
    assert_eq!(c.height, 120);
    assert_pixel_within(&p6, 89, 37, (243, 196, 89), 1);
    assert_pixel_within(&p6, 295, 37, (124, 196, 237), 1);
    assert_pixel_within(&p6, 100, 100, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_strip() {
    let c = dash_strip();
    let reference = read_file("reference/chapter-15/dash-strip.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 160, 20, (206, 206, 212), 1);
    assert_pixel_within(&p6, 20, 140, (237, 137, 149), 1);
    assert_pixel_within(&p6, 24, 140, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_spiral_is_one_subpath_and_it_dashes_into_seventeen() {
    let sp = golden_spiral();

    assert_eq!(subpaths(&sp).len(), 1);
    assert!(renderer::approx_eq_eps(path_length(&sp), 427.493, 0.01));
    assert_eq!(dash_count(&sp, &[16.0, 10.0], 0.0), 17);
    let d = dash(&sp, &[16.0, 10.0], 0.0);
    assert!(tuples_eq(subpaths(&d)[0].points[0], renderer::point(142.0, 130.0)));
    assert!(renderer::approx_eq_eps(path_length(&d), 267.493, 0.01));
}

#[test]
fn the_spiral_dashed() {
    let c = spiral_dashes();
    let reference = read_file("reference/chapter-15/spiral.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 340);
    assert_eq!(c.height, 340);
    assert_pixel_within(&p6, 142, 130, (243, 196, 89), 1);
    assert_pixel_within(&p6, 157, 138, (124, 196, 237), 1);
    assert_pixel_within(&p6, 20, 20, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_15_test() {
    let c = plate_15();
    let reference = read_file("reference/chapter-15/plate-15.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 680);
    assert_eq!(c.height, 680);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
