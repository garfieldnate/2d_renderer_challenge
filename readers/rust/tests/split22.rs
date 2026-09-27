// features/chapter22-split.feature

use renderer::{
    find_splits, lex_less, merge_segments, path_segments, point, polygon, seg, split_segments,
    sweep_stats,
};

#[test]
fn split_points_come_in_order_along_the_segment() {
    let mut st = sweep_stats();
    let segs = vec![
        seg(point(10.0, 0.0), point(0.0, 5.0), 1, 0),
        seg(point(2.0, -1.0), point(3.0, 9.0), 1, 0),
        seg(point(7.0, -1.0), point(8.0, 9.0), 1, 0),
    ];
    let splits = find_splits(&segs, "brute", &mut st);
    assert_eq!(splits[0], vec![point(7.0, 1.0), point(2.0, 4.0)]);
    assert_eq!(splits[1], vec![point(2.0, 4.0)]);
    assert_eq!(splits[2], vec![point(7.0, 1.0)]);
    assert_eq!(st.tests, 3);
}

#[test]
fn rounded_points_go_in_order_along_the_segment_not_in_the_sweeps_order() {
    let segs = vec![
        seg(point(6.0, 0.0), point(5.0, 100.0), 1, 0),
        seg(point(15.0, 42.0), point(-5.0, 59.0), 0, 1),
        seg(point(12.0, 43.0), point(-3.0, 59.0), 0, 1),
    ];
    let splits = find_splits(&segs, "brute", &mut sweep_stats());
    assert_eq!(splits[0], vec![point(6.0, 50.0), point(5.0, 50.0)]);
    assert!(lex_less(point(5.0, 50.0), point(6.0, 50.0)));
}

#[test]
fn merging_adds_windings_and_a_segment_that_adds_nothing_goes() {
    let m = merge_segments(&[
        seg(point(0.0, 0.0), point(4.0, 0.0), 1, 0),
        seg(point(4.0, 0.0), point(0.0, 0.0), 1, 0),
        seg(point(1.0, 1.0), point(2.0, 2.0), 1, 0),
        seg(point(0.0, 0.0), point(0.0, 4.0), 0, 1),
        seg(point(0.0, 4.0), point(0.0, 0.0), 0, -1),
    ]);
    assert_eq!(
        m,
        vec![
            seg(point(0.0, 0.0), point(0.0, 4.0), 0, 2),
            seg(point(1.0, 1.0), point(2.0, 2.0), 1, 0),
        ]
    );
}

#[test]
fn two_overlapping_squares_split_into_twelve_segments_in_two_passes() {
    let a = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let b = polygon(&[point(5.0, 5.0), point(15.0, 5.0), point(15.0, 15.0), point(5.0, 15.0)]);
    let mut st = sweep_stats();
    let mut segs = path_segments(&a, "a");
    segs.extend(path_segments(&b, "b"));
    let segs = split_segments(&segs, "brute", &mut st);
    assert_eq!(segs.len(), 12);
    assert_eq!(segs[2], seg(point(2560.0, 0.0), point(2560.0, 1280.0), 1, 0));
    assert_eq!(segs[3], seg(point(1280.0, 1280.0), point(2560.0, 1280.0), 0, 1));
    assert_eq!(segs[4], seg(point(1280.0, 1280.0), point(1280.0, 2560.0), 0, -1));
    assert_eq!(st.passes, 2);
    assert_eq!(st.tests, 94);
}

#[test]
fn rounding_a_crossing_can_make_a_new_meeting_so_the_loop_goes_round_again() {
    let segs = vec![
        seg(point(2.0, 0.0), point(10.0, 12.0), 1, 0),
        seg(point(9.0, 0.0), point(6.0, 7.0), 1, 0),
        seg(point(7.0, 4.0), point(3.0, 7.0), 1, 0),
    ];
    let mut st = sweep_stats();
    let first = find_splits(&merge_segments(&segs), "brute", &mut sweep_stats());
    let out = split_segments(&segs, "brute", &mut st);
    assert_eq!(first[0], vec![point(5.0, 5.0), point(6.0, 6.0)]);
    assert_eq!(first[1], vec![point(6.0, 6.0)]);
    assert_eq!(first[2], vec![point(5.0, 5.0)]);
    assert_eq!(st.passes, 3);
    assert_eq!(
        out,
        vec![
            seg(point(2.0, 0.0), point(5.0, 5.0), 1, 0),
            seg(point(9.0, 0.0), point(7.0, 4.0), 1, 0),
            seg(point(7.0, 4.0), point(5.0, 5.0), 1, 0),
            seg(point(7.0, 4.0), point(6.0, 6.0), 1, 0),
            seg(point(5.0, 5.0), point(6.0, 6.0), 1, 0),
            seg(point(5.0, 5.0), point(3.0, 7.0), 1, 0),
            seg(point(6.0, 6.0), point(6.0, 7.0), 1, 0),
            seg(point(6.0, 6.0), point(10.0, 12.0), 1, 0),
        ]
    );
}
