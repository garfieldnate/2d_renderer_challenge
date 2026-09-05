// features/chapter03-plate.feature
import { fan_bresenham, fan_coverage, fan_wu, plate_03, ray_ends } from "../src/scenes.ts";
import { canvas_to_p6, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { assert_eq, assert_pixels, assert_triple, assert_true, read_file } from "../src/assert.ts";

Deno.test("The ray endpoints", () => {
  assert_pixels(ray_ends(), [
    [152, 80], [142, 116], [116, 142], [80, 152], [44, 142], [18, 116],
    [8, 80], [18, 44], [44, 18], [80, 8], [116, 18], [142, 44],
  ]);
});

Deno.test("Bresenham's fan", () => {
  const c = fan_bresenham();
  const ref = read_file("reference/chapter-03/fan-bresenham.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 160, 0);
  assert_eq(c.height, 160, 0);
  assert_triple(ppm_pixel(p6, 80, 80), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 120, 80), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 10, 10), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 100, 91), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 100, 92), [246, 246, 241], 1);
  // the steep rays, where a transposed x/y would show up
  assert_triple(ppm_pixel(p6, 103, 120), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 102, 120), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 104, 120), [39, 39, 44], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("Wu's fan", () => {
  const c = fan_wu();
  const ref = read_file("reference/chapter-03/fan-wu.ppm");
  const p6 = canvas_to_p6(c);
  assert_triple(ppm_pixel(p6, 80, 80), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 120, 80), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 100, 91), [163, 163, 161], 1);
  assert_triple(ppm_pixel(p6, 100, 92), [199, 199, 196], 1);
  assert_triple(ppm_pixel(p6, 103, 120), [220, 220, 216], 1);
  assert_triple(ppm_pixel(p6, 104, 120), [130, 130, 129], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("The fan as twelve thin rectangles", () => {
  const c = fan_coverage();
  const ref = read_file("reference/chapter-03/fan-coverage.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 320, 0);
  assert_eq(c.height, 320, 0);
  assert_triple(ppm_pixel(p6, 160, 160), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 10, 10), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 240, 160), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 240, 158), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 200, 183), [177, 177, 174], 1);
  assert_triple(ppm_pixel(p6, 200, 185), [209, 209, 205], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("Plate 3", () => {
  const c = plate_03();
  const ref = read_file("reference/chapter-03/plate-03.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 640, 0);
  assert_eq(c.height, 320, 0);
  assert_triple(ppm_pixel(p6, 160, 160), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 480, 160), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 10, 10), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 200, 183), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 200, 185), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 520, 183), [163, 163, 161], 1);
  assert_triple(ppm_pixel(p6, 520, 185), [199, 199, 196], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
