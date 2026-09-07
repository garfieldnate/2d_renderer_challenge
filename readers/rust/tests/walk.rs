// features/chapter07-walk.feature

use renderer::{accumulate, accumulator, approx_eq, area_at, cover_at, point};

#[test]
fn an_edge_going_up_the_canvas_carries_a_positive_height() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(1.5, 3.0), point(1.5, 0.0));
    assert!(approx_eq(area_at(&acc, 1, 0), 0.5));
    assert!(approx_eq(cover_at(&acc, 1, 0), 1.0));
    assert!(approx_eq(area_at(&acc, 1, 1), 0.5));
    assert!(approx_eq(cover_at(&acc, 1, 2), 1.0));
}

#[test]
fn the_same_edge_going_down_carries_a_negative_height() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(1.5, 0.0), point(1.5, 3.0));
    assert!(approx_eq(area_at(&acc, 1, 0), -0.5));
    assert!(approx_eq(cover_at(&acc, 1, 1), -1.0));
}

#[test]
fn a_partial_height_edge_deposits_only_its_height() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(1.5, 0.75), point(1.5, 0.25));
    assert!(approx_eq(area_at(&acc, 1, 0), 0.25));
    assert!(approx_eq(cover_at(&acc, 1, 0), 0.5));
    assert!(approx_eq(cover_at(&acc, 1, 1), 0.0));
}

#[test]
fn an_edge_that_crosses_several_rows_is_clipped_to_each() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(1.5, 2.5), point(1.5, 0.5));
    assert!(approx_eq(cover_at(&acc, 1, 0), 0.5));
    assert!(approx_eq(cover_at(&acc, 1, 1), 1.0));
    assert!(approx_eq(cover_at(&acc, 1, 2), 0.5));
}

#[test]
fn an_edge_reaching_above_and_below_the_buffer_fills_every_row_it_can() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(1.5, 5.0), point(1.5, -2.0));
    assert!(approx_eq(cover_at(&acc, 1, 0), 1.0));
    assert!(approx_eq(cover_at(&acc, 1, 1), 1.0));
    assert!(approx_eq(cover_at(&acc, 1, 2), 1.0));
}

#[test]
fn a_horizontal_edge_deposits_nothing() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(0.0, 1.0), point(3.0, 1.0));
    assert!(approx_eq(area_at(&acc, 1, 1), 0.0));
    assert!(approx_eq(cover_at(&acc, 1, 1), 0.0));
}

#[test]
fn an_edge_entirely_left_of_the_buffer_covers_every_cell_to_its_right() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(-3.0, 3.0), point(-3.0, 0.0));
    assert!(approx_eq(area_at(&acc, 0, 0), 1.0));
    assert!(approx_eq(cover_at(&acc, 0, 0), 1.0));
    assert!(approx_eq(area_at(&acc, 1, 0), 0.0));
}

#[test]
fn an_edge_entirely_right_of_the_buffer_deposits_nothing() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(10.0, 3.0), point(10.0, 0.0));
    assert!(approx_eq(area_at(&acc, 3, 0), 0.0));
    assert!(approx_eq(cover_at(&acc, 3, 0), 0.0));
}
