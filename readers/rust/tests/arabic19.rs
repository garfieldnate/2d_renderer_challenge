// features/chapter19-arabic.feature

use renderer::{apply_forms, apply_ligatures, arabic_forms, glyph_advance, glyph_buffer, joining_type, load_font, read_file};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
}

const BEH: &str = "\u{0628}";
const BEH_BEH: &str = "\u{0628}\u{0628}";
const BEH_BEH_BEH: &str = "\u{0628}\u{0628}\u{0628}";
const BAB: &str = "\u{0628}\u{0627}\u{0628}";
const BEH_SPACE_BEH: &str = "\u{0628}\u{0020}\u{0628}";
const SALAM: &str = "\u{0633}\u{0644}\u{0627}\u{0645}";
const KITAB_MARKED: &str = "\u{0643}\u{0650}\u{062A}\u{0627}\u{0628}";
const KITAB: &str = "\u{0643}\u{062A}\u{0627}\u{0628}";

#[test]
fn the_joining_types() {
    let f = font();
    assert_eq!(joining_type(&f, 1603), "dual");
    assert_eq!(joining_type(&f, 1575), "right");
    assert_eq!(joining_type(&f, 1616), "transparent");
    assert_eq!(joining_type(&f, 1569), "none");
    assert_eq!(joining_type(&f, 1600), "dual");
    assert_eq!(joining_type(&f, 32), "none");
    assert_eq!(joining_type(&f, 65), "none");
}

#[test]
fn an_arabic_letter_selects_its_form_by_its_neighbours() {
    let f = font();
    assert_eq!(arabic_forms(&f, BEH), vec!["isol"]);
    assert_eq!(arabic_forms(&f, BEH_BEH), vec!["init", "fina"]);
    assert_eq!(arabic_forms(&f, BEH_BEH_BEH), vec!["init", "medi", "fina"]);
    assert_eq!(arabic_forms(&f, BAB), vec!["init", "fina", "isol"]);
    assert_eq!(arabic_forms(&f, BEH_SPACE_BEH), vec!["isol", "isol", "isol"]);
    assert_eq!(arabic_forms(&f, SALAM), vec!["init", "medi", "fina", "isol"]);
}

#[test]
fn a_vowel_mark_is_transparent_the_letters_join_across_it() {
    let f = font();
    assert_eq!(arabic_forms(&f, KITAB_MARKED), vec!["init", "isol", "medi", "fina", "isol"]);
    assert_eq!(arabic_forms(&f, KITAB), vec!["init", "medi", "fina", "isol"]);
}

#[test]
fn the_forms_table_swaps_glyphs_and_leaves_alone_what_it_has_no_form_for() {
    let f = font();
    let b = apply_forms(&f, KITAB_MARKED, &glyph_buffer(&f, KITAB_MARKED));
    assert_eq!(b[0].glyph, "kaf.init");
    assert_eq!(b[1].glyph, "kasra");
    assert_eq!(b[2].glyph, "teh.medi");
    assert_eq!(b[3].glyph, "alef.fina");
    assert_eq!(b[4].glyph, "beh");
    assert_eq!(b[4].cluster, 4);
    assert_eq!(f.forms["kaf"]["medi"], "kaf.medi");
    assert_eq!(f.forms["alef"]["fina"], "alef.fina");
    assert_eq!(glyph_advance(&f, "kaf"), 1688.0);
    assert_eq!(glyph_advance(&f, "kaf.init"), 975.0);
}

#[test]
fn lam_and_alef_ligate_after_their_forms_are_chosen() {
    let f = font();
    let b = apply_ligatures(&f, &apply_forms(&f, SALAM, &glyph_buffer(&f, SALAM)));
    assert_eq!(b.len(), 3);
    assert_eq!(b[0].glyph, "seen.init");
    assert_eq!(b[1].glyph, "lam_alef.fina");
    assert_eq!(b[1].cluster, 1);
    assert_eq!(b[2].glyph, "meem");
    assert_eq!(b[2].cluster, 3);
    assert_eq!(f.ligatures[1], (vec!["lam.medi".to_string(), "alef.fina".to_string()], "lam_alef.fina".to_string()));
}
