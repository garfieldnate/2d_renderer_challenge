// features/chapter21-bounds.feature

use renderer::{
    canvas_to_p6, coverage_in, fill_bounds, fill_path, fill_path_bounded, full_coverage, max_channel_difference,
    max_coverage_difference, path, point, polygon, read_file, render_svg_with, stats,
};

#[test]
fn the_window_under_a_path_in_whole_pixels() {
    assert_eq!(
        fill_bounds(&polygon(&[point(2.5, 3.25), point(20.0, 3.25), point(20.0, 17.75), point(2.5, 17.75)]), 64, 64),
        (2, 3, 21, 18)
    );
    assert_eq!(
        fill_bounds(&polygon(&[point(2.0, 3.0), point(20.0, 3.0), point(20.0, 18.0), point(2.0, 18.0)]), 64, 64),
        (2, 3, 21, 19)
    );
    assert_eq!(
        fill_bounds(&polygon(&[point(-5.0, -5.0), point(10.5, -5.0), point(10.5, 70.0), point(-5.0, 70.0)]), 64, 64),
        (0, 0, 11, 64)
    );
    assert_eq!(
        fill_bounds(&polygon(&[point(70.0, 5.0), point(80.0, 5.0), point(80.0, 10.0), point(70.0, 10.0)]), 64, 64),
        (0, 0, 0, 0)
    );
    assert_eq!(fill_bounds(&path(), 64, 64), (0, 0, 0, 0));
}

#[test]
fn a_bounded_fill_resolves_only_its_window_and_agrees_with_chapter_7() {
    let mut st = stats();
    let tri = polygon(&[point(3.3, 2.7), point(40.1, 9.9), point(12.6, 33.3)]);
    let win = fill_path_bounded(&tri, "nonzero", 64, 64, &mut st);
    assert_eq!(win.x0, 3);
    assert_eq!(win.y0, 2);
    assert_eq!(win.cov.width, 38);
    assert_eq!(win.cov.height, 32);
    assert_eq!(st.cells, 1216);
    assert_eq!(coverage_in(&win, 1, 1), 0.0);
    assert_eq!(coverage_in(&win, 60, 60), 0.0);
    assert!(max_coverage_difference(&full_coverage(&win, 64, 64), &fill_path(&tri, "nonzero", 64, 64)) <= 0.000001);
}

#[test]
fn the_tiger_bounded() {
    let mut st = stats();
    let text = String::from_utf8(read_file("reference/chapter-20/tiger.svg")).unwrap();
    let c = render_svg_with(&text, 450, 450, "bounded", &mut st);
    assert_eq!(st.cells, 1395287);
    assert_eq!(st.copies, 0);
    assert!(max_channel_difference(canvas_to_p6(&c), read_file("reference/chapter-20/tiger.ppm")) <= 1);
}
