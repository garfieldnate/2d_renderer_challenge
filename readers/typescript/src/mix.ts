import { type Color, color } from "./color.ts";
import { decode, encode } from "./srgb.ts";

/**
 * One global boolean, defaulting to on. Every scenario that doesn't say
 * otherwise expects it on. Deno.test runs serially, so a plain module
 * global is safe here.
 */
const state = { linear_blending: true };

export function linear_blending(): boolean {
  return state.linear_blending;
}

export function set_linear_blending(on: boolean): void {
  state.linear_blending = on;
}

function clamp01(v: number): number {
  return v < 0 ? 0 : v > 1 ? 1 : v;
}

/** The color a fraction t of the way from a to b. */
export function mix(a: Color, b: Color, t: number, linear = state.linear_blending): Color {
  if (linear) {
    // light is what the canvas holds; interpolate it directly
    return color(
      a.red + (b.red - a.red) * t,
      a.green + (b.green - a.green) * t,
      a.blue + (b.blue - a.blue) * t,
    );
  }
  // the browser's way: encode is only defined on 0..1, so clamp each end first
  const ch = (x: number, y: number) => {
    const ex = encode(clamp01(x)), ey = encode(clamp01(y));
    return decode(ex + (ey - ex) * t);
  };
  return color(ch(a.red, b.red), ch(a.green, b.green), ch(a.blue, b.blue));
}
