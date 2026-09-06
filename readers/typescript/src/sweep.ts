// Chapter 6. The scanline fill: take the path apart into an edge table,
// sweep the rows keeping only the edges that are active, and fill the
// spans the winding number finds on each one. Same picture chapter 5's
// rasterize_centers produces, far less work.
import { type Edge, edges, type FillRule, type Path } from "./path.ts";
import { type CoverageBuffer, coverage_buffer, set_coverage } from "./coverage.ts";
import { type Matrix3, multiply_tuple } from "./matrix.ts";

/**
 * One edge, ready for the sweep: its top and bottom y, where it crosses
 * its top, its slope in x per unit of y, and its direction — +1 heading
 * down the canvas (a.y < b.y), -1 heading up. The same sign chapter 5's
 * winding number gave a crossing.
 */
export interface EdgeEntry {
  y_top: number;
  y_bottom: number;
  x_top: number;
  slope: number;
  direction: number;
}

function to_entry(e: Edge): EdgeEntry | null {
  // Horizontal, exactly: a.y = b.y. Dropped, not clamped — its slope
  // would be a division by zero, and chapter 5's half-open rule already
  // said a horizontal edge never crosses a sample height.
  if (e.a.y === e.b.y) return null;
  const direction = e.a.y < e.b.y ? 1 : -1;
  const top = direction === 1 ? e.a : e.b;
  const bottom = direction === 1 ? e.b : e.a;
  const slope = (bottom.x - top.x) / (bottom.y - top.y);
  return { y_top: top.y, y_bottom: bottom.y, x_top: top.x, slope, direction };
}

/** Every non-horizontal edge, sorted by y_top, then by x_top. */
export function edge_table(p: Path): EdgeEntry[] {
  const out: EdgeEntry[] = [];
  for (const e of edges(p)) {
    const entry = to_entry(e);
    if (entry) out.push(entry);
  }
  out.sort((a, b) => a.y_top - b.y_top || a.x_top - b.x_top);
  return out;
}

/** Where the edge crosses height y: x_top + (y - y_top) * slope. */
export function x_at(e: EdgeEntry, y: number): number {
  return e.x_top + (y - e.y_top) * e.slope;
}

/**
 * (x, direction) for every edge that spans height y, half-open: y_top <=
 * y < y_bottom, sorted by x.
 */
export function crossings_on_row(table: EdgeEntry[], y: number): [number, number][] {
  const out: [number, number][] = [];
  for (const e of table) {
    if (e.y_top <= y && y < e.y_bottom) out.push([x_at(e, y), e.direction]);
  }
  out.sort((a, b) => a[0] - b[0]);
  return out;
}

/**
 * Walk the sorted crossings left to right, accumulating the winding
 * number, and return the maximal (x_start, x_end) intervals where the
 * rule says inside. Touching inside stretches merge, because the rule
 * never turned false between them.
 */
export function spans_from_crossings(
  xs: [number, number][],
  rule: FillRule,
): [number, number][] {
  const out: [number, number][] = [];
  let w = 0;
  let start: number | null = null;
  for (const [x, d] of xs) {
    w += d;
    const insideNow = rule === "nonzero" ? w !== 0 : Math.abs(w % 2) === 1;
    if (insideNow && start === null) start = x;
    if (!insideNow && start !== null) {
      out.push([start, x]);
      start = null;
    }
  }
  return out;
}

/** crossings_on_row and spans_from_crossings together, for one pixel row. */
export function spans(p: Path, rule: FillRule, row: number): [number, number][] {
  const y = row + 0.5;
  return spans_from_crossings(crossings_on_row(edge_table(p), y), rule);
}

/**
 * Every pixel of the row whose center lies in [x0, x1) to 1: the first is
 * ceil(x0 - 0.5), the last is ceil(x1 - 0.5) - 1, clipped to the buffer.
 * Half-open at the right end, so two spans that meet at a pixel center
 * fill it exactly once.
 */
export function fill_span(cov: CoverageBuffer, row: number, x0: number, x1: number): void {
  const first = Math.ceil(x0 - 0.5);
  const last = Math.ceil(x1 - 0.5) - 1;
  const lo = Math.max(first, 0);
  const hi = Math.min(last, cov.width - 1);
  for (let x = lo; x <= hi; x++) set_coverage(cov, x, row, 1);
}

/**
 * The classical scanline fill. Sweep the rows top to bottom, keeping the
 * active edge list: edges whose y_top has been reached join it (off the
 * front of the sorted table, no searching), edges whose y_bottom has
 * been passed leave it. Sort the survivors' crossings and fill the spans.
 */
export function fill_path_aliased(p: Path, rule: FillRule, w: number, h: number): CoverageBuffer {
  const cov = coverage_buffer(w, h);
  const table = edge_table(p);
  let active: EdgeEntry[] = [];
  let next = 0;
  for (let row = 0; row < h; row++) {
    const y = row + 0.5;
    while (next < table.length && table[next].y_top <= y) {
      active.push(table[next]);
      next++;
    }
    active = active.filter((e) => e.y_bottom > y); // half-open: out once y reaches the bottom
    const xs: [number, number][] = active.map((e) => [x_at(e, y), e.direction]);
    xs.sort((a, b) => a[0] - b[0]);
    for (const [x0, x1] of spans_from_crossings(xs, rule)) fill_span(cov, row, x0, x1);
  }
  return cov;
}

/**
 * Chapter 1's max_channel_difference for coverage buffers: the largest
 * difference between corresponding entries, or 1 when the sizes differ.
 */
export function max_coverage_difference(a: CoverageBuffer, b: CoverageBuffer): number {
  if (a.width !== b.width || a.height !== b.height) return 1;
  let max = 0;
  for (let i = 0; i < a.values.length; i++) {
    const d = Math.abs(a.values[i] - b.values[i]);
    if (d > max) max = d;
  }
  return max;
}

/** Every point of every subpath through m, closed flags and all. The original is untouched. */
export function transform_path(p: Path, m: Matrix3): Path {
  return {
    subpaths: p.subpaths.map((sp) => ({
      points: sp.points.map((pt) => multiply_tuple(m, pt)),
      closed: sp.closed,
    })),
  };
}
