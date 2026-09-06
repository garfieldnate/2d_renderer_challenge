// features/chapter04-tuples.feature
import {
  add,
  cross,
  div,
  dot,
  magnitude,
  negate,
  normalize,
  point,
  scale,
  sub,
  vector,
} from "../src/tuple.ts";
import { assert_eq, assert_tuple } from "../src/assert.ts";

Deno.test("A point has w = 1", () => {
  const p = point(4, -4);
  assert_eq(p.x, 4);
  assert_eq(p.y, -4);
  assert_eq(p.w, 1);
});

Deno.test("A vector has w = 0", () => {
  const v = vector(4, -4);
  assert_eq(v.x, 4);
  assert_eq(v.y, -4);
  assert_eq(v.w, 0);
});

Deno.test("The difference of two points is the vector between them", () => {
  const a = point(3, 2);
  const b = point(5, 6);
  assert_tuple(sub(b, a), vector(2, 4));
  assert_tuple(sub(a, b), vector(-2, -4));
});

Deno.test("A point plus a vector is a point", () => {
  const p = point(3, -2);
  const v = vector(-2, 3);
  assert_tuple(add(p, v), point(1, 1));
  assert_tuple(sub(p, v), point(5, -5));
});

Deno.test("A vector plus a vector is a vector", () => {
  const a = vector(3, -2);
  const b = vector(-2, 3);
  assert_tuple(add(a, b), vector(1, 1));
  assert_tuple(sub(a, b), vector(5, -5));
});

Deno.test("Negating, scaling and dividing a vector", () => {
  const v = vector(1, -2);
  assert_tuple(negate(v), vector(-1, 2));
  assert_tuple(scale(v, 3.5), vector(3.5, -7));
  assert_tuple(scale(v, 0.5), vector(0.5, -1));
  assert_tuple(div(v, 2), vector(0.5, -1));
});

Deno.test("The magnitude of a vector", () => {
  assert_eq(magnitude(vector(1, 0)), 1);
  assert_eq(magnitude(vector(0, 1)), 1);
  assert_eq(magnitude(vector(3, 4)), 5);
  assert_eq(magnitude(vector(-3, -4)), 5);
  assert_eq(magnitude(vector(-1, -2)), 2.2361);
});

Deno.test("Normalizing a vector", () => {
  assert_tuple(normalize(vector(4, 0)), vector(1, 0));
  assert_tuple(normalize(vector(1, 2)), vector(0.4472, 0.8944));
  assert_eq(magnitude(normalize(vector(1, 2))), 1);
});

Deno.test("The dot product of two vectors", () => {
  const a = vector(1, 2);
  const b = vector(2, 3);
  assert_eq(dot(a, b), 8);
  assert_eq(dot(a, vector(-2, 1)), 0);
});

Deno.test("The cross product of two vectors is a number", () => {
  const a = vector(1, 0);
  const b = vector(0, 1);
  assert_eq(cross(a, b), 1);
  assert_eq(cross(b, a), -1);
  assert_eq(cross(a, a), 0);
  assert_eq(cross(vector(2, 3), vector(4, 5)), -2);
});

Deno.test("The sign of the cross product says which side of a line a point is on", () => {
  const a = point(0, 0);
  const b = point(10, 0);
  assert_eq(cross(sub(b, a), sub(point(5, 3), a)), 30);
  assert_eq(cross(sub(b, a), sub(point(5, -3), a)), -30);
  assert_eq(cross(sub(b, a), sub(point(20, 0), a)), 0);
});
