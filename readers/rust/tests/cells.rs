// features/chapter07-cells.feature

use renderer::{accumulator, add_cell, approx_eq, area_at, cover_at};

#[test]
fn a_fresh_accumulator_is_all_zeros() {
    let acc = accumulator(4, 3);
    assert_eq!(acc.width, 4);
    assert_eq!(acc.height, 3);
    assert!(approx_eq(area_at(&acc, 1, 0), 0.0));
    assert!(approx_eq(cover_at(&acc, 3, 2), 0.0));
}

#[test]
fn add_cell_deposits_an_area_and_a_cover() {
    let mut acc = accumulator(4, 3);
    add_cell(&mut acc, 1, 0, 0.3, 0.7);
    assert!(approx_eq(area_at(&acc, 1, 0), 0.3));
    assert!(approx_eq(cover_at(&acc, 1, 0), 0.7));
    assert!(approx_eq(area_at(&acc, 0, 0), 0.0));
    assert!(approx_eq(cover_at(&acc, 2, 0), 0.0));
}

#[test]
fn add_cell_accumulates_rather_than_overwrites() {
    let mut acc = accumulator(4, 3);
    add_cell(&mut acc, 2, 1, 0.25, 0.5);
    add_cell(&mut acc, 2, 1, 0.25, 0.5);
    assert!(approx_eq(area_at(&acc, 2, 1), 0.5));
    assert!(approx_eq(cover_at(&acc, 2, 1), 1.0));
}

#[test]
fn a_deposit_left_of_the_buffer_folds_onto_column_0_as_cover() {
    let mut acc = accumulator(4, 3);
    add_cell(&mut acc, -2, 0, 0.3, 0.7);
    assert!(approx_eq(area_at(&acc, 0, 0), 0.7));
    assert!(approx_eq(cover_at(&acc, 0, 0), 0.7));
}

#[test]
fn a_deposit_right_of_the_buffer_is_dropped() {
    let mut acc = accumulator(4, 3);
    add_cell(&mut acc, 9, 0, 0.3, 0.7);
    assert!(approx_eq(area_at(&acc, 3, 0), 0.0));
    assert!(approx_eq(cover_at(&acc, 3, 0), 0.0));
}
