# 2D Renderer Challenge: Python Implementation

Python 3 implementation of chapters 1 through 8 of the 2D Renderer Challenge, using only the Python standard library.

## Build

No build step required. The implementation uses only Python 3 stdlib.

## Run Tests

```sh
python3 test_runner.py
```

This runs all Gherkin scenarios from chapters 1 through 8, from every `.feature` file under `features/`.

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
    ('needles.ppm', renderer.needles), ('soft-square.ppm', renderer.soft_square),
    ('star-exact.ppm', renderer.star_exact), ('spiral-smooth.ppm', renderer.spiral_smooth),
    ('plate-07.ppm', renderer.plate_07),
    ('drops.ppm', renderer.drops), ('flower.ppm', renderer.flower),
    ('plate-08.ppm', renderer.plate_08),
]:
    p6 = renderer.canvas_to_p6(func())
    with open(f'out/{name}', 'wb') as f:
        f.write(p6 if isinstance(p6, bytes) else p6.encode('latin-1'))
"
```

Renders for chapters 1-6 land under `reference/chapter-01/` through `reference/chapter-06/`; chapter 7's renders (`needles.ppm`, `soft-square.ppm`, `star-exact.ppm`, `spiral-smooth.ppm`, `plate-07.ppm`) are under `reference/chapter-07/`, and chapter 8's (`drops.ppm`, `flower.ppm`, `plate-08.ppm`) under `reference/chapter-08/`.

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
- Chapter 7 replaces the center-sample/sweep fill with an analytic (signed-area) rasterizer. `Accumulator`/`accumulator(w, h)` holds two floats per cell, `area` and `cover`; `add_cell` deposits into one cell, folding a deposit left of the buffer onto column 0 as pure cover and dropping one right of the buffer. `accumulate_row` deposits one edge's piece within a single row, sharing its signed height across the cells it crosses by width and weighting each cell's area by the trapezoid midpoint rule. `accumulate` walks a whole edge down the rows it crosses (clipped to the buffer), with sign `+1` when the edge's first point has the larger `y` (heading up the canvas) and `-1` otherwise; horizontal edges deposit nothing. `resolve` sweeps each row left to right, turning the running cover-sum plus each cell's own area into a winding number, and `apply_rule` folds that (possibly fractional) winding into coverage — `min(1, |w|)` for `"nonzero"`, a triangle wave for `"evenodd"`. `fill_path(p, rule, w, h)` is the fill from here on, replacing `fill_path_aliased`; `polygon_area` is the shoelace formula, used by the scenarios to check the fill's total ink against the shape's exact area. `needle_path`/`needles`, `soft_square`, `star_exact`, `spiral_smooth`, `rays`/`sunburst`/`plate_07` render chapter 7's plates.
- Chapter 8 adds Bezier curves and the SVG elliptical arc. `Curve`/`quadratic`/`cubic` hold a curve as its control points; `point_at` evaluates it by de Casteljau's repeated linear interpolation; `split_at` keeps the same construction's left and right edges to split a curve into two of the same degree; `derivative` evaluates the curve's hodograph (one degree lower) for the tangent vector; `transform_curve` takes every control point through a matrix. `curve_bounds` finds the tight axis-aligned box by solving each axis of the derivative for its roots in `(0, 1)` (linear for a quadratic, quadratic for a cubic) and evaluating the curve there and at both ends. `flatness` is the farthest an interior control point sits from the chord between the curve's ends; `flatten` recursively bisects with `split_at` until every piece is flat enough, returning the polyline's points; `flatten_into_path` appends a flattened curve to a path with `line_to`. `polyline_length`/`flatten_length` measure a polyline/flattened curve's length. `arc(x1, y1, rx, ry, phi, large_arc, sweep, x2, y2)` converts SVG's endpoint form to a center form (growing the radii together and setting `corrected` when they're too small to reach, and returning `None` for coincident endpoints or a zero radius); `arc_point` walks it. `teardrop`/`drops`, `petal`/`flower_at`/`flower`/`plate_08` render chapter 8's plates.
- All geometry calculations use floating-point coordinates
- Antialiasing uses 8×8 supersampling (64 samples per pixel)
- P6 binary PPM files are used for efficiency
- Matrix operations use exact arithmetic with component-wise tolerance comparison (0.0001)
- Transforms are composed in reverse order: C * B * A applies A first, then B, then C
- The Gherkin test harness (`test_runner.py`) compares lists and tuples element-wise with the usual 0.0001 tolerance, recursively, so a list of `(x, direction)` crossings or `(x0, x1)` spans compares each float with tolerance rather than falling back to Python's exact `==` (see Feedback, chapter 6, for why this needed fixing).
