// features/chapter07-fill.feature

use renderer::{
    approx_eq, approx_eq_eps, close, coverage_at, fill_path, fill_path_aliased, filled, ink,
    line_to, max_coverage_difference, move_to, path, point, polygon, polygon_area, rasterize,
    scaling, star, transform_path,
};

#[test]
fn a_square_whose_edges_sit_on_pixel_centers() {
    let p = polygon(&[point(1.5, 1.5), point(5.5, 1.5), point(5.5, 5.5), point(1.5, 5.5)]);
    let cov = fill_path(&p, "nonzero", 8, 8);
    assert!(approx_eq(coverage_at(&cov, 1, 1), 0.25));
    assert!(approx_eq(coverage_at(&cov, 3, 1), 0.5));
    assert!(approx_eq(coverage_at(&cov, 1, 3), 0.5));
    assert!(approx_eq(coverage_at(&cov, 3, 3), 1.0));
    assert!(approx_eq(coverage_at(&cov, 0, 0), 0.0));
    assert!(approx_eq(ink(&cov), 16.0));
    assert!(approx_eq(ink(&cov), polygon_area(&p)));
}

#[test]
fn the_ink_of_a_filled_polygon_is_its_exact_area() {
    let r = polygon(&[point(1.5, 2.0), point(4.75, 2.0), point(4.75, 5.0), point(1.5, 5.0)]);
    let t = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    let cr = fill_path(&r, "nonzero", 8, 8);
    let ct = fill_path(&t, "nonzero", 20, 20);
    assert!(approx_eq(ink(&cr), 9.75));
    assert!(approx_eq(ink(&cr), polygon_area(&r)));
    assert!(approx_eq(coverage_at(&cr, 1, 3), 0.5));
    assert!(approx_eq(coverage_at(&cr, 2, 3), 1.0));
    assert!(approx_eq(coverage_at(&cr, 4, 3), 0.75));
    assert!(approx_eq(ink(&ct), 50.0));
    assert!(approx_eq(ink(&ct), polygon_area(&t)));
}

#[test]
fn a_polygon_circles_ink_is_its_exact_area_where_the_supersampler_misses() {
    let p = renderer::circle_path(10.3, 9.7, 7.0, 12);
    let cov = fill_path(&p, "nonzero", 20, 20);
    assert!(approx_eq(ink(&cov), polygon_area(&p)));
    assert!(approx_eq_eps(ink(&cov), 147.0, 0.0001));
}

#[test]
fn a_scaled_shapes_ink_scales_with_its_area() {
    let t = transform_path(
        &polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]),
        scaling(2.0, 3.0),
    );
    let cov = fill_path(&t, "nonzero", 40, 40);
    assert!(approx_eq(ink(&cov), 300.0));
    assert!(approx_eq(ink(&cov), polygon_area(&t)));
}

#[test]
fn on_a_grid_aligned_shape_the_fill_and_the_supersampler_agree_exactly() {
    let r = polygon(&[point(1.5, 2.0), point(4.75, 2.0), point(4.75, 5.0), point(1.5, 5.0)]);
    let t = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    assert!(approx_eq(
        max_coverage_difference(
            &fill_path(&r, "nonzero", 8, 8),
            &rasterize(&filled(&r, "nonzero"), 8, 8)
        ),
        0.0
    ));
    assert!(approx_eq(
        max_coverage_difference(
            &fill_path(&t, "nonzero", 20, 20),
            &rasterize(&filled(&t, "nonzero"), 20, 20)
        ),
        0.0
    ));
}

#[test]
fn the_fill_replaces_chapter_6s_agreeing_on_solid_pixels_and_improving_the_edge() {
    let r = polygon(&[point(1.5, 2.0), point(4.75, 2.0), point(4.75, 5.0), point(1.5, 5.0)]);
    let exact = fill_path(&r, "nonzero", 8, 8);
    let aliased = fill_path_aliased(&r, "nonzero", 8, 8);
    assert!(approx_eq(coverage_at(&exact, 2, 3), 1.0));
    assert!(approx_eq(coverage_at(&aliased, 2, 3), 1.0));
    assert!(approx_eq(coverage_at(&exact, 6, 3), 0.0));
    assert!(approx_eq(coverage_at(&aliased, 6, 3), 0.0));
    assert!(approx_eq(coverage_at(&exact, 4, 3), 0.75));
    assert!(approx_eq(coverage_at(&aliased, 4, 3), 1.0));
}

#[test]
fn a_doubled_square_is_solid_under_nonzero_and_a_hole_under_evenodd() {
    let mut p = path();
    move_to(&mut p, point(1.5, 1.5));
    line_to(&mut p, point(5.5, 1.5));
    line_to(&mut p, point(5.5, 5.5));
    line_to(&mut p, point(1.5, 5.5));
    close(&mut p);
    move_to(&mut p, point(1.5, 1.5));
    line_to(&mut p, point(5.5, 1.5));
    line_to(&mut p, point(5.5, 5.5));
    line_to(&mut p, point(1.5, 5.5));
    close(&mut p);
    let nz = fill_path(&p, "nonzero", 8, 8);
    let eo = fill_path(&p, "evenodd", 8, 8);
    assert!(approx_eq(coverage_at(&nz, 3, 3), 1.0));
    assert!(approx_eq(coverage_at(&eo, 3, 3), 0.0));
}

#[test]
fn the_star_both_rules_filled_exactly() {
    let p = star();
    let nz = fill_path(&p, "nonzero", 160, 160);
    let eo = fill_path(&p, "evenodd", 160, 160);
    assert!(approx_eq(coverage_at(&nz, 80, 80), 1.0));
    assert!(approx_eq(coverage_at(&eo, 80, 80), 0.0));
    assert!(approx_eq_eps(ink(&nz), 5500.7654, 0.01));
    assert!(approx_eq_eps(ink(&eo), 3801.1615, 0.01));
    assert!(approx_eq_eps(coverage_at(&nz, 44, 80), 0.9456, 0.001));
    assert!(approx_eq_eps(coverage_at(&nz, 43, 80), 0.3556, 0.001));
}

#[test]
fn a_polygon_larger_than_the_buffer_fills_it_solid() {
    let p = polygon(&[point(-5.0, -5.0), point(30.0, -5.0), point(30.0, 30.0), point(-5.0, 30.0)]);
    let cov = fill_path(&p, "nonzero", 8, 8);
    assert!(approx_eq(ink(&cov), 64.0));
}

#[test]
fn an_empty_path_fills_nothing() {
    let p = path();
    let cov = fill_path(&p, "nonzero", 8, 8);
    assert!(approx_eq(ink(&cov), 0.0));
}
