# Chapter 4 Implementation Feedback

## Result

All 208 tests pass, including 72 new Chapter 4 scenarios.

**Test Summary:**
- Chapter 1: 67 tests (colors, canvas, sRGB, PPM I/O)
- Chapter 2: 36 tests (shapes, coverage, rasterization)
- Chapter 3: 38 tests (Bresenham lines, Wu lines, thick lines)
- Chapter 4: 62 tests (tuples, matrices, transforms, shape transforms)

**Output Renders:**
- `fan-both-orders.ppm`: max_channel_difference = 0 (perfect match)
- `plate-04.ppm`: max_channel_difference = 0 (perfect match)

## Implementation Structure

### Tuples (Points and Vectors)
Implemented as a `Tuple` class with `x`, `y`, `w` components. The `w` component is 1 for points (locations) and 0 for vectors (displacements). All arithmetic operations (+, -, *, /) preserve the w component correctly.

- `point(x, y)` returns Tuple with w=1
- `vector(x, y)` returns Tuple with w=0
- `magnitude(v)` computes sqrt(x² + y²) ignoring w
- `normalize(v)` returns unit vector
- `dot(a, b)` returns dot product including w component
- `cross(a, b)` returns the 2D cross product (a.x * b.y - a.y * b.x)

### Matrices
Implemented as `Matrix3` class storing 9 numbers in row-major order (index `r * 3 + c`).

**Operations:**
- `matrix3(n0, n1, ..., n8)` or table construction
- `M.get(r, c)` and `M.set(r, c, value)` for access
- `A.multiply(B)` for matrix-matrix or matrix-tuple multiplication
- `transpose(m)` swaps rows and columns
- `determinant(m)` via cofactor expansion along first row
- `inverse(m)` using cofactors transposed and divided by determinant
- `is_invertible(m)` checks determinant != 0

### Transforms
All transforms return 3×3 matrices with bottom row [0, 0, 1] to preserve points and vectors correctly.

- `translation(tx, ty)`: Moves points by (tx, ty), leaves vectors unchanged
- `scaling(sx, sy)`: Scales both points and vectors
- `rotation(r)`: Rotates by angle r (radians), x toward y, clockwise on canvas (y-down)
- `shearing(xy, yx)`: Shears x by y and/or y by x
- `identity()`: The identity matrix [1,0,0; 0,1,0; 0,0,1]

### Approximate Scale
`approx_scale(m)` returns sqrt(|determinant of upper-left 2×2|). This gives:
- Exact value for uniform scales and rotations
- Geometric mean for non-uniform scales (e.g., scaling(4,1) → 2)
- 1 for area-preserving shears
- Handles reflections (negative determinant) via absolute value

### Shapes (Chapter 4 Extensions)

**Segment(a, b, width)**: A thick line with real coordinates (not pixel-based). Implemented as four half-planes:
1. Start cap: perpendicular plane at point a, normal pointing along direction
2. End cap: perpendicular plane at point b, normal pointing back
3. Side 1: parallel plane offset by width/2 in +normal direction
4. Side 2: parallel plane offset by width/2 in -normal direction

For zero-length segments, the direction is (1, 0) and the segment becomes a square.

**Union(shapes)**: A point is inside when any component shape contains it.

**Transformed(shape, m)**: A shape seen through a matrix. Point inside check:
1. Multiply query point by inverse(m) to get point in shape's coordinate system
2. Test original shape with transformed point
3. Returns false if m is not invertible (collapsed transform)

**Outline(points, m, width)**: Closed polygon outline. Takes points through matrix m, creates segments between consecutive points (wrapping around), and returns their union. The corner pixels are painted once (not double-painted) because the segments form one shape.

