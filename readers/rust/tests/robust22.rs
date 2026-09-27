// features/chapter22-robust.feature

use renderer::{combine, cross, point, point_lists, polygon, simplify};

fn float_crossing(
    a: renderer::Tuple,
    b: renderer::Tuple,
    c: renderer::Tuple,
    d: renderer::Tuple,
) -> renderer::Tuple {
    let t = cross(c - a, d - c) / cross(b - a, d - c);
    a + (b - a) * t
}

#[test]
fn a_crossing_computed_in_floating_point_is_on_neither_segment() {
    let a = point(2.6, 2.3);
    let b = point(10.0, 4.7);
    let c = point(8.4, 4.8);
    let d = point(6.4, 1.5);
    let p = float_crossing(a, b, c, d);
    assert_ne!(cross(b - a, p - a), 0.0);
    assert_ne!(cross(d - c, p - c), 0.0);
}

#[test]
fn squares_sharing_an_edge_unite_into_one_rectangle() {
    let a = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let b = polygon(&[point(10.0, 0.0), point(20.0, 0.0), point(20.0, 10.0), point(10.0, 10.0)]);
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "union")),
        vec![vec![point(0.0, 0.0), point(20.0, 0.0), point(20.0, 10.0), point(0.0, 10.0)]]
    );
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "intersection")),
        Vec::<Vec<renderer::Tuple>>::new()
    );
}

#[test]
fn squares_sharing_part_of_an_edge() {
    let a = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let b = polygon(&[point(10.0, 4.0), point(20.0, 4.0), point(20.0, 14.0), point(10.0, 14.0)]);
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "union")),
        vec![vec![
            point(0.0, 0.0),
            point(10.0, 0.0),
            point(10.0, 4.0),
            point(20.0, 4.0),
            point(20.0, 14.0),
            point(10.0, 14.0),
            point(10.0, 10.0),
            point(0.0, 10.0),
        ]]
    );
}

#[test]
fn squares_touching_at_a_corner_share_a_point_and_nothing_else() {
    let a = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let b = polygon(&[point(10.0, 10.0), point(20.0, 10.0), point(20.0, 20.0), point(10.0, 20.0)]);
    assert_eq!(point_lists(&combine(&a, "nonzero", &b, "nonzero", "union")).len(), 2);
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "intersection")),
        Vec::<Vec<renderer::Tuple>>::new()
    );
}

#[test]
fn two_triangles_that_share_only_their_top_point_stay_two_contours() {
    let a = polygon(&[point(5.0, 0.0), point(10.0, 8.0), point(7.0, 8.0)]);
    let b = polygon(&[point(5.0, 0.0), point(3.0, 8.0), point(0.0, 8.0)]);
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "union")),
        vec![
            vec![point(5.0, 0.0), point(3.0, 8.0), point(0.0, 8.0)],
            vec![point(5.0, 0.0), point(10.0, 8.0), point(7.0, 8.0)],
        ]
    );
}

#[test]
fn at_a_shared_corner_the_furthest_right_turn_is_not_the_first_edge_in_the_list() {
    let a = polygon(&[point(1.0, 0.0), point(3.0, 2.0), point(2.0, 4.0)]);
    let b = polygon(&[point(3.0, 2.0), point(4.0, 3.0), point(4.0, 4.0)]);
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "union")),
        vec![
            vec![point(1.0, 0.0), point(3.0, 2.0), point(2.0, 4.0)],
            vec![point(3.0, 2.0), point(4.0, 3.0), point(4.0, 4.0)],
        ]
    );
}

#[test]
fn a_corner_resting_on_an_edge() {
    let a = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]);
    let b = polygon(&[point(5.0, 10.0), point(8.0, 15.0), point(2.0, 15.0)]);
    assert_eq!(
        point_lists(&combine(&a, "nonzero", &b, "nonzero", "union")),
        vec![
            vec![point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)],
            vec![point(5.0, 10.0), point(8.0, 15.0), point(2.0, 15.0)],
        ]
    );
}

#[test]
fn a_spike_that_goes_out_and_comes_back_adds_nothing() {
    let p = polygon(&[
        point(0.0, 0.0),
        point(10.0, 0.0),
        point(10.0, 5.0),
        point(18.0, 5.0),
        point(10.0, 5.0),
        point(10.0, 10.0),
        point(0.0, 10.0),
    ]);
    assert_eq!(
        point_lists(&simplify(&p, "nonzero")),
        vec![vec![point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0), point(0.0, 10.0)]]
    );
}

#[test]
fn a_sliver_thinner_than_the_grid_is_gone_and_one_a_grid_unit_thick_stays() {
    let thin =
        polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 0.001), point(0.0, 0.001)]);
    assert_eq!(point_lists(&simplify(&thin, "nonzero")), Vec::<Vec<renderer::Tuple>>::new());
    let thick =
        polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 0.003), point(0.0, 0.003)]);
    assert_eq!(
        point_lists(&simplify(&thick, "nonzero")),
        vec![vec![
            point(0.0, 0.0),
            point(10.0, 0.0),
            point(10.0, 0.00390625),
            point(0.0, 0.00390625),
        ]]
    );
}
