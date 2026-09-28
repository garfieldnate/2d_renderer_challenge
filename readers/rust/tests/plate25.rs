// features/chapter25-plate.feature

use renderer::{brush_demo, canvas_to_p6, dither_strip, halo_demo, max_channel_difference, paint_by_script, plate_25, ppm_pixel, read_file};

fn check_render(render: impl Fn() -> renderer::Canvas, file: &str, w: usize, h: usize) {
    let c = render();
    let ref_ppm = read_file(file);
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, w, "width for {file}");
    assert_eq!(c.height, h, "height for {file}");
    assert!(max_channel_difference(&p6, &ref_ppm) <= 1, "render mismatch for {file}");
}

fn assert_pixel(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol && (actual.1 - expected.1).abs() <= tol && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} +/- {tol}, got {actual:?}"
    );
}

#[test]
fn each_render_matches_its_reference() {
    check_render(dither_strip, "reference/chapter-25/dither-strip.ppm", 256, 96);
    check_render(halo_demo, "reference/chapter-25/halo-demo.ppm", 640, 160);
    check_render(brush_demo, "reference/chapter-25/brush-demo.ppm", 400, 240);
    check_render(paint_by_script, "reference/chapter-25/paint-by-script.ppm", 480, 320);
}

#[test]
fn the_halo_and_the_two_controls_that_fight_over_it() {
    let p6 = canvas_to_p6(&halo_demo());
    assert_pixel(&p6, 72, 22, (177, 175, 172), 1);
    assert_pixel(&p6, 232, 22, (177, 175, 172), 1);
    assert_pixel(&p6, 392, 22, (153, 202, 212), 1);
    assert_pixel(&p6, 552, 22, (124, 225, 243), 1);
    assert_pixel(&p6, 80, 80, (124, 225, 243), 1);
}

#[test]
fn the_painting() {
    let p6 = canvas_to_p6(&paint_by_script());
    assert_pixel(&p6, 10, 300, (39, 89, 124), 1);
    assert_pixel(&p6, 370, 110, (247, 217, 145), 1);
}

#[test]
fn plate_25_test() {
    let c = plate_25();
    let ref_ppm = read_file("reference/chapter-25/plate-25.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 480);
    assert_eq!(c.height, 240);
    assert_pixel(&p6, 150, 120, (124, 225, 243), 1);
    assert_pixel(&p6, 236, 120, (246, 243, 234), 1);
    assert!(max_channel_difference(&p6, &ref_ppm) <= 1);
}
