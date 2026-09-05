import type { Color } from "./color.ts";
import type { Canvas } from "./canvas.ts";
import { type Shape, inside } from "./shape.ts";
import { mix } from "./mix.ts";

/** A canvas of numbers instead of colors: one coverage per pixel, 0 to 1. */
export interface CoverageBuffer {
  width: number;
  height: number;
  values: number[];
}

export function coverage_buffer(width: number, height: number): CoverageBuffer {
  return { width, height, values: new Array(width * height).fill(0) };
}

export function coverage_at(cov: CoverageBuffer, x: number, y: number): number {
  return cov.values[y * cov.width + x];
}

/** As with the canvas, writes outside the buffer are dropped. */
export function set_coverage(cov: CoverageBuffer, x: number, y: number, v: number): void {
  if (x < 0 || x >= cov.width || y < 0 || y >= cov.height) return;
  cov.values[y * cov.width + x] = v;
}

/** The sum of every value: the area of the shape, in pixels. */
export function ink(cov: CoverageBuffer): number {
  let total = 0;
  for (const v of cov.values) total += v;
  return total;
}

/** Pixel (x, y) is the square from (x, y) to (x+1, y+1): its center is +0.5. */
export function center_inside(s: Shape, x: number, y: number): number {
  return inside(s, x + 0.5, y + 0.5) ? 1 : 0;
}

export function rasterize_centers(s: Shape, w: number, h: number): CoverageBuffer {
  const cov = coverage_buffer(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) set_coverage(cov, x, y, center_inside(s, x, y));
  }
  return cov;
}

/** Sample count in row j, column i of pixel (x, y) is at (x+(i+0.5)/8, y+(j+0.5)/8). */
export function coverage(s: Shape, x: number, y: number): number {
  let n = 0;
  for (let j = 0; j < 8; j++) {
    for (let i = 0; i < 8; i++) {
      if (inside(s, x + (i + 0.5) / 8, y + (j + 0.5) / 8)) n++;
    }
  }
  return n / 64;
}

export function rasterize(s: Shape, w: number, h: number): CoverageBuffer {
  const cov = coverage_buffer(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) set_coverage(cov, x, y, coverage(s, x, y));
  }
  return cov;
}

/**
 * The stencil. Move every pixel toward the color by that pixel's coverage.
 * The arithmetic is on light, always: this is not the naive-blending switch.
 */
export function paint_through(c: Canvas, cov: CoverageBuffer, col: Color): void {
  for (let y = 0; y < c.height; y++) {
    for (let x = 0; x < c.width; x++) {
      const k = coverage_at(cov, x, y);
      const i = y * c.width + x;
      c.pixels[i] = mix(c.pixels[i], col, k, true);
    }
  }
}
