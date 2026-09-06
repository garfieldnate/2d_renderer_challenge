# 2D Renderer Challenge - Ruby Implementation

This is a Ruby implementation of the 2D Renderer Challenge, covering Chapters 1 through 6.

## Running Tests

Run all tests from this directory (it expects `features/` and `reference/` beside it, which the book's staging tool provides):
```bash
ruby test_chapter01.rb
ruby test_chapter02.rb
ruby test_chapter03.rb
ruby test_chapter04.rb
ruby test_chapter05.rb
ruby test_chapter06.rb
```

Test results:
- Chapter 1: 64 runs, 782 assertions, all pass
- Chapter 2: 35 runs, 187 assertions, all pass
- Chapter 3: 41 runs, 177 assertions, all pass
- Chapter 4: 76 runs, 306 assertions, all pass
- Chapter 5: 32 runs, 253 assertions, all pass
- Chapter 6: 37 runs, 232 assertions, all pass

`test_chapter03_mistakes.rb` holds a few skipped scenarios that document
mistakes a reader could make in chapter 3; they aren't part of the pass/fail
count above.

## Generating Output Images

Generate Chapter 2 reference images:
```bash
ruby generate_chapter02_outputs.rb
```

Generate Chapter 3, 4, 5 and 6 renders:
```bash
ruby render_chapter03.rb
ruby render_chapter04.rb
ruby render_chapter05.rb
ruby render_chapter06.rb
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

**Chapter 4:**
- `out/fan-both-orders.ppm` - The chapter 3 fan under rotate-then-translate vs translate-then-rotate
- `out/plate-04.ppm` - The letter F under both transform orders, magnified 2x

**Chapter 5:**
- `out/star-centers.ppm` - The pentagram filled under nonzero and even-odd, by the center question
- `out/star-coverage.ppm` - The same, by 8x8 coverage within the star's bounds
- `out/plate-05.ppm` - Both rows stacked and magnified 2x

**Chapter 6:**
- `out/spiral.ppm` - 24 pentagrams along a spiral, filled by the scanline sweep
- `out/plate-06.ppm` - The spiral magnified 2x

All renders in `out/` match their `reference/chapter-0N/*.ppm` counterparts with
`max_channel_difference` of 0 (exact byte match), except chapter 3's Wu/coverage
renders which are within the book's stated tolerance.

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

### Chapter 4: Points, Vectors, Transforms
- Tuples (`point`/`vector`), 3x3 matrices, transposition, determinant, inverse
- `translation`, `scaling`, `rotation`, `shearing`, and their composition by `*`
  (read right to left, as the book says)
- `Segment` becomes a real geometric primitive (`segment(a, b, width)`), and
  `thick_line` is now defined in terms of it
- `Union` and `Transformed` shapes let any shape go through a matrix; a shape
  through a non-invertible matrix is empty
- `outline(points, m, width)` unions the segments of a transformed polygon into
  one shape so shared corners paint once, not twice
- `approx_scale(m)` reports the geometric mean of a transform's stretch, used
  to keep a pen's width consistent under non-uniform scale
- `side_by_side(a, b)` composites two canvases for the plates

### Chapter 5: Paths and Insideness
- `Path`/`Subpath`: `move_to`, `line_to`, `close`, `subpaths`, `edges`, `bounds`.
  A `line_to` right after a `close` starts a new subpath at the point the
  closed subpath began (that's where the pen ends up); a `line_to` with no
  current subpath behaves like a `move_to`
- `polygon(...)` and `circle_path(cx, cy, r, n)` build paths directly
- `crossings(p, x, y)` and `winding_at(p, x, y)` implement ray casting and the
  signed winding number, both using the half-open rule (`a.y <= y < b.y`) so a
  vertex on the ray counts once
- `inside_nonzero`/`inside_evenodd` and `filled(p, rule)` turn a path into a
  `Shape` chapter 2's rasterizer can draw
- `rasterize_within(shape, box, w, h)` restricts chapter 2's rasterize to the
  pixels a bounding box touches
- `star()` is the book's pentagram fixture, reused in chapter 6

### Chapter 6: Filling a Polygon
- `edge_table(p)` turns a path's edges into `Edge` records (`y_top`,
  `y_bottom`, `x_top`, `slope`, `direction`), dropping exactly-horizontal edges
  and sorting by `y_top` then `x_top`
- `crossings_on_row`, `spans_from_crossings`, `spans(p, rule, row)` and
  `fill_span(cov, row, x0, x1)` build one row of the scanline fill; `fill_span`
  is half-open at its right end so two spans that share a boundary fill that
  pixel exactly once
- `fill_path_aliased(p, rule, w, h)` is the classical scanline sweep with an
  active edge list; it produces the exact same coverage buffer as chapter 5's
  `rasterize_centers(filled(p, rule), w, h)`, verified pixel for pixel by
  `max_coverage_difference`, and it is dramatically faster: the chapter 5
  by-coverage star render takes ~8.5s in this implementation, the chapter 6
  sweep-based spiral of 24 stars takes ~0.5s
- `transform_path(p, m)` and `unit_star()`/`spiral()`/`plate_06()` build the
  spiral plate
- **Reader note**: `edge_table`'s slope formula (`(b.x - a.x) / (b.y - a.y)`)
  must use float division. Several scenarios build polygons from integer
  coordinates (e.g. `polygon(point(0, 0), point(10, 0), point(5, 10))`), and in
  Ruby, `Integer / Integer` truncates (floors) instead of producing a float;
  this implementation forces `.to_f` on the divisor in both branches

## File Structure

- `renderer.rb` - Main implementation of graphics functions
- `test_chapter01.rb` - Unit tests for Chapter 1
- `test_chapter02.rb` - Unit tests for Chapter 2
- `test_chapter03.rb` - Unit tests for Chapter 3
- `test_chapter03_mistakes.rb` - Documented (skipped) mistakes for Chapter 3
- `test_chapter04.rb` - Unit tests for Chapter 4
- `test_chapter05.rb` - Unit tests for Chapter 5
- `test_chapter06.rb` - Unit tests for Chapter 6
- `generate_chapter02_outputs.rb` - Script to generate Chapter 2 output images
- `render_chapter03.rb` - Script to generate Chapter 3 output images
- `render_chapter04.rb` - Script to generate Chapter 4 output images
- `render_chapter05.rb` - Script to generate Chapter 5 output images
- `render_chapter06.rb` - Script to generate Chapter 6 output images
