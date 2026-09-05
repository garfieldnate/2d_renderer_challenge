// features/chapter02-plate.feature
import { plate_02 } from "../src/scenes.ts";
import { canvas_to_p6, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { assert_eq, assert_triple, assert_true, read_file } from "../src/assert.ts";

Deno.test("The plate (chapter 2)", () => {
  const c = plate_02();
  const ref = read_file("reference/chapter-02/plate-02.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 480, 0);
  assert_eq(c.height, 240, 0);
  assert_triple(ppm_pixel(p6, 120, 120), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 360, 120), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 93, 27), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 333, 27), [157, 127, 64], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
