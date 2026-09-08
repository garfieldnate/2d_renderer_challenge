// features/chapter10-stops.feature

use renderer::{color, colors_eq, sample_stops, stop};

#[test]
fn a_stop_offset_returns_its_own_colour() {
    let s = vec![stop(0.0, color(0.0, 0.0, 0.0)), stop(0.5, color(1.0, 0.0, 0.0)), stop(1.0, color(1.0, 1.0, 1.0))];
    assert!(colors_eq(sample_stops(&s, 0.0), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(sample_stops(&s, 0.5), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(sample_stops(&s, 1.0), color(1.0, 1.0, 1.0)));
}

#[test]
fn between_two_stops_is_a_straight_blend() {
    let s = vec![stop(0.0, color(0.0, 0.0, 0.0)), stop(0.5, color(1.0, 0.0, 0.0)), stop(1.0, color(1.0, 1.0, 1.0))];
    assert!(colors_eq(sample_stops(&s, 0.25), color(0.5, 0.0, 0.0)));
    assert!(colors_eq(sample_stops(&s, 0.75), color(1.0, 0.5, 0.5)));
}

#[test]
fn outside_the_ends_clamps_to_the_end_colours() {
    let s = vec![stop(0.0, color(0.0, 0.0, 0.0)), stop(0.5, color(1.0, 0.0, 0.0)), stop(1.0, color(1.0, 1.0, 1.0))];
    assert!(colors_eq(sample_stops(&s, -0.3), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(sample_stops(&s, 1.5), color(1.0, 1.0, 1.0)));
}

#[test]
fn uneven_stops_still_blend_by_their_own_spacing() {
    let s = vec![stop(0.0, color(0.0, 0.0, 0.0)), stop(0.8, color(1.0, 0.0, 0.0)), stop(1.0, color(0.0, 0.0, 1.0))];
    assert!(colors_eq(sample_stops(&s, 0.4), color(0.5, 0.0, 0.0)));
    assert!(colors_eq(sample_stops(&s, 0.9), color(0.5, 0.0, 0.5)));
}
