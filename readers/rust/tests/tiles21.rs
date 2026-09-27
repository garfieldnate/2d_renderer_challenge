// features/chapter21-tiles.feature

use renderer::{
    classify_tiles, close, coverage_in, fill_path, fill_path_tiled, full_coverage, line_to, max_coverage_difference,
    move_to, path, point, polygon, stats, tile_count,
};

fn sq(x0: f64, y0: f64, x1: f64, y1: f64) -> renderer::Path {
    polygon(&[point(x0, y0), point(x1, y0), point(x1, y1), point(x0, y1)])
}

#[test]
fn a_square_leaves_its_middle_tiles_solid() {
    let t = classify_tiles(&sq(4.0, 4.0, 60.0, 60.0), "nonzero", 64, 64);
    assert_eq!(t[0], ["partial", "partial", "partial", "partial"]);
    assert_eq!(t[1], ["partial", "solid", "solid", "partial"]);
    assert_eq!(t[3], ["partial", "partial", "partial", "partial"]);
    assert_eq!(tile_count(&t, "solid"), 4);
}

#[test]
fn an_edge_on_a_tile_boundary_deposits_into_the_tile_on_its_right() {
    let t = classify_tiles(&sq(16.0, 16.0, 48.0, 48.0), "nonzero", 64, 64);
    assert_eq!(t[0], ["empty", "empty", "empty", "empty"]);
    assert_eq!(t[1], ["empty", "partial", "solid", "partial"]);
    assert_eq!(t[2], ["empty", "partial", "solid", "partial"]);
    assert_eq!(t[3], ["empty", "empty", "empty", "empty"]);
}

#[test]
fn a_horizontal_edge_makes_a_tile_partial_and_an_edge_off_the_canvas_deposits_nothing() {
    let t = classify_tiles(&sq(0.0, 0.0, 64.0, 40.0), "nonzero", 64, 64);
    assert_eq!(t[0], ["partial", "solid", "solid", "solid"]);
    assert_eq!(t[2], ["partial", "partial", "partial", "partial"]);
    assert_eq!(t[3], ["empty", "empty", "empty", "empty"]);
}

#[test]
fn the_fill_rule_decides_what_a_hole_is() {
    let mut ring = path();
    move_to(&mut ring, point(2.0, 2.0));
    line_to(&mut ring, point(62.0, 2.0));
    line_to(&mut ring, point(62.0, 62.0));
    line_to(&mut ring, point(2.0, 62.0));
    close(&mut ring);
    move_to(&mut ring, point(14.0, 14.0));
    line_to(&mut ring, point(50.0, 14.0));
    line_to(&mut ring, point(50.0, 50.0));
    line_to(&mut ring, point(14.0, 50.0));
    close(&mut ring);
    assert_eq!(classify_tiles(&ring, "nonzero", 64, 64)[1], ["partial", "solid", "solid", "partial"]);
    assert_eq!(classify_tiles(&ring, "evenodd", 64, 64)[1], ["partial", "empty", "empty", "partial"]);
}

#[test]
fn only_partial_tiles_are_resolved_and_the_coverage_agrees_with_chapter_7() {
    let mut st = stats();
    let s = sq(4.0, 4.0, 60.0, 60.0);
    let t = fill_path_tiled(&s, "nonzero", 64, 64, &mut st);
    assert_eq!(st.cells, 3072);
    assert_eq!(coverage_in(&t, 30, 30), 1.0);
    assert_eq!(coverage_in(&t, 2, 2), 0.0);
    assert_eq!(coverage_in(&t, 4, 30), 1.0);
    assert!(max_coverage_difference(&full_coverage(&t, 64, 64), &fill_path(&s, "nonzero", 64, 64)) <= 0.000001);
}

#[test]
fn a_tiny_shape_in_a_corner_of_a_canvas_cut_short() {
    let t = classify_tiles(&sq(3.0, 3.0, 5.0, 5.0), "nonzero", 40, 40);
    assert_eq!(t.len(), 3);
    assert_eq!(t[0].len(), 3);
    assert_eq!(t[0], ["partial", "empty", "empty"]);
    assert_eq!(tile_count(&t, "empty"), 8);
}
