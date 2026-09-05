// features/chapter01-limits.feature
import { pixel_at } from "../src/canvas.ts";
import { color } from "../src/color.ts";
import {
  canvas_to_ppm,
  distinct_values,
  max_channel_difference,
  ppm_pixel,
} from "../src/ppm.ts";
import { clamp_pair, ramp } from "../src/scenes.ts";
import {
  assert_color,
  assert_eq,
  assert_lines,
  assert_triple,
  assert_true,
  read_file,
} from "../src/assert.ts";

Deno.test("A 256-step ramp", () => {
  const c = ramp();
  assert_eq(c.width, 256, 0);
  assert_eq(c.height, 32, 0);
  assert_color(pixel_at(c, 0, 0), color(0, 0, 0));
  assert_color(pixel_at(c, 128, 0), color(0.5020, 0.5020, 0.5020));
  assert_color(pixel_at(c, 255, 31), color(1, 1, 1));
});

Deno.test("Encoding stretches the dark end and squeezes the bright end", () => {
  const ppm = canvas_to_ppm(ramp());
  assert_lines(
    ppm,
    4,
    4,
    "0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46",
  );
  assert_triple(ppm_pixel(ppm, 75, 0), [148, 148, 148], 1);
  assert_triple(ppm_pixel(ppm, 76, 0), [148, 148, 148], 1);
  assert_triple(ppm_pixel(ppm, 254, 0), [255, 255, 255], 1);
  assert_eq(distinct_values(ppm), 183, 0);
  const ref = read_file("reference/chapter-01/ramp.ppm");
  const d = max_channel_difference(ppm, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("Clamping changes the color, not only the brightness", () => {
  const c = clamp_pair();
  assert_eq(c.width, 200, 0);
  assert_eq(c.height, 100, 0);
  assert_color(pixel_at(c, 50, 50), color(2, 0.5, 0.5));
  assert_color(pixel_at(c, 150, 50), color(1, 0.25, 0.25));
  const ppm = canvas_to_ppm(c);
  assert_triple(ppm_pixel(ppm, 50, 50), [255, 188, 188], 1);
  assert_triple(ppm_pixel(ppm, 150, 50), [255, 137, 137], 1);
  const ref = read_file("reference/chapter-01/clamp-pair.ppm");
  const d = max_channel_difference(ppm, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
