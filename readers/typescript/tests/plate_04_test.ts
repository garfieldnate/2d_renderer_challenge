// features/chapter04-plate.feature
import { multiply, rotation, transform_points, translation } from "../src/matrix.ts";
import { point } from "../src/tuple.ts";
import { fan_both_orders, fan_points, letter_f, plate_04 } from "../src/scenes.ts";
import { canvas_to_p6, max_channel_difference, ppm_pixel } from "../src/ppm.ts";
import { assert_eq, assert_triple, assert_true, assert_tuple, read_file } from "../src/assert.ts";

Deno.test("The fan as points", () => {
  const pts = fan_points();
  assert_eq(pts.length, 13, 0);
  assert_tuple(pts[0], point(0, 0));
  assert_tuple(pts[1], point(36, 0));
  assert_tuple(pts[4], point(0, 36));
  assert_tuple(pts[7], point(-36, 0));
  assert_tuple(pts[2], point(31.1769, 18));
});

Deno.test("Rotate, then translate: the fan turns about its own center", () => {
  const m = multiply(translation(104.5, 76.5), rotation(Math.PI / 6));
  const pts = transform_points(fan_points(), m);
  assert_tuple(pts[0], point(104.5, 76.5));
  assert_tuple(pts[1], point(135.6769, 94.5));
  assert_tuple(pts[4], point(86.5, 107.6769));
});

Deno.test("Translate, then rotate: the fan swings about the canvas corner", () => {
  const m = multiply(rotation(Math.PI / 6), translation(104.5, 76.5));
  const pts = transform_points(fan_points(), m);
  assert_tuple(pts[0], point(52.2497, 118.5009));
  assert_tuple(pts[1], point(83.4266, 136.5009));
});

Deno.test("The letter F", () => {
  const f = letter_f();
  assert_eq(f.length, 10, 0);
  assert_tuple(f[0], point(-20, -30));
  assert_tuple(f[1], point(20, -30));
  assert_tuple(f[5], point(12, -5));
  assert_tuple(f[9], point(-20, 30));
});

Deno.test("The F at home", () => {
  const f = transform_points(letter_f(), translation(44.5, 44.5));
  assert_tuple(f[0], point(24.5, 14.5));
  assert_tuple(f[1], point(64.5, 14.5));
  assert_tuple(f[9], point(24.5, 74.5));
});

Deno.test("The F, rotated then translated", () => {
  const m = multiply(translation(104.5, 76.5), rotation(Math.PI / 6));
  const f = transform_points(letter_f(), m);
  assert_tuple(f[0], point(102.1795, 40.5192));
  assert_tuple(f[1], point(136.8205, 60.5192));
  assert_tuple(f[5], point(117.3923, 78.1699));
  assert_tuple(f[9], point(72.1795, 92.4808));
});

Deno.test("The F, translated then rotated", () => {
  const m = multiply(rotation(Math.PI / 6), translation(104.5, 76.5));
  const f = transform_points(letter_f(), m);
  assert_tuple(f[0], point(49.9291, 82.5202));
  assert_tuple(f[1], point(84.5702, 102.5202));
  assert_tuple(f[5], point(65.142, 120.1708));
  assert_tuple(f[9], point(19.9291, 134.4817));
});

Deno.test("The fan, both orders", () => {
  const c = fan_both_orders();
  const ref = read_file("reference/chapter-04/fan-both-orders.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 320, 0);
  assert_eq(c.height, 160, 0);
  assert_triple(ppm_pixel(p6, 104, 76), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 124, 76), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 104, 56), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 125, 88), [236, 236, 231], 1);
  assert_triple(ppm_pixel(p6, 116, 97), [236, 236, 231], 1);
  assert_triple(ppm_pixel(p6, 141, 76), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 10, 10), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 212, 118), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 232, 118), [246, 246, 241], 1);
  assert_triple(ppm_pixel(p6, 233, 130), [223, 223, 219], 1);
  assert_triple(ppm_pixel(p6, 224, 139), [236, 236, 231], 1);
  assert_triple(ppm_pixel(p6, 200, 139), [211, 211, 207], 1);
  assert_triple(ppm_pixel(p6, 310, 10), [39, 39, 44], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});

Deno.test("Plate 4", () => {
  const c = plate_04();
  const ref = read_file("reference/chapter-04/plate-04.ppm");
  const p6 = canvas_to_p6(c);
  assert_eq(c.width, 640, 0);
  assert_eq(c.height, 320, 0);
  assert_triple(ppm_pixel(p6, 48, 28), [99, 99, 102], 1);
  assert_triple(ppm_pixel(p6, 80, 28), [111, 111, 115], 1);
  assert_triple(ppm_pixel(p6, 48, 100), [111, 111, 115], 1);
  assert_triple(ppm_pixel(p6, 10, 10), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 200, 150), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 268, 129), [237, 237, 233], 1);
  assert_triple(ppm_pixel(p6, 215, 145), [237, 237, 233], 1);
  assert_triple(ppm_pixel(p6, 239, 101), [237, 237, 233], 1);
  assert_triple(ppm_pixel(p6, 174, 173), [217, 217, 213], 1);
  assert_triple(ppm_pixel(p6, 368, 28), [99, 99, 102], 1);
  assert_triple(ppm_pixel(p6, 500, 60), [39, 39, 44], 1);
  assert_triple(ppm_pixel(p6, 453, 207), [236, 236, 231], 1);
  assert_triple(ppm_pixel(p6, 431, 229), [234, 234, 229], 1);
  assert_triple(ppm_pixel(p6, 445, 249), [234, 234, 229], 1);
  assert_triple(ppm_pixel(p6, 368, 273), [177, 177, 174], 1);
  const d = max_channel_difference(p6, ref);
  assert_true(d <= 1, `max_channel_difference = ${d}`);
});
