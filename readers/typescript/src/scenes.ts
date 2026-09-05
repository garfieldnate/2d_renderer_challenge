import { type Color, color } from "./color.ts";
import { type Canvas, canvas, fill, magnify, write_pixel } from "./canvas.ts";
import { decode } from "./srgb.ts";
import { mix, set_linear_blending } from "./mix.ts";
import { circle } from "./shape.ts";
import {
  coverage_at,
  coverage_buffer,
  paint_through,
  rasterize,
  rasterize_centers,
  set_coverage,
} from "./coverage.ts";

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

// ---- chapter 2 -----------------------------------------------------------

const PAPER = color(0.02, 0.02, 0.025);
const INK = color(0.9, 0.55, 0.1);

export function disc_centers(): Canvas {
  const c = canvas(40, 40);
  fill(c, PAPER);
  const cov = rasterize_centers(circle(20, 20, 16), 40, 40);
  paint_through(c, cov, INK);
  return magnify(c, 8);
}

export function disc_coverage(): Canvas {
  const c = canvas(40, 40);
  fill(c, PAPER);
  const cov = rasterize(circle(20, 20, 16), 40, 40);
  paint_through(c, cov, INK);
  return magnify(c, 8);
}

export function painted_twice(): Canvas {
  const c = canvas(80, 40);
  fill(c, PAPER);
  const cov = rasterize(circle(20, 20, 16), 40, 40);
  const once = coverage_buffer(80, 40); // the disc in both halves
  for (let y = 0; y <= 39; y++) {
    for (let x = 0; x <= 39; x++) {
      set_coverage(once, x, y, coverage_at(cov, x, y));
      set_coverage(once, x + 40, y, coverage_at(cov, x, y));
    }
  }
  paint_through(c, once, INK);
  const twice = coverage_buffer(80, 40); // the disc in the right half only
  for (let y = 0; y <= 39; y++) {
    for (let x = 0; x <= 39; x++) {
      set_coverage(twice, x + 40, y, coverage_at(cov, x, y));
    }
  }
  paint_through(c, twice, INK);
  return magnify(c, 6);
}

export function plate_02(): Canvas {
  const c = canvas(80, 40);
  fill(c, PAPER);
  const shape = circle(20, 20, 16);
  const left = rasterize_centers(shape, 40, 40);
  const right = rasterize(shape, 40, 40);
  const both = coverage_buffer(80, 40);
  for (let y = 0; y <= 39; y++) {
    for (let x = 0; x <= 39; x++) {
      set_coverage(both, x, y, coverage_at(left, x, y));
      set_coverage(both, x + 40, y, coverage_at(right, x, y));
    }
  }
  paint_through(c, both, INK);
  return magnify(c, 6);
}
