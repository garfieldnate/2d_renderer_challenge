// features/chapter01-canvas.feature
import { canvas, fill, pixel_at, write_pixel } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import { assert_color, assert_eq, assert_every_pixel } from "../src/assert.ts";

Deno.test("A new canvas is black", () => {
  const c = canvas(10, 20);
  assert_eq(c.width, 10);
  assert_eq(c.height, 20);
  assert_every_pixel(c, color(0, 0, 0));
});

Deno.test("Writing a pixel", () => {
  const c = canvas(10, 20);
  const red = color(1, 0, 0);
  write_pixel(c, 2, 3, red);
  assert_color(pixel_at(c, 2, 3), red);
});

Deno.test("x is the column and y is the row", () => {
  const c = canvas(10, 20);
  write_pixel(c, 2, 3, color(1, 0, 0));
  assert_color(pixel_at(c, 3, 2), color(0, 0, 0));
  assert_color(pixel_at(c, 2, 3), color(1, 0, 0));
});

Deno.test("Writing outside the canvas is ignored", () => {
  const c = canvas(10, 20);
  write_pixel(c, -1, 5, color(1, 0, 0));
  write_pixel(c, 10, 5, color(1, 0, 0));
  write_pixel(c, 5, -1, color(1, 0, 0));
  write_pixel(c, 5, 20, color(1, 0, 0));
  assert_every_pixel(c, color(0, 0, 0));
});

Deno.test("A pixel can be written more than once", () => {
  const c = canvas(10, 20);
  write_pixel(c, 2, 3, color(1, 0, 0));
  write_pixel(c, 2, 3, color(0, 1, 0));
  assert_color(pixel_at(c, 2, 3), color(0, 1, 0));
});

Deno.test("Filling a canvas", () => {
  const c = canvas(10, 20);
  fill(c, color(0.1, 0.2, 0.3));
  assert_every_pixel(c, color(0.1, 0.2, 0.3));
});
