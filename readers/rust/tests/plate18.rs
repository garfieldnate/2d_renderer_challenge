// features/chapter18-plate.feature

use renderer::{
    approx_eq_eps, canvas, canvas_to_p6, color, colors_eq, draw_run, draw_text, break_demo,
    drift_demo, fill, kern_demo, layout_run, load_font, max_channel_difference, pen_advance,
    pixel_at, plate_18, ppm_pixel, read_file, run_advance, subpixel_of,
};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
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

fn assert_pixel_exact(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64)) {
    assert_eq!(ppm_pixel(p6, x, y), expected, "pixel ({x},{y})");
}

#[test]
fn a_run_at_whole_pixels_draws_what_chapter_17_drew() {
    let f = font();
    let mut a = canvas(30, 14);
    let mut b = canvas(30, 14);
    fill(&mut a, color(1.0, 1.0, 1.0));
    fill(&mut b, color(1.0, 1.0, 1.0));

    let run = layout_run(&f, "Ha", 11.0, 2.0, 11.0, false);
    draw_run(&mut a, &f, &run, 11.0, color(0.0, 0.0, 0.0), true);
    let _pen = draw_text(&mut b, &f, "Ha", 11.0, 2.0, 11.0, color(0.0, 0.0, 0.0), true);

    assert_eq!(max_channel_difference(canvas_to_p6(&a), canvas_to_p6(&b)), 0);
    assert!(colors_eq(pixel_at(&a, 3, 6), color(0.0331, 0.0331, 0.0331)));
}

#[test]
fn the_baseline_rounds_to_a_pixel_row_halves_up() {
    let f = font();
    let mut a = canvas(30, 14);
    let mut b = canvas(30, 14);
    fill(&mut a, color(1.0, 1.0, 1.0));
    fill(&mut b, color(1.0, 1.0, 1.0));

    let run_a = layout_run(&f, "Ha", 11.0, 2.4, 11.5, false);
    let run_b = layout_run(&f, "Ha", 11.0, 2.4, 11.4, false);
    draw_run(&mut a, &f, &run_a, 11.0, color(0.0, 0.0, 0.0), true);
    draw_run(&mut b, &f, &run_b, 11.0, color(0.0, 0.0, 0.0), true);

    assert_eq!(subpixel_of(2.4), (2, 2));
    assert!(colors_eq(pixel_at(&a, 3, 11), color(0.4077, 0.4077, 0.4077)));
    assert!(colors_eq(pixel_at(&a, 3, 12), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&b, 3, 11), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&b, 3, 10), color(0.4077, 0.4077, 0.4077)));
}

#[test]
fn the_kern_pair_the_font_asks_for() {
    let c = kern_demo();
    let reference = read_file("reference/chapter-18/kerning.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 190);
    assert_pixel_within(&p6, 135, 40, (206, 206, 212), 1);
    assert_pixel_within(&p6, 135, 130, (39, 39, 44), 1);
    assert_pixel_within(&p6, 141, 130, (206, 206, 212), 1);
    assert_pixel_within(&p6, 141, 40, (39, 39, 44), 1);
    assert_pixel_within(&p6, 251, 180, (176, 93, 146), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn greedy_breaking_inside_a_measure() {
    let c = break_demo();
    let reference = read_file("reference/chapter-18/breaking.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 340);
    assert_eq!(c.height, 150);
    assert_pixel_within(&p6, 20, 60, (93, 167, 181), 1);
    assert_pixel_within(&p6, 31, 28, (206, 206, 212), 1);
    assert_pixel_within(&p6, 200, 140, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn a_rounded_pen_drifts() {
    let f = font();
    let c = drift_demo();
    let reference = read_file("reference/chapter-18/drift.ppm");
    let p6 = canvas_to_p6(&c);

    assert!(approx_eq_eps(pen_advance(&f, "i", 11.0), 2.6694, 0.0001));
    assert!(approx_eq_eps(
        20.0 * (renderer::round(pen_advance(&f, "i", 11.0)) as f64)
            - run_advance(&f, "iiiiiiiiiiiiiiiiiiii", 11.0, false),
        6.6113,
        0.0001
    ));
    assert_eq!(c.width, 780);
    assert_eq!(c.height, 132);
    assert_pixel_within(&p6, 571, 30, (124, 225, 243), 1);
    assert_pixel_within(&p6, 616, 90, (237, 124, 196), 1);
    assert_pixel_within(&p6, 600, 120, (237, 124, 196), 1);
    assert_pixel_exact(&p6, 600, 60, (255, 255, 255));
    assert_pixel_within(&p6, 21, 40, (114, 114, 114), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_18_test() {
    let c = plate_18();
    let reference = read_file("reference/chapter-18/plate-18.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 660);
    assert_eq!(c.height, 236);
    assert_pixel_within(&p6, 340, 130, (72, 124, 135), 1);
    assert_pixel_within(&p6, 24, 20, (55, 55, 59), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
