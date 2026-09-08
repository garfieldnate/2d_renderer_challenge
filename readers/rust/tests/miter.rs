// features/chapter13-miter.feature

use renderer::{approx_eq_eps, chevron, miter_length, stroke_to_path, subpaths, vector};

#[test]
fn the_miter_length_matches_the_closed_form() {
    assert!(approx_eq_eps(miter_length(vector(1.0, 0.0), vector(0.0, 1.0), 2.0), 2.828427, 0.0001));
    assert!(approx_eq_eps(
        miter_length(vector(1.0, 0.0), vector(0.5, 0.866025), 2.0),
        2.309401,
        0.0001
    ));
}

#[test]
fn the_miter_limit_switches_the_join_to_a_bevel_past_its_threshold() {
    let sharp = stroke_to_path(&chevron(), 26.0, "butt", "miter", 2.0);
    let flat = stroke_to_path(&chevron(), 26.0, "butt", "miter", 1.5);

    assert_eq!(subpaths(&sharp)[2].points.len(), 4);
    assert_eq!(subpaths(&flat)[2].points.len(), 3);
}
