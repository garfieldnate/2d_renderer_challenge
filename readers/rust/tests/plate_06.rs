// features/chapter06-plate.feature

use renderer::{
    bounds, canvas_to_p6, edges, max_channel_difference, plate_06, point, ppm_pixel, read_file,
    spiral, subpaths, tuples_eq, unit_star,
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

fn assert_bounds(actual: (f64, f64, f64, f64), expected: (f64, f64, f64, f64)) {
    assert!(
        renderer::approx_eq(actual.0, expected.0)
            && renderer::approx_eq(actual.1, expected.1)
            && renderer::approx_eq(actual.2, expected.2)
            && renderer::approx_eq(actual.3, expected.3),
        "bounds: expected {expected:?}, got {actual:?}"
    );
}

#[test]
fn the_unit_star() {
    let p = unit_star();
    assert_eq!(edges(&p).len(), 5);
    assert!(tuples_eq(subpaths(&p)[0].points[0], point(0.0, -1.0)));
    assert!(tuples_eq(subpaths(&p)[0].points[1], point(0.5878, 0.809)));
    assert!(tuples_eq(subpaths(&p)[0].points[2], point(-0.9511, -0.309)));
    assert_bounds(bounds(&p), (-0.9511, -1.0, 0.9511, 0.809));
}

#[test]
fn the_spiral() {
    let c = spiral();
    let reference = read_file("reference/chapter-06/spiral.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 180, 160, (243, 196, 89), 1);
    assert_pixel_within(&p6, 183, 171, (124, 196, 237), 1);
    assert_pixel_within(&p6, 179, 183, (237, 137, 149), 1);
    assert_pixel_within(&p6, 104, 139, (237, 137, 149), 1);
    assert_pixel_within(&p6, 230, 111, (124, 196, 237), 1);
    assert_pixel_within(&p6, 32, 137, (124, 196, 237), 1);
    assert_pixel_within(&p6, 34, 104, (237, 137, 149), 1);
    assert_pixel_within(&p6, 160, 160, (39, 39, 44), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
    assert_pixel_within(&p6, 300, 20, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_6() {
    let c = plate_06();
    let reference = read_file("reference/chapter-06/plate-06.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 640);
    assert_eq!(c.height, 640);
    assert_pixel_within(&p6, 360, 320, (243, 196, 89), 1);
    assert_pixel_within(&p6, 68, 208, (237, 137, 149), 1);
    assert_pixel_within(&p6, 320, 320, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
