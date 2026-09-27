// features/chapter22-combine.feature

use renderer::{
    approx_eq_eps, combine, fill_path, max_coverage_difference, path, point, point_lists,
    polygon, polygon_area, simplify, star, stitch,
};

fn font() -> renderer::Font {
    renderer::load_font(renderer::read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn stitching_follows_the_pairs_and_drops_the_straight_vertex() {
    let c = stitch(&[
        (point(4.0, 4.0), point(0.0, 4.0)),
        (point(0.0, 0.0), point(2.0, 0.0)),
        (point(0.0, 4.0), point(0.0, 0.0)),
        (point(4.0, 0.0), point(4.0, 4.0)),
        (point(2.0, 0.0), point(4.0, 0.0)),
    ]);
    assert_eq!(c, vec![vec![point(0.0, 0.0), point(4.0, 0.0), point(4.0, 4.0), point(0.0, 4.0)]]);
}

#[test]
fn turning_furthest_right_keeps_two_squares_that_touch_at_a_corner_apart() {
    let c = stitch(&[
        (point(0.0, 0.0), point(4.0, 0.0)),
        (point(4.0, 0.0), point(4.0, 4.0)),
        (point(4.0, 4.0), point(0.0, 4.0)),
        (point(0.0, 4.0), point(0.0, 0.0)),
        (point(4.0, 4.0), point(8.0, 4.0)),
        (point(8.0, 4.0), point(8.0, 8.0)),
        (point(8.0, 8.0), point(4.0, 8.0)),
        (point(4.0, 8.0), point(4.0, 4.0)),
    ]);
    assert_eq!(
        c,
        vec![
            vec![point(0.0, 0.0), point(4.0, 0.0), point(4.0, 4.0), point(0.0, 4.0)],
            vec![point(4.0, 4.0), point(8.0, 4.0), point(8.0, 8.0), point(4.0, 8.0)],
        ]
    );
}

fn two_squares() -> (renderer::Path, renderer::Path) {
    (
        polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]),
        polygon(&[point(5.0, 5.0), point(15.0, 5.0), point(15.0, 15.0), point(5.0, 15.0)]),
    )
}

#[test]
fn two_squares_four_ways() {
    let (a, b) = two_squares();
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "union")),
        vec![vec![
            point(0.0, 0.0),
            point(10.0, 0.0),
            point(10.0, 5.0),
            point(15.0, 5.0),
            point(15.0, 15.0),
            point(5.0, 15.0),
            point(5.0, 10.0),
            point(0.0, 10.0),
        ]]
    );
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "intersection")),
        vec![vec![point(5.0, 5.0), point(10.0, 5.0), point(10.0, 10.0), point(5.0, 10.0)]]
    );
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "difference")),
        vec![vec![
            point(0.0, 0.0),
            point(10.0, 0.0),
            point(10.0, 5.0),
            point(5.0, 5.0),
            point(5.0, 10.0),
            point(0.0, 10.0),
        ]]
    );
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "xor")),
        vec![
            vec![
                point(0.0, 0.0),
                point(10.0, 0.0),
                point(10.0, 5.0),
                point(5.0, 5.0),
                point(5.0, 10.0),
                point(0.0, 10.0),
            ],
            vec![
                point(10.0, 5.0),
                point(15.0, 5.0),
                point(15.0, 15.0),
                point(5.0, 15.0),
                point(5.0, 10.0),
                point(10.0, 10.0),
            ],
        ]
    );
}

#[test]
fn the_result_winds_clockwise_whichever_way_the_input_wound() {
    let ccw = polygon(&[point(0.0, 0.0), point(0.0, 10.0), point(10.0, 10.0), point(10.0, 0.0)]);
    assert_eq!(polygon_area(&ccw), -100.0);
    assert_eq!(
        point_lists(&simplify(&ccw, "nonzero")),
        vec![vec![point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]]
    );
    assert_eq!(polygon_area(&simplify(&ccw, "nonzero")), 100.0);
}

#[test]
fn a_hole_winds_the_other_way() {
    let outer = polygon(&[point(0.0, 0.0), point(12.0, 0.0), point(12.0, 12.0), point(0.0, 12.0)]);
    let inner = polygon(&[point(4.0, 4.0), point(8.0, 4.0), point(8.0, 8.0), point(4.0, 8.0)]);
    let r = combine(&outer, "nonzero", &inner, "nonzero", "difference");
    assert_eq!(
        point_lists(&r),
        vec![
            vec![point(0.0, 0.0), point(12.0, 0.0), point(12.0, 12.0), point(0.0, 12.0)],
            vec![point(4.0, 4.0), point(4.0, 8.0), point(8.0, 8.0), point(8.0, 4.0)],
        ]
    );
    assert_eq!(polygon_area(&r), 128.0);
}

