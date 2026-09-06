// features/chapter02-centers.feature

use renderer::{
    approx_eq, center_inside, circle, coverage, coverage_at, coverage_buffer, half_plane, ink,
    rasterize_centers, rectangle, set_coverage,
};

#[test]
fn a_new_coverage_buffer_is_empty() {
    let cov = coverage_buffer(4, 3);
    assert_eq!(cov.width, 4);
    assert_eq!(cov.height, 3);
    assert!(approx_eq(coverage_at(&cov, 2, 1), 0.0));
    assert!(approx_eq(ink(&cov), 0.0));
}

#[test]
fn setting_coverage() {
    let mut cov = coverage_buffer(4, 3);
    set_coverage(&mut cov, 2, 1, 0.75);
    assert!(approx_eq(coverage_at(&cov, 2, 1), 0.75));
    assert!(approx_eq(coverage_at(&cov, 1, 2), 0.0));
    assert!(approx_eq(ink(&cov), 0.75));
}

#[test]
fn setting_coverage_outside_the_buffer_is_ignored_and_reading_it_gives_0() {
    let mut cov = coverage_buffer(4, 3);
    set_coverage(&mut cov, -1, 1, 1.0);
    set_coverage(&mut cov, 4, 1, 1.0);
    set_coverage(&mut cov, 1, 3, 1.0);
    assert!(approx_eq(ink(&cov), 0.0));
    assert!(approx_eq(coverage_at(&cov, -1, 1), 0.0));
    assert!(approx_eq(coverage_at(&cov, 4, 1), 0.0));
    assert!(approx_eq(coverage_at(&cov, 1, 3), 0.0));
}

#[test]
fn the_center_of_pixel_x_y_is_x_plus_half_y_plus_half() {
    let s = half_plane(2.5, 0.0, 1.0, 0.0);
    assert!(center_inside(&s, 2, 4));
    assert!(!center_inside(&s, 1, 4));

    let t = half_plane(2.6, 0.0, 1.0, 0.0);
    assert!(!center_inside(&t, 2, 4));
}

#[test]
fn the_center_question_is_not_at_least_half() {
    let s = half_plane(2.55, 0.0, 1.0, 0.0);
    assert!(!center_inside(&s, 2, 4));
    assert!(approx_eq(coverage(&s, 2, 4), 0.5));
}

#[test]
fn a_buffer_need_not_be_square() {
    let s = rectangle(0.0, 0.0, 2.0, 1.0);
    let cov = rasterize_centers(&s, 4, 2);
    assert_eq!(cov.width, 4);
    assert_eq!(cov.height, 2);
    assert!(approx_eq(coverage_at(&cov, 1, 0), 1.0));
    assert!(approx_eq(coverage_at(&cov, 0, 1), 0.0));
    assert!(approx_eq(ink(&cov), 2.0));
}

#[test]
fn a_rectangle_by_asking_each_center() {
    let s = rectangle(1.25, 2.0, 4.75, 5.0);
    let cov = rasterize_centers(&s, 8, 8);
    assert!(approx_eq(coverage_at(&cov, 1, 4), 1.0));
    assert!(approx_eq(coverage_at(&cov, 4, 1), 0.0));
    assert!(approx_eq(coverage_at(&cov, 4, 4), 1.0));
    assert!(approx_eq(coverage_at(&cov, 0, 3), 0.0));
    assert!(approx_eq(coverage_at(&cov, 5, 3), 0.0));
    assert!(approx_eq(coverage_at(&cov, 2, 1), 0.0));
    assert!(approx_eq(coverage_at(&cov, 2, 5), 0.0));
    assert!(approx_eq(ink(&cov), 12.0));
}

#[test]
fn a_disc_by_asking_each_center() {
    let s = circle(8.0, 8.0, 5.0);
    let cov = rasterize_centers(&s, 16, 16);
    assert_eq!(cov.width, 16);
    assert_eq!(cov.height, 16);
    assert!(approx_eq(coverage_at(&cov, 8, 8), 1.0));
    assert!(approx_eq(coverage_at(&cov, 3, 8), 1.0));
    assert!(approx_eq(coverage_at(&cov, 12, 8), 1.0));
    assert!(approx_eq(coverage_at(&cov, 2, 8), 0.0));
    assert!(approx_eq(coverage_at(&cov, 13, 8), 0.0));
    assert!(approx_eq(coverage_at(&cov, 4, 4), 1.0));
    assert!(approx_eq(coverage_at(&cov, 3, 4), 0.0));
    assert!(approx_eq(ink(&cov), 80.0));
}
