// features/chapter17-plate.feature

use renderer::{
    approx_eq_eps, canvas, canvas_to_p6, color, colors_eq, draw_text, fill, lcd_plate, load_font,
    max_channel_difference, pen_advance, pixel_at, plate_17, ppm_pixel, read_file,
    smoothing_demo, subpixel_strip,
};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

fn assert_pixel_exact(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64)) {
    let actual = ppm_pixel(p6, x, y);
    assert_eq!(actual, expected, "pixel ({x},{y})");
}

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
fn the_pen_advance_in_pixels() {
    let f = font();
    assert!(approx_eq_eps(pen_advance(&f, "H", 11.0), 7.8418, 0.0001));
    assert!(approx_eq_eps(pen_advance(&f, "space", 11.0), 2.7231, 0.0001));
}

#[test]
fn draw_text_steps_the_pen_by_each_advance_and_answers_where_it_stopped() {
    let f = font();
    let mut c = canvas(30, 14);
    fill(&mut c, color(1.0, 1.0, 1.0));
    let pen = draw_text(&mut c, &f, "Ha", 11.0, 2.0, 11.0, color(0.0, 0.0, 0.0), true);

    assert!(approx_eq_eps(pen, 15.8252, 0.0001));
    assert!(approx_eq_eps(
        pen,
        2.0 + pen_advance(&f, "H", 11.0) + pen_advance(&f, "a", 11.0),
        0.0001
    ));
    assert!(colors_eq(pixel_at(&c, 3, 6), color(0.0331, 0.0331, 0.0331)));
    assert!(colors_eq(pixel_at(&c, 29, 6), color(1.0, 1.0, 1.0)));
}

#[test]
fn the_same_stem_at_four_quarters() {
    let c = subpixel_strip();
    let reference = read_file("reference/chapter-17/subpixels.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 112);
    assert_pixel_within(&p6, 40, 60, (114, 114, 114), 1);
    assert_pixel_within(&p6, 120, 60, (84, 84, 84), 1);
    assert_pixel_within(&p6, 280, 60, (202, 202, 202), 1);
    assert_pixel_exact(&p6, 10, 10, (255, 255, 255));
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn three_ways_to_smooth() {
    let c = smoothing_demo();
    let reference = read_file("reference/chapter-17/smoothing.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 288);
    assert_eq!(c.height, 168);
    assert_pixel_within(&p6, 150, 20, (250, 250, 250), 1);
    assert_pixel_within(&p6, 150, 76, (243, 243, 243), 1);
    assert_pixel_within(&p6, 150, 132, (174, 174, 174), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn grayscale_above_stripes_below() {
    let c = lcd_plate();
    let reference = read_file("reference/chapter-17/lcd.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 144);
    assert_eq!(c.height, 192);
    assert_pixel_within(&p6, 60, 40, (46, 46, 46), 1);
    assert_pixel_within(&p6, 60, 136, (123, 51, 126), 1);
    assert_pixel_exact(&p6, 5, 5, (255, 255, 255));
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_17_test() {
    let c = plate_17();
    let reference = read_file("reference/chapter-17/plate-17.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 288);
    assert_eq!(c.height, 384);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
