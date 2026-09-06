// features/chapter05-winding.feature
import { circle_path, close, crossings, edges, line_to, move_to, polygon, winding_at } from "../src/path.ts";
import { star } from "../src/scenes.ts";
import { point } from "../src/tuple.ts";
import { assert_eq } from "../src/assert.ts";

Deno.test("Crossings from inside and outside a square", () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert_eq(crossings(p, 5, 5), 1, 0);
  assert_eq(crossings(p, 15, 5), 0, 0);
  assert_eq(crossings(p, -1, 5), 2, 0);
});

Deno.test("A clockwise square winds once", () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert_eq(winding_at(p, 5, 5), 1, 0);
  assert_eq(winding_at(p, 15, 5), 0, 0);
  assert_eq(winding_at(p, -1, 5), 0, 0);
  assert_eq(winding_at(p, 5, -1), 0, 0);
  assert_eq(winding_at(p, 5, 11), 0, 0);
});

Deno.test("The same square the other way round winds minus once", () => {
  const p = polygon(point(0, 0), point(0, 10), point(10, 10), point(10, 0));
  assert_eq(winding_at(p, 5, 5), -1, 0);
  assert_eq(crossings(p, 5, 5), 1, 0);
});

Deno.test("A ray through a vertex counts it once", () => {
  const p = polygon(point(5, 0), point(10, 5), point(5, 10), point(0, 5));
  assert_eq(crossings(p, 2, 5), 1, 0);
  assert_eq(winding_at(p, 2, 5), 1, 0);
  assert_eq(crossings(p, -1, 5), 2, 0);
  assert_eq(winding_at(p, -1, 5), 0, 0);
  assert_eq(winding_at(p, 12, 5), 0, 0);
  assert_eq(winding_at(p, 5, 5), 1, 0);
});

Deno.test("The boundary belongs to the top and the left", () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert_eq(winding_at(p, 5, 0), 1, 0);
  assert_eq(winding_at(p, 0, 5), 1, 0);
  assert_eq(winding_at(p, 0, 0), 1, 0);
  assert_eq(winding_at(p, 5, 10), 0, 0);
  assert_eq(winding_at(p, 10, 5), 0, 0);
  assert_eq(winding_at(p, 10, 10), 0, 0);
});

Deno.test("Two rectangles that share an edge cover it once", () => {
  const p = polygon(point(0, 0), point(5, 0), point(5, 10), point(0, 10));
  // a second subpath, sharing the edge x = 5 with the first
  move_to(p, point(5, 0));
  line_to(p, point(10, 0));
  line_to(p, point(10, 10));
  line_to(p, point(5, 10));
  close(p);
  assert_eq(winding_at(p, 2, 5), 1, 0);
  assert_eq(winding_at(p, 5, 5), 1, 0);
  assert_eq(winding_at(p, 8, 5), 1, 0);
});

Deno.test("A diamond wound twice has winding number 2", () => {
  const p = polygon(point(5, 0), point(10, 5), point(5, 10), point(0, 5));
  // the same diamond, drawn a second time over itself
  move_to(p, point(5, 0));
  line_to(p, point(10, 5));
  line_to(p, point(5, 10));
  line_to(p, point(0, 5));
  close(p);
  assert_eq(edges(p).length, 8, 0);
  assert_eq(winding_at(p, 5, 5), 2, 0);
  assert_eq(crossings(p, 5, 5), 2, 0);
  assert_eq(winding_at(p, 12, 5), 0, 0);
});

Deno.test("The polygon circle", () => {
  const p = circle_path(10, 10, 5, 8);
  assert_eq(winding_at(p, 10, 10), 1, 0);
  assert_eq(winding_at(p, 14.9, 10), 1, 0);
  assert_eq(winding_at(p, 15, 10), 0, 0);
  assert_eq(winding_at(p, 10, 5.1), 1, 0);
  assert_eq(winding_at(p, 10, 4.9), 0, 0);
});

Deno.test("The pentagram's center winds twice", () => {
  const p = star();
  assert_eq(winding_at(p, 80.5, 80.5), 2, 0);
  assert_eq(crossings(p, 80.5, 80.5), 2, 0);
  assert_eq(winding_at(p, 80.5, 20), 1, 0);
  assert_eq(winding_at(p, 30, 60), 1, 0);
  assert_eq(crossings(p, 30, 60), 3, 0);
  assert_eq(winding_at(p, 80.5, 120), 0, 0);
  assert_eq(crossings(p, 80.5, 120), 2, 0);
  assert_eq(winding_at(p, 10, 10), 0, 0);
});
