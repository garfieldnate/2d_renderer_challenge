// features/chapter01-gray-match.feature
import { pixel_at } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import { canvas_to_ppm, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { gray_match, quarter_match } from "../src/scenes.ts";
import {
  assert_color,
  assert_eq,
  assert_triple,
  assert_true,
  count_pixels,
  read_file,
} from "../src/assert.ts";

Deno.test("The gray match", () => {
  const c = gray_match();
  assert_eq(c.width, 300, 0);
  assert_eq(c.height, 100, 0);
  assert_color(pixel_at(c, 0, 0), color(1, 1, 1));
  assert_color(pixel_at(c, 1, 0), color(0, 0, 0));
  assert_color(pixel_at(c, 0, 1), color(0, 0, 0));
  assert_color(pixel_at(c, 1, 1), color(1, 1, 1));
  assert_color(pixel_at(c, 150, 50), color(0.2159, 0.2159, 0.2159));
  assert_color(pixel_at(c, 250, 50), color(0.5, 0.5, 0.5));
  assert_eq(count_pixels(c, color(1, 1, 1)), 5000, 0);
});

Deno.test("The gray match, as a file", () => {
  const c = gray_match();
  const ppm = canvas_to_ppm(c);
  assert_triple(ppm_pixel(ppm, 0, 0), [255, 255, 255], 1);
  assert_triple(ppm_pixel(ppm, 1, 0), [0, 0, 0], 1);
  assert_triple(ppm_pixel(ppm, 150, 50), [128, 128, 128], 1);
  assert_triple(ppm_pixel(ppm, 250, 50), [188, 188, 188], 1);
  const ref = read_file("reference/chapter-01/gray-match.ppm");
  const d = max_channel_difference(ppm, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("One pixel in four", () => {
  const c = quarter_match();
  assert_eq(c.width, 200, 0);
  assert_eq(c.height, 100, 0);
  assert_color(pixel_at(c, 0, 0), color(1, 1, 1));
  assert_color(pixel_at(c, 1, 0), color(0, 0, 0));
  assert_color(pixel_at(c, 2, 2), color(1, 1, 1));
  assert_color(pixel_at(c, 3, 1), color(1, 1, 1));
  assert_color(pixel_at(c, 150, 50), color(0.25, 0.25, 0.25));
  assert_eq(count_pixels(c, color(1, 1, 1)), 2500, 0);
  const ppm = canvas_to_ppm(c);
  assert_triple(ppm_pixel(ppm, 150, 50), [137, 137, 137], 1);
  const ref = read_file("reference/chapter-01/quarter-match.ppm");
  const d = max_channel_difference(ppm, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
