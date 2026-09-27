// features/chapter20-building.feature

use renderer::{
    approx_eq, arc_cubics, build_path, commands_bounds, identity, path_commands, point, scaling, subpaths,
    tuples_eq, Tuple,
};

fn assert_points(actual: &[Tuple], expected: &[Tuple]) {
    assert_eq!(actual.len(), expected.len(), "expected {expected:?}, got {actual:?}");
    for (a, e) in actual.iter().zip(expected) {
        assert!(tuples_eq(*a, *e), "expected {expected:?}, got {actual:?}");
    }
}

fn assert_bounds(actual: (f64, f64, f64, f64), expected: (f64, f64, f64, f64)) {
    assert!(
        approx_eq(actual.0, expected.0)
            && approx_eq(actual.1, expected.1)
            && approx_eq(actual.2, expected.2)
            && approx_eq(actual.3, expected.3),
        "expected {expected:?}, got {actual:?}"
    );
}

#[test]
fn a_quarter_circle_is_one_cubic_with_handles_0_5523_of_a_radius_long() {
    let cs = arc_cubics(10.0, 0.0, 10.0, 10.0, 0.0, false, true, 0.0, 10.0);
    assert_eq!(cs.len(), 1);
    assert!(tuples_eq(cs[0].points[0], point(10.0, 0.0)));
    assert!(tuples_eq(cs[0].points[1], point(10.0, 5.5228)));
    assert!(tuples_eq(cs[0].points[2], point(5.5228, 10.0)));
    assert!(tuples_eq(cs[0].points[3], point(0.0, 10.0)));
    assert_eq!(arc_cubics(8.3, 1.1, 3.3, 3.3, 0.0, false, true, 5.0, 4.4).len(), 1);
}

#[test]
fn a_half_turn_is_two_quarters_and_the_sweep_flag_says_which_way_round() {
    let cs = arc_cubics(0.0, 0.0, 5.0, 5.0, 0.0, false, true, 10.0, 0.0);
    assert_eq!(cs.len(), 2);
    assert!(tuples_eq(cs[0].points[3], point(5.0, -5.0)));
    assert!(tuples_eq(cs[1].points[1], point(7.7614, -5.0)));
    assert!(tuples_eq(cs[1].points[3], point(10.0, 0.0)));
    assert!(tuples_eq(arc_cubics(0.0, 0.0, 5.0, 5.0, 0.0, false, false, 10.0, 0.0)[0].points[3], point(5.0, 5.0)));
}

#[test]
fn radii_too_small_to_reach_are_grown_as_chapter_8_does() {
    let cs = arc_cubics(0.0, 0.0, 1.0, 1.0, 0.0, false, true, 10.0, 0.0);
    assert_eq!(cs.len(), 2);
    assert!(tuples_eq(cs[0].points[3], point(5.0, -5.0)));
}

#[test]
fn the_large_arc_flag_takes_the_long_way_round() {
    assert_eq!(arc_cubics(0.0, 0.0, 10.0, 10.0, 0.0, true, false, 0.01, 0.0).len(), 4);
    assert_eq!(arc_cubics(0.0, 0.0, 10.0, 10.0, 0.0, false, false, 0.01, 0.0).len(), 1);
}

#[test]
fn no_arc_between_coincident_points_and_a_line_when_a_radius_is_zero() {
    assert_eq!(arc_cubics(3.0, 3.0, 5.0, 5.0, 0.0, false, true, 3.0, 3.0).len(), 0);
    assert_eq!(arc_cubics(0.0, 0.0, 0.0, 5.0, 0.0, false, true, 9.0, 3.0).len(), 1);
    assert!(tuples_eq(arc_cubics(0.0, 0.0, 0.0, 5.0, 0.0, false, true, 9.0, 3.0)[0].points[1], point(3.0, 1.0)));
    assert!(tuples_eq(arc_cubics(0.0, 0.0, 0.0, 5.0, 0.0, false, true, 9.0, 3.0)[0].points[2], point(6.0, 2.0)));
}

#[test]
fn points_go_through_the_matrix_and_z_then_l_starts_at_the_subpaths_start() {
    let p = build_path(&path_commands("M0 0 L10 0 L10 10 Z L0 10"), scaling(2.0, 2.0), 0.1);
    assert_eq!(subpaths(&p).len(), 2);
    assert_points(&subpaths(&p)[0].points, &[point(0.0, 0.0), point(20.0, 0.0), point(20.0, 20.0)]);
    assert!(subpaths(&p)[0].closed);
    assert_points(&subpaths(&p)[1].points, &[point(0.0, 0.0), point(0.0, 20.0)]);
    assert!(!subpaths(&p)[1].closed);
}

#[test]
fn a_moveto_on_its_own_is_dropped_but_a_closed_point_stays() {
    let p = build_path(&path_commands("M0 0 L10 0 M20 20 M5 5 L6 6 M7 7"), identity(), 0.1);
    assert_eq!(subpaths(&p).len(), 2);
    assert_points(&subpaths(&p)[1].points, &[point(5.0, 5.0), point(6.0, 6.0)]);
    assert_eq!(subpaths(&build_path(&path_commands("M1 1 Z"), identity(), 0.1)).len(), 1);
}

#[test]
fn curves_are_flattened_after_the_transform_so_a_bigger_curve_gets_more_points() {
    assert_eq!(subpaths(&build_path(&path_commands("M0 0 Q10 0 10 10"), identity(), 0.1))[0].points.len(), 13);
    assert_eq!(
        subpaths(&build_path(&path_commands("M0 0 Q10 0 10 10"), scaling(10.0, 10.0), 0.1))[0].points.len(),
        33
    );
}

#[test]
fn an_arc_in_a_path_ends_exactly_at_its_end_point() {
    let p = build_path(&path_commands("M0 0 A5 5 0 0 1 10 0"), identity(), 0.1);
    assert_eq!(subpaths(&p)[0].points.len(), 17);
    assert!(tuples_eq(subpaths(&p)[0].points[16], point(10.0, 0.0)));
    assert!(tuples_eq(subpaths(&p)[0].points[8], point(5.0, -5.0)));
}

#[test]
fn the_bounds_of_the_geometry_not_of_the_control_points() {
    assert_bounds(commands_bounds(&path_commands("M0 0 C0 -10 10 -10 10 0")), (0.0, -7.5, 10.0, 0.0));
    assert_bounds(commands_bounds(&path_commands("M0 0 Q10 20 20 0")), (0.0, 0.0, 20.0, 10.0));
    assert_bounds(commands_bounds(&path_commands("M0 0 A5 5 0 0 1 10 0")), (0.0, -5.0, 10.0, 0.0));
    assert_bounds(commands_bounds(&path_commands("M0 0 A5 5 0 0 0 10 0")), (0.0, 0.0, 10.0, 5.0));
    assert_bounds(commands_bounds(&path_commands("")), (0.0, 0.0, 0.0, 0.0));
}
