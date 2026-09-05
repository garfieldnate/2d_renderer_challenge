// features/chapter02-twice.feature

use renderer::{
    canvas, canvas_to_p6, color, colors_eq, coverage_buffer, max_channel_difference,
    paint_through, painted_twice, pixel_at, ppm_pixel, read_file, set_coverage,
};

fn assert_pixel_within(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} ± {tol}, got {actual:?}"
    );
}

#[test]
fn half_coverage_painted_twice_is_three_quarters() {
    let mut c = canvas(1, 1);
    let mut cov = coverage_buffer(1, 1);
    set_coverage(&mut cov, 0, 0, 0.5);
    paint_through(&mut c, &cov, color(1.0, 1.0, 1.0));
    paint_through(&mut c, &cov, color(1.0, 1.0, 1.0));
    assert!(colors_eq(pixel_at(&c, 0, 0), color(0.75, 0.75, 0.75)));
}

#[test]
fn the_disc_once_and_twice() {
    let c = painted_twice();
    let reference = read_file("reference/chapter-02/painted-twice.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 480);
    assert_eq!(c.height, 240);
    assert_pixel_within(&p6, 120, 120, (243, 196, 89), 1);
    assert_pixel_within(&p6, 360, 120, (243, 196, 89), 1);
    assert_pixel_within(&p6, 93, 27, (157, 127, 64), 1);
    assert_pixel_within(&p6, 333, 27, (194, 156, 74), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
