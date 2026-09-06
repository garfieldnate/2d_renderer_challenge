// features/chapter05-plate.feature
import { bounds, edges, subpaths } from "../src/path.ts";
import { plate_05, star, star_centers, star_coverage } from "../src/scenes.ts";
import { canvas_to_p6, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { assert_bounds, assert_eq, assert_triple, assert_true, assert_tuple, read_file } from "../src/assert.ts";
import { point } from "../src/tuple.ts";

Deno.test("The pentagram", () => {
  const p = star();
  assert_eq(subpaths(p).length, 1, 0);
  assert_eq(edges(p).length, 5, 0);
  assert_tuple(subpaths(p)[0].points[0], point(80.5, 10.5));
  assert_tuple(subpaths(p)[0].points[1], point(121.645, 137.1312));
  assert_tuple(subpaths(p)[0].points[2], point(13.926, 58.8688));
  assert_tuple(subpaths(p)[0].points[3], point(147.074, 58.8688));
  assert_tuple(subpaths(p)[0].points[4], point(39.355, 137.1312));
  assert_bounds(bounds(p), { minX: 13.926, minY: 10.5, maxX: 147.074, maxY: 137.1312 });
});

Deno.test("The star by the center question", () => {
  const c = star_centers();
  const ref = read_file("reference/chapter-05/star-centers.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 320, 0);
  assert_eq(c.height, 160, 0);
  assert_triple(ppm_pixel(p6, 80, 80), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 240, 80), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 80, 20), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 240, 20), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 30, 60), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 190, 60), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 80, 120), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 80, 10), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 10, 10), [39, 39, 44], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("The star by coverage", () => {
  const c = star_coverage();
  const ref = read_file("reference/chapter-05/star-coverage.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 320, 0);
  assert_eq(c.height, 160, 0);
  assert_triple(ppm_pixel(p6, 80, 80), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 240, 80), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 80, 20), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 240, 20), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 80, 120), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 80, 10), [77, 65, 48], 1);
  assert_triple(ppm_pixel(p6, 240, 10), [77, 65, 48], 1);
  assert_triple(ppm_pixel(p6, 80, 11), [199, 160, 76], 1);
  assert_triple(ppm_pixel(p6, 14, 58), [101, 83, 52], 1);
  assert_triple(ppm_pixel(p6, 174, 58), [101, 83, 52], 1);
  assert_triple(ppm_pixel(p6, 10, 10), [39, 39, 44], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("Plate 5", () => {
  const c = plate_05();
  const ref = read_file("reference/chapter-05/plate-05.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 640, 0);
  assert_eq(c.height, 640, 0);
  assert_triple(ppm_pixel(p6, 160, 160), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 480, 160), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 160, 480), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 480, 480), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 160, 40), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 480, 360), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 160, 20), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 160, 341), [77, 65, 48], 1);
  assert_triple(ppm_pixel(p6, 480, 341), [77, 65, 48], 1);
  assert_triple(ppm_pixel(p6, 348, 437), [101, 83, 52], 1);
  assert_triple(ppm_pixel(p6, 20, 20), [39, 39, 44], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
