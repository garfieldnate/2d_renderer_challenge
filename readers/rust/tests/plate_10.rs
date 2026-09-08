// features/chapter10-plate.feature

use renderer::{
    canvas, canvas_to_p6, color, extend_strip, fill, fill_path, max_channel_difference, paint_fill,
    paint_through, pixel_at, plate_10, point, polygon, ppm_pixel, radial_t, read_file, solid, stop,
    three_gradients,
};

#[test]
fn a_solid_paint_fills_exactly_like_paint_through() {
    let box_ = polygon(&[point(1.0, 1.0), point(6.0, 1.0), point(6.0, 6.0), point(1.0, 6.0)]);
    let cov = fill_path(&box_, "nonzero", 8, 8);
    let mut a = canvas(8, 8);
    let mut b = canvas(8, 8);
    fill(&mut a, color(0.02, 0.02, 0.025));
    fill(&mut b, color(0.02, 0.02, 0.025));
    paint_fill(&mut a, &cov, &solid(color(0.9, 0.5, 0.2)));
    paint_through(&mut b, &cov, color(0.9, 0.5, 0.2));
    assert!(renderer::colors_eq(pixel_at(&a, 3, 3), pixel_at(&b, 3, 3)));
    assert!(renderer::colors_eq(pixel_at(&a, 1, 1), pixel_at(&b, 1, 1)));
}

#[test]
fn an_unreachable_focal_pixel_takes_the_last_stop_not_black() {
    let g = renderer::radial_gradient(
        point(100.0, 50.0),
        0.0,
        point(50.0, 50.0),
        20.0,
        vec![stop(0.0, color(0.0, 0.0, 0.0)), stop(1.0, color(1.0, 1.0, 1.0))],
        "pad",
    );
    assert!(radial_t(&g, 110.0, 50.0).is_none());
    assert!(renderer::colors_eq(renderer::paint_at(&g, 110.0, 50.0), color(1.0, 1.0, 1.0)));
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
fn the_three_gradients() {
    let c = three_gradients();
    let reference = read_file("reference/chapter-10/three-gradients.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 458);
    assert_eq!(c.height, 150);
    assert_pixel_within(&p6, 10, 10, (68, 40, 108), 1);
    assert_pixel_within(&p6, 140, 140, (255, 249, 225), 1);
    assert_pixel_within(&p6, 209, 55, (71, 41, 109), 1);
    assert_pixel_within(&p6, 383, 20, (65, 39, 108), 1);
    assert_pixel_within(&p6, 438, 75, (196, 95, 130), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn the_extend_strip() {
    let c = extend_strip();
    let reference = read_file("reference/chapter-10/extend-modes.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 360);
    assert_eq!(c.height, 180);
    assert_pixel_within(&p6, 20, 30, (89, 108, 188), 1);
    assert_pixel_within(&p6, 340, 30, (255, 218, 89), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_10_test() {
    let c = plate_10();
    let reference = read_file("reference/chapter-10/plate-10.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 458);
    assert_eq!(c.height, 150);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
