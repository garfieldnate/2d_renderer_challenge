// features/chapter16-font.feature

use renderer::{approx_eq, glyph_advance, glyph_count, glyph_name, load_font, read_file};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn the_fonts_vertical_metrics() {
    let f = font();
    assert!(approx_eq(f.units_per_em, 2048.0));
    assert!(approx_eq(f.ascender, 1900.0));
    assert!(approx_eq(f.descender, -500.0));
    assert!(approx_eq(f.line_gap, 0.0));
    assert_eq!(glyph_count(&f), 177);
}

#[test]
fn characters_map_to_glyph_names_and_a_missing_one_maps_to_notdef() {
    let f = font();
    assert_eq!(glyph_name(&f, 65), "A");
    assert_eq!(glyph_name(&f, 233), "eacute");
    assert_eq!(glyph_name(&f, 64257), "f_i");
    assert_eq!(glyph_name(&f, 9731), ".notdef");
}

#[test]
fn advances_are_in_font_units() {
    let f = font();
    assert!(approx_eq(glyph_advance(&f, "A"), 1336.0));
    assert!(approx_eq(glyph_advance(&f, "space"), 507.0));
    assert!(approx_eq(glyph_advance(&f, ".notdef"), 908.0));
    assert!(approx_eq(glyph_advance(&f, "i"), 497.0));
}

#[test]
fn a_glyph_is_contours_of_flagged_points() {
    let f = font();
    let g = &f.glyphs["i"];
    assert_eq!(g.contours.len(), 2);
    assert_eq!(g.contours[0].len(), 4);
    assert_eq!(g.contours[0][0], (341.0, 0.0, true));
    assert_eq!(g.contours[1].len(), 9);
    assert_eq!(g.contours[1][1], (141.0, 1414.0, false));
    assert_eq!(g.components.len(), 0);
}
