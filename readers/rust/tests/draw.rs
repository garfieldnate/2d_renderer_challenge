// features/chapter04-drawing.feature

use renderer::{
    approx_eq, approx_scale, canvas, circle, color, colors_eq, coverage_at, identity, ink, inside,
    lit_pixels, outline, paint_through, pixel_at, point, rasterize, rectangle, scaling, segment,
    thick_line, total_ink, translation, transformed, union,
};

#[test]
fn a_segment_between_pixel_centers_is_a_thick_line() {
    let s = segment(point(2.5, 2.5), point(11.5, 5.5), 1.0);
    let cov = rasterize(&s, 16, 10);
    assert!(approx_eq(coverage_at(&cov, 2, 2), 0.484375));
    assert!(approx_eq(coverage_at(&cov, 6, 3), 0.6875));
    assert!(approx_eq(coverage_at(&cov, 7, 3), 0.359375));
    assert!(approx_eq(ink(&cov), 9.4063));
}

#[test]
fn a_segment_need_not_start_on_a_pixel_center() {
    let s = segment(point(1.0, 3.5), point(7.0, 3.5), 1.0);
    let cov = rasterize(&s, 10, 10);
    assert!(approx_eq(coverage_at(&cov, 0, 3), 0.0));
    assert!(approx_eq(coverage_at(&cov, 1, 3), 1.0));
    assert!(approx_eq(coverage_at(&cov, 6, 3), 1.0));
    assert!(approx_eq(coverage_at(&cov, 7, 3), 0.0));
    assert!(approx_eq(coverage_at(&cov, 3, 2), 0.0));
    assert!(approx_eq(ink(&cov), 6.0));
}

#[test]
fn a_segment_of_no_length_is_a_square() {
    let s = segment(point(3.5, 3.5), point(3.5, 3.5), 1.0);
    let cov = rasterize(&s, 8, 8);
    assert!(approx_eq(coverage_at(&cov, 3, 3), 1.0));
    assert!(approx_eq(ink(&cov), 1.0));
}

#[test]
fn a_union_is_inside_when_any_of_its_parts_is() {
    let s = union(vec![circle(2.0, 2.0, 1.0), rectangle(5.0, 0.0, 7.0, 4.0)]);
    assert!(inside(&s, 2.0, 2.0));
    assert!(inside(&s, 6.0, 1.0));
    assert!(!inside(&s, 4.0, 2.0));
    assert!(approx_eq(ink(&rasterize(&s, 8, 8)), 11.25));
}

#[test]
fn a_circle_seen_through_a_scale_is_an_ellipse() {
    let s = transformed(circle(0.0, 0.0, 4.0), scaling(2.0, 1.0));
    assert!(inside(&s, 7.9, 0.0));
    assert!(!inside(&s, 8.1, 0.0));
    assert!(inside(&s, 0.0, 3.9));
    assert!(!inside(&s, 0.0, 4.1));
    assert!(inside(&s, 5.6, 1.4));
    assert!(!inside(&s, 5.6, 2.9));
}

#[test]
fn the_transform_is_applied_in_the_order_the_matrix_says() {
    let s = transformed(circle(0.0, 0.0, 4.0), translation(10.0, 10.0) * scaling(2.0, 1.0));
    assert!(inside(&s, 10.0, 10.0));
    assert!(inside(&s, 17.9, 10.0));
    assert!(!inside(&s, 18.1, 10.0));
    assert!(inside(&s, 10.0, 13.9));
    assert!(!inside(&s, 10.0, 14.1));
}

#[test]
fn a_shape_seen_through_a_collapsed_transform_is_empty() {
    let s = transformed(circle(0.0, 0.0, 4.0), scaling(0.0, 1.0));
    assert!(!inside(&s, 0.0, 0.0));
    assert!(approx_eq(ink(&rasterize(&s, 10, 10)), 0.0));
}

#[test]
fn a_pen_in_shape_space_scales_with_the_shape() {
    let s = transformed(thick_line(5, 0, 5, 9, 1.0), scaling(3.0, 1.0));
    let cov = rasterize(&s, 24, 10);
    assert!(approx_eq(coverage_at(&cov, 14, 4), 0.0));
    assert!(approx_eq(coverage_at(&cov, 15, 4), 1.0));
    assert!(approx_eq(coverage_at(&cov, 16, 4), 1.0));
    assert!(approx_eq(coverage_at(&cov, 17, 4), 1.0));
    assert!(approx_eq(coverage_at(&cov, 18, 4), 0.0));
    assert!(approx_eq(ink(&cov), 27.0));
}

