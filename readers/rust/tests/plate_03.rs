// features/chapter03-plate.feature

use renderer::{
    canvas_to_p6, fan_bresenham, fan_coverage, fan_wu, max_channel_difference, plate_03,
    ppm_pixel, ray_ends, read_file,
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
fn the_ray_endpoints() {
    assert_eq!(
        ray_ends(),
        vec![
            (152, 80),
            (142, 116),
            (116, 142),
            (80, 152),
            (44, 142),
            (18, 116),
            (8, 80),
            (18, 44),
            (44, 18),
            (80, 8),
            (116, 18),
            (142, 44),
        ]
    );
}

#[test]
fn bresenhams_fan() {
    let c = fan_bresenham();
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 160);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 80, 80, (246, 246, 241), 1);
    assert_pixel_within(&p6, 120, 80, (246, 246, 241), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert_pixel_within(&p6, 100, 91, (39, 39, 44), 1);
    assert_pixel_within(&p6, 100, 92, (246, 246, 241), 1);
    assert_pixel_within(&p6, 103, 120, (246, 246, 241), 1);
    assert_pixel_within(&p6, 102, 120, (39, 39, 44), 1);
    assert_pixel_within(&p6, 104, 120, (39, 39, 44), 1);
    let reference = read_file("reference/chapter-03/fan-bresenham.ppm");
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn wus_fan() {
    let c = fan_wu();
    let p6 = canvas_to_p6(&c);
    assert_pixel_within(&p6, 80, 80, (246, 246, 241), 1);
    assert_pixel_within(&p6, 120, 80, (246, 246, 241), 1);
    assert_pixel_within(&p6, 100, 91, (163, 163, 161), 1);
    assert_pixel_within(&p6, 100, 92, (199, 199, 196), 1);
    assert_pixel_within(&p6, 103, 120, (220, 220, 216), 1);
    assert_pixel_within(&p6, 104, 120, (130, 130, 129), 1);
    let reference = read_file("reference/chapter-03/fan-wu.ppm");
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_fan_as_twelve_thin_rectangles() {
    let c = fan_coverage();
    let reference = read_file("reference/chapter-03/fan-coverage.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 320);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 160, 160, (246, 246, 241), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert_pixel_within(&p6, 240, 160, (246, 246, 241), 1);
    assert_pixel_within(&p6, 240, 158, (39, 39, 44), 1);
    assert_pixel_within(&p6, 200, 183, (177, 177, 174), 1);
    assert_pixel_within(&p6, 200, 185, (209, 209, 205), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_3() {
    let c = plate_03();
    let reference = read_file("reference/chapter-03/plate-03.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 640);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 160, 160, (246, 246, 241), 1);
    assert_pixel_within(&p6, 480, 160, (246, 246, 241), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert_pixel_within(&p6, 200, 183, (39, 39, 44), 1);
    assert_pixel_within(&p6, 200, 185, (246, 246, 241), 1);
    assert_pixel_within(&p6, 520, 183, (163, 163, 161), 1);
    assert_pixel_within(&p6, 520, 185, (199, 199, 196), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
