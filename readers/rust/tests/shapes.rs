// features/chapter02-shapes.feature

use renderer::{circle, half_plane, inside, rectangle};

#[test]
fn a_point_inside_a_circle() {
    let s = circle(8.0, 8.0, 5.0);
    assert!(inside(&s, 8.0, 8.0));
    assert!(inside(&s, 12.0, 8.0));
    assert!(inside(&s, 13.0, 8.0));
    assert!(!inside(&s, 13.01, 8.0));
    assert!(!inside(&s, 11.6, 11.6));
}

#[test]
fn a_point_inside_a_rectangle() {
    let s = rectangle(1.25, 2.0, 4.75, 5.0);
    assert!(inside(&s, 3.0, 3.0));
    assert!(inside(&s, 1.25, 2.0));
    assert!(inside(&s, 4.75, 5.0));
    assert!(!inside(&s, 1.2, 3.0));
    assert!(!inside(&s, 3.0, 5.1));
}

#[test]
fn a_point_inside_a_half_plane() {
    let s = half_plane(2.5, 0.0, 1.0, 0.0);
    assert!(inside(&s, 2.5, 7.0));
    assert!(inside(&s, 3.0, -4.0));
    assert!(!inside(&s, 2.4, 0.0));
}

#[test]
fn the_normal_picks_the_side() {
    let s = half_plane(2.5, 0.0, -1.0, 0.0);
    assert!(inside(&s, 2.4, 0.0));
    assert!(!inside(&s, 3.0, 0.0));
}
