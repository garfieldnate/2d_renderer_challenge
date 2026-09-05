// features/chapter01-plate.feature
import { canvas_to_ppm, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { plate_01 } from "../src/scenes.ts";
import { linear_blending, set_linear_blending } from "../src/mix.ts";
import { assert_eq, assert_triple, assert_true, read_file } from "../src/assert.ts";

Deno.test("The plate", () => {
  set_linear_blending(true);
  const c = plate_01();
  assert_eq(c.width, 400, 0);
  assert_eq(c.height, 180, 0);
  const ppm = canvas_to_ppm(c);
  assert_triple(ppm_pixel(ppm, 0, 20), [0, 0, 0], 1);
  assert_triple(ppm_pixel(ppm, 399, 20), [255, 255, 255], 1);
  assert_triple(ppm_pixel(ppm, 200, 20), [128, 128, 128], 1);
  assert_triple(ppm_pixel(ppm, 200, 65), [188, 188, 188], 1);
  assert_triple(ppm_pixel(ppm, 200, 42), [0, 0, 0], 1);
  assert_triple(ppm_pixel(ppm, 0, 110), [218, 0, 0], 1);
  assert_triple(ppm_pixel(ppm, 399, 110), [0, 149, 39], 1);
  assert_triple(ppm_pixel(ppm, 200, 110), [109, 75, 19], 1);
  assert_triple(ppm_pixel(ppm, 200, 155), [160, 108, 26], 1);
  assert_triple(ppm_pixel(ppm, 200, 87), [0, 0, 0], 1);
  assert_triple(ppm_pixel(ppm, 200, 132), [0, 0, 0], 1);
  assert_triple(ppm_pixel(ppm, 200, 177), [0, 0, 0], 1);
  const ref = read_file("reference/chapter-01/plate-01.ppm");
  const d = max_channel_difference(ppm, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
  assert_true(linear_blending(), "linear blending is off");
});
