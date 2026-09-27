// features/chapter21-plate.feature

use renderer::{
    canvas_to_p6, max_channel_difference, plate_21, ppm_pixel, read_file, render_svg, render_svg_with, stats,
    tile_work,
};

fn assert_pixel_within(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} ± {tol}, got {actual:?}"
    );
}

fn text(name: &str) -> String {
    String::from_utf8(read_file(&format!("reference/chapter-20/{name}.svg"))).unwrap()
}

#[test]
fn the_tiger_tiled_drawn_byte_for_byte_as_chapter_20_drew_it() {
    let mut st = stats();
    let t = text("tiger");
    let c = render_svg_with(&t, 450, 450, "tiled", &mut st);
    assert_eq!(st.cells, 816480);
    assert_eq!(st.copies, 207872);
    assert_eq!(max_channel_difference(canvas_to_p6(&c), canvas_to_p6(&render_svg(&t, 450, 450))), 0);
    assert!(max_channel_difference(canvas_to_p6(&c), read_file("reference/chapter-20/tiger.ppm")) <= 1);
}

#[test]
fn the_harbor_and_the_rose_every_way_byte_for_byte() {
    let harbor = text("harbor");
    let rose = text("rose");
    let h = canvas_to_p6(&render_svg(&harbor, 480, 320));
    let r = canvas_to_p6(&render_svg(&rose, 400, 400));
    assert_eq!(max_channel_difference(canvas_to_p6(&render_svg_with(&harbor, 480, 320, "bounded", &mut stats())), &h), 0);
    assert_eq!(max_channel_difference(canvas_to_p6(&render_svg_with(&harbor, 480, 320, "tiled", &mut stats())), &h), 0);
    assert_eq!(max_channel_difference(canvas_to_p6(&render_svg_with(&rose, 400, 400, "bounded", &mut stats())), &r), 0);
    assert_eq!(max_channel_difference(canvas_to_p6(&render_svg_with(&rose, 400, 400, "tiled", &mut stats())), &r), 0);
}

#[test]
fn where_the_tigers_work_is() {
    let w = tile_work(&text("tiger"), 450, 450);
    assert_eq!(w.len(), 29);
    assert_eq!(w[0].len(), 29);
    assert_eq!(w[0][0], (0, 0));
    assert_eq!(w[14][3], (31, 0));
    assert_eq!(w[12][12], (23, 1));
    assert_eq!(w[2][21], (0, 2));
}

#[test]
fn plate_21_test() {
    let c = plate_21();
    let reference = read_file("reference/chapter-21/work_map.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 910);
    assert_eq!(c.height, 450);
    assert_pixel_within(&p6, 250, 200, (0, 0, 0), 1);
    assert_pixel_within(&p6, 455, 5, (39, 39, 44), 1);
    assert_pixel_within(&p6, 516, 232, (237, 124, 196), 1);
    assert_pixel_within(&p6, 660, 200, (213, 112, 176), 1);
    assert_pixel_within(&p6, 804, 40, (100, 180, 196), 1);
    assert_pixel_within(&p6, 460, 0, (39, 39, 44), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
