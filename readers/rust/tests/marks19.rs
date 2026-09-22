// features/chapter19-marks.feature

use renderer::{glyph_advance, is_mark, load_font, read_file, shape};

fn arabic_font() -> renderer::Font {
    load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
}

fn roboto_font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

const KITAB_MARKED: &str = "\u{0643}\u{0650}\u{062A}\u{0627}\u{0628}";
// beh, fatha, shadda
const BEH_FATHA_SHADDA: &str = "\u{0628}\u{064E}\u{0651}";
// kasra, beh
const KASRA_BEH: &str = "\u{0650}\u{0628}";

#[test]
fn the_anchors_in_font_units() {
    let f = arabic_font();
    assert_eq!(f.marks["kasra"], ("below".to_string(), 512.0, 0.0));
    assert_eq!(f.marks["fatha"], ("above".to_string(), 512.0, 1200.0));
    assert_eq!(f.anchors["kaf.init"]["below"], (300.0, -150.0));
    assert_eq!(f.anchors["kaf.init"]["above"], (250.0, 1550.0));
    assert_eq!(f.anchors["beh"]["above"], (900.0, 1000.0));
    assert_eq!(glyph_advance(&f, "kasra"), 0.0);
    assert!(is_mark(&f, "kasra"));
    assert!(!is_mark(&f, "kaf"));
}

#[test]
fn a_marks_anchor_lands_on_its_bases_and_it_joins_the_bases_cluster() {
    let f = arabic_font();
    let b = shape(&f, KITAB_MARKED);
    assert_eq!(b.len(), 5);
    assert_eq!(b[0].glyph, "kaf.init");
    assert_eq!(b[0].cluster, 0);
    assert_eq!(b[1].glyph, "kasra");
    assert_eq!(b[1].cluster, 0);
    assert_eq!(b[1].dx, -212.0);
    assert_eq!(b[1].dy, -150.0);
    assert_eq!(b[2].glyph, "teh.medi");
    assert_eq!(b[2].cluster, 2);
    assert_eq!(b[2].dx, 0.0);
    assert_eq!(renderer::clusters(&b), vec![0, 2, 3, 4]);
}

#[test]
fn two_marks_on_one_base_both_take_its_anchor_a_mark_with_no_base_stays_put() {
    let f = arabic_font();
    let b = shape(&f, BEH_FATHA_SHADDA);
    assert_eq!(b.len(), 3);
    assert_eq!(b[1].glyph, "fatha");
    assert_eq!(b[1].dx, 388.0);
    assert_eq!(b[1].dy, -200.0);
    assert_eq!(b[2].glyph, "shadda");
    assert_eq!(b[2].dx, 388.0);
    assert_eq!(b[2].dy, -200.0);
    assert_eq!(b[2].cluster, 0);

    let no_base = shape(&f, KASRA_BEH);
    assert_eq!(no_base[0].glyph, "kasra");
    assert_eq!(no_base[0].cluster, 0);
    assert_eq!(no_base[0].dx, 0.0);
    assert_eq!(no_base[1].cluster, 1);
}

#[test]
fn shaping_latin_is_ligatures_alone() {
    let f = roboto_font();
    let b = shape(&f, "office");
    assert_eq!(b.len(), 5);
    assert_eq!(b[2].glyph, "f_i");
    assert_eq!(b[2].cluster, 2);
    assert!(!is_mark(&f, "f_i"));
}