#[test]
fn one_paths_own_overlaps_are_resolved_by_its_fill_rule() {
    let mut p = path();
    renderer::move_to(&mut p, point(0.0, 0.0));
    renderer::line_to(&mut p, point(10.0, 0.0));
    renderer::line_to(&mut p, point(10.0, 10.0));
    renderer::line_to(&mut p, point(0.0, 10.0));
    renderer::close(&mut p);
    renderer::move_to(&mut p, point(5.0, 5.0));
    renderer::line_to(&mut p, point(15.0, 5.0));
    renderer::line_to(&mut p, point(15.0, 15.0));
    renderer::line_to(&mut p, point(5.0, 15.0));
    renderer::close(&mut p);

    assert_eq!(
        point_lists(&simplify(&p, "nonzero")),
        vec![vec![
            point(0.0, 0.0),
            point(10.0, 0.0),
            point(10.0, 5.0),
            point(15.0, 5.0),
            point(15.0, 15.0),
            point(5.0, 15.0),
            point(5.0, 10.0),
            point(0.0, 10.0),
        ]]
    );
    assert_eq!(point_lists(&simplify(&p, "evenodd")).len(), 2);
    assert_eq!(polygon_area(&simplify(&p, "evenodd")), 150.0);
}

#[test]
fn the_stars_crossings_become_corners() {
    assert_eq!(
        point_lists(&simplify(&star(), "nonzero")),
        vec![vec![
            point(80.5, 10.5),
            point(96.21484375, 58.8671875),
            point(147.07421875, 58.8671875),
            point(105.9296875, 88.76171875),
            point(121.64453125, 137.1328125),
            point(80.5, 107.23828125),
            point(39.35546875, 137.1328125),
            point(55.0703125, 88.76171875),
            point(13.92578125, 58.8671875),
            point(64.78515625, 58.8671875),
        ]]
    );
    assert_eq!(point_lists(&simplify(&star(), "evenodd")).len(), 5);
    assert!(approx_eq_eps(polygon_area(&simplify(&star(), "nonzero")), 5500.767746, 0.000001));
    assert!(approx_eq_eps(polygon_area(&simplify(&star(), "evenodd")), 3800.918060, 0.000001));
}

#[test]
fn a_shape_with_itself() {
    let a = renderer::plate_glyph();
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &a, "nonzero", "union")),
        point_lists(&simplify(&a, "nonzero"))
    );
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &a, "nonzero", "intersection")),
        point_lists(&simplify(&a, "nonzero"))
    );
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &a, "nonzero", "difference")),
        Vec::<Vec<renderer::Tuple>>::new()
    );
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &a, "nonzero", "xor")),
        Vec::<Vec<renderer::Tuple>>::new()
    );
}

#[test]
fn the_areas_add_up() {
    let _ = font();
    let a = renderer::plate_glyph();
    let b = renderer::plate_star();
    let union = polygon_area(&combine(&a, "nonzero", &b, "evenodd", "union"));
    let both = polygon_area(&combine(&a, "nonzero", &b, "evenodd", "intersection"));
    let a_only = polygon_area(&combine(&a, "nonzero", &b, "evenodd", "difference"));
    let b_only = polygon_area(&combine(&b, "evenodd", &a, "nonzero", "difference"));
    let either = polygon_area(&combine(&a, "nonzero", &b, "evenodd", "xor"));
    assert!(approx_eq_eps(union, either + both, 0.000001));
    assert!(approx_eq_eps(union, a_only + b_only + both, 0.000001));
    assert!(approx_eq_eps(
        union + both,
        polygon_area(&simplify(&a, "nonzero")) + polygon_area(&simplify(&b, "evenodd")),
        0.05
    ));
}

#[test]
fn either_fill_rule_fills_the_result_the_same() {
    let r = combine(&renderer::plate_glyph(), "nonzero", &renderer::plate_star(), "evenodd", "xor");
    assert!(
        max_coverage_difference(
            &fill_path(&r, "nonzero", 200, 200),
            &fill_path(&r, "evenodd", 200, 200)
        ) <= 0.000001
    );
}
