# 2D Renderer Challenge - JavaScript Implementation

Implementation of Chapters 1–3 of "The 2D Renderer Challenge" in JavaScript (Node 22, built-in modules only).

## Running Tests

Run all tests from this directory (it expects `features/` and `reference/` beside it, which the book's staging tool provides):
```bash
node test.js
```

This runs:
- **Chapter 1**: 60 tests covering colors, canvas, sRGB, PPM I/O, and compositing
- **Chapter 2**: 29 tests covering shapes, coverage buffers, magnification, and coverage-based rasterization
- **Chapter 3**: 32 tests covering Bresenham line rasterization, Wu's antialiased lines, and thick lines as rectangles

All 121 tests should pass.

## Generating Output Files

The test suite automatically generates output images:
```bash
node test.js
```

Output files are written to `out/`:

Chapter 3:
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
- **Shapes**: Circle, rectangle, half-plane, thick line (point-in-shape tests)
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

## Key Design Choices

1. **Dual-format PPM support**: Functions detect P3 vs P6 by checking the header and parse accordingly
2. **Shape interface**: Simple function dispatch (no class inheritance) for circle, rectangle, half-plane, thick line
3. **Coverage computation**: Brute-force 8×8 grid per pixel (64 samples)
4. **Compositing**: Uses linear blend in light space; painting twice through coverage gives 1-(1-k)² opacity
5. **Thick lines**: Implemented as four half-planes (start cap, end cap, two sides), avoiding special line code
