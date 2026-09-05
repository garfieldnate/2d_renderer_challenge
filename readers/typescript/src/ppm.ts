import type { Canvas } from "./canvas.ts";
import { encode } from "./srgb.ts";

const MAX_LINE = 70;

/** Clamp to 0..1, encode, scale to 255, round. In that order. */
export function to_byte(light: number): number {
  const v = light < 0 ? 0 : light > 1 ? 1 : light;
  return Math.round(encode(v) * 255);
}

/** A PPM in hand is either P3 text or a blob of bytes in either format. */
export type Ppm = string | Uint8Array;

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

/**
 * P3 with the numbers written as bytes: the same three header lines with a 6
 * in place of the 3, exactly one newline, then one byte per channel.
 * The bytes are the numbers the P3 writer computes, so to_byte is shared.
 */
export function canvas_to_p6(c: Canvas): Uint8Array {
  const header = new TextEncoder().encode(`P6\n${c.width} ${c.height}\n255\n`);
  const out = new Uint8Array(header.length + c.width * c.height * 3);
  out.set(header, 0);
  let i = header.length;
  for (let y = 0; y < c.height; y++) {
    for (let x = 0; x < c.width; x++) {
      const p = c.pixels[y * c.width + x];
      out[i++] = to_byte(p.red);
      out[i++] = to_byte(p.green);
      out[i++] = to_byte(p.blue);
    }
  }
  return out;
}

interface ParsedPpm {
  width: number;
  height: number;
  data: ArrayLike<number>;
}

function parse_p3(ppm: string): ParsedPpm {
  const tokens = ppm.split(/\s+/).filter((t) => t.length > 0);
  return {
    width: Number(tokens[1]),
    height: Number(tokens[2]),
    data: tokens.slice(4).map(Number),
  };
}

/** After "P6", three whole numbers, one whitespace byte, then the pixels. */
function parse_p6(b: Uint8Array): ParsedPpm {
  let i = 2;
  const nums: number[] = [];
  while (nums.length < 3) {
    while (i < b.length && b[i] <= 0x20) i++;
    let n = 0;
    while (i < b.length && b[i] >= 0x30 && b[i] <= 0x39) n = n * 10 + (b[i++] - 0x30);
    nums.push(n);
  }
  i += 1; // exactly one whitespace byte after the last header number
  return { width: nums[0], height: nums[1], data: b.subarray(i) };
}

/** Look at the first two bytes; a P3 file is text that happens to be bytes. */
function parse(ppm: Ppm): ParsedPpm {
  if (typeof ppm === "string") return parse_p3(ppm);
  if (ppm[0] === 0x50 && ppm[1] === 0x36) return parse_p6(ppm);
  return parse_p3(new TextDecoder().decode(ppm));
}

/** The three whole numbers at pixel (x, y). */
export function ppm_pixel(ppm: Ppm, x: number, y: number): [number, number, number] {
  const p = parse(ppm);
  const i = (y * p.width + x) * 3;
  return [p.data[i], p.data[i + 1], p.data[i + 2]];
}

/** How many different numbers appear in the pixel data. */
export function distinct_values(ppm: Ppm): number {
  return new Set(Array.from(parse(ppm).data)).size;
}

/**
 * The largest difference between any pair of corresponding numbers.
 * Files of different size are as different as it gets: 255.
 */
export function max_channel_difference(a: Ppm, b: Ppm): number {
  const pa = parse(a), pb = parse(b);
  if (pa.width !== pb.width || pa.height !== pb.height) return 255;
  let max = 0;
  for (let i = 0; i < pa.data.length; i++) {
    const d = Math.abs(pa.data[i] - pb.data[i]);
    if (d > max) max = d;
  }
  return max;
}
