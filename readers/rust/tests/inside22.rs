// features/chapter22-inside.feature

use renderer::{
    inside_rule, keep_edges, merge_segments, op_inside, path_segments, point, polygon, seg,
    split_segments, sweep_stats, winding_beside,
};

#[test]
fn the_two_sides_of_a_squares_edges() {
    let sq = merge_segments(&[
        seg(point(0.0, 0.0), point(4.0, 0.0), 1, 0),
        seg(point(4.0, 0.0), point(4.0, 4.0), 1, 0),
        seg(point(4.0, 4.0), point(0.0, 4.0), 1, 0),
        seg(point(0.0, 4.0), point(0.0, 0.0), 1, 0),
    ]);
    assert_eq!(sq[0], seg(point(0.0, 0.0), point(4.0, 0.0), 1, 0));
    assert_eq!(winding_beside(&sq, 0), ((0, 0), (1, 0)));
    assert_eq!(sq[1], seg(point(0.0, 0.0), point(0.0, 4.0), -1, 0));
    assert_eq!(winding_beside(&sq, 1), ((1, 0), (0, 0)));
    assert_eq!(winding_beside(&sq, 2), ((0, 0), (1, 0)));
    assert_eq!(winding_beside(&sq, 3), ((1, 0), (0, 0)));
}

fn two_squares_split() -> Vec<renderer::Seg> {
    let a = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let b = polygon(&[point(5.0, 5.0), point(15.0, 5.0), point(15.0, 15.0), point(5.0, 15.0)]);
    let mut segs = path_segments(&a, "a");
    segs.extend(path_segments(&b, "b"));
    split_segments(&segs, "brute", &mut sweep_stats())
}

#[test]
fn where_two_squares_overlap_both_paths_wind_around_the_middle() {
    let segs = two_squares_split();
    assert_eq!(segs[3], seg(point(1280.0, 1280.0), point(2560.0, 1280.0), 0, 1));
    assert_eq!(winding_beside(&segs, 3), ((1, 0), (1, 1)));
    assert_eq!(segs[6], seg(point(2560.0, 1280.0), point(2560.0, 2560.0), 1, 0));
    assert_eq!(winding_beside(&segs, 6), ((0, 1), (1, 1)));
}

#[test]
fn the_ray_breaks_a_tie_in_y_by_x_as_the_sweep_does() {
    let segs = vec![
        seg(point(0.0, 0.0), point(0.0, 10.0), 1, 0),
        seg(point(4.0, 0.0), point(4.0, 5.0), 0, 1),
        seg(point(4.0, 5.0), point(4.0, 20.0), 0, -1),
    ];
    let flat = vec![
        seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
        seg(point(12.0, -5.0), point(12.0, 0.0), 0, 1),
        seg(point(12.0, 0.0), point(12.0, 5.0), 0, -1),
    ];
    assert_eq!(winding_beside(&segs, 0), ((0, 1), (1, 1)));
    assert_eq!(winding_beside(&flat, 0), ((0, 1), (1, 1)));
}

#[test]
fn what_each_operation_calls_inside() {
    let cases: [(&str, bool, bool, bool); 4] = [
        ("union", true, true, true),
        ("intersection", true, false, false),
        ("difference", false, true, false),
        ("xor", false, true, true),
    ];
    for (op, both, a_only, b_only) in cases {
        assert_eq!(op_inside(op, true, true), both);
        assert_eq!(op_inside(op, true, false), a_only);
        assert_eq!(op_inside(op, false, true), b_only);
        assert_eq!(op_inside(op, false, false), false);
    }
}

#[test]
fn a_winding_of_2_is_inside_under_nonzero_and_outside_under_even_odd() {
    assert!(inside_rule(2, "nonzero"));
    assert!(!inside_rule(2, "evenodd"));
    assert!(inside_rule(-1, "evenodd"));
    assert!(inside_rule(-2, "nonzero"));
    assert!(!inside_rule(0, "nonzero"));
}

#[test]
fn the_kept_edges_run_with_the_inside_on_their_right() {
    let segs = two_squares_split();
    assert_eq!(
        keep_edges(&segs, "nonzero", "nonzero", "intersection"),
        vec![
            (point(1280.0, 1280.0), point(2560.0, 1280.0)),
            (point(1280.0, 2560.0), point(1280.0, 1280.0)),
            (point(2560.0, 1280.0), point(2560.0, 2560.0)),
            (point(2560.0, 2560.0), point(1280.0, 2560.0)),
        ]
    );
    assert_eq!(
        keep_edges(&segs, "nonzero", "nonzero", "difference"),
        vec![
            (point(0.0, 0.0), point(2560.0, 0.0)),
            (point(0.0, 2560.0), point(0.0, 0.0)),
            (point(2560.0, 0.0), point(2560.0, 1280.0)),
            (point(2560.0, 1280.0), point(1280.0, 1280.0)),
            (point(1280.0, 1280.0), point(1280.0, 2560.0)),
            (point(1280.0, 2560.0), point(0.0, 2560.0)),
        ]
    );
    assert_eq!(keep_edges(&segs, "nonzero", "nonzero", "union").len(), 8);
    assert_eq!(keep_edges(&segs, "nonzero", "nonzero", "xor").len(), 12);
}
