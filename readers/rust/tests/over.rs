// features/chapter09-over.feature

use renderer::{color, from_color, opaque, over, pixel, pixels_eq, CLEAR};

#[test]
fn a_translucent_source_over_an_opaque_destination() {
    let src = from_color(color(1.0, 0.0, 0.0), 0.5);
    let dst = opaque(color(0.0, 0.0, 1.0));
    assert!(pixels_eq(over(src, dst), pixel(0.5, 0.0, 0.5, 1.0)));
}

#[test]
fn an_opaque_source_hides_the_destination() {
    let src = opaque(color(1.0, 0.0, 0.0));
    let dst = opaque(color(0.0, 0.0, 1.0));
    assert!(pixels_eq(over(src, dst), src));
}

#[test]
fn a_transparent_source_changes_nothing() {
    let dst = from_color(color(0.0, 0.0, 1.0), 0.4);
    assert!(pixels_eq(over(CLEAR, dst), dst));
}

#[test]
fn over_nothing_leaves_the_source_alone() {
    let src = from_color(color(1.0, 0.0, 0.0), 0.6);
    assert!(pixels_eq(over(src, CLEAR), src));
}

#[test]
fn two_translucent_pixels_stack_their_alphas() {
    let src = from_color(color(1.0, 0.0, 0.0), 0.6);
    let dst = from_color(color(0.0, 0.0, 1.0), 0.4);
    assert!(pixels_eq(over(src, dst), pixel(0.6, 0.0, 0.16, 0.76)));
}
