// features/chapter04-matrices.feature

use renderer::{
    approx_eq, determinant, identity, inverse, is_invertible, matrices_eq, matrix3, matrix_at,
    point, rotation, scaling, transpose, translation, tuples_eq, vector,
};

#[test]
fn constructing_and_inspecting_a_matrix() {
    // Given the following matrix M:
    //   | 1 | 2 | 3 |
    //   | 4 | 5 | 6 |
    //   | 7 | 8 | 9 |
    let m = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
    assert!(approx_eq(matrix_at(&m, 0, 0), 1.0));
    assert!(approx_eq(matrix_at(&m, 0, 2), 3.0));
    assert!(approx_eq(matrix_at(&m, 1, 0), 4.0));
    assert!(approx_eq(matrix_at(&m, 1, 1), 5.0));
    assert!(approx_eq(matrix_at(&m, 2, 0), 7.0));
    assert!(approx_eq(matrix_at(&m, 2, 2), 9.0));
    assert!(matrices_eq(&m, &matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0)));
}

#[test]
fn matrix_equality_with_identical_matrices() {
    let a = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
    let b = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
    assert!(matrices_eq(&a, &b));
}

#[test]
fn matrix_equality_with_different_matrices() {
    let a = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
    let b = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 8.0);
    assert!(!matrices_eq(&a, &b));
}

#[test]
fn multiplying_two_matrices() {
    // Given the following matrix A:
    //   | 1 | 2 | 3 |
    //   | 4 | 5 | 6 |
    //   | 7 | 8 | 9 |
    let a = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
    // And the following matrix B:
    //   | 2 | -1 | 0 |
    //   | 1 |  3 | 1 |
    //   | 0 |  1 | 2 |
    let b = matrix3(2.0, -1.0, 0.0, 1.0, 3.0, 1.0, 0.0, 1.0, 2.0);
    // Then A * B is the following matrix:
    //   |  4 |  8 |  8 |
    //   | 13 | 17 | 17 |
    //   | 22 | 26 | 26 |
    let expected = matrix3(4.0, 8.0, 8.0, 13.0, 17.0, 17.0, 22.0, 26.0, 26.0);
    assert!(matrices_eq(&(a * b), &expected));
}

#[test]
fn matrix_multiplication_is_not_commutative() {
    let a = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
    let b = matrix3(2.0, -1.0, 0.0, 1.0, 3.0, 1.0, 0.0, 1.0, 2.0);
    assert!(!matrices_eq(&(a * b), &(b * a)));
}

#[test]
fn a_matrix_multiplied_by_a_point() {
    // Given the following matrix A:
    //   | 1 | 2 | 3 |
    //   | 4 | 5 | 6 |
    //   | 0 | 0 | 1 |
    let a = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 0.0, 0.0, 1.0);
    let p = point(1.0, 2.0);
    assert!(tuples_eq(a * p, point(8.0, 20.0)));
}

#[test]
fn a_matrix_multiplied_by_a_vector_ignores_the_last_column() {
    let a = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 0.0, 0.0, 1.0);
    let v = vector(1.0, 2.0);
    assert!(tuples_eq(a * v, vector(5.0, 14.0)));
}

#[test]
fn multiplying_by_the_identity_matrix_changes_nothing() {
    let a = matrix3(0.0, 1.0, 2.0, 1.0, 2.0, 4.0, 2.0, 4.0, 8.0);
    let p = point(1.0, 2.0);
    assert!(matrices_eq(&(a * identity()), &a));
    assert!(matrices_eq(&(identity() * a), &a));
    assert!(tuples_eq(identity() * p, p));
}

#[test]
fn transposing_a_matrix() {
    // Given the following matrix A:
    //   | 0 | 9 | 3 |
    //   | 9 | 8 | 0 |
    //   | 1 | 8 | 5 |
    let a = matrix3(0.0, 9.0, 3.0, 9.0, 8.0, 0.0, 1.0, 8.0, 5.0);
    // Then transpose(A) is the following matrix:
    //   | 0 | 9 | 1 |
    //   | 9 | 8 | 8 |
    //   | 3 | 0 | 5 |
    let expected = matrix3(0.0, 9.0, 1.0, 9.0, 8.0, 8.0, 3.0, 0.0, 5.0);
    assert!(matrices_eq(&transpose(a), &expected));
}

#[test]
fn transposing_the_identity_matrix() {
    assert!(matrices_eq(&transpose(identity()), &identity()));
}

