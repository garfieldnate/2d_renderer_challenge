// Chapter 4. A 3 by 3 matrix of real numbers, row by row. M[r, c] is the
// entry in row r, column c, both counted from zero.
import type { Tuple } from "./tuple.ts";

export interface Matrix3 {
  /** nine numbers, row by row: [m00, m01, m02, m10, m11, m12, m20, m21, m22] */
  readonly v: number[];
}

/** matrix3 takes nine numbers, row by row, for when a table is too much ceremony. */
export function matrix3(
  m00: number, m01: number, m02: number,
  m10: number, m11: number, m12: number,
  m20: number, m21: number, m22: number,
): Matrix3 {
  return { v: [m00, m01, m02, m10, m11, m12, m20, m21, m22] };
}

/** M[r, c]: the entry in row r, column c, both counting from zero. */
export function at(M: Matrix3, r: number, c: number): number {
  return M.v[r * 3 + c];
}

export function identity(): Matrix3 {
  return matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1);
}

export function multiply(A: Matrix3, B: Matrix3): Matrix3 {
  const r: number[] = new Array(9);
  for (let row = 0; row < 3; row++) {
    for (let col = 0; col < 3; col++) {
      r[row * 3 + col] = at(A, row, 0) * at(B, 0, col) +
        at(A, row, 1) * at(B, 1, col) +
        at(A, row, 2) * at(B, 2, col);
    }
  }
  return { v: r };
}

/** Treats (x, y, w) as a column: the result's x, y, w are the three row dot products. */
export function multiply_tuple(M: Matrix3, t: Tuple): Tuple {
  return {
    x: at(M, 0, 0) * t.x + at(M, 0, 1) * t.y + at(M, 0, 2) * t.w,
    y: at(M, 1, 0) * t.x + at(M, 1, 1) * t.y + at(M, 1, 2) * t.w,
    w: at(M, 2, 0) * t.x + at(M, 2, 1) * t.y + at(M, 2, 2) * t.w,
  };
}

/** Every point of a list through the same matrix. */
export function transform_points(points: Tuple[], m: Matrix3): Tuple[] {
  return points.map((p) => multiply_tuple(m, p));
}

export function transpose(M: Matrix3): Matrix3 {
  return matrix3(
    at(M, 0, 0), at(M, 1, 0), at(M, 2, 0),
    at(M, 0, 1), at(M, 1, 1), at(M, 2, 1),
    at(M, 0, 2), at(M, 1, 2), at(M, 2, 2),
  );
}

/** The 2x2 determinant left when row r and column c are deleted. */
export function minor(M: Matrix3, r: number, c: number): number {
  const rows = [0, 1, 2].filter((i) => i !== r);
  const cols = [0, 1, 2].filter((i) => i !== c);
  return at(M, rows[0], cols[0]) * at(M, rows[1], cols[1]) -
    at(M, rows[0], cols[1]) * at(M, rows[1], cols[0]);
}

export function cofactor(M: Matrix3, r: number, c: number): number {
  const m = minor(M, r, c);
  return (r + c) % 2 === 1 ? -m : m;
}

/** A cofactor expansion along the first row. */
export function determinant(M: Matrix3): number {
  return at(M, 0, 0) * cofactor(M, 0, 0) +
    at(M, 0, 1) * cofactor(M, 0, 1) +
    at(M, 0, 2) * cofactor(M, 0, 2);
}

export function is_invertible(M: Matrix3): boolean {
  return determinant(M) !== 0;
}

/**
 * The matrix of cofactors, transposed, divided by the determinant. The
 * transpose happens by writing each cofactor straight into [c, r].
 */
export function inverse(M: Matrix3): Matrix3 {
  const d = determinant(M);
  const r: number[] = new Array(9);
  for (let row = 0; row < 3; row++) {
    for (let col = 0; col < 3; col++) {
      r[col * 3 + row] = cofactor(M, row, col) / d;
    }
  }
  return { v: r };
}

export function translation(tx: number, ty: number): Matrix3 {
  return matrix3(1, 0, tx, 0, 1, ty, 0, 0, 1);
}

export function scaling(sx: number, sy: number): Matrix3 {
  return matrix3(sx, 0, 0, 0, sy, 0, 0, 0, 1);
}

/** A positive angle turns the x axis toward the y axis, in radians. */
export function rotation(r: number): Matrix3 {
  const c = Math.cos(r), s = Math.sin(r);
  return matrix3(c, -s, 0, s, c, 0, 0, 0, 1);
}

export function shearing(xy: number, yx: number): Matrix3 {
  return matrix3(1, xy, 0, yx, 1, 0, 0, 0, 1);
}

/**
 * One number for how much m stretches lengths: the square root of the
 * absolute value of the determinant of its upper-left 2 by 2. Exact for
 * uniform scales and rotations, a compromise for shears and non-uniform
 * scales (see chapter 4, "How big is a transform"). Absolute value because
 * a reflection's determinant is negative and it's still a scale of 1.
 */
export function approx_scale(m: Matrix3): number {
  const d = at(m, 0, 0) * at(m, 1, 1) - at(m, 0, 1) * at(m, 1, 0);
  return Math.sqrt(Math.abs(d));
}
