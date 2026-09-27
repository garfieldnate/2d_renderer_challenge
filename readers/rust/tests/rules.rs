// features/chapter05-rules.feature

use renderer::{
    approx_eq, bounds, close, coverage_at, filled, ink, inside, inside_evenodd, inside_nonzero,
    line_to, move_to, path, point, polygon, rasterize, rasterize_within, star, winding_at,
};

#[test]
fn a_single_loop_is_inside_under_both_rules() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    assert!(inside_nonzero(&p, 5.0, 5.0));
    assert!(inside_evenodd(&p, 5.0, 5.0));
    assert!(!inside_nonzero(&p, 15.0, 5.0));
    assert!(!inside_evenodd(&p, 15.0, 5.0));
}

#[test]
fn an_inner_loop_the_other_way_round_is_a_hole_under_both_rules() {
    let mut p = path();
    move_to(&mut p, point(0.0, 0.0));
    line_to(&mut p, point(10.0, 0.0));
    line_to(&mut p, point(10.0, 10.0));
    line_to(&mut p, point(0.0, 10.0));
    close(&mut p);
    move_to(&mut p, point(3.0, 3.0));
    line_to(&mut p, point(3.0, 7.0));
    line_to(&mut p, point(7.0, 7.0));
    line_to(&mut p, point(7.0, 3.0));
    close(&mut p);

    assert_eq!(winding_at(&p, 5.0, 5.0), 0);
    assert_eq!(winding_at(&p, 1.0, 1.0), 1);
    assert!(!inside_nonzero(&p, 5.0, 5.0));
    assert!(!inside_evenodd(&p, 5.0, 5.0));
    assert!(inside_nonzero(&p, 1.0, 1.0));
}

#[test]
fn an_inner_loop_the_same_way_round_is_a_hole_only_under_even_odd() {
    let mut p = path();
    move_to(&mut p, point(0.0, 0.0));
    line_to(&mut p, point(10.0, 0.0));
    line_to(&mut p, point(10.0, 10.0));
    line_to(&mut p, point(0.0, 10.0));
    close(&mut p);
    move_to(&mut p, point(3.0, 3.0));
    line_to(&mut p, point(7.0, 3.0));
    line_to(&mut p, point(7.0, 7.0));
    line_to(&mut p, point(3.0, 7.0));
    close(&mut p);

    assert_eq!(winding_at(&p, 5.0, 5.0), 2);
    assert!(inside_nonzero(&p, 5.0, 5.0));
    assert!(!inside_evenodd(&p, 5.0, 5.0));
}

#[test]
fn a_loop_wound_twice_vanishes_under_even_odd() {
    let mut p = path();
    move_to(&mut p, point(5.0, 0.0));
    line_to(&mut p, point(10.0, 5.0));
    line_to(&mut p, point(5.0, 10.0));
    line_to(&mut p, point(0.0, 5.0));
    line_to(&mut p, point(5.0, 0.0));
    line_to(&mut p, point(10.0, 5.0));
    line_to(&mut p, point(5.0, 10.0));
    line_to(&mut p, point(0.0, 5.0));
    close(&mut p);

    assert!(inside_nonzero(&p, 5.0, 5.0));
    assert!(!inside_evenodd(&p, 5.0, 5.0));
}

#[test]
fn the_pentagrams_center_is_inside_under_nonzero_and_outside_under_even_odd() {
    let p = star();
    assert!(inside_nonzero(&p, 80.5, 80.5));
    assert!(!inside_evenodd(&p, 80.5, 80.5));
    assert!(inside_nonzero(&p, 80.5, 20.0));
    assert!(inside_evenodd(&p, 80.5, 20.0));
    assert!(!inside_nonzero(&p, 80.5, 120.0));
    assert!(!inside_evenodd(&p, 80.5, 120.0));
}