#[test]
fn the_determinant_of_a_3_by_3_matrix() {
    // Given the following matrix A:
    //   |  1 | 2 |  6 |
    //   | -5 | 8 | -4 |
    //   |  2 | 6 |  4 |
    let a = matrix3(1.0, 2.0, 6.0, -5.0, 8.0, -4.0, 2.0, 6.0, 4.0);
    assert!(approx_eq(determinant(a), -196.0));
}

#[test]
fn the_determinant_of_a_transform_is_the_area_factor() {
    assert!(approx_eq(determinant(identity()), 1.0));
    assert!(approx_eq(determinant(scaling(2.0, 3.0)), 6.0));
    assert!(approx_eq(determinant(rotation(0.7)), 1.0));
    assert!(approx_eq(determinant(translation(4.0, 9.0)), 1.0));
    assert!(approx_eq(determinant(scaling(-1.0, 1.0)), -1.0));
}

#[test]
fn testing_an_invertible_matrix_for_invertibility() {
    // Given the following matrix A:
    //   | 3 | 0 |  2 |
    //   | 2 | 0 | -2 |
    //   | 0 | 1 |  1 |
    let a = matrix3(3.0, 0.0, 2.0, 2.0, 0.0, -2.0, 0.0, 1.0, 1.0);
    assert!(approx_eq(determinant(a), 10.0));
    assert!(is_invertible(a));
}

#[test]
fn testing_a_non_invertible_matrix_for_invertibility() {
    // Given the following matrix A:
    //   | 1 | 2 | 3 |
    //   | 2 | 4 | 6 |
    //   | 0 | 0 | 1 |
    let a = matrix3(1.0, 2.0, 3.0, 2.0, 4.0, 6.0, 0.0, 0.0, 1.0);
    assert!(approx_eq(determinant(a), 0.0));
    assert!(!is_invertible(a));
}

#[test]
fn calculating_the_inverse_of_a_matrix() {
    // Given the following matrix A:
    //   | 3 | 0 |  2 |
    //   | 2 | 0 | -2 |
    //   | 0 | 1 |  1 |
    let a = matrix3(3.0, 0.0, 2.0, 2.0, 0.0, -2.0, 0.0, 1.0, 1.0);
    let b = inverse(a);
    assert!(approx_eq(matrix_at(&b, 0, 0), 0.2));
    assert!(approx_eq(matrix_at(&b, 1, 2), 1.0));
    assert!(approx_eq(matrix_at(&b, 2, 1), -0.3));
    // And B is the following matrix:
    //   |  0.2 |  0.2 | 0 |
    //   | -0.2 |  0.3 | 1 |
    //   |  0.2 | -0.3 | 0 |
    let expected = matrix3(0.2, 0.2, 0.0, -0.2, 0.3, 1.0, 0.2, -0.3, 0.0);
    assert!(matrices_eq(&b, &expected));
    assert!(matrices_eq(&(a * b), &identity()));
}

#[test]
fn multiplying_a_product_by_its_inverse() {
    let a = matrix3(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
    let b = matrix3(2.0, -1.0, 0.0, 1.0, 3.0, 1.0, 0.0, 1.0, 2.0);
    let c = a * b;
    assert!(matrices_eq(&(c * inverse(b)), &a));
}

#[test]
fn the_inverse_of_a_transform_is_a_transform() {
    let a = translation(5.0, -3.0) * rotation(std::f64::consts::PI / 6.0) * scaling(2.0, 3.0);
    let b = inverse(a);
    assert!(approx_eq(matrix_at(&b, 2, 0), 0.0));
    assert!(approx_eq(matrix_at(&b, 2, 1), 0.0));
    assert!(approx_eq(matrix_at(&b, 2, 2), 1.0));
    assert!(approx_eq(matrix_at(&b, 0, 0), 0.4330));
    assert!(approx_eq(matrix_at(&b, 0, 2), -1.4151));
    assert!(approx_eq(matrix_at(&b, 1, 2), 1.6994));
    assert!(matrices_eq(&(b * a), &identity()));
}

#[test]
fn invertibility_is_an_exact_test_against_zero() {
    assert!(is_invertible(scaling(0.0001, 1.0)));
    assert!(approx_eq(determinant(scaling(0.0001, 1.0)), 0.0001));
    assert!(tuples_eq(inverse(scaling(0.0001, 1.0)) * point(0.0001, 3.0), point(1.0, 3.0)));
}
