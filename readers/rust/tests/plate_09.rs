// features/chapter09-plate.feature

use renderer::{
    blend_strip, canvas_to_p6, color, composite, from_color, max_channel_difference, opaque, pixel, pixels_eq,
    plate_09, porter_duff_table, ppm_pixel, read_file, seam,
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
fn the_porter_duff_table_places_each_operator() {
    let c = porter_duff_table();
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 256);
    assert_eq!(c.height, 192);
    assert_pixel_within(&p6, 20, 20, (39, 39, 44), 1);
    assert_pixel_within(&p6, 102, 38, (249, 196, 89), 1);
    assert_pixel_within(&p6, 148, 20, (124, 188, 237), 1);
    assert_pixel_within(&p6, 232, 38, (249, 196, 89), 1);
    assert_pixel_within(&p6, 40, 102, (124, 188, 237), 1);
    assert_pixel_within(&p6, 79, 79, (39, 39, 44), 1);
    assert_pixel_within(&p6, 102, 96, (249, 196, 89), 1);
    assert_pixel_within(&p6, 230, 160, (39, 39, 44), 1);
}

#[test]
fn the_conflation_seam_is_0_75_not_1_0() {
    let half = from_color(color(1.0, 1.0, 1.0), 0.5);
    let black = opaque(color(0.0, 0.0, 0.0));
    let once = composite("src-over", half, black);
    let twice = composite("src-over", half, once);
    assert!(pixels_eq(once, pixel(0.5, 0.5, 0.5, 1.0)));
    assert!(pixels_eq(twice, pixel(0.75, 0.75, 0.75, 1.0)));
}

#[test]
fn the_seam_shows_in_the_render() {
    let c = seam();
    let reference = read_file("reference/chapter-09/seam.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 40, 160, (249, 196, 89), 1);
    assert_pixel_within(&p6, 160, 160, (220, 173, 81), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_9() {
    let c = plate_09();
    let reference = read_file("reference/chapter-09/plate-09.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 512);
    assert_eq!(c.height, 384);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_blend_mode_strip() {
    let c = blend_strip();
    let reference = read_file("reference/chapter-09/blend-modes.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 256);
    assert_eq!(c.height, 256);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
