// features/chapter03-bresenham.feature
import { canvas, write_pixel } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import { line_bresenham } from "../src/line.ts";
import { canvas_to_p6, max_channel_difference } from "../src/ppm.ts";
import { assert_eq, assert_pixels, lit_pixels } from "../src/assert.ts";

const WHITE = color(1, 1, 1);

Deno.test("lit_pixels reads like a page", () => {
  const c = canvas(10, 10);
  write_pixel(c, 5, 0, WHITE);
  write_pixel(c, 0, 2, WHITE);
  write_pixel(c, 2, 2, color(0.5, 0, 0));
  assert_pixels(lit_pixels(c), [[5, 0], [0, 2], [2, 2]]);
});

Deno.test("A diagonal", () => {
  const c = canvas(10, 10);
  line_bresenham(c, 0, 0, 5, 5, WHITE);
  assert_pixels(lit_pixels(c), [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]);
});

Deno.test("A horizontal line lights one row and nothing else", () => {
  const c = canvas(10, 10);
  line_bresenham(c, 0, 3, 7, 3, WHITE);
  assert_pixels(lit_pixels(c), [
    [0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3],
  ]);
});

Deno.test("A shallow line steps along x", () => {
  const c = canvas(10, 10);
  line_bresenham(c, 0, 0, 7, 3, WHITE);
  assert_pixels(lit_pixels(c), [
    [0, 0], [1, 0], [2, 1], [3, 1], [4, 2], [5, 2], [6, 3], [7, 3],
  ]);
});

Deno.test("A steep line steps along y", () => {
  const c = canvas(10, 10);
  line_bresenham(c, 1, 1, 3, 7, WHITE);
  assert_pixels(lit_pixels(c), [
    [1, 1], [1, 2], [2, 3], [2, 4], [2, 5], [3, 6], [3, 7],
  ]);
});

Deno.test("The pixels don't depend on which end you start from", () => {
  const c1 = canvas(10, 10);
  const c2 = canvas(10, 10);
  line_bresenham(c1, 1, 1, 3, 7, WHITE);
  line_bresenham(c2, 3, 7, 1, 1, WHITE);
  assert_pixels(lit_pixels(c1), lit_pixels(c2));
  assert_eq(max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)), 0, 0);
});

Deno.test("A line going up and to the right", () => {
  const c = canvas(10, 10);
  line_bresenham(c, 0, 6, 7, 3, WHITE);
  assert_pixels(lit_pixels(c), [
    [6, 3], [7, 3], [4, 4], [5, 4], [2, 5], [3, 5], [0, 6], [1, 6],
  ]);
});

Deno.test("At an exact half the line stays on its row one step longer", () => {
  const c = canvas(10, 10);
  line_bresenham(c, 0, 0, 4, 2, WHITE);
  assert_pixels(lit_pixels(c), [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2]]);
});

Deno.test("A line of one point", () => {
  const c = canvas(10, 10);
  line_bresenham(c, 3, 3, 3, 3, WHITE);
  assert_pixels(lit_pixels(c), [[3, 3]]);
});

Deno.test("A line may run off the canvas", () => {
  const c = canvas(10, 10);
  line_bresenham(c, 0, 0, 12, 6, WHITE);
  assert_eq(lit_pixels(c).length, 10, 0);
});
