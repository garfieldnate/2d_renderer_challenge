// features/chapter01-colors.feature

use renderer::{approx_eq, color, colors_eq};

#[test]
fn a_color_is_a_red_green_blue_tuple() {
    let c = color(-0.5, 0.4, 1.7);
    assert!(approx_eq(c.red, -0.5));
    assert!(approx_eq(c.green, 0.4));
    assert!(approx_eq(c.blue, 1.7));
}

#[test]
fn adding_colors() {
    let c1 = color(0.9, 0.6, 0.75);
    let c2 = color(0.7, 0.1, 0.25);
    assert!(colors_eq(c1 + c2, color(1.6, 0.7, 1.0)));
}

#[test]
fn subtracting_colors() {
    let c1 = color(0.9, 0.6, 0.75);
    let c2 = color(0.7, 0.1, 0.25);
    assert!(colors_eq(c1 - c2, color(0.2, 0.5, 0.5)));
}

#[test]
fn scaling_a_color_by_a_number() {
    let c = color(0.2, 0.3, 0.4);
    assert!(colors_eq(c * 2.0, color(0.4, 0.6, 0.8)));
    assert!(colors_eq(c * 0.5, color(0.1, 0.15, 0.2)));
}

#[test]
fn multiplying_two_colors_filters_one_through_the_other() {
    let c1 = color(1.0, 0.2, 0.4);
    let c2 = color(0.9, 1.0, 0.1);
    assert!(colors_eq(c1 * c2, color(0.9, 0.2, 0.04)));
}

#[test]
fn colors_compare_component_by_component_with_the_usual_tolerance() {
    let c1 = color(0.1, 0.5, 1.0);
    let c2 = color(0.2, 0.0, 0.0);
    assert!(colors_eq(c1 + c2, color(0.3, 0.5, 1.0)));
    assert!(!colors_eq(c1 + c2, color(0.3, 0.5, 1.001)));
}
