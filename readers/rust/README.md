# The 2D Renderer Challenge — Rust

Chapters 1 (`The Canvas and the Color`) through 10 (`Paint Servers and
Gradients`), stdlib only.

## Build, test, render

```
cargo test --release   # every scenario in features/, chapters 1-10
cargo run --release --bin render_all   # writes all renders (P3 + P6) to out/
```

That's it — `cargo build` alone also works if you just want the library to compile.

## Layout

- `src/lib.rs` — the renderer: colors, canvas, sRGB, P3/P6 PPM, shapes,
  coverage buffers, `magnify`, `paint_through`, Bresenham's and Wu's line
  algorithms, `thick_line`, tuples, matrices and transforms, paths and
  winding numbers, the classical scanline sweep, the analytic
  (accumulator-based) exact fill, Bezier curves and flattening, the SVG
  elliptical arc, premultiplied pixels, Porter-Duff compositing and the
  sixteen blend modes, layers, paint servers (solid + three gradients),
  ordered dithering, and the chapter's named figures/plates.
- `src/bin/render_all.rs` — renders every figure/plate to `out/`.
- `tests/*.rs` — one test file per `features/*.feature` file (Gherkin
  scenarios translated 1:1 into `#[test]` functions; outlines expanded per
  row).
- `reference/chapter-0{1..9}/*.ppm` and `reference/chapter-10/*.ppm` —
  the book's reference images, compared against with
  `max_channel_difference`.

`--release` matters here: chapter 2's brute-force `coverage()` samples 64
points per pixel per disc, chapter 3's `thick_line` reuses that same
rasterizer for every ray of the fan (twelve 160×160 rasterizations at 64
samples a pixel), and chapter 5's plate rasterizes the star by coverage
twice — comfortably fast in release, noticeably slower in debug.

## Chapter 3 notes

`Shape` gained one variant, `Intersection`, for `thick_line`: four
half-plane parameters (not four `Shape`s) held in a fixed-size array
rather than a `Vec`. (Chapter 4's `Union(Vec<Shape>)` and chapter 5's
`Filled(Box<Path>, Rule)` mean `Shape` is `Clone` but no longer `Copy` —
existing code that used to rely on `Shape: Copy` now borrows a `&Shape`
instead, which turned out to be less friction than cloning throughout.)

## Chapter 5 notes

`Path` is a `Vec<Subpath>`, each `Subpath` a `Vec<Tuple>` plus a `closed`
flag. `edges(p)` always treats every subpath as closed — the flag only
affects where the *next* `line_to` after a `close` starts. `winding_at`
and `crossings` both use the half-open rule (`a.y <= y < b.y` or the
reverse) so a vertex on the ray counts once. `filled(p, rule)` is a new
`Shape` variant so chapter 2's `rasterize`/`rasterize_centers` machinery
draws any path unchanged.

## Chapter 6 notes

