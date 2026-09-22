// features/chapter18-kerning.feature

use renderer::{approx_eq, approx_eq_eps, kern, layout_run, load_font, read_file, run_advance};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn the_fonts_kern_pairs_in_font_units() {
    let f = font();
    assert!(approx_eq(kern(&f, "T", "A"), -79.0));
    assert!(approx_eq(kern(&f, "A", "V"), -87.0));
    assert!(approx_eq(kern(&f, "A", "T"), -129.0));
    assert!(approx_eq(kern(&f, "V", "E"), 0.0));
    assert!(approx_eq(kern(&f, "H", "a"), 0.0));
    assert!(approx_eq(kern(&f, "space", "T"), -40.0));
}

#[test]
fn a_kerned_pair_is_narrower_than_the_unkerned_sum_by_exactly_the_kern() {
    let f = font();
    assert!(approx_eq_eps(run_advance(&f, "Wa", 11.0, false), 15.7427, 0.0001));
    assert!(approx_eq_eps(run_advance(&f, "Wa", 11.0, true), 15.5654, 0.0001));
    assert!(approx_eq(
        run_advance(&f, "Wa", 11.0, true),
        run_advance(&f, "Wa", 11.0, false) + kern(&f, "W", "a") * 11.0 / 2048.0
    ));
    assert!(approx_eq(run_advance(&f, "Ha", 11.0, true), run_advance(&f, "Ha", 11.0, false)));
}

#[test]
fn the_pen_moves_by_the_pair_before_the_second_glyph_is_placed() {
    let f = font();
    let kerned = layout_run(&f, "TAVERN", 64.0, 12.0, 70.0, true);
    let plain = layout_run(&f, "TAVERN", 64.0, 12.0, 70.0, false);
    assert!(approx_eq(kerned[0].x, 12.0));
    assert!(approx_eq_eps(kerned[1].x, 47.7188, 0.0001));
    assert!(approx_eq(kerned[1].x, plain[1].x + kern(&f, "T", "A") * 64.0 / 2048.0));
    assert!(approx_eq(kerned[2].x, 86.75));
    assert!(approx_eq_eps(kerned[3].x, 127.4688, 0.0001));
    assert!(approx_eq(kerned[5].x, 203.25));
    assert!(approx_eq(plain[5].x, 208.4375));
    assert!(approx_eq(run_advance(&f, "TAVERN", 64.0, true), 236.875));
    assert!(approx_eq(
        run_advance(&f, "TAVERN", 64.0, false) - run_advance(&f, "TAVERN", 64.0, true),
        5.1875
    ));
}
