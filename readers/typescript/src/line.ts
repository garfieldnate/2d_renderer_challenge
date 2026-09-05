// Chapter 3. Two special-purpose line algorithms, kept for the lesson they
// teach: the shape in shape.ts is the one the rest of the book uses.
import type { Color } from "./color.ts";
import { type Canvas, pixel_at, write_pixel } from "./canvas.ts";
import { mix } from "./mix.ts";

/**
 * Bresenham, 1962. One pixel per step along the longer axis, chosen with
 * whole numbers only, both endpoints included.
 */
export function line_bresenham(
  c: Canvas,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
  col: Color,
): void {
  const steep = Math.abs(y1 - y0) > Math.abs(x1 - x0);
  if (steep) { // walk along y instead
    [x0, y0] = [y0, x0];
    [x1, y1] = [y1, x1];
  }
  if (x0 > x1) { // always walk left to right
    [x0, x1] = [x1, x0];
    [y0, y1] = [y1, y0];
  }
  const dx = x1 - x0;
  const dy = Math.abs(y1 - y0);
  const ystep = y0 < y1 ? 1 : -1;
  let err = Math.floor(dx / 2); // integer division
  let y = y0;
  for (let x = x0; x <= x1; x++) {
    if (steep) write_pixel(c, y, x, col); // swap back on the way out
    else write_pixel(c, x, y, col);
    err -= dy;
    if (err < 0) {
      y += ystep;
      err += dx;
    }
  }
}

/** paint_through for a single pixel. Off-canvas and zero weight do nothing. */
export function plot(
  c: Canvas,
  x: number,
  y: number,
  col: Color,
  weight: number,
): void {
  if (weight === 0) return;
  if (x < 0 || x >= c.width || y < 0 || y >= c.height) return;
  write_pixel(c, x, y, mix(pixel_at(c, x, y), col, weight));
}

/**
 * Wu, 1991. Two pixels per step, weighted by where the ideal line falls
 * between them. Integer endpoints only.
 */
export function line_wu(
  c: Canvas,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
  col: Color,
): void {
  const steep = Math.abs(y1 - y0) > Math.abs(x1 - x0);
  if (steep) {
    [x0, y0] = [y0, x0];
    [x1, y1] = [y1, x1];
  }
  if (x0 > x1) {
    [x0, x1] = [x1, x0];
    [y0, y1] = [y1, y0];
  }
  const dx = x1 - x0;
  const slope = dx === 0 ? 0 : (y1 - y0) / dx;
  for (let x = x0; x <= x1; x++) {
    const y = y0 + (x - x0) * slope;
    const yi = Math.floor(y);
    const f = y - yi;
    if (steep) {
      plot(c, yi, x, col, 1 - f);
      plot(c, yi + 1, x, col, f);
    } else {
      plot(c, x, yi, col, 1 - f);
      plot(c, x, yi + 1, col, f);
    }
  }
}
