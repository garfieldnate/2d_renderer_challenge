// features/chapter05-rules.feature
import { bounds, close, filled, inside_evenodd, inside_nonzero, line_to, move_to, path, polygon, rasterize_within, winding_at } from "../src/path.ts";
import { star } from "../src/scenes.ts";
import { inside } from "../src/shape.ts";
import { coverage_at, ink, rasterize } from "../src/coverage.ts";
import { point } from "../src/tuple.ts";
import { assert_eq, assert_true } from "../src/assert.ts";

Deno.test("A single loop is inside under both rules", () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert_true(inside_nonzero(p, 5, 5) === true, "inside_nonzero(p, 5, 5)");
  assert_true(inside_evenodd(p, 5, 5) === true, "inside_evenodd(p, 5, 5)");
  assert_true(inside_nonzero(p, 15, 5) === false, "inside_nonzero(p, 15, 5)");
  assert_true(inside_evenodd(p, 15, 5) === false, "inside_evenodd(p, 15, 5)");
});

Deno.test("An inner loop the other way round is a hole under both rules", () => {
  const p = path();
  move_to(p, point(0, 0));
  line_to(p, point(10, 0));
  line_to(p, point(10, 10));
  line_to(p, point(0, 10));
  close(p);
  move_to(p, point(3, 3));
  line_to(p, point(3, 7));
  line_to(p, point(7, 7));
  line_to(p, point(7, 3));
  close(p);
  assert_eq(winding_at(p, 5, 5), 0, 0);
  assert_eq(winding_at(p, 1, 1), 1, 0);
  assert_true(inside_nonzero(p, 5, 5) === false, "inside_nonzero(p, 5, 5)");
  assert_true(inside_evenodd(p, 5, 5) === false, "inside_evenodd(p, 5, 5)");
  assert_true(inside_nonzero(p, 1, 1) === true, "inside_nonzero(p, 1, 1)");
});

Deno.test("An inner loop the same way round is a hole only under even-odd", () => {
  const p = path();
  move_to(p, point(0, 0));
  line_to(p, point(10, 0));
  line_to(p, point(10, 10));
  line_to(p, point(0, 10));
  close(p);
  move_to(p, point(3, 3));
  line_to(p, point(7, 3));
  line_to(p, point(7, 7));
  line_to(p, point(3, 7));
  close(p);
  assert_eq(winding_at(p, 5, 5), 2, 0);
  assert_true(inside_nonzero(p, 5, 5) === true, "inside_nonzero(p, 5, 5)");
  assert_true(inside_evenodd(p, 5, 5) === false, "inside_evenodd(p, 5, 5)");
});

Deno.test("A loop wound twice vanishes under even-odd", () => {
  const p = path();
  move_to(p, point(5, 0));
  line_to(p, point(10, 5));
  line_to(p, point(5, 10));
  line_to(p, point(0, 5));
  line_to(p, point(5, 0));
  line_to(p, point(10, 5));
  line_to(p, point(5, 10));
  line_to(p, point(0, 5));
  close(p);
  assert_true(inside_nonzero(p, 5, 5) === true, "inside_nonzero(p, 5, 5)");
  assert_true(inside_evenodd(p, 5, 5) === false, "inside_evenodd(p, 5, 5)");
});

Deno.test("The pentagram's center is inside under nonzero and outside under even-odd", () => {
  const p = star();
  assert_true(inside_nonzero(p, 80.5, 80.5) === true, "inside_nonzero(p, 80.5, 80.5)");
  assert_true(inside_evenodd(p, 80.5, 80.5) === false, "inside_evenodd(p, 80.5, 80.5)");
  assert_true(inside_nonzero(p, 80.5, 20) === true, "inside_nonzero(p, 80.5, 20)");
  assert_true(inside_evenodd(p, 80.5, 20) === true, "inside_evenodd(p, 80.5, 20)");
  assert_true(inside_nonzero(p, 80.5, 120) === false, "inside_nonzero(p, 80.5, 120)");
  assert_true(inside_evenodd(p, 80.5, 120) === false, "inside_evenodd(p, 80.5, 120)");
});

Deno.test("A filled path is a shape", () => {
  const s = filled(polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6)), "nonzero");
  const cov = rasterize(s, 8, 8);
  assert_true(inside(s, 3, 3) === true, "inside(s, 3, 3)");
  assert_true(inside(s, 7, 3) === false, "inside(s, 7, 3)");
  assert_eq(coverage_at(cov, 3, 3), 1, 0);
  assert_eq(coverage_at(cov, 1, 3), 0, 0);
  assert_eq(coverage_at(cov, 6, 3), 0, 0);
  assert_eq(ink(cov), 16);
});

Deno.test("A filled path takes the rule seriously", () => {
  const p = star();
  const a = filled(p, "nonzero");
  const b = filled(p, "evenodd");
  const ca = rasterize(a, 160, 160);
  const cb = rasterize(b, 160, 160);
  assert_eq(coverage_at(ca, 80, 80), 1, 0);
  assert_eq(coverage_at(cb, 80, 80), 0, 0);
  assert_eq(coverage_at(ca, 80, 20), 1, 0);
  assert_eq(coverage_at(cb, 80, 20), 1, 0);
  assert_eq(coverage_at(ca, 80, 10), 0.0625);
  assert_eq(coverage_at(cb, 80, 10), 0.0625);
  assert_eq(ink(ca), 5499.9375);
  assert_eq(ink(cb), 3800.375);
});

Deno.test("Rasterizing within the bounds gives the same coverage", () => {
  const p = star();
  const s = filled(p, "evenodd");
  const full = rasterize(s, 160, 160);
  const within = rasterize_within(s, bounds(p), 160, 160);
  assert_eq(ink(within), ink(full));
  assert_eq(coverage_at(within, 80, 20), coverage_at(full, 80, 20));
  assert_eq(coverage_at(within, 13, 58), coverage_at(full, 13, 58));
  assert_eq(coverage_at(within, 10, 10), 0, 0);
});

Deno.test("The box is inclusive of the pixels it touches, and clipped to the buffer", () => {
  const s = filled(
    polygon(point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)),
    "nonzero",
  );
  const cov = rasterize_within(s, { minX: 1.5, minY: 1.5, maxX: 6.5, maxY: 6.5 }, 8, 8);
  const big = rasterize_within(s, { minX: -5, minY: -5, maxX: 20, maxY: 20 }, 8, 8);
  assert_eq(coverage_at(cov, 1, 1), 0.25);
  assert_eq(coverage_at(cov, 6, 6), 0.25);
  assert_eq(coverage_at(cov, 3, 3), 1, 0);
  assert_eq(ink(cov), 25);
  assert_eq(ink(big), 25);
});
