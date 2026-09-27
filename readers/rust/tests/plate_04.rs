// features/chapter04-plate.feature

use renderer::{
    canvas_to_p6, fan_both_orders, fan_points, letter_f, max_channel_difference, point, plate_04,
    ppm_pixel, read_file, rotation, translation, transform_points, tuples_eq,
};

const PI: f64 = std::f64::consts::PI;

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
fn the_fan_as_points() {
    let pts = fan_points();
    assert_eq!(pts.len(), 13);
    assert!(tuples_eq(pts[0], point(0.0, 0.0)));
    assert!(tuples_eq(pts[1], point(36.0, 0.0)));
    assert!(tuples_eq(pts[4], point(0.0, 36.0)));
    assert!(tuples_eq(pts[7], point(-36.0, 0.0)));
    assert!(tuples_eq(pts[2], point(31.1769, 18.0)));
}

#[test]
fn rotate_then_translate_the_fan_turns_about_its_own_center() {
    let m = translation(104.5, 76.5) * rotation(PI / 6.0);
    let pts = transform_points(&fan_points(), m);
    assert!(tuples_eq(pts[0], point(104.5, 76.5)));
    assert!(tuples_eq(pts[1], point(135.6769, 94.5)));
    assert!(tuples_eq(pts[4], point(86.5, 107.6769)));
}

#[test]
fn translate_then_rotate_the_fan_swings_about_the_canvas_corner() {
    let m = rotation(PI / 6.0) * translation(104.5, 76.5);
    let pts = transform_points(&fan_points(), m);
    assert!(tuples_eq(pts[0], point(52.2497, 118.5009)));
    assert!(tuples_eq(pts[1], point(83.4266, 136.5009)));
}

#[test]
fn the_letter_f() {
    let f = letter_f();
    assert_eq!(f.len(), 10);
    assert!(tuples_eq(f[0], point(-20.0, -30.0)));
    assert!(tuples_eq(f[1], point(20.0, -30.0)));
    assert!(tuples_eq(f[5], point(12.0, -5.0)));
    assert!(tuples_eq(f[9], point(-20.0, 30.0)));
}

#[test]
fn the_f_at_home() {
    let f = transform_points(&letter_f(), translation(44.5, 44.5));
    assert!(tuples_eq(f[0], point(24.5, 14.5)));
    assert!(tuples_eq(f[1], point(64.5, 14.5)));
    assert!(tuples_eq(f[9], point(24.5, 74.5)));
}

#[test]
fn the_f_rotated_then_translated() {
    let m = translation(104.5, 76.5) * rotation(PI / 6.0);
    let f = transform_points(&letter_f(), m);
    assert!(tuples_eq(f[0], point(102.1795, 40.5192)));
    assert!(tuples_eq(f[1], point(136.8205, 60.5192)));
    assert!(tuples_eq(f[5], point(117.3923, 78.1699)));
    assert!(tuples_eq(f[9], point(72.1795, 92.4808)));
}

#[test]
fn the_f_translated_then_rotated() {
    let m = rotation(PI / 6.0) * translation(104.5, 76.5);
    let f = transform_points(&letter_f(), m);
    assert!(tuples_eq(f[0], point(49.9291, 82.5202)));
    assert!(tuples_eq(f[1], point(84.5702, 102.5202)));
    assert!(tuples_eq(f[5], point(65.142, 120.1708)));
    assert!(tuples_eq(f[9], point(19.9291, 134.4817)));
}

#[test]
fn the_fan_both_orders() {
    let c = fan_both_orders();
    let reference = read_file("reference/chapter-04/fan-both-orders.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 104, 76, (246, 246, 241), 1);
    assert_pixel_within(&p6, 124, 76, (246, 246, 241), 1);
    assert_pixel_within(&p6, 104, 56, (246, 246, 241), 1);
    assert_pixel_within(&p6, 125, 88, (236, 236, 231), 1);
    assert_pixel_within(&p6, 116, 97, (236, 236, 231), 1);
    assert_pixel_within(&p6, 141, 76, (39, 39, 44), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert_pixel_within(&p6, 212, 118, (246, 246, 241), 1);
    assert_pixel_within(&p6, 232, 118, (246, 246, 241), 1);
    assert_pixel_within(&p6, 233, 130, (223, 223, 219), 1);
    assert_pixel_within(&p6, 224, 139, (236, 236, 231), 1);
    assert_pixel_within(&p6, 200, 139, (211, 211, 207), 1);
    assert_pixel_within(&p6, 310, 10, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_4() {
    let c = plate_04();
    let reference = read_file("reference/chapter-04/plate-04.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 640);
    assert_eq!(c.height, 320);
    assert_pixel_within(&p6, 48, 28, (99, 99, 102), 1);
    assert_pixel_within(&p6, 80, 28, (111, 111, 115), 1);
    assert_pixel_within(&p6, 48, 100, (111, 111, 115), 1);
    assert_pixel_within(&p6, 10, 10, (39, 39, 44), 1);
    assert_pixel_within(&p6, 200, 150, (39, 39, 44), 1);
    assert_pixel_within(&p6, 268, 129, (237, 237, 233), 1);
    assert_pixel_within(&p6, 215, 145, (237, 237, 233), 1);
    assert_pixel_within(&p6, 239, 101, (237, 237, 233), 1);
    assert_pixel_within(&p6, 174, 173, (217, 217, 213), 1);
    assert_pixel_within(&p6, 368, 28, (99, 99, 102), 1);
    assert_pixel_within(&p6, 500, 60, (39, 39, 44), 1);
    assert_pixel_within(&p6, 453, 207, (236, 236, 231), 1);
    assert_pixel_within(&p6, 431, 229, (234, 234, 229), 1);
    assert_pixel_within(&p6, 445, 249, (234, 234, 229), 1);
    assert_pixel_within(&p6, 368, 273, (177, 177, 174), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn side_by_side_puts_the_first_canvas_on_the_left() {
    use renderer::{canvas, color, colors_eq, fill, pixel_at, side_by_side};
    let mut a = canvas(2, 3);
    let mut b = canvas(4, 3);
    fill(&mut a, color(1.0, 0.0, 0.0));
    fill(&mut b, color(0.0, 0.0, 1.0));
    let c = side_by_side(&a, &b);
    assert_eq!(c.width, 6);
    assert_eq!(c.height, 3);
    assert!(colors_eq(pixel_at(&c, 0, 0), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 1, 2), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 2, 0), color(0.0, 0.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 5, 2), color(0.0, 0.0, 1.0)));
}
