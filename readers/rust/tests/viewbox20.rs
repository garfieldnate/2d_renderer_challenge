// features/chapter20-viewbox.feature

use renderer::{
    aspect_demo, canvas_to_p6, identity, matrices_eq, max_channel_difference, point, ppm_pixel, read_file,
    scaling, tuples_eq, view_box_matrix,
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
fn meet_fits_the_whole_box_and_centres_it() {
    let m = view_box_matrix(Some("0 0 60 80"), Some("xMidYMid meet"), 120, 90);
    assert!(tuples_eq(m * point(0.0, 0.0), point(26.25, 0.0)));
    assert!(tuples_eq(m * point(60.0, 80.0), point(93.75, 90.0)));
    assert!(matrices_eq(&view_box_matrix(Some("0 0 60 80"), None, 120, 90), &m));
    assert!(matrices_eq(&view_box_matrix(Some("0 0 60 80"), Some("xMidYMid"), 120, 90), &m));
}

#[test]
fn the_alignment_words_slide_the_box_along_the_spare_axis() {
    let vb = |a: &str| view_box_matrix(Some("0 0 60 80"), Some(a), 120, 90);
    assert!(tuples_eq(vb("xMinYMid meet") * point(0.0, 0.0), point(0.0, 0.0)));
    assert!(tuples_eq(vb("xMaxYMid meet") * point(0.0, 0.0), point(52.5, 0.0)));
    assert!(tuples_eq(vb("xMaxYMid meet") * point(60.0, 80.0), point(120.0, 90.0)));
}

#[test]
fn slice_fills_the_viewport_and_spills() {
    let vb = |a: &str| view_box_matrix(Some("0 0 60 80"), Some(a), 120, 90);
    assert!(tuples_eq(vb("xMidYMid slice") * point(0.0, 0.0), point(0.0, -35.0)));
    assert!(tuples_eq(vb("xMidYMid slice") * point(60.0, 80.0), point(120.0, 125.0)));
    assert!(tuples_eq(vb("xMidYMin slice") * point(0.0, 0.0), point(0.0, 0.0)));
    assert!(tuples_eq(vb("xMaxYMax slice") * point(0.0, 0.0), point(0.0, -70.0)));
}

#[test]
fn none_stretches_each_axis_on_its_own() {
    let m = view_box_matrix(Some("0 0 60 80"), Some("none"), 120, 90);
    assert!(matrices_eq(&m, &scaling(2.0, 1.125)));
    assert!(tuples_eq(
        view_box_matrix(Some("10 20 60 80"), Some("none"), 120, 90) * point(10.0, 20.0),
        point(0.0, 0.0)
    ));
}

#[test]
fn the_boxs_origin_moves_to_the_viewports() {
    assert!(tuples_eq(
        view_box_matrix(Some("10 20 60 80"), Some("xMidYMid meet"), 120, 90) * point(10.0, 20.0),
        point(26.25, 0.0)
    ));
    assert!(tuples_eq(view_box_matrix(Some("-5,-5,10,10"), None, 100, 100) * point(0.0, 0.0), point(50.0, 50.0)));
}

#[test]
fn no_usable_viewbox_is_the_identity() {
    assert!(matrices_eq(&view_box_matrix(None, None, 50, 50), &identity()));
    assert!(matrices_eq(&view_box_matrix(Some("0 0 0 5"), None, 50, 50), &identity()));
    assert!(matrices_eq(&view_box_matrix(Some("0 0 50"), None, 50, 50), &identity()));
}

#[test]
fn one_drawing_five_ways_to_fit_it() {
    let c = aspect_demo();
    let reference = read_file("reference/chapter-20/aspect_demo.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 660);
    assert_eq!(c.height, 110);
    assert_pixel_within(&p6, 70, 39, (232, 85, 58), 1);
    assert_pixel_within(&p6, 240, 50, (255, 255, 255), 1);
    assert_pixel_within(&p6, 280, 50, (255, 255, 255), 1);
    assert_pixel_within(&p6, 335, 50, (232, 85, 58), 1);
    assert_pixel_within(&p6, 150, 95, (59, 91, 122), 1);
    assert_pixel_within(&p6, 590, 27, (232, 85, 58), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
