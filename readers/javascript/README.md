# 2D Renderer Challenge - JavaScript Implementation

Implementation of Chapters 1 and 2 of "The 2D Renderer Challenge" in JavaScript (Node 22, built-in modules only).

## Running Tests

Run all tests from the project root:
```bash
node readers/javascript/test.js
```

This runs:
- **Chapter 1**: 60 tests covering colors, canvas, sRGB, PPM I/O, and compositing
- **Chapter 2**: 29 tests covering shapes, coverage buffers, magnification, and coverage-based rasterization

All 89 tests should pass.

## Generating Output Files

The test suite automatically generates output images:
```bash
node readers/javascript/test.js
```

Output files are written to `out/`:
- `disc-centers.ppm` - Circle rasterized by pixel centers (binary P6 format, 320×320)
- `disc-coverage.ppm` - Circle rasterized with 8×8 sampling (binary P6 format, 320×320)
- `painted-twice.ppm` - Coverage painted once (left) and twice (right) (binary P6 format, 480×240)
- `plate-02.ppm` - Side-by-side comparison: centers vs coverage (binary P6 format, 480×240)

Plus Chapter 1 outputs:
- `gray-match.ppm` - Checkerboard, gray midpoint, and 0.5 (300×100)
- `quarter-match.ppm` - 25% pattern vs solid 0.25 (200×100)
- `ramp.ppm` - 256-step brightness ramp (256×32)
- `clamp-pair.ppm` - Out-of-range colors and clamping (200×100)
- `plate-01.ppm` - Browser blend vs light-linear blend (400×180)

## Implementation Structure

- **Color & Canvas**: Basic color math and pixel storage
- **sRGB**: Encoding/decoding for proper gamma handling
- **PPM I/O**: P3 text and P6 binary formats, with unified reader
- **Shapes**: Circle, rectangle, half-plane (point-in-shape tests)
- **Coverage Buffer**: Sparse storage of coverage values (0-1)
- **Rasterization**:
  - `rasterize_centers()` - Binary coverage by center test
  - `rasterize()` - 8×8 sample-point grid for accurate coverage
- **Painting**: `paint_through()` uses coverage values to blend colors
- **Magnify**: Pixel-perfect scaling (no filtering)

## Key Design Choices

1. **Dual-format PPM support**: Functions detect P3 vs P6 by checking the header and parse accordingly
2. **Shape interface**: Simple function dispatch (no class inheritance) for circle, rectangle, half-plane
3. **Coverage computation**: Brute-force 8×8 grid per pixel (64 samples)
4. **Compositing**: Uses linear blend in light space; painting twice through coverage gives 1-(1-k)² opacity
