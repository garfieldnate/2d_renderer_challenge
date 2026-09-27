// features/chapter13-stroke.feature

use renderer::{
    approx_eq_eps, chevron, coverage_at, fill_path, inside_nonzero, line_to, max_coverage_difference,
    move_to, path, point, polygon, polygon_area, stroke_to_path, subpaths, tuples_eq, u_turn,
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
join_shape_case!(round_join_has_thirteen_points, "round", 13);

#[test]
fn the_round_join_is_an_arc_across_the_outer_gap_not_around_the_inside() {
    let o = stroke_to_path(&chevron(), 26.0, "butt", "round", 4.0);
    assert!(tuples_eq(subpaths(&o)[2].points[0], point(80.0, 120.0)));
    assert!(approx_eq_eps(subpaths(&o)[2].points[6].x, 78.797, 0.01));
    assert!(approx_eq_eps(subpaths(&o)[2].points[6].y, 132.944, 0.01));
    assert!(inside_nonzero(&o, 80.0, 131.0));
    assert!(!inside_nonzero(&o, 80.0, 135.0));
}

#[test]
fn the_miter_reaches_its_tip_at_the_vertex_plus_the_miter_length() {
    let o = stroke_to_path(&chevron(), 26.0, "butt", "miter", 4.0);
    assert!(tuples_eq(subpaths(&o)[2].points[0], point(80.0, 120.0)));
    assert!(approx_eq_eps(subpaths(&o)[2].points[2].x, 80.0, 0.01));
    assert!(approx_eq_eps(subpaths(&o)[2].points[2].y, 144.528, 0.01));
}

#[test]
fn the_join_sits_on_the_outer_side_of_the_turn() {
    let o = stroke_to_path(&chevron(), 26.0, "butt", "bevel", 4.0);
    assert!(tuples_eq(subpaths(&o)[2].points[0], point(80.0, 120.0)));
    assert!(approx_eq_eps(subpaths(&o)[2].points[1].x, 68.976, 0.01));
    assert!(approx_eq_eps(subpaths(&o)[2].points[1].y, 126.89, 0.01));
    assert!(approx_eq_eps(subpaths(&o)[2].points[2].x, 91.024, 0.01));
    assert!(approx_eq_eps(subpaths(&o)[2].points[2].y, 126.89, 0.01));
}

#[test]
fn every_piece_winds_the_same_way_so_overlapping_pieces_add_instead_of_cancelling() {
    let mut hat = path();
    move_to(&mut hat, point(30.0, 120.0));
    line_to(&mut hat, point(80.0, 40.0));
    line_to(&mut hat, point(130.0, 120.0));
    let o = stroke_to_path(&hat, 26.0, "butt", "bevel", 4.0);

    assert!(approx_eq_eps(polygon_area(&o), -4981.625, 0.01));
    assert!(approx_eq_eps(
        polygon_area(&stroke_to_path(&chevron(), 26.0, "butt", "bevel", 4.0)),
        -4981.625,
        0.01
    ));
}

#[test]
fn a_wide_stroke_around_a_tight_bend_overlaps_itself_and_stays_solid() {
    let o = stroke_to_path(&u_turn(), 40.0, "butt", "round", 4.0);
    let cov = fill_path(&o, "nonzero", 100, 100);

    assert_eq!(subpaths(&o).len(), 15);
    assert_eq!(coverage_at(&cov, 50, 37), 1.0);
    assert_eq!(coverage_at(&cov, 46, 22), 1.0);
    assert_eq!(coverage_at(&cov, 53, 22), 1.0);
}

#[test]
fn a_closed_subpath_strokes_to_segments_and_joins_with_no_caps() {
    let mut tri = path();
    move_to(&mut tri, point(20.0, 20.0));
    line_to(&mut tri, point(80.0, 20.0));
    line_to(&mut tri, point(50.0, 70.0));
    renderer::close(&mut tri);
    let o = stroke_to_path(&tri, 8.0, "butt", "miter", 4.0);

    assert_eq!(subpaths(&o).len(), 6);
}

#[test]
fn a_round_cap_is_a_semicircle_of_sixteen_steps_whatever_the_rounding() {
    let mut seg = path();
    move_to(&mut seg, point(465.1115070868785, 303.45792752328475));
    line_to(&mut seg, point(464.47508947743773, 304.22927221043426));
    let o = stroke_to_path(&seg, 0.8, "round", "miter", 4.0);
    assert_eq!(subpaths(&o).len(), 3);
    assert_eq!(subpaths(&o)[1].points.len(), 17);
    assert_eq!(subpaths(&o)[2].points.len(), 17);
}
