// features/chapter04-shapes.feature: "Transforming what you draw" —
// segment, union, transformed, outline.
import { circle, inside, outline, rectangle, segment, thick_line, transformed, union } from "../src/shape.ts";
import { coverage_at, ink, paint_through, rasterize } from "../src/coverage.ts";
import { canvas, pixel_at } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import { approx_scale, identity, multiply, multiply_tuple, scaling, translation } from "../src/matrix.ts";
import { point } from "../src/tuple.ts";
import { assert_color, assert_eq, assert_true, lit_pixels, total_ink } from "../src/assert.ts";

Deno.test("A segment between pixel centers is a thick line", () => {
  const s = segment(point(2.5, 2.5), point(11.5, 5.5), 1);
  const cov = rasterize(s, 16, 10);
  assert_eq(coverage_at(cov, 2, 2), 0.484375);
  assert_eq(coverage_at(cov, 6, 3), 0.6875);
  assert_eq(coverage_at(cov, 7, 3), 0.359375);
  assert_eq(ink(cov), 9.4063);
});

Deno.test("A segment need not start on a pixel center", () => {
  const s = segment(point(1, 3.5), point(7, 3.5), 1);
  const cov = rasterize(s, 10, 10);
  assert_eq(coverage_at(cov, 0, 3), 0, 0);
  assert_eq(coverage_at(cov, 1, 3), 1, 0);
  assert_eq(coverage_at(cov, 6, 3), 1, 0);
  assert_eq(coverage_at(cov, 7, 3), 0, 0);
  assert_eq(coverage_at(cov, 3, 2), 0, 0);
  assert_eq(ink(cov), 6);
});

Deno.test("A segment of no length is a square", () => {
  const s = segment(point(3.5, 3.5), point(3.5, 3.5), 1);
  const cov = rasterize(s, 8, 8);
  assert_eq(coverage_at(cov, 3, 3), 1, 0);
  assert_eq(ink(cov), 1);
});

Deno.test("A union is inside when any of its parts is", () => {
  const s = union([circle(2, 2, 1), rectangle(5, 0, 7, 4)]);
  assert_true(inside(s, 2, 2) === true, "inside(s, 2, 2)");
  assert_true(inside(s, 6, 1) === true, "inside(s, 6, 1)");
  assert_true(inside(s, 4, 2) === false, "inside(s, 4, 2)");
  assert_eq(ink(rasterize(s, 8, 8)), 11.25);
});

Deno.test("A circle seen through a scale is an ellipse", () => {
  const s = transformed(circle(0, 0, 4), scaling(2, 1));
  assert_true(inside(s, 7.9, 0) === true, "inside(s, 7.9, 0)");
  assert_true(inside(s, 8.1, 0) === false, "inside(s, 8.1, 0)");
  assert_true(inside(s, 0, 3.9) === true, "inside(s, 0, 3.9)");
  assert_true(inside(s, 0, 4.1) === false, "inside(s, 0, 4.1)");
  assert_true(inside(s, 5.6, 1.4) === true, "inside(s, 5.6, 1.4)");
  assert_true(inside(s, 5.6, 2.9) === false, "inside(s, 5.6, 2.9)");
});

Deno.test("The transform is applied in the order the matrix says", () => {
  const s = transformed(circle(0, 0, 4), multiply(translation(10, 10), scaling(2, 1)));
  assert_true(inside(s, 10, 10) === true, "inside(s, 10, 10)");
  assert_true(inside(s, 17.9, 10) === true, "inside(s, 17.9, 10)");
  assert_true(inside(s, 18.1, 10) === false, "inside(s, 18.1, 10)");
  assert_true(inside(s, 10, 13.9) === true, "inside(s, 10, 13.9)");
  assert_true(inside(s, 10, 14.1) === false, "inside(s, 10, 14.1)");
});

Deno.test("A shape seen through a collapsed transform is empty", () => {
  const s = transformed(circle(0, 0, 4), scaling(0, 1));
  assert_true(inside(s, 0, 0) === false, "inside(s, 0, 0)");
  assert_eq(ink(rasterize(s, 10, 10)), 0);
});

