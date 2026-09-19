// features/chapter17-fudge.feature

use renderer::color;
use renderer::{
    approx_eq_eps, canvas, colors_eq, coverage_at, embolden, fill, glyph_bitmap, ink, load_font,
    paint_bitmap, pixel_at, read_file,
};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn encoded_space_blending_is_darker_at_the_same_coverage() {
    let f = font();
    let mut a = canvas(10, 14);
    let mut b = canvas(10, 14);
    fill(&mut a, color(1.0, 1.0, 1.0));
    fill(&mut b, color(1.0, 1.0, 1.0));
    let bm = glyph_bitmap(&f, "l", 11.0, 0);
    paint_bitmap(&mut a, &bm, 4, 11, color(0.0, 0.0, 0.0), true);
    paint_bitmap(&mut b, &bm, 4, 11, color(0.0, 0.0, 0.0), false);

    assert!(colors_eq(pixel_at(&a, 4, 6), color(0.8379, 0.8379, 0.8379)));
    assert!(colors_eq(pixel_at(&b, 4, 6), color(0.6701, 0.6701, 0.6701)));
    assert!(colors_eq(pixel_at(&a, 5, 6), color(0.1685, 0.1685, 0.1685)));
    assert!(colors_eq(pixel_at(&b, 5, 6), color(0.0241, 0.0241, 0.0241)));
}

#[test]
fn emboldening_adds_ink_and_grows_the_bitmap_by_a_pixel_all_round() {
    let f = font();
    let plain = glyph_bitmap(&f, "l", 11.0, 0);
    let bold = embolden(&f, "l", 11.0, 0.333333);
    assert_eq!(bold.width, 4);
    assert_eq!(bold.height, 11);
    assert_eq!(bold.left, -1);
    assert_eq!(bold.top, -10);
    assert!(approx_eq_eps(ink(&plain.coverage), 8.197632, 0.0001));
    assert!(approx_eq_eps(ink(&bold.coverage), 12.9527, 0.001));
    assert!(approx_eq_eps(coverage_at(&bold.coverage, 2, 6), 1.0, 0.0001));
    assert!(approx_eq_eps(coverage_at(&bold.coverage, 1, 6), 0.4909, 0.001));
    assert!(approx_eq_eps(coverage_at(&bold.coverage, 0, 6), 0.0, 0.0001));
}

#[test]
fn more_emboldening_more_ink() {
    let f = font();
    assert!(approx_eq_eps(ink(&embolden(&f, "o", 11.0, 0.5).coverage), 25.300, 0.01));
    assert!(approx_eq_eps(ink(&glyph_bitmap(&f, "o", 11.0, 0).coverage), 14.041, 0.01));
    assert!(
        ink(&embolden(&f, "o", 11.0, 0.5).coverage) >= ink(&embolden(&f, "o", 11.0, 0.25).coverage)
    );
}
