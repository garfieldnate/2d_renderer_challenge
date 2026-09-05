// features/chapter01-mix.feature
//
// Linear blending is thread-local (see src/lib.rs), defaulting to on, so
// each test starts with the switch on regardless of test execution order
// or parallelism -- this is how the "reset before each scenario" rule from
// the chapter is honored in Rust's threaded test harness.

use renderer::{color, colors_eq, is_linear_blending, mix, set_linear_blending};

#[test]
fn linear_blending_is_on_by_default() {
    assert!(is_linear_blending());
}

#[test]
fn halfway_between_black_and_white() {
    let a = color(0.0, 0.0, 0.0);
    let b = color(1.0, 1.0, 1.0);
    assert!(colors_eq(mix(a, b, 0.5), color(0.5, 0.5, 0.5)));
}

#[test]
fn the_ends_of_a_mix_are_its_inputs() {
    let a = color(0.7, 0.0, 0.0);
    let b = color(0.0, 0.3, 0.02);
    assert!(colors_eq(mix(a, b, 0.0), a));
    assert!(colors_eq(mix(a, b, 1.0), b));
}

#[test]
fn red_to_green_in_light() {
    let a = color(0.7, 0.0, 0.0);
    let b = color(0.0, 0.3, 0.02);
    assert!(colors_eq(mix(a, b, 0.5), color(0.35, 0.15, 0.01)));
    assert!(colors_eq(mix(a, b, 0.25), color(0.525, 0.075, 0.005)));
}

#[test]
fn halfway_between_black_and_white_the_way_browsers_do_it() {
    set_linear_blending(false);
    let a = color(0.0, 0.0, 0.0);
    let b = color(1.0, 1.0, 1.0);
    assert!(colors_eq(mix(a, b, 0.5), color(0.2140, 0.2140, 0.2140)));
}

#[test]
fn red_to_green_the_way_browsers_do_it() {
    set_linear_blending(false);
    let a = color(0.7, 0.0, 0.0);
    let b = color(0.0, 0.3, 0.02);
    assert!(colors_eq(mix(a, b, 0.5), color(0.1527, 0.0693, 0.0067)));
}

#[test]
fn the_ends_of_a_mix_are_its_inputs_either_way() {
    set_linear_blending(false);
    let a = color(0.7, 0.0, 0.0);
    let b = color(0.0, 0.3, 0.02);
    assert!(colors_eq(mix(a, b, 0.0), a));
    assert!(colors_eq(mix(a, b, 1.0), b));
}
