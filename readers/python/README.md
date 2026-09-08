# 2D Renderer Challenge: Python Implementation

Python 3 implementation of chapters 1 through 13 of the 2D Renderer Challenge, using only the Python standard library.

## Build

No build step required. The implementation uses only Python 3 stdlib.

## Run Tests

```sh
python3 test_runner.py
```

This runs all Gherkin scenarios from chapters 1 through 13, from every `.feature` file under `features/`.

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
    ('porter-duff.ppm', renderer.porter_duff_table), ('plate-09.ppm', renderer.plate_09),
    ('blend-modes.ppm', renderer.blend_strip), ('seam.ppm', renderer.seam),
    ('three-gradients.ppm', renderer.three_gradients), ('plate-10.ppm', renderer.plate_10),
    ('extend-modes.ppm', renderer.extend_strip),
    ('two-filters.ppm', renderer.two_filters), ('plate-11.ppm', renderer.plate_11),
    ('three-filters.ppm', renderer.three_filters),
    ('opacity.ppm', renderer.opacity_plate), ('plate-12.ppm', renderer.plate_12),
    ('clip-demo.ppm', renderer.clip_demo),
    ('joins.ppm', renderer.joins_plate), ('plate-13.ppm', renderer.plate_13),
    ('caps.ppm', renderer.caps_demo),
]:
    p6 = renderer.canvas_to_p6(func())
    with open(f'out/{name}', 'wb') as f:
        f.write(p6 if isinstance(p6, bytes) else p6.encode('latin-1'))
