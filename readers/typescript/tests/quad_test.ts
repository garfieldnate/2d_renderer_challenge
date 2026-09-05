// features/chapter03-quad.feature
import { inside, thick_line } from "../src/shape.ts";
import { coverage_at, ink, rasterize } from "../src/coverage.ts";
import { assert_eq, assert_true } from "../src/assert.ts";

Deno.test("Inside a thick line", () => {
  const s = thick_line(0, 0, 4, 0, 1);
  assert_true(inside(s, 2.5, 0.5) === true, "inside(s, 2.5, 0.5)");
  assert_true(inside(s, 2.5, 1.0) === true, "inside(s, 2.5, 1.0)");
  assert_true(inside(s, 2.5, 1.01) === false, "inside(s, 2.5, 1.01)");
  assert_true(inside(s, 0.5, 0.5) === true, "inside(s, 0.5, 0.5)");
  assert_true(inside(s, 0.4, 0.5) === false, "inside(s, 0.4, 0.5)");
  assert_true(inside(s, 4.5, 0.5) === true, "inside(s, 4.5, 0.5)");
  assert_true(inside(s, 4.6, 0.5) === false, "inside(s, 4.6, 0.5)");
});

Deno.test("A horizontal thick line covers its row, with half pixels at the ends", () => {
  const s = thick_line(0, 3, 7, 3, 1);
  const cov = rasterize(s, 10, 10);
  assert_eq(coverage_at(cov, 0, 3), 0.5);
  assert_eq(coverage_at(cov, 1, 3), 1, 0);
  assert_eq(coverage_at(cov, 6, 3), 1, 0);
  assert_eq(coverage_at(cov, 7, 3), 0.5);
  assert_eq(coverage_at(cov, 8, 3), 0, 0);
  assert_eq(coverage_at(cov, 3, 2), 0, 0);
  assert_eq(coverage_at(cov, 3, 4), 0, 0);
  assert_eq(ink(cov), 7);
});

for (const [x1, y1] of [[12, 2], [10, 8], [8, 10], [2, 12]]) {
  Deno.test(`The ink is the length, whatever the angle: (2, 2) to (${x1}, ${y1})`, () => {
    const s = thick_line(2, 2, x1, y1, 1);
    const cov = rasterize(s, 20, 20);
    assert_eq(ink(cov), 10);
  });
}

Deno.test("Except that the grid is blind along the diagonal", () => {
  const s = thick_line(2, 2, 9, 9, 1);
  const cov = rasterize(s, 20, 20);
  assert_eq(ink(cov), 9.7188);
  assert_eq(ink(cov), 9.8995, 0.25);
});
