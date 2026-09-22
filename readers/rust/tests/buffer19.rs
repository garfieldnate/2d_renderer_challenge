// features/chapter19-buffer.feature

use renderer::{clusters, glyph_buffer, load_font, read_file};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn one_entry_per_character_each_its_own_cluster() {
    let f = font();
    let b = glyph_buffer(&f, "office");
    assert_eq!(b.len(), 6);
    assert_eq!(b[0].glyph, "o");
    assert_eq!(b[0].cluster, 0);
    assert_eq!(b[3].glyph, "i");
    assert_eq!(b[3].cluster, 3);
    assert_eq!(clusters(&b), vec![0, 1, 2, 3, 4, 5]);

    assert_eq!(glyph_buffer(&f, "a\u{2603}")[1].glyph, ".notdef");
    assert_eq!(glyph_buffer(&f, "").len(), 0);
}
