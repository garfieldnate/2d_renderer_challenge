# 2D Renderer Challenge - Ruby Implementation

This is a Ruby implementation of the 2D Renderer Challenge, covering Chapters 1 and 2.

## Running Tests

Run all tests from this directory (it expects `features/` and `reference/` beside it, which the book's staging tool provides):
```bash
ruby test_chapter01.rb
ruby test_chapter02.rb
```

## Generating Output Images

Generate the Chapter 2 reference images:
```bash
ruby generate_chapter02_outputs.rb
```

This produces the following P6 (binary PPM) files in the `out/` directory:
- `out/disc-centers.ppm` - Circle rendered using center-point sampling
- `out/disc-coverage.ppm` - Circle rendered using 8x8 coverage sampling
- `out/painted-twice.ppm` - Demonstrates the difference between coverage and opacity
- `out/plate-02.ppm` - Side-by-side comparison of centers vs coverage sampling

## Implementation Notes

### Chapter 1: The Canvas and the Color
- Implements basic color operations and canvas manipulation
- Supports P3 (text) PPM format
- Includes sRGB color space conversions and color mixing

### Chapter 2: Coverage
- Implements shape queries (circle, rectangle, half-plane)
- Adds binary P6 (rawbits) PPM format support
- Implements coverage buffers and rasterization
- Supports painting through coverage values
- Canvas magnification without resampling

## File Structure

- `renderer.rb` - Main implementation of graphics functions
- `test_chapter01.rb` - Unit tests for Chapter 1
- `test_chapter02.rb` - Unit tests for Chapter 2
- `generate_chapter02_outputs.rb` - Script to generate output images
