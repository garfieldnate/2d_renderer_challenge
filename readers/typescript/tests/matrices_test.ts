// features/chapter04-matrices.feature
import {
  at,
  determinant,
  identity,
  inverse,
  is_invertible,
  matrix3,
  multiply,
  multiply_tuple,
  rotation,
  scaling,
  transpose,
  translation,
} from "../src/matrix.ts";
import { point, vector } from "../src/tuple.ts";
import { assert_eq, assert_matrix, assert_matrix_ne, assert_true, assert_tuple } from "../src/assert.ts";

Deno.test("Constructing and inspecting a matrix", () => {
  const M = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  assert_eq(at(M, 0, 0), 1);
  assert_eq(at(M, 0, 2), 3);
  assert_eq(at(M, 1, 0), 4);
  assert_eq(at(M, 1, 1), 5);
  assert_eq(at(M, 2, 0), 7);
  assert_eq(at(M, 2, 2), 9);
  assert_matrix(M, matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9));
});

Deno.test("Matrix equality with identical matrices", () => {
  const A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const B = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  assert_matrix(A, B);
});

Deno.test("Matrix equality with different matrices", () => {
  const A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const B = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 8);
  assert_matrix_ne(A, B);
});

Deno.test("Multiplying two matrices", () => {
  const A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const B = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
  assert_matrix(multiply(A, B), matrix3(4, 8, 8, 13, 17, 17, 22, 26, 26));
});

Deno.test("Matrix multiplication is not commutative", () => {
  const A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const B = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
  assert_matrix_ne(multiply(A, B), multiply(B, A));
});

Deno.test("A matrix multiplied by a point", () => {
  const A = matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1);
  const p = point(1, 2);
  assert_tuple(multiply_tuple(A, p), point(8, 20));
});

Deno.test("A matrix multiplied by a vector ignores the last column", () => {
  const A = matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1);
  const v = vector(1, 2);
  assert_tuple(multiply_tuple(A, v), vector(5, 14));
});

Deno.test("Multiplying by the identity matrix changes nothing", () => {
  const A = matrix3(0, 1, 2, 1, 2, 4, 2, 4, 8);
  const p = point(1, 2);
  assert_matrix(multiply(A, identity()), A);
  assert_matrix(multiply(identity(), A), A);
  assert_tuple(multiply_tuple(identity(), p), p);
});

Deno.test("Transposing a matrix", () => {
  const A = matrix3(0, 9, 3, 9, 8, 0, 1, 8, 5);
  assert_matrix(transpose(A), matrix3(0, 9, 1, 9, 8, 8, 3, 0, 5));
});

Deno.test("Transposing the identity matrix", () => {
  assert_matrix(transpose(identity()), identity());
});

Deno.test("The determinant of a 3 by 3 matrix", () => {
  const A = matrix3(1, 2, 6, -5, 8, -4, 2, 6, 4);
  assert_eq(determinant(A), -196);
});

Deno.test("The determinant of a transform is the area factor", () => {
  assert_eq(determinant(identity()), 1);
  assert_eq(determinant(scaling(2, 3)), 6);
  assert_eq(determinant(rotation(0.7)), 1);
  assert_eq(determinant(translation(4, 9)), 1);
  assert_eq(determinant(scaling(-1, 1)), -1);
});

Deno.test("Testing an invertible matrix for invertibility", () => {
  const A = matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1);
  assert_eq(determinant(A), 10);
  assert_true(is_invertible(A) === true, "is_invertible(A)");
});

Deno.test("Testing a non-invertible matrix for invertibility", () => {
  const A = matrix3(1, 2, 3, 2, 4, 6, 0, 0, 1);
  assert_eq(determinant(A), 0);
  assert_true(is_invertible(A) === false, "is_invertible(A)");
});

Deno.test("Calculating the inverse of a matrix", () => {
  const A = matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1);
  const B = inverse(A);
  assert_eq(at(B, 0, 0), 0.2);
  assert_eq(at(B, 1, 2), 1);
  assert_eq(at(B, 2, 1), -0.3);
  assert_matrix(B, matrix3(0.2, 0.2, 0, -0.2, 0.3, 1, 0.2, -0.3, 0));
  assert_matrix(multiply(A, B), identity());
});

Deno.test("Multiplying a product by its inverse", () => {
  const A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const B = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
  const C = multiply(A, B);
  assert_matrix(multiply(C, inverse(B)), A);
});

Deno.test("The inverse of a transform is a transform", () => {
  const A = multiply(multiply(translation(5, -3), rotation(Math.PI / 6)), scaling(2, 3));
  const B = inverse(A);
  assert_eq(at(B, 2, 0), 0);
  assert_eq(at(B, 2, 1), 0);
  assert_eq(at(B, 2, 2), 1);
  assert_eq(at(B, 0, 0), 0.4330);
  assert_eq(at(B, 0, 2), -1.4151);
  assert_eq(at(B, 1, 2), 1.6994);
  assert_matrix(multiply(B, A), identity());
});
