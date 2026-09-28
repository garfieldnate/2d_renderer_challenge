// features/chapter25-brush.feature

use renderer::{
    approx_eq, brush, canvas, color, coverage_at, dab_coverage, fill, min_along, paint_stroke, pixel_at, point,
    stamp_positions, stroke_mask, wobbly_events,
};

#[test]
fn a_dabs_profile() {
    let b = brush(10.0, 0.5, 0.25, 0.6, 1.0);
    assert_eq!(dab_coverage(&b, 0.0), 1.0);
    assert_eq!(dab_coverage(&b, 5.0), 1.0);
    assert_eq!(dab_coverage(&b, 7.5), 0.5);
    assert_eq!(dab_coverage(&b, 10.0), 0.0);
    assert_eq!(dab_coverage(&b, 12.0), 0.0);
}

#[test]
fn dabs_are_spaced_by_distance_along_the_path_carried_across_events() {
    assert_eq!(
        stamp_positions(&[point(0.0, 0.0), point(3.0, 0.0), point(10.0, 0.0)], &brush(10.0, 0.5, 0.25, 0.6, 1.0)),
        vec![point(0.0, 0.0), point(5.0, 0.0), point(10.0, 0.0)]
    );
    assert_eq!(
        stamp_positions(&[point(0.0, 0.0), point(12.0, 0.0)], &brush(2.0, 1.0, 0.5, 1.0, 1.0)),
        vec![
            point(0.0, 0.0),
            point(2.0, 0.0),
            point(4.0, 0.0),
            point(6.0, 0.0),
            point(8.0, 0.0),
            point(10.0, 0.0),
            point(12.0, 0.0),
        ]
    );
    assert_eq!(stamp_positions(&wobbly_events(), &brush(8.0, 0.5, 0.25, 0.6, 1.0)).len(), 99);
}

#[test]
fn flow_builds_up_where_dabs_overlap() {
    let one = stroke_mask(20, 20, &[point(10.0, 10.0)], &brush(4.0, 0.5, 1.0, 0.6, 1.0));
    let two = stroke_mask(20, 20, &[point(10.0, 10.0), point(10.0, 10.0)], &brush(4.0, 0.5, 1.0, 0.6, 1.0));
    assert_eq!(coverage_at(&one, 10, 10), 0.6);
    assert!(approx_eq(coverage_at(&one, 12, 10), 0.435147));
    assert_eq!(coverage_at(&two, 10, 10), 0.84);
}

#[test]
fn opacity_caps_the_stroke_however_often_it_crosses_itself() {
    let mut c = canvas(60, 40);
    fill(&mut c, color(1.0, 1.0, 1.0));
    let m = paint_stroke(
        &mut c,
        &[point(10.0, 20.0), point(50.0, 20.0), point(10.0, 20.0), point(50.0, 20.0)],
        &brush(6.0, 1.0, 0.25, 1.0, 0.5),
        color(0.0, 0.0, 0.0),
        true,
    );
    assert_eq!(coverage_at(&m, 30, 20), 0.5);
    assert_eq!(pixel_at(&c, 30, 20), color(0.5, 0.5, 0.5));
}

#[test]
fn one_dab_per_event_leaves_beads_spacing_by_distance_doesnt() {
    let ev = wobbly_events();
    let b = brush(8.0, 0.5, 0.25, 0.6, 1.0);
    let by_distance = stroke_mask(400, 120, &stamp_positions(&ev, &b), &b);
    let by_event = stroke_mask(400, 120, &ev, &b);
    assert_eq!(min_along(&by_event, &ev, 50), 0.0);
    assert!(approx_eq(min_along(&by_distance, &ev, 50), 0.704456));
}
