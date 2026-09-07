// features/chapter08-curves.feature

use renderer::{cubic, derivative, point, point_at, quadratic, split_at, transform_curve, translation, tuples_eq, vector};

#[test]
fn a_quadratic_evaluated_along_its_length() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    assert!(tuples_eq(point_at(&q, 0.0), point(0.0, 0.0)));
    assert!(tuples_eq(point_at(&q, 1.0), point(4.0, 0.0)));
    assert!(tuples_eq(point_at(&q, 0.5), point(2.0, 2.0)));
    assert!(tuples_eq(point_at(&q, 0.25), point(1.0, 1.5)));
}

#[test]
fn a_cubic_evaluated_at_its_middle() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    assert!(tuples_eq(point_at(&c, 0.5), point(2.0, 3.0)));
    assert!(tuples_eq(point_at(&c, 0.25), point(0.625, 2.25)));
}

#[test]
fn the_derivative_is_the_tangent_and_it_can_point_backward() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    assert!(tuples_eq(derivative(&q, 0.0), vector(4.0, 8.0)));
    assert!(tuples_eq(derivative(&q, 0.5), vector(4.0, 0.0)));
    assert!(tuples_eq(derivative(&q, 1.0), vector(4.0, -8.0)));
}

#[test]
fn splitting_and_rejoining_reproduces_the_curve() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let (left, right) = split_at(&c, 0.25);
    assert!(tuples_eq(point_at(&left, 1.0), point_at(&c, 0.25)));
    assert!(tuples_eq(point_at(&right, 0.0), point_at(&c, 0.25)));
    assert!(tuples_eq(point_at(&left, 0.4), point_at(&c, 0.1)));
    assert!(tuples_eq(point_at(&right, 0.4), point_at(&c, 0.55)));
    assert!(tuples_eq(point_at(&right, 1.0), point(4.0, 0.0)));
}

#[test]
fn a_curve_taken_through_a_matrix() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    let t = transform_curve(&q, translation(10.0, 20.0));
    assert!(tuples_eq(point_at(&t, 0.0), point(10.0, 20.0)));
    assert!(tuples_eq(point_at(&t, 0.5), point(12.0, 22.0)));
}
