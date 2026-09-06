import { type Color, color } from "./color.ts";
import { type Canvas, canvas, clone, fill, magnify, pixel_at, side_by_side, write_pixel } from "./canvas.ts";
import { decode } from "./srgb.ts";
import { mix, set_linear_blending } from "./mix.ts";
import { circle, outline, segment, thick_line, union } from "./shape.ts";
import { line_bresenham, line_wu } from "./line.ts";
import {
  coverage_at,
  coverage_buffer,
  paint_through,
  rasterize,
  rasterize_centers,
  set_coverage,
} from "./coverage.ts";
import { point, type Tuple } from "./tuple.ts";
import { type Matrix3, multiply, rotation, transform_points, translation } from "./matrix.ts";
import type { Shape } from "./shape.ts";

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

// ---- chapter 3 -----------------------------------------------------------

const RAY_PAPER = color(0.02, 0.02, 0.025);
const RAY_INK = color(0.92, 0.92, 0.88);

/** Twelve points 72 pixels from the middle of a 160 by 160 canvas. */
export function ray_ends(): [number, number][] {
  const ends: [number, number][] = [];
  for (let k = 0; k <= 11; k++) {
    const a = (k * 30 * Math.PI) / 180;
    ends.push([
      Math.round(80 + 72 * Math.cos(a)),
      Math.round(80 + 72 * Math.sin(a)),
    ]);
  }
  return ends;
}

export function fan_bresenham(): Canvas {
  const c = canvas(160, 160);
  fill(c, RAY_PAPER);
  for (const [x, y] of ray_ends()) line_bresenham(c, 80, 80, x, y, RAY_INK);
  return c;
}

/** fan_bresenham with line_wu in its place, and nothing else changed. */
export function fan_wu(): Canvas {
  const c = canvas(160, 160);
  fill(c, RAY_PAPER);
  for (const [x, y] of ray_ends()) line_wu(c, 80, 80, x, y, RAY_INK);
  return c;
}

/** The same fan as twelve thin rectangles. Slow, and worth it. */
export function fan_coverage(): Canvas {
  const c = canvas(160, 160);
  fill(c, RAY_PAPER);
  for (const [x, y] of ray_ends()) {
    const cov = rasterize(thick_line(80, 80, x, y, 1), 160, 160);
    paint_through(c, cov, RAY_INK);
  }
  return magnify(c, 2);
}

export function plate_03(): Canvas {
  const both = canvas(320, 160);
  const a = fan_bresenham();
  const b = fan_wu();
  for (let y = 0; y <= 159; y++) {
    for (let x = 0; x <= 159; x++) {
      write_pixel(both, x, y, pixel_at(a, x, y));
      write_pixel(both, x + 160, y, pixel_at(b, x, y));
    }
  }
  return magnify(both, 2);
}

// ---- chapter 4 -----------------------------------------------------------

const FAN_PAPER = color(0.02, 0.02, 0.025);
const FAN_INK = color(0.92, 0.92, 0.88);

/** The center, then twelve ends at radius 36, a ray every 30 degrees. */
export function fan_points(): Tuple[] {
  const pts: Tuple[] = [point(0, 0)];
  for (let k = 0; k <= 11; k++) {
    const a = (k * 30 * Math.PI) / 180;
    pts.push(point(36 * Math.cos(a), 36 * Math.sin(a)));
  }
  return pts;
}

/** fan_points(), taken through m and drawn as one union of segments. */
export function fan_transformed(m: Matrix3): Canvas {
  const c = canvas(160, 160);
  fill(c, FAN_PAPER);
  const pts = transform_points(fan_points(), m);
  const rays: Shape[] = [];
  for (let k = 1; k <= 12; k++) rays.push(segment(pts[0], pts[k], 1));
  paint_through(c, rasterize(union(rays), 160, 160), FAN_INK);
  return c;
}

/** The same two matrices, in both orders, side by side. */
export function fan_both_orders(): Canvas {
  const turn = rotation(Math.PI / 6);
  const move = translation(104.5, 76.5);
  return side_by_side(
    fan_transformed(multiply(move, turn)),
    fan_transformed(multiply(turn, move)),
  );
}

/**
 * Ten corners, clockwise from the top left, in a box 40 wide and 60 tall
 * centered on the origin: an F with no symmetry at all.
 */
export function letter_f(): Tuple[] {
  return [
    point(-20, -30), point(20, -30), point(20, -20), point(-10, -20),
    point(-10, -5), point(12, -5), point(12, 5), point(-10, 5),
    point(-10, 30), point(-20, 30),
  ];
}

const F_INK = color(0.92, 0.92, 0.88);
const F_DIM = color(0.16, 0.16, 0.17);

/** The F drawn at home, then through move*turn and turn*move, side by side. */
export function f_both_orders(): Canvas {
  const turn = rotation(Math.PI / 6);
  const move = translation(104.5, 76.5);
  const home = translation(44.5, 44.5);
  const ghost = canvas(160, 160);
  fill(ghost, FAN_PAPER);
  paint_through(ghost, rasterize(outline(letter_f(), home, 1), 160, 160), F_DIM);
  const a = clone(ghost);
  const b = clone(ghost);
  paint_through(a, rasterize(outline(letter_f(), multiply(move, turn), 1), 160, 160), F_INK);
  paint_through(b, rasterize(outline(letter_f(), multiply(turn, move), 1), 160, 160), F_INK);
  return side_by_side(a, b);
}

export function plate_04(): Canvas {
  return magnify(f_both_orders(), 2);
}
