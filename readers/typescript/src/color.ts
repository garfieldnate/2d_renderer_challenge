// A color is three floating point numbers measuring light.
// 0 is none, 1 is as much as the display can make. Values may
// leave 0..1 during a calculation; they are clamped on the way to a file.

export interface Color {
  red: number;
  green: number;
  blue: number;
}

export function color(red: number, green: number, blue: number): Color {
  return { red, green, blue };
}

export function add(a: Color, b: Color): Color {
  return color(a.red + b.red, a.green + b.green, a.blue + b.blue);
}

export function sub(a: Color, b: Color): Color {
  return color(a.red - b.red, a.green - b.green, a.blue - b.blue);
}

/** Scale a color by a number. */
export function scale(c: Color, s: number): Color {
  return color(c.red * s, c.green * s, c.blue * s);
}

/** Hadamard product: one color filtered through the other. */
export function multiply(a: Color, b: Color): Color {
  return color(a.red * b.red, a.green * b.green, a.blue * b.blue);
}