"
```

Renders for chapters 1-6 land under `reference/chapter-01/` through `reference/chapter-06/`; chapter 7's renders (`needles.ppm`, `soft-square.ppm`, `star-exact.ppm`, `spiral-smooth.ppm`, `plate-07.ppm`) are under `reference/chapter-07/`, chapter 8's (`drops.ppm`, `flower.ppm`, `plate-08.ppm`) under `reference/chapter-08/`, chapter 9's (`porter-duff.ppm`, `plate-09.ppm`, `blend-modes.ppm`, `seam.ppm`) under `reference/chapter-09/`, chapter 10's (`three-gradients.ppm`, `plate-10.ppm`, `extend-modes.ppm`) under `reference/chapter-10/`, chapter 11's (`two-filters.ppm`, `plate-11.ppm`, `three-filters.ppm`) under `reference/chapter-11/`, chapter 12's (`opacity.ppm`, `plate-12.ppm`, `clip-demo.ppm`) under `reference/chapter-12/`, and chapter 13's (`joins.ppm`, `plate-13.ppm`, `caps.ppm`) under `reference/chapter-13/`.

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
- Chapter 9 adds premultiplied pixels and compositing. `Pixel`/`pixel(r, g, b, a)` stores colour already scaled by alpha; `from_color`/`opaque` premultiply, `pixel_color` un-premultiplies (reading black for a fully transparent pixel), `pixel_alpha` reads the alpha, `CLEAR` is the fully-transparent pixel, `lerp_pixel` blends two pixels straight down their channels. `over(src, dst)` is source-over; `coefficients(op, a_s, a_d)` is the Porter-Duff `(Fa, Fb)` table for the twelve named operators, and `composite(op, src, dst)` applies them. `blend(mode, src, dst)` is source-over with the overlap passed through `blend_color(mode, backdrop, source)`, which dispatches to the twelve separable per-channel modes or, for `"hue"`/`"saturation"`/`"color"`/`"luminosity"`, to `_lum`/`_sat`/`_clip_color`/`_set_lum`/`_set_sat` (the standard `Lum`/`Sat`/`ClipColor`/`SetLum`/`SetSat` compositing-spec helpers). `layer(w, h)` is a buffer of premultiplied pixels; `paint_shape` paints a colour into one through a coverage buffer (chapter 2's `paint_through`, but landing on a layer instead of paper); `composite_layers` and `flatten_layer` composite two layers and flatten one onto an opaque backing colour. `porter_duff_table`/`plate_09`, `blend_strip`, and `seam` render chapter 9's plates — `seam()` renders at quarter scale (two triangles sharing a main-diagonal edge, `(4, 4)`-`(76, 76)` on an 80×80 canvas) and magnifies by 4 so the one-pixel-wide conflation seam reads clearly.
- Chapter 10 turns paint into a function of position. `Stop`/`stop(offset, color)` and `sample_stops(stops, t)` are the colour-stop table, found by binary search and blended in linear light. `extend(t, mode)` folds an out-of-range parameter back in for `"pad"`/`"repeat"`/`"reflect"`. `linear_gradient`/`linear_t` project a point onto an axis; `radial_gradient`/`radial_t` solve the interpolated-circle quadratic, taking the largest root with a non-negative radius (or `None` if the point is outside every circle in the family — the focal gradient's unreachable cone); `conic_gradient`/`conic_t` take the angle around a center as a fraction of a turn. `solid(color)` and `paint_at(paint, x, y)` round out the `Paint` protocol (a `None` from `radial_t` reads as the last stop, not black). `paint_fill(c, cov, paint)` is `paint_through` with the colour replaced by a `paint_at` sample per pixel. `three_gradients`/`plate_10` and `extend_strip` render chapter 10's plates (the sunset stop table and the two-stop extend-mode table were reverse-engineered from the reference PPMs — see FEEDBACK.md). `BAYER4`/`dither_threshold`/`to_byte_dithered`/`canvas_to_p6_dithered` add ordered dithering: nudge the scaled light value by the position's 4×4 Bayer-matrix threshold before the floor.
- Chapter 11 adds images and resampling. `Image`/`image(w, h, pixels)` is a flat, row-major grid of premultiplied pixels; `read_image(ppm)` parses a P6 PPM, decoding each byte from sRGB to linear light and storing it opaque. `image_texel(img, ix, iy, extend)` reads one texel with an out-of-range index folded back by `"clamp"`/`"repeat"`/`"reflect"` (a private `_wrap_index` helper). `sample_nearest` floors straight to a texel (no half-pixel offset — flooring the raw coordinate already finds the cell the point falls in); `sample_bilinear` and `sample_bicubic` work in texel-centre space (source coordinate minus 0.5) and blend with `lerp_pixel` / Catmull-Rom weights from `catmull(t)`. `image_paint(img, m, filter, extend)` is a `Paint` (dispatched in `paint_at`) that walks a device point back through `inverse(m)` before sampling — the reason resampling has to walk destination pixels, not source ones. `downsample(img)` box-averages a 2x2 block of premultiplied channels; `mip_chain(img)` halves down to a single pixel; `mip_level_for(scale)` is `max(0, floor(log2(1/scale)))`. `sprite()`/`two_filters()`/`plate_11()`/`three_filters()` render chapter 11's plates — the 8x8 sprite is built as a canvas and round-tripped through `canvas_to_p6`/`read_image` so the round trip is real.
- Chapter 12 adds clipping, soft masks, and groups, reusing chapter 2's coverage buffer and chapter 9's layers almost unchanged. `multiply_coverage(a, b)` clips one coverage buffer by another, cell by cell; `full_clip(w, h)` is coverage 1 everywhere (a no-op clip); `clip_path(p, rule, w, h)` is only `fill_path` under a different name, and `clip_rect` builds a rectangle path and clips to it. `soft_mask(cx, cy, r, w, h)` is a linear radial falloff, `clamp(1 - distance/r)`. `set_layer_pixel`/`layer_pixel` read and write a layer's premultiplied pixels directly; `push_group(w, h)` is `layer(w, h)`; `paint_into(lyr, cov, color, opacity)` paints through a coverage buffer scaled by an overall opacity and returns the layer; `scale_opacity(lyr, opacity)` scales every premultiplied channel (rgb and alpha alike); `pop_group_with_opacity(group, base, opacity)` fades the whole group once with `scale_opacity` and composites it over `base` with `composite_layers("src-over", ...)`, which is why a group's opacity resolves its own internal overlaps before fading, unlike applying opacity to each child. `opacity_plate()`/`plate_12()` render the group-opacity plate (`per_child()` at 50% each vs. `group_opacity()` opaque-then-faded); `clip_demo()` clips a `unit_star()` (radius 60, centred in a 150x150 panel) to a 45-radius circle on the left and a 70-radius soft mask on the right — the star radius, clip radius, mask radius and centre were reverse-engineered from the reference PPM (see FEEDBACK.md), since the chapter gives no pseudocode for this render.
- Chapter 13 turns a stroke into a fill: `stroke_to_path(path, width, cap, join, miter_limit)` builds, for each subpath, a rectangle per segment (`_seg_rect`), a join wedge per interior vertex (`_join_shape`, `"miter"`/`"round"`/`"bevel"`), and a cap shape per open end (`_cap_shape`, `"butt"`/`"round"`/`"square"`) — all as subpaths of one output path, meant to be filled `"nonzero"` with chapter 7's `fill_path`; there is no new rasterizer. `miter_length(d_in, d_out, h)` is the closed form `h / sin(theta / 2)`, `theta` the interior angle between the incoming direction reversed and the outgoing direction; the join construction itself finds the miter tip by intersecting the two offset edges and falls back to a bevel when that tip's distance from the vertex exceeds `miter_limit * h`. Degenerate inputs are handled explicitly: `_dedupe_points` drops consecutive duplicate points before any direction is computed (the division-by-zero the chapter warns about), and a subpath left with a single point is a dot — a filled disc for a round cap, a square for a square cap, nothing for butt. `chevron()` is the plate's three-point V, used to compare join styles on the same corner. `joins_plate()`/`plate_13()`/`caps_demo()` render chapter 13's plates, each panel a gray `fill_path` of the generated outline with the outline itself redrawn over it in magenta via chapter 3's `line_wu` (which takes integer endpoints, so the outline's coordinates are rounded with `round_half_up` first).
- All geometry calculations use floating-point coordinates
- Antialiasing uses 8×8 supersampling (64 samples per pixel)
- P6 binary PPM files are used for efficiency
- Matrix operations use exact arithmetic with component-wise tolerance comparison (0.0001)
- Transforms are composed in reverse order: C * B * A applies A first, then B, then C
- The Gherkin test harness (`test_runner.py`) compares lists and tuples element-wise with the usual 0.0001 tolerance, recursively, so a list of `(x, direction)` crossings or `(x0, x1)` spans compares each float with tolerance rather than falling back to Python's exact `==` (see Feedback, chapter 6, for why this needed fixing).
