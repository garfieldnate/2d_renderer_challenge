import type { Color } from "./color.ts";
import type { Canvas } from "./canvas.ts";

export const EPS = 0.0001;

/** a = b means |a - b| <= tolerance. */
export function eq(a: number, b: number, eps = EPS): boolean {
  return Math.abs(a - b) <= eps;
}

export function assert_eq(a: number, b: number, eps = EPS, msg = ""): void {
  if (!eq(a, b, eps)) {
    throw new Error(`${msg} expected ${b} +/- ${eps}, got ${a}`);
  }
}

export function assert_ne(a: number, b: number, eps = EPS, msg = ""): void {
  if (eq(a, b, eps)) throw new Error(`${msg} expected ${a} != ${b} (+/- ${eps})`);
}

export function color_eq(a: Color, b: Color, eps = EPS): boolean {
  return eq(a.red, b.red, eps) && eq(a.green, b.green, eps) &&
    eq(a.blue, b.blue, eps);
}

function show(c: Color): string {
  return `color(${c.red}, ${c.green}, ${c.blue})`;
}

export function assert_color(a: Color, b: Color, eps = EPS, msg = ""): void {
  if (!color_eq(a, b, eps)) {
    throw new Error(`${msg} expected ${show(b)}, got ${show(a)}`);
  }
}

export function assert_color_ne(a: Color, b: Color, eps = EPS): void {
  if (color_eq(a, b, eps)) throw new Error(`expected ${show(a)} != ${show(b)}`);
}

/** A triple of whole numbers compares exactly unless a tolerance is given. */
export function assert_triple(
  a: [number, number, number],
  b: [number, number, number],
  tol = 0,
): void {
  for (let i = 0; i < 3; i++) {
    if (Math.abs(a[i] - b[i]) > tol) {
      throw new Error(`expected (${b}) +/- ${tol}, got (${a})`);
    }
  }
}

export function assert_every_pixel(c: Canvas, col: Color): void {
  for (let y = 0; y < c.height; y++) {
    for (let x = 0; x < c.width; x++) {
      const p = c.pixels[y * c.width + x];
      if (!color_eq(p, col)) {
        throw new Error(`pixel (${x}, ${y}) is ${show(p)}, expected ${show(col)}`);
      }
    }
  }
}

/** Counting pixels of a given color is a loop, not a renderer function. */
export function count_pixels(c: Canvas, col: Color): number {
  let n = 0;
  for (const p of c.pixels) if (color_eq(p, col)) n++;
  return n;
}

export function lines_of(ppm: string): string[] {
  const l = ppm.split("\n");
  if (l.length > 0 && l[l.length - 1] === "") l.pop();
  return l;
}

/** lines a-b of ppm are <block> */
export function assert_lines(ppm: string, from: number, to: number, block: string): void {
  const actual = lines_of(ppm).slice(from - 1, to);
  const expected = block.trim().split("\n").map((s) => s.trim());
  if (actual.length !== expected.length) {
    throw new Error(`expected ${expected.length} lines, got ${actual.length}`);
  }
  for (let i = 0; i < expected.length; i++) {
    if (actual[i] !== expected[i]) {
      throw new Error(
        `line ${from + i}:\n  expected: ${JSON.stringify(expected[i])}\n  actual:   ${JSON.stringify(actual[i])}`,
      );
    }
  }
}

export function assert_true(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

export function read_file(path: string): string {
  return Deno.readTextFileSync(path);
}
