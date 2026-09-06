# 2D Renderer Challenge - JavaScript Implementation

Implementation of Chapters 1–6 of "The 2D Renderer Challenge" in JavaScript (Node 22, built-in modules only).

## Running Tests

Run all tests from this directory (it expects `features/` and `reference/` beside it, which the book's staging tool provides):
```bash
node test.js
```

This runs:
- **Chapter 1**: colors, canvas, sRGB, PPM I/O, and compositing
- **Chapter 2**: shapes, coverage buffers, magnification, and coverage-based rasterization
- **Chapter 3**: Bresenham line rasterization, Wu's antialiased lines, and thick lines as rectangles
- **Chapter 4**: points, vectors, matrices, transforms, and shape transformations
- **Chapter 5**: paths, the crossing count, the winding number, the nonzero/even-odd fill rules, and the bounded rasterizer
- **Chapter 6**: the edge table, crossings/spans on a row, the active-edge scanline sweep, `transform_path`, and the spiral plate
- **Output files**: one test per chapter that writes that chapter's renders to `out/`

All 284 tests should pass.

## Generating Output Files

The test suite automatically generates output images:
```bash
node test.js
```

Output files are written to `out/`:

Chapter 6:
- `spiral.ppm` - Twenty-four stars along a spiral, filled by the scanline sweep (320×320, binary P6 format)
- `plate-06.ppm` - The spiral, magnified 2× (640×640, binary P6 format)

Chapter 5:
- `star-centers.ppm` - The pentagram filled nonzero (left) and even-odd (right) by the center question (320×160, binary P6 format)
- `star-coverage.ppm` - The same, by 8×8 coverage within the path's bounds (320×160, binary P6 format)
- `plate-05.ppm` - The center and coverage panels stacked, magnified 2× (640×640, binary P6 format)

Chapter 4:
- `fan-both-orders.ppm` - Two fans showing the order-dependence of matrix multiplication (320×160, binary P6 format)
- `plate-04.ppm` - An F shape through two different matrix multiplication orders, magnified 2× (640×320, binary P6 format)

Chapter 3:
- `fan-bresenham.ppm` - Twelve rays drawn with Bresenham's line (160×160, binary P6 format)
- `fan-wu.ppm` - Twelve rays drawn with Wu's antialiased line (160×160, binary P6 format)
- `fan-coverage.ppm` - Twelve rays as thick lines (coverage-based, 320×320, binary P6 format)
- `plate-03.ppm` - Bresenham's fan (left) vs Wu's fan (right), magnified 2× (640×320, binary P6 format)

Chapter 2:
- `disc-centers.ppm` - Circle rasterized by pixel centers (binary P6 format, 320×320)
- `disc-coverage.ppm` - Circle rasterized with 8×8 sampling (binary P6 format, 320×320)
- `painted-twice.ppm` - Coverage painted once (left) and twice (right) (binary P6 format, 480×240)
- `plate-02.ppm` - Side-by-side comparison: centers vs coverage (binary P6 format, 480×240)

Chapter 1:
- `gray-match.ppm` - Checkerboard, gray midpoint, and 0.5 (300×100)
- `quarter-match.ppm` - 25% pattern vs solid 0.25 (200×100)
- `ramp.ppm` - 256-step brightness ramp (256×32)
- `clamp-pair.ppm` - Out-of-range colors and clamping (200×100)
- `plate-01.ppm` - Browser blend vs light-linear blend (400×180)

## Implementation Structure

- **Color & Canvas**: Basic color math and pixel storage
- **sRGB**: Encoding/decoding for proper gamma handling
- **PPM I/O**: P3 text and P6 binary formats, with unified reader
- **Shapes**: Circle, rectangle, half-plane, thick line, segment, union, transformed, filled path (point-in-shape tests)
- **Coverage Buffer**: Sparse storage of coverage values (0-1)
- **Rasterization**:
  - `rasterize_centers()` - Binary coverage by center test
  - `rasterize()` - 8×8 sample-point grid for accurate coverage
  - `rasterize_within()` - `rasterize()` restricted to a path's bounding box (chapter 5)
  - `fill_path_aliased()` - the classical scanline sweep with an edge table and active edge list; produces the same buffer as `rasterize_centers(filled(p, rule), w, h)` (chapter 6)
- **Painting**: `paint_through()` uses coverage values to blend colors (always in light, regardless of the linear-blending switch)
- **Magnify**: Pixel-perfect scaling (no filtering)
- **Lines**:
  - `line_bresenham()` - Integer-only midpoint line algorithm, one pixel per column/row
  - `line_wu()` - Antialiased lines via weighted two-pixel coverage (always blended in light, regardless of the linear-blending switch)
  - `thick_line()` - Lines as rectangles: four half-planes composed with `inside()`
  - `segment()` - Real-coordinate thick lines (chapter 4)
- **Tuples and Matrices**:
  - `Tuple` class: Points (w=1) and vectors (w=0) with arithmetic operations
  - `Matrix3` class: 3×3 matrices in row-major order with multiplication
  - Vector operations: `magnitude()`, `normalize()`, `dot()`, `cross()` (magnitude and dot look at x and y only, ignoring w)
  - Matrix operations: `transpose()`, `determinant()`, `inverse()`, `cofactor()`, `minor()`
- **Transforms**: `translation()`, `scaling()`, `rotation()`, `shearing()`, `identity()`
- **Approximate Scale**: `approx_scale()` for determining stretch factor (geometric mean of determinant)
- **Shape Transforms**:
  - `transformed()` - Applies matrix via inverse in shape space
  - `union()` - Multiple shapes as one
  - `outline()` - Closed polygon outline with stroke width
  - `transform_points()` - Applies matrix to point list
- **Paths** (chapter 5):
  - `Path` / `path()`, `move_to()`, `line_to()`, `close()`, `subpaths()`, `edges()`, `bounds()` - the path data structure
  - `polygon()`, `circle_path()` - path builders
  - `crossings()`, `winding_at()` - the ray-casting insideness tests, both half-open at the lower edge
  - `inside_nonzero()`, `inside_evenodd()` - the two fill rules on top of `winding_at()`
  - `filled()` - a path plus a rule, as a `Shape`
- **Scanline fill** (chapter 6):
  - `edge_table()`, `x_at()` - the sorted, non-horizontal edge table
  - `crossings_on_row()`, `spans_from_crossings()`, `spans()` - per-row crossings and the spans between them
  - `fill_span()` - turns a span into set pixels, half-open at the right end
  - `fill_path_aliased()` - the active-edge sweep
  - `transform_path()` - `transform_points()` with the subpath structure kept
  - `max_coverage_difference()` - `max_channel_difference()` for coverage buffers

## Key Design Choices

1. **Dual-format PPM support**: Functions detect P3 vs P6 by checking the header and parse accordingly
2. **Shape interface**: Polymorphic `inside()` function using `instanceof` checks for all shape types, including `FilledPath`
3. **Coverage computation**: Brute-force 8×8 grid per pixel (64 samples)
4. **Compositing**: Uses linear blend in light space; painting twice through coverage gives 1-(1-k)² opacity
5. **Thick lines and segments**: Implemented as four half-planes (start cap, end cap, two sides), avoiding special line code
6. **Tuple representation**: Points and vectors are `Tuple` objects with `w = 1` for points, `w = 0` for vectors
7. **Matrix storage**: Row-major order in a flat array for fast indexing
8. **Transform composition**: Matrices multiply right-to-left (rightmost transform applied first)
9. **Transformed shapes**: Query backward through inverse matrix to detect shape boundary in original space
10. **Approximate scale**: Uses geometric mean of determinant (square root) as compromise between largest stretch and area factor
11. **Path storage**: A path is `{ subpaths: [{ points: [Tuple, ...], closed: bool }, ...] }`, a plain list of subpaths built by `move_to`/`line_to`/`close`
12. **`edges()` always closes each subpath**: for filling, every subpath (2+ points) contributes the wrap-around edge from its last point to its first, whether or not `close()` was called
13. **Half-open rule, three times over**: `crossings()`/`winding_at()` treat an edge as spanning height `y` when `a.y <= y < b.y` (or the reverse), `fill_span()` fills pixel centers in `[x0, x1)`, and the sweep's active-edge join/exit uses the same `<=`/`>` split — all three are the same convention so a path's boundary belongs to exactly one side
14. **The scanline sweep reads the edge table once, front to back**, keeping an active list filtered by `y_bottom > y` each row, rather than rescanning every edge on every row

## Reader Notes

See `FEEDBACK.md` for what was ambiguous, what broke, and what mutation testing found (in
particular: `inside_evenodd` and the even-odd fill rule have no chapter 5 scenario that exercises
a *negative* odd winding number, so a `w % 2 === 1` without `Math.abs` passes every chapter 5
scenario even though it's wrong).
