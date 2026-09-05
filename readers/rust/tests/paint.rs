// features/chapter02-paint.feature

use renderer::{
    canvas, canvas_to_p6, canvas_to_ppm, color, colors_eq, coverage_buffer, disc_centers, fill,
    distinct_values, max_channel_difference, paint_through, pixel_at, ppm_pixel, read_file,
    set_coverage,
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
fn half_coverage_is_half_the_paint() {
    let mut c = canvas(1, 1);
    let mut cov = coverage_buffer(1, 1);
    set_coverage(&mut cov, 0, 0, 0.5);
    paint_through(&mut c, &cov, color(1.0, 1.0, 1.0));
    assert!(colors_eq(pixel_at(&c, 0, 0), color(0.5, 0.5, 0.5)));
}

#[test]
fn paint_over_something_that_isnt_black() {
    let mut c = canvas(1, 1);
    let mut cov = coverage_buffer(1, 1);
    fill(&mut c, color(0.2, 0.2, 0.2));
    set_coverage(&mut cov, 0, 0, 0.25);
    paint_through(&mut c, &cov, color(1.0, 0.0, 0.0));
    assert!(colors_eq(pixel_at(&c, 0, 0), color(0.4, 0.15, 0.15)));
}

#[test]
fn zero_leaves_it_alone_and_one_replaces_it() {
    let mut c = canvas(2, 1);
    let mut cov = coverage_buffer(2, 1);
    fill(&mut c, color(0.2, 0.2, 0.2));
    set_coverage(&mut cov, 1, 0, 1.0);
    paint_through(&mut c, &cov, color(1.0, 0.0, 0.0));
    assert!(colors_eq(pixel_at(&c, 0, 0), color(0.2, 0.2, 0.2)));
    assert!(colors_eq(pixel_at(&c, 1, 0), color(1.0, 0.0, 0.0)));
}

#[test]
fn the_arithmetic_is_on_light() {
    let mut c = canvas(1, 1);
    let mut cov = coverage_buffer(1, 1);
    set_coverage(&mut cov, 0, 0, 0.5);
    paint_through(&mut c, &cov, color(1.0, 1.0, 1.0));
    let ppm = canvas_to_ppm(&c);
    assert_eq!(ppm_pixel(&ppm, 0, 0), (188, 188, 188));
}

#[test]
fn the_disc_by_centers() {
    let c = disc_centers();
    let reference = read_file("reference/chapter-02/disc-centers.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 160, 160, (243, 196, 89), 1);
    assert_pixel_within(&p6, 124, 36, (39, 39, 44), 1);
    assert_pixel_within(&p6, 132, 36, (243, 196, 89), 1);
    assert_eq!(distinct_values(&p6), 5);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
