// features/chapter04-transforms.feature

use renderer::{
    approx_eq, inverse, magnitude, point, rotation, scaling, shearing, translation, tuples_eq,
    vector,
};

const PI: f64 = std::f64::consts::PI;

#[test]
fn multiplying_by_a_translation_matrix() {
    let t = translation(5.0, -3.0);
    let p = point(-3.0, 4.0);
    assert!(tuples_eq(t * p, point(2.0, 1.0)));
}

#[test]
fn the_inverse_of_a_translation_moves_the_other_way() {
    let t = translation(5.0, -3.0);
    let p = point(-3.0, 4.0);
    assert!(tuples_eq(inverse(t) * p, point(-8.0, 7.0)));
}

#[test]
fn translation_does_not_affect_vectors() {
    let t = translation(5.0, -3.0);
    let v = vector(-3.0, 4.0);
    assert!(tuples_eq(t * v, v));
}

#[test]
fn a_scaling_matrix_applied_to_a_point() {
    let s = scaling(2.0, 3.0);
    let p = point(-4.0, 6.0);
    assert!(tuples_eq(s * p, point(-8.0, 18.0)));
}

#[test]
fn a_scaling_matrix_applied_to_a_vector() {
    let s = scaling(2.0, 3.0);
    let v = vector(-4.0, 6.0);
    assert!(tuples_eq(s * v, vector(-8.0, 18.0)));
}

#[test]
fn the_inverse_of_a_scaling_shrinks() {
    let s = scaling(2.0, 3.0);
    let v = vector(-4.0, 6.0);
    assert!(tuples_eq(inverse(s) * v, vector(-2.0, 2.0)));
}

#[test]
fn reflection_is_scaling_by_a_negative_value() {
    let s = scaling(-1.0, 1.0);
    let p = point(2.0, 3.0);
    assert!(tuples_eq(s * p, point(-2.0, 3.0)));
}

#[test]
fn a_positive_rotation_turns_x_toward_y() {
    let p = point(1.0, 0.0);
    assert!(tuples_eq(rotation(PI / 4.0) * p, point(0.7071, 0.7071)));
    assert!(tuples_eq(rotation(PI / 2.0) * p, point(0.0, 1.0)));
    assert!(tuples_eq(rotation(PI) * p, point(-1.0, 0.0)));
}

#[test]
fn the_inverse_of_a_rotation_turns_the_other_way() {
    let p = point(1.0, 0.0);
    assert!(tuples_eq(inverse(rotation(PI / 4.0)) * p, point(0.7071, -0.7071)));
    assert!(tuples_eq(rotation(-PI / 4.0) * p, point(0.7071, -0.7071)));
}

#[test]
fn a_rotation_preserves_length() {
    let v = vector(3.0, 4.0);
    assert!(approx_eq(magnitude(rotation(1.2) * v), 5.0));
    assert!(approx_eq(magnitude(rotation(-2.8) * v), 5.0));
}

#[test]
fn shearing_moves_x_in_proportion_to_y() {
    let s = shearing(1.0, 0.0);
    let p = point(2.0, 3.0);
    assert!(tuples_eq(s * p, point(5.0, 3.0)));
}

#[test]
fn shearing_moves_y_in_proportion_to_x() {
    let s = shearing(0.0, 1.0);
    let p = point(2.0, 3.0);
    assert!(tuples_eq(s * p, point(2.0, 5.0)));
}

#[test]
fn individual_transformations_are_applied_in_sequence() {
    let p = point(1.0, 0.0);
    let a = rotation(PI / 2.0);
    let b = scaling(5.0, 5.0);
    let c = translation(10.0, 5.0);

    let p2 = a * p;
    let p3 = b * p2;
    let p4 = c * p3;

    assert!(tuples_eq(p2, point(0.0, 1.0)));
    assert!(tuples_eq(p3, point(0.0, 5.0)));
    assert!(tuples_eq(p4, point(10.0, 10.0)));
}

#[test]
fn chained_transformations_must_be_applied_in_reverse_order() {
    let p = point(1.0, 0.0);
    let a = rotation(PI / 2.0);
    let b = scaling(5.0, 5.0);
    let c = translation(10.0, 5.0);

    let t = c * b * a;
    assert!(tuples_eq(t * p, point(10.0, 10.0)));
}

#[test]
fn the_other_order_is_a_different_transform() {
    let p = point(1.0, 0.0);
    let a = rotation(PI / 2.0);
    let b = scaling(5.0, 5.0);
    let c = translation(10.0, 5.0);

    let t = a * b * c;
    assert!(tuples_eq(t * p, point(-25.0, 55.0)));
}

#[test]
fn rotating_about_a_point_that_isnt_the_origin() {
    let t = translation(4.0, 4.0) * rotation(PI / 2.0) * translation(-4.0, -4.0);
    assert!(tuples_eq(t * point(6.0, 4.0), point(4.0, 6.0)));
    assert!(tuples_eq(t * point(4.0, 4.0), point(4.0, 4.0)));
}
