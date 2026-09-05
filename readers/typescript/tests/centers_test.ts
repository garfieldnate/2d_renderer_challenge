// features/chapter02-centers.feature
import { circle, half_plane, rectangle } from "../src/shape.ts";
import {
  center_inside,
  coverage,
  coverage_at,
  coverage_buffer,
  ink,
  rasterize_centers,
  set_coverage,
} from "../src/coverage.ts";
import { assert_eq } from "../src/assert.ts";

Deno.test("A new coverage buffer is empty", () => {
  const cov = coverage_buffer(4, 3);
  assert_eq(cov.width, 4, 0);
  assert_eq(cov.height, 3, 0);
  assert_eq(coverage_at(cov, 2, 1), 0, 0);
  assert_eq(ink(cov), 0, 0);
});

Deno.test("Setting coverage", () => {
  const cov = coverage_buffer(4, 3);
  set_coverage(cov, 2, 1, 0.75);
  assert_eq(coverage_at(cov, 2, 1), 0.75);
  assert_eq(coverage_at(cov, 1, 2), 0, 0);
  assert_eq(ink(cov), 0.75);
});

Deno.test("Setting coverage outside the buffer is ignored, and reading it gives 0", () => {
  const cov = coverage_buffer(4, 3);
  set_coverage(cov, -1, 1, 1);
  set_coverage(cov, 4, 1, 1);
  set_coverage(cov, 1, 3, 1);
  assert_eq(ink(cov), 0, 0);
  assert_eq(coverage_at(cov, -1, 1), 0, 0);
  assert_eq(coverage_at(cov, 4, 1), 0, 0);
  assert_eq(coverage_at(cov, 1, 3), 0, 0);
});

Deno.test("The center of pixel (x, y) is (x + 0.5, y + 0.5)", () => {
  const s = half_plane(2.5, 0, 1, 0);
  assert_eq(center_inside(s, 2, 4), 1, 0);
  assert_eq(center_inside(s, 1, 4), 0, 0);
  const t = half_plane(2.6, 0, 1, 0);
  assert_eq(center_inside(t, 2, 4), 0, 0);
});

Deno.test('The center question is not "at least half"', () => {
  const s = half_plane(2.55, 0, 1, 0);
  assert_eq(center_inside(s, 2, 4), 0, 0);
  assert_eq(coverage(s, 2, 4), 0.5);
});

Deno.test("A buffer need not be square", () => {
  const s = rectangle(0, 0, 2, 1);
  const cov = rasterize_centers(s, 4, 2);
  assert_eq(cov.width, 4, 0);
  assert_eq(cov.height, 2, 0);
  assert_eq(coverage_at(cov, 1, 0), 1, 0);
  assert_eq(coverage_at(cov, 0, 1), 0, 0);
  assert_eq(ink(cov), 2, 0);
});

Deno.test("A rectangle, by asking each center", () => {
  const s = rectangle(1.25, 2.0, 4.75, 5.0);
  const cov = rasterize_centers(s, 8, 8);
  assert_eq(coverage_at(cov, 1, 4), 1, 0);
  assert_eq(coverage_at(cov, 4, 1), 0, 0);
  assert_eq(coverage_at(cov, 4, 4), 1, 0);
  assert_eq(coverage_at(cov, 0, 3), 0, 0);
  assert_eq(coverage_at(cov, 5, 3), 0, 0);
  assert_eq(coverage_at(cov, 2, 1), 0, 0);
  assert_eq(coverage_at(cov, 2, 5), 0, 0);
  assert_eq(ink(cov), 12, 0);
});

Deno.test("A disc, by asking each center", () => {
  const s = circle(8, 8, 5);
  const cov = rasterize_centers(s, 16, 16);
  assert_eq(cov.width, 16, 0);
  assert_eq(cov.height, 16, 0);
  assert_eq(coverage_at(cov, 8, 8), 1, 0);
  assert_eq(coverage_at(cov, 3, 8), 1, 0);
  assert_eq(coverage_at(cov, 12, 8), 1, 0);
  assert_eq(coverage_at(cov, 2, 8), 0, 0);
  assert_eq(coverage_at(cov, 13, 8), 0, 0);
  assert_eq(coverage_at(cov, 4, 4), 1, 0);
  assert_eq(coverage_at(cov, 3, 4), 0, 0);
  assert_eq(ink(cov), 80, 0);
});
