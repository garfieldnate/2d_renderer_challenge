// features/chapter19-ligatures.feature

use renderer::{apply_ligatures, clusters, glyph_advance, glyph_buffer, load_font, read_file};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
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
