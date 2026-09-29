// features/epilogue-document.feature

use renderer::{canvas_to_p6, max_channel_difference, ppm_pixel, read_file, render_svg};

fn assert_pixel_within(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} ± {tol}, got {actual:?}"
    );
}

fn cover_svg() -> String {
    String::from_utf8(read_file("reference/epilogue/cover.svg")).unwrap()
}

#[test]
fn the_document_drawn_by_chapter_20_and_nothing_else() {
    let reference = read_file("reference/epilogue/cover-art.ppm");
    let c = render_svg(&cover_svg(), 480, 680);
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 480);
    assert_eq!(c.height, 680);
    assert_pixel_within(&p6, 240, 8, (21, 19, 42), 1);
    assert_pixel_within(&p6, 240, 670, (46, 22, 54), 1);
    assert_pixel_within(&p6, 60, 60, (207, 121, 77), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_clip_rounds_the_panels_corner_and_the_rule_is_dashed() {
    let p6 = canvas_to_p6(&render_svg(&cover_svg(), 480, 680));
    assert_pixel_within(&p6, 41, 41, (23, 19, 43), 1);
    assert_pixel_within(&p6, 47, 472, (255, 154, 82), 1);
    assert_pixel_within(&p6, 58, 472, (40, 21, 51), 1);
}

#[test]
fn the_crop_marks_are_one_group_so_where_two_arms_cross_is_no_brighter_than_one_arm() {
    let p6 = canvas_to_p6(&render_svg(&cover_svg(), 480, 680));
    assert_pixel_within(&p6, 24, 24, (180, 176, 171), 1);
    assert_pixel_within(&p6, 24, 20, (180, 176, 171), 1);
    assert_pixel_within(&p6, 20, 24, (180, 176, 171), 1);
    assert_pixel_within(&p6, 23, 20, (22, 19, 42), 1);
}
