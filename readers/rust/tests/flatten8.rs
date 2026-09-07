// features/chapter08-flatten.feature

use renderer::{approx_eq, approx_eq_eps, cubic, flatness, flatten, flatten_length, point, quadratic, tuples_eq};

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
