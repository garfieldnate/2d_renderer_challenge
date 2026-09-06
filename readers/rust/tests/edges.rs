// features/chapter06-edges.feature

use renderer::{approx_eq, close, edge_table, line_to, move_to, path, point, polygon, x_at};

#[test]
fn a_rectangle_has_two_edges_in_its_table() {
    let p = polygon(&[point(2.0, 2.0), point(6.0, 2.0), point(6.0, 6.0), point(2.0, 6.0)]);
    let t = edge_table(&p);
    assert_eq!(t.len(), 2);
    assert!(approx_eq(t[0].y_top, 2.0));
    assert!(approx_eq(t[0].y_bottom, 6.0));
    assert!(approx_eq(t[0].x_top, 2.0));
    assert!(approx_eq(t[0].slope, 0.0));
    assert_eq!(t[0].direction, -1);
    assert!(approx_eq(t[1].x_top, 6.0));
    assert_eq!(t[1].direction, 1);
}

#[test]
fn a_triangles_edges_carry_their_slopes() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    let t = edge_table(&p);
    assert_eq!(t.len(), 2);
    assert!(approx_eq(t[0].x_top, 0.0));
    assert!(approx_eq(t[0].slope, 0.5));
    assert_eq!(t[0].direction, -1);
    assert!(approx_eq(t[1].x_top, 10.0));
    assert!(approx_eq(t[1].slope, -0.5));
    assert_eq!(t[1].direction, 1);
}

#[test]
fn the_table_is_sorted_by_top_then_by_x_at_the_top() {
    let mut p = path();
    move_to(&mut p, point(2.0, 2.0));
    line_to(&mut p, point(4.0, 1.0));
    line_to(&mut p, point(6.0, 3.0));
    line_to(&mut p, point(8.0, 1.0));
    line_to(&mut p, point(9.0, 6.0));
    line_to(&mut p, point(1.0, 6.0));
    close(&mut p);

    let t = edge_table(&p);
    assert_eq!(t.len(), 5);
    assert!(approx_eq(t[0].y_top, 1.0));
    assert!(approx_eq(t[0].x_top, 4.0));
    assert!(approx_eq(t[1].y_top, 1.0));
    assert!(approx_eq(t[1].x_top, 4.0));
    assert!(approx_eq(t[2].y_top, 1.0));
    assert!(approx_eq(t[2].x_top, 8.0));
    assert!(approx_eq(t[3].y_top, 1.0));
    assert!(approx_eq(t[3].x_top, 8.0));
    assert!(approx_eq(t[4].y_top, 2.0));
    assert!(approx_eq(t[4].x_top, 2.0));
}

#[test]
fn a_horizontal_edge_is_dropped_not_clamped() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 5.0), point(0.0, 5.0)]);
    let t = edge_table(&p);
    assert_eq!(t.len(), 2);
    assert!(approx_eq(t[0].x_top, 0.0));
    assert!(approx_eq(t[1].x_top, 10.0));
}

#[test]
fn an_edge_knows_where_it_crosses_a_height() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    let t = edge_table(&p);
    assert!(approx_eq(x_at(&t[0], 4.0), 2.0));
    assert!(approx_eq(x_at(&t[1], 4.0), 8.0));
    assert!(approx_eq(x_at(&t[0], 0.5), 0.25));
}

#[test]
fn the_edge_table_is_the_same_whichever_way_the_path_was_drawn() {
    let a = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    let b = polygon(&[point(0.0, 0.0), point(5.0, 10.0), point(10.0, 0.0)]);
    let ta = edge_table(&a);
    let tb = edge_table(&b);
    assert!(approx_eq(ta[0].x_top, tb[0].x_top));
    assert!(approx_eq(ta[0].slope, tb[0].slope));
    assert_eq!(ta[0].direction, -1);
    assert_eq!(tb[0].direction, 1);
}
