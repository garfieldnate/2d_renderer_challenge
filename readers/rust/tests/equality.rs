// features/chapter01-equality.feature

use renderer::{approx_eq, approx_eq_eps};

#[test]
fn two_numbers_within_tolerance_are_equal() {
    assert!(approx_eq_eps(1.0, 1.0000001, 0.00001));
}

#[test]
fn two_numbers_outside_tolerance_are_not_equal() {
    assert!(!approx_eq_eps(1.0, 1.001, 0.00001));
}

#[test]
fn default_tolerance_is_0_0001() {
    assert!(approx_eq(0.1 + 0.2, 0.3));
    assert!(approx_eq(1.0, 1.00009));
    assert!(!approx_eq(1.0, 1.0002));
}
