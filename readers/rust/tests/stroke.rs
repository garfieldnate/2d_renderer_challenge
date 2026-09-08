// features/chapter13-stroke.feature

use renderer::{
    chevron, fill_path, line_to, max_coverage_difference, move_to, path, point, polygon,
    stroke_to_path, subpaths, tuples_eq,
};

#[test]
fn a_stroked_segment_with_butt_caps_is_exactly_a_rectangle() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 5.0));
    line_to(&mut seg, point(10.0, 5.0));
    let o = stroke_to_path(&seg, 4.0, "butt", "miter", 4.0);

    assert_eq!(subpaths(&o).len(), 1);
    assert!(tuples_eq(subpaths(&o)[0].points[0], point(0.0, 7.0)));
    assert!(tuples_eq(subpaths(&o)[0].points[1], point(10.0, 7.0)));
    assert!(tuples_eq(subpaths(&o)[0].points[2], point(10.0, 3.0)));
    assert!(tuples_eq(subpaths(&o)[0].points[3], point(0.0, 3.0)));
}

#[test]
fn the_stroked_segment_fills_the_same_pixels_as_the_rectangle() {
    let mut seg = path();
    move_to(&mut seg, point(0.0, 5.0));
    line_to(&mut seg, point(10.0, 5.0));
    let o = stroke_to_path(&seg, 4.0, "butt", "miter", 4.0);
    let rect = polygon(&[point(0.0, 3.0), point(10.0, 3.0), point(10.0, 7.0), point(0.0, 7.0)]);

    let cov_o = fill_path(&o, "nonzero", 12, 10);
    let cov_rect = fill_path(&rect, "nonzero", 12, 10);
    assert_eq!(max_coverage_difference(&cov_o, &cov_rect), 0.0);
}

// Scenario Outline: A chevron's join is a different shape for each join style
macro_rules! join_shape_case {
    ($name:ident, $join:expr, $points:expr) => {
        #[test]
        fn $name() {
            let o = stroke_to_path(&chevron(), 26.0, "butt", $join, 4.0);
            assert_eq!(subpaths(&o).len(), 3);
            assert_eq!(subpaths(&o)[2].points.len(), $points);
        }
    };
}

join_shape_case!(miter_join_has_four_points, "miter", 4);
join_shape_case!(bevel_join_has_three_points, "bevel", 3);
join_shape_case!(round_join_has_twenty_four_points, "round", 24);

#[test]
fn the_miter_reaches_its_tip_at_the_vertex_plus_the_miter_length() {
    let o = stroke_to_path(&chevron(), 26.0, "butt", "miter", 4.0);
    assert!(tuples_eq(subpaths(&o)[2].points[0], point(80.0, 120.0)));
    assert!(renderer::approx_eq_eps(subpaths(&o)[2].points[2].x, 80.0, 0.01));
    assert!(renderer::approx_eq_eps(subpaths(&o)[2].points[2].y, 144.528, 0.01));
}
