# 2D Renderer Challenge - Ruby Implementation

This is a Ruby implementation of the 2D Renderer Challenge, covering Chapters 1, 2, and 3.

## Running Tests

Run all tests from this directory (it expects `features/` and `reference/` beside it, which the book's staging tool provides):
```bash
ruby test_chapter01.rb
ruby test_chapter02.rb
ruby test_chapter03.rb
```

Test results:
- Chapter 1: 64 runs, 782 assertions, all pass
- Chapter 2: 35 runs, 187 assertions, all pass
- Chapter 3: 41 runs, 177 assertions, all pass

## Generating Output Images

Generate Chapter 2 reference images:
```bash
ruby generate_chapter02_outputs.rb
```

Generate Chapter 3 renders:
```bash
ruby render_chapter03.rb
```

This produces the following P6 (binary PPM) files in the `out/` directory:

**Chapter 2:**
- `out/disc-centers.ppm` - Circle rendered using center-point sampling
- `out/disc-coverage.ppm` - Circle rendered using 8x8 coverage sampling
- `out/painted-twice.ppm` - Demonstrates the difference between coverage and opacity
- `out/plate-02.ppm` - Side-by-side comparison of centers vs coverage sampling

**Chapter 3:**
- `out/fan-bresenham.ppm` - 12 rays drawn with Bresenham's line algorithm (160x160)
- `out/fan-wu.ppm` - 12 rays drawn with Wu's antialiased line algorithm (160x160)
- `out/fan-coverage.ppm` - 12 rays rendered as thick rectangles (320x320, magnified 2x)
- `out/plate-03.ppm` - Bresenham's fan (left) vs Wu's antialiased fan (right), magnified 2x

## Implementation Notes

### Chapter 1: The Canvas and the Color
- Implements basic color operations and canvas manipulation
- Supports P3 (text) PPM format
- Includes sRGB color space conversions and color mixing
- `mix(a, b, t, linear_blending = nil)` takes an optional fourth argument that
  overrides the global `$linear_blending` switch for that one call, without
  changing the switch itself

### Chapter 2: Coverage
- Implements shape queries (circle, rectangle, half-plane)
- Adds binary P6 (rawbits) PPM format support
- Implements coverage buffers and rasterization
- Supports painting through coverage values
- Canvas magnification without resampling
- `paint_through` always mixes in light, regardless of `$linear_blending`
  (it calls `mix` with the fourth argument forced to `true`)

### Chapter 3: Lines
- Implements Bresenham's integer-only line algorithm
- Implements Wu's antialiased line algorithm with sub-pixel accuracy
- Implements thick_line as a composite shape (4 half-planes); a zero-length
  thick_line is a width-by-width square centered on the point, not a
  degenerate sliver
- Supports rendering fans of rays at multiple angles
- Rasterization of lines as coverage-filled rectangles
- fan_coverage rendering time: ~10-15 seconds for 12 rays at 160x160 with 2x magnification

## File Structure

- `renderer.rb` - Main implementation of graphics functions
- `test_chapter01.rb` - Unit tests for Chapter 1
- `test_chapter02.rb` - Unit tests for Chapter 2
- `test_chapter03.rb` - Unit tests for Chapter 3
- `generate_chapter02_outputs.rb` - Script to generate Chapter 2 output images
- `render_chapter03.rb` - Script to generate Chapter 3 output images