Deno.test("A pen in shape space scales with the shape", () => {
  const s = transformed(thick_line(5, 0, 5, 9, 1), scaling(3, 1));
  const cov = rasterize(s, 24, 10);
  assert_eq(coverage_at(cov, 14, 4), 0, 0);
  assert_eq(coverage_at(cov, 15, 4), 1, 0);
  assert_eq(coverage_at(cov, 16, 4), 1, 0);
  assert_eq(coverage_at(cov, 17, 4), 1, 0);
  assert_eq(coverage_at(cov, 18, 4), 0, 0);
  assert_eq(ink(cov), 27);
});

Deno.test("A pen in device space does not", () => {
  const m = scaling(3, 1);
  const s = segment(multiply_tuple(m, point(5.5, 0.5)), multiply_tuple(m, point(5.5, 9.5)), 1);
  const cov = rasterize(s, 24, 10);
  assert_eq(coverage_at(cov, 15, 4), 0, 0);
  assert_eq(coverage_at(cov, 16, 4), 1, 0);
  assert_eq(coverage_at(cov, 17, 4), 0, 0);
  assert_eq(ink(cov), 9);
});

Deno.test("Dividing the width by approx_scale makes the two pens agree", () => {
  const m = scaling(2, 2);
  const s = transformed(segment(point(5.5, 0.5), point(5.5, 9.5), 1 / approx_scale(m)), m);
  const cov = rasterize(s, 24, 20);
  assert_eq(coverage_at(cov, 9, 5), 0, 0);
  assert_eq(coverage_at(cov, 10, 5), 0.5);
  assert_eq(coverage_at(cov, 11, 5), 0.5);
  assert_eq(coverage_at(cov, 12, 5), 0, 0);
  assert_eq(ink(cov), 18);
});

Deno.test("Under a non-uniform scale the compromise shows", () => {
  const m = scaling(4, 1);
  const w = 1 / approx_scale(m);
  const v = transformed(segment(point(2.5, 0.5), point(2.5, 9.5), w), m);
  const h = transformed(segment(point(0.5, 5.5), point(4.5, 5.5), w), m);
  const cv = rasterize(v, 24, 12);
  const ch = rasterize(h, 24, 12);
  assert_eq(coverage_at(cv, 8, 5), 0, 0);
  assert_eq(coverage_at(cv, 9, 5), 1, 0);
  assert_eq(coverage_at(cv, 10, 5), 1, 0);
  assert_eq(coverage_at(cv, 11, 5), 0, 0);
  assert_eq(ink(cv), 18);
  assert_eq(coverage_at(ch, 10, 4), 0, 0);
  assert_eq(coverage_at(ch, 10, 5), 0.5);
  assert_eq(coverage_at(ch, 10, 6), 0, 0);
  assert_eq(ink(ch), 8);
});

Deno.test("An outline is one shape, so its corners are painted once", () => {
  const pts = [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)];
  const c = canvas(8, 8);
  paint_through(c, rasterize(outline(pts, identity(), 1), 8, 8), color(1, 1, 1));
  assert_eq(lit_pixels(c).length, 20, 0);
  assert_color(pixel_at(c, 3, 1), color(1, 1, 1));
  assert_color(pixel_at(c, 1, 3), color(1, 1, 1));
  assert_color(pixel_at(c, 1, 1), color(0.75, 0.75, 0.75));
  assert_color(pixel_at(c, 3, 3), color(0, 0, 0));
  assert_color(pixel_at(c, 0, 1), color(0, 0, 0));
  assert_eq(total_ink(c), 19);
});

Deno.test("An outline takes its points through the matrix first", () => {
  const pts = [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)];
  const c = canvas(16, 16);
  paint_through(c, rasterize(outline(pts, scaling(2, 2), 1), 16, 16), color(1, 1, 1));
  assert_eq(lit_pixels(c).length, 76, 0);
  assert_color(pixel_at(c, 3, 3), color(0.75, 0.75, 0.75));
  assert_color(pixel_at(c, 8, 2), color(0.5, 0.5, 0.5));
  assert_color(pixel_at(c, 8, 3), color(0.5, 0.5, 0.5));
  assert_color(pixel_at(c, 8, 4), color(0, 0, 0));
});
