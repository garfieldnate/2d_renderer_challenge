// features/chapter01-mix.feature
import { color } from "../src/color.ts";
import { linear_blending, mix, set_linear_blending } from "../src/mix.ts";
import { assert_color, assert_true } from "../src/assert.ts";

// "Reset it before each scenario, or turn it back on at the end of any
//  scenario that turns it off."
function scenario(name: string, body: () => void) {
  Deno.test(name, () => {
    set_linear_blending(true);
    try {
      body();
    } finally {
      set_linear_blending(true);
    }
  });
}

scenario("Linear blending is on by default", () => {
  assert_true(linear_blending(), "linear blending is off");
});

scenario("Halfway between black and white", () => {
  const a = color(0, 0, 0);
  const b = color(1, 1, 1);
  assert_color(mix(a, b, 0.5), color(0.5, 0.5, 0.5));
});

scenario("The ends of a mix are its inputs", () => {
  const a = color(0.7, 0, 0);
  const b = color(0, 0.3, 0.02);
  assert_color(mix(a, b, 0), a);
  assert_color(mix(a, b, 1), b);
});

scenario("Red to green, in light", () => {
  const a = color(0.7, 0, 0);
  const b = color(0, 0.3, 0.02);
  assert_color(mix(a, b, 0.5), color(0.35, 0.15, 0.01));
  assert_color(mix(a, b, 0.25), color(0.525, 0.075, 0.005));
});

scenario("Halfway between black and white, the way browsers do it", () => {
  set_linear_blending(false);
  const a = color(0, 0, 0);
  const b = color(1, 1, 1);
  assert_color(mix(a, b, 0.5), color(0.2140, 0.2140, 0.2140));
});

scenario("Red to green, the way browsers do it", () => {
  set_linear_blending(false);
  const a = color(0.7, 0, 0);
  const b = color(0, 0.3, 0.02);
  assert_color(mix(a, b, 0.5), color(0.1527, 0.0693, 0.0067));
});

scenario("The light's way never clamps", () => {
  const a = color(1.5, 0.5, -0.2);
  const b = color(0, 0, 0);
  assert_color(mix(a, b, 0), color(1.5, 0.5, -0.2));
  assert_color(mix(a, b, 0.5), color(0.75, 0.25, -0.1));
});

scenario("The switch can be passed instead of set", () => {
  const a = color(0, 0, 0);
  const b = color(1, 1, 1);
  assert_color(mix(a, b, 0.5, true), color(0.5, 0.5, 0.5));
  assert_color(mix(a, b, 0.5, false), color(0.2140, 0.2140, 0.2140));
  assert_true(linear_blending(), "linear blending is on");
});

// The clamp has to sit on the ends before the lerp, not on the result after
// it: probing only at t = 0 (as "The browser's way can't see past 1" used
// to) can't tell those apart, since both agree there. t = 0.5 is where they
// disagree.
scenario("The browser's way clamps each end before encoding it", () => {
  set_linear_blending(false);
  const a = color(1.5, 0.5, -0.2);
  const b = color(0, 0, 0);
  assert_color(mix(a, b, 0), color(1, 0.5, 0));
  assert_color(mix(a, b, 0.5), color(0.2140, 0.1113, 0.0000));
});

scenario("The ends of a mix are its inputs either way, when they're in range", () => {
  set_linear_blending(false);
  const a = color(0.7, 0, 0);
  const b = color(0, 0.3, 0.02);
  assert_color(mix(a, b, 0), a);
  assert_color(mix(a, b, 1), b);
});
