import type { Canvas } from "./canvas.ts";
import { encode } from "./srgb.ts";

const MAX_LINE = 70;

/** Clamp to 0..1, encode, scale to 255, round. In that order. */
export function to_byte(light: number): number {
  const v = light < 0 ? 0 : light > 1 ? 1 : light;
  return Math.round(encode(v) * 255);
}

export function canvas_to_ppm(c: Canvas): string {
  const out: string[] = ["P3", `${c.width} ${c.height}`, "255"];
  for (let y = 0; y < c.height; y++) {
    let line = "";
    for (let x = 0; x < c.width; x++) {
      const p = c.pixels[y * c.width + x];
      for (const v of [p.red, p.green, p.blue]) {
        const tok = String(to_byte(v));
        if (line === "") line = tok;
        else if (line.length + 1 + tok.length > MAX_LINE) {
          out.push(line);
          line = tok;
        } else line += " " + tok;
      }
    }
    out.push(line);
  }
  return out.join("\n") + "\n";
}

interface ParsedPpm {
  width: number;
  height: number;
  data: number[];
}

function parse(ppm: string): ParsedPpm {
  const tokens = ppm.split(/\s+/).filter((t) => t.length > 0);
  return {
    width: Number(tokens[1]),
    height: Number(tokens[2]),
    data: tokens.slice(4).map(Number),
  };
}

/** The three whole numbers at pixel (x, y). */
export function ppm_pixel(
  ppm: string,
  x: number,
  y: number,
): [number, number, number] {
  const p = parse(ppm);
  const i = (y * p.width + x) * 3;
  return [p.data[i], p.data[i + 1], p.data[i + 2]];
}

/** How many different numbers appear in the pixel data. */
export function distinct_values(ppm: string): number {
  return new Set(parse(ppm).data).size;
}

/**
 * The largest difference between any pair of corresponding numbers.
 * Files of different size are as different as it gets: 255.
 */
export function max_channel_difference(a: string, b: string): number {
  const pa = parse(a), pb = parse(b);
  if (pa.width !== pb.width || pa.height !== pb.height) return 255;
  let max = 0;
  for (let i = 0; i < pa.data.length; i++) {
    const d = Math.abs(pa.data[i] - pb.data[i]);
    if (d > max) max = d;
  }
  return max;
}
