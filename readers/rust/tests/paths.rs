// features/chapter05-paths.feature

use renderer::{
    bounds, circle_path, close, edges, line_to, move_to, path, point, polygon, subpaths,
    tuples_eq, winding_at,
};

fn assert_bounds(actual: (f64, f64, f64, f64), expected: (f64, f64, f64, f64)) {
    assert!(
        renderer::approx_eq(actual.0, expected.0)
            && renderer::approx_eq(actual.1, expected.1)
            && renderer::approx_eq(actual.2, expected.2)
            && renderer::approx_eq(actual.3, expected.3),
        "bounds: expected {expected:?}, got {actual:?}"
    );
}

#[test]
fn an_empty_path() {
    let p = path();
    assert_eq!(subpaths(&p).len(), 0);
    assert_eq!(edges(&p).len(), 0);
    assert_bounds(bounds(&p), (0.0, 0.0, 0.0, 0.0));
}

#[test]
fn a_triangle_closed() {
    let mut p = path();
    move_to(&mut p, point(1.0, 1.0));
    line_to(&mut p, point(9.0, 1.0));
    line_to(&mut p, point(5.0, 8.0));
    close(&mut p);

    assert_eq!(subpaths(&p).len(), 1);
    assert!(subpaths(&p)[0].closed);
    assert_eq!(subpaths(&p)[0].points.len(), 3);
    assert!(tuples_eq(subpaths(&p)[0].points[2], point(5.0, 8.0)));
    let es = edges(&p);
    assert_eq!(es.len(), 3);
    assert!(tuples_eq(es[2].0, point(5.0, 8.0)));
    assert!(tuples_eq(es[2].1, point(1.0, 1.0)));
    assert_bounds(bounds(&p), (1.0, 1.0, 9.0, 8.0));
}

#[test]
fn a_triangle_left_open_still_has_three_edges() {
    let mut p = path();
    move_to(&mut p, point(1.0, 1.0));
    line_to(&mut p, point(9.0, 1.0));
    line_to(&mut p, point(5.0, 8.0));

    assert!(!subpaths(&p)[0].closed);
    let es = edges(&p);
    assert_eq!(es.len(), 3);
    assert!(tuples_eq(es[2].0, point(5.0, 8.0)));
    assert!(tuples_eq(es[2].1, point(1.0, 1.0)));
}

#[test]
fn move_to_starts_a_second_subpath() {
    let mut p = path();
    move_to(&mut p, point(0.0, 0.0));
    line_to(&mut p, point(10.0, 0.0));
    line_to(&mut p, point(10.0, 10.0));
    line_to(&mut p, point(0.0, 10.0));
    close(&mut p);
    move_to(&mut p, point(3.0, 3.0));
    line_to(&mut p, point(3.0, 7.0));
    line_to(&mut p, point(7.0, 7.0));
    line_to(&mut p, point(7.0, 3.0));
    close(&mut p);

    assert_eq!(subpaths(&p).len(), 2);
    assert!(tuples_eq(subpaths(&p)[1].points[0], point(3.0, 3.0)));
    assert_eq!(edges(&p).len(), 8);
    assert_bounds(bounds(&p), (0.0, 0.0, 10.0, 10.0));
}

#[test]
fn line_to_after_a_close_starts_a_new_subpath_where_the_closed_one_began() {
    let mut p = path();
    move_to(&mut p, point(1.0, 1.0));
    line_to(&mut p, point(4.0, 1.0));
    line_to(&mut p, point(4.0, 4.0));
    close(&mut p);
    line_to(&mut p, point(9.0, 9.0));

    assert_eq!(subpaths(&p).len(), 2);
    assert!(!subpaths(&p)[1].closed);
    assert_eq!(subpaths(&p)[1].points.len(), 2);
    assert!(tuples_eq(subpaths(&p)[1].points[0], point(1.0, 1.0)));
    assert!(tuples_eq(subpaths(&p)[1].points[1], point(9.0, 9.0)));
}

#[test]
fn line_to_with_nothing_to_extend_behaves_as_move_to() {
    let mut p = path();
    line_to(&mut p, point(2.0, 3.0));

    assert_eq!(subpaths(&p).len(), 1);
    assert_eq!(subpaths(&p)[0].points.len(), 1);
    assert!(tuples_eq(subpaths(&p)[0].points[0], point(2.0, 3.0)));
}

#[test]
fn a_subpath_of_one_point_has_no_edges_and_closing_nothing_does_nothing() {
    let mut p = path();
    close(&mut p);
    move_to(&mut p, point(1.0, 1.0));
    move_to(&mut p, point(2.0, 2.0));

    assert_eq!(subpaths(&p).len(), 2);
    assert_eq!(edges(&p).len(), 0);
    assert_bounds(bounds(&p), (1.0, 1.0, 2.0, 2.0));
}

#[test]
fn a_subpath_of_two_points_has_two_edges_and_encloses_nothing() {
    let mut p = path();
    move_to(&mut p, point(1.0, 1.0));
    line_to(&mut p, point(9.0, 9.0));

    assert_eq!(edges(&p).len(), 2);
    assert_eq!(winding_at(&p, 3.0, 5.0), 0);
}

#[test]
fn polygon_is_a_closed_subpath_through_its_points() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);

    assert_eq!(subpaths(&p).len(), 1);
    assert!(subpaths(&p)[0].closed);
    assert_eq!(edges(&p).len(), 4);
}

#[test]
fn circle_path_is_a_polygon_standing_in_for_a_circle() {
    let p = circle_path(10.0, 10.0, 5.0, 8);

    assert_eq!(subpaths(&p)[0].points.len(), 8);
    assert!(tuples_eq(subpaths(&p)[0].points[0], point(15.0, 10.0)));
    assert!(tuples_eq(subpaths(&p)[0].points[1], point(13.5355, 13.5355)));
    assert!(tuples_eq(subpaths(&p)[0].points[2], point(10.0, 15.0)));
    assert_bounds(bounds(&p), (5.0, 5.0, 15.0, 15.0));
}
