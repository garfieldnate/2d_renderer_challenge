// features/chapter06-sweep.feature

use renderer::{
    approx_eq, bounds, circle_path, coverage_at, coverage_buffer, filled, fill_path_aliased, ink,
    max_coverage_difference, path, point, polygon, rasterize_centers, set_coverage, subpaths,
    transform_path, translation, tuples_eq,
};

#[test]
fn two_buffers_that_differ() {
    let mut a = coverage_buffer(3, 3);
    let mut b = coverage_buffer(3, 3);
    set_coverage(&mut a, 1, 1, 1.0);
    set_coverage(&mut b, 1, 1, 0.25);
    assert!(approx_eq(max_coverage_difference(&a, &b), 0.75));
    assert!(approx_eq(max_coverage_difference(&a, &a), 0.0));
}

#[test]
fn buffers_of_different_sizes_are_as_different_as_it_gets() {
    let a = coverage_buffer(3, 3);
    let b = coverage_buffer(3, 4);
    assert!(approx_eq(max_coverage_difference(&a, &b), 1.0));
}

#[test]
fn a_rectangle() {
    let p = polygon(&[point(2.0, 2.0), point(6.0, 2.0), point(6.0, 6.0), point(2.0, 6.0)]);
    let cov = fill_path_aliased(&p, "nonzero", 8, 8);
    assert!(approx_eq(coverage_at(&cov, 2, 2), 1.0));
    assert!(approx_eq(coverage_at(&cov, 5, 5), 1.0));
    assert!(approx_eq(coverage_at(&cov, 6, 5), 0.0));
    assert!(approx_eq(coverage_at(&cov, 5, 6), 0.0));
    assert!(approx_eq(coverage_at(&cov, 1, 2), 0.0));
    assert!(approx_eq(ink(&cov), 16.0));
    let s = filled(&p, "nonzero");
    assert!(approx_eq(max_coverage_difference(&cov, &rasterize_centers(&s, 8, 8)), 0.0));
}

#[test]
fn a_triangle() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    let cov = fill_path_aliased(&p, "nonzero", 20, 20);
    assert!(approx_eq(coverage_at(&cov, 0, 0), 1.0));
    assert!(approx_eq(coverage_at(&cov, 9, 0), 1.0));
    assert!(approx_eq(coverage_at(&cov, 10, 0), 0.0));
    assert!(approx_eq(coverage_at(&cov, 4, 8), 1.0));
    assert!(approx_eq(coverage_at(&cov, 3, 8), 0.0));
    assert!(approx_eq(coverage_at(&cov, 5, 9), 0.0));
    assert!(approx_eq(ink(&cov), 50.0));
    let s = filled(&p, "nonzero");
    assert!(approx_eq(max_coverage_difference(&cov, &rasterize_centers(&s, 20, 20)), 0.0));
}

#[test]
fn the_same_triangle_drawn_the_other_way_round() {
    let a = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    let b = polygon(&[point(0.0, 0.0), point(5.0, 10.0), point(10.0, 0.0)]);
    let ca = fill_path_aliased(&a, "nonzero", 20, 20);
    let cb = fill_path_aliased(&b, "nonzero", 20, 20);
    assert!(approx_eq(max_coverage_difference(&ca, &cb), 0.0));
}

#[test]
fn a_polygon_circle() {
    let p = circle_path(10.3, 9.7, 7.0, 12);
    let cov = fill_path_aliased(&p, "nonzero", 20, 20);
    assert!(approx_eq(ink(&cov), 145.0));
    let s = filled(&p, "nonzero");
    assert!(approx_eq(max_coverage_difference(&cov, &rasterize_centers(&s, 20, 20)), 0.0));
}

#[test]
fn the_star_both_rules_matches_chapter_5_pixel_for_pixel() {
    let p = renderer::star();
    let nz = fill_path_aliased(&p, "nonzero", 160, 160);
    let eo = fill_path_aliased(&p, "evenodd", 160, 160);
    assert!(approx_eq(ink(&nz), 5480.0));
    assert!(approx_eq(ink(&eo), 3780.0));
    assert!(approx_eq(coverage_at(&nz, 80, 80), 1.0));
    assert!(approx_eq(coverage_at(&eo, 80, 80), 0.0));
    let snz = filled(&p, "nonzero");
    let seo = filled(&p, "evenodd");
    assert!(approx_eq(max_coverage_difference(&nz, &rasterize_centers(&snz, 160, 160)), 0.0));
    assert!(approx_eq(max_coverage_difference(&eo, &rasterize_centers(&seo, 160, 160)), 0.0));
}

