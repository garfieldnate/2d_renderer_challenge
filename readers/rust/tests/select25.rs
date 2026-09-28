// features/chapter25-select.feature

use renderer::{
    add_selection, canvas, color, coverage_at, drop_floating, feather, float_selection, history,
    history_fill, ink, intersect_selection, marquee, move_floating, pixel_at, redo,
    stored_pixels, subtract_selection, undo, fill, write_pixel,
};

#[test]
fn selections_combine_like_coverage() {
    let a = marquee(2.0, 2.0, 6.0, 6.0, 8, 8);
    let b = marquee(4.0, 4.0, 8.0, 8.0, 8, 8);
    assert_eq!(ink(&add_selection(&a, &b)), 28.0);
    assert_eq!(ink(&subtract_selection(&a, &b)), 12.0);
    assert_eq!(ink(&intersect_selection(&a, &b)), 4.0);
}

#[test]
fn feathering_keeps_the_selections_size_and_softens_its_edge() {
    let f = feather(&marquee(2.0, 2.0, 6.0, 6.0, 8, 8), 1);
    assert_eq!(coverage_at(&f, 3, 3), 1.0);
    assert!(renderer::approx_eq(coverage_at(&f, 2, 2), 0.444444));
    assert!(renderer::approx_eq(coverage_at(&f, 1, 1), 0.111111));
    assert!(renderer::approx_eq(ink(&f), 16.0));
}

#[test]
fn off_the_buffer_counts_as_unselected() {
    let f = feather(&marquee(0.0, 0.0, 4.0, 4.0, 8, 8), 1);
    assert!(renderer::approx_eq(coverage_at(&f, 0, 0), 0.444444));
    assert_eq!(coverage_at(&f, 1, 1), 1.0);
}

#[test]
fn a_floating_selection_moves_and_drops() {
    let mut c = canvas(8, 8);
    fill(&mut c, color(0.0, 0.0, 1.0));
    write_pixel(&mut c, 2, 2, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 3, 2, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 2, 3, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 3, 3, color(1.0, 0.0, 0.0));
    let mut f = float_selection(&mut c, &marquee(2.0, 2.0, 4.0, 4.0, 8, 8), color(0.0, 0.0, 1.0));
    move_floating(&mut f, 3, 1);
    drop_floating(&mut c, &f);
    assert_eq!(pixel_at(&c, 2, 2), color(0.0, 0.0, 1.0));
    assert_eq!(pixel_at(&c, 5, 3), color(1.0, 0.0, 0.0));
    assert_eq!(pixel_at(&c, 6, 4), color(1.0, 0.0, 0.0));
    assert_eq!(pixel_at(&c, 4, 2), color(0.0, 0.0, 1.0));
}

#[test]
fn undo_redo_and_a_new_edit_ends_redo() {
    let mut c = canvas(8, 8);
    let mut h = history(&c);
    history_fill(&mut h, &mut c, 0, 0, 4, 4, color(1.0, 1.0, 1.0));
    history_fill(&mut h, &mut c, 2, 2, 6, 6, color(1.0, 0.0, 0.0));
    assert_eq!(pixel_at(&c, 3, 3), color(1.0, 0.0, 0.0));
    assert_eq!(stored_pixels(&h), 32);
    assert!(undo(&mut h, &mut c));
    assert_eq!(pixel_at(&c, 3, 3), color(1.0, 1.0, 1.0));
    assert_eq!(pixel_at(&c, 5, 5), color(0.0, 0.0, 0.0));
    assert!(redo(&mut h, &mut c));
    assert_eq!(pixel_at(&c, 3, 3), color(1.0, 0.0, 0.0));
    assert!(undo(&mut h, &mut c));
    assert!(undo(&mut h, &mut c));
    assert!(!undo(&mut h, &mut c));
    assert_eq!(pixel_at(&c, 1, 1), color(0.0, 0.0, 0.0));
    assert!(redo(&mut h, &mut c));
    assert_eq!(pixel_at(&c, 1, 1), color(1.0, 1.0, 1.0));
}

#[test]
fn an_edit_after_an_undo_throws_redo_away() {
    let mut c = canvas(8, 8);
    let mut h = history(&c);
    history_fill(&mut h, &mut c, 0, 0, 4, 4, color(1.0, 1.0, 1.0));
    history_fill(&mut h, &mut c, 2, 2, 6, 6, color(1.0, 0.0, 0.0));
    undo(&mut h, &mut c);
    history_fill(&mut h, &mut c, 0, 0, 1, 1, color(0.0, 1.0, 0.0));
    assert!(!redo(&mut h, &mut c));
    assert_eq!(stored_pixels(&h), 17);
    assert_eq!(pixel_at(&c, 0, 0), color(0.0, 1.0, 0.0));
}
