// features/epilogue-glow.feature

use renderer::{approx_eq, book_cover_glow, canvas_to_p6, glow_of, max_channel_difference, ppm_pixel, read_file};

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
fn how_the_glow_falls_off() {
    assert!(approx_eq(glow_of(-3.0), 0.45));
    assert!(approx_eq(glow_of(0.0), 0.45));
    assert!(approx_eq(glow_of(5.0), 0.1125));
    assert!(approx_eq(glow_of(10.0), 0.0));
    assert!(approx_eq(glow_of(12.0), 0.0));
}

#[test]
fn at_chapter_23s_spread_of_4_the_clamp_would_glow_and_at_8_it_doesnt() {
    assert!(approx_eq(glow_of(4.0 * 44.0 / 32.0), 0.091125));
    assert!(approx_eq(glow_of(8.0 * 44.0 / 32.0), 0.0));
}

#[test]
fn the_glow_sits_around_the_titles_letters_and_nowhere_else() {
    let reference = read_file("reference/epilogue/cover-glow.ppm");
    let c = book_cover_glow();
    let p6 = canvas_to_p6(&c);
    assert_pixel_within(&p6, 44, 499, (243, 239, 230), 1);
    assert_pixel_within(&p6, 44, 494, (114, 67, 57), 1);
    assert_pixel_within(&p6, 35, 499, (93, 54, 55), 1);
    assert_pixel_within(&p6, 60, 540, (42, 21, 52), 1);
    assert_pixel_within(&p6, 56, 639, (255, 155, 82), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
