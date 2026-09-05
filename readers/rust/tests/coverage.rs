// features/chapter02-coverage.feature

use renderer::{
    approx_eq, approx_eq_eps, canvas_to_p6, circle, coverage, coverage_at, disc_coverage,
    half_plane, ink, max_channel_difference, ppm_pixel, rasterize, read_file, rectangle,
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
fn the_sixty_four_sample_points() {
    let s = half_plane(2.5, 0.0, 1.0, 0.0);
    assert!(approx_eq(coverage(s, 2, 4), 0.5));
    assert!(approx_eq(coverage(s, 1, 4), 0.0));
    assert!(approx_eq(coverage(s, 3, 4), 1.0));
}

#[test]
fn a_rectangle_is_covered_exactly_when_its_edges_land_on_sample_boundaries() {
    let s = rectangle(1.25, 2.0, 4.75, 5.0);
    let cov = rasterize(s, 8, 8);
    assert!(approx_eq(coverage_at(&cov, 0, 2), 0.0));
    assert!(approx_eq(coverage_at(&cov, 1, 2), 0.75));
    assert!(approx_eq(coverage_at(&cov, 2, 2), 1.0));
    assert!(approx_eq(coverage_at(&cov, 3, 2), 1.0));
    assert!(approx_eq(coverage_at(&cov, 4, 2), 0.75));
    assert!(approx_eq(coverage_at(&cov, 5, 2), 0.0));
    assert!(approx_eq(coverage_at(&cov, 2, 1), 0.0));
    assert!(approx_eq(coverage_at(&cov, 2, 5), 0.0));
    assert!(approx_eq(ink(&cov), 10.5));
}

#[test]
fn neither_need_the_buffer_be_square_here() {
    let s = rectangle(0.0, 0.0, 2.0, 1.0);
    let cov = rasterize(s, 4, 2);
    assert_eq!(cov.width, 4);
    assert_eq!(cov.height, 2);
    assert!(approx_eq(coverage_at(&cov, 1, 0), 1.0));
    assert!(approx_eq(coverage_at(&cov, 2, 0), 0.0));
    assert!(approx_eq(coverage_at(&cov, 0, 1), 0.0));
    assert!(approx_eq(ink(&cov), 2.0));
}

#[test]
fn a_half_plane_through_a_pixel_center_covers_half_of_it() {
    let s = half_plane(2.5, 4.5, 0.6, 0.8);
    assert!(approx_eq(coverage(s, 2, 4), 0.5));
}

#[test]
fn except_when_the_grid_conspires() {
    let s = half_plane(2.5, 4.5, 1.0, 1.0);
    assert!(approx_eq(coverage(s, 2, 4), 0.5625));
}

#[test]
fn a_disc_is_only_ever_approximately_covered() {
    let s = circle(8.0, 8.0, 5.0);
    let cov = rasterize(s, 16, 16);
    assert!(approx_eq(coverage_at(&cov, 8, 8), 1.0));
    assert!(approx_eq(coverage_at(&cov, 3, 8), 0.96875));
    assert!(approx_eq(coverage_at(&cov, 12, 8), 0.96875));
    assert!(approx_eq(coverage_at(&cov, 4, 4), 0.5625));
    assert!(approx_eq(coverage_at(&cov, 3, 4), 0.0));
    assert!(approx_eq(ink(&cov), 78.5));
    assert!(approx_eq_eps(ink(&cov), 78.5398, 0.1));
}

#[test]
fn the_disc_by_coverage() {
    let c = disc_coverage();
    let reference = read_file("reference/chapter-02/disc-coverage.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 160, 160, (243, 196, 89), 1);
    assert_pixel_within(&p6, 124, 36, (157, 127, 64), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
