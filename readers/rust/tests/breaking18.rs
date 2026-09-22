// features/chapter18-breaking.feature

use renderer::{approx_eq_eps, break_lines, load_font, read_file, run_advance};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn greedy_breaking_at_three_measures() {
    let f = font();
    let text = "the quick brown fox jumps over the lazy dog";
    assert_eq!(
        break_lines(&f, text, 11.0, 100.0, true),
        vec!["the quick brown fox", "jumps over the lazy", "dog"]
    );
    assert_eq!(
        break_lines(&f, text, 11.0, 60.0, true),
        vec!["the quick", "brown fox", "jumps over", "the lazy dog"]
    );
    assert_eq!(
        break_lines(&f, text, 11.0, 150.0, true),
        vec!["the quick brown fox jumps", "over the lazy dog"]
    );
    assert!(run_advance(&f, "the quick brown fox", 11.0, true) <= 100.0);
    assert!(100.0 <= run_advance(&f, "the quick brown fox jumps", 11.0, true));
}

#[test]
fn a_line_exactly_as_wide_as_the_measure_fits() {
    let f = font();
    let text = "the quick brown fox jumps over the lazy dog";
    let measure = run_advance(&f, "the quick", 11.0, true);
    assert!(approx_eq_eps(measure, 44.521, 0.0001));
    let lines = break_lines(&f, text, 11.0, measure, true);
    assert_eq!(lines[0], "the quick");
    assert_eq!(lines.len(), 6);
    let short_lines = break_lines(&f, text, 11.0, measure - 0.01, true);
    assert_eq!(short_lines[0], "the");
    assert_eq!(short_lines.len(), 7);
}

#[test]
fn a_word_wider_than_the_measure_sits_alone_and_overflows() {
    let f = font();
    assert_eq!(
        break_lines(&f, "a supercalifragilistic word", 11.0, 40.0, true),
        vec!["a", "supercalifragilistic", "word"]
    );
    assert!(40.0 <= run_advance(&f, "supercalifragilistic", 11.0, true));
}

#[test]
fn no_text_is_no_lines_and_runs_of_spaces_are_one_break() {
    let f = font();
    assert_eq!(break_lines(&f, "", 11.0, 100.0, true).len(), 0);
    assert_eq!(break_lines(&f, "  two  spaces ", 11.0, 100.0, true), vec!["two spaces"]);
    assert_eq!(break_lines(&f, "one", 11.0, 1.0, true), vec!["one"]);
}
