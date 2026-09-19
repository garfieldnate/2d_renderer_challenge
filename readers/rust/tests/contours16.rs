// features/chapter16-contours.feature

use renderer::{contour_curves, implied_points, load_font, point, read_file, tuples_eq};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn a_loop_of_off_curve_points_implies_a_midpoint_between_each_pair() {
    let c = vec![(0.0, 0.0, false), (10.0, 0.0, false), (10.0, 10.0, false), (0.0, 10.0, false)];
    let pts = implied_points(&c);
    assert_eq!(pts.len(), 8);
    assert_eq!(pts[0], (5.0, 0.0, true));
    assert_eq!(pts[1], (10.0, 0.0, false));
    assert_eq!(pts[2], (10.0, 5.0, true));
    assert_eq!(pts[7], (0.0, 0.0, false));

    let curves = contour_curves(&c);
    assert_eq!(curves.len(), 4);
    assert!(tuples_eq(curves[0].points[0], point(5.0, 0.0)));
    assert!(tuples_eq(curves[0].points[1], point(10.0, 0.0)));
    assert!(tuples_eq(curves[0].points[2], point(10.0, 5.0)));
}

#[test]
fn a_loop_that_starts_off_curve_is_rotated_to_start_on_curve() {
    let c = vec![(10.0, 0.0, false), (10.0, 10.0, true), (0.0, 10.0, true), (0.0, 0.0, true)];
    let pts = implied_points(&c);
    assert_eq!(pts.len(), 4);
    assert_eq!(pts[0], (10.0, 10.0, true));
    assert_eq!(pts[3], (10.0, 0.0, false));
}

#[test]
fn straight_edges_become_quadratics_through_their_midpoints() {
    let c = vec![(0.0, 0.0, true), (10.0, 0.0, true), (5.0, 8.0, true)];
    let curves = contour_curves(&c);
    assert_eq!(curves.len(), 3);
    assert!(tuples_eq(curves[0].points[1], point(5.0, 0.0)));
    assert!(tuples_eq(curves[1].points[1], point(7.5, 4.0)));
    assert!(tuples_eq(curves[2].points[0], point(5.0, 8.0)));
    assert!(tuples_eq(curves[2].points[2], point(0.0, 0.0)));
}

#[test]
fn mixed_points_on_off_off_on() {
    let c = vec![(0.0, 0.0, true), (10.0, 0.0, false), (10.0, 10.0, false), (0.0, 10.0, true)];
    assert_eq!(implied_points(&c).len(), 5);
    assert_eq!(implied_points(&c)[2], (10.0, 5.0, true));

    let curves = contour_curves(&c);
    assert_eq!(curves.len(), 3);
    assert!(tuples_eq(curves[0].points[2], point(10.0, 5.0)));
    assert!(tuples_eq(curves[1].points[0], point(10.0, 5.0)));
    assert!(tuples_eq(curves[2].points[1], point(0.0, 5.0)));
}

#[test]
fn the_dot_of_the_i_is_mostly_implied() {
    let f = font();
    let dot = f.glyphs["i"].contours[1].clone();
    assert_eq!(dot.len(), 9);
    assert_eq!(implied_points(&dot).len(), 16);
    assert_eq!(implied_points(&dot)[2], (168.5, 1445.0, true));

    let curves = contour_curves(&dot);
    assert_eq!(curves.len(), 8);
    assert!(tuples_eq(curves[1].points[0], point(168.5, 1445.0)));
    assert!(tuples_eq(curves[1].points[1], point(196.0, 1476.0)));
    assert!(tuples_eq(curves[1].points[2], point(250.0, 1476.0)));

    assert_eq!(contour_curves(&f.glyphs["i"].contours[0]).len(), 4);
    assert_eq!(contour_curves(&f.glyphs["o"].contours[0]).len(), 12);
}
