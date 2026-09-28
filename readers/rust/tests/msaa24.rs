// features/chapter24-msaa.feature

use renderer::{fill_path, max_coverage_difference, msaa_coverage, point, sample_pattern, sliver};

#[test]
fn the_patterns() {
    assert_eq!(sample_pattern(16).len(), 16);
    assert_eq!(sample_pattern(16)[0], point(0.03125, 0.21875));
    assert_eq!(sample_pattern(16)[1], point(0.09375, 0.53125));
    assert_eq!(sample_pattern(4)[2], point(0.125, 0.625));
    assert_eq!(sample_pattern(64).len(), 64);
}

#[test]
fn more_samples_come_closer_to_chapter_7_and_how_theyre_placed_matters_as_much_as_how_many() {
    let p = sliver();
    let exact = fill_path(&p, "nonzero", 80, 40);
    assert!(renderer::approx_eq(max_coverage_difference(&msaa_coverage(&p, "nonzero", 80, 40, 1), &exact), 0.4875));
    assert!(renderer::approx_eq(max_coverage_difference(&msaa_coverage(&p, "nonzero", 80, 40, 4), &exact), 0.1125));
    assert!(renderer::approx_eq(max_coverage_difference(&msaa_coverage(&p, "nonzero", 80, 40, 16), &exact), 0.0375));
    assert!(renderer::approx_eq(max_coverage_difference(&msaa_coverage(&p, "nonzero", 80, 40, 64), &exact), 0.0375));
}
