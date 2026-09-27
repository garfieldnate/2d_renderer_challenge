// features/chapter08-arc.feature

use renderer::{approx_eq, arc, arc_point, point, tuples_eq};

#[test]
fn the_two_flags_choose_among_four_arcs_between_the_same_endpoints() {
    let a = arc(0.0, 0.0, 5.0, 5.0, 0.0, false, false, 6.0, 0.0).unwrap();
    assert!(tuples_eq(arc_point(&a, 0.5), point(3.0, 1.0)));

    let a01 = arc(0.0, 0.0, 5.0, 5.0, 0.0, false, true, 6.0, 0.0).unwrap();
    assert!(tuples_eq(arc_point(&a01, 0.5), point(3.0, -1.0)));

    let a10 = arc(0.0, 0.0, 5.0, 5.0, 0.0, true, false, 6.0, 0.0).unwrap();
    assert!(tuples_eq(arc_point(&a10, 0.5), point(3.0, 9.0)));

    let a11 = arc(0.0, 0.0, 5.0, 5.0, 0.0, true, true, 6.0, 0.0).unwrap();
    assert!(tuples_eq(arc_point(&a11, 0.5), point(3.0, -9.0)));
}

#[test]
fn every_one_of_the_four_still_meets_both_endpoints() {
    let a = arc(0.0, 0.0, 5.0, 5.0, 0.0, true, false, 6.0, 0.0).unwrap();
    assert!(tuples_eq(arc_point(&a, 0.0), point(0.0, 0.0)));
    assert!(tuples_eq(arc_point(&a, 1.0), point(6.0, 0.0)));
}

#[test]
fn radii_too_small_to_reach_are_grown_until_they_do() {
    let a = arc(0.0, 0.0, 0.5, 0.5, 0.0, false, true, 2.0, 0.0).unwrap();
    assert!(a.corrected);
    assert!(approx_eq(a.rx, 1.0));
    assert!(approx_eq(a.ry, 1.0));
    assert!(tuples_eq(arc_point(&a, 0.0), point(0.0, 0.0)));
    assert!(tuples_eq(arc_point(&a, 1.0), point(2.0, 0.0)));
    assert!(tuples_eq(arc_point(&a, 0.5), point(1.0, -1.0)));
}

#[test]
fn a_rotated_ellipse_still_lands_on_its_endpoints() {
    let a = arc(1.0, 1.0, 4.0, 2.0, std::f64::consts::PI / 6.0, false, true, 7.0, 4.0).unwrap();
    assert!(!a.corrected);
    assert!(tuples_eq(arc_point(&a, 0.0), point(1.0, 1.0)));
    assert!(tuples_eq(arc_point(&a, 1.0), point(7.0, 4.0)));
    assert!(tuples_eq(arc_point(&a, 0.5), point(4.268029, 1.595108)));
}

#[test]
fn a_degenerate_arc_is_no_arc() {
    assert!(arc(0.0, 0.0, 1.0, 1.0, 0.0, false, true, 0.0, 0.0).is_none());
    assert!(arc(0.0, 0.0, 0.0, 1.0, 0.0, false, true, 2.0, 0.0).is_none());
}

#[test]
fn a_half_circle_is_the_boundary_the_acos_clamp_guards() {
    let a = arc(0.0, 0.0, 2.5, 2.5, 0.0, false, false, 3.0, 4.0).unwrap();
    assert!(tuples_eq(arc_point(&a, 0.0), point(0.0, 0.0)));
    assert!(tuples_eq(arc_point(&a, 1.0), point(3.0, 4.0)));
    assert!(tuples_eq(arc_point(&a, 0.5), point(-0.5, 3.5)), "{:?}", arc_point(&a, 0.5));
    let b = arc(0.0, 0.0, 2.5, 2.5, 0.0, false, true, 3.0, 4.0).unwrap();
    assert!(tuples_eq(arc_point(&b, 0.5), point(3.5, 0.5)), "{:?}", arc_point(&b, 0.5));
}
