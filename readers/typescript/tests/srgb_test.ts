// features/chapter01-srgb.feature
import { decode, encode } from "../src/srgb.ts";
import { assert_eq } from "../src/assert.ts";

// Scenario Outline: Encoding light into a file value
for (const [light, value] of [
  [0.0, 0.0],
  [0.0025, 0.0323],
  [0.01, 0.0999],
  [0.1, 0.3492],
  [0.216, 0.5021],
  [0.25, 0.5371],
  [0.5, 0.7354],
  [0.75, 0.8808],
  [1.0, 1.0],
]) {
  Deno.test(`Encoding light into a file value: ${light} -> ${value}`, () => {
    assert_eq(encode(light), value);
  });
}

// Scenario Outline: Decoding a file value into light
for (const [value, light] of [
  [0.0, 0.0],
  [0.04, 0.0031],
  [0.05, 0.0039],
  [0.1, 0.0100],
  [0.5, 0.2140],
  [0.75, 0.5225],
  [1.0, 1.0],
]) {
  Deno.test(`Decoding a file value into light: ${value} -> ${light}`, () => {
    assert_eq(decode(value), light);
  });
}

Deno.test("Decode undoes encode", () => {
  assert_eq(decode(encode(0.2)), 0.2, 0.000000001);
});

Deno.test("Encode undoes decode", () => {
  assert_eq(encode(decode(0.7)), 0.7, 0.000000001);
});

Deno.test("The half gray that isn't 128", () => {
  assert_eq(Math.round(encode(0.5) * 255), 188, 0);
});

Deno.test("What 128 actually is", () => {
  assert_eq(decode(128 / 255), 0.2159);
});
