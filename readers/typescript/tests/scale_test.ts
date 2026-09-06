// features/chapter04-scale.feature
import { approx_scale, identity, matrix3, multiply, rotation, scaling, shearing, translation } from "../src/matrix.ts";
import { assert_eq } from "../src/assert.ts";

Deno.test("The identity, a translation and a rotation don't stretch", () => {
  assert_eq(approx_scale(identity()), 1);
  assert_eq(approx_scale(translation(7, 9)), 1);
  assert_eq(approx_scale(rotation(1.1)), 1);
});

Deno.test("A uniform scale is reported exactly", () => {
  assert_eq(approx_scale(scaling(2, 2)), 2);
  assert_eq(approx_scale(scaling(0.5, 0.5)), 0.5);
  assert_eq(approx_scale(multiply(scaling(3, 3), rotation(0.7))), 3);
  assert_eq(approx_scale(multiply(translation(5, 5), scaling(3, 3))), 3);
});

Deno.test("A reflection is not a negative scale", () => {
  assert_eq(approx_scale(scaling(-2, 2)), 2);
});

Deno.test("A non-uniform scale is reported as the geometric mean", () => {
  assert_eq(approx_scale(scaling(4, 1)), 2);
  assert_eq(approx_scale(multiply(scaling(4, 1), rotation(0.4))), 2);
  assert_eq(approx_scale(scaling(9, 1)), 3);
});

Deno.test("A shear that preserves area reports 1", () => {
  assert_eq(approx_scale(shearing(1, 0)), 1);
  assert_eq(approx_scale(shearing(0.5, 0.5)), 0.8660);
});

Deno.test("A collapsed transform reports 0", () => {
  assert_eq(approx_scale(scaling(0, 1)), 0);
  assert_eq(approx_scale(matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1)), 0);
});
