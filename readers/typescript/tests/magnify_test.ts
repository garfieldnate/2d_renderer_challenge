// features/chapter02-magnify.feature
import { canvas, magnify, pixel_at, write_pixel } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import { canvas_to_p6, max_channel_difference } from "../src/ppm.ts";
import { assert_color, assert_eq, count_pixels } from "../src/assert.ts";

Deno.test("Every pixel becomes a block", () => {
  const c = canvas(2, 1);
  write_pixel(c, 0, 0, color(1, 0, 0));
  write_pixel(c, 1, 0, color(0, 0.5, 0));
  const m = magnify(c, 3);
  assert_eq(m.width, 6, 0);
  assert_eq(m.height, 3, 0);
  assert_color(pixel_at(m, 0, 0), color(1, 0, 0));
  assert_color(pixel_at(m, 2, 2), color(1, 0, 0));
  assert_color(pixel_at(m, 3, 0), color(0, 0.5, 0));
  assert_color(pixel_at(m, 5, 2), color(0, 0.5, 0));
  assert_eq(count_pixels(m, color(1, 0, 0)), 9, 0);
});

Deno.test("Magnifying by one changes nothing", () => {
  const c = canvas(2, 1);
  write_pixel(c, 1, 0, color(0, 0.5, 0));
  const m = magnify(c, 1);
  assert_eq(max_channel_difference(canvas_to_p6(c), canvas_to_p6(m)), 0, 0);
});
