// features/chapter20-numbers.feature

use renderer::{approx_eq, number_list, read_flag, read_number};

fn assert_list(actual: Vec<f64>, expected: &[f64]) {
    assert_eq!(actual.len(), expected.len(), "expected {expected:?}, got {actual:?}");
    for (a, e) in actual.iter().zip(expected) {
        assert!(approx_eq(*a, *e), "expected {expected:?}, got {actual:?}");
    }
}

fn assert_read(actual: (Option<f64>, usize), value: Option<f64>, index: usize) {
    assert_eq!(actual.1, index, "index: got {actual:?}");
    match (actual.0, value) {
        (Some(a), Some(e)) => assert!(approx_eq(a, e), "value: got {actual:?}"),
        (None, None) => {}
        _ => panic!("expected {value:?}, got {actual:?}"),
    }
}

#[test]
fn a_number_is_read_and_the_index_moves_past_it() {
    assert_read(read_number("12.5e1,3", 0), Some(125.0), 6);
    assert_read(read_number("M-.5", 1), Some(-0.5), 4);
    assert_read(read_number("x", 0), None, 0);
    assert_read(read_number("-", 0), None, 0);
    assert_read(read_number(".", 0), None, 0);
}

#[test]
fn signs_and_a_second_point_separate_numbers_without_any_space() {
    assert_list(number_list("10,20 30-40"), &[10.0, 20.0, 30.0, -40.0]);
    assert_list(number_list(".5.5"), &[0.5, 0.5]);
    assert_list(number_list("0.5.5.5"), &[0.5, 0.5, 0.5]);
    assert_list(number_list("+3 -0"), &[3.0, 0.0]);
}

#[test]
fn exponents_and_an_e_that_isnt_one() {
    assert_list(number_list("1e2 1E-1 -.5e+1"), &[100.0, 0.1, -5.0]);
    assert_list(number_list("1e5.5"), &[100000.0, 0.5]);
    assert_list(number_list("3."), &[3.0]);
    assert_list(number_list("1e"), &[1.0]);
}

#[test]
fn one_comma_between_numbers_and_the_list_stops_at_anything_else() {
    assert_list(number_list("5 , 6"), &[5.0, 6.0]);
    assert_list(number_list(" 5\t6\n7 "), &[5.0, 6.0, 7.0]);
    assert_list(number_list("5,,6"), &[5.0]);
    assert_list(number_list("1 2 x 3"), &[1.0, 2.0]);
    assert_list(number_list(""), &[]);
}

#[test]
fn a_flag_is_one_character_and_needs_no_separator() {
    assert_read(read_flag("0110", 0), Some(0.0), 1);
    assert_read(read_flag("0110", 1), Some(1.0), 2);
    assert_read(read_flag("2", 0), None, 0);
}
