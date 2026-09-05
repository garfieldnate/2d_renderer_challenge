// features/chapter02-shapes.feature
import { circle, half_plane, inside, rectangle } from "../src/shape.ts";
import { assert_true } from "../src/assert.ts";

function is(v: boolean, want: boolean, what: string): void {
  assert_true(v === want, `${what}: expected ${want}, got ${v}`);
}

Deno.test("A point inside a circle", () => {
  const s = circle(8, 8, 5);
  is(inside(s, 8, 8), true, "inside(s, 8, 8)");
  is(inside(s, 12, 8), true, "inside(s, 12, 8)");
  is(inside(s, 13, 8), true, "inside(s, 13, 8)");
  is(inside(s, 13.01, 8), false, "inside(s, 13.01, 8)");
  is(inside(s, 11.6, 11.6), false, "inside(s, 11.6, 11.6)");
});

Deno.test("A point inside a rectangle", () => {
  const s = rectangle(1.25, 2.0, 4.75, 5.0);
  is(inside(s, 3, 3), true, "inside(s, 3, 3)");
  is(inside(s, 1.25, 2.0), true, "inside(s, 1.25, 2.0)");
  is(inside(s, 4.75, 5.0), true, "inside(s, 4.75, 5.0)");
  is(inside(s, 1.2, 3), false, "inside(s, 1.2, 3)");
  is(inside(s, 3, 5.1), false, "inside(s, 3, 5.1)");
});

Deno.test("A point inside a half-plane", () => {
  const s = half_plane(2.5, 0, 1, 0);
  is(inside(s, 2.5, 7), true, "inside(s, 2.5, 7)");
  is(inside(s, 3, -4), true, "inside(s, 3, -4)");
  is(inside(s, 2.4, 0), false, "inside(s, 2.4, 0)");
});

Deno.test("The normal picks the side", () => {
  const s = half_plane(2.5, 0, -1, 0);
  is(inside(s, 2.4, 0), true, "inside(s, 2.4, 0)");
  is(inside(s, 3, 0), false, "inside(s, 3, 0)");
});
