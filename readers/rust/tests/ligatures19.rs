// features/chapter19-ligatures.feature

use renderer::{apply_ligatures, clusters, glyph_advance, glyph_buffer, load_font, read_file};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

const TOY_JSON: &str = r#"{"units_per_em": 1000, "ascender": 800, "descender": -200, "line_gap": 0, "cmap": {"97": "a", "98": "b", "99": "c", "42": "dot"}, "glyphs": {".notdef": {"advance": 500, "contours": [], "components": []}, "a": {"advance": 600, "contours": [], "components": []}, "b": {"advance": 600, "contours": [], "components": []}, "c": {"advance": 600, "contours": [], "components": []}, "a_b": {"advance": 900, "contours": [], "components": []}, "a_b_c": {"advance": 1200, "contours": [], "components": []}, "a_b_a": {"advance": 1500, "contours": [], "components": []}, "dot": {"advance": 0, "contours": [], "components": []}}, "kern": [["a", "b", -100]], "ligatures": [[["a", "b"], "a_b"], [["a", "b", "c"], "a_b_c"], [["a_b", "a"], "a_b_a"]], "marks": {"dot": ["above", 0, 0]}, "anchors": {"a": {"above": [300, 700]}}}"#;

fn toy_font() -> renderer::Font {
    load_font(TOY_JSON)
}

#[test]
fn f_plus_i_produces_one_glyph_with_a_two_character_cluster() {
    let f = font();
    let b = apply_ligatures(&f, &glyph_buffer(&f, "office"));
    assert_eq!(b.len(), 5);
    assert_eq!(b[1].glyph, "f");
    assert_eq!(b[1].cluster, 1);
    assert_eq!(b[2].glyph, "f_i");
    assert_eq!(b[2].cluster, 2);
    assert_eq!(b[3].glyph, "c");
    assert_eq!(b[3].cluster, 4);
    assert_eq!(clusters(&b), vec![0, 1, 2, 4, 5]);
}

#[test]
fn the_walk_is_greedy_from_the_left_and_a_result_is_not_fed_back_in() {
    let f = font();
    let waffle = apply_ligatures(&f, &glyph_buffer(&f, "waffle"));
    assert_eq!(waffle[3].glyph, "f_l");
    assert_eq!(waffle[3].cluster, 3);
    assert_eq!(clusters(&waffle), vec![0, 1, 2, 3, 5]);

    let fig = apply_ligatures(&f, &glyph_buffer(&f, "fig"));
    assert_eq!(fig[0].glyph, "f_i");
    assert_eq!(fig[0].cluster, 0);
    assert_eq!(fig[1].cluster, 2);

    assert_eq!(apply_ligatures(&f, &glyph_buffer(&f, "off")).len(), 3);
}

#[test]
fn a_ligature_is_narrower_than_its_parts() {
    let f = font();
    assert_eq!(glyph_advance(&f, "f_i"), 1134.0);
    assert_eq!(glyph_advance(&f, "f") + glyph_advance(&f, "i"), 1208.0);
}

#[test]
fn the_longest_rule_that_matches_wins_on_a_font_written_by_hand_to_have_two() {
    let toy = toy_font();
    let abc = apply_ligatures(&toy, &glyph_buffer(&toy, "abc"));
    assert_eq!(abc.len(), 1);
    assert_eq!(abc[0].glyph, "a_b_c");
    assert_eq!(abc[0].cluster, 0);

    let abcab = apply_ligatures(&toy, &glyph_buffer(&toy, "abcab"));
    assert_eq!(abcab[1].glyph, "a_b");
    assert_eq!(abcab[1].cluster, 3);

    assert_eq!(apply_ligatures(&toy, &glyph_buffer(&toy, "acb")).len(), 3);
}

#[test]
fn a_result_is_never_fed_back_into_the_rules() {
    let toy = toy_font();
    let b = apply_ligatures(&toy, &glyph_buffer(&toy, "aba"));
    assert_eq!(b.len(), 2);
    assert_eq!(b[0].glyph, "a_b");
    assert_eq!(b[1].glyph, "a");
    assert_eq!(b[1].cluster, 2);
}
