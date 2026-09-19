// features/chapter15-dash.feature

use renderer::{dash, line_to, move_to, path, path_length, point, subpaths, tuples_eq};

#[test]
fn dashes_on_a_straight_line_land_at_exact_multiples() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(100.0, 0.0));
    let d = dash(&seg, &[10.0, 5.0], 0.0);

    assert_eq!(subpaths(&d).len(), 7);
    assert!(tuples_eq(subpaths(&d)[0].points[0], point(0.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[0].points[1], point(10.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[0], point(15.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[1], point(25.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[6].points[0], point(90.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[6].points[1], point(100.0, 0.0)));
    assert!(!subpaths(&d)[6].closed);
}

#[test]
fn the_dashes_and_the_gaps_add_up_to_the_path() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(100.0, 0.0));
    let d = dash(&seg, &[10.0, 5.0], 0.0);

    assert!(renderer::approx_eq(path_length(&d), 70.0));
    assert!(renderer::approx_eq(path_length(&seg) - path_length(&d), 30.0));
}

#[test]
fn the_phase_starts_the_walk_partway_into_the_pattern() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(100.0, 0.0));
    let d = dash(&seg, &[10.0, 5.0], 3.0);

    assert_eq!(subpaths(&d).len(), 7);
    assert!(tuples_eq(subpaths(&d)[0].points[0], point(0.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[0].points[1], point(7.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[0], point(12.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[6].points[1], point(97.0, 0.0)));
}

#[test]
fn a_phase_into_a_gap_starts_with_a_gap() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(100.0, 0.0));
    let d = dash(&seg, &[10.0, 5.0], 12.0);

    assert_eq!(subpaths(&d).len(), 7);
    assert!(tuples_eq(subpaths(&d)[0].points[0], point(3.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[0].points[1], point(13.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[6].points[0], point(93.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[6].points[1], point(100.0, 0.0)));
}

#[test]
fn a_phase_of_the_patterns_sum_is_no_phase_and_a_negative_phase_wraps() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(100.0, 0.0));

    let d15 = dash(&seg, &[10.0, 5.0], 15.0);
    assert!(tuples_eq(subpaths(&d15)[0].points[1], point(10.0, 0.0)));
    assert!(tuples_eq(subpaths(&d15)[1].points[0], point(15.0, 0.0)));

    let dneg = dash(&seg, &[10.0, 5.0], -3.0);
    assert!(tuples_eq(subpaths(&dneg)[0].points[0], point(3.0, 0.0)));
    assert!(tuples_eq(subpaths(&dneg)[0].points[1], point(13.0, 0.0)));
}

#[test]
fn a_dash_that_reaches_a_corner_turns_it() {
    let mut bend = path();
    move_to(&mut bend, point(0.0, 0.0));
    line_to(&mut bend, point(10.0, 0.0));
    line_to(&mut bend, point(10.0, 10.0));
    let d = dash(&bend, &[12.0, 4.0], 0.0);

    assert_eq!(subpaths(&d).len(), 2);
    assert_eq!(subpaths(&d)[0].points.len(), 3);
    assert!(tuples_eq(subpaths(&d)[0].points[1], point(10.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[0].points[2], point(10.0, 2.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[0], point(10.0, 6.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[1], point(10.0, 10.0)));
}

#[test]
fn a_gap_that_reaches_a_corner_turns_it_too() {
    let mut bend = path();
    move_to(&mut bend, point(0.0, 0.0));
    line_to(&mut bend, point(10.0, 0.0));
    line_to(&mut bend, point(10.0, 10.0));
    let d = dash(&bend, &[8.0, 4.0], 0.0);

    assert_eq!(subpaths(&d).len(), 2);
    assert!(tuples_eq(subpaths(&d)[0].points[1], point(8.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[0], point(10.0, 2.0)));
}

#[test]
fn duplicate_points_do_not_stall_the_walk() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(10.0, 0.0));
    let d = dash(&seg, &[4.0, 2.0], 0.0);

    assert_eq!(subpaths(&d).len(), 2);
    assert!(tuples_eq(subpaths(&d)[0].points[1], point(4.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[0], point(6.0, 0.0)));
}
