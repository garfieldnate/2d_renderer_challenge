// features/chapter08-flatten.feature

use renderer::{
    approx_eq, approx_eq_eps, close, cubic, flatness, flatten, flatten_into_path, flatten_length, path, point,
    quadratic, subpaths, tuples_eq,
};

#[test]
fn flatness_is_the_reach_of_the_control_points_from_the_chord() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    assert!(approx_eq(flatness(&q), 4.0));
    assert!(approx_eq(
        flatness(&cubic(point(0.0, 0.0), point(1.0, 1.0), point(2.0, 2.0), point(3.0, 3.0))),
        0.0
    ));
}

#[test]
fn a_straight_curve_flattens_to_its_two_endpoints() {
    let c = cubic(point(0.0, 0.0), point(1.0, 1.0), point(2.0, 2.0), point(3.0, 3.0));
    let pts = flatten(&c, 0.01);
    assert_eq!(pts.len(), 2);
    assert!(tuples_eq(pts[0], point(0.0, 0.0)));
    assert!(tuples_eq(pts[1], point(3.0, 3.0)));
}

#[test]
fn flattening_always_keeps_both_ends() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let pts = flatten(&c, 2.0);
    assert!(tuples_eq(pts[0], point(0.0, 0.0)));
    assert!(tuples_eq(pts[pts.len() - 1], point(4.0, 0.0)));
}

#[test]
fn a_tighter_tolerance_uses_more_points() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    assert_eq!(flatten(&c, 2.0).len(), 3);
    assert_eq!(flatten(&c, 0.1).len(), 9);
}

#[test]
fn the_flattened_length_converges_to_the_arc_length() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    assert!(approx_eq_eps(flatten_length(&c, 2.0), 7.2111, 0.001));
    assert!(approx_eq_eps(flatten_length(&c, 0.1), 7.9509, 0.001));
    assert!(approx_eq_eps(flatten_length(&c, 0.001), 7.9992, 0.001));
}

#[test]
fn a_curve_scaled_up_needs_more_points_so_flatten_after_the_transform() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    assert_eq!(flatten(&c, 0.1).len(), 9);
    assert_eq!(flatten(&renderer::transform_curve(&c, renderer::scaling(10.0, 10.0)), 0.1).len(), 33);
}

#[test]
fn appending_curves_to_a_path_joins_them_without_repeating_a_point() {
    let mut p = path();
    flatten_into_path(
        &mut p,
        &quadratic(point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0)),
        0.1,
    );
    flatten_into_path(
        &mut p,
        &quadratic(point(10.0, 10.0), point(10.0, 20.0), point(0.0, 20.0)),
        0.1,
    );
    assert_eq!(subpaths(&p).len(), 1);
    assert_eq!(subpaths(&p)[0].points.len(), 25);
    assert!(tuples_eq(subpaths(&p)[0].points[12], point(10.0, 10.0)));
    assert!(!tuples_eq(subpaths(&p)[0].points[13], point(10.0, 10.0)));
}

#[test]
fn a_curve_that_starts_away_from_the_pen_is_joined_with_a_line_and_after_a_close_it_starts_a_new_subpath() {
    let mut p = path();
    flatten_into_path(
        &mut p,
        &quadratic(point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0)),
        0.1,
    );
    flatten_into_path(
        &mut p,
        &quadratic(point(5.0, 25.0), point(0.0, 30.0), point(-5.0, 25.0)),
        0.1,
    );
    close(&mut p);
    flatten_into_path(
        &mut p,
        &quadratic(point(50.0, 0.0), point(60.0, 0.0), point(60.0, 10.0)),
        0.1,
    );
    assert_eq!(subpaths(&p).len(), 2);
    assert_eq!(subpaths(&p)[0].points.len(), 22);
    assert!(tuples_eq(subpaths(&p)[0].points[13], point(5.0, 25.0)));
    assert!(tuples_eq(subpaths(&p)[1].points[0], point(50.0, 0.0)));
    assert_eq!(subpaths(&p)[1].points.len(), 13);
}
