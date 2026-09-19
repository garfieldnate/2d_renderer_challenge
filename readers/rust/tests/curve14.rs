// features/chapter14-curve.feature

use renderer::{
    approx_eq, approx_eq_eps, cubic, distance_to_curve, offset_curve, offset_distance_error, point,
    point_at, quadratic, sub_curve, tuples_eq,
};

#[test]
fn a_piece_of_a_curve_between_two_parameters() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let piece = sub_curve(&c, 0.25, 0.75);

    assert!(tuples_eq(point_at(&piece, 0.0), point(0.625, 2.25)));
    assert!(tuples_eq(point_at(&piece, 0.5), point(2.0, 3.0)));
    assert!(tuples_eq(point_at(&piece, 1.0), point(3.375, 2.25)));
}

#[test]
fn a_gentle_offset_needs_one_piece_at_a_loose_tolerance_and_four_at_a_tight_one() {
    let arc = cubic(
        point(100.0, 0.0),
        point(100.0, 55.2285),
        point(55.2285, 100.0),
        point(0.0, 100.0),
    );

    assert_eq!(offset_curve(&arc, 10.0, 0.1).len(), 1);
    assert_eq!(offset_curve(&arc, 10.0, 0.01).len(), 4);
    assert_eq!(offset_curve(&arc, -10.0, 0.01).len(), 4);
}

#[test]
fn the_pieces_chain_end_to_end_from_the_first_offset_point_to_the_last() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let pieces = offset_curve(&c, 1.0, 0.01);

    assert_eq!(pieces.len(), 4);
    assert!(tuples_eq(pieces[0].points[0], point(-1.0, 0.0)));
    assert!(tuples_eq(pieces[1].points[0], pieces[0].points[3]));
    assert!(tuples_eq(pieces[1].points[3], point(2.0, 4.0)));
    assert!(tuples_eq(pieces[2].points[0], point(2.0, 4.0)));
    assert!(tuples_eq(pieces[3].points[3], point(5.0, 0.0)));
}

#[test]
fn on_the_outside_every_point_of_the_offset_is_a_distance_d_from_the_curve() {
    let arc = cubic(
        point(100.0, 0.0),
        point(100.0, 55.2285),
        point(55.2285, 100.0),
        point(0.0, 100.0),
    );
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));

    assert!(offset_distance_error(&arc, 10.0, 0.01) <= 0.01);
    assert!(offset_distance_error(&arc, -10.0, 0.01) <= 0.01);
    assert!(offset_distance_error(&q, 2.0, 0.01) <= 0.01);
    assert!(offset_distance_error(&q, 2.0, 0.1) <= 0.1);
}

#[test]
fn on_the_inside_of_a_tight_bend_the_offset_folds_and_comes_closer_than_d() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    let pieces = offset_curve(&q, -2.0, 0.01);

    assert_eq!(pieces.len(), 6);
    assert!(approx_eq_eps(pieces[1].points[3].x, 2.4502, 0.0001));
    assert!(approx_eq_eps(pieces[1].points[3].y, 0.118898, 0.0001));
    assert!(tuples_eq(pieces[2].points[3], point(2.0, 0.0)));
    assert!(approx_eq_eps(pieces[3].points[3].x, 1.5498, 0.0001));
    assert!(approx_eq_eps(pieces[3].points[3].y, 0.118898, 0.0001));
    assert!(approx_eq(distance_to_curve(&q, point(2.0, 0.0)), 1.732051));
    assert!(offset_distance_error(&q, -2.0, 0.01) >= 0.7);
}
