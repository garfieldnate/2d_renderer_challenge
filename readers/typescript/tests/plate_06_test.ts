// features/chapter06-plate.feature
import { bounds, edges, subpaths } from "../src/path.ts";
import { plate_06, spiral, unit_star } from "../src/scenes.ts";
import { canvas_to_p6, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { assert_bounds, assert_eq, assert_triple, assert_true, assert_tuple, read_file } from "../src/assert.ts";
import { point } from "../src/tuple.ts";

Deno.test("The unit star", () => {
  const p = unit_star();
  assert_eq(edges(p).length, 5, 0);
  assert_tuple(subpaths(p)[0].points[0], point(0, -1));
  assert_tuple(subpaths(p)[0].points[1], point(0.5878, 0.809));
  assert_tuple(subpaths(p)[0].points[2], point(-0.9511, -0.309));
  assert_bounds(bounds(p), { minX: -0.9511, minY: -1, maxX: 0.9511, maxY: 0.809 });
});

Deno.test("The spiral", () => {
  const c = spiral();
  const ref = read_file("reference/chapter-06/spiral.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 320, 0);
  assert_eq(c.height, 320, 0);
  assert_triple(ppm_pixel(p6, 180, 160), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 183, 171), [124, 196, 237], 1);
  assert_triple(ppm_pixel(p6, 179, 183), [237, 137, 149], 1);
  assert_triple(ppm_pixel(p6, 104, 139), [237, 137, 149], 1);
  assert_triple(ppm_pixel(p6, 230, 111), [124, 196, 237], 1);
  assert_triple(ppm_pixel(p6, 32, 137), [124, 196, 237], 1);
  assert_triple(ppm_pixel(p6, 34, 104), [237, 137, 149], 1);
  assert_triple(ppm_pixel(p6, 160, 160), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 5, 5), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 300, 20), [39, 39, 44], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("Plate 6", () => {
  const c = plate_06();
  const ref = read_file("reference/chapter-06/plate-06.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 640, 0);
  assert_eq(c.height, 640, 0);
  assert_triple(ppm_pixel(p6, 360, 320), [243, 196, 89], 1);
  assert_triple(ppm_pixel(p6, 68, 208), [237, 137, 149], 1);
  assert_triple(ppm_pixel(p6, 320, 320), [39, 39, 44], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
