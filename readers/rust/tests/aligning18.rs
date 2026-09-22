// features/chapter18-aligning.feature

use renderer::{approx_eq, approx_eq_eps, layout_line, layout_paragraph, load_font, pen_advance, read_file, run_advance};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn four_alignments_of_one_short_line() {
    let f = font();
    assert!(approx_eq_eps(run_advance(&f, "to be", 11.0, true), 24.4814, 0.0001));

    let left = layout_line(&f, "to be", 11.0, 10.0, 20.0, 60.0, "left", true);
    assert!(approx_eq(left[0].x, 10.0));
    assert!(approx_eq_eps(left[4].x, 28.6538, 0.0001));

    let right = layout_line(&f, "to be", 11.0, 10.0, 20.0, 60.0, "right", true);
    assert!(approx_eq_eps(right[0].x, 45.5186, 0.0001));
    assert!(approx_eq_eps(right[4].x, 64.1724, 0.0001));

    let center = layout_line(&f, "to be", 11.0, 10.0, 20.0, 60.0, "center", true);
    assert!(approx_eq_eps(center[0].x, 27.7593, 0.0001));
    assert!(approx_eq_eps(center[4].x, 46.4131, 0.0001));

    assert!(approx_eq_eps(right[4].x + pen_advance(&f, "e", 11.0), 70.0, 0.0001));
}

#[test]
fn justify_stretches_the_spaces_not_the_letters() {
    let f = font();
    let run = layout_line(&f, "to be", 11.0, 10.0, 20.0, 60.0, "justify", true);
    assert!(approx_eq(run[0].x, 10.0));
    assert!(approx_eq_eps(run[1].x, 13.4858, 0.0001));
    assert_eq!(run[2].name, "space");
    assert!(approx_eq_eps(run[2].x, 19.7593, 0.0001));
    assert!(approx_eq_eps(run[3].x, 58.001, 0.0001));
    assert!(approx_eq_eps(run[4].x, 64.1724, 0.0001));
    assert!(approx_eq_eps(run[4].x + pen_advance(&f, "e", 11.0), 70.0, 0.0001));

    let two = layout_line(&f, "to", 11.0, 10.0, 20.0, 60.0, "justify", true);
    assert!(approx_eq_eps(two[1].x, 13.4858, 0.0001));
}

#[test]
fn a_paragraph_stacks_its_lines_by_line_height_and_leaves_the_last_line_ragged() {
    let f = font();
    let run = layout_paragraph(&f, "the quick brown fox jumps over the lazy dog", 11.0, 10.0, 20.0, 100.0, "justify", true);
    assert_eq!(run.len(), 41);
    assert_eq!(run[0].name, "t");
    assert!(approx_eq(run[0].x, 10.0));
    assert!(approx_eq(run[0].y, 20.0));
    assert_eq!(run[18].name, "x");
    assert!(approx_eq_eps(run[18].x + pen_advance(&f, "x", 11.0), 110.0, 0.0001));
    assert_eq!(run[19].name, "j");
    assert!(approx_eq(run[19].x, 10.0));
    assert!(approx_eq(run[19].y, 20.0 + renderer::line_height(&f, 11.0)));
    assert!(approx_eq_eps(run[19].y, 32.8906, 0.0001));
    assert_eq!(run[38].name, "d");
    assert!(approx_eq(run[38].x, 10.0));
    assert!(approx_eq_eps(run[38].y, 45.7813, 0.0001));
    assert_eq!(run[40].name, "g");
    assert!(approx_eq_eps(run[40].x, 22.4771, 0.0001));
}
