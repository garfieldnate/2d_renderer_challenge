// features/chapter01-colors.feature
import { add, color, multiply, scale, sub } from "../src/color.ts";
import { assert_color, assert_color_ne, assert_eq } from "../src/assert.ts";

Deno.test("A color is a red, green, blue tuple", () => {
  const c = color(-0.5, 0.4, 1.7);
  assert_eq(c.red, -0.5);
  assert_eq(c.green, 0.4);
  assert_eq(c.blue, 1.7);
});

Deno.test("Adding colors", () => {
  const c1 = color(0.9, 0.6, 0.75);
  const c2 = color(0.7, 0.1, 0.25);
  assert_color(add(c1, c2), color(1.6, 0.7, 1.0));
});

Deno.test("Subtracting colors", () => {
  const c1 = color(0.9, 0.6, 0.75);
  const c2 = color(0.7, 0.1, 0.25);
  assert_color(sub(c1, c2), color(0.2, 0.5, 0.5));
});

Deno.test("Scaling a color by a number", () => {
  const c = color(0.2, 0.3, 0.4);
  assert_color(scale(c, 2), color(0.4, 0.6, 0.8));
  assert_color(scale(c, 0.5), color(0.1, 0.15, 0.2));
});

Deno.test("Multiplying two colors filters one through the other", () => {
  const c1 = color(1, 0.2, 0.4);
  const c2 = color(0.9, 1, 0.1);
  assert_color(multiply(c1, c2), color(0.9, 0.2, 0.04));
});

Deno.test("Colors compare component by component, with the usual tolerance", () => {
  const c1 = color(0.1, 0.5, 1);
  const c2 = color(0.2, 0, 0);
  assert_color(add(c1, c2), color(0.3, 0.5, 1));
  assert_color_ne(add(c1, c2), color(0.3, 0.5, 1.001));
});
