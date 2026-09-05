// A shape is anything that can answer one question: is this point inside you?
// Coordinates are real numbers, not pixel indices.

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
 * A line is a very thin rectangle: the one of the given width centered on the
 * segment from the center of pixel (x0, y0) to the center of pixel (x1, y1),
 * with square ends. Four half-planes, all facing inward.
 */
export function thick_line(
  x0: number,
  y0: number,
  x1: number,
  y1: number,
  width: number,
): Shape {
  const ax = x0 + 0.5, ay = y0 + 0.5;
  const bx = x1 + 0.5, by = y1 + 0.5;
  const len = Math.hypot(bx - ax, by - ay);
  // A zero-length segment has no direction; point it along x so the ends
  // still cut a square of the requested width out of the plane.
  const dx = len === 0 ? 1 : (bx - ax) / len;
  const dy = len === 0 ? 0 : (by - ay) / len;
  const nx = -dy, ny = dx; // unit normal
  const h = width / 2;
  return intersection(
    half_plane(ax, ay, dx, dy), // past the start, looking along the line
    half_plane(bx, by, -dx, -dy), // before the end, looking back
    half_plane(ax - nx * h, ay - ny * h, nx, ny), // one side, facing in
    half_plane(ax + nx * h, ay + ny * h, -nx, -ny), // the other side
  );
}
