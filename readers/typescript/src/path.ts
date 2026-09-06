// Chapter 5. A path is a list of subpaths; a subpath is a list of points
// and a flag for whether the pen closed the loop. move_to lifts the pen
// and puts it down, starting a new subpath. line_to extends the current
// one, or starts one if there's nothing to extend. close marks the
// current subpath finished.
import { cross, point, sub, type Tuple } from "./tuple.ts";
import type { Shape } from "./shape.ts";
import { type CoverageBuffer, coverage, coverage_buffer, set_coverage } from "./coverage.ts";

export interface Subpath {
  points: Tuple[];
  closed: boolean;
}

export interface Path {
  subpaths: Subpath[];
}

export interface Edge {
  a: Tuple;
  b: Tuple;
}

/** (min x, min y, max x, max y). An empty path's bounds are (0, 0, 0, 0). */
export interface Bounds {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

export function path(): Path {
  return { subpaths: [] };
}

/** Hands the subpath list to the tests, each with .points and .closed. */
export function subpaths(p: Path): Subpath[] {
  return p.subpaths;
}

function current(p: Path): Subpath | undefined {
  return p.subpaths[p.subpaths.length - 1];
}

/** Lifts the pen and puts it down at pt: a new subpath of one point. */
export function move_to(p: Path, pt: Tuple): void {
  p.subpaths.push({ points: [pt], closed: false });
}

/**
 * Draws from wherever the pen is to pt. With nothing to draw from — no
 * subpath yet, or the last one closed — there's nowhere to draw a line
 * from, so this behaves as a move_to, except after a close: PostScript
 * and SVG both restart the new subpath at the point the closed one began,
 * because that's where the pen ended up.
 */
export function line_to(p: Path, pt: Tuple): void {
  const sp = current(p);
  if (!sp) {
    move_to(p, pt);
    return;
  }
  if (sp.closed) {
    p.subpaths.push({ points: [sp.points[0], pt], closed: false });
    return;
  }
  sp.points.push(pt);
}

/** Marks the current subpath closed. Nothing to close, or closed twice: no-op. */
export function close(p: Path): void {
  const sp = current(p);
  if (sp) sp.closed = true;
}

/**
 * Every edge of every subpath, as (a, b) pairs, treating every subpath as
 * closed whether or not close was called. A subpath of one point
 * contributes no edges; n points (n >= 2) contribute n edges, the last
 * one back to the first.
 */
export function edges(p: Path): Edge[] {
  const out: Edge[] = [];
  for (const sp of p.subpaths) {
    const n = sp.points.length;
    if (n < 2) continue;
    for (let i = 0; i < n; i++) {
      out.push({ a: sp.points[i], b: sp.points[(i + 1) % n] });
    }
  }
  return out;
}

/** The smallest axis-aligned box around every point of every subpath. */
export function bounds(p: Path): Bounds {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  let any = false;
  for (const sp of p.subpaths) {
    for (const pt of sp.points) {
      any = true;
      if (pt.x < minX) minX = pt.x;
      if (pt.y < minY) minY = pt.y;
      if (pt.x > maxX) maxX = pt.x;
      if (pt.y > maxY) maxY = pt.y;
    }
  }
  return any ? { minX, minY, maxX, maxY } : { minX: 0, minY: 0, maxX: 0, maxY: 0 };
}

/** A closed subpath through the given points. */
export function polygon(...points: Tuple[]): Path {
  const p = path();
  points.forEach((pt, i) => (i === 0 ? move_to(p, pt) : line_to(p, pt)));
  close(p);
  return p;
}

/**
 * A regular n-gon standing in for a circle: first point at angle 0, on
 * the right, going clockwise on the screen (angle increases with y
 * pointing down).
 */
export function circle_path(cx: number, cy: number, r: number, n: number): Path {
  const pts: Tuple[] = [];
  for (let k = 0; k < n; k++) {
    const a = (2 * Math.PI * k) / n;
    pts.push(point(cx + r * Math.cos(a), cy + r * Math.sin(a)));
  }
  return polygon(...pts);
}

/**
 * How many edges a ray from (x, y) toward +x crosses. Half-open: an edge
 * from a to b spans height y when a.y <= y < b.y or b.y <= y < a.y, so a
 * vertex on the ray counts once and a horizontal edge is never crossed.
 */
export function crossings(p: Path, x: number, y: number): number {
  let count = 0;
  for (const { a, b } of edges(p)) {
    const spans = (a.y <= y && y < b.y) || (b.y <= y && y < a.y);
    if (!spans) continue;
    const t = (y - a.y) / (b.y - a.y);
    const cx = a.x + t * (b.x - a.x);
    if (cx > x) count++;
  }
  return count;
}

/**
 * The winding number: each edge that spans the ray's height counts +1
 * heading down the canvas (q on the left) or -1 heading up (q on the
 * right). Positive is clockwise on the screen, because the canvas's y
 * points down.
 */
export function winding_at(p: Path, x: number, y: number): number {
  const q = point(x, y);
  let w = 0;
  for (const { a, b } of edges(p)) {
    if (a.y <= y) {
      if (b.y > y && cross(sub(b, a), sub(q, a)) > 0) w += 1;
    } else {
      if (b.y <= y && cross(sub(b, a), sub(q, a)) < 0) w -= 1;
    }
  }
  return w;
}

/** Nonzero: inside when the winding number isn't zero. */
export function inside_nonzero(p: Path, x: number, y: number): boolean {
  return winding_at(p, x, y) !== 0;
}

/** Even-odd: inside when the winding number is odd. */
export function inside_evenodd(p: Path, x: number, y: number): boolean {
  return Math.abs(winding_at(p, x, y) % 2) === 1;
}

export type FillRule = "nonzero" | "evenodd";

/** The shape a path encloses under a rule, "nonzero" or "evenodd". */
export function filled(p: Path, rule: FillRule): Shape {
  return {
    contains(x, y) {
      return rule === "nonzero" ? inside_nonzero(p, x, y) : inside_evenodd(p, x, y);
    },
  };
}

/**
 * Chapter 2's rasterize, restricted to the pixels box touches: columns
 * from floor(min x) up to but not including ceil(max x), rows likewise,
 * clipped to the buffer. Same coverage as rasterize, less work.
 */
export function rasterize_within(s: Shape, box: Bounds, w: number, h: number): CoverageBuffer {
  const cov = coverage_buffer(w, h);
  const x0 = Math.max(0, Math.floor(box.minX));
  const x1 = Math.min(w, Math.ceil(box.maxX));
  const y0 = Math.max(0, Math.floor(box.minY));
  const y1 = Math.min(h, Math.ceil(box.maxY));
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) set_coverage(cov, x, y, coverage(s, x, y));
  }
  return cov;
}
