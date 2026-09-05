// features/chapter01-ppm.feature
import { canvas, fill, write_pixel } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import {
  canvas_to_ppm,
  distinct_values,
  max_channel_difference,
  ppm_pixel,
} from "../src/ppm.ts";
import {
  assert_eq,
  assert_lines,
  assert_triple,
  assert_true,
  lines_of,
} from "../src/assert.ts";

Deno.test("The PPM header", () => {
  const c = canvas(5, 3);
  const ppm = canvas_to_ppm(c);
  assert_lines(ppm, 1, 3, `
      P3
      5 3
      255
  `);
});

Deno.test("Pixel values are encoded, not scaled", () => {
  const c = canvas(3, 1);
  write_pixel(c, 0, 0, color(1, 0, 0));
  write_pixel(c, 1, 0, color(0, 0.5, 0));
  write_pixel(c, 2, 0, color(0, 0, 0.216));
  const ppm = canvas_to_ppm(c);
  assert_lines(ppm, 4, 4, "255 0 0 0 188 0 0 0 128");
});

Deno.test("Colors out of range are clamped, not wrapped", () => {
  const c = canvas(2, 1);
  write_pixel(c, 0, 0, color(1.5, 0, -0.5));
  const ppm = canvas_to_ppm(c);
  assert_lines(ppm, 4, 4, "255 0 0 0 0 0");
});

Deno.test("Every row starts a new line, and no line exceeds 70 characters", () => {
  const c = canvas(10, 2);
  fill(c, color(1, 0.8, 0.6));
  const ppm = canvas_to_ppm(c);
  assert_lines(ppm, 4, 7, `
      255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231
      203 255 231 203 255 231 203 255 231 203 255 231 203
      255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231
      203 255 231 203 255 231 203 255 231 203 255 231 203
  `);
  for (const line of lines_of(ppm)) {
    assert_true(line.length <= 70, `line longer than 70: ${line.length}`);
  }
});

Deno.test("A line of exactly 70 characters is allowed", () => {
  const c = canvas(8, 1);
  fill(c, color(1, 0.1, 0));
  write_pixel(c, 7, 0, color(1, 1, 1));
  const ppm = canvas_to_ppm(c);
  assert_lines(ppm, 4, 5, `
      255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 255
      255
  `);
  assert_eq(lines_of(ppm)[3].length, 70, 0);
});

Deno.test("The file ends with a newline", () => {
  const c = canvas(5, 3);
  const ppm = canvas_to_ppm(c);
  assert_true(ppm.endsWith("\n"), "ppm does not end with a newline");
});

Deno.test("Reading a pixel back out of the text", () => {
  const c = canvas(3, 2);
  write_pixel(c, 2, 1, color(0, 0.5, 1));
  const ppm = canvas_to_ppm(c);
  assert_triple(ppm_pixel(ppm, 2, 1), [0, 188, 255]);
  assert_triple(ppm_pixel(ppm, 1, 1), [0, 0, 0]);
});

Deno.test("Counting the distinct values in a file", () => {
  const c = canvas(3, 1);
  write_pixel(c, 0, 0, color(1, 0, 0));
  write_pixel(c, 1, 0, color(0, 0.5, 0));
  write_pixel(c, 2, 0, color(0, 0, 0.216));
  const ppm = canvas_to_ppm(c);
  assert_eq(distinct_values(ppm), 4, 0);
});

Deno.test("Comparing two files", () => {
  const c1 = canvas(2, 1);
  const c2 = canvas(2, 1);
  write_pixel(c2, 0, 0, color(0.5, 0, 0));
  const ppm1 = canvas_to_ppm(c1);
  const ppm2 = canvas_to_ppm(c2);
  assert_eq(max_channel_difference(ppm1, ppm1), 0, 0);
  assert_eq(max_channel_difference(ppm1, ppm2), 188, 0);
});

Deno.test("Files of different sizes are as different as it gets", () => {
  const ppm1 = canvas_to_ppm(canvas(5, 3));
  const ppm2 = canvas_to_ppm(canvas(3, 5));
  assert_eq(max_channel_difference(ppm1, ppm2), 255, 0);
});
