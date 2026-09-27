// features/chapter23-curves.feature

use renderer::{
    approx_eq, approx_eq_eps, brute_distance, cubic, distance_to_cubic, distance_to_curve,
    distance_to_quadratic, max_curve_error, nearest_t_cubic, point, quadratic, solve_cubic,
    tuples_eq, weyl_points,
};

fn vecs_close(a: &[f64], b: &[f64]) -> bool {
    a.len() == b.len() && a.iter().zip(b.iter()).all(|(&x, &y)| approx_eq(x, y))
}

#[test]
fn cubic_roots_and_the_cases_that_arent_cubic() {
    assert!(vecs_close(&solve_cubic(1.0, -6.0, 11.0, -6.0), &[1.0, 2.0, 3.0]));
    assert!(vecs_close(&solve_cubic(1.0, 0.0, 0.0, -8.0), &[2.0]));
    assert!(vecs_close(&solve_cubic(2.0, 0.0, -2.0, 0.0), &[-1.0, 0.0, 1.0]));
    assert!(vecs_close(&solve_cubic(0.0, 1.0, -3.0, 2.0), &[1.0, 2.0]));
    assert!(vecs_close(&solve_cubic(0.0, 0.0, 2.0, -1.0), &[0.5]));
    assert!(solve_cubic(0.0, 0.0, 0.0, 1.0).is_empty());
}

#[test]
fn the_nearest_point_of_a_quadratic() {
    let flat = quadratic(point(0.0, 0.0), point(5.0, 0.0), point(10.0, 0.0));
    let arch = quadratic(point(10.0, 80.0), point(50.0, -20.0), point(90.0, 80.0));
    assert_eq!(distance_to_quadratic(point(5.0, 3.0), &flat), 3.0);
    assert_eq!(distance_to_quadratic(point(13.0, 4.0), &flat), 5.0);
    assert_eq!(distance_to_quadratic(point(50.0, 20.0), &arch), 10.0);
    assert!(approx_eq_eps(distance_to_quadratic(point(50.0, 60.0), &arch), 26.532998, 0.000001));
}

#[test]
fn the_nearest_point_of_a_cubic_can_be_an_end_that_newton_walks_away_from() {
    let c = cubic(point(30.0, 50.0), point(10.0, 40.0), point(10.0, 70.0), point(10.0, 100.0));
    assert_eq!(distance_to_cubic(point(70.0, 80.0), &c), 50.0);
    assert_eq!(nearest_t_cubic(point(70.0, 80.0), &c), 0.0);
}

#[test]
fn the_points_are_the_same_everywhere() {
    let pts = weyl_points(2, 0.0, 0.0, 100.0, 100.0);
    assert!(tuples_eq(pts[0], point(75.48776662466927, 56.98402909980532)));
    assert!(tuples_eq(pts[1], point(50.97553324933854, 13.968058199610638)));
}

#[test]
fn both_fields_match_a_brute_force_search_over_10000_points() {
    let pts = weyl_points(10000, 0.0, 0.0, 100.0, 100.0);
    let q = quadratic(point(10.0, 80.0), point(50.0, -20.0), point(90.0, 80.0));
    let c = cubic(point(10.0, 80.0), point(30.0, -10.0), point(70.0, 120.0), point(90.0, 20.0));
    assert!(max_curve_error(&q, &pts) <= 0.000001);
    assert!(max_curve_error(&c, &pts) <= 0.000001);
}

#[test]
fn a_cubic_that_loops_back_past_the_point() {
    let c = cubic(
        point(83.1679, 49.0113),
        point(3.7744, 16.9556),
        point(9.872, 71.7692),
        point(90.0182, 19.9317),
    );
    let p = point(52.2111, 45.0896);
    assert!(approx_eq_eps(distance_to_cubic(p, &c), 5.379229, 0.00001));
    assert!(approx_eq_eps(brute_distance(&c, p), 5.379229, 0.00001));
    assert!(distance_to_curve(&c, p) >= 5.4);
}