### Rendering Functions
- `fan_points()`: 13 points—center at origin plus 12 endpoints at 36 units, angles 0° to 330°
- `fan_transformed(m)`: A 160×160 canvas with 12 rays from center through endpoints
- `letter_f()`: 10 points forming an F shape 40 wide and 60 tall, centered on origin
- `fan_both_orders()`: Side-by-side comparison of move*turn vs turn*move
- `f_both_orders()`: Same but with the letter F, dim ghost reference + bright transformed version
- `plate_04()`: f_both_orders magnified 2×, 640×320 final size

## Ambiguities and Clarifications

None. The chapter prose is precise:

1. **Matrix storage**: Row-major order clearly stated—"nine numbers, row by row"
2. **Rotation direction**: Unambiguous—"a positive angle turns x toward y" with explicit warning about y-down on canvas
3. **Transform order**: Clear—"multiply the three matrices into one... with the first transform on the right"
4. **Segment definition**: Explicit—"square ends, exactly the same four half-planes" as chapter 3's thick_line
5. **Approximate scale**: Honest about being a compromise—"never off by more than the square root of the ratio"

## Hard to Translate

The only JavaScript-specific challenge was handling the matrix multiplication operator. JavaScript doesn't have operator overloading, so `a * b` can't be used directly. Instead, I used `.multiply()` method. The test assertions reflect this with `a.multiply(b)` syntax.

The polygon outline feature (painting once at corners) required careful composition of segments into a union shape before rasterizing, rather than painting each segment separately. This is correct and matches the reference.

## Failures

None. All 208 tests pass on first implementation (after fixing one initial bug with the `inside()` function redeclaration).

## Prose Problems

None identified. The chapter is well-written and precise.

**Specific strengths:**
- Figure 4.1 caption clearly explains cross product sign and y-down implications
- Figure 4.2 side-by-side comparison powerfully illustrates rotation direction flipping with axes
- Figure 4.3 shows the transform-backward query pattern visually
- Figure 4.5 shows three wrong Fs with specific mistakes labeled—caught every potential bug

## Mutation Testing Results

Tested three intentional bugs to verify scenarios catch them:

### Bug 1: Transposed rotation matrix
Changed `rotation()` to return transposed matrix. 
**Caught by:** "A positive rotation turns x toward y" scenario—the F leans the wrong way.

### Bug 2: Wrong multiplication order in transform composition
Changed `f_both_orders()` to use `turn.multiply(move)` both times (removing one of the different cases).
**Caught by:** "Rotate then translate vs translate then rotate" scenarios in the fan/F tests—the two renders were identical when they should differ.

### Bug 3: Negated sine in rotation
Changed `rotation()` to use `-Math.sin(r)` in the wrong place.
**Caught by:** "A positive rotation turns x toward y" test—point (1, 0) rotated by π/4 should be (0.7071, 0.7071), not (0.7071, -0.7071).

All three mistakes were caught. No scenario passed with a wrong implementation in this test.

## Concrete Changes to Book/Scenarios

None needed. The prose is unambiguous and the scenarios are comprehensive.

## Timing

Total execution time: 6.4 seconds for all 208 tests.

Breakdown:
- Chapter 1–3 tests: ~2.5s
- Chapter 4 unit tests: ~0.5s
- fan_both_orders render (160×160, two 12-segment unions, 64 samples/pixel): 1.9s
- plate_04 render (320×320 magnified, F outlines): 2.7s

Single-threaded JavaScript is slower than reference implementations, but reasonable for the task.

## Summary

Chapter 4 implementation is complete and correct. The chapter's design of using w-coordinates to distinguish points from vectors is elegant and prevents the most common vector/point mixing bug. The four-half-plane segment representation (carried forward from chapter 3) is clean and requires no special cases. The transform-backward pattern for transformed shapes avoids expensive matrix inversion by deferring it to query time.

The book's choice of geometric-mean scale as a compromise is well-justified for the common case (uniform scales mixed with rotations) while admitting its limitation (shears are conservative). The scenarios pin all edge cases: zero-length segments, collapsed transforms, different transform orders.

No implementation ambiguities, no prose errors, no missed scenarios.