#[test]
fn a_filled_path_is_a_shape() {
    let p = polygon(&[point(2.0, 2.0), point(6.0, 2.0), point(6.0, 6.0), point(2.0, 6.0)]);
    let s = filled(&p, "nonzero");
    let cov = rasterize(&s, 8, 8);

    assert!(inside(&s, 3.0, 3.0));
    assert!(!inside(&s, 7.0, 3.0));
    assert!(approx_eq(coverage_at(&cov, 3, 3), 1.0));
    assert!(approx_eq(coverage_at(&cov, 1, 3), 0.0));
    assert!(approx_eq(coverage_at(&cov, 6, 3), 0.0));
    assert!(approx_eq(ink(&cov), 16.0));
}

#[test]
fn a_filled_path_takes_the_rule_seriously() {
    let p = star();
    let a = filled(&p, "nonzero");
    let b = filled(&p, "evenodd");
    let ca = rasterize(&a, 160, 160);
    let cb = rasterize(&b, 160, 160);

    assert!(approx_eq(coverage_at(&ca, 80, 80), 1.0));
    assert!(approx_eq(coverage_at(&cb, 80, 80), 0.0));
    assert!(approx_eq(coverage_at(&ca, 80, 20), 1.0));
    assert!(approx_eq(coverage_at(&cb, 80, 20), 1.0));
    assert!(approx_eq(coverage_at(&ca, 80, 10), 0.0625));
    assert!(approx_eq(coverage_at(&cb, 80, 10), 0.0625));
    assert!(approx_eq(ink(&ca), 5499.9375));
    assert!(approx_eq(ink(&cb), 3800.375));
}

#[test]
fn rasterizing_within_the_bounds_gives_the_same_coverage() {
    let p = star();
    let s = filled(&p, "evenodd");
    let full = rasterize(&s, 160, 160);
    let within = rasterize_within(&s, bounds(&p), 160, 160);

    assert!(approx_eq(ink(&within), ink(&full)));
    assert!(approx_eq(coverage_at(&within, 80, 20), coverage_at(&full, 80, 20)));
    assert!(approx_eq(coverage_at(&within, 13, 58), coverage_at(&full, 13, 58)));
    assert!(approx_eq(coverage_at(&within, 10, 10), 0.0));
}

#[test]
fn the_box_is_inclusive_of_the_pixels_it_touches_and_clipped_to_the_buffer() {
    let p = polygon(&[
        point(1.5, 1.5),
        point(6.5, 1.5),
        point(6.5, 6.5),
        point(1.5, 6.5),
    ]);
    let s = filled(&p, "nonzero");
    let cov = rasterize_within(&s, (1.5, 1.5, 6.5, 6.5), 8, 8);
    let big = rasterize_within(&s, (-5.0, -5.0, 20.0, 20.0), 8, 8);

    assert!(approx_eq(coverage_at(&cov, 1, 1), 0.25));
    assert!(approx_eq(coverage_at(&cov, 6, 6), 0.25));
    assert!(approx_eq(coverage_at(&cov, 3, 3), 1.0));
    assert!(approx_eq(ink(&cov), 25.0));
    assert!(approx_eq(ink(&big), 25.0));
}

#[test]
fn even_odd_counts_negative_windings_too() {
    let p = polygon(&[point(0.0, 0.0), point(0.0, 10.0), point(10.0, 10.0), point(10.0, 0.0)]);
    let mut q = path();
    move_to(&mut q, point(5.0, 0.0));
    let seq = [(0.0, 5.0), (5.0, 10.0), (10.0, 5.0), (5.0, 0.0), (0.0, 5.0), (5.0, 10.0), (10.0, 5.0),
               (5.0, 0.0), (0.0, 5.0), (5.0, 10.0), (10.0, 5.0)];
    for (x, y) in seq { line_to(&mut q, point(x, y)); }
    close(&mut q);
    assert_eq!(winding_at(&p, 5.0, 5.0), -1);
    assert!(inside_evenodd(&p, 5.0, 5.0));
    assert_eq!(winding_at(&q, 5.0, 5.0), -3);
    assert!(inside_evenodd(&q, 5.0, 5.0));
    assert!(inside_nonzero(&q, 5.0, 5.0));
}
