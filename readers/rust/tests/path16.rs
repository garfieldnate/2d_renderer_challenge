// features/chapter16-path.feature

use renderer::{
    approx_eq, approx_eq_eps, contour_path, coverage_at, fill_path, glyph_path, identity, ink,
    load_font, point, polygon_area, read_file, subpaths, text_matrix, tuples_eq,
};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn the_text_matrix_scales_and_turns_y_over() {
    let f = font();
    let m = text_matrix(&f, 2048.0, 100.0, 500.0);
    assert!(tuples_eq(m * point(0.0, 0.0), point(100.0, 500.0)));
    assert!(tuples_eq(m * point(2048.0, 2048.0), point(2148.0, -1548.0)));
    assert!(tuples_eq(m * point(0.0, 1900.0), point(100.0, -1400.0)));
    assert!(tuples_eq(text_matrix(&f, 16.0, 10.0, 20.0) * point(1024.0, 1024.0), point(18.0, 12.0)));
}

#[test]
fn a_glyph_path_has_one_closed_subpath_per_contour() {
    let f = font();
    let m = text_matrix(&f, 200.0, 20.0, 160.0);
    let o = glyph_path(&f, "o", m, 0.05);
    assert_eq!(subpaths(&o).len(), 2);
    assert!(subpaths(&o)[0].closed);
    assert!(subpaths(&o)[1].closed);
    assert_eq!(subpaths(&glyph_path(&f, "eacute", m, 0.05)).len(), 3);
    assert_eq!(subpaths(&glyph_path(&f, "i", m, 0.05)).len(), 2);
}

#[test]
fn the_two_contours_of_an_o_wind_opposite_ways_and_the_flip_turns_both_over() {
    let f = font();
    let m = text_matrix(&f, 200.0, 20.0, 160.0);
    assert!(approx_eq_eps(polygon_area(&contour_path(&f, "o", 0, m, 0.05)), 8509.81, 0.01));
    assert!(approx_eq_eps(polygon_area(&contour_path(&f, "o", 1, m, 0.05)), -3894.40, 0.01));
    assert!(polygon_area(&contour_path(&f, "o", 0, identity(), 1.0)) <= 0.0);
    assert!(polygon_area(&contour_path(&f, "o", 1, identity(), 1.0)) >= 0.0);
}

#[test]
fn the_counter_is_a_hole_the_ink_is_the_outer_area_minus_the_inner() {
    let f = font();
    let m = text_matrix(&f, 200.0, 20.0, 160.0);
    let cov = fill_path(&glyph_path(&f, "o", m, 0.05), "nonzero", 200, 200);
    assert!(approx_eq_eps(ink(&cov), 4615.41, 0.01));
    assert!(approx_eq(coverage_at(&cov, 35, 110), 1.0));
    assert!(approx_eq(coverage_at(&cov, 72, 100), 0.0));
    assert!(approx_eq(coverage_at(&cov, 5, 5), 0.0));
}
