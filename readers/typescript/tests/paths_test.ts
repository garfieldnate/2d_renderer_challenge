// features/chapter05-paths.feature
import {
  bounds,
  circle_path,
  close,
  edges,
  line_to,
  move_to,
  path,
  polygon,
  subpaths,
  winding_at,
} from "../src/path.ts";
import { point } from "../src/tuple.ts";
import { assert_bounds, assert_eq, assert_true, assert_tuple } from "../src/assert.ts";

Deno.test("An empty path", () => {
  const p = path();
  assert_eq(subpaths(p).length, 0, 0);
  assert_eq(edges(p).length, 0, 0);
  assert_bounds(bounds(p), { minX: 0, minY: 0, maxX: 0, maxY: 0 });
});

Deno.test("A triangle, closed", () => {
  const p = path();
  move_to(p, point(1, 1));
  line_to(p, point(9, 1));
  line_to(p, point(5, 8));
  close(p);
  assert_eq(subpaths(p).length, 1, 0);
  assert_true(subpaths(p)[0].closed === true, "subpaths(p)[0].closed");
  assert_eq(subpaths(p)[0].points.length, 3, 0);
  assert_tuple(subpaths(p)[0].points[2], point(5, 8));
  assert_eq(edges(p).length, 3, 0);
  assert_tuple(edges(p)[2].a, point(5, 8));
  assert_tuple(edges(p)[2].b, point(1, 1));
  assert_bounds(bounds(p), { minX: 1, minY: 1, maxX: 9, maxY: 8 });
});

Deno.test("A triangle left open still has three edges", () => {
  const p = path();
  move_to(p, point(1, 1));
  line_to(p, point(9, 1));
  line_to(p, point(5, 8));
  assert_true(subpaths(p)[0].closed === false, "subpaths(p)[0].closed");
  assert_eq(edges(p).length, 3, 0);
  assert_tuple(edges(p)[2].a, point(5, 8));
  assert_tuple(edges(p)[2].b, point(1, 1));
});

Deno.test("move_to starts a second subpath", () => {
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
  assert_eq(subpaths(p).length, 2, 0);
  assert_tuple(subpaths(p)[1].points[0], point(3, 3));
  assert_eq(edges(p).length, 8, 0);
  assert_bounds(bounds(p), { minX: 0, minY: 0, maxX: 10, maxY: 10 });
});

Deno.test("line_to after a close starts a new subpath where the closed one began", () => {
  const p = path();
  move_to(p, point(1, 1));
  line_to(p, point(4, 1));
  line_to(p, point(4, 4));
  close(p);
  line_to(p, point(9, 9));
  assert_eq(subpaths(p).length, 2, 0);
  assert_true(subpaths(p)[1].closed === false, "subpaths(p)[1].closed");
  assert_eq(subpaths(p)[1].points.length, 2, 0);
  assert_tuple(subpaths(p)[1].points[0], point(1, 1));
  assert_tuple(subpaths(p)[1].points[1], point(9, 9));
});

Deno.test("line_to with nothing to extend behaves as move_to", () => {
  const p = path();
  line_to(p, point(2, 3));
  assert_eq(subpaths(p).length, 1, 0);
  assert_eq(subpaths(p)[0].points.length, 1, 0);
  assert_tuple(subpaths(p)[0].points[0], point(2, 3));
});

Deno.test("A subpath of one point has no edges, and closing nothing does nothing", () => {
  const p = path();
  close(p);
  move_to(p, point(1, 1));
  move_to(p, point(2, 2));
  assert_eq(subpaths(p).length, 2, 0);
  assert_eq(edges(p).length, 0, 0);
  assert_bounds(bounds(p), { minX: 1, minY: 1, maxX: 2, maxY: 2 });
});

Deno.test("A subpath of two points has two edges and encloses nothing", () => {
  const p = path();
  move_to(p, point(1, 1));
  line_to(p, point(9, 9));
  assert_eq(edges(p).length, 2, 0);
  assert_eq(winding_at(p, 3, 5), 0, 0);
});

Deno.test("polygon is a closed subpath through its points", () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert_eq(subpaths(p).length, 1, 0);
  assert_true(subpaths(p)[0].closed === true, "subpaths(p)[0].closed");
  assert_eq(edges(p).length, 4, 0);
});

Deno.test("circle_path is a polygon standing in for a circle", () => {
  const p = circle_path(10, 10, 5, 8);
  assert_eq(subpaths(p)[0].points.length, 8, 0);
  assert_tuple(subpaths(p)[0].points[0], point(15, 10));
  assert_tuple(subpaths(p)[0].points[1], point(13.5355, 13.5355));
  assert_tuple(subpaths(p)[0].points[2], point(10, 15));
  assert_bounds(bounds(p), { minX: 5, minY: 5, maxX: 15, maxY: 15 });
});
