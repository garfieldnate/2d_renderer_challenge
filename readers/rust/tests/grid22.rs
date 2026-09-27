// features/chapter22-grid.feature

use renderer::{combine, grid, lex_less, orient, point, point_lists, polygon, snap_point};

#[test]
fn a_coordinate_becomes_a_whole_number_of_grid_units_halves_up() {
    assert_eq!(grid(1.0), 256);
    assert_eq!(grid(0.5), 128);
    assert_eq!(grid(3.14159), 804);
    assert_eq!(grid(0.001953125), 1);
    assert_eq!(grid(-0.001953125), 0);
    assert_eq!(grid(0.0019), 0);
    assert_eq!(grid(-0.003), -1);
    assert_eq!(snap_point(point(2.5, -0.25)), point(640.0, -64.0));
}

#[test]
fn a_square_moved_a_millionth_of_a_pixel_snaps_back_onto_itself() {
    let a = polygon(&[point(10.0, 10.0), point(30.0, 10.0), point(30.0, 30.0), point(10.0, 30.0)]);
    let b = polygon(&[
        point(10.000001, 10.0),
        point(30.0, 10.000001),
        point(30.000001, 30.0),
        point(10.0, 30.000001),
    ]);
    let xor = combine(&a, "nonzero", &b, "nonzero", "xor");
    assert_eq!(point_lists(&xor), Vec::<Vec<renderer::Tuple>>::new());
    let union = combine(&a, "nonzero", &b, "nonzero", "union");
    assert_eq!(
        point_lists(&union),
        vec![vec![point(10.0, 10.0), point(30.0, 10.0), point(30.0, 30.0), point(10.0, 30.0)]]
    );
}

#[test]
fn orient_says_which_way_three_points_turn() {
    assert_eq!(orient(point(0.0, 0.0), point(256.0, 0.0), point(0.0, 256.0)), 65536.0);
    assert_eq!(orient(point(0.0, 0.0), point(256.0, 0.0), point(0.0, -256.0)), -65536.0);
    assert_eq!(orient(point(0.0, 0.0), point(256.0, 0.0), point(512.0, 0.0)), 0.0);
}

#[test]
fn orient_is_exact_at_the_far_corners_of_the_grid() {
    let a = point(-262144.0, -262144.0);
    let b = point(262144.0, 262143.0);
    let c = point(262143.0, 262142.0);
    assert_eq!(orient(a, b, c), -1.0);
    assert_eq!(orient(a, b, point(0.0, 0.0)), 262144.0);
    assert_eq!(orient(a, point(262144.0, 262144.0), point(0.0, 0.0)), 0.0);
}

#[test]
fn the_sweeps_order_is_top_to_bottom_then_left_to_right() {
    assert!(lex_less(point(5.0, 1.0), point(0.0, 2.0)));
    assert!(!lex_less(point(0.0, 2.0), point(5.0, 1.0)));
    assert!(lex_less(point(1.0, 3.0), point(2.0, 3.0)));
    assert!(!lex_less(point(2.0, 3.0), point(2.0, 3.0)));
}
