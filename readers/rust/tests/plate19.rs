// features/chapter19-plate.feature

use renderer::{
    canvas_to_p6, forms_demo, ligature_demo, max_channel_difference, mixed_demo, plate_19,
    ppm_pixel, read_file, word_demo,
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
fn the_ligature_and_where_the_cursor_may_stand() {
    let c = ligature_demo();
    let reference = read_file("reference/chapter-19/ligature.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 260);
    assert_eq!(c.height, 100);
    assert_pixel_within(&p6, 106, 50, (237, 124, 196), 1);
    assert_pixel_within(&p6, 120, 50, (206, 206, 212), 1);
    assert_pixel_within(&p6, 56, 80, (124, 225, 243), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn one_letter_four_forms() {
    let c = forms_demo();
    let reference = read_file("reference/chapter-19/forms.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 110);
    assert_pixel_within(&p6, 50, 55, (206, 206, 212), 1);
    assert_pixel_within(&p6, 180, 55, (206, 206, 212), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn a_word_right_to_left_with_its_mark_attached() {
    let c = word_demo();
    let reference = read_file("reference/chapter-19/word.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 260);
    assert_eq!(c.height, 100);
    assert_pixel_within(&p6, 88, 50, (206, 206, 212), 1);
    assert_pixel_within(&p6, 133, 72, (237, 124, 196), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn two_scripts_on_one_line_and_the_comma_that_jumped() {
    let c = mixed_demo();
    let reference = read_file("reference/chapter-19/mixed.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 300);
    assert_eq!(c.height, 60);
    assert_pixel_within(&p6, 24, 30, (206, 206, 212), 1);
    assert_pixel_within(&p6, 155, 30, (206, 206, 212), 1);
    assert_pixel_within(&p6, 191, 30, (206, 206, 212), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_19_test() {
    let c = plate_19();
    let reference = read_file("reference/chapter-19/plate-19.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 540);
    assert_eq!(c.height, 210);
    assert_pixel_within(&p6, 24, 165, (206, 206, 212), 1);
    assert_pixel_within(&p6, 75, 165, (237, 124, 196), 1);
    assert_pixel_within(&p6, 296, 165, (206, 206, 212), 1);
    assert_pixel_within(&p6, 345, 165, (237, 124, 196), 1);
    assert_pixel_within(&p6, 5, 5, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
