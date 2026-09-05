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

scenario("The browser's way can't see past 1", () => {
  set_linear_blending(false);
  const a = color(1.5, 0.5, -0.2);
  const b = color(0, 0, 0);
  assert_color(mix(a, b, 0), color(1, 0.5, 0));
});

scenario("The ends of a mix are its inputs either way", () => {
  set_linear_blending(false);
  const a = color(0.7, 0, 0);
  const b = color(0, 0.3, 0.02);
  assert_color(mix(a, b, 0), a);
  assert_color(mix(a, b, 1), b);
});
