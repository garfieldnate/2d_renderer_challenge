// features/chapter12-clip.feature

use renderer::{
    circle_path, clip_path, clip_rect, coverage_at, coverage_buffer, fill_path, full_clip,
    max_coverage_difference, multiply_coverage, point, polygon, set_coverage,
};

#[test]
fn multiplying_two_coverage_buffers_cell_by_cell() {
    let mut a = coverage_buffer(2, 1);
    let mut b = coverage_buffer(2, 1);
    set_coverage(&mut a, 0, 0, 0.5);
    set_coverage(&mut a, 1, 0, 1.0);
    set_coverage(&mut b, 0, 0, 0.5);
    set_coverage(&mut b, 1, 0, 0.25);

    let m = multiply_coverage(&a, &b);
    assert!((coverage_at(&m, 0, 0) - 0.25).abs() < 0.0001);
    assert!((coverage_at(&m, 1, 0) - 0.25).abs() < 0.0001);
}

#[test]
fn clipping_to_the_whole_canvas_changes_nothing() {
    let cov = fill_path(&circle_path(6.0, 6.0, 4.0, 32), "nonzero", 12, 12);
    let full = full_clip(12, 12);
    assert_eq!(max_coverage_difference(&multiply_coverage(&cov, &full), &cov), 0.0);
}

#[test]
fn nested_clips_commute() {
    let r = clip_rect(2.0, 2.0, 8.0, 8.0, 12, 12);
    let c = clip_path(&circle_path(6.0, 6.0, 4.0, 32), "nonzero", 12, 12);
    assert_eq!(max_coverage_difference(&multiply_coverage(&r, &c), &multiply_coverage(&c, &r)), 0.0);
}

#[test]
fn a_clip_zeroes_the_coverage_outside_it() {
    let shape = fill_path(
        &polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]),
        "nonzero",
        12,
        12,
    );
    let clip = clip_rect(2.0, 2.0, 6.0, 6.0, 12, 12);
    let clipped = multiply_coverage(&shape, &clip);
    assert!((coverage_at(&clipped, 4, 4) - 1.0).abs() < 0.0001);
    assert!((coverage_at(&clipped, 8, 8) - 0.0).abs() < 0.0001);
}
