// features/chapter03-wu.feature
import { canvas, pixel_at } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import { line_wu } from "../src/line.ts";
import { canvas_to_p6, max_channel_difference } from "../src/ppm.ts";
import {
  assert_color,
  assert_eq,
  assert_pixels,
  lit_pixels,
  total_ink,
} from "../src/assert.ts";

const WHITE = color(1, 1, 1);
const gray = (v: number) => color(v, v, v);

Deno.test("A half step lights two pixels equally", () => {
  const c = canvas(10, 10);
  line_wu(c, 0, 0, 4, 2, WHITE);
  assert_color(pixel_at(c, 0, 0), color(1, 1, 1));
  assert_color(pixel_at(c, 1, 0), gray(0.5));
  assert_color(pixel_at(c, 1, 1), gray(0.5));
  assert_color(pixel_at(c, 2, 1), color(1, 1, 1));
  assert_color(pixel_at(c, 2, 2), color(0, 0, 0));
  assert_color(pixel_at(c, 4, 2), color(1, 1, 1));
  assert_eq(total_ink(c), 5);
});

Deno.test("A diagonal has uniform weights", () => {
  const c = canvas(10, 10);
  line_wu(c, 0, 0, 5, 5, WHITE);
  assert_pixels(lit_pixels(c), [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]);
  assert_color(pixel_at(c, 3, 3), color(1, 1, 1));
  assert_eq(total_ink(c), 6);
});

Deno.test("A horizontal line has weight 1 on its row and 0 on the neighbors", () => {
  const c = canvas(10, 10);
  line_wu(c, 0, 3, 7, 3, WHITE);
  assert_pixels(lit_pixels(c), [
    [0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3],
  ]);
  assert_color(pixel_at(c, 3, 3), color(1, 1, 1));
  assert_color(pixel_at(c, 3, 2), color(0, 0, 0));
  assert_color(pixel_at(c, 3, 4), color(0, 0, 0));
  assert_eq(total_ink(c), 8);
});

Deno.test("A steep line weights across columns", () => {
  const c = canvas(10, 10);
  line_wu(c, 1, 1, 3, 7, WHITE);
  assert_color(pixel_at(c, 1, 1), color(1, 1, 1));
  assert_color(pixel_at(c, 1, 2), gray(0.6667));
  assert_color(pixel_at(c, 2, 2), gray(0.3333));
  assert_color(pixel_at(c, 2, 4), color(1, 1, 1));
  assert_color(pixel_at(c, 3, 7), color(1, 1, 1));
  assert_eq(total_ink(c), 7);
});

Deno.test("The weights don't depend on which end you start from", () => {
  const c1 = canvas(10, 10);
  const c2 = canvas(10, 10);
  line_wu(c1, 1, 1, 3, 7, WHITE);
  line_wu(c2, 3, 7, 1, 1, WHITE);
  assert_eq(max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)), 0, 0);
});

// yi comes from floor, not trunc: y goes negative here (-1, -0.5, ...),
// and trunc(-0.5) would give the wrong pixel and a negative weight.
Deno.test("A line that starts above the canvas", () => {
  const c = canvas(10, 10);
  line_wu(c, 0, -1, 8, 3, WHITE);
  assert_color(pixel_at(c, 1, 0), gray(0.5));
  assert_color(pixel_at(c, 2, 0), color(1, 1, 1));
  assert_eq(total_ink(c), 7.5);
});

Deno.test("A Wu line of one point", () => {
  const c = canvas(10, 10);
  line_wu(c, 3, 3, 3, 3, WHITE);
  assert_pixels(lit_pixels(c), [[3, 3]]);
  assert_color(pixel_at(c, 3, 3), color(1, 1, 1));
});

Deno.test("Sevenths", () => {
  const c = canvas(10, 10);
  line_wu(c, 0, 0, 7, 3, WHITE);
  assert_color(pixel_at(c, 1, 0), gray(0.5714));
  assert_color(pixel_at(c, 1, 1), gray(0.4286));
  assert_color(pixel_at(c, 2, 0), gray(0.1429));
  assert_color(pixel_at(c, 2, 1), gray(0.8571));
  assert_eq(total_ink(c), 8);
});

for (const [x1, y1, expected] of [[12, 2, 11], [10, 8, 9], [8, 10, 9], [2, 12, 11]]) {
  Deno.test(`The ink depends on the angle: (2, 2) to (${x1}, ${y1}) is ${expected}`, () => {
    const c = canvas(20, 20);
    line_wu(c, 2, 2, x1, y1, WHITE);
    assert_eq(total_ink(c), expected);
  });
}
