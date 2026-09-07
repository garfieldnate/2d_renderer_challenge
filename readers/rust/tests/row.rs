// features/chapter07-row.feature

use renderer::{accumulate_row, accumulator, approx_eq, approx_eq_eps, area_at, cover_at};

#[test]
fn a_piece_that_stays_in_one_cell() {
    let mut acc = accumulator(4, 3);
    accumulate_row(&mut acc, 0, 1.5, 1.5, 1.0);
    assert!(approx_eq(area_at(&acc, 1, 0), 0.5));
    assert!(approx_eq(cover_at(&acc, 1, 0), 1.0));
}

#[test]
fn a_slanted_piece_in_one_cell_leans_its_area_toward_the_left() {
    let mut acc = accumulator(4, 3);
    accumulate_row(&mut acc, 0, 1.0, 1.5, 1.0);
    assert!(approx_eq(area_at(&acc, 1, 0), 0.75));
    assert!(approx_eq(cover_at(&acc, 1, 0), 1.0));
}

#[test]
fn a_piece_that_spans_several_cells_shares_its_height_by_width() {
    let mut acc = accumulator(4, 3);
    accumulate_row(&mut acc, 2, 0.0, 3.0, 1.0);
    assert!(approx_eq_eps(area_at(&acc, 0, 2), 0.1667, 0.0001));
    assert!(approx_eq_eps(area_at(&acc, 1, 2), 0.1667, 0.0001));
    assert!(approx_eq_eps(area_at(&acc, 2, 2), 0.1667, 0.0001));
    assert!(approx_eq_eps(cover_at(&acc, 0, 2), 0.3333, 0.0001));
    assert!(approx_eq_eps(cover_at(&acc, 1, 2), 0.3333, 0.0001));
    assert!(approx_eq_eps(cover_at(&acc, 2, 2), 0.3333, 0.0001));
}

#[test]
fn a_negative_height_deposits_negative_numbers() {
    let mut acc = accumulator(4, 3);
    accumulate_row(&mut acc, 0, 1.5, 1.5, -1.0);
    assert!(approx_eq(area_at(&acc, 1, 0), -0.5));
    assert!(approx_eq(cover_at(&acc, 1, 0), -1.0));
}
