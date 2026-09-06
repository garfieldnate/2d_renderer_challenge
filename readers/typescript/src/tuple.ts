// Chapter 4. A point is a place; a vector is a displacement. Both are
// (x, y, w): w = 1 for a point, w = 0 for a vector. The arithmetic on all
// three components does the bookkeeping: point - point has w = 0 (a
// vector), point + vector has w = 1 (a point), point + point has w = 2,
// which is a mistake with no name.

export interface Tuple {
  x: number;
  y: number;
  w: number;
}

export function point(x: number, y: number): Tuple {
  return { x, y, w: 1 };
}

export function vector(x: number, y: number): Tuple {
  return { x, y, w: 0 };
}

export function add(a: Tuple, b: Tuple): Tuple {
  return { x: a.x + b.x, y: a.y + b.y, w: a.w + b.w };
}

export function sub(a: Tuple, b: Tuple): Tuple {
  return { x: a.x - b.x, y: a.y - b.y, w: a.w - b.w };
}

export function negate(v: Tuple): Tuple {
  return { x: -v.x, y: -v.y, w: -v.w };
}

/** Scale every component, including w: only ever used on vectors, where w is 0. */
export function scale(v: Tuple, s: number): Tuple {
  return { x: v.x * s, y: v.y * s, w: v.w * s };
}

export function div(v: Tuple, s: number): Tuple {
  return scale(v, 1 / s);
}

export function magnitude(v: Tuple): number {
  return Math.sqrt(v.x * v.x + v.y * v.y);
}

/** A vector of length 1 pointing the same way. */
export function normalize(v: Tuple): Tuple {
  return div(v, magnitude(v));
}

/** a.x*b.x + a.y*b.y: zero when a and b are perpendicular. */
export function dot(a: Tuple, b: Tuple): number {
  return a.x * b.x + a.y * b.y;
}

/**
 * In two dimensions there's nowhere perpendicular for the cross product to
 * go, so what's left is a single number, the area of the parallelogram a
 * and b span, signed by which way b turns from a.
 */
export function cross(a: Tuple, b: Tuple): number {
  return a.x * b.y - a.y * b.x;
}
