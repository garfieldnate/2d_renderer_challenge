// features/chapter02-p6.feature
import { canvas, write_pixel } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import {
  canvas_to_p6,
  canvas_to_ppm,
  distinct_values,
  max_channel_difference,
  ppm_pixel,
} from "../src/ppm.ts";
import { assert_begins_with, assert_eq, assert_triple, byte_of } from "../src/assert.ts";

Deno.test("The header, then the bytes", () => {
  const c = canvas(2, 1);
  write_pixel(c, 0, 0, color(1, 0, 0));
  write_pixel(c, 1, 0, color(0, 0.5, 0));
  const p6 = canvas_to_p6(c);
  assert_begins_with(p6, "P6\n2 1\n255\n");
  assert_eq(p6.length, 17, 0, "length(p6)");
  assert_eq(byte_of(p6, 12), 255, 0, "byte 12");
  assert_eq(byte_of(p6, 13), 0, 0, "byte 13");
  assert_eq(byte_of(p6, 16), 188, 0, "byte 16");
});

Deno.test("The same pixel comes back out of either format", () => {
  const c = canvas(2, 1);
  write_pixel(c, 1, 0, color(0, 0.5, 0));
  const p3 = canvas_to_ppm(c);
  const p6 = canvas_to_p6(c);
  assert_triple(ppm_pixel(p6, 1, 0), [0, 188, 0]);
  assert_triple(ppm_pixel(p3, 1, 0), [0, 188, 0]);
  assert_eq(max_channel_difference(p3, p6), 0, 0);
  assert_eq(distinct_values(p6), 2, 0);
});

Deno.test("Sizes still have to match", () => {
  const p6a = canvas_to_p6(canvas(2, 1));
  const p6b = canvas_to_p6(canvas(1, 2));
  assert_eq(max_channel_difference(p6a, p6b), 255, 0);
});
