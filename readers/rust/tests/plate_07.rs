// features/chapter07-plate.feature

use renderer::{
    approx_eq, canvas_to_p6, fill_path, fill_path_aliased, ink, max_channel_difference,
    needle_path, needles, plate_07, polygon_area, ppm_pixel, read_file, soft_square,
    spiral_smooth, star_exact,
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
fn the_needles_aliased_against_exact() {
    let c = needles();
    let reference = read_file("reference/chapter-07/needles.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 480);
    assert_eq!(c.height, 240);
    assert!(approx_eq(ink(&fill_path_aliased(&needle_path(), "nonzero", 60, 60)), 268.0));
    assert!(approx_eq(
        ink(&fill_path(&needle_path(), "nonzero", 60, 60)),
        polygon_area(&needle_path())
    ));
    assert_pixel_within(&p6, 120, 120, (39, 39, 44), 1);
    assert_pixel_within(&p6, 360, 120, (94, 78, 51), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_soft_square() {
    let c = soft_square();
    let reference = read_file("reference/chapter-07/soft-square.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 192);
    assert_eq!(c.height, 192);
    assert_pixel_within(&p6, 96, 96, (243, 196, 89), 1);
    assert_pixel_within(&p6, 36, 36, (134, 109, 59), 1);
    assert_pixel_within(&p6, 12, 12, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_star_exact_both_rules() {
    let c = star_exact();
    let reference = read_file("reference/chapter-07/star-exact.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 80, 80, (243, 196, 89), 1);
    assert_pixel_within(&p6, 240, 80, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_spiral_smooth() {
    let c = spiral_smooth();
    let reference = read_file("reference/chapter-07/spiral-smooth.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 180, 160, (243, 196, 89), 1);
    assert_pixel_within(&p6, 160, 160, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_7() {
    let c = plate_07();
    let reference = read_file("reference/chapter-07/plate-07.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 480);
    assert_eq!(c.height, 480);
    assert_pixel_within(&p6, 240, 60, (243, 196, 89), 1);
    assert_pixel_within(&p6, 440, 240, (243, 196, 89), 1);
    assert_pixel_within(&p6, 439, 257, (124, 196, 237), 1);
    assert_pixel_within(&p6, 436, 274, (237, 137, 149), 1);
    assert_pixel_within(&p6, 229, 210, (246, 243, 234), 1);
    assert_pixel_within(&p6, 240, 240, (39, 39, 44), 1);
    assert_pixel_within(&p6, 20, 20, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
