// features/chapter04-transforms.feature
import { inverse, multiply, multiply_tuple, rotation, scaling, shearing, translation } from "../src/matrix.ts";
import { magnitude, point, vector } from "../src/tuple.ts";
import { assert_eq, assert_tuple } from "../src/assert.ts";

Deno.test("Multiplying by a translation matrix", () => {
  const t = translation(5, -3);
  const p = point(-3, 4);
  assert_tuple(multiply_tuple(t, p), point(2, 1));
});

Deno.test("The inverse of a translation moves the other way", () => {
  const t = translation(5, -3);
  const p = point(-3, 4);
  assert_tuple(multiply_tuple(inverse(t), p), point(-8, 7));
});

Deno.test("Translation does not affect vectors", () => {
  const t = translation(5, -3);
  const v = vector(-3, 4);
  assert_tuple(multiply_tuple(t, v), v);
});

Deno.test("A scaling matrix applied to a point", () => {
  const s = scaling(2, 3);
  const p = point(-4, 6);
  assert_tuple(multiply_tuple(s, p), point(-8, 18));
});

Deno.test("A scaling matrix applied to a vector", () => {
  const s = scaling(2, 3);
  const v = vector(-4, 6);
  assert_tuple(multiply_tuple(s, v), vector(-8, 18));
});

Deno.test("The inverse of a scaling shrinks", () => {
  const s = scaling(2, 3);
  const v = vector(-4, 6);
  assert_tuple(multiply_tuple(inverse(s), v), vector(-2, 2));
});

Deno.test("Reflection is scaling by a negative value", () => {
  const s = scaling(-1, 1);
  const p = point(2, 3);
  assert_tuple(multiply_tuple(s, p), point(-2, 3));
});

Deno.test("A positive rotation turns x toward y", () => {
  const p = point(1, 0);
  assert_tuple(multiply_tuple(rotation(Math.PI / 4), p), point(0.7071, 0.7071));
  assert_tuple(multiply_tuple(rotation(Math.PI / 2), p), point(0, 1));
  assert_tuple(multiply_tuple(rotation(Math.PI), p), point(-1, 0));
});

Deno.test("The inverse of a rotation turns the other way", () => {
  const p = point(1, 0);
  assert_tuple(multiply_tuple(inverse(rotation(Math.PI / 4)), p), point(0.7071, -0.7071));
  assert_tuple(multiply_tuple(rotation(-Math.PI / 4), p), point(0.7071, -0.7071));
});

Deno.test("A rotation preserves length", () => {
  const v = vector(3, 4);
  assert_eq(magnitude(multiply_tuple(rotation(1.2), v)), 5);
  assert_eq(magnitude(multiply_tuple(rotation(-2.8), v)), 5);
});

Deno.test("Shearing moves x in proportion to y", () => {
  const s = shearing(1, 0);
  const p = point(2, 3);
  assert_tuple(multiply_tuple(s, p), point(5, 3));
});

Deno.test("Shearing moves y in proportion to x", () => {
  const s = shearing(0, 1);
  const p = point(2, 3);
  assert_tuple(multiply_tuple(s, p), point(2, 5));
});

Deno.test("Individual transformations are applied in sequence", () => {
  const p = point(1, 0);
  const A = rotation(Math.PI / 2);
  const B = scaling(5, 5);
  const C = translation(10, 5);
  const p2 = multiply_tuple(A, p);
  const p3 = multiply_tuple(B, p2);
  const p4 = multiply_tuple(C, p3);
  assert_tuple(p2, point(0, 1));
  assert_tuple(p3, point(0, 5));
  assert_tuple(p4, point(10, 10));
});

Deno.test("Chained transformations must be applied in reverse order", () => {
  const p = point(1, 0);
  const A = rotation(Math.PI / 2);
  const B = scaling(5, 5);
  const C = translation(10, 5);
  const T = multiply(multiply(C, B), A);
  assert_tuple(multiply_tuple(T, p), point(10, 10));
});

Deno.test("The other order is a different transform", () => {
  const p = point(1, 0);
  const A = rotation(Math.PI / 2);
  const B = scaling(5, 5);
  const C = translation(10, 5);
  const T = multiply(multiply(A, B), C);
  assert_tuple(multiply_tuple(T, p), point(-25, 55));
});

Deno.test("Rotating about a point that isn't the origin", () => {
  const T = multiply(multiply(translation(4, 4), rotation(Math.PI / 2)), translation(-4, -4));
  assert_tuple(multiply_tuple(T, point(6, 4)), point(4, 6));
  assert_tuple(multiply_tuple(T, point(4, 4)), point(4, 4));
});
