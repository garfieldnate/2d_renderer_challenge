// features/epilogue-cover.feature

use renderer::{book_cover, canvas_to_p6, max_channel_difference, ppm_pixel, read_file, render_svg, render_svg_with, stats};

fn assert_pixel_within(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} ± {tol}, got {actual:?}"
    );
}

#[test]
fn the_cover() {
    let reference = read_file("reference/epilogue/cover.ppm");
    let c = book_cover();
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 480);
    assert_eq!(c.height, 680);
    assert_pixel_within(&p6, 44, 499, (243, 239, 230), 1);
    assert_pixel_within(&p6, 52, 551, (243, 239, 230), 1);
    assert_pixel_within(&p6, 60, 540, (42, 21, 52), 1);
    assert_pixel_within(&p6, 56, 639, (255, 155, 82), 1);
    assert_pixel_within(&p6, 240, 8, (21, 19, 42), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn chapter_21s_tiled_walker_draws_the_covers_document_byte_for_byte() {
    let mut st = stats();
    let text = String::from_utf8(read_file("reference/epilogue/cover.svg")).unwrap();
    let c = render_svg_with(&text, 480, 680, "tiled", &mut st);
    assert_eq!(st.cells, 881792);
    assert_eq!(st.copies, 205568);
    assert_eq!(
        max_channel_difference(canvas_to_p6(&c), canvas_to_p6(&render_svg(&text, 480, 680))),
        0
    );
    assert!(max_channel_difference(canvas_to_p6(&c), read_file("reference/epilogue/cover-art.ppm")) <= 1);
}
