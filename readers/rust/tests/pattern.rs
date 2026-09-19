// features/chapter15-pattern.feature

use renderer::{approx_eq, bounds, dash, line_to, move_to, normalize_pattern, path, point, stroke_to_path, subpaths};

fn assert_pattern_eq(actual: &[f64], expected: &[f64]) {
    assert_eq!(actual.len(), expected.len(), "expected {expected:?}, got {actual:?}");
    for (a, b) in actual.iter().zip(expected.iter()) {
        assert!(approx_eq(*a, *b), "expected {expected:?}, got {actual:?}");
    }
}

#[test]
fn an_odd_pattern_is_repeated_so_on_and_off_alternate_the_same_way_each_cycle() {
    assert_pattern_eq(&normalize_pattern(&[5.0]), &[5.0, 5.0]);
    assert_pattern_eq(&normalize_pattern(&[5.0, 2.0, 1.0]), &[5.0, 2.0, 1.0, 5.0, 2.0, 1.0]);
    assert_pattern_eq(&normalize_pattern(&[4.0, 2.0]), &[4.0, 2.0]);
}

#[test]
fn a_pattern_that_adds_up_to_nothing_or_has_a_negative_entry_is_no_pattern() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(100.0, 0.0));

    assert_pattern_eq(&normalize_pattern(&[0.0, 0.0]), &[]);
    assert_pattern_eq(&normalize_pattern(&[]), &[]);
    assert_pattern_eq(&normalize_pattern(&[5.0, -5.0]), &[]);
    assert_pattern_eq(&normalize_pattern(&[6.0, -2.0]), &[]);

    let d1 = dash(&seg, &[0.0, 0.0], 0.0);
    assert_eq!(subpaths(&d1).len(), 1);
    assert!(renderer::tuples_eq(subpaths(&d1)[0].points[1], point(100.0, 0.0)));

    assert_eq!(subpaths(&dash(&seg, &[], 0.0)).len(), 1);
    assert_eq!(subpaths(&dash(&seg, &[5.0, -5.0], 0.0)).len(), 1);
    assert_eq!(subpaths(&dash(&seg, &[6.0, -2.0], 0.0)).len(), 1);
}

#[test]
fn a_repeated_odd_pattern_walks_as_its_doubled_self() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(30.0, 0.0));
    let d = dash(&seg, &[5.0, 2.0, 1.0], 0.0);

    assert_eq!(subpaths(&d).len(), 6);
    assert!(renderer::tuples_eq(subpaths(&d)[0].points[1], point(5.0, 0.0)));
    assert!(renderer::tuples_eq(subpaths(&d)[1].points[0], point(7.0, 0.0)));
    assert!(renderer::tuples_eq(subpaths(&d)[1].points[1], point(8.0, 0.0)));
    assert!(renderer::tuples_eq(subpaths(&d)[2].points[0], point(13.0, 0.0)));
    assert!(renderer::tuples_eq(subpaths(&d)[3].points[0], point(16.0, 0.0)));
    assert!(renderer::tuples_eq(subpaths(&d)[3].points[1], point(21.0, 0.0)));
}

#[test]
fn a_zero_length_dash_is_a_point_and_with_a_round_cap_a_dot() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 0.0));
    line_to(&mut seg, point(12.0, 0.0));
    let d = dash(&seg, &[0.0, 6.0], 0.0);

    assert_eq!(subpaths(&d).len(), 2);
    assert_eq!(subpaths(&d)[0].points.len(), 1);
    assert!(renderer::tuples_eq(subpaths(&d)[0].points[0], point(0.0, 0.0)));
    assert!(renderer::tuples_eq(subpaths(&d)[1].points[0], point(6.0, 0.0)));

    let round = stroke_to_path(&d, 4.0, "round", "round", 4.0);
    assert_eq!(subpaths(&round).len(), 2);
    let b = bounds(&round);
    assert!(approx_eq(b.0, -2.0) && approx_eq(b.1, -2.0) && approx_eq(b.2, 8.0) && approx_eq(b.3, 2.0));

    let butt = stroke_to_path(&d, 4.0, "butt", "round", 4.0);
    assert_eq!(subpaths(&butt).len(), 0);
}
