// features/chapter22-sweep.feature

use renderer::{find_splits, point, seg, struck_segments, sweep_stats};

#[test]
fn the_sweep_finds_what_every_pair_finds() {
    let segs = struck_segments(1);
    let mut brute = sweep_stats();
    let mut sweep = sweep_stats();
    let a = find_splits(&segs, "brute", &mut brute);
    let b = find_splits(&segs, "sweep", &mut sweep);
    assert_eq!(segs.len(), 787);
    assert_eq!(a, b);
    assert_eq!(brute.tests, 309291);
    assert_eq!(sweep.tests, 34326);
}

#[test]
fn only_pairs_whose_rows_overlap_are_tested() {
    let segs = vec![
        seg(point(0.0, 0.0), point(10.0, 10.0), 1, 0),
        seg(point(0.0, 20.0), point(10.0, 30.0), 1, 0),
        seg(point(10.0, 0.0), point(0.0, 10.0), 0, 1),
        seg(point(5.0, 10.0), point(5.0, 20.0), 0, 1),
    ];
    let mut st = sweep_stats();
    let mut brute = sweep_stats();
    let splits = find_splits(&segs, "sweep", &mut st);
    assert_eq!(splits, find_splits(&segs, "brute", &mut brute));
    assert_eq!(st.tests, 3);
    assert_eq!(brute.tests, 6);
    assert_eq!(splits[0], vec![point(5.0, 5.0)]);
    assert_eq!(splits[2], vec![point(5.0, 5.0)]);
    assert_eq!(splits[3], Vec::<renderer::Tuple>::new());
}

#[test]
fn a_segment_that_ends_where_another_starts_is_out_of_the_list() {
    let mut st = sweep_stats();
    let segs = vec![
        seg(point(0.0, 0.0), point(0.0, 10.0), 1, 0),
        seg(point(0.0, 10.0), point(0.0, 20.0), 1, 0),
    ];
    find_splits(&segs, "sweep", &mut st);
    assert_eq!(st.tests, 0);
}
