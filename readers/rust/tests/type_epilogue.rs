// features/epilogue-type.feature

use renderer::{approx_eq, break_lines, layout_paragraph, layout_run, line_height, load_font, read_file, run_advance};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn the_title_breaks_after_renderer() {
    let f = font();
    assert_eq!(
        break_lines(&f, "The 2D Renderer Challenge", 44.0, 400.0, true),
        vec!["The 2D Renderer".to_string(), "Challenge".to_string()]
    );
    assert!(approx_eq(run_advance(&f, "The 2D Renderer", 44.0, true), 324.628906));
    assert!(approx_eq(run_advance(&f, "The 2D Renderer Challenge", 44.0, true), 529.267578));
    assert!(approx_eq(line_height(&f, 44.0), 51.5625));
}

#[test]
fn the_second_line_starts_at_the_margin_one_line_height_down_and_the_space_it_broke_at_isnt_placed() {
    let f = font();
    let title = layout_paragraph(&f, "The 2D Renderer Challenge", 44.0, 40.0, 530.0, 400.0, "left", true);
    assert_eq!(title.len(), 24);
    assert_eq!(title[14].name, "r");
    assert!(approx_eq(title[14].x, 349.740234));
    assert!(approx_eq(title[14].y, 530.0));
    assert_eq!(title[15].name, "C");
    assert!(approx_eq(title[15].x, 40.0));
    assert!(approx_eq(title[15].y, 581.5625));
}

#[test]
fn the_subtitle_fits_on_one_line() {
    let f = font();
    let sub = layout_run(&f, "A test-driven guide to drawing every pixel yourself", 15.0, 40.0, 640.0, true);
    assert_eq!(sub.len(), 51);
    assert!(approx_eq(
        run_advance(&f, "A test-driven guide to drawing every pixel yourself", 15.0, true),
        328.630371
    ));
}
