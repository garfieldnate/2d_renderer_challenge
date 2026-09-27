// features/chapter23-primitives.feature

use renderer::{approx_eq_eps, point, polygon, sd_box, sd_circle, sd_polygon, sd_rounded_box, star};

#[test]
fn a_circle() {
    assert_eq!(sd_circle(point(3.0, 4.0), point(0.0, 0.0), 2.0), 3.0);
    assert_eq!(sd_circle(point(1.0, 0.0), point(0.0, 0.0), 2.0), -1.0);
    assert_eq!(sd_circle(point(2.0, 0.0), point(0.0, 0.0), 2.0), 0.0);
}

#[test]
fn a_segment_beside_it_and_beyond_its_ends() {
    use renderer::distance_to_segment;
    assert_eq!(distance_to_segment(point(5.0, 3.0), point(0.0, 0.0), point(10.0, 0.0)), 3.0);
    assert_eq!(distance_to_segment(point(-3.0, 4.0), point(0.0, 0.0), point(10.0, 0.0)), 5.0);
    assert_eq!(distance_to_segment(point(13.0, -4.0), point(0.0, 0.0), point(10.0, 0.0)), 5.0);
    assert_eq!(distance_to_segment(point(3.0, 4.0), point(0.0, 0.0), point(0.0, 0.0)), 5.0);
}

#[test]
fn a_box_beside_a_side_off_a_corner_and_inside() {
    assert_eq!(sd_box(point(13.0, 0.0), point(0.0, 0.0), 10.0, 5.0), 3.0);
    assert_eq!(sd_box(point(13.0, 9.0), point(0.0, 0.0), 10.0, 5.0), 5.0);
    assert_eq!(sd_box(point(2.0, 1.0), point(0.0, 0.0), 10.0, 5.0), -4.0);
    assert_eq!(sd_box(point(-2.0, -4.0), point(0.0, 0.0), 10.0, 5.0), -1.0);
}

#[test]
fn rounding_a_box_rounds_its_corners_and_nothing_else() {
    assert!(approx_eq_eps(
        sd_rounded_box(point(13.0, 9.0), point(0.0, 0.0), 10.0, 5.0, 2.0),
        5.810250,
        0.000001
    ));
    assert_eq!(sd_rounded_box(point(13.0, 0.0), point(0.0, 0.0), 10.0, 5.0, 2.0), 3.0);
    assert_eq!(sd_rounded_box(point(0.0, 0.0), point(0.0, 0.0), 10.0, 5.0, 2.0), -5.0);
}

#[test]
fn a_polygons_sign_comes_from_chapter_5s_winding_number() {
    let sq = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    assert_eq!(sd_polygon(point(5.0, 3.0), &sq, "nonzero"), -3.0);
    assert_eq!(sd_polygon(point(13.0, 14.0), &sq, "nonzero"), 5.0);
    assert!(approx_eq_eps(sd_polygon(point(80.5, 80.5), &star(), "nonzero"), -21.631190, 0.000001));
    assert!(approx_eq_eps(sd_polygon(point(80.5, 80.5), &star(), "evenodd"), 21.631190, 0.000001));
}
