// features/chapter04-scale.feature

use renderer::{approx_eq, approx_scale, identity, matrix3, rotation, scaling, shearing, translation};

#[test]
fn the_identity_a_translation_and_a_rotation_dont_stretch() {
    assert!(approx_eq(approx_scale(identity()), 1.0));
    assert!(approx_eq(approx_scale(translation(7.0, 9.0)), 1.0));
    assert!(approx_eq(approx_scale(rotation(1.1)), 1.0));
}

#[test]
fn a_uniform_scale_is_reported_exactly() {
    assert!(approx_eq(approx_scale(scaling(2.0, 2.0)), 2.0));
    assert!(approx_eq(approx_scale(scaling(0.5, 0.5)), 0.5));
    assert!(approx_eq(approx_scale(scaling(3.0, 3.0) * rotation(0.7)), 3.0));
    assert!(approx_eq(approx_scale(translation(5.0, 5.0) * scaling(3.0, 3.0)), 3.0));
}

#[test]
fn a_reflection_is_not_a_negative_scale() {
    assert!(approx_eq(approx_scale(scaling(-2.0, 2.0)), 2.0));
}

#[test]
fn a_non_uniform_scale_is_reported_as_the_geometric_mean() {
    assert!(approx_eq(approx_scale(scaling(4.0, 1.0)), 2.0));
    assert!(approx_eq(approx_scale(scaling(4.0, 1.0) * rotation(0.4)), 2.0));
    assert!(approx_eq(approx_scale(scaling(9.0, 1.0)), 3.0));
}

#[test]
fn a_shear_that_preserves_area_reports_1() {
    assert!(approx_eq(approx_scale(shearing(1.0, 0.0)), 1.0));
    assert!(approx_eq(approx_scale(shearing(0.5, 0.5)), 0.8660));
}

#[test]
fn a_collapsed_transform_reports_0() {
    assert!(approx_eq(approx_scale(scaling(0.0, 1.0)), 0.0));
    assert!(approx_eq(approx_scale(matrix3(1.0, 2.0, 0.0, 2.0, 4.0, 0.0, 0.0, 0.0, 1.0)), 0.0));
}
