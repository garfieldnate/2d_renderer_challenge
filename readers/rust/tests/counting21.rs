// features/chapter21-counting.feature

use renderer::{
    canvas_to_p6, color, draw_coverage_counted, fill_path, fill_path_counted, layer, layer_pixel,
    max_channel_difference, max_coverage_difference, pixel, pixels_eq, point, polygon, read_file,
    render_svg_with, solid, stats,
};

fn square() -> renderer::Path {
    polygon(&[point(4.0, 4.0), point(20.0, 4.0), point(20.0, 20.0), point(4.0, 20.0)])
}

#[test]
fn chapter_7_resolves_the_whole_canvas_for_a_small_square() {
    let mut st = stats();
    let cov = fill_path_counted(&square(), "nonzero", 64, 64, &mut st);
    assert_eq!(st.cells, 4096);
    assert_eq!(st.blends, 0);
    assert_eq!(st.copies, 0);
    assert_eq!(max_coverage_difference(&cov, &fill_path(&square(), "nonzero", 64, 64)), 0.0);
}

#[test]
fn only_the_pixels_with_coverage_are_blended() {
    let mut st = stats();
    let mut l = layer(64, 64);
    let cov = fill_path(&square(), "nonzero", 64, 64);
    draw_coverage_counted(&mut l, &cov, &solid(color(1.0, 0.0, 0.0)), 1.0, &mut st);
    assert_eq!(st.blends, 256);
    assert!(pixels_eq(layer_pixel(&l, 10, 10), pixel(1.0, 0.0, 0.0, 1.0)));
    assert!(pixels_eq(layer_pixel(&l, 30, 30), pixel(0.0, 0.0, 0.0, 0.0)));
}

#[test]
fn the_tiger_as_chapter_20_draws_it() {
    let mut st = stats();
    let text = String::from_utf8(read_file("reference/chapter-20/tiger.svg")).unwrap();
    let c = render_svg_with(&text, 450, 450, "whole", &mut st);
    assert_eq!(st.cells, 61762500);
    assert_eq!(st.copies, 0);
    assert!(max_channel_difference(canvas_to_p6(&c), read_file("reference/chapter-20/tiger.ppm")) <= 1);
}
