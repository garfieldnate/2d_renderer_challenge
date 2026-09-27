// features/chapter22-bentley.feature

use renderer::{find_splits, point, seg, split_segments, struck_segments, sweep_stats};

#[test]
fn three_segments_through_one_point_are_split_in_one_event() {
    let mut st = sweep_stats();
    let segs = vec![
        seg(point(0.0, 0.0), point(12.0, 12.0), 1, 0),
        seg(point(12.0, 0.0), point(0.0, 12.0), 1, 0),
        seg(point(6.0, 0.0), point(6.0, 12.0), 1, 0),
    ];
    let splits = find_splits(&segs, "bentley-ottmann", &mut st);
    assert_eq!(
        splits,
        vec![vec![point(6.0, 6.0)], vec![point(6.0, 6.0)], vec![point(6.0, 6.0)]]
    );
    assert_eq!(st.events, 7);
    assert_eq!(st.tests, 2);
}

#[test]
fn a_crossing_between_grid_points_is_an_exact_event_split_rounded() {
    let mut st = sweep_stats();
    let segs = vec![
        seg(point(0.0, 0.0), point(3.0, 1.0), 1, 0),
        seg(point(0.0, 1.0), point(3.0, 0.0), 0, 1),
    ];
    let splits = find_splits(&segs, "bentley-ottmann", &mut st);
    assert_eq!(splits, vec![vec![point(2.0, 1.0)], vec![point(2.0, 1.0)]]);
    assert_eq!(st.events, 5);
    assert_eq!(st.tests, 1);
}

#[test]
fn a_horizontal_segment_is_last_among_those_leaving_a_point() {
    let mut st = sweep_stats();
    let segs = vec![
        seg(point(0.0, 5.0), point(10.0, 5.0), 1, 0),
        seg(point(5.0, 0.0), point(5.0, 10.0), 1, 0),
        seg(point(2.0, 0.0), point(8.0, 10.0), 1, 0),
    ];
    let splits = find_splits(&segs, "bentley-ottmann", &mut st);
    assert_eq!(
        splits,
        vec![vec![point(5.0, 5.0)], vec![point(5.0, 5.0)], vec![point(5.0, 5.0)]]
    );
    assert_eq!(st.events, 7);
    assert_eq!(st.tests, 2);
}

#[test]
fn neighbours_that_part_and_meet_again_find_their_crossing_twice_and_its_one_event() {
    let mut st = sweep_stats();
    let segs = vec![
        seg(point(0.0, 0.0), point(10.0, 10.0), 1, 0),
        seg(point(10.0, 0.0), point(0.0, 10.0), 1, 0),
        seg(point(5.0, 1.0), point(5.0, 3.0), 1, 0),
    ];
    let splits = find_splits(&segs, "bentley-ottmann", &mut st);
    assert_eq!(splits, vec![vec![point(5.0, 5.0)], vec![point(5.0, 5.0)], vec![]]);
    assert_eq!(st.events, 7);
    assert_eq!(st.tests, 4);
}

#[test]
fn bentley_ottmann_finds_what_every_pair_finds_testing_neighbours_only() {
    let segs = struck_segments(1);
    let mut st = sweep_stats();
    let splits = find_splits(&segs, "bentley-ottmann", &mut st);
    assert_eq!(splits, find_splits(&segs, "brute", &mut sweep_stats()));
    assert_eq!(st.tests, 1659);
    assert_eq!(st.events, 879);
}

#[test]
fn the_whole_split_three_ways_one_answer() {
    let segs = struck_segments(2);
    let mut brute = sweep_stats();
    let mut sweep = sweep_stats();
    let mut bo = sweep_stats();
    let a = split_segments(&segs, "brute", &mut brute);
    let b = split_segments(&segs, "sweep", &mut sweep);
    let c = split_segments(&segs, "bentley-ottmann", &mut bo);
    assert_eq!(a, b);
    assert_eq!(a, c);
    assert_eq!(c.len(), 1559);
    assert_eq!(brute.tests, 2012677);
    assert_eq!(sweep.tests, 278841);
    assert_eq!(bo.tests, 5224);
    assert_eq!(bo.events, 2823);
    assert_eq!(bo.passes, 2);
}
