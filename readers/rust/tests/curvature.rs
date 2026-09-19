// features/chapter14-curvature.feature

use renderer::{approx_eq_eps, cubic, curvature, cusps, point, quadratic, second_derivative, tuples_eq, vector};

#[test]
fn the_second_derivative_of_a_quadratic_is_constant_a_cubics_is_linear() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));

    assert!(tuples_eq(second_derivative(&q, 0.0), vector(0.0, -16.0)));
    assert!(tuples_eq(second_derivative(&q, 0.5), vector(0.0, -16.0)));
    assert!(tuples_eq(second_derivative(&c, 0.0), vector(24.0, -24.0)));
    assert!(tuples_eq(second_derivative(&c, 0.5), vector(0.0, -24.0)));
    assert!(tuples_eq(second_derivative(&c, 1.0), vector(-24.0, -24.0)));
}

#[test]
fn curvature_is_signed_like_the_cross_product_and_its_reciprocal_is_a_radius() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    let line = cubic(point(0.0, 0.0), point(1.0, 1.0), point(2.0, 2.0), point(3.0, 3.0));
    let arc = cubic(
        point(100.0, 0.0),
        point(100.0, 55.2285),
        point(55.2285, 100.0),
        point(0.0, 100.0),
    );

    assert!(approx_eq_eps(curvature(&q, 0.5), -1.0, 0.0001));
    assert!(approx_eq_eps(curvature(&q, 0.0), -0.089443, 0.0001));
    assert!(approx_eq_eps(curvature(&c, 0.5), -0.666667, 0.0001));
    assert!(approx_eq_eps(curvature(&line, 0.5), 0.0, 0.0001));
    assert!(approx_eq_eps(curvature(&arc, 0.5), 0.009938, 0.0001));
    assert!(approx_eq_eps(curvature(&arc, 0.0), 0.009786, 0.0001));
}

#[test]
fn the_offset_stalls_where_d_reaches_the_radius_on_the_inside_of_the_turn() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));

    assert_eq!(cusps(&q, -0.5).len(), 0);
    assert_eq!(cusps(&q, 2.0).len(), 0);
    let c2 = cusps(&q, -2.0);
    assert_eq!(c2.len(), 2);
    assert!(approx_eq_eps(c2[0], 0.308395, 0.0001));
    assert!(approx_eq_eps(c2[1], 0.691605, 0.0001));
    assert!(approx_eq_eps(curvature(&q, c2[0]), -0.5, 0.0001));
}

#[test]
fn a_wider_offset_stalls_sooner() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));

    assert_eq!(cusps(&c, -1.0).len(), 0);
    assert_eq!(cusps(&c, -1.5).len(), 0);
    let c2 = cusps(&c, -2.0);
    assert_eq!(c2.len(), 2);
    assert!(approx_eq_eps(c2[0], 0.30334, 0.0001));
    assert!(approx_eq_eps(c2[1], 0.69666, 0.0001));
}
