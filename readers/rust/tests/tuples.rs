// features/chapter04-tuples.feature

use renderer::{
    approx_eq, cross, dot, magnitude, normalize, point, tuples_eq, vector,
};

#[test]
fn a_point_has_w_1() {
    let p = point(4.0, -4.0);
    assert!(approx_eq(p.x, 4.0));
    assert!(approx_eq(p.y, -4.0));
    assert!(approx_eq(p.w, 1.0));
}

#[test]
fn a_vector_has_w_0() {
    let v = vector(4.0, -4.0);
    assert!(approx_eq(v.x, 4.0));
    assert!(approx_eq(v.y, -4.0));
    assert!(approx_eq(v.w, 0.0));
}

#[test]
fn the_difference_of_two_points_is_the_vector_between_them() {
    let a = point(3.0, 2.0);
    let b = point(5.0, 6.0);
    assert!(tuples_eq(b - a, vector(2.0, 4.0)));
    assert!(tuples_eq(a - b, vector(-2.0, -4.0)));
}

#[test]
fn a_point_plus_a_vector_is_a_point() {
    let p = point(3.0, -2.0);
    let v = vector(-2.0, 3.0);
    assert!(tuples_eq(p + v, point(1.0, 1.0)));
    assert!(tuples_eq(p - v, point(5.0, -5.0)));
}

#[test]
fn a_vector_plus_a_vector_is_a_vector() {
    let a = vector(3.0, -2.0);
    let b = vector(-2.0, 3.0);
    assert!(tuples_eq(a + b, vector(1.0, 1.0)));
    assert!(tuples_eq(a - b, vector(5.0, -5.0)));
}

#[test]
fn negating_scaling_and_dividing_a_vector() {
    let v = vector(1.0, -2.0);
    assert!(tuples_eq(-v, vector(-1.0, 2.0)));
    assert!(tuples_eq(v * 3.5, vector(3.5, -7.0)));
    assert!(tuples_eq(v * 0.5, vector(0.5, -1.0)));
    assert!(tuples_eq(v / 2.0, vector(0.5, -1.0)));
}

#[test]
fn the_magnitude_of_a_vector() {
    assert!(approx_eq(magnitude(vector(1.0, 0.0)), 1.0));
    assert!(approx_eq(magnitude(vector(0.0, 1.0)), 1.0));
    assert!(approx_eq(magnitude(vector(3.0, 4.0)), 5.0));
    assert!(approx_eq(magnitude(vector(-3.0, -4.0)), 5.0));
    assert!(approx_eq(magnitude(vector(-1.0, -2.0)), 2.2361));
}

#[test]
fn normalizing_a_vector() {
    assert!(tuples_eq(normalize(vector(4.0, 0.0)), vector(1.0, 0.0)));
    assert!(tuples_eq(normalize(vector(1.0, 2.0)), vector(0.4472, 0.8944)));
    assert!(approx_eq(magnitude(normalize(vector(1.0, 2.0))), 1.0));
}

#[test]
fn the_dot_product_of_two_vectors() {
    let a = vector(1.0, 2.0);
    let b = vector(2.0, 3.0);
    assert!(approx_eq(dot(a, b), 8.0));
    assert!(approx_eq(dot(a, vector(-2.0, 1.0)), 0.0));
}

#[test]
fn the_cross_product_of_two_vectors_is_a_number() {
    let a = vector(1.0, 0.0);
    let b = vector(0.0, 1.0);
    assert!(approx_eq(cross(a, b), 1.0));
    assert!(approx_eq(cross(b, a), -1.0));
    assert!(approx_eq(cross(a, a), 0.0));
    assert!(approx_eq(cross(vector(2.0, 3.0), vector(4.0, 5.0)), -2.0));
}

#[test]
fn the_sign_of_the_cross_product_says_which_side_of_a_line_a_point_is_on() {
    let a = point(0.0, 0.0);
    let b = point(10.0, 0.0);
    assert!(approx_eq(cross(b - a, point(5.0, 3.0) - a), 30.0));
    assert!(approx_eq(cross(b - a, point(5.0, -3.0) - a), -30.0));
    assert!(approx_eq(cross(b - a, point(20.0, 0.0) - a), 0.0));
}
