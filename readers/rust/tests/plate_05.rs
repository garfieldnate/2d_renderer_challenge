// features/chapter05-plate.feature

use renderer::{
    bounds, canvas_to_p6, edges, max_channel_difference, plate_05, point, ppm_pixel, read_file,
    star, star_centers, star_coverage, subpaths, tuples_eq,
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
fn the_pentagram() {
    let p = star();
    assert_eq!(subpaths(&p).len(), 1);
    assert_eq!(edges(&p).len(), 5);
    assert!(tuples_eq(subpaths(&p)[0].points[0], point(80.5, 10.5)));
    assert!(tuples_eq(subpaths(&p)[0].points[1], point(121.645, 137.1312)));
    assert!(tuples_eq(subpaths(&p)[0].points[2], point(13.926, 58.8688)));
    assert!(tuples_eq(subpaths(&p)[0].points[3], point(147.074, 58.8688)));
    assert!(tuples_eq(subpaths(&p)[0].points[4], point(39.355, 137.1312)));
    assert_bounds(bounds(&p), (13.926, 10.5, 147.074, 137.1312));
}

#[test]
fn the_star_by_the_center_question() {
    let c = star_centers();
    let reference = read_file("reference/chapter-05/star-centers.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 80, 80, (243, 196, 89), 1);
    assert_pixel_within(&p6, 240, 80, (39, 39, 44), 1);
    assert_pixel_within(&p6, 80, 20, (243, 196, 89), 1);
    assert_pixel_within(&p6, 240, 20, (243, 196, 89), 1);
    assert_pixel_within(&p6, 30, 60, (243, 196, 89), 1);
    assert_pixel_within(&p6, 190, 60, (243, 196, 89), 1);
    assert_pixel_within(&p6, 80, 120, (39, 39, 44), 1);
    assert_pixel_within(&p6, 80, 10, (39, 39, 44), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_star_by_coverage() {
    let c = star_coverage();
    let reference = read_file("reference/chapter-05/star-coverage.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 80, 80, (243, 196, 89), 1);
    assert_pixel_within(&p6, 240, 80, (39, 39, 44), 1);
    assert_pixel_within(&p6, 80, 20, (243, 196, 89), 1);
    assert_pixel_within(&p6, 240, 20, (243, 196, 89), 1);
    assert_pixel_within(&p6, 80, 120, (39, 39, 44), 1);
    assert_pixel_within(&p6, 80, 10, (77, 65, 48), 1);
    assert_pixel_within(&p6, 240, 10, (77, 65, 48), 1);
    assert_pixel_within(&p6, 80, 11, (199, 160, 76), 1);
    assert_pixel_within(&p6, 14, 58, (101, 83, 52), 1);
    assert_pixel_within(&p6, 174, 58, (101, 83, 52), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_5() {
    let c = plate_05();
    let reference = read_file("reference/chapter-05/plate-05.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 640);
    assert_eq!(c.height, 640);
    assert_pixel_within(&p6, 160, 160, (243, 196, 89), 1);
    assert_pixel_within(&p6, 480, 160, (39, 39, 44), 1);
    assert_pixel_within(&p6, 160, 480, (243, 196, 89), 1);
    assert_pixel_within(&p6, 480, 480, (39, 39, 44), 1);
    assert_pixel_within(&p6, 160, 40, (243, 196, 89), 1);
    assert_pixel_within(&p6, 480, 360, (243, 196, 89), 1);
    assert_pixel_within(&p6, 160, 20, (39, 39, 44), 1);
    assert_pixel_within(&p6, 160, 341, (77, 65, 48), 1);
    assert_pixel_within(&p6, 480, 341, (77, 65, 48), 1);
    assert_pixel_within(&p6, 348, 437, (101, 83, 52), 1);
    assert_pixel_within(&p6, 20, 20, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
