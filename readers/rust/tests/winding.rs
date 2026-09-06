// features/chapter05-winding.feature

use renderer::{circle_path, close, crossings, edges, line_to, move_to, path, point, polygon, star, winding_at};

#[test]
fn crossings_from_inside_and_outside_a_square() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    assert_eq!(crossings(&p, 5.0, 5.0), 1);
    assert_eq!(crossings(&p, 15.0, 5.0), 0);
    assert_eq!(crossings(&p, -1.0, 5.0), 2);
}

#[test]
fn a_clockwise_square_winds_once() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    assert_eq!(winding_at(&p, 5.0, 5.0), 1);
    assert_eq!(winding_at(&p, 15.0, 5.0), 0);
    assert_eq!(winding_at(&p, -1.0, 5.0), 0);
    assert_eq!(winding_at(&p, 5.0, -1.0), 0);
    assert_eq!(winding_at(&p, 5.0, 11.0), 0);
}

#[test]
fn the_same_square_the_other_way_round_winds_minus_once() {
    let p = polygon(&[point(0.0, 0.0), point(0.0, 10.0), point(10.0, 10.0), point(10.0, 0.0)]);
    assert_eq!(winding_at(&p, 5.0, 5.0), -1);
    assert_eq!(crossings(&p, 5.0, 5.0), 1);
}

#[test]
fn a_ray_through_a_vertex_counts_it_once() {
    let p = polygon(&[point(5.0, 0.0), point(10.0, 5.0), point(5.0, 10.0), point(0.0, 5.0)]);
    assert_eq!(crossings(&p, 2.0, 5.0), 1);
    assert_eq!(winding_at(&p, 2.0, 5.0), 1);
    assert_eq!(crossings(&p, -1.0, 5.0), 2);
    assert_eq!(winding_at(&p, -1.0, 5.0), 0);
    assert_eq!(winding_at(&p, 12.0, 5.0), 0);
    assert_eq!(winding_at(&p, 5.0, 5.0), 1);
}

#[test]
fn the_boundary_belongs_to_the_top_and_the_left() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    assert_eq!(winding_at(&p, 5.0, 0.0), 1);
    assert_eq!(winding_at(&p, 0.0, 5.0), 1);
    assert_eq!(winding_at(&p, 0.0, 0.0), 1);
    assert_eq!(winding_at(&p, 5.0, 10.0), 0);
    assert_eq!(winding_at(&p, 10.0, 5.0), 0);
    assert_eq!(winding_at(&p, 10.0, 10.0), 0);
}

#[test]
fn two_rectangles_that_share_an_edge_cover_it_once() {
    let mut p = path();
    move_to(&mut p, point(0.0, 0.0));
    line_to(&mut p, point(5.0, 0.0));
    line_to(&mut p, point(5.0, 10.0));
    line_to(&mut p, point(0.0, 10.0));
    close(&mut p);
    move_to(&mut p, point(5.0, 0.0));
    line_to(&mut p, point(10.0, 0.0));
    line_to(&mut p, point(10.0, 10.0));
    line_to(&mut p, point(5.0, 10.0));
    close(&mut p);

    assert_eq!(winding_at(&p, 2.0, 5.0), 1);
    assert_eq!(winding_at(&p, 5.0, 5.0), 1);
    assert_eq!(winding_at(&p, 8.0, 5.0), 1);
}

#[test]
fn a_diamond_wound_twice_has_winding_number_2() {
    let mut p = path();
    move_to(&mut p, point(5.0, 0.0));
    line_to(&mut p, point(10.0, 5.0));
    line_to(&mut p, point(5.0, 10.0));
    line_to(&mut p, point(0.0, 5.0));
    line_to(&mut p, point(5.0, 0.0));
    line_to(&mut p, point(10.0, 5.0));
    line_to(&mut p, point(5.0, 10.0));
    line_to(&mut p, point(0.0, 5.0));
    close(&mut p);

    assert_eq!(edges(&p).len(), 8);
    assert_eq!(winding_at(&p, 5.0, 5.0), 2);
    assert_eq!(crossings(&p, 5.0, 5.0), 2);
    assert_eq!(winding_at(&p, 12.0, 5.0), 0);
}

#[test]
fn the_polygon_circle() {
    let p = circle_path(10.0, 10.0, 5.0, 8);
    assert_eq!(winding_at(&p, 10.0, 10.0), 1);
    assert_eq!(winding_at(&p, 14.9, 10.0), 1);
    assert_eq!(winding_at(&p, 15.0, 10.0), 0);
    assert_eq!(winding_at(&p, 10.0, 5.1), 1);
    assert_eq!(winding_at(&p, 10.0, 4.9), 0);
}

#[test]
fn the_pentagrams_center_winds_twice() {
    let p = star();
    assert_eq!(winding_at(&p, 80.5, 80.5), 2);
    assert_eq!(crossings(&p, 80.5, 80.5), 2);
    assert_eq!(winding_at(&p, 80.5, 20.0), 1);
    assert_eq!(winding_at(&p, 30.0, 60.0), 1);
    assert_eq!(crossings(&p, 30.0, 60.0), 3);
    assert_eq!(winding_at(&p, 80.5, 120.0), 0);
    assert_eq!(crossings(&p, 80.5, 120.0), 2);
    assert_eq!(winding_at(&p, 10.0, 10.0), 0);
}
