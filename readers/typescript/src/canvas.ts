import { type Color, color } from "./color.ts";

export interface Canvas {
  width: number;
  height: number;
  pixels: Color[];
}

export function canvas(width: number, height: number): Canvas {
  const pixels: Color[] = new Array(width * height);
  for (let i = 0; i < width * height; i++) pixels[i] = color(0, 0, 0);
  return { width, height, pixels };
}

/** x is the column, y is the row. Writes outside the canvas are silently dropped. */
export function write_pixel(c: Canvas, x: number, y: number, col: Color): void {
  if (x < 0 || x >= c.width || y < 0 || y >= c.height) return;
  c.pixels[y * c.width + x] = col;
}

export function pixel_at(c: Canvas, x: number, y: number): Color {
  return c.pixels[y * c.width + x];
}

export function fill(c: Canvas, col: Color): void {
  for (let i = 0; i < c.pixels.length; i++) c.pixels[i] = col;
}

/**
 * A canvas k times wider and taller, every pixel repeated into a k by k
 * block. No smoothing, no averaging.
 */
export function magnify(c: Canvas, k: number): Canvas {
  const m = canvas(c.width * k, c.height * k);
  for (let y = 0; y < m.height; y++) {
    for (let x = 0; x < m.width; x++) {
      m.pixels[y * m.width + x] = c.pixels[Math.floor(y / k) * c.width + Math.floor(x / k)];
    }
  }
  return m;
}
