// features/chapter14-stroke.feature

use renderer::{
    approx_eq_eps, distance_to_curve, fill_path, flatten_then_stroke, hairpin, inside_evenodd,
    inside_nonzero, max_coverage_difference, offset_point, point, point_count, round,
    stroke_curve_to_path, subpaths, tuples_eq,
};

#[test]
fn the_stroke_of_a_curve_is_one_closed_subpath_right_offset_out_and_left_offset_back() {
    let o = stroke_curve_to_path(&hairpin(), 60.0, "butt", 0.25);

    assert_eq!(subpaths(&o).len(), 1);
    assert!(subpaths(&o)[0].closed);
    assert_eq!(subpaths(&o)[0].points.len(), 58);
    assert!(tuples_eq(subpaths(&o)[0].points[0], offset_point(&hairpin(), 0.0, 30.0)));
    assert!(tuples_eq(subpaths(&o)[0].points[57], offset_point(&hairpin(), 0.0, -30.0)));
    assert!(approx_eq_eps(subpaths(&o)[0].points[0].x, 64.5435, 0.001));
    assert!(approx_eq_eps(subpaths(&o)[0].points[0].y, 145.214, 0.001));
}

#[test]
fn the_folds_tip_lands_exactly_on_a_half_and_is_drawn_one_row_down() {
    let o = stroke_curve_to_path(&hairpin(), 60.0, "butt", 0.25);

    assert!(tuples_eq(subpaths(&o)[0].points[13], point(80.0, 42.5)));
    assert!(tuples_eq(subpaths(&o)[0].points[42], point(80.0, -17.5)));
    assert_eq!(round(42.5), 43);
    assert_eq!(round(-17.5), -17);
}

#[test]
fn caps_add_their_points_to_the_same_outline() {
    assert_eq!(point_count(&stroke_curve_to_path(&hairpin(), 60.0, "round", 0.25)), 88);
    assert_eq!(point_count(&stroke_curve_to_path(&hairpin(), 60.0, "square", 0.25)), 62);
}

#[test]
fn flattening_first_gives_the_same_picture_from_many_more_pieces() {
    let o = stroke_curve_to_path(&hairpin(), 60.0, "butt", 0.25);
    let f = flatten_then_stroke(&hairpin(), 60.0, "butt", 0.25);

    assert_eq!(subpaths(&f).len(), 43);
    assert_eq!(point_count(&f), 172);
    assert_eq!(point_count(&o), 58);
    assert!(
        max_coverage_difference(
            &fill_path(&o, "nonzero", 160, 160),
            &fill_path(&f, "nonzero", 160, 160)
        ) <= 0.6
    );
}

#[test]
fn the_inner_offset_folds_into_a_loop_and_nonzero_fills_it() {
    let o = stroke_curve_to_path(&hairpin(), 60.0, "butt", 0.25);

    assert_eq!(renderer::cusps(&hairpin(), 30.0).len(), 2);
    assert_eq!(renderer::cusps(&hairpin(), -30.0).len(), 0);

    assert!(approx_eq_eps(distance_to_curve(&hairpin(), point(80.5, 60.5)), 25.967, 0.01));
    assert!(inside_nonzero(&o, 80.5, 60.5));
    assert!(!inside_evenodd(&o, 80.5, 60.5));

    assert!(approx_eq_eps(distance_to_curve(&hairpin(), point(80.5, 30.5)), 14.503, 0.01));
    assert!(inside_nonzero(&o, 80.5, 30.5));
    assert!(inside_evenodd(&o, 80.5, 30.5));

    assert!(approx_eq_eps(distance_to_curve(&hairpin(), point(80.5, 85.5)), 32.626, 0.01));
    assert!(!inside_nonzero(&o, 80.5, 85.5));
}
