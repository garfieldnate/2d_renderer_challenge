// features/chapter20-transform.feature

use renderer::{identity, matrices_eq, matrix3, parse_transform, point, tuples_eq};

fn t(s: &str) -> renderer::Matrix3 {
    parse_transform(Some(s))
}

#[test]
fn matrix_lists_its_six_numbers_column_by_column() {
    let m = t("matrix(1 2 3 4 5 6)");
    assert!(matrices_eq(&m, &matrix3(1.0, 3.0, 5.0, 2.0, 4.0, 6.0, 0.0, 0.0, 1.0)));
}

#[test]
fn translate_scale_and_their_one_number_forms() {
    assert!(tuples_eq(t("translate(10 20)") * point(1.0, 1.0), point(11.0, 21.0)));
    assert!(tuples_eq(t("translate(10)") * point(1.0, 1.0), point(11.0, 1.0)));
    assert!(tuples_eq(t("scale(2)") * point(1.0, 1.0), point(2.0, 2.0)));
    assert!(tuples_eq(t("scale(2,3)") * point(1.0, 1.0), point(2.0, 3.0)));
    assert!(tuples_eq(t("translate(1e1 -2e0)") * point(1.0, 1.0), point(11.0, -1.0)));
}

#[test]
fn rotate_is_in_degrees_clockwise_on_screen_and_can_turn_about_a_point() {
    assert!(tuples_eq(t("rotate(90)") * point(1.0, 1.0), point(-1.0, 1.0)));
    assert!(tuples_eq(t("rotate(90 10 10)") * point(1.0, 1.0), point(19.0, 1.0)));
    assert!(tuples_eq(t("rotate(90 10 10)") * point(10.0, 10.0), point(10.0, 10.0)));
}

#[test]
fn skewx_leans_x_with_y_skewy_leans_y_with_x() {
    assert!(tuples_eq(t("skewX(45)") * point(1.0, 1.0), point(2.0, 1.0)));
    assert!(tuples_eq(t("skewY(45)") * point(1.0, 1.0), point(1.0, 2.0)));
    assert!(tuples_eq(t("skewX(45)") * point(1.0, 0.0), point(1.0, 0.0)));
}

#[test]
fn a_list_applies_right_to_left() {
    assert!(tuples_eq(t("translate(10,20) scale(2)") * point(1.0, 1.0), point(12.0, 22.0)));
    assert!(tuples_eq(t("scale(2) translate(10,20)") * point(1.0, 1.0), point(22.0, 42.0)));
    assert!(matrices_eq(&t("translate(10 20),scale(2)"), &t("translate(10 20) scale(2)")));
    assert!(tuples_eq(t("translate(10 20)rotate(90)") * point(1.0, 1.0), point(9.0, 21.0)));
    assert!(tuples_eq(t("translate (5 5)") * point(1.0, 1.0), point(6.0, 6.0)));
}

#[test]
fn nothing_or_anything_broken_is_the_identity() {
    assert!(matrices_eq(&t(""), &identity()));
    assert!(matrices_eq(&parse_transform(None), &identity()));
    assert!(matrices_eq(&t("rotate(30 1)"), &identity()));
    assert!(matrices_eq(&t("translate(1 2) bogus(3)"), &identity()));
    assert!(matrices_eq(&t("scale(2"), &identity()));
}
