// A shape is anything that can answer one question: is this point inside you?
// Coordinates are real numbers, not pixel indices.
import { type Matrix3, inverse, is_invertible, multiply_tuple } from "./matrix.ts";
import { point, type Tuple } from "./tuple.ts";

export interface Shape {
  contains(x: number, y: number): boolean;
}

export function inside(s: Shape, x: number, y: number): boolean {
  return s.contains(x, y);
}

/** Inside means within the radius, boundary included. */
export function circle(cx: number, cy: number, r: number): Shape {
  const rr = r * r;
  return {
    contains(x, y) {
      const dx = x - cx, dy = y - cy;
      return dx * dx + dy * dy <= rr;
    },
  };
}

/** Left, top, right, bottom. Boundary included. */
export function rectangle(x0: number, y0: number, x1: number, y1: number): Shape {
  return {
    contains(x, y) {
      return x >= x0 && x <= x1 && y >= y0 && y <= y1;
    },
  };
}

/**
 * Everything on the side the normal points to. A point is inside when the
 * vector from (px, py) to it has a non-negative dot product with the normal.
 * The normal needn't have length 1.
 */
export function half_plane(px: number, py: number, nx: number, ny: number): Shape {
  return {
    contains(x, y) {
      return (x - px) * nx + (y - py) * ny >= 0;
    },
  };
}

/** Inside every one of them. */
export function intersection(...parts: Shape[]): Shape {
  return {
    contains(x, y) {
      for (const p of parts) if (!p.contains(x, y)) return false;
      return true;
    },
  };
}

/**
 * A line is a very thin rectangle: the one of the given width centered on
 * the segment from point a to point b, square ends. Four half-planes, all
 * facing inward.
 */
export function segment(a: Tuple, b: Tuple, width: number): Shape {
  const len = Math.hypot(b.x - a.x, b.y - a.y);
  const h = width / 2;
  // A zero-length segment has no direction to cap along, so it isn't a
  // flush-capped rectangle of zero length: it's a width-by-width square
  // centered on the point.
  if (len === 0) return rectangle(a.x - h, a.y - h, a.x + h, a.y + h);
  const dx = (b.x - a.x) / len;
  const dy = (b.y - a.y) / len;
  const nx = -dy, ny = dx; // unit normal
  return intersection(
    half_plane(a.x, a.y, dx, dy), // past the start, looking along the line
    half_plane(b.x, b.y, -dx, -dy), // before the end, looking back
    half_plane(a.x - nx * h, a.y - ny * h, nx, ny), // one side, facing in
    half_plane(a.x + nx * h, a.y + ny * h, -nx, -ny), // the other side
  );
}

/**
 * Chapter 3's thick_line, in terms of segment: the pixel indices become the
 * centers of those pixels, and the rest is the same four half-planes.
 */
export function thick_line(
  x0: number,
  y0: number,
  x1: number,
  y1: number,
  width: number,
): Shape {
  return segment(point(x0 + 0.5, y0 + 0.5), point(x1 + 0.5, y1 + 0.5), width);
}

/** Inside when any of its shapes is. */
export function union(shapes: Shape[]): Shape {
  return {
    contains(x, y) {
      for (const s of shapes) if (s.contains(x, y)) return true;
      return false;
    },
  };
}

/**
 * The shape seen through m. A device point is inside it when running that
 * point backwards through the inverse of m lands inside the original
 * shape. A matrix with no inverse can't be undone, so nothing is inside it.
 */
export function transformed(shape: Shape, m: Matrix3): Shape {
  if (!is_invertible(m)) {
    return { contains: () => false };
  }
  const inv = inverse(m);
  return {
    contains(x, y) {
      const p = multiply_tuple(inv, point(x, y));
      return shape.contains(p.x, p.y);
    },
  };
}

/**
 * The closed polygon through points after m, every edge a segment of the
 * given width in device space, as one shape: an edge shared by two corners
 * paints that corner's coverage once, not twice.
 */
export function outline(points: Tuple[], m: Matrix3, width: number): Shape {
  const pts = points.map((p) => multiply_tuple(m, p));
  const edges: Shape[] = [];
  for (let i = 0; i < pts.length; i++) {
    edges.push(segment(pts[i], pts[(i + 1) % pts.length], width));
  }
  return union(edges);
}
