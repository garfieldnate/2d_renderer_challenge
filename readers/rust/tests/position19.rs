// features/chapter19-position.feature

use renderer::{approx_eq, approx_eq_eps, buffer_advance, caret_offsets, caret_positions, glyph_buffer, layout_run, load_font, pen_advance, position, read_file, run_advance, shape};

fn roboto_font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

fn arabic_font() -> renderer::Font {
    load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
}

const KITAB_MARKED: &str = "\u{0643}\u{0650}\u{062A}\u{0627}\u{0628}";

#[test]
fn a_buffer_straight_from_the_cmap_positions_exactly_as_layout_run_lays_it_out() {
    let f = roboto_font();
    let run = position(&f, &glyph_buffer(&f, "TAVERN"), 64.0, 12.0, 70.0, "ltr", true);
    assert_eq!(run.len(), 6);
    assert_eq!(run[1].name, "A");
    assert!(approx_eq(run[1].x, layout_run(&f, "TAVERN", 64.0, 12.0, 70.0, true)[1].x));
    assert!(approx_eq(run[5].x, 203.25));
    assert!(approx_eq(
        buffer_advance(&f, &glyph_buffer(&f, "TAVERN"), 64.0, true),
        run_advance(&f, "TAVERN", 64.0, true)
    ));
}

#[test]
fn a_shaped_latin_run_is_narrower_by_the_ligature() {
    let f = roboto_font();
    let b = shape(&f, "office");
    let run = position(&f, &b, 64.0, 20.0, 70.0, "ltr", true);
    assert!(approx_eq(buffer_advance(&f, &b, 64.0, true), 161.5625));
    assert!(approx_eq(run_advance(&f, "office", 64.0, true), 163.875));
    assert_eq!(run[2].name, "f_i");
    assert!(approx_eq_eps(run[2].x, 78.7188, 0.0001));
    assert!(approx_eq_eps(run[4].x, 147.6563, 0.0001));
}

#[test]
fn right_to_left_the_first_glyph_lands_at_the_right_end() {
    let f = arabic_font();
    let b = shape(&f, KITAB_MARKED);
    let run = position(&f, &b, 64.0, 20.0, 64.0, "rtl", false);
    assert!(approx_eq_eps(buffer_advance(&f, &b, 64.0, false), 129.5313, 0.0001));
    assert_eq!(run[0].name, "kaf.init");
    assert!(approx_eq(run[0].x, 119.0625));
    assert!(approx_eq(run[0].y, 64.0));
    assert_eq!(run[2].name, "teh.medi");
    assert!(approx_eq(run[2].x, 99.75));
    assert!(approx_eq(run[3].x, 80.25));
    assert_eq!(run[4].name, "beh");
    assert!(approx_eq(run[4].x, 20.0));
    assert!(approx_eq(run[0].x + pen_advance(&f, "kaf.init", 64.0), 20.0 + buffer_advance(&f, &b, 64.0, false)));
}

#[test]
fn a_mark_sits_at_its_bases_origin_plus_its_offset_whichever_way_the_pen_walks() {
    let f = arabic_font();
    let b = shape(&f, KITAB_MARKED);
    let rtl = position(&f, &b, 64.0, 20.0, 64.0, "rtl", false);
    let ltr = position(&f, &b, 64.0, 20.0, 64.0, "ltr", false);
    assert_eq!(rtl[1].name, "kasra");
    assert!(approx_eq(rtl[1].x, 112.4375));
    assert!(approx_eq(rtl[1].y, 68.6875));
    assert!(approx_eq(rtl[1].x, rtl[0].x - 212.0 * 64.0 / 2048.0));
    assert!(approx_eq(ltr[0].x, 20.0));
    assert!(approx_eq(ltr[1].x, 13.375));
    assert!(approx_eq(ltr[1].y, 68.6875));
    assert!(approx_eq_eps(ltr[2].x, 50.4688, 0.0001));
    assert!(approx_eq_eps(ltr[4].x, 89.2813, 0.0001));
}

#[test]
fn the_cursor_may_stand_at_cluster_boundaries_and_nowhere_else() {
    let f = roboto_font();
    let b = shape(&f, "office");
    assert_eq!(caret_offsets(&b, 6), vec![0, 1, 2, 4, 5, 6]);
    let positions = caret_positions(&f, &b, 6, 64.0, 20.0, "ltr", true);
    let expected = [20.0, 56.5, 78.7188, 114.1563, 147.6563, 181.5625];
    for (a, e) in positions.iter().zip(expected.iter()) {
        assert!(approx_eq_eps(*a, *e, 0.0001));
    }
}

#[test]
fn cursor_positions_in_a_right_to_left_run_run_from_right_to_left() {
    let f = arabic_font();
    let b = shape(&f, KITAB_MARKED);
    assert_eq!(caret_offsets(&b, 5), vec![0, 2, 3, 4, 5]);
    let positions = caret_positions(&f, &b, 5, 64.0, 20.0, "rtl", false);
    let expected = [149.5313, 119.0625, 99.75, 80.25, 20.0];
    for (a, e) in positions.iter().zip(expected.iter()) {
        assert!(approx_eq_eps(*a, *e, 0.0001));
    }
    assert!(approx_eq(positions[0], 20.0 + buffer_advance(&f, &b, 64.0, false)));
}
