// features/chapter17-lcd.feature

use renderer::color;
use renderer::{
    approx_eq, approx_eq_eps, canvas, colors_eq, coverage_at, fill, fill_path, glyph_path, ink,
    lcd_coverage, lcd_filter, load_font, paint_lcd, pixel_at, read_file, text_matrix, LCD_TAPS,
};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn the_filters_taps_sum_to_one_and_spread_a_spike_over_three_stripes() {
    assert!(approx_eq(LCD_TAPS.0, 0.333333));
    assert!(approx_eq(LCD_TAPS.1, 0.333333));
    assert!(approx_eq(LCD_TAPS.2, 0.333333));

    let out = lcd_filter(&[0.0, 0.0, 3.0, 0.0, 0.0]);
    assert_eq!(out.len(), 5);
    for (a, b) in out.iter().zip([0.0, 1.0, 1.0, 1.0, 0.0]) {
        assert!(approx_eq(*a, b));
    }

    let out2 = lcd_filter(&[1.0, 1.0, 1.0]);
    for (a, b) in out2.iter().zip([0.666667, 1.0, 0.666667]) {
        assert!(approx_eq(*a, b));
    }

    let out3 = lcd_filter(&[6.0]);
    assert!(approx_eq(out3[0], 2.0));

    assert_eq!(lcd_filter(&[]).len(), 0);
}

#[test]
fn three_coverages_per_pixel_carry_three_times_the_ink() {
    let f = font();
    let cov3 = lcd_coverage(&f, "l", 11.0, 4.0, 11.0, 10, 14);
    let gray = fill_path(&glyph_path(&f, "l", text_matrix(&f, 11.0, 4.0, 11.0), 0.1), "nonzero", 10, 14);

    assert_eq!(cov3.width, 30);
    assert_eq!(cov3.height, 14);
    assert!(approx_eq_eps(ink(&cov3), 24.592896, 0.0001));
    assert!(approx_eq_eps(ink(&gray), 8.197632, 0.0001));
    assert!(approx_eq_eps(coverage_at(&gray, 4, 5), 0.1621, 0.0001));
    assert!(approx_eq_eps(coverage_at(&gray, 5, 5), 0.8315, 0.0001));
    assert!(approx_eq_eps(coverage_at(&cov3, 13, 5), 0.1621, 0.0001));
    assert!(approx_eq_eps(coverage_at(&cov3, 14, 5), 0.4954, 0.0001));
    assert!(approx_eq_eps(coverage_at(&cov3, 15, 5), 0.8288, 0.0001));
    assert!(approx_eq_eps(coverage_at(&cov3, 16, 5), 0.8315, 0.0001));
    assert!(approx_eq_eps(coverage_at(&cov3, 17, 5), 0.4982, 0.0001));
    assert!(approx_eq_eps(coverage_at(&cov3, 18, 5), 0.1649, 0.0001));
    assert!(approx_eq(coverage_at(&cov3, 12, 5), 0.0));
}

#[test]
fn each_channel_takes_its_own_stripe() {
    let f = font();
    let mut c = canvas(10, 14);
    fill(&mut c, color(1.0, 1.0, 1.0));
    let cov3 = lcd_coverage(&f, "l", 11.0, 4.0, 11.0, 10, 14);
    paint_lcd(&mut c, &cov3, color(0.0, 0.0, 0.0));

    assert!(colors_eq(pixel_at(&c, 4, 5), color(1.0, 0.8379, 0.5046)));
    assert!(colors_eq(pixel_at(&c, 5, 5), color(0.1712, 0.1685, 0.5018)));
    assert!(colors_eq(pixel_at(&c, 6, 5), color(0.8351, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 8, 5), color(1.0, 1.0, 1.0)));
}
