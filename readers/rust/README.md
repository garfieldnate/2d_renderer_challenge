# The 2D Renderer Challenge — Rust

Chapters 1 (`The Canvas and the Color`) through 12 (`Clipping, Masks and
Groups`), stdlib only.

## Build, test, render

```
cargo test --release   # every scenario in features/, chapters 1-12
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
  sixteen blend modes, layers, paint servers (solid, three gradients,
  images), ordered dithering, resampling filters, mip pyramids, clips,
  soft masks, groups, and the chapter's named figures/plates.
- `src/bin/render_all.rs` — renders every figure/plate to `out/`.
- `tests/*.rs` — one test file per `features/*.feature` file (Gherkin
  scenarios translated 1:1 into `#[test]` functions; outlines expanded per
  row).
- `reference/chapter-0{1..9}/*.ppm` and `reference/chapter-{10,11,12}/*.ppm`
  — the book's reference images, compared against with
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

## Chapter 11 notes

`Image` is `{ width, height, px: Vec<Pixel> }`, premultiplied linear
light like chapter 9's `Layer`. `read_image` decodes every byte from sRGB
and stores it opaque; `image_texel` folds an out-of-range index back in
with `wrap_index` (`"clamp"`/`"repeat"`/`"reflect"`, one function shared
by both axes). `sample_nearest` is a plain `floor` with no offset;
`sample_bilinear`/`sample_bicubic` shift the source coordinate back by
0.5 into texel-centre space first, then blend 4 or 16 neighbours
(`catmull` gives the 4 Catmull-Rom weights, reused by both the horizontal
and vertical pass of the bicubic sum). All three samplers are exposed at
a fixed `"clamp"` extend for the scenarios that call them with only
`(img, sx, sy)`; `image_paint` is the general form, taking its own
`filter` and `extend`, and joins `Paint` as a fifth variant that stores
`inverse(m)` up front the same way `transformed` does for a `Shape`.
`downsample` box-averages a 2x2 block through `image_texel(..., "clamp")`
so an odd edge just repeats its last texel; `mip_chain` halves down to
1x1, `mip_level_for` is `floor(-log2(scale))` clamped at 0 for a scale of
1 or more. `sprite()` builds its 8x8 grid as a `Canvas`, round-trips it
through `canvas_to_p6`/`read_image` (the chapter's own point about the
PPM writer running backwards), and `two_filters`/`three_filters`/
`plate_11` all diff 0 against `reference/chapter-11/` — not merely
within tolerance.

## Chapter 12 notes

Clipping needed no new rasterizer: `multiply_coverage` is a cell-by-cell
product of two `CoverageBuffer`s, `full_clip` is all 1.0, and `clip_rect`/
`clip_path` are `fill_path` under new names (a four-cornered `polygon`
for the rectangle). `soft_mask` is one `sqrt` and a `clamp` — coverage
`1 - distance/r`, floored at 0 — so a clip and a mask share the exact
same multiplication, just with softer numbers. `layer_pixel`/
`set_layer_pixel` give `Layer` the accessor `Canvas` already had.
`push_group` is `layer` under this chapter's name; `paint_into` returns a
*new* layer (`over(source, existing)` per pixel) rather than mutating in
place, so nesting calls reads left to right the way the feature file
writes it; `scale_opacity` multiplies every premultiplied channel,
including alpha, by one number; `pop_group_with_opacity` is
`scale_opacity` then one `composite_layers("src-over", ...)` — flatten
first, fade second, which is the entire reason a group's opacity differs
from fading each child. `clip_demo()` has no pseudocode or JS source in
the chapter (like chapter 7's `soft_square`/`star_exact`): its geometry
was reverse-engineered from the reference PPM alone — see FEEDBACK.md for
how. It turned out to be chapter 5's star (`unit_star()` placed by
`translation(75, 75) * scaling(60, 60)`) clipped by a circle of radius 45
on the left and a `soft_mask` of radius 70 on the right, both centred on
the star's own centre; `opacity_plate`/`plate_12`/`clip_demo` all diff 0
against `reference/chapter-12/`.

## Mutation testing (chapters 11-12)

Six more deliberate bugs, tested and reverted: dropping the half-pixel
offset in `bilinear_at` (caught by the identity-transform scenario),
sampling through `m` instead of `inverse(m)` in `image_paint` (caught by
both the translated-image and doubled-image scenarios), wrong Catmull-Rom
weights with the linear term dropped (caught by the weights scenario
directly, and by `three_filters` against its reference), `multiply_coverage`
using `max` instead of a product (caught immediately — three of the four
clip scenarios), a hard 0/1 step in `soft_mask` instead of the linear
falloff (caught by both mask scenarios), and group opacity applied to
each child instead of once at pop time (not caught by `groups.rs`, which
exercises `paint_into`/`pop_group_with_opacity` directly and was
untouched by this mutation, but caught hard by every `plate_12.rs`
scenario once the render itself was mutated to make that mistake).

One mutation did **not** get caught by anything: unpremultiplying before
averaging in `downsample` (average straight color, then remultiply by the
averaged alpha) survived every single test, chapters 1-12, because every
`Image` scenario in this book — the 2x2 test fixture, the 8x8 sprite —
uses fully opaque texels. With alpha exactly 1 everywhere, straight and
premultiplied colour are numerically identical, so the bug that chapter 9
went out of its way to explain (averaging straight drags a transparent
pixel's stored colour into the result) has no data in chapter 11 where it
could show up. See FEEDBACK.md.