#[test]
fn an_edge_that_starts_on_a_sample_height_is_active_there_and_one_that_ends_there_is_not() {
    let p = polygon(&[point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5)]);
    let cov = fill_path_aliased(&p, "nonzero", 8, 8);
    assert!(approx_eq(coverage_at(&cov, 2, 1), 0.0));
    assert!(approx_eq(coverage_at(&cov, 2, 2), 1.0));
    assert!(approx_eq(coverage_at(&cov, 2, 4), 1.0));
    assert!(approx_eq(coverage_at(&cov, 2, 5), 0.0));
    assert!(approx_eq(coverage_at(&cov, 1, 3), 1.0));
    assert!(approx_eq(coverage_at(&cov, 4, 3), 0.0));
    assert!(approx_eq(ink(&cov), 9.0));
    let s = filled(&p, "nonzero");
    assert!(approx_eq(max_coverage_difference(&cov, &rasterize_centers(&s, 8, 8)), 0.0));
}

#[test]
fn a_polygon_larger_than_the_buffer_fills_it() {
    let p = polygon(&[point(-5.0, -5.0), point(30.0, -5.0), point(30.0, 30.0), point(-5.0, 30.0)]);
    let cov = fill_path_aliased(&p, "nonzero", 8, 8);
    assert!(approx_eq(ink(&cov), 64.0));
}

#[test]
fn an_empty_path_fills_nothing() {
    let p = path();
    let cov = fill_path_aliased(&p, "nonzero", 8, 8);
    assert!(approx_eq(ink(&cov), 0.0));
}

#[test]
fn transform_path_takes_every_point_through_the_matrix_and_keeps_the_flags() {
    let p = polygon(&[point(1.25, 2.0), point(4.75, 2.0), point(4.75, 5.0), point(1.25, 5.0)]);
    let q = transform_path(&p, translation(10.0, 20.0));

    assert_eq!(subpaths(&q).len(), 1);
    assert!(subpaths(&q)[0].closed);
    assert!(tuples_eq(subpaths(&q)[0].points[0], point(11.25, 22.0)));
    assert!(tuples_eq(subpaths(&q)[0].points[2], point(14.75, 25.0)));
    assert!(tuples_eq(subpaths(&p)[0].points[0], point(1.25, 2.0)));
}

fn assert_bounds(actual: (f64, f64, f64, f64), expected: (f64, f64, f64, f64)) {
    assert!(
        approx_eq(actual.0, expected.0)
            && approx_eq(actual.1, expected.1)
            && approx_eq(actual.2, expected.2)
            && approx_eq(actual.3, expected.3),
        "bounds: expected {expected:?}, got {actual:?}"
    );
}

#[test]
fn a_transformed_star_fills_where_the_transform_put_it() {
    let m = translation(10.0, 10.0)
        * renderer::scaling(0.11, 0.11)
        * translation(-80.5, -80.5);
    let p = transform_path(&renderer::star(), m);
    let nz = fill_path_aliased(&p, "nonzero", 20, 20);
    let eo = fill_path_aliased(&p, "evenodd", 20, 20);

    assert_bounds(bounds(&p), (2.6769, 2.3, 17.3231, 16.2294));
    assert!(approx_eq(ink(&nz), 60.0));
    assert!(approx_eq(ink(&eo), 40.0));
    let s = filled(&p, "nonzero");
    assert!(approx_eq(max_coverage_difference(&nz, &rasterize_centers(&s, 20, 20)), 0.0));
}

#[test]
fn a_bow_tie_has_four_crossings_on_a_row_and_they_must_be_sorted() {
    use renderer::spans;
    let p = polygon(&[point(1.0, 1.0), point(15.0, 6.0), point(15.0, 1.0), point(1.0, 6.0)]);
    let cov = fill_path_aliased(&p, "nonzero", 16, 8);
    for rule in ["nonzero", "evenodd"] {
        let s = spans(&p, rule, 2);
        let e = [(1.0, 5.2), (10.8, 15.0)];
        assert_eq!(s.len(), 2, "{rule}: {s:?}");
        for (a, b) in s.iter().zip(e.iter()) {
            assert!(approx_eq(a.0, b.0) && approx_eq(a.1, b.1), "{rule}: {s:?}");
        }
    }
    assert!(approx_eq(coverage_at(&cov, 4, 2), 1.0));
    assert!(approx_eq(coverage_at(&cov, 5, 2), 0.0));
    assert!(approx_eq(coverage_at(&cov, 10, 2), 0.0));
    assert!(approx_eq(coverage_at(&cov, 11, 2), 1.0));
    assert!(approx_eq(ink(&cov), 34.0));
    assert_eq!(max_coverage_difference(&cov, &rasterize_centers(&filled(&p, "nonzero"), 16, 8)), 0.0);
}
