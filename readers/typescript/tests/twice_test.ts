// features/chapter02-twice.feature
import { canvas, pixel_at } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import { coverage_buffer, paint_through, set_coverage } from "../src/coverage.ts";
import { painted_twice } from "../src/scenes.ts";
import { canvas_to_p6, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { assert_color, assert_eq, assert_triple, assert_true, read_file } from "../src/assert.ts";

Deno.test("Half coverage, painted twice, is three quarters", () => {
  const c = canvas(1, 1);
  const cov = coverage_buffer(1, 1);
  set_coverage(cov, 0, 0, 0.5);
  paint_through(c, cov, color(1, 1, 1));
  paint_through(c, cov, color(1, 1, 1));
  assert_color(pixel_at(c, 0, 0), color(0.75, 0.75, 0.75));
});

Deno.test("The disc, once and twice", () => {
  const c = painted_twice();
  const ref = read_file("reference/chapter-02/painted-twice.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 480, 0);
  assert_eq(c.height, 240, 0);
  assert_triple(ppm_pixel(p6, 120, 120), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 360, 120), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 93, 27), [157, 127, 64], 1);
  assert_triple(ppm_pixel(p6, 333, 27), [194, 156, 74], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
