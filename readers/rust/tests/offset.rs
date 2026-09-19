// features/chapter14-offset.feature

use renderer::{
    approx_eq_eps, cubic, magnitude, normal_at, offset_point, point, point_at, quadratic,
    tangent_at, tuples_eq, vector,
};

fn assert_vec_eq(a: renderer::Tuple, b: renderer::Tuple) {
    assert!(tuples_eq(a, b), "expected {b:?}, got {a:?}");
}

#[test]
fn the_normal_is_the_tangent_turned_toward_plus_y() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    assert_vec_eq(tangent_at(&q, 0.0), vector(0.447214, 0.894427));
    assert_vec_eq(normal_at(&q, 0.0), vector(-0.894427, 0.447214));
    assert_vec_eq(tangent_at(&q, 0.5), vector(1.0, 0.0));
    assert_vec_eq(normal_at(&q, 0.5), vector(0.0, 1.0));
}

#[test]
fn offsetting_a_straight_curve_gives_the_parallel_line() {
    let line = cubic(point(0.0, 0.0), point(1.0, 1.0), point(2.0, 2.0), point(3.0, 3.0));
    assert_vec_eq(offset_point(&line, 0.0, 1.0), point(-0.707107, 0.707107));
    assert_vec_eq(offset_point(&line, 0.5, 2.0_f64.sqrt()), point(0.5, 2.5));
    assert_vec_eq(offset_point(&line, 1.0, -1.0), point(3.707107, 2.292893));
}

#[test]
fn positive_d_is_below_a_rightward_tangent_negative_is_above() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    assert_vec_eq(point_at(&c, 0.5), point(2.0, 3.0));
    assert_vec_eq(offset_point(&c, 0.5, 1.0), point(2.0, 4.0));
    assert_vec_eq(offset_point(&c, 0.5, -1.0), point(2.0, 2.0));
}

#[test]
fn offsetting_a_circle_moves_it_to_another_circle_about_the_same_center() {
    let arc = cubic(
        point(100.0, 0.0),
        point(100.0, 55.2285),
        point(55.2285, 100.0),
        point(0.0, 100.0),
    );
    assert!(approx_eq_eps(magnitude(offset_point(&arc, 0.5, 10.0) - point(0.0, 0.0)), 90.0, 0.05));
    assert!(approx_eq_eps(magnitude(offset_point(&arc, 0.25, -10.0) - point(0.0, 0.0)), 110.0, 0.05));
    assert!(approx_eq_eps(magnitude(offset_point(&arc, 0.0, 10.0) - point(0.0, 0.0)), 90.0, 0.0001));
}

#[test]
fn a_handle_sitting_on_its_anchor_still_has_a_direction() {
    let stalled = cubic(point(0.0, 0.0), point(0.0, 0.0), point(4.0, 4.0), point(4.0, 0.0));
    let p = offset_point(&stalled, 0.0, 1.0);
    assert!(approx_eq_eps(p.x, -0.707107, 0.001));
    assert!(approx_eq_eps(p.y, 0.707107, 0.001));
}
