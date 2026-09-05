import { type Color, color } from "./color.ts";

/** file value -> light */
export function decode(v: number): number {
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

/** light -> file value */
export function encode(l: number): number {
  return l <= 0.0031308 ? l * 12.92 : 1.055 * Math.pow(l, 1 / 2.4) - 0.055;
}

export function decode_color(c: Color): Color {
  return color(decode(c.red), decode(c.green), decode(c.blue));
}

export function encode_color(c: Color): Color {
  return color(encode(c.red), encode(c.green), encode(c.blue));
}