#[test]
fn a_pen_in_device_space_does_not() {
    let m = scaling(3.0, 1.0);
    let s = segment(m * point(5.5, 0.5), m * point(5.5, 9.5), 1.0);
    let cov = rasterize(&s, 24, 10);
    assert!(approx_eq(coverage_at(&cov, 15, 4), 0.0));
    assert!(approx_eq(coverage_at(&cov, 16, 4), 1.0));
    assert!(approx_eq(coverage_at(&cov, 17, 4), 0.0));
    assert!(approx_eq(ink(&cov), 9.0));
}

#[test]
fn dividing_the_width_by_approx_scale_makes_the_two_pens_agree() {
    let m = scaling(2.0, 2.0);
    let s = transformed(segment(point(5.5, 0.5), point(5.5, 9.5), 1.0 / approx_scale(m)), m);
    let cov = rasterize(&s, 24, 20);
    assert!(approx_eq(coverage_at(&cov, 9, 5), 0.0));
    assert!(approx_eq(coverage_at(&cov, 10, 5), 0.5));
    assert!(approx_eq(coverage_at(&cov, 11, 5), 0.5));
    assert!(approx_eq(coverage_at(&cov, 12, 5), 0.0));
    assert!(approx_eq(ink(&cov), 18.0));
}

#[test]
fn under_a_non_uniform_scale_the_compromise_shows() {
    let m = scaling(4.0, 1.0);
    let w = 1.0 / approx_scale(m);
    let v = transformed(segment(point(2.5, 0.5), point(2.5, 9.5), w), m);
    let h = transformed(segment(point(0.5, 5.5), point(4.5, 5.5), w), m);
    let cv = rasterize(&v, 24, 12);
    let ch = rasterize(&h, 24, 12);

    assert!(approx_eq(coverage_at(&cv, 8, 5), 0.0));
    assert!(approx_eq(coverage_at(&cv, 9, 5), 1.0));
    assert!(approx_eq(coverage_at(&cv, 10, 5), 1.0));
    assert!(approx_eq(coverage_at(&cv, 11, 5), 0.0));
    assert!(approx_eq(ink(&cv), 18.0));

    assert!(approx_eq(coverage_at(&ch, 10, 4), 0.0));
    assert!(approx_eq(coverage_at(&ch, 10, 5), 0.5));
    assert!(approx_eq(coverage_at(&ch, 10, 6), 0.0));
    assert!(approx_eq(ink(&ch), 8.0));
}

#[test]
fn an_outline_is_one_shape_so_its_corners_are_painted_once() {
    let pts = vec![point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)];
    let mut c = canvas(8, 8);
    let cov = rasterize(&outline(&pts, identity(), 1.0), 8, 8);
    paint_through(&mut c, &cov, color(1.0, 1.0, 1.0));

    assert_eq!(lit_pixels(&c).len(), 20);
    assert!(colors_eq(pixel_at(&c, 3, 1), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 1, 3), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 1, 1), color(0.75, 0.75, 0.75)));
    assert!(colors_eq(pixel_at(&c, 3, 3), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 0, 1), color(0.0, 0.0, 0.0)));
    assert!(approx_eq(total_ink(&c), 19.0));
}

#[test]
fn an_outline_takes_its_points_through_the_matrix_first() {
    let pts = vec![point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)];
    let mut c = canvas(16, 16);
    let cov = rasterize(&outline(&pts, scaling(2.0, 2.0), 1.0), 16, 16);
    paint_through(&mut c, &cov, color(1.0, 1.0, 1.0));

    assert_eq!(lit_pixels(&c).len(), 76);
    assert!(colors_eq(pixel_at(&c, 3, 3), color(0.75, 0.75, 0.75)));
    assert!(colors_eq(pixel_at(&c, 8, 2), color(0.5, 0.5, 0.5)));
    assert!(colors_eq(pixel_at(&c, 8, 3), color(0.5, 0.5, 0.5)));
    assert!(colors_eq(pixel_at(&c, 8, 4), color(0.0, 0.0, 0.0)));
}
