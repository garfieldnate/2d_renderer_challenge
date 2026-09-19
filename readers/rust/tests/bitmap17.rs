// features/chapter17-bitmap.feature

use renderer::{
    approx_eq, approx_eq_eps, canvas, colors_eq, coverage_at, fill, glyph_bitmap, ink, load_font,
    paint_bitmap, pixel_at, read_file, subpixel_of,
};
use renderer::color;

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn a_pen_position_rounds_to_the_nearest_quarter_pixel() {
    assert_eq!(subpixel_of(10.0), (10, 0));
    assert_eq!(subpixel_of(10.1), (10, 0));
    assert_eq!(subpixel_of(10.3), (10, 1));
    assert_eq!(subpixel_of(10.5), (10, 2));
    assert_eq!(subpixel_of(10.62), (10, 2));
    assert_eq!(subpixel_of(10.9), (11, 0));
    assert_eq!(subpixel_of(-0.3), (-1, 3));
}

#[test]
fn a_bitmap_is_just_big_enough_and_knows_where_it_sits() {
    let f = font();
    let b = glyph_bitmap(&f, "l", 11.0, 0);
    assert_eq!(b.width, 2);
    assert_eq!(b.height, 9);
    assert_eq!(b.left, 0);
    assert_eq!(b.top, -9);
    assert!(approx_eq_eps(coverage_at(&b.coverage, 0, 5), 0.1621, 0.0001));
    assert!(approx_eq_eps(coverage_at(&b.coverage, 1, 5), 0.8315, 0.0001));
    assert_eq!(glyph_bitmap(&f, "g", 11.0, 0).top, -6);
    assert_eq!(glyph_bitmap(&f, "g", 11.0, 0).height, 9);
    assert_eq!(glyph_bitmap(&f, "space", 11.0, 0).width, 0);
}

#[test]
fn a_quarter_to_the_right_moves_the_ink_not_the_amount_of_it() {
    let f = font();
    let b1 = glyph_bitmap(&f, "l", 11.0, 1);
    let b3 = glyph_bitmap(&f, "l", 11.0, 3);
    assert_eq!(b1.left, 1);
    assert!(approx_eq_eps(coverage_at(&b1.coverage, 0, 5), 0.9121, 0.0001));
    assert!(approx_eq_eps(coverage_at(&b1.coverage, 1, 5), 0.0815, 0.0001));
    assert!(approx_eq_eps(coverage_at(&b3.coverage, 0, 5), 0.4121, 0.0001));
    assert!(approx_eq_eps(coverage_at(&b3.coverage, 1, 5), 0.5815, 0.0001));
    assert!(approx_eq(ink(&b1.coverage), ink(&glyph_bitmap(&f, "l", 11.0, 0).coverage)));
    assert!(approx_eq_eps(ink(&b3.coverage), 8.197632, 0.0001));
    assert!(approx_eq(
        ink(&glyph_bitmap(&f, "H", 11.0, 1).coverage),
        ink(&glyph_bitmap(&f, "H", 11.0, 0).coverage)
    ));
}

#[test]
fn painting_a_bitmap_lands_it_at_the_pen() {
    let f = font();
    let mut c = canvas(10, 14);
    fill(&mut c, color(1.0, 1.0, 1.0));
    let b = glyph_bitmap(&f, "l", 11.0, 0);
    paint_bitmap(&mut c, &b, 4, 11, color(0.0, 0.0, 0.0), true);
    assert!(colors_eq(pixel_at(&c, 5, 6), color(0.1685, 0.1685, 0.1685)));
    assert!(colors_eq(pixel_at(&c, 4, 6), color(0.8379, 0.8379, 0.8379)));
    assert!(colors_eq(pixel_at(&c, 6, 6), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 5, 11), color(1.0, 1.0, 1.0)));
}
