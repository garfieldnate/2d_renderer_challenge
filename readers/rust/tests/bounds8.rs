// features/chapter08-bounds.feature

use renderer::{approx_eq, cubic, curve_bounds, point, quadratic};

fn assert_bounds(actual: (f64, f64, f64, f64), expected: (f64, f64, f64, f64)) {
    assert!(
        approx_eq(actual.0, expected.0)
            && approx_eq(actual.1, expected.1)
            && approx_eq(actual.2, expected.2)
            && approx_eq(actual.3, expected.3),
        "bounds: expected {expected:?}, got {actual:?}"
    );
}

#[test]
fn the_curve_stays_well_inside_its_control_points() {
    let c = cubic(point(0.0, 0.0), point(1.0, 3.0), point(3.0, -2.0), point(4.0, 1.0));
    assert_bounds(curve_bounds(&c), (0.0, 0.0, 4.0, 1.0));
}

#[test]
fn an_arch_peaks_below_its_control_points() {
    let c = cubic(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 4.0), point(4.0, 0.0));
    assert_bounds(curve_bounds(&c), (0.0, 0.0, 4.0, 3.0));
}

#[test]
fn a_quadratics_bounds_come_from_its_one_turning_point() {
    let q = quadratic(point(0.0, 0.0), point(2.0, 4.0), point(4.0, 0.0));
    assert_bounds(curve_bounds(&q), (0.0, 0.0, 4.0, 2.0));
}
