import type { Color } from "./color.ts";
import type { Canvas } from "./canvas.ts";
import type { Tuple } from "./tuple.ts";
import { at, type Matrix3 } from "./matrix.ts";

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

/** Reference images are binary from chapter 2 on, so this returns bytes. */
export function read_file(path: string): Uint8Array {
  return Deno.readFileSync(path);
}

/** "p6 begins with ..." — the header, byte for byte. */
export function assert_begins_with(bytes: Uint8Array, prefix: string): void {
  const want = new TextEncoder().encode(prefix);
  const got = bytes.subarray(0, want.length);
  for (let i = 0; i < want.length; i++) {
    if (got[i] !== want[i]) {
      throw new Error(
        `expected file to begin with ${JSON.stringify(prefix)}, got ` +
          JSON.stringify(new TextDecoder().decode(got)),
      );
    }
  }
}

/** "byte n of p6" counts from 1. */
export function byte_of(bytes: Uint8Array, n: number): number {
  return bytes[n - 1];
}

/** Every pixel that isn't black, as (x, y), top row first, left to right. */
export function lit_pixels(c: Canvas): [number, number][] {
  const out: [number, number][] = [];
  for (let y = 0; y < c.height; y++) {
    for (let x = 0; x < c.width; x++) {
      const p = c.pixels[y * c.width + x];
      if (p.red !== 0 || p.green !== 0 || p.blue !== 0) out.push([x, y]);
    }
  }
  return out;
}

export function assert_pixels(
  a: [number, number][],
  b: [number, number][],
): void {
  const show = (l: [number, number][]) => l.map(([x, y]) => `(${x}, ${y})`).join(", ");
  if (a.length !== b.length || a.some((p, i) => p[0] !== b[i][0] || p[1] !== b[i][1])) {
    throw new Error(`expected [${show(b)}], got [${show(a)}]`);
  }
}

/** The sum of every pixel's red channel: how much white paint went down. */
export function total_ink(c: Canvas): number {
  let t = 0;
  for (const p of c.pixels) t += p.red;
  return t;
}

function show_tuple(t: Tuple): string {
  return `(${t.x}, ${t.y}, ${t.w})`;
}

export function tuple_eq(a: Tuple, b: Tuple, eps = EPS): boolean {
  return eq(a.x, b.x, eps) && eq(a.y, b.y, eps) && eq(a.w, b.w, eps);
}

export function assert_tuple(a: Tuple, b: Tuple, eps = EPS, msg = ""): void {
  if (!tuple_eq(a, b, eps)) {
    throw new Error(`${msg} expected ${show_tuple(b)}, got ${show_tuple(a)}`);
  }
}

export function assert_tuple_ne(a: Tuple, b: Tuple, eps = EPS): void {
  if (tuple_eq(a, b, eps)) {
    throw new Error(`expected ${show_tuple(a)} != ${show_tuple(b)}`);
  }
}

function show_matrix(M: Matrix3): string {
  const rows = [0, 1, 2].map((r) => [0, 1, 2].map((c) => at(M, r, c)).join(", "));
  return rows.map((r) => `| ${r} |`).join(" ");
}

export function matrix_eq(A: Matrix3, B: Matrix3, eps = EPS): boolean {
  for (let i = 0; i < 9; i++) if (!eq(A.v[i], B.v[i], eps)) return false;
  return true;
}

export function assert_matrix(A: Matrix3, B: Matrix3, eps = EPS, msg = ""): void {
  if (!matrix_eq(A, B, eps)) {
    throw new Error(`${msg} expected ${show_matrix(B)}, got ${show_matrix(A)}`);
  }
}

export function assert_matrix_ne(A: Matrix3, B: Matrix3, eps = EPS): void {
  if (matrix_eq(A, B, eps)) {
    throw new Error(`expected ${show_matrix(A)} != ${show_matrix(B)}`);
  }
}

/** Chapter 5: bounds(p) is (min x, min y, max x, max y), same tolerance as a tuple. */
export interface BoundsLike {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

function show_bounds(b: BoundsLike): string {
  return `(${b.minX}, ${b.minY}, ${b.maxX}, ${b.maxY})`;
}

export function assert_bounds(a: BoundsLike, b: BoundsLike, eps = EPS): void {
  if (
    !eq(a.minX, b.minX, eps) || !eq(a.minY, b.minY, eps) ||
    !eq(a.maxX, b.maxX, eps) || !eq(a.maxY, b.maxY, eps)
  ) {
    throw new Error(`expected ${show_bounds(b)}, got ${show_bounds(a)}`);
  }
}
