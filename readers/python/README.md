# 2D Renderer Challenge: Python Implementation

Python 3 implementation of chapters 1 through 6 of the 2D Renderer Challenge, using only the Python standard library.

## Build

No build step required. The implementation uses only Python 3 stdlib.

## Run Tests

```sh
python3 test_runner.py
```

This runs all Gherkin scenarios from chapters 1 through 6, from every `.feature` file under `features/`.

## Produce Renders

```sh
python3 -c "
import renderer
import os
os.makedirs('out', exist_ok=True)
for name, func in [
    ('disc-centers.ppm', renderer.disc_centers), ('disc-coverage.ppm', renderer.disc_coverage),
    ('painted-twice.ppm', renderer.painted_twice), ('plate-02.ppm', renderer.plate_02),
    ('fan-bresenham.ppm', renderer.fan_bresenham), ('fan-wu.ppm', renderer.fan_wu),
    ('fan-coverage.ppm', renderer.fan_coverage), ('plate-03.ppm', renderer.plate_03),
    ('fan-both-orders.ppm', renderer.fan_both_orders), ('plate-04.ppm', renderer.plate_04),
    ('star-centers.ppm', renderer.star_centers), ('star-coverage.ppm', renderer.star_coverage),
    ('plate-05.ppm', renderer.plate_05),
    ('spiral.ppm', renderer.spiral), ('plate-06.ppm', renderer.plate_06),
]:
    p6 = renderer.canvas_to_p6(func())
    with open(f'out/{name}', 'wb') as f:
        f.write(p6 if isinstance(p6, bytes) else p6.encode('latin-1'))
"
```

Compare a render against its reference with `renderer.max_channel_difference`:

```sh
python3 -c "
import renderer
with open('out/spiral.ppm', 'rb') as f: p6 = f.read()
with open('reference/chapter-06/spiral.ppm', 'rb') as f: ref = f.read()
print(renderer.max_channel_difference(p6, ref))
"
```

## Files

- `renderer.py` — Core graphics functions and chapter implementations
- `test_runner.py` — Gherkin test harness
- `features/` — Gherkin feature files (test specifications)
- `reference/` — Reference images for validation
- `out/` — Generated output images (after rendering)

## Implementation Notes

- Chapter 1 implements the canvas, colors, and PPM output
- Chapter 2 adds coverage buffers, shape queries, and antialiasing via supersampling
- Chapter 3 implements three line rendering approaches: Bresenham (fast, discrete), Wu (antialiased), and thick_line (coverage-based)
- Chapter 4 implements points, vectors, 3×3 matrices, and matrix transforms (translation, scaling, rotation, shearing); adds segment, union, transformed, and outline shapes; defines approx_scale for understanding stretch factors
- Chapter 5 adds `Path`: `move_to`/`line_to`/`close` build subpaths, `edges` lists every edge treating each subpath as closed, `bounds` is the axis-aligned box. `crossings` and `winding_at` answer insideness by ray casting, both using the half-open rule (`a.y <= y < b.y`) so a ray through a vertex counts once. `inside_nonzero`/`inside_evenodd` are the two fill rules built on `winding_at`; `filled(path, rule)` turns a path into a `Shape` chapter 2's rasterizer already knows how to draw. `rasterize_within` restricts chapter 2's `rasterize` to a path's bounding box. `star()`/`star_panel`/`star_centers`/`star_coverage`/`plate_05` render the pentagram plate.
- Chapter 6 replaces the per-pixel winding-number query with a classical scanline sweep. `edge_table` prepares every non-horizontal edge (`y_top`, `y_bottom`, `x_top`, `slope`, `direction`) sorted for the sweep; horizontal edges (`a.y == b.y` exactly) are dropped. `x_at` evaluates an edge's x at a height. `crossings_on_row` and `spans_from_crossings` turn a table into spans for one row; `fill_span` paints the pixels whose centers fall in a half-open span. `fill_path_aliased` is the full sweep with an active-edge list, producing a 0/1 coverage buffer identical to chapter 5's `rasterize_centers(filled(path, rule), w, h)` (checked directly by scenarios via `max_coverage_difference`). `transform_path` carries a path through a matrix without touching the original. `unit_star`/`spiral`/`plate_06` render the spiral plate of 24 stars.
- All geometry calculations use floating-point coordinates
- Antialiasing uses 8×8 supersampling (64 samples per pixel)
- P6 binary PPM files are used for efficiency
- Matrix operations use exact arithmetic with component-wise tolerance comparison (0.0001)
- Transforms are composed in reverse order: C * B * A applies A first, then B, then C
- The Gherkin test harness (`test_runner.py`) compares lists and tuples element-wise with the usual 0.0001 tolerance, recursively, so a list of `(x, direction)` crossings or `(x0, x1)` spans compares each float with tolerance rather than falling back to Python's exact `==` (see Feedback, chapter 6, for why this needed fixing).
