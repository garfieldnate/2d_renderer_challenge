// features/chapter06-edges.feature
import { close, line_to, move_to, path, polygon } from "../src/path.ts";
import { edge_table, x_at } from "../src/sweep.ts";
import { point } from "../src/tuple.ts";
import { assert_eq } from "../src/assert.ts";

Deno.test("A rectangle has two edges in its table", () => {
  const p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6));
  const t = edge_table(p);
  assert_eq(t.length, 2, 0);
  assert_eq(t[0].y_top, 2);
  assert_eq(t[0].y_bottom, 6);
  assert_eq(t[0].x_top, 2);
  assert_eq(t[0].slope, 0);
  assert_eq(t[0].direction, -1, 0);
  assert_eq(t[1].x_top, 6);
  assert_eq(t[1].direction, 1, 0);
});

Deno.test("A triangle's edges carry their slopes", () => {
  const p = polygon(point(0, 0), point(10, 0), point(5, 10));
  const t = edge_table(p);
  assert_eq(t.length, 2, 0);
  assert_eq(t[0].x_top, 0);
  assert_eq(t[0].slope, 0.5);
  assert_eq(t[0].direction, -1, 0);
  assert_eq(t[1].x_top, 10);
  assert_eq(t[1].slope, -0.5);
  assert_eq(t[1].direction, 1, 0);
});

Deno.test("The table is sorted by top, then by x at the top", () => {
  const p = path();
  move_to(p, point(2, 2));
  line_to(p, point(4, 1));
  line_to(p, point(6, 3));
  line_to(p, point(8, 1));
  line_to(p, point(9, 6));
  line_to(p, point(1, 6));
  close(p);
  const t = edge_table(p);
  assert_eq(t.length, 5, 0);
  assert_eq(t[0].y_top, 1);
  assert_eq(t[0].x_top, 4);
  assert_eq(t[1].y_top, 1);
  assert_eq(t[1].x_top, 4);
  assert_eq(t[2].y_top, 1);
  assert_eq(t[2].x_top, 8);
  assert_eq(t[3].y_top, 1);
  assert_eq(t[3].x_top, 8);
  assert_eq(t[4].y_top, 2);
  assert_eq(t[4].x_top, 2);
});

Deno.test("A horizontal edge is dropped, not clamped", () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5));
  const t = edge_table(p);
  assert_eq(t.length, 2, 0);
  assert_eq(t[0].x_top, 0);
  assert_eq(t[1].x_top, 10);
});

Deno.test("An edge knows where it crosses a height", () => {
  const p = polygon(point(0, 0), point(10, 0), point(5, 10));
  const t = edge_table(p);
  assert_eq(x_at(t[0], 4), 2);
  assert_eq(x_at(t[1], 4), 8);
  assert_eq(x_at(t[0], 0.5), 0.25);
});

Deno.test("The edge table is the same whichever way the path was drawn", () => {
  const a = polygon(point(0, 0), point(10, 0), point(5, 10));
  const b = polygon(point(0, 0), point(5, 10), point(10, 0));
  const ta = edge_table(a);
  const tb = edge_table(b);
  assert_eq(ta[0].x_top, tb[0].x_top);
  assert_eq(ta[0].slope, tb[0].slope);
  assert_eq(ta[0].direction, -1, 0);
  assert_eq(tb[0].direction, 1, 0);
});
