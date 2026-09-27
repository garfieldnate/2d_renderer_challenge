// features/chapter22-meet.feature

use renderer::{crossing_point, meet, path_segments, point, polygon, seg};

#[test]
fn a_segment_keeps_its_ends_in_the_sweeps_order() {
    let s = seg(point(10.0, 0.0), point(0.0, 0.0), 1, 0);
    assert_eq!(s.lo, point(0.0, 0.0));
    assert_eq!(s.hi, point(10.0, 0.0));
    assert_eq!(s.wa, -1);
    assert_eq!(s.wb, 0);
    assert_eq!(s, seg(point(0.0, 0.0), point(10.0, 0.0), -1, 0));
    assert_ne!(
        seg(point(0.0, 5.0), point(10.0, 5.0), 0, 1),
        seg(point(10.0, 5.0), point(0.0, 5.0), 0, 1)
    );
    assert_eq!(seg(point(4.0, 9.0), point(6.0, 2.0), 0, 1).lo, point(6.0, 2.0));
}

#[test]
fn a_paths_segments_are_its_edges_on_the_grid() {
    let p = polygon(&[point(1.0, 1.0), point(2.0, 1.0), point(2.0, 2.0), point(1.0, 2.0)]);
    let segs = path_segments(&p, "a");
    assert_eq!(
        segs,
        vec![
            seg(point(256.0, 256.0), point(512.0, 256.0), 1, 0),
            seg(point(512.0, 256.0), point(512.0, 512.0), 1, 0),
            seg(point(256.0, 512.0), point(512.0, 512.0), -1, 0),
            seg(point(256.0, 256.0), point(256.0, 512.0), -1, 0),
        ]
    );
    let p2 = polygon(&[point(1.0, 1.0), point(2.0, 1.0), point(2.001, 1.0), point(2.0, 2.0)]);
    assert_eq!(
        path_segments(&p2, "b"),
        vec![
            seg(point(256.0, 256.0), point(512.0, 256.0), 0, 1),
            seg(point(512.0, 256.0), point(512.0, 512.0), 0, 1),
            seg(point(256.0, 256.0), point(512.0, 512.0), 0, -1),
        ]
    );
}

#[test]
fn two_segments_crossing_are_both_split_where_they_cross() {
    let m = meet(
        &seg(point(0.0, 0.0), point(10.0, 10.0), 1, 0),
        &seg(point(0.0, 10.0), point(10.0, 0.0), 1, 0),
    );
    assert_eq!(m.kind, "cross");
    assert_eq!(m.on_s, vec![point(5.0, 5.0)]);
    assert_eq!(m.on_t, vec![point(5.0, 5.0)]);
}

#[test]
fn a_crossing_between_grid_points_rounds_to_one_halves_up() {
    let s = seg(point(0.0, 0.0), point(3.0, 1.0), 1, 0);
    let t = seg(point(0.0, 1.0), point(3.0, 0.0), 0, 1);
    assert_eq!(crossing_point(&s, &t), point(2.0, 1.0));
    assert_eq!(
        crossing_point(
            &seg(point(-3.0, 0.0), point(0.0, 1.0), 1, 0),
            &seg(point(-3.0, 1.0), point(0.0, 0.0), 0, 1)
        ),
        point(-1.0, 1.0)
    );
    assert_eq!(
        crossing_point(
            &seg(point(2.0, 0.0), point(10.0, 12.0), 1, 0),
            &seg(point(9.0, 0.0), point(6.0, 7.0), 1, 0)
        ),
        point(6.0, 6.0)
    );
    assert_eq!(
        crossing_point(
            &seg(point(2.0, 0.0), point(10.0, 12.0), 1, 0),
            &seg(point(7.0, 4.0), point(3.0, 7.0), 1, 0)
        ),
        point(5.0, 5.0)
    );
}

#[test]
fn a_crossing_that_rounds_onto_an_end_splits_only_the_other_segment() {
    let m = meet(
        &seg(point(0.0, 0.0), point(100.0, 1.0), 1, 0),
        &seg(point(0.0, 1.0), point(1.0, -1.0), 1, 0),
    );
    assert_eq!(m.kind, "cross");
    assert_eq!(m.on_s, Vec::<renderer::Tuple>::new());
    assert_eq!(m.on_t, vec![point(0.0, 0.0)]);
}

#[test]
fn an_end_touching_the_middle_of_another_segment_splits_it() {
    let m = meet(
        &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
        &seg(point(5.0, 0.0), point(5.0, 10.0), 1, 0),
    );
    assert_eq!(m.kind, "touch");
    assert_eq!(m.on_s, vec![point(5.0, 0.0)]);
    assert_eq!(m.on_t, Vec::<renderer::Tuple>::new());
}

#[test]
fn collinear_segments_that_overlap_split_each_other_at_their_ends() {
    let m = meet(
        &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
        &seg(point(4.0, 0.0), point(14.0, 0.0), 1, 0),
    );
    let n = meet(
        &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
        &seg(point(2.0, 0.0), point(6.0, 0.0), 1, 0),
    );
    let same = meet(
        &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
        &seg(point(10.0, 0.0), point(0.0, 0.0), 1, 0),
    );
    assert_eq!(m.kind, "overlap");
    assert_eq!(m.on_s, vec![point(4.0, 0.0)]);
    assert_eq!(m.on_t, vec![point(10.0, 0.0)]);
    assert_eq!(n.kind, "overlap");
    assert_eq!(n.on_s, vec![point(2.0, 0.0), point(6.0, 0.0)]);
    assert_eq!(n.on_t, Vec::<renderer::Tuple>::new());
    assert_eq!(same.kind, "overlap");
    assert_eq!(same.on_s, Vec::<renderer::Tuple>::new());
    assert_eq!(same.on_t, Vec::<renderer::Tuple>::new());
}

#[test]
fn segments_that_share_only_an_end_or_nothing_arent_split() {
    assert_eq!(
        meet(
            &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
            &seg(point(10.0, 0.0), point(10.0, 10.0), 1, 0)
        )
        .kind,
        "end"
    );
    assert_eq!(
        meet(
            &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
            &seg(point(10.0, 0.0), point(20.0, 0.0), 1, 0)
        )
        .kind,
        "end"
    );
    assert_eq!(
        meet(
            &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
            &seg(point(0.0, 1.0), point(10.0, 1.0), 1, 0)
        )
        .kind,
        "none"
    );
    assert_eq!(
        meet(
            &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
            &seg(point(11.0, 0.0), point(20.0, 0.0), 1, 0)
        )
        .kind,
        "none"
    );
    assert_eq!(
        meet(
            &seg(point(0.0, 0.0), point(10.0, 0.0), 1, 0),
            &seg(point(12.0, -5.0), point(12.0, 5.0), 1, 0)
        )
        .kind,
        "none"
    );
    assert_eq!(
        meet(
            &seg(point(0.0, 0.0), point(4.0, 4.0), 1, 0),
            &seg(point(3.0, 0.0), point(9.0, 2.0), 1, 0)
        )
        .kind,
        "none"
    );
}
