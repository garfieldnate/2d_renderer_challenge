# The 2D Renderer Challenge — Rust

Chapters 1 (`The Canvas and the Color`) through 25 (`The Raster Editor
Detour`), plus the epilogue (`One Last Picture`), stdlib only except for one
vendored crate: chapter 20 reads XML with
`roxmltree` 0.20 (source under `vendor/`, `.cargo/config.toml` points cargo
at it, so everything builds with `--offline` and no network). Chapter 16 needed a small hand-written JSON reader for the font
file (`reference/chapter-16/roboto.json`); no crate was added for it. Chapter
19 reuses that same reader for `reference/chapter-19/dejavu-arabic.json`,
which carries four more optional sections (`kern`/`ligatures` since chapter
18, `joining`/`forms`/`marks`/`anchors` new in chapter 19). Chapter 22 needs
exact arithmetic beyond 64 bits in two places (a crossing's numerator, and
comparing two crossings' exact positions in the Bentley-Ottmann sweep);
Rust's `i128` covers both, still stdlib, still no new dependency. Chapter 25's
`canvas_to_bmp8`/`read_bmp8` are a hand-written 8-bit indexed BMP reader and
writer, again no new dependency.

## Build, test, render

```
cargo test --release --offline   # every scenario in features/, chapters 1-25 and the epilogue
cargo run --release --offline --bin render_all   # writes all renders (P3 + P6) to out/,
                                                 # then prints chapter 21's work table
cargo run --release --offline --example span_bench   # composite_span vs composite_span4
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
  soft masks, groups, `stroke_to_path` and its joins/caps/miter, curve
  offsetting and curve stroking (chapter 14), dashing (chapter 15), a
  hand-written JSON reader plus glyphs/contours/composites/the text matrix
  (chapter 16), quarter-pixel bitmaps/the glyph cache and atlas/stem
  darkening/LCD subpixel rendering (chapter 17), laying out a run of text —
  advances/kerning/greedy line breaking/the four alignments/`draw_run` as
  the seam into chapter 17 (chapter 18), and a small shaping pipeline —
  itemizing by script, a glyph buffer with clusters, ligature substitution,
  Arabic joining forms, mark-to-base attachment, and positioning in either
  direction (chapter 19), plus every chapter's named figures/plates.
  Chapter 20 adds an SVG front end (an owned `Element` tree over
  roxmltree, the number/path-data/transform/colour/style parsers, basic
  shapes, `view_box_matrix`, paint servers via `transformed_paint`, clips,
  group opacity and the `render_svg` walker); chapter 21 adds work
  counters (`Stats`), bounded fills (`fill_bounds`/`fill_path_bounded`/
  `draw_window`), 16-pixel tiles over a sparse accumulator
  (`classify_tiles`/`fill_path_tiled`/`draw_tiled`), the scalar and
  four-wide span compositors, and `render_svg_with(.., mode, ..)`.
  Chapter 22 adds the grid (`grid`/`snap_point`/`orient`/`lex_less`),
  `Seg`/`seg`/`path_segments`, `meet`/`crossing_point` (exact, via `i128`),
  three interchangeable crossing finders (`find_splits(.., "brute" |
  "sweep" | "bentley-ottmann", ..)`, the last a real Bentley-Ottmann sweep
  with an ordered status and exact fractional events), `merge_segments`/
  `split_segments`, `winding_beside`/`inside_rule`/`op_inside`/
  `keep_edges`, `stitch` (furthest-right turns via an exact half-plus-cross
  angular order), and `combine`/`simplify` — the whole boolean pipeline —
  plus `struck_line`/`struck_segments` (the benchmark) and the seal.
  Chapter 23 adds exact fields for primitives (`sd_circle`/
  `distance_to_segment`/`sd_box`/`sd_rounded_box`/`sd_polygon`) and curves
  (`solve_cubic`, `distance_to_quadratic`, `distance_to_cubic`/
  `nearest_t_cubic` by Newton's method from nine seeds, `brute_distance`
  as ground truth), a `Field` (`field`/`field_of`/`field_at`/
  `field_range`/`field_coverage`), the one-line operations
  (`field_offset`/`field_stroke`/`field_union`/`field_intersection`/
  `field_difference`/`field_xor`), `smooth_min`/`field_smooth_union`, the
  Felzenszwalb-Huttenlocher distance transform (`edt_1d`/
  `distance_transform`/`field_from_coverage`), and glyph atlases
  (`bake_sdf`/`bake_msdf`/`bake_mtsdf`, `color_edges`/`pseudo_distance` for
  the multi-channel bake, `sample_field`/`median3`/`draw_baked`/
  `draw_effect`). Chapter 24 adds stencil-and-cover (`Stencil`/
  `stencil_buffer`/`cover`), Loop-Blinn curve stenciling without flattening
  (`loop_blinn_uv`/`inside_curve`/`loop_blinn_stencil`/`glyph_stencil`),
  multisampling (`sample_pattern`/`msaa_coverage`), the observation that a
  `Paint` is already a shader (`shade_tile`), and a four-stage compute
  pipeline (`encode_svg`/`Scene`/`flatten_stage`/`bin_stage`/`coarse_stage`/
  `fine_tile`/`run_pipeline`/`render_svg_gpu`) whose tiles run in
  `lcg_shuffle` order and land byte-identical to chapter 20's, plus a
  two-block-deep tile stack (`STACK_DEPTH`/`FineStats`) that counts spills
  instead of allocating slow memory. Chapter 25 adds a round brush
  (`Brush`/`dab_coverage`/`stamp_positions`/`stroke_mask`/`paint_stroke`),
  the scanline flood fill (`flood_mask`/`bucket`/`anti_alias_mask`),
  Heckbert's median cut and the two dithers (`median_cut`/`threshold`/
  `ordered_dither`/`error_diffuse`), a hand-written 8-bit indexed BMP
  reader and writer (`canvas_to_bmp8`/`read_bmp8`), and selection/undo
  (`marquee`/`add_selection`/`subtract_selection`/`intersect_selection`/
  `feather`/`float_selection`/`History`/`history_fill`/`undo`/`redo`). The
  epilogue adds `book_cover()` (chapter 20's `render_svg` of
  `reference/epilogue/cover.svg`, plus the title and subtitle laid out by
  chapter 18 and drawn with chapter 18's `draw_run`), `glow_of` (the bonus
  glow's falloff), and `book_cover_glow()` (the same cover with a
  `bake_mtsdf`/`draw_effect` glow under the title, for readers who did
  chapter 23).
- `src/bin/render_all.rs` — renders every figure/plate to `out/`, plus the
  epilogue's `cover-art.ppm`, `cover.ppm` and `cover-glow.ppm`.
- `examples/span_bench.rs` — times chapter 21's two span compositors.
- `tests/*.rs` — one test file per `features/*.feature` file (Gherkin
  scenarios translated 1:1 into `#[test]` functions; outlines expanded per
  row).
- `reference/chapter-0{1..9}/*.ppm`, `reference/chapter-{10..15}/*.ppm`,
  `reference/chapter-16/roboto.json` (the font data),
  `reference/chapter-19/dejavu-arabic.json` (chapter 19's Arabic font data)
  and `reference/chapter-{16..19}/*.ppm` — the book's reference images (and,
  for 16 on, its fonts), compared against with `max_channel_difference`. Note:
  `out/two-strokes.ppm`, `fold.ppm`, `offsets.ppm` and `plate-14.ppm`
  (chapter 14) and `even-marks.ppm`, `dash-strip.ppm`, `spiral-dashes.ppm`
  and `plate-15.ppm` (chapter 15) all land in the same flat `out/`
  directory as every earlier chapter's renders. Chapter 15's spiral render
  used to be named `spiral.ppm` and collide with chapter 6's `spiral()`
  render of the same name; it's now `spiral-dashes.ppm`. Chapters 16 and 17
  add `glyph.ppm`, `plate-16.ppm`, `composite.ppm`, `sizes.ppm`, `flip.ppm`,
  `subpixels.ppm`, `smoothing.ppm`, `lcd.ppm` and `plate-17.ppm`. Chapter 18
  adds `kerning.ppm`, `breaking.ppm`, `drift.ppm` and `plate-18.ppm`; chapter
  19 adds `ligature.ppm`, `forms.ppm`, `word.ppm`, `mixed.ppm` and
  `plate-19.ppm`. Chapter 22 adds `plate-22.ppm` and `seal.ppm`; chapter 23
  adds `primitive-fields.ppm`, `error-map.ppm`, `fields-vs-paths.ppm`,
  `fillets.ppm`, `transform-demo.ppm`, `atlas-corners.ppm`,
  `trap-shrink.ppm`, `plate-23.ppm` and `title.ppm`. Chapter 24 adds
  `plate-24.ppm`, `msaa-demo.ppm`, `spill-map.ppm` and `tiger-assembly.ppm`;
  chapter 25 adds `plate-25.ppm`, `dither-strip.ppm`, `halo-demo.ppm`,
  `brush-demo.ppm` and `paint-by-script.ppm`. None of these collide
  with an earlier chapter's names.
  Every render is checked against its own `reference/chapter-NN/` directory
  by the tests regardless.
- `reference/epilogue/cover.svg`, `cover-art.ppm`, `cover.ppm` and
  `cover-glow.ppm` — the epilogue's document and its three renders
  (`render_svg` of the document alone, `book_cover()`, and
  `book_cover_glow()`), written to `out/` under the same names.

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

## Chapter 13 notes

`stroke_to_path(path, width, cap, join, miter_limit)` turns any `Path`
into a fillable outline: one rectangle per segment (`seg_rect`), one
join wedge per interior vertex (`join_shape` — bevel a triangle, round
an arc, miter the intersection of the two offset edges, falling back to
a bevel past `miter_limit`), one cap shape per open end (`cap_shape` —
`butt` emits nothing, `square` a rectangle extended by half the width,
`round` a semicircle), all as closed subpaths of one `Path`. There's no
new rasterizer — `fill_path(outline, "nonzero", w, h)` from chapter 7 is
the whole story, and the overlaps on the inside of every turn, wound
twice, disappear into the fill for free. Consecutive duplicate points
are dropped first (`dedupe_points`) so a doubled point never becomes a
zero-length segment's undefined direction; a subpath left with a single
point becomes a disc (round cap), a square (square cap) or nothing
(butt cap) instead of dividing by zero. `miter_length(d_in, d_out, h)` is
`h / sin(theta / 2)`, `theta` the interior angle between the *reversed*
incoming direction and the outgoing one — this matched both the standalone
closed-form scenario and the chevron's actual miter tip distance exactly,
confirming there's one formula, not two. `chevron()` is the plate's V:
three points, `(30, 40)`, `(80, 120)`, `(130, 40)`, never closed.
`joins_plate()`/`plate_13()`/`caps_demo()` all diff 0 against
`reference/chapter-13/` — not merely within tolerance.

## Mutation testing (chapter 13)

Five deliberate bugs, tested and reverted: flipping which side of a turn
is "outer" in `join_shape` (not caught by the join-style or miter-length
unit scenarios, which only pin point *counts* — caught by the miter's
own tip-position scenario, the round join's point count once the arc
sweeps the wrong way round, and both plate reference diffs), a miter
that never falls back to a bevel regardless of `miter_limit` (caught
immediately by the miter-limit scenario), offsetting by the full width
instead of half in `stroke_to_path` (caught immediately — every
degenerate-case scenario, since even a single-point dot's bounds
double), a round cap swept through the wrong semicircle (not caught by
any unit scenario — nothing pins a cap's own geometry directly — caught
by the caps render's reference diff), and skipping `dedupe_points`
entirely (caught immediately: a zero-length segment's direction is
`0/0`, and the duplicate-points scenario's subpath count and point
values come out wrong once NaNs propagate). All five were caught by at
least one scenario; none survived silently. The two that only the
plate/caps renders caught (outer side, cap sweep direction) are the
strongest argument in this project for pinning `max_channel_difference`
on every render rather than trusting point-count scenarios alone — a
join or cap's precise geometry is only checked end to end there.

### Chapter 13 catch-up (round 2)

Two more scenarios landed in `features/chapter13-stroke.feature` after the
round above: `polygon_area` now returns a *signed* area (it used to
`.abs()` it) so a stroke's pieces can be checked for consistent winding,
and the round join sweeps the outer gap the short way round instead of
picking a direction from the turn's own sign. `polygon_area` no longer
taking the absolute value is safe for chapter 7's own scenarios only
because every shape they use (`polygon`, `circle_path`, `star`,
`needle_path`) already happens to be wound clockwise on screen, which is
what makes the signed value positive there too; that's a coincidence of
which way those shapes were authored, not a rule, and is worth knowing if
a future chapter adds a counterclockwise-wound fixture to chapter 7's
tests. `ang_between(from, to)` is the shared "shortest way round" helper
`join_shape`'s round branch now uses; `u_turn()` is the nine-point hairpin
semicircle the new self-overlap scenario strokes 40 wide. All of chapters
1-13 are green again after the fix (`stroke.rs` fully rewritten to match
the current feature file; `miter.rs`, `degenerate.rs` and `plate_13.rs`
were already in sync and needed no changes, though `plate_13.rs`'s render
comparisons only started passing once the join fix landed).

## Chapter 14 notes

`tangent_at`/`normal_at`/`offset_point` are one small function apiece:
`tangent_at` normalizes `derivative`, nudging the parameter `0.0001`
further into the curve first (`live_t`) when the derivative is exactly
zero there (a handle sitting on its own anchor); `normal_at` is chapter
13's `perp` on the tangent; `offset_point` steps `d` along it. `curvature`
is `cross(v, a) / |v|^3` with `a` a new `second_derivative` (the same
degree-reduction trick as `derivative`, run twice, so it needs no
quadratic/cubic special case). `cusps(c, d)` finds where `1 - curvature *
d` changes sign by sampling 64 parameters and bisecting 40 times between
any pair that disagree. `fit_offset` solves one cubic through the two end
offset points and the curve's own end tangents whose midpoint lands on
the true offset at `t = 0.5`, falling back to a third of the chord per
handle when the end tangents are parallel; `offset_error` is the worst
miss over 17 matched parameters, and `distance_to_curve` (65 samples, 32
rounds of ternary search) is the honest measure the whole thing is
checked against. `offset_curve` splits at every cusp first (so no piece
contains a stall) and then fits-and-halves each piece to tolerance,
capped at 16 halvings; `sub_curve(c, t0, t1)` is two `split_at` calls.
`stroke_curve_to_path` builds one closed outline directly from the `+h`
and `-h` offsets (flattened) plus the two end caps — no new rasterizer,
same `fill_path` nonzero as every chapter since 7 — and is deliberately
*not* run through chapter 13's winding-orientation fix (`push_closed_subpath`),
because it only ever produces one subpath and the scenario pins its first
and last points by construction (the `+h` offset's start, the `-h`
offset's start), which a blanket reorientation would silently break.
`flatten_then_stroke` is the old way (flatten, then chapter 13 with round
joins) kept around only so the two can be compared. `hairpin()` and
`arch()` are the plate's two curves; `offsets_plate` reuses chapter 13's
`stroke_to_path` + `fill_path` to draw every hairline (an offset curve is
just another path to stroke thin and fill), which is the same trick
`two_strokes`/`fold_demo`/`spiral_dashes` (chapter 15) all lean on.

**A rounding-mode bug, then a correction.** `two_strokes()` and
`fold_demo()` once failed `max_channel_difference` by a handful of pixels
(up to 82 out of 255) clustered at the exact symmetry axis of the
hairpin's self-crossing fold: the hairpin and its offsets are symmetric
about `x = 80`, so the offset construction lands a vertex at the *exact*
half-integer coordinate `(80.0, 42.5)`, and Rust's `f64::round()` (ties
away from zero, `42.5 -> 43`) disagreed with the reference at that one
row. A prior round of this catch-up chased that down to a `pyround`
(ties-to-even) helper and added `round_half_to_even` for the two
`line_wu`-facing panel functions (chapter 13's `stroke_panel` and chapter
14's `outline_panel_rule`). The book has since settled the question the
other way: chapter 13 §13.5's pseudo-code and chapter 14 §14.5 both now
say outline coordinates round to the nearest pixel *halves up* — the same
`floor(v + 0.5)` rule chapter 1's byte conversion uses — and
`chapter14-stroke.feature` pins `round(42.5) = 43`, `round(-17.5) = -17`
directly (a negative half, which chapter 1 never exercised). That also
exposed a second bug: chapter 1's own `round` was `x.round()`, which ties
away from zero and gives `-17.5 -> -18`, not `-17`. Both are now
`floor(x + 0.5)` in `round`, `round_half_to_even` is gone, and
`stroke_panel` / `outline_panel_rule` both call chapter 1's `round`. See
**Failures** in `FEEDBACK.md` for the full diagnosis.

## Chapter 15 notes

`path_length` sums a path's own segments, adding the closing one only for
a subpath that's actually closed — unlike `edges`, which always treats
every subpath as closed for filling's sake, so it can't be reused here.
`arc_length_table(c, n)` is `n + 1` running chord lengths;
`t_at_length` binary-searches the table and interpolates linearly inside
the one chord that spans the target length (exact, since a chord is
straight); `point_at_length`/`split_at_length` hand that parameter to
chapter 8's `point_at`/`split_at`. `normalize_pattern` is three lines
(reject negative-or-non-positive-sum as "no pattern", double an odd
list). `dash(p, pattern, phase)` is a straight, careful port of the
walk in the chapter's own pseudocode: one pass per subpath (pushing the
subpath's first point onto its own end first, for a closed one, so the
walk crosses the closing segment too), tracking which pattern entry is
current and how much of it is left, taking `min(remaining, segment
left)` steps and flipping on/off exactly when an entry is used up — never
when a segment ends, which is what lets a dash cross a corner without a
seam. The closed-subpath join (last dash absorbs first when both touch
the subpath's start, or the single dash closes into a loop if it *is*
the first) is a small post-pass over that subpath's own slice of dashes,
mirroring the chapter's prose exactly. `dash_count` is just
`subpaths(dash(...)).len()` — the chapter names it but never spells out
a different way to compute it, and none of the pinned numbers suggested
one. `golden_spiral()` is seven quarters, each a cubic with the usual
`0.5522847498` handle constant, flattened into one running open subpath
so the dash walk never resets mid-spiral; `spiral_dashes` draws the
undashed spiral hairline-thin first, then strokes each dash of
`dash(sp, [16, 10], 0)` separately (7 wide, round cap and join) so each
one can take its own ink from a 3-color rotation — the same
one-subpath-at-a-time construction chapter 14 uses for its own hairlines,
via a small `subpath_as_path` helper.

Every chapter-15 render (`even-marks.ppm`, `dash-strip.ppm`,
`spiral.ppm`, `plate-15.ppm`) diffs 0 against `reference/chapter-15/` —
not merely within tolerance.

## Mutation testing (chapters 14-15)

Six deliberate bugs, tested and reverted, three per chapter. All six were
caught; none survived.

- **Chapter 14 — offset normal on the wrong side** (`normal_at` returning
  `-perp(tangent)` instead of `perp(tangent)`): caught immediately and
  everywhere — all five `offset.rs` scenarios fail on the very first
  comparison, since every offset point in the chapter is pinned by exact
  coordinates.
- **Chapter 14 — the cusp condition with the wrong sign** (`cusps`
  testing `1 + curvature * d` instead of `1 - curvature * d`): caught
  directly by both `curvature.rs` cusp scenarios (wrong cusp count and
  wrong cusp parameters on both the quadratic and the cubic).
- **Chapter 14 — an offset outline that doesn't split at cusps**
  (`offset_curve` skipping the `cusps` step entirely, just fitting and
  halving the whole curve): not caught by the two scenarios whose curves
  never reach their stall radius (a gentle offset and the plain
  end-to-end chaining check happen to still come out right, since halving
  alone eventually satisfies `offset_error` even without a cusp split) —
  but caught hard by every scenario that actually folds: the parabola's
  fold-piece-count scenario, and all three `stroke14.rs`/`curve14.rs`
  scenarios built on the hairpin or the folding parabola, which is
  exactly the geometry this feature exists for.
- **Chapter 15 — a dash walk that resets the pattern at every vertex**
  (reinitializing `i`/`remaining`/`on` at the top of each segment's loop
  instead of carrying them across the whole subpath): caught by 5 of 8
  `dash15.rs` scenarios (every corner and phase scenario, since a reset
  makes the pattern start over at each vertex) and 2 of 5 `closed15.rs`
  scenarios.
- **Chapter 15 — the phase applied the wrong way** (walking `-phase` into
  the pattern instead of `phase`): caught by all three phase scenarios in
  `dash15.rs` (the zero-phase and no-phase-given scenarios are unaffected
  by construction, since a phase of 0 negates to 0).
- **Chapter 15 — a closed subpath not walked around its closing segment**
  (skipping the `pts.push(pts[0])` step for a closed subpath): caught by
  all three `closed15.rs` scenarios that actually use a closed shape (the
  square) — the two-open-subpaths scenario is naturally unaffected.

No mutation in this round survived every scenario. The closest calls were
chapter 14's cusp-split removal (silent on 2 of 5 scenarios in its own
feature file) and chapter 15's phase flip (silent on scenarios that don't
exercise a nonzero phase) — both undetected only by scenarios that were
never testing the mutated behavior in the first place, not by a gap in
coverage.

## Chapter 13 catch-up (round 3)

`features/chapter13-degenerate.feature` gained a scenario since the round
above: a closed subpath whose last point duplicates its first (the reader
wrote an explicit line back to the start before calling `close`, which
every glyph contour in chapter 16 does) used to build a zero-length
closing segment on top of the real one, whose direction is `0/0`.
`stroke_to_path` now drops that duplicate last point before building
segments, exactly as `chapter-13.html` §13.2's pseudo-code now spells out
("if closed and pts ends where it began, drop that end too"). `degenerate.rs`
gained the new scenario (a stroked closed square, checked by subpath count
and `polygon_area`); every other chapter 1-15 test was already green and
needed no changes.

## Chapter 16 notes

`load_font` reads the book's JSON schema through a small hand-written
recursive-descent parser (`Json`/`JsonParser`, private to `src/lib.rs`):
objects, arrays, strings, numbers and booleans, nothing more. `Font` holds
`units_per_em`/`ascender`/`descender`/`line_gap`, `cmap` (`HashMap<String,
String>`) and `glyphs` (`HashMap<String, Glyph>`); `Glyph` is `advance` plus
`contours` (`Vec<Vec<(f64, f64, bool)>>`, the on-curve flag) and
`components` (`Vec<Component>`, each a glyph name and a `[f64; 6]`
transform). The on-curve flag is a JSON boolean in the schema, and both the
real font file and the chapter's own hand-written-font scenario write it
that way; `Json::as_flag` also accepts a bare `0`/`1` number as a lenient
fallback, but nothing in `features/` exercises that branch any more (an
earlier draft of the hand-written-font scenario did, before the schema
note in `chapter-16.html` pinned the flag as a boolean).

`implied_points` walks the loop once, pushing a midpoint between every
consecutive off-curve pair (including the wrap from last to first), then
rotates to start on an on-curve point. `contour_curves` turns that into
chapter 8 quadratics, treating two consecutive on-curve points as a
straight edge through their own midpoint. `component_matrix(t)` is
`matrix3(t[0], t[2], t[4], t[1], t[3], t[5], 0, 0, 1)` — TrueType's
`x' = a·x + c·y + dx` read into `matrix3`'s row-by-row constructor.
`glyph_outline` recurses through components, transforming each one's
curves through its own matrix; `glyph_bounds` unions `curve_bounds` (not
the control box) over every quadratic, `(0, 0, 0, 0)` for an empty glyph.

`text_matrix(font, size, x, y)` is `translation(x, y) * scaling(s, -s)`
with `s = size / units_per_em` — the one and only flip, exactly as the
chapter insists. `glyph_path`/`contour_path` transform each quadratic,
flatten it in device space with chapter 8's `flatten_into_path`, and close
each contour into its own subpath; no special-casing was needed for the
"straight edge as a degenerate quadratic" trick since chapter 8's own
Bezier math already treats a control point sitting on the chord as a line.

`glyph_plate`/`plate_16`/`composite_demo`/`sizes`/`flip_trap` are ported
straight from the chapter's own figure JS (visible in `chapter-16.html`'s
embedded `<script>` — see **Prose problems** below): a paint buffer, hairline
outlines via chapter 13's `stroke_to_path` at width 1 (or 1.5 for the
off-curve circles), and small filled squares for on-curve points. All five
chapter 16 renders (`glyph.ppm`, `plate-16.ppm`, `composite.ppm`,
`sizes.ppm`, `flip.ppm`) diff 0 against `reference/chapter-16/` — not
merely within tolerance.

**A bug found and fixed while building `flip_trap`.** The horizontal
baseline hairline was first built with chapter 5's `polygon(&[a, b])` —
which always calls `close()`. A *closed* 2-point subpath doubles back on
itself in `stroke_to_path`: `segs` gets both the forward edge and, because
the subpath is closed, an explicit reverse edge back to the start, so the
line rendered twice as wide (full coverage across two pixel rows instead
of 0.5 coverage split across the two rows straddling it). The fix was
building the line as an *open* two-point path (`move_to`/`line_to`, no
`close`) — the same distinction chapter 13's own `chevron()` (never closed)
and the plate's box outline (`polygon`, closed) already draw, but easy to
blur when reaching for the shortest helper. `max_channel_difference` on
`flip.ppm` caught it immediately (51, not ≤ 1); no unit scenario would
have, since nothing in `chapter16-plate.feature` pins the hairline's own
width directly.

## Chapter 17 notes

`SUBPIXELS = 4`; `subpixel_of(x)` splits `x` into a whole pixel and the
nearest quarter (`floor((x - floor(x)) * 4 + 0.5)`, carrying into the next
whole pixel when that rounds to 4 — including for a negative `x`, which
the scenario pins directly). `Bitmap` is `{ coverage, width, height, left,
top }`; `glyph_bitmap` sizes its buffer from `glyph_bounds` shifted by
`subpixel / 4`, floored/ceilinged outward to whole pixels exactly as
§17.1 describes, and returns a `0×0` bitmap for an empty glyph (`space`)
without going through the general "at least 1 pixel" sizing rule that
every other glyph gets. `paint_bitmap` is chapter 1's `mix_with` under a
new name, looped over the bitmap's own footprint with an explicit bounds
check before touching the canvas (unlike `write_pixel`, `pixel_at` panics
outside its bounds rather than silently ignoring the read, so the check
has to come first here).

`GlyphCache` keys on `(name, size.to_bits(), subpixel)` — `f64` isn't
`Hash`/`Eq`, so the size's bit pattern stands in for it, which is exact
for the identical-`f64`-in, identical-`f64`-out case every scenario uses.
`Atlas` packs shelves, ported straight from `chapter-17.html` §17.2's
`atlas_add` pseudo-code, in the same order: a bitmap wider or taller than
the whole atlas returns `None` immediately, before anything about the
current shelf is touched; only then does a bitmap that doesn't fit the
shelf's *width* close it (`shelf_top += shelf_height; cursor_x = 0;
shelf_height = 0`) and open a fresh one; only then does the height check
against the (possibly just-reset) shelf run, returning `None` if even a
fresh shelf can't fit it; otherwise the bitmap is blit in and the shelf's
`cursor_x`/`shelf_height` are advanced (`shelf_height` growing to fit a
taller bitmap that still fits the shelf's *width*, rather than always
being fixed by the shelf's first bitmap). Checking "can this ever fit"
first is what lets a too-wide bitmap (`40 × 5` against a `32`-wide atlas)
return `None` without disturbing the current shelf at all — a bitmap
added right after lands back on that same shelf (see the
chapter-17-catch-up scenario "A bitmap the atlas can never hold leaves the
shelf alone" in `FEEDBACK.md`). An earlier version of this code
reconstructed shelf packing from the scenario's original seven
`atlas_add` calls alone, before the chapter printed pseudo-code for it,
and used a retry loop that closed the shelf as soon as a bitmap failed to
fit its width — including a too-wide-for-the-atlas bitmap — which gave
the same answers on every scenario that existed then but failed the
catch-up's two new ones (see **Catch-up** in `FEEDBACK.md`).

`embolden` grows the glyph's own bounds by a pixel all round, fills the
glyph normally, strokes its outline (chapter 13's `stroke_to_path`, round
join and cap, the `amount` as width) into the same buffer, and adds the
two coverages clamped to 1 — no new geometry beyond what chapters 7 and 13
already provide. `LCD_TAPS = (1/3, 1/3, 1/3)`; `lcd_filter` pads both ends
with zero (not the edge value — see **Mutation results**); `lcd_coverage`
rasterizes through `scaling(3, 1) * text_matrix(...)` into a `3w`-wide
buffer and filters every row; `paint_lcd` mixes each of a pixel's three
channels through its own stripe's coverage, always in linear light (no
`linear` flag — chapter 9/1's switch never enters an LCD renderer's
picture). `pen_advance`/`draw_text` are one-liners; `draw_text`'s return
value (the pen's final position after stepping across `"Ha"`) and two of
the pixels it painted are now pinned directly in
`chapter17-plate.feature` (added in the chapter-17 catch-up pass), not
just exercised indirectly through `smoothing_demo`.

All four chapter 17 renders (`subpixels.ppm`, `smoothing.ppm`, `lcd.ppm`,
`plate-17.ppm`) diff 0 against `reference/chapter-17/` — not merely within
tolerance. No render in this chapter exercises the atlas or the cache at
all; both are proven correct only by their own unit scenarios (see
**Mutation results**, chapter 17 in `FEEDBACK.md`).

## Mutation testing (chapters 16-17)

Six deliberate bugs, tested and reverted; details and exact numbers are in
`FEEDBACK.md`. Two are worth calling out here because they survived every
render and every non-synthetic scenario, caught only by one hand-built
unit scenario apiece: `implied_points` dropping the wrap-around
off-curve/off-curve pair (none of Roboto's own glyphs happen to have one,
so `plate16.rs` in full stayed green) and `component_matrix` with its `b`
and `c` columns swapped (`eacute`'s only real transform in this font has
`b = c = 0`, so the composite figures don't move at all). A third —
`lcd_filter` padding with the edge value instead of zero — was caught by
the filter's own direct scenario but by nothing that renders a real glyph,
since no glyph's ink happens to reach column 0 or the last column of its
LCD buffer in any pinned render. See `FEEDBACK.md` for the full list,
including the two that render-diffs alone caught immediately (the
double-flip and the atlas that never opens a new shelf).

## Chapter 18 notes

`Placement { name, x, y }` is the whole of layout's output: a flat list a
renderer hands to chapter 17 unchanged. `ascent`/`descent`/`line_height`
are one-line conversions of the font's own vertical metrics into pixels
(`descent` negates the file's negative descender, so it comes out
positive as the chapter says). `layout_run` walks the pen by one
`glyph_advance` per character, pulling in `kern(font, prev, cur)` before
placing every glyph after the first when `kerning` is on; `run_advance`
is the same walk without building the list. `kern` reads `Font.kern`
(added to the loader this chapter, a `HashMap<(String, String), f64>`,
0.0 for a pair the file doesn't list). `break_lines` is greedy: split on
spaces, grow the current line while `run_advance` of the candidate stays
`<= measure`, start a new line the moment it doesn't; a word alone that's
still too wide is left to overflow rather than hyphenated. `layout_line`
is `layout_run` plus the slack (`measure - run_advance`) distributed one
of four ways; `"justify"` only fires when the line has at least one
space, otherwise it falls through to the same `shift = 0.0` `"left"`
takes. `layout_paragraph` is `break_lines` + `layout_line` per line
stacked by `line_height`, forcing the last line to `"left"` when the
paragraph's own alignment is `"justify"`. `draw_run` is the seam:
`subpixel_of(p.x)` into chapter 17's `glyph_bitmap`/`paint_bitmap`, the
baseline through chapter 1's `round` (halves up), not `floor` — a run at
whole pixels is checked byte-identical to chapter 17's `draw_text`.
`kern_demo`/`break_demo`/`drift_demo`/`alignment_plate` (`plate_18`) all
diff 0 against `reference/chapter-18/` — not merely within tolerance.

## Chapter 19 notes

`Font` gained five more optional sections this chapter needed a font to
carry (`ligatures`/`kern` already existed for chapter 18): `joining`
(`HashMap<String, String>`, codepoint string to Unicode joining type),
`forms` (`HashMap<String, HashMap<String, String>>`, glyph name to
form to glyph name), `marks` (`HashMap<String, (String, f64, f64)>`,
mark glyph to anchor class and its own anchor point), and `anchors`
(`HashMap<String, HashMap<String, (f64, f64)>>`, base glyph to anchor
point per class); all four are empty maps when a file doesn't carry the
section, which is Roboto's case for all four and DejaVu Sans's case for
none. `script_of` is three range checks; `itemize` walks the string once,
skipping `"common"` characters without ending the current item (so they
land in whichever item is open when the loop reaches the next real
letter, or in one Latin item if the whole string is `"common"`).
`GlyphEntry { glyph, cluster, dx, dy }` is the shaping buffer's own
element; `glyph_buffer` is one entry per character straight through the
cmap. `apply_ligatures` walks left to right, tries the font's rules
longest-parts-first at each position, and steps past a match's whole
width without re-checking the glyph it just produced — `font.ligatures`
is a `Vec<(Vec<String>, String)>` so a rule's parts aren't fixed at two.
`joining_type`/`form_of`/`arabic_forms` are Unicode's join-type rule
almost verbatim: a transparent character is skipped over (not treated as
a neighbour) when looking either direction for the nearest real one.
`attach_marks` finds each mark's nearest preceding non-mark, borrows its
anchor of the mark's own class, and reparents the mark onto the base's
cluster; no base, or a base with no anchor of that class, leaves the mark
at its own cluster and a zero offset. `shape` is the pipeline `forms?
-> ligatures -> marks?`, forms and marks only run when the font's table
is non-empty, which is why shaping Latin (Roboto has neither) is
ligatures alone. `position` is `layout_run`'s walk generalized to either
direction: `"rtl"` starts the pen at `x + buffer_advance` and subtracts
each advance before placing, so the first entry lands at the run's right
end; a mark is placed at its base's last placed origin (`base_x`) plus
its own offset scaled to pixels, `dy` negated (font units point up,
pixels down) — never touching the pen. `caret_offsets` is `clusters(buffer)`
plus the text's length; `caret_positions` is the same walk's `x` at each
of those offsets, the last one being the pen's final position. None of
this needed a new rasterizer: every render goes through chapter 18's
`draw_run` once shaping and positioning have produced ordinary
placements. `ligature_demo`/`forms_demo`/`word_demo`/`mixed_demo`/
`cluster_plate` (`plate_19`) all diff 0 against `reference/chapter-19/` —
not merely within tolerance.

## Mutation testing (chapters 18-19)

Six deliberate bugs, tested and reverted, three per chapter.

- **Chapter 18 — kerning applied after the glyph instead of before**
  (`layout_run` placing the glyph, advancing the pen by its own width,
  and only then adding the kern against the *next* glyph): caught hard —
  6 scenarios fail across `kerning18.rs`, `aligning18.rs` and
  `plate18.rs`, since every kerned position from the second character on
  comes out shifted by one glyph's worth of kerning.
- **Chapter 18 — the baseline floored instead of rounded halves-up**
  (`draw_run` using `p.y.floor()` instead of chapter 1's `round`): caught
  by the scenario built for exactly this (`the_baseline_rounds_to_a_pixel_row_halves_up`)
  plus two render diffs (`breaking.ppm`, `plate-18.ppm`) whose baselines
  land on a non-whole `y`.
- **Chapter 18 — a justified paragraph's last line also stretched**
  (`layout_paragraph` always passing the paragraph's own `align` instead
  of forcing `"left"` on the last line): **not caught by anything.**
  Every justified paragraph in this book's scenarios and renders happens
  to end its last line on a single word (`"dog"`, `"drew."`), and
  `layout_line`'s justify branch only fires when a line has at least one
  space (`gaps > 0`) — a one-word line is identical whether or not it's
  "supposed" to be forced left. The rule is stated in prose and in the
  chapter's pseudocode, and it's real (a multi-word last line would
  visibly stretch), but nothing in `features/chapter18-*.feature` pins a
  paragraph whose last line has two or more words under `"justify"`. This
  is the single most valuable finding of this round — see **Concrete
  changes** below.
- **Chapter 19 — the rtl pen starting at `x` instead of
  `x + buffer_advance`**: caught hard — 6 scenarios fail, 3 directly in
  `position19.rs` (both the dedicated rtl scenario and the mark-offset
  scenario, which reads `rtl[0].x` as its reference point) and 3 more in
  `plate19.rs`'s render diffs (`word.ppm`, `mixed.ppm`, `plate-19.ppm`).
- **Chapter 19 — a ligature result fed back into the rules**
  (`apply_ligatures` re-running itself on its own output until nothing
  changes, instead of treating a match's result as final): **not caught
  by anything.** Every scenario and every render in this chapter's font
  data uses ligature rules whose *results* (`f_i`, `f_l`, `lam_alef`,
  `lam_alef.fina`, …) never themselves appear as the left-hand side of
  another rule, so feeding a result back in is a no-op on every buffer
  this book ever builds. The prose states the rule explicitly
  ("A result is never fed back into another rule") and a scenario is
  named for it ("The walk is greedy from the left and a result is not
  fed back in"), but that scenario only checks that a *later* position
  in the buffer isn't matched early (greediness), not that an already
  -produced glyph is exempt from re-matching. See **Concrete changes**.
- **Chapter 19 — a mark keeping its own cluster instead of taking its
  base's** (`attach_marks` writing `e.cluster` instead of `b.cluster`
  into the reparented entry): caught directly by 2 of 3 `marks19.rs`
  scenarios (the kasra's cluster and the two-marks-on-one-base scenario
  both pin the reparented cluster value).

Two of six mutations survived every scenario and every render. Both are
recorded above and in **Concrete changes**; neither was silent because of
a gap in *coverage* (every code path the mutation touches is exercised)
but because the specific *data* this book's fonts and example texts
happen to use never puts the mutated behavior and the correct behavior
in disagreement.


## Chapter 20 notes

`parse_xml` converts roxmltree's borrowed tree into an owned `Element`
(`name`, `attributes: Vec<(String, String)>`, `children`), so nothing
downstream carries roxmltree lifetimes. Attribute and element names are
local names. `attribute`, `children` and `find_by_id` are the chapter's
three accessors. Things the scenarios write as `none` are `Option`s:
`read_number`/`read_flag` answer `(Option<f64>, usize)`, `parse_color`
answers `Option<Color>`, `parse_transform` and `view_box_matrix` take
`Option<&str>` so `parse_transform(none)` is `parse_transform(None)`,
`paint_server` and `clip_coverage` answer `Option`. A `Command` is
`{ op: &'static str, args: Vec<f64> }`, flags stored as `0.0`/`1.0`.
`Style` has one field per property (snake_case); `fill`/`stroke` are an
`SvgPaint` enum (`None`, `Color(c)`, `Url("url(#id)")`).
`transformed_paint` is a new `Paint::Transformed` variant: Rust's
`Paint` is an enum, so "joining the registry" means adding a variant and
a match arm in `paint_at`. The walker is one struct shared with chapter
21 (`render_svg` is `render_svg_with(.., "whole", ..)`).
`aspect_demo()` (Figure 20.4) is only defined by the chapter's figure
code; see FEEDBACK.md.

Chapter 7's `add_cell`/`accumulate_row`/`accumulate` became thin wrappers
over generic versions (`CellSink`), so chapter 21's sparse accumulator
receives bit-for-bit the same deposits as the dense one.

## Chapter 21 notes

`Stats` is `{ cells, blends, copies }` (u64), passed as `&mut Stats`.
`CoverageSource` is a trait over `CoverageBuffer`, `Window` and `Tiled`
so `coverage_in`/`full_coverage` read any of them. The tiled fill keeps
deposits in a `HashMap<(x, row), (area, cover)>`, sorts each row's cells,
computes the running sum arriving at every tile column's left edge, and
resolves only partial tiles, which makes its values bit-identical to
chapter 7's (same additions, same order). `draw_tiled` copies solid
tiles under a solid opaque paint with `slice::fill`, and blends partial
rows of a solid paint through `composite_span4` (a `[f64; 4]` lane loop,
no intrinsics, no `std::simd`). Tile classes are `&'static str`
(`"empty"`, `"solid"`, `"partial"`). `tile_work` renders in tiled mode
while tallying `(partial, solid)` per tile.

All five chapter 20/21 renders (`aspect_demo`, `harbor`, `rose`, `tiger`,
`work_map`) are byte-identical to `reference/` (max_channel_difference 0).

## Chapter 22 notes

`grid(v)` is `floor(v * 256.0 + 0.5)` as an `i64`; `snap_point`/`orient`
(chapter 4's `cross`, reused unchanged)/`lex_less` are the section's other
three primitives. `Tuple` gained `PartialEq` (exact, component by
component) for this chapter's grid points, which are always whole
numbers; every earlier chapter keeps using `tuples_eq` for its tolerance.
`Seg { lo, hi, wa, wb }` is built by `seg(a, b, wa, wb)`, which swaps ends
and negates both windings when `a` comes after `b` in the sweep's order;
`path_segments` snaps every edge and drops one whose ends land on the same
point. `meet(s, t)` classifies the four ways (`"none"`/`"end"`/`"cross"`/
`"touch"`/`"overlap"`) by four `orient` tests exactly as `chapter-22.html`
describes: collinear (all four zero) routes to a lexicographic
overlap-of-ranges check; a proper crossing needs each pair of the other
segment's ends strictly on opposite sides; failing that, up to one
endpoint resting strictly inside the other segment is a touch; anything
else sharing an endpoint exactly is an end. `crossing_point`/
`exact_crossing` do the whole computation in `i128` (`(2N + beta).div_euclid(2
* beta)`, exact halves-up rounding via `div_euclid`, which rounds toward
negative infinity for a positive divisor — exactly the `div` the chapter
asks for).

`find_splits` dispatches to three independent implementations that answer
identical splits: `"brute"` (every pair), `"sweep"` (an active list sorted
by `lo`, pruned by `lex_less(lo, hi)`), and `"bentley-ottmann"` — a real
ordered status, processing events (grid points and, later, exact
fractional crossings) in the sweep's order. The event queue holds an
`EPoint` enum (`Grid(i64, i64)` or `Frac(i128, i128, i128)` for `X/D,
Y/D`), compared exactly by cross-multiplying (`epoint_cmp`, up to ~100
bits, well inside `i128`); `eorient` is the ~80-bit exact orientation test
against a fractional event. The status splices in a freshly-ordered block
at each event (`leaving_cmp`, `cross(t_dir, s_dir)`'s sign, ties by
original index — the horizontal-last rule falls out of this for free,
verified against the feature's own scenario rather than special-cased).
`merge_segments`/`split_segments` are a straightforward transliteration of
the chapter's own pseudo-code; the loop's exact pass/test counts (2 passes
for two overlapping squares, 3 for the rounding-creates-a-new-meeting
example, and the full `struck_segments(1)`/`struck_segments(2)` benchmark
numbers) all matched by construction once `meet` and the three finders
were right — no numbers needed adjusting to make a scenario pass.

`winding_beside` doubles the midpoint (`lo + hi`) and compares every other
segment's `lo`/`hi` doubled too, exactly as `chapter-22.html` says "to stay
in whole numbers"; `inside_rule`/`op_inside`/`keep_edges` are one-liners.
`stitch` was the one place the first draft went wrong: "turning furthest
right" needs an angular order starting from *facing back the way you
came*, sweeping counterclockwise, and in this book's clockwise-positive
`cross` convention that means the half nearer `r` is `cross(r, d) < 0`,
not `> 0` — the opposite of my first guess. Two scenarios failed
immediately and unambiguously (`turning_furthest_right_keeps_two_squares_
that_touch_at_a_corner_apart` merged the two squares into one contour;
the star's evenodd `simplify` produced 2 contours instead of 5), which is
exactly the kind of "can fail on the mistake it exists for" scenario the
book's own testing notes ask for — flipping the sign of `ccw_half`'s
branches fixed both instantly. `combine`/`simplify`/`point_lists` are the
whole pipeline; `text_path`/`struck_line`/`struck_segments`/`rosette` and
the plate/seal renders (`op_panel`/`plate_22`/`seal`) all matched the
reference on the first render — `roboto()` (a small new public loader,
also used by chapter 23) and chapter 16-19's existing `layout_run`/
`glyph_path`/`text_matrix` needed no changes at all.

Every chapter 22 scenario (56 across the nine feature files) is green,
and both `plate-22.ppm` and `seal.ppm` are byte-identical to `reference/`.

### Mutation testing (chapter 22)

Three deliberate bugs, tested and reverted. Reversing `stitch`'s turn
comparator (picking the furthest-*left* turn instead) was caught by three
scenarios at once (`two_squares_four_ways`, the touching-corner scenario,
and the star's crossings-become-corners scenario) — the same class of bug
the real implementation actually had on the first pass, described above.
Skipping the second and later passes of `split_segments` (returning after
one cut) was caught immediately by the two-overlapping-squares scenario
(12 segments expected, only some produced) and the three-pass
rounding-creates-a-new-meeting scenario (`st.passes` pinned at 3, got 1),
plus the Bentley-Ottmann benchmark's own segment count. Removing the
`"touch"` case from `meet` entirely (folding it into `"none"`, a plausible
slip for a reader who only thought of crossings and collinear overlaps)
was caught by exactly one scenario — its own direct unit test
(`an_end_touching_the_middle_of_another_segment_splits_it`) — and by
*nothing else*, not even `robust22.rs`'s "a corner resting on an edge"
scenario, which touches a vertex against an edge in exactly this way. The
reason: that scenario's vertex sits at the far end of a long edge that
doesn't need cutting there for the *final* stitched result to come out
right (nothing else meets the uncut edge at that interior point), so the
touch/no-touch distinction is invisible to it. This is worth knowing: a
future scenario that stitches a third shape through that exact touch
point would be the one to actually exercise this path end to end.

## Chapter 23 notes

`sd_circle`/`distance_to_segment`/`sd_box`/`sd_rounded_box`/`sd_polygon`
are `chapter-23.html` §23.1's formulas verbatim (`sd_box`'s two-line
formula is exactly as printed: `length(max(q, 0)) + min(max(qx, qy), 0)`);
`sd_polygon` reuses chapter 5's `winding_at` and this chapter's own
`inside_rule` (borrowed from chapter 22, since "inside under a fill rule"
is the same question either way) for its sign. `solve_cubic` falls back to
a quadratic then a linear solve as the leading coefficients vanish below
`1e-12`, and picks Cardano's formula or the cosine (trigonometric) formula
by the sign of the depressed cubic's discriminant — verified against six
pinned cases including a triple-root-adjacent one, all exact.
`distance_to_quadratic` finds the perpendicular-foot cubic's roots in
`(0, 1)` via `solve_cubic` directly (no numeric solver at all);
`nearest_t_cubic`/`distance_to_cubic` are nine seeds and Newton's method
as prescribed, keeping the earliest candidate on a tie, which is exactly
what makes the `(70, 80)` end-is-the-answer scenario come out at `t = 0`
rather than a stationary point Newton would otherwise wander to.
`brute_distance`/`weyl_points`/`max_curve_error` are the independent
ground truth; both curve distance functions matched it to within `1e-6`
over 10,000 Weyl-sequence points on the first attempt, and the
loop-back-cubic scenario (where chapter 14's own `distance_to_curve`
gets it wrong, by design) passed without adjustment.

`Field { width, height, values }` plus `field`/`field_of`/`field_at`/
`field_range`/`field_coverage` are chapter 2's `CoverageBuffer` pattern
one level up; `polygon_field`/`coverage_error` close out §23.3.
`field_offset`/`field_stroke`/`field_union`/`field_intersection`/
`field_difference`/`field_xor` are each one line over `field_zip`, a
private per-value zip helper; every one of the "for free" comparisons
against chapters 13, 14 and 22's own stroke/offset/boolean code passed
first try, pinned `ink` differences included. `smooth_min`/
`field_smooth_union`/`fillet_field` are §23.5's one-line polynomial
smooth minimum.

`edt_1d` is Felzenszwalb and Huttenlocher's lower envelope of parabolas,
transliterated from the chapter's own pseudo-code line for line (the
`while s <= z[k]: k -= 1` loop never needs an extra guard against `k`
going negative, because `z[0] = -infinity` stops it there by
construction); `far_value`/`distance_transform`/
`brute_distance_transform`/`bits_of`/`coverage_of`/`field_from_coverage`
round out §23.6, and `distance_transform` matched `brute_distance_
transform` over all 4096 pixels of `transform_bitmap()` on the first run.

§23.7's glyph atlases were the chapter's biggest chunk of new code.
`bake_box`/`bake_sdf` needed no surprises. `is_corner(a, b)` is literally
`dot(a, b) <= 0 || abs(cross(a, b)) > sin(3)` — `3` in *radians*, which
looks like a typo until you notice `sin(3 rad) = sin(pi - 3 rad) = sin(~8
degrees)`, exactly the "turns by more than about eight degrees" the prose
promises; it reads like a magic number until you do the trig. `color_edges`
rotates a contour to its first corner and either colours every curve
white (no corners), splits until there are at least three curves and
bands them cyan/white/magenta (one corner), or alternates cyan/magenta by
run with a yellow last run on an odd count (more corners) — all five
`colouring_edges` fixtures (square, triangle, house, teardrop, circle)
matched on the first try. `pseudo_distance` and `bake_msdf`'s per-channel
"least distance, ties broken by which edge meets `p` closer to a right
angle" selection are `chapter-23.html` §23.9's `msdf_texel`/
`pseudo_distance` pseudo-code directly; `bake_mtsdf` adds `bake_sdf`'s
field as a fourth channel. `sample_field`/`median3`/`draw_baked`/
`draw_effect` share one bounds helper (`baked_bounds`); `draw_effect`
takes a `k_of` closure in place of `clamp(0.5 - d, 0, 1)`, plus a flag for
whether the distance comes from the fourth (true, unclamped) channel or
the median of the first three.

§23.8's `peanut`/`min_of` needed nothing but chapter 22's own `combine`
for the "true" union.

The plate (§23.9): `band_canvas`/`band_color` bands every field the same
way; `primitive_fields`/`error_map`/`fillets`/`transform_demo`/
`atlas_corners`/`trap_shrink`/`plate_23` all matched `reference/` on the
first render. `title` needed one correction: "`draw_effect` four times
over the run in order" means one full pass over every glyph per effect
(all eight shadows, then all eight glows, then all eight fills, then all
eight outlines) — not all four effects for one glyph before moving to the
next. Doing it per-glyph left `max_channel_difference` at 6 (not 0);
switching to per-effect passes (baking every glyph's `Baked` once,
up front, then four loops over the placements) made it byte-identical.
The book's own prose doesn't fully disambiguate this ("four times over
the run" reads either way until you compare against the reference), which
is worth a clarifying sentence — see **Prose problems** in `FEEDBACK.md`.

Every chapter 23 scenario (36 across the nine feature files) is green,
and all nine named renders, plus `plate-23.ppm`, are byte-identical to
`reference/chapter-23/`.

### Mutation testing (chapter 23)

Four deliberate bugs, tested and reverted. Flipping `smooth_min`'s sign
(adding the correction instead of subtracting it) was caught immediately
and everywhere: both of `smooth23.rs`'s own scenarios, and every render
that uses a fillet or a smooth union. Skipping the second
(row) pass of `distance_transform` (returning the column pass's squared
distances unchanged) was caught immediately by three of the four
`transform23.rs` scenarios and the render suite. Removing `pseudo_distance`'s
"past the end" special case (always falling through to the interior
formula) was caught by its own direct scenario and by both `bake_msdf`
scenarios/renders that exercise a real corner (`atlas-corners.ppm`,
`three_channels_at_one_texel`) — corners are exactly where the distinction
matters. The fourth is the one that survived almost everywhere:
disabling `bake_msdf`'s "if two edges tie on distance at an end, prefer
the one whose end direction is closer to a right angle to `p`" tie-break
(always keeping whichever edge was found first) was caught by
*only one scenario in the entire suite* — `three_channels_at_one_texel`
— out of all 789 scenarios across 23 chapters, including `atlas_corners()`
and `title()`, both of which bake and draw real glyph corners with
`bake_msdf`/`bake_mtsdf` at visible sizes. The tie-break only matters
exactly at a corner where two edges' nearest points are equidistant from
a sampled texel, a narrow enough condition that neither rendered glyph's
texel grid happens to land on one. This is the single most valuable
finding of this round: `atlas_corners()`/`title()` prove `bake_msdf`
produces a plausible-looking image without proving the tie-break is
implemented at all.

## Chapter 24 notes

`triangle_winding(a, b, c, x, y)` is `winding_at(&polygon(&[a, b, c]), x, y)`
directly — chapter 5's own winding rule, reused rather than re-derived, since
a signed triangle's winding at a point is exactly what `winding_at` already
computes for any closed polygon. `Stencil { width, height, values: Vec<i64>,
fragments }` is `stencil_triangle`'s target; `stencil_buffer_at(p, w, h, ox,
oy)` takes the sample offset explicitly and `stencil_buffer(p, w, h)` is the
default-0.5 wrapper Rust needs in place of the book's left-out-argument
convention (there's no way to give a function a default parameter here).
`cover`/`stencil_at`/`winding_mismatches` are one-liners once `Stencil`
exists. `loop_blinn_uv`/`inside_curve`/`curve_sign` are `chapter-24.html`
§24.2's formulas verbatim; `curve_terms` is `loop_blinn_stencil`'s second
half factored out on its own (both the plate and `glyph_stencil` need it
separately), and `loop_blinn_stencil` is the fan of chords plus `curve_terms`
added in. `glyph_curves(font, name, m)` — introduced in this chapter, not
chapter 23, despite the feature text's attribution — flattens
`glyph_outline`'s per-contour curves into one ordered list, each transformed
by `m`; `glyph_stencil` anchors at its first curve's first point. Both the
un-flattened `g` (22,813 fragments) and `ampersand` matched a
thousandth-of-a-pixel-flattened `glyph_path` with zero winding mismatches on
the first run — no surprises in the Loop-Blinn math itself.

`sample_pattern`/`msaa_coverage` are `chapter-24.html` §24.3's four patterns
and the per-sample stencil evaluation; the four msaa-vs-exact differences
(0.4875, 0.1125, 0.0375, 0.0375) matched on the first render. `shade_tile`
and `lcg_shuffle` (Fisher-Yates from the end, `i128` for the intermediate
product so it never needs a double's rounding) are §24.4's purity check and
the shared shuffle everything else in the chapter uses.

The compute pipeline (§24.5) is `SvgCommand`/`Encoder` (a walker that mirrors
`Walker::render_element`/`draw_shape` field for field but records
`Fill`/`Push`/`Pop` instead of drawing), `Scene`/`SceneCommand` (every path,
clip parts included, numbered as a draw the moment it's encountered),
`flatten_stage`/`bin_stage` (a `RecordingSink` implementing the crate's own
`CellSink` trait, so every `add_cell_to` call chapter 7's accumulator would
have made is captured instead, filed by tile), and `coarse_stage`/
`fine_tile`. Two decisions keep it byte-exact against chapter 20 without
fighting Rust's floating-point associativity: `coarse_stage` resolves each
tile's fill directly from a `TileWork` built by the crate's own private
`tile_pass` (the same function `fill_path_tiled` already calls) rather than
literally re-deriving arriving-sums from `bins` cell by cell — since
`tile_pass`'s per-cell sums and its arriving-sum sweep are the same
already-proven-correct arithmetic in the same order, resolving through it
guarantees bit-identical results without re-implementing (and possibly
mis-ordering) the summation; `bin_stage` still exists and is exercised
independently (its own `deposit_count` scenario is pinned at 119,876 for the
tiger), it just isn't the numeric source of truth for rendering. `cull_groups`
is generic (`PipeCmd<F, C>`, a stack of frames each remembering whether it
saw a fill), which lets the same function serve both the feature's own
bare-tuple scenario (`PipeCmd<i64, ()>`) and the real pipeline's
`CoarseCommand = PipeCmd<FillCmd, Vec<f64>>` — one algorithm, two payload
types, instead of transcribing the stack logic twice. `fine_tile` matches
§24.7's printed pseudocode line for line, reusing chapter 9's `over`/
`pop_group_with_opacity` for the group stack. All three documents (tiger,
harbor, rose) came out byte-identical to chapter 20 in both raster order and
`lcg_shuffle(.., 99)` order on the first render; `STACK_DEPTH = 2` and the
rose's 200 spills (two-deep-nested petal groups) matched the pinned values
too.

Plate 24, `msaa_demo`, `spill_map` and `tiger_assembly` (the last three
needing `stack_below`, an existing private helper from chapter 23, for their
top-to-bottom/2x2 layouts) all came out byte-identical (`max_channel_
difference` 0) to `reference/chapter-24/` on the first render.

### Mutation testing (chapter 24)

Three deliberate bugs, tested and reverted. Dropping `inside_curve`'s `s > 0`
guard (using `u^2 - v < 0` alone) was caught immediately and everywhere: two
of `loopblinn24.rs`'s own scenarios, the un-flattened `g`'s winding-mismatch
count (3,658 mismatches where 0 were expected), and both `plate24.rs` render
checks. Replacing a scratch buffer's fresh `layer(tw, th)` at the top of
`fine_tile` with one pulled from a thread-local pool and *not cleared*
between tiles — simulating a real GPU renderer's reused-scratch-buffer bug —
was caught by the tiger's byte-exact-match scenario even in plain raster
order (a same-sized later tile inherited an earlier tile's rendered pixels
instead of starting transparent), and by the bespoke non-grouped-clip
scenario. Neither of those needed the shuffled-vs-raster-order equality
check specifically; the plain "matches chapter 20" comparison already
noticed. The third is the interesting one: breaking `fan_anchor` to always
return `point(0, 0)` instead of the path's own first point was caught hard
by the two scenarios that pin `fan_anchor`'s return value and the star's
fragment count directly (`fan_anchor(sq) = point(1, 1)` failed outright, and
the star's fragment count rose from 13,660 to 25,686 with the much larger
bounding boxes an origin-anchored fan produces) — **but every render-based
scenario, including `plate_24`'s own pinned pixels, still passed.** The
reason: stencil-and-cover's correctness proof never requires the anchor to
lie on the path or even near it — any fixed point makes the fan's spokes
cancel the same way, so the *pixel values* stay exactly right regardless of
which point is chosen. Only efficiency (and the two scenarios that happen to
pin the anchor and the resulting fragment count) suffers. This is worth
knowing: a reader who picks a convenient-but-wrong anchor (the canvas
corner, say) would ship a working renderer and only get caught by the two
scenarios written specifically to catch it, not by anything downstream.

## Chapter 25 notes

`Brush { radius, hardness, spacing, flow, opacity }` and `dab_coverage` are
straight from §25.1's formula. `stamp_positions` carries the distance still
needed (`need`) across segments exactly as the chapter's prose describes —
the three-point scenario (`(0,0)`, `(3,0)`, `(10,0)` with `step = 5`) only
comes out right (`(0,0)`, `(5,0)`, `(10,0)`) if the leftover `need` from the
short first segment (3 of the 5 units) carries into the second. `stroke_mask`
samples at pixel centers (`x + 0.5, y + 0.5`) and folds dabs in with the
same `1 - (1 - m)(1 - flow * k)` union chapter 12's clips use; both overlap
scenarios (0.6, 0.435147, 0.84) matched on the first run. `wobbly_events`
and `min_along` are §25.1's demonstration that spacing by distance beats one
dab per event (99 dabs from 25 events; `min_along` 0 vs 0.704456).

The scanline `flood_mask` is `chapter-25.html` §25.5's printed pseudocode
translated directly, with a private `fm_push` helper so both the initial
seed and every run-head seed go through the same push/stats bookkeeping —
`fs.pushes` counts the initial seed too, which is what makes the empty
200x200 canvas come out at exactly 200 (one seed per row) rather than 199.
`ring_canvas` (chapter 13's stroke, chapter 7's exact fill, painted through)
matched `bytes_at`'s three pinned pixels and all four tolerance/anti-alias
ink values (10324, 10484, 10700, 25600, 10648) and `select_color`'s 23636 on
the first try — no fudging needed on the antialiased ring's byte values.
`naive_depth` is simulated with an explicit heap-allocated stack (each frame
remembering which of the four directions it's tried next) rather than
genuine recursion: a real recursive translation of the chapter's own
four-way naive fill overflows the test thread's stack at `naive_depth(200,
200)` (40,000 deep) well before it returns, which is the whole point of the
section (see **Failures** below) — simulating the same call/return structure
on the heap gets the identical depths (12, 40,000) without the crash.

Heckbert's median cut (`median_cut`) matched all four hand-worked cases in
the scenario (including the earliest-box-on-a-tie and
red-before-green-before-blue-on-a-tie rules) and the ring canvas's own
four-colour palette (`(63, 63, 80)`, `(128, 127, 130)`, `(226, 223, 215)`,
`(246, 243, 234)`) on the first attempt, once the "never cut after the last
colour" clamp was in place for boxes whose running count never reaches half
before the last entry. `threshold`/`ordered_dither`/`error_diffuse` work in
light (`palette_light` decodes each byte); the small 4-pixel error-diffusion
scenario (`[0, 0, 1, 1]`) and the ramp's three mean-light values (0.5,
0.530273, 0.500732) all matched immediately. `canvas_to_bmp8`/`read_bmp8`
are a direct translation of §25.3's byte layout (offset 1078 is a constant,
not computed, since the palette is always written as the full 256 entries);
the byte-by-byte scenario matched on the first attempt, including the
row-padding from 5 to 8 bytes and the bottom-up row order.

`marquee`/`add_selection`/`subtract_selection`/`intersect_selection` are
thin wrappers over chapter 12's `clip_rect`/`union_coverage`/
`multiply_coverage`. `feather` is a plain two-pass box blur; `coverage_at`'s
existing out-of-bounds-is-0 convention already gives "off the buffer counts
as unselected" for free, no special-casing needed. `Floating`/
`float_selection`/`move_floating`/`drop_floating` reuse chapter 9's `Pixel`/
`Layer`/`over`. `History` does **not** hold a reference to the canvas it was
built from — Rust won't let it stash a live `&mut Canvas` alongside the
test's own direct `pixel_at(&c, ..)` calls on the same canvas — so
`history_fill`/`undo`/`redo` all take the canvas as an explicit second
argument instead of the feature's implicit shared-object style; every other
function and scenario translates without needing this kind of change (see
**Hard to translate** in `FEEDBACK.md`). `undo`/`redo` are exactly
symmetric: an edit only ever stores its own "before" pixels at push time,
and the pixels it overwrites are captured lazily, at undo/redo time, from
whatever is actually on the canvas then — which is what makes
`stored_pixels` come out at 32, then 17 after a new edit clears the redo
stack, matching the scenario exactly without ever storing a redundant
"after" snapshot up front.

`paint_by_script` skips the magenta stroke the prose describes as "painted,
then undone" rather than implementing a generic undo for an arbitrary
brush stroke: a perfect undo restores the canvas pixel-for-pixel, so never
painting it at all is provably byte-identical to painting and undoing it,
and the render matched the reference on the first try. Every other step
(gradient sky, flat sea, sun/hills/waves brush strokes, the boat's
floating-selection move, and the final median-cut/error-diffuse/BMP
round trip) is exactly what the prose lists, in that order.

Every chapter 25 scenario (22 across five feature files) is green, and all
five named renders plus `plate-25.ppm` are byte-identical
(`max_channel_difference` 0) to `reference/chapter-25/`.

### Mutation testing (chapter 25)

Three deliberate bugs, tested and reverted. Making `anti_alias_mask` check
all eight neighbours instead of four was caught immediately by its own
scenario (`ink` rose from 10,648 to 10,718) and by `halo_demo`'s render.
Skipping the `decode` in `palette_light` (treating a palette byte's `/255`
as its light directly, the chapter 1 mistake the prose warns about) passed
`quantize25.rs`'s own scenario completely unnoticed — because that scenario
dithers to a pure black-and-white palette, and `decode(0) = 0`,
`decode(1) = 1` exactly regardless of the transfer function, so the two
palette entries this book's only pinned dither scenario ever uses are
immune to the bug by construction. It only showed up on `paint_by_script`'s
16-colour median-cut palette, where intermediate byte values actually
differ under the two conventions: the render came out visibly wrong at
(370, 110), nowhere near where a palette shift would be expected, because
the *global* palette (computed once from every pixel) shifted, which
retroactively changed the quantization decision for pixels far from any
change. **This is worth recording as a gap**: nothing in
`chapter25-quantize.feature` pins a dither scenario against a palette with
values other than pure black and white, so a linear-light regression here
is invisible except through the one render that happens to use a richer
palette. The third mutation folded the brush's `opacity` into each dab's
contribution to the union (`1 - (1 - m)(1 - flow * k * opacity)`) instead
of scaling the finished mask once at the end, which is a real bug against
the chapter's own stated invariant — "a stroke at 50% opacity never gets
darker than 50% however many times it crosses itself" no longer holds,
since repeated per-dab factors still drive the union toward 1 regardless of
opacity. **Every scenario in `chapter25-brush.feature` passed**, because
none of its four brush scenarios uses an opacity below 1; only
`paint_by_script`'s six overlapping wave strokes (`brush(1.6, 0.2, 0.3,
0.7, 0.8)`, opacity 0.8) exercised it, and even then only indirectly, again
through the shared median-cut palette shifting a pixel 260 units away. See
**Concrete changes** in `FEEDBACK.md`: the chapter's own stated invariant
about opacity and self-crossing strokes has no direct scenario of its own.

## Chapter 23 catch-up (before the epilogue)

`features/chapter23-atlas.feature` gained one scenario since this code last
ran: "A space has no edges, so every texel is as far out as the clamp
allows", which calls `bake_mtsdf(f, "space", 16, 3)` and checks all four
channels come back at the spread. `bake_sdf`/`bake_msdf`/`bake_mtsdf` were
already written generally enough (the distance loop over an empty curve
list leaves `best = f64::INFINITY`, and `bake_msdf`'s per-channel loop over
zero matching edges falls through to its `None => spread` arm) that the new
scenario passed on the first try with no code change — added to
`tests/atlas23.rs` as `a_space_has_no_edges_so_every_texel_is_as_far_out_as_the_clamp_allows`.

## Epilogue notes

Nothing in the epilogue needed new machinery: `book_cover()` and
`book_cover_glow()` (in `src/lib.rs`, right after chapter 25) are thin
compositions of `render_svg` (chapter 20), `load_font`/`layout_paragraph`/
`layout_run`/`draw_run` (chapters 16/18), and, for the bonus glow,
`bake_mtsdf`/`draw_effect` (chapter 23) — exactly the seven-line program
the chapter prints. All eleven scenarios across the four
`features/epilogue-*.feature` files passed on the first attempt, and all
three named renders (`cover-art.ppm`, `cover.ppm`, `cover-glow.ppm`) came
out **byte-identical** (`max_channel_difference` 0, not just ≤ 1) to
`reference/epilogue/`, confirmed both through the test suite's `≤ 1`
scenarios and by a direct byte-for-byte `cmp` of `out/*.ppm` against
`reference/epilogue/*.ppm` after `render_all`.

The type feature's placement indices (`title[14]`, `title[15]`) and the
"24 placements for 25 characters" count are pure consequences of chapters
16 and 18's existing `break_lines`/`layout_paragraph`: `break_lines` already
reconstructs each line by rejoining its words with single spaces, so the
line-breaking space itself was already never placed, with no
epilogue-specific code needed.

`book_cover_glow` bakes each *distinct* glyph name in the title once (a
`HashMap<String, Baked>` keyed by glyph name, filled while walking the
placements) before drawing any glow, matching the chapter's prose ("every
distinct glyph of the title baked once") — though nothing in the scenarios
would have caught baking per-placement instead of per-glyph-name, since the
result is pixel-identical either way and only the work done differs.

Timing (release, one run each, this machine): `cover-art` (the bare SVG
document) 392ms; `cover` (`book_cover()`) 470ms; `cover-glow`
(`book_cover_glow()`) 1.03s — the extra ~600ms is baking and evaluating the
MTSDF field for the roughly 20 distinct glyphs in the title.

### Mutation testing (epilogue)

Three deliberate bugs, tested and reverted, all caught:

1. **The chapter's own named trap**: baking the glow at chapter 23's spread
   of 4 instead of the epilogue's spread of 8. Caught by
   `the_glow_sits_around_the_titles_letters_and_nowhere_else`
   (pixel (35, 499): expected (93, 54, 55) ± 1, got (97, 56, 55)) — a small
   miss, but over the 1-channel budget.
2. **Drawing the glow after `draw_run` instead of before** (painting the
   soft field on top of the crisp glyph bitmaps instead of underneath
   them). Caught by the same scenario, much more loudly (pixel (44, 499):
   expected (243, 239, 230), got (249, 207, 183) — the paper background
   picking up an unwanted glow tint where the glyph should have covered it
   cleanly).
3. **Passing `linear = false` to both `draw_run` calls in `book_cover`**
   (the browser-mode blend instead of the book's default linear one). This
   is the interesting one: **every point-probe (`ppm_pixel`) assertion in
   `the_cover` still passed** — the five hand-picked pixels happen to sit
   where the mistake doesn't move the byte by more than 1 — and only the
   golden-image scenario line, `max_channel_difference(p6, ref) ≤ 1`,
   caught it, at an actual difference of 54. This is a direct
   demonstration of the book's own §0.5 point about why golden-image tests
   exist alongside point probes: a handful of probes, however well chosen,
   can miss a global mistake that a full-image diff catches immediately.

All three mutations were reverted and the full suite re-confirmed green
(846 scenarios) before moving on.