`edge_table(p)` reshapes `edges(p)` into non-horizontal `Edge`s
(`y_top`, `y_bottom`, `x_top`, `slope`, `direction`), sorted by `y_top`
then `x_top`. `fill_path_aliased` sweeps the sorted table with an active
edge list — no full rescan per row — and its output is byte-for-byte the
same coverage buffer as chapter 5's `rasterize_centers(filled(p, rule),
w, h)`, checked directly with `max_coverage_difference`. `transform_path`
gives `Path` the same "transform the points, then ask" treatment chapter
4 gave `Shape`.

## Chapter 7 notes

`Accumulator` holds two `Vec<f64>` (`area`, `cover`), one entry per cell.
`add_cell` folds a deposit left of the buffer onto column 0 as pure cover
and drops one right of it; `accumulate_row` splits a piece across the
cells it spans, weighting each cell's area by the trapezoid midpoint
rule; `accumulate` clips a whole edge to the rows it crosses (clamped to
the buffer) and hands each piece to `accumulate_row`, with a horizontal
edge dropped outright. `resolve` sweeps each row left to right, turning
the running cover sum plus each cell's own area into a winding number,
and `apply_rule` folds that (possibly fractional) number into coverage
for `"nonzero"` (`min(1, |w|)`) or `"evenodd"` (the `|w|` triangle wave).
`fill_path` is `accumulator` + `accumulate` over every edge + `resolve`,
and replaces `fill_path_aliased` as the fill from here on (kept only for
chapter 6's own scenarios and the two direct A/B comparisons this
chapter's scenarios make against it). `polygon_area` is the shoelace
formula, used to check the fill's ink against ground truth rather than
against another rasterizer.

`soft_square()` and `star_exact()` and `spiral_smooth()` are named in
`chapter-07.html`'s prose and scenarios but, unlike `needles()`, `rays()`
and `sunburst()`, ship with no pseudocode or figure source in the
chapter. Their geometry (canvas size, magnification, panel layout, ink
choice) was reverse-engineered from the pinned pixel values and the
reference PPMs themselves — see FEEDBACK.md.

## Chapter 8 notes

`Curve` is a `Vec<Tuple>` of 3 (`quadratic`) or 4 (`cubic`) control
points. `point_at`/`split_at` share one `de_casteljau` construction;
`derivative` evaluates the hodograph (control points scaled by degree,
one degree lower) at `t`, so it's a vector (`w = 0`) automatically
through `Tuple` subtraction. `curve_bounds` finds the derivative's roots
in `(0, 1)` directly by degree (linear for a quadratic's derivative,
the quadratic formula for a cubic's) rather than a generic numeric
solver, since those are the only two degrees the book ever has.
`flatten` recurses via `split_at(c, 0.5)` until `flatness(c) <=
tolerance`; `flatten_into_path` appends to a `Path` with `line_to`,
skipping the curve's own first point when the pen is already there.
`arc`/`arc_point` are a direct port of the SVG spec's endpoint-to-center
construction (`Option<Arc>`, `None` for a degenerate arc), including the
radius-growing correction and the large_arc/sweep angle adjustment.
`derivative`, `curve_bounds`, `polyline_length` and `flatten_length` have
no JS reference source in the chapter either (only prose and scenarios);
their algorithms are standard Bezier math, not lifted from the book.

## Chapter 9 notes

`Pixel` is premultiplied (`r`, `g`, `b` each already scaled by `a`);
`from_color`/`opaque`/`pixel_color`/`pixel_alpha`/`CLEAR`/`lerp_pixel` are
the whole of §9.1. `over` and `composite` share one shape (`Fa * src + Fb
* dst`, alpha included); `composite`'s twelve operators are a lookup
table of `(Fa, Fb)` pairs (`porter_duff_coeffs`) keyed by the operator's
own name string, matching the book's table exactly. The sixteen blend
modes split into `separable_blend` (a `fn(f64, f64) -> f64` per mode,
applied channel by channel) and `nonseparable_blend` (`hue`/
`saturation`/`color`/`luminosity`, each one line once `lum`, `sat`,
`set_lum`, `set_sat` and `clip_color` exist); `blend_color` picks between
them and `blend` is source-over with the overlap run through it. `Layer`
is a flat `Vec<Pixel>` (public field, no accessor ceremony — nothing
outside this file needs one); `paint_shape` is `paint_through`'s
premultiplying twin, `composite_layers`/`blend_layers` apply an operator
or mode pixel by pixel, and `flatten_layer` is `over` against an opaque
background, un-premultiplied back into a `Canvas`. `porter_duff_table`,
`blend_strip` and `seam` were built to match the chapter's own reference
JS byte for byte (tile size, square/circle geometry, triangle
coordinates, magnification factors) — every one of `out/*.ppm` diffs 0
against `reference/chapter-09/`, not merely within tolerance. `seam`
reproduces the conflation bug on purpose (two independently antialiased
triangles composited src-over in sequence): "fixing" it by merging their
coverage before painting is exactly the mutation this project's testing
caught (see FEEDBACK.md).

## Chapter 10 notes

`Stop`/`stop`/`sample_stops` are the table shared by all three
gradients; `sample_stops` binary-searches for the bracketing pair rather
than scanning linearly. `extend` is three one-line branches (`pad`
clamps, `repeat` takes the fractional part, `reflect` folds the absolute
value's mod-2 back under 1). `Paint` is an enum (`Solid`, `Linear`,
`Radial`, `Conic`); `linear_t`/`radial_t`/`conic_t` each pattern-match
their own variant (and panic on a mismatch, which no scenario ever
triggers). `radial_t` returns `Option<f64>`, checking the quadratic's two
roots in the order the book's own reference does (not sorted by size —
whichever root has a non-negative interpolated radius wins), so
`paint_at`'s focal-cone case (`None` maps to the last stop, not black)
matches exactly. `paint_fill` is `paint_through` with the color argument
replaced by a `paint_at` sample per pixel, forced through `mix_with(...,
true)` the same way `paint_through` always was. `to_byte` is
`channel_to_byte` under its chapter-10 name; `BAYER4`/`dither_threshold`/
`to_byte_dithered`/`canvas_to_p6_dithered` are ordered dithering, floor
instead of round-to-nearest with the Bayer nudge added first. All three
named renders (`three_gradients`/`plate_10` — identical by the book's own
pseudocode — and `extend_strip`) diff 0 against `reference/chapter-10/`.

## Mutation testing (chapters 9-10)

Eight deliberate bugs were introduced one at a time, tested, and
reverted: a swapped `src-over` coefficient (using `dst`'s alpha instead
of `src`'s), blending in encoded instead of linear space, a wrong `lum`
weighting (equal thirds instead of 0.3/0.59/0.11), "fixing" the chapter 9
conflation seam by merging coverage before painting, always taking the
first root of the radial quadratic instead of checking eligibility,
`reflect` implemented as `repeat`, the dither threshold omitted, and the
focal gradient's unreachable cone painted black instead of the last
stop. Every one of the eight was caught by at least one scenario — none
survived. Details, including which scenario caught each, are in
FEEDBACK.md.
