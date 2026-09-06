// features/chapter06-sweep.feature
import { bounds, circle_path, filled, path, polygon, subpaths } from "../src/path.ts";
import { star } from "../src/scenes.ts";
import { coverage_at, coverage_buffer, ink, rasterize_centers, set_coverage } from "../src/coverage.ts";
import { fill_path_aliased, max_coverage_difference, transform_path } from "../src/sweep.ts";
import { point } from "../src/tuple.ts";
import { multiply, scaling, translation } from "../src/matrix.ts";
import { assert_bounds, assert_eq, assert_true, assert_tuple } from "../src/assert.ts";

Deno.test("Two buffers that differ", () => {
  const a = coverage_buffer(3, 3);
  const b = coverage_buffer(3, 3);
  set_coverage(a, 1, 1, 1);
  set_coverage(b, 1, 1, 0.25);
  assert_eq(max_coverage_difference(a, b), 0.75);
  assert_eq(max_coverage_difference(a, a), 0, 0);
});

Deno.test("Buffers of different sizes are as different as it gets", () => {
  const a = coverage_buffer(3, 3);
  const b = coverage_buffer(3, 4);
  assert_eq(max_coverage_difference(a, b), 1, 0);
});

Deno.test("A rectangle", () => {
  const p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6));
  const cov = fill_path_aliased(p, "nonzero", 8, 8);
  assert_eq(coverage_at(cov, 2, 2), 1, 0);
  assert_eq(coverage_at(cov, 5, 5), 1, 0);
  assert_eq(coverage_at(cov, 6, 5), 0, 0);
  assert_eq(coverage_at(cov, 5, 6), 0, 0);
  assert_eq(coverage_at(cov, 1, 2), 0, 0);
  assert_eq(ink(cov), 16);
  assert_eq(max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 8, 8)), 0, 0);
});

Deno.test("A triangle", () => {
  const p = polygon(point(0, 0), point(10, 0), point(5, 10));
  const cov = fill_path_aliased(p, "nonzero", 20, 20);
  assert_eq(coverage_at(cov, 0, 0), 1, 0);
  assert_eq(coverage_at(cov, 9, 0), 1, 0);
  assert_eq(coverage_at(cov, 10, 0), 0, 0);
  assert_eq(coverage_at(cov, 4, 8), 1, 0);
  assert_eq(coverage_at(cov, 3, 8), 0, 0);
  assert_eq(coverage_at(cov, 5, 9), 0, 0);
  assert_eq(ink(cov), 50);
  assert_eq(max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 20, 20)), 0, 0);
});

Deno.test("The same triangle drawn the other way round", () => {
  const a = polygon(point(0, 0), point(10, 0), point(5, 10));
  const b = polygon(point(0, 0), point(5, 10), point(10, 0));
  const ca = fill_path_aliased(a, "nonzero", 20, 20);
  const cb = fill_path_aliased(b, "nonzero", 20, 20);
  assert_eq(max_coverage_difference(ca, cb), 0, 0);
});

Deno.test("A polygon circle", () => {
  const p = circle_path(10.3, 9.7, 7, 12);
  const cov = fill_path_aliased(p, "nonzero", 20, 20);
  assert_eq(ink(cov), 145);
  assert_eq(max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 20, 20)), 0, 0);
});

Deno.test("The star, both rules, matches chapter 5 pixel for pixel", () => {
  const p = star();
  const nz = fill_path_aliased(p, "nonzero", 160, 160);
  const eo = fill_path_aliased(p, "evenodd", 160, 160);
  assert_eq(ink(nz), 5480);
  assert_eq(ink(eo), 3780);
  assert_eq(coverage_at(nz, 80, 80), 1, 0);
  assert_eq(coverage_at(eo, 80, 80), 0, 0);
  assert_eq(max_coverage_difference(nz, rasterize_centers(filled(p, "nonzero"), 160, 160)), 0, 0);
  assert_eq(max_coverage_difference(eo, rasterize_centers(filled(p, "evenodd"), 160, 160)), 0, 0);
});

Deno.test("An edge that starts on a sample height is active there, and one that ends there is not", () => {
  const p = polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5));
  const cov = fill_path_aliased(p, "nonzero", 8, 8);
  assert_eq(coverage_at(cov, 2, 1), 0, 0);
  assert_eq(coverage_at(cov, 2, 2), 1, 0);
  assert_eq(coverage_at(cov, 2, 4), 1, 0);
  assert_eq(coverage_at(cov, 2, 5), 0, 0);
  assert_eq(coverage_at(cov, 1, 3), 1, 0);
  assert_eq(coverage_at(cov, 4, 3), 0, 0);
  assert_eq(ink(cov), 9);
  assert_eq(max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 8, 8)), 0, 0);
});

Deno.test("A polygon larger than the buffer fills it", () => {
  const p = polygon(point(-5, -5), point(30, -5), point(30, 30), point(-5, 30));
  const cov = fill_path_aliased(p, "nonzero", 8, 8);
  assert_eq(ink(cov), 64);
});

Deno.test("An empty path fills nothing", () => {
  const p = path();
  const cov = fill_path_aliased(p, "nonzero", 8, 8);
  assert_eq(ink(cov), 0);
});

Deno.test("transform_path takes every point through the matrix and keeps the flags", () => {
  const p = polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5));
  const q = transform_path(p, translation(10, 20));
  assert_eq(subpaths(q).length, 1, 0);
  assert_true(subpaths(q)[0].closed === true, "subpaths(q)[0].closed");
  assert_tuple(subpaths(q)[0].points[0], point(11.25, 22));
  assert_tuple(subpaths(q)[0].points[2], point(14.75, 25));
  assert_tuple(subpaths(p)[0].points[0], point(1.25, 2));
});

Deno.test("A transformed star fills where the transform put it", () => {
  const m = multiply(multiply(translation(10, 10), scaling(0.11, 0.11)), translation(-80.5, -80.5));
  const p = transform_path(star(), m);
  const nz = fill_path_aliased(p, "nonzero", 20, 20);
  const eo = fill_path_aliased(p, "evenodd", 20, 20);
  assert_bounds(bounds(p), { minX: 2.6769, minY: 2.3, maxX: 17.3231, maxY: 16.2294 });
  assert_eq(ink(nz), 60);
  assert_eq(ink(eo), 40);
  assert_eq(max_coverage_difference(nz, rasterize_centers(filled(p, "nonzero"), 20, 20)), 0, 0);
});
