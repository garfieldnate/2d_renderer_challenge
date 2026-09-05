// features/chapter02-coverage.feature
import { circle, half_plane, rectangle } from "../src/shape.ts";
import { coverage, coverage_at, ink, rasterize } from "../src/coverage.ts";
import { disc_coverage } from "../src/scenes.ts";
import { canvas_to_p6, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { assert_eq, assert_triple, assert_true, read_file } from "../src/assert.ts";

Deno.test("The sixty-four sample points", () => {
  const s = half_plane(2.5, 0, 1, 0);
  assert_eq(coverage(s, 2, 4), 0.5);
  assert_eq(coverage(s, 1, 4), 0, 0);
  assert_eq(coverage(s, 3, 4), 1, 0);
});

Deno.test("A rectangle is covered exactly, when its edges land on sample boundaries", () => {
  const s = rectangle(1.25, 2.0, 4.75, 5.0);
  const cov = rasterize(s, 8, 8);
  assert_eq(coverage_at(cov, 0, 2), 0, 0);
  assert_eq(coverage_at(cov, 1, 2), 0.75);
  assert_eq(coverage_at(cov, 2, 2), 1, 0);
  assert_eq(coverage_at(cov, 3, 2), 1, 0);
  assert_eq(coverage_at(cov, 4, 2), 0.75);
  assert_eq(coverage_at(cov, 5, 2), 0, 0);
  assert_eq(coverage_at(cov, 2, 1), 0, 0);
  assert_eq(coverage_at(cov, 2, 5), 0, 0);
  assert_eq(ink(cov), 10.5);
});

Deno.test("Neither need the buffer be square here", () => {
  const s = rectangle(0, 0, 2, 1);
  const cov = rasterize(s, 4, 2);
  assert_eq(cov.width, 4, 0);
  assert_eq(cov.height, 2, 0);
  assert_eq(coverage_at(cov, 1, 0), 1, 0);
  assert_eq(coverage_at(cov, 2, 0), 0, 0);
  assert_eq(coverage_at(cov, 0, 1), 0, 0);
  assert_eq(ink(cov), 2, 0);
});

Deno.test("A half-plane through a pixel center covers half of it", () => {
  const s = half_plane(2.5, 4.5, 0.6, 0.8);
  assert_eq(coverage(s, 2, 4), 0.5);
});

Deno.test("Except when the grid conspires", () => {
  const s = half_plane(2.5, 4.5, 1, 1);
  assert_eq(coverage(s, 2, 4), 0.5625);
});

Deno.test("A disc is only ever approximately covered", () => {
  const s = circle(8, 8, 5);
  const cov = rasterize(s, 16, 16);
  assert_eq(coverage_at(cov, 8, 8), 1, 0);
  assert_eq(coverage_at(cov, 3, 8), 0.96875);
  assert_eq(coverage_at(cov, 12, 8), 0.96875);
  assert_eq(coverage_at(cov, 4, 4), 0.5625);
  assert_eq(coverage_at(cov, 3, 4), 0, 0);
  assert_eq(ink(cov), 78.5);
  assert_eq(ink(cov), 78.5398, 0.1);
});

Deno.test("The disc by coverage", () => {
  const c = disc_coverage();
  const ref = read_file("reference/chapter-02/disc-coverage.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 320, 0);
  assert_eq(c.height, 320, 0);
  assert_triple(ppm_pixel(p6, 160, 160), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 124, 36), [157, 127, 64], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
