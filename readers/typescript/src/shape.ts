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
