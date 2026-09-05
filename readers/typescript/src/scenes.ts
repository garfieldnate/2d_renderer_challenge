import { type Color, color } from "./color.ts";
import { type Canvas, canvas, write_pixel } from "./canvas.ts";
import { decode } from "./srgb.ts";
import { mix, set_linear_blending } from "./mix.ts";

const WHITE = color(1, 1, 1);
const BLACK = color(0, 0, 0);

export function gray_match(): Canvas {
  const c = canvas(300, 100);
  for (let y = 0; y <= 99; y++) {
    for (let x = 0; x <= 99; x++) {
      write_pixel(c, x, y, (x + y) % 2 === 0 ? WHITE : BLACK);
    }
  }
  const g = decode(128 / 255);
  for (let y = 0; y <= 99; y++) {
    for (let x = 100; x <= 199; x++) write_pixel(c, x, y, color(g, g, g));
  }
  for (let y = 0; y <= 99; y++) {
    for (let x = 200; x <= 299; x++) write_pixel(c, x, y, color(0.5, 0.5, 0.5));
  }
  return c;
}

export function quarter_match(): Canvas {
  const c = canvas(200, 100);
  for (let y = 0; y <= 99; y++) {
    for (let x = 0; x <= 99; x++) {
      write_pixel(c, x, y, (x + y) % 4 === 0 ? WHITE : BLACK);
    }
  }
  for (let y = 0; y <= 99; y++) {
    for (let x = 100; x <= 199; x++) {
      write_pixel(c, x, y, color(0.25, 0.25, 0.25));
    }
  }
  return c;
}

export function ramp(): Canvas {
  const c = canvas(256, 32);
  for (let x = 0; x <= 255; x++) {
    const g = x / 255;
    for (let y = 0; y <= 31; y++) write_pixel(c, x, y, color(g, g, g));
  }
  return c;
}

export function clamp_pair(): Canvas {
  const c = canvas(200, 100);
  for (let y = 0; y <= 99; y++) {
    for (let x = 0; x <= 99; x++) write_pixel(c, x, y, color(2, 0.5, 0.5));
    for (let x = 100; x <= 199; x++) write_pixel(c, x, y, color(1, 0.25, 0.25));
  }
  return c;
}

export function ramp_pair(c: Canvas, top: number, a: Color, b: Color): void {
  for (let x = 0; x <= 399; x++) {
    const t = x / 399;
    set_linear_blending(false);
    const naive = mix(a, b, t);
    set_linear_blending(true);
    const light = mix(a, b, t);
    for (let y = top; y <= top + 39; y++) write_pixel(c, x, y, naive);
    for (let y = top + 45; y <= top + 84; y++) write_pixel(c, x, y, light);
  }
}

export function plate_01(): Canvas {
  const c = canvas(400, 180);
  ramp_pair(c, 0, color(0, 0, 0), color(1, 1, 1));
  ramp_pair(c, 90, color(0.7, 0, 0), color(0, 0.3, 0.02));
  return c;
}
