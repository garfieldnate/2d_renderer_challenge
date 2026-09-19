// features/chapter14-fit.feature

use renderer::{approx_eq, approx_eq_eps, cubic, distance_to_curve, fit_offset, offset_error, point, quadratic};

#[test]
fn the_fit_of_a_straight_curve_is_exact() {
    let line = cubic(point(0.0, 0.0), point(1.0, 1.0), point(2.0, 2.0), point(3.0, 3.0));
    let f = fit_offset(&line, 1.0);

    assert!(approx_eq(f.points[0].x, -0.707107) && approx_eq(f.points[0].y, 0.707107));
    assert!(approx_eq(f.points[1].x, 0.292893) && approx_eq(f.points[1].y, 1.707107));
    assert!(approx_eq(f.points[3].x, 2.292893) && approx_eq(f.points[3].y, 3.707107));
    assert!(approx_eq(offset_error(&line, 1.0, &f), 0.0));
}

#[test]
fn the_fit_of_a_quarter_circle_lands_its_handles_on_the_offset_circle() {
    let arc = cubic(
        point(100.0, 0.0),
        point(100.0, 55.2285),
        point(55.2285, 100.0),
        point(0.0, 100.0),
    );
    let f = fit_offset(&arc, 10.0);

    assert!(approx_eq(f.points[0].x, 90.0) && approx_eq(f.points[0].y, 0.0));
    assert!(approx_eq_eps(f.points[1].x, 90.0, 0.001));
    assert!(approx_eq_eps(f.points[1].y, 49.7056, 0.001));
    assert!(approx_eq_eps(f.points[2].x, 49.7056, 0.001));
    assert!(approx_eq_eps(f.points[2].y, 90.0, 0.001));
    assert!(approx_eq(f.points[3].x, 0.0) && approx_eq(f.points[3].y, 90.0));
    assert!(approx_eq_eps(offset_error(&arc, 10.0, &f), 0.012092, 0.0001));
}

#[test]
fn a_u_turn_cannot_be_fitted_in_one_piece_and_the_miss_says_so() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let f = fit_offset(&c, 1.0);

    assert!(approx_eq(f.points[0].x, -1.0) && approx_eq(f.points[0].y, 0.0));
    assert!(approx_eq(f.points[1].x, -1.0) && approx_eq(f.points[1].y, 2.0));
    assert!(approx_eq(f.points[2].x, 5.0) && approx_eq(f.points[2].y, 2.0));
    assert!(approx_eq(f.points[3].x, 5.0) && approx_eq(f.points[3].y, 0.0));
    assert!(approx_eq(offset_error(&c, 1.0, &f), 2.5));
}

#[test]
fn the_distance_from_a_point_to_a_curve() {
    let line = cubic(point(0.0, 0.0), point(1.0, 1.0), point(2.0, 2.0), point(3.0, 3.0));
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    let arc = cubic(
        point(100.0, 0.0),
        point(100.0, 55.2285),
        point(55.2285, 100.0),
        point(0.0, 100.0),
    );

    assert!(approx_eq(distance_to_curve(&line, point(3.0, 0.0)), 2.121320));
    assert!(approx_eq(distance_to_curve(&line, point(5.0, 5.0)), 2.828427));
    assert!(approx_eq(distance_to_curve(&q, point(2.0, 5.0)), 3.0));
    assert!(approx_eq(distance_to_curve(&q, point(2.0, 0.0)), 1.732051));
    assert!(approx_eq_eps(distance_to_curve(&arc, point(0.0, 0.0)), 100.0, 0.03));
}
