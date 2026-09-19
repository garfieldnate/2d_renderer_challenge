// features/chapter15-closed.feature

use renderer::{dash, line_to, move_to, path, path_length, point, polygon, subpaths, tuples_eq};

#[test]
fn each_subpath_starts_the_pattern_over() {
    let mut two = path();
    move_to(&mut two, point(0.0, 0.0));
    line_to(&mut two, point(7.0, 0.0));
    move_to(&mut two, point(0.0, 10.0));
    line_to(&mut two, point(20.0, 10.0));
    let d = dash(&two, &[6.0, 4.0], 0.0);

    assert_eq!(subpaths(&d).len(), 3);
    assert!(tuples_eq(subpaths(&d)[0].points[1], point(6.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[0], point(0.0, 10.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[1], point(6.0, 10.0)));
    assert!(tuples_eq(subpaths(&d)[2].points[0], point(10.0, 10.0)));
    assert!(tuples_eq(subpaths(&d)[2].points[1], point(16.0, 10.0)));
}

#[test]
fn a_closed_subpath_is_walked_around_its_closing_segment() {
    let square = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let d = dash(&square, &[6.0, 4.0], 0.0);

    assert_eq!(subpaths(&d).len(), 4);
    assert!(tuples_eq(subpaths(&d)[3].points[0], point(0.0, 10.0)));
    assert!(tuples_eq(subpaths(&d)[3].points[1], point(0.0, 4.0)));
    assert!(!subpaths(&d)[3].closed);
}

#[test]
fn a_last_dash_that_runs_into_the_first_is_joined_to_it() {
    let square = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let d = dash(&square, &[4.0, 2.0], 0.0);

    assert_eq!(subpaths(&d).len(), 6);
    assert!(tuples_eq(subpaths(&d)[0].points[0], point(6.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[0].points[1], point(10.0, 0.0)));
    assert_eq!(subpaths(&d)[5].points.len(), 3);
    assert!(tuples_eq(subpaths(&d)[5].points[0], point(0.0, 4.0)));
    assert!(tuples_eq(subpaths(&d)[5].points[1], point(0.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[5].points[2], point(4.0, 0.0)));
    assert!(renderer::approx_eq(path_length(&d), 28.0));
}

#[test]
fn a_dash_that_covers_the_whole_loop_is_the_loop_closed() {
    let square = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let d = dash(&square, &[100.0, 1.0], 0.0);

    assert_eq!(subpaths(&d).len(), 1);
    assert!(subpaths(&d)[0].closed);
    assert_eq!(subpaths(&d)[0].points.len(), 4);
    assert!(renderer::approx_eq(path_length(&d), 40.0));
}

#[test]
fn a_pattern_that_ends_on_a_gap_at_the_start_leaves_the_corner_alone() {
    let square = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let d = dash(&square, &[10.0, 10.0], 0.0);

    assert_eq!(subpaths(&d).len(), 2);
    assert!(tuples_eq(subpaths(&d)[0].points[0], point(0.0, 0.0)));
    assert!(tuples_eq(subpaths(&d)[1].points[1], point(0.0, 10.0)));
}
