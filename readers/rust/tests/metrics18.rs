// features/chapter18-metrics.feature

use renderer::{approx_eq, approx_eq_eps, ascent, descent, layout_run, line_height, load_font, pen_advance, read_file, run_advance};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn the_vertical_metrics_in_pixels() {
    let f = font();
    assert!(approx_eq_eps(ascent(&f, 16.0), 14.8438, 0.0001));
    assert!(approx_eq_eps(descent(&f, 16.0), 3.9063, 0.0001));
    assert!(approx_eq(line_height(&f, 16.0), 18.75));
    assert!(approx_eq_eps(line_height(&f, 14.0), 16.4063, 0.0001));
    assert!(approx_eq(line_height(&f, 16.0), ascent(&f, 16.0) + descent(&f, 16.0)));
}

#[test]
fn a_run_is_one_placement_per_character_each_an_advance_further_along() {
    let f = font();
    let run = layout_run(&f, "Ha", 11.0, 2.0, 11.0, false);
    assert_eq!(run.len(), 2);
    assert_eq!(run[0].name, "H");
    assert!(approx_eq(run[0].x, 2.0));
    assert!(approx_eq(run[0].y, 11.0));
    assert_eq!(run[1].name, "a");
    assert!(approx_eq(run[1].x, 2.0 + pen_advance(&f, "H", 11.0)));
    assert!(approx_eq_eps(run[1].x, 9.8418, 0.0001));
    assert!(approx_eq(run[1].y, 11.0));
    assert!(approx_eq_eps(run_advance(&f, "Ha", 11.0, false), 13.8252, 0.0001));
    assert!(approx_eq(
        run_advance(&f, "Ha", 11.0, false),
        pen_advance(&f, "H", 11.0) + pen_advance(&f, "a", 11.0)
    ));
}

#[test]
fn spaces_are_placed_and_so_is_a_character_the_font_doesnt_have() {
    let f = font();
    let run = layout_run(&f, "a\u{2603}b", 11.0, 0.0, 0.0, false);
    assert_eq!(run.len(), 3);
    assert_eq!(run[1].name, ".notdef");
    assert!(approx_eq_eps(run[1].x, 5.9834, 0.0001));
    assert_eq!(run[2].name, "b");
    assert!(approx_eq_eps(run[2].x, 10.8604, 0.0001));

    let spaced = layout_run(&f, "a b", 11.0, 0.0, 0.0, false);
    assert_eq!(spaced[1].name, "space");
    assert!(approx_eq_eps(spaced[2].x, 5.9834 + pen_advance(&f, "space", 11.0), 0.0001));

    assert_eq!(layout_run(&f, "", 11.0, 0.0, 0.0, false).len(), 0);
    assert!(approx_eq(run_advance(&f, "", 11.0, false), 0.0));
}

#[test]
fn without_kerning_the_runs_advance_is_the_sum_of_the_glyph_advances() {
    let f = font();
    assert!(approx_eq(run_advance(&f, "TAVERN", 64.0, false), 242.0625));
    let run = layout_run(&f, "TAVERN", 64.0, 12.0, 70.0, false);
    assert!(approx_eq(run[5].x, 208.4375));
}
