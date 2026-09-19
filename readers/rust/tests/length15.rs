// features/chapter15-length.feature

use renderer::{
    approx_eq, approx_eq_eps, arc_length, arc_length_table, cubic, line_to, lopsided, move_to,
    path, path_length, point, point_at, point_at_length, polygon, split_at_length, t_at_length,
    tuples_eq,
};

#[test]
fn the_length_of_a_path_sums_its_segments_and_a_closed_subpath_includes_the_closing_one() {
    let mut open = path();
    move_to(&mut open, point(0.0, 0.0));
    line_to(&mut open, point(3.0, 4.0));
    line_to(&mut open, point(3.0, 0.0));

    assert!(approx_eq(path_length(&open), 9.0));
    assert!(approx_eq(
        path_length(&polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)])),
        40.0
    ));
}

#[test]
fn the_arc_length_table_is_the_running_length_of_chords() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let table = arc_length_table(&c, 4);

    assert_eq!(table.len(), 5);
    assert!(approx_eq(table[0], 0.0));
    assert!(approx_eq(table[1], 2.335193));
    assert!(approx_eq(table[2], 3.901438));
    assert!(approx_eq(table[4], 7.802876));
}

#[test]
fn more_chords_creep_up_on_the_true_length() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let line = cubic(point(0.0, 0.0), point(1.0, 1.0), point(2.0, 2.0), point(3.0, 3.0));

    assert!(approx_eq(arc_length(&c, 4), 7.802876));
    assert!(approx_eq(arc_length(&c, 16), 7.987725));
    assert!(approx_eq(arc_length(&c, 256), 7.999952));
    assert!(approx_eq(arc_length(&line, 256), 4.242641));
}

#[test]
fn the_parameter_at_a_length_by_interpolation() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let table = arc_length_table(&c, 256);
    let total = arc_length(&c, 256);

    assert!(approx_eq(t_at_length(&table, 0.0), 0.0));
    assert!(approx_eq(t_at_length(&table, total / 2.0), 0.5));
    assert!(approx_eq(t_at_length(&table, total / 4.0), 0.201966));
    assert!(approx_eq(t_at_length(&table, total + 1.0), 1.0));
    assert!(approx_eq(t_at_length(&table, -1.0), 0.0));
}

#[test]
fn a_point_and_a_split_at_a_given_length() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let total = arc_length(&c, 256);
    let (left, right) = split_at_length(&c, 2.0, 256);

    assert!(tuples_eq(point_at_length(&c, total / 2.0, 256), point(2.0, 3.0)));
    let p = point_at_length(&c, total / 4.0, 256);
    assert!(approx_eq_eps(p.x, 0.423579, 0.0001));
    assert!(approx_eq_eps(p.y, 1.93411, 0.0001));
    assert!(approx_eq_eps(arc_length(&left, 256), 2.0, 0.001));
    assert!(approx_eq_eps(arc_length(&right, 256), 6.0, 0.001));
    assert!(tuples_eq(point_at(&left, 1.0), point_at(&right, 0.0)));
}

#[test]
fn the_parameter_is_not_the_length() {
    let c = lopsided();
    let total = arc_length(&c, 256);

    assert!(approx_eq_eps(total, 198.0971, 0.001));
    assert!(tuples_eq(point_at(&c, 0.5), point(71.875, 58.125)));
    let p = point_at_length(&c, total / 2.0, 256);
    assert!(approx_eq_eps(p.x, 98.7142, 0.001));
    assert!(approx_eq_eps(p.y, 52.9628, 0.001));
    assert!(approx_eq_eps(t_at_length(&arc_length_table(&c, 256), total / 2.0), 0.635558, 0.0001));
}
