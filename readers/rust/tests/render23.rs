// features/chapter23-render.feature

use renderer::{
    coverage_at, coverage_error, field_at, field_coverage, fill_path, ink, max_coverage_difference,
    point, polygon, polygon_field, simplify, star,
};

fn circle_field(cx: f64, cy: f64, r: f64, w: usize, h: usize) -> renderer::Field {
    renderer::field(w, h, move |p| renderer::sd_circle(p, point(cx, cy), r))
}

#[test]
fn a_field_is_sampled_at_pixel_centers() {
    let f = circle_field(8.0, 8.0, 3.0, 16, 16);
    assert!(renderer::approx_eq(field_at(&f, 8, 8), -2.292893));
    assert!(renderer::approx_eq(field_at(&f, 11, 8), 0.535534));
    assert_eq!(coverage_at(&field_coverage(&f), 8, 8), 1.0);
    assert_eq!(coverage_at(&field_coverage(&f), 11, 8), 0.0);
}

#[test]
fn along_an_edge_that_runs_with_the_pixels_the_field_is_exact() {
    let bx = polygon(&[
        point(10.3, 12.7),
        point(50.6, 12.7),
        point(50.6, 40.2),
        point(10.3, 40.2),
    ]);
    let cov = field_coverage(&polygon_field(&bx, "nonzero", 64, 64));
    let exact = fill_path(&bx, "nonzero", 64, 64);
    assert!(renderer::approx_eq(coverage_at(&cov, 10, 25), 0.7));
    assert!(renderer::approx_eq(coverage_at(&exact, 10, 25), 0.7));
    assert!(renderer::approx_eq(coverage_at(&cov, 10, 12), 0.3));
    assert!(renderer::approx_eq(coverage_at(&exact, 10, 12), 0.21));
    assert!(renderer::approx_eq(max_coverage_difference(&cov, &exact), 0.12));
}

#[test]
fn along_a_slanted_edge_its_a_little_off() {
    let d = polygon(&[
        point(74.37, 40.21),
        point(40.37, 74.21),
        point(6.37, 40.21),
        point(40.37, 6.21),
    ]);
    let cov = field_coverage(&polygon_field(&d, "nonzero", 80, 80));
    let exact = fill_path(&d, "nonzero", 80, 80);
    assert!(renderer::approx_eq(coverage_at(&cov, 71, 43), 0.203015));
    assert!(renderer::approx_eq(coverage_at(&exact, 71, 43), 0.1682));
}

#[test]
fn at_the_stars_points_its_a_long_way_off_and_inside_its_wrong_until_the_path_is_simplified() {
    let exact = fill_path(&star(), "nonzero", 160, 160);
    let raw = coverage_error(&field_coverage(&polygon_field(&star(), "nonzero", 160, 160)), &exact);
    let clean = coverage_error(
        &field_coverage(&polygon_field(&simplify(&star(), "nonzero"), "nonzero", 160, 160)),
        &exact,
    );
    assert!(renderer::approx_eq(
        max_coverage_difference(&field_coverage(&polygon_field(&star(), "nonzero", 160, 160)), &exact),
        0.491037
    ));
    assert!(renderer::approx_eq(ink(&raw), 44.800368));
    assert!(renderer::approx_eq(ink(&clean), 9.808571));
    assert_eq!(coverage_at(&raw, 80, 80), 0.0);
    assert!(renderer::approx_eq(coverage_at(&raw, 80, 58), 0.131190));
    assert_eq!(coverage_at(&clean, 80, 58), 0.0);
}
