// features/chapter02-paint.feature
import { canvas, fill, pixel_at } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import { coverage_buffer, paint_through, set_coverage } from "../src/coverage.ts";
import { canvas_to_p6, canvas_to_ppm, distinct_values, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { disc_centers } from "../src/scenes.ts";
import { set_linear_blending } from "../src/mix.ts";
import {
  assert_color,
  assert_eq,
  assert_triple,
  assert_true,
  read_file,
} from "../src/assert.ts";

Deno.test("Half coverage is half the paint", () => {
  const c = canvas(1, 1);
  const cov = coverage_buffer(1, 1);
  set_coverage(cov, 0, 0, 0.5);
  paint_through(c, cov, color(1, 1, 1));
  assert_color(pixel_at(c, 0, 0), color(0.5, 0.5, 0.5));
});

Deno.test("Paint over something that isn't black", () => {
  const c = canvas(1, 1);
  const cov = coverage_buffer(1, 1);
  fill(c, color(0.2, 0.2, 0.2));
  set_coverage(cov, 0, 0, 0.25);
  paint_through(c, cov, color(1, 0, 0));
  assert_color(pixel_at(c, 0, 0), color(0.4, 0.15, 0.15));
});

Deno.test("Zero leaves it alone and one replaces it", () => {
  const c = canvas(2, 1);
  const cov = coverage_buffer(2, 1);
  fill(c, color(0.2, 0.2, 0.2));
  set_coverage(cov, 1, 0, 1);
  paint_through(c, cov, color(1, 0, 0));
  assert_color(pixel_at(c, 0, 0), color(0.2, 0.2, 0.2));
  assert_color(pixel_at(c, 1, 0), color(1, 0, 0));
});

// paint_through always mixes in light, even with the naive-blending switch
// off: this is the probe that would catch it reading the switch instead.
Deno.test("The arithmetic is on light, whatever the switch says", () => {
  set_linear_blending(false);
  try {
    const c = canvas(1, 1);
    const cov = coverage_buffer(1, 1);
    set_coverage(cov, 0, 0, 0.5);
    paint_through(c, cov, color(1, 1, 1));
    const ppm = canvas_to_ppm(c);
    assert_color(pixel_at(c, 0, 0), color(0.5, 0.5, 0.5));
    assert_triple(ppm_pixel(ppm, 0, 0), [188, 188, 188]);
  } finally {
    set_linear_blending(true);
  }
});

Deno.test("The disc by centers", () => {
  const c = disc_centers();
  const ref = read_file("reference/chapter-02/disc-centers.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 320, 0);
  assert_eq(c.height, 320, 0);
  assert_triple(ppm_pixel(p6, 160, 160), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 124, 36), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 132, 36), [243, 196, 89], 1);
  assert_eq(distinct_values(p6), 5, 0);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
