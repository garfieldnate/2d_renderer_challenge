# 2D Renderer Challenge - JavaScript Implementation

Implementation of Chapters 1–4 of "The 2D Renderer Challenge" in JavaScript (Node 22, built-in modules only).

## Running Tests

Run all tests from this directory (it expects `features/` and `reference/` beside it, which the book's staging tool provides):
```bash
node test.js
```

This runs:
- **Chapter 1**: 67 tests covering colors, canvas, sRGB, PPM I/O, and compositing
- **Chapter 2**: 36 tests covering shapes, coverage buffers, magnification, and coverage-based rasterization
- **Chapter 3**: 38 tests covering Bresenham line rasterization, Wu's antialiased lines, and thick lines as rectangles
- **Chapter 4**: 62 tests covering points, vectors, matrices, transforms, and shape transformations
- **Output files**: 3 tests for rendering and writing output (including 1 test pair for chapters 3–4)

All 208 tests should pass.

## Generating Output Files

The test suite automatically generates output images:
```bash
node test.js
```

Output files are written to `out/`:

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
- **Shapes**: Circle, rectangle, half-plane, thick line, segment, union, transformed (point-in-shape tests)
- **Coverage Buffer**: Sparse storage of coverage values (0-1)
- **Rasterization**:
  - `rasterize_centers()` - Binary coverage by center test
  - `rasterize()` - 8×8 sample-point grid for accurate coverage
- **Painting**: `paint_through()` uses coverage values to blend colors
- **Magnify**: Pixel-perfect scaling (no filtering)
- **Lines**:
  - `line_bresenham()` - Integer-only midpoint line algorithm, one pixel per column/row
  - `line_wu()` - Antialiased lines via weighted two-pixel coverage
  - `thick_line()` - Lines as rectangles: four half-planes composed with `inside()`
  - `segment()` - Real-coordinate thick lines (chapter 4)
- **Tuples and Matrices**:
  - `Tuple` class: Points (w=1) and vectors (w=0) with arithmetic operations
  - `Matrix3` class: 3×3 matrices in row-major order with multiplication
  - Vector operations: `magnitude()`, `normalize()`, `dot()`, `cross()`
  - Matrix operations: `transpose()`, `determinant()`, `inverse()`, `cofactor()`, `minor()`
- **Transforms**: `translation()`, `scaling()`, `rotation()`, `shearing()`, `identity()`
- **Approximate Scale**: `approx_scale()` for determining stretch factor (geometric mean of determinant)
- **Shape Transforms**:
  - `transformed()` - Applies matrix via inverse in shape space
  - `union()` - Multiple shapes as one
  - `outline()` - Closed polygon outline with stroke width
  - `transform_points()` - Applies matrix to point list

## Key Design Choices

1. **Dual-format PPM support**: Functions detect P3 vs P6 by checking the header and parse accordingly
2. **Shape interface**: Polymorphic `inside()` function using `instanceof` checks for all shape types
3. **Coverage computation**: Brute-force 8×8 grid per pixel (64 samples)
4. **Compositing**: Uses linear blend in light space; painting twice through coverage gives 1-(1-k)² opacity
5. **Thick lines and segments**: Implemented as four half-planes (start cap, end cap, two sides), avoiding special line code
6. **Tuple representation**: Points and vectors are `Tuple` objects with `w = 1` for points, `w = 0` for vectors
7. **Matrix storage**: Row-major order in a flat array for fast indexing
8. **Transform composition**: Matrices multiply right-to-left (rightmost transform applied first)
9. **Transformed shapes**: Query backward through inverse matrix to detect shape boundary in original space
10. **Approximate scale**: Uses geometric mean of determinant (square root) as compromise between largest stretch and area factor
