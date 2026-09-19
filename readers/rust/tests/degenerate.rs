// features/chapter13-degenerate.feature

use renderer::{bounds, line_to, move_to, path, point, stroke_to_path, subpaths, tuples_eq};

fn assert_bounds(actual: (f64, f64, f64, f64), expected: (f64, f64, f64, f64)) {
    assert!(
        renderer::approx_eq(actual.0, expected.0)
            && renderer::approx_eq(actual.1, expected.1)
            && renderer::approx_eq(actual.2, expected.2)
            && renderer::approx_eq(actual.3, expected.3),
        "bounds: expected {expected:?}, got {actual:?}"
    );
}

#[test]
fn duplicate_consecutive_points_are_dropped() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 5.0));
    line_to(&mut seg, point(0.0, 5.0));
    line_to(&mut seg, point(10.0, 5.0));
    let o = stroke_to_path(&seg, 4.0, "butt", "miter", 4.0);

    assert_eq!(subpaths(&o).len(), 1);
    assert!(tuples_eq(subpaths(&o)[0].points[0], point(0.0, 7.0)));
}

#[test]
fn a_single_point_with_a_round_cap_is_a_dot() {
    let mut p = path();
    move_to(&mut p, point(20.0, 20.0));
    let o = stroke_to_path(&p, 10.0, "round", "miter", 4.0);

    assert_eq!(subpaths(&o).len(), 1);
    assert_bounds(bounds(&o), (15.0, 15.0, 25.0, 25.0));
}

#[test]
fn a_single_point_with_a_butt_cap_draws_nothing() {
    let mut p = path();
    move_to(&mut p, point(20.0, 20.0));
    let o = stroke_to_path(&p, 10.0, "butt", "miter", 4.0);

    assert_eq!(subpaths(&o).len(), 0);
}

#[test]
fn a_square_cap_extends_a_half_width_past_the_end() {
    let mut seg = path();
    move_to(&mut seg, point(45.0, 40.0));
    line_to(&mut seg, point(115.0, 40.0));
    let o = stroke_to_path(&seg, 30.0, "square", "miter", 4.0);

    assert_eq!(subpaths(&o).len(), 3);
    assert!(tuples_eq(subpaths(&o)[2].points[1], point(130.0, 55.0)));
    assert!(tuples_eq(subpaths(&o)[2].points[2], point(130.0, 25.0)));
}

#[test]
fn a_single_point_with_a_square_cap_is_a_square() {
    let mut p = path();
    move_to(&mut p, point(20.0, 20.0));
    let o = stroke_to_path(&p, 10.0, "square", "miter", 4.0);

    assert_eq!(subpaths(&o).len(), 1);
    assert_bounds(bounds(&o), (15.0, 15.0, 25.0, 25.0));
}
