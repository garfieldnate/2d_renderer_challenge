# The 2D Renderer Challenge — working notes for Claude

A test-driven book that builds a 2D vector renderer from nothing, modeled on _The Ray Tracer
Challenge_. Read `plan.html` (the outline and writing guide) and `README.md` before touching
a chapter. This file holds the rules that aren't derivable from the code.

## The iron rule: every step is pinned by Gherkin

The first draft of chapter 1 failed because it left things to the reader. Never again.

- **Every step a chapter asks the reader to take has a scenario.** If the prose says "write
  this", "decide what happens when", "try", or "render this and look", there is a `.feature`
  scenario that pins the result. No exercise is ever left to the reader to figure out.
- **Every suggested implementation is specified**, including the "one-off fun" renders (the
  checkerboard match, the 256-step ramp, the clamp pair). These are exactly the tests that find
  real bugs: transposed x/y, truncation instead of rounding, the wrong branch of a transfer
  function. Each render is a named function that returns a canvas (`gray_match()`,
  `plate_01()`), so scenarios can call it, and each has a reference PPM under
  `reference/chapter-NN/` that a scenario diffs against with an explicit budget.
- **Chapter-end programs are printed** as short pseudo-code (30 lines or fewer) _and_ pinned by
  a scenario. Pseudo-code ranges are inclusive at both ends, and the chapter says so.
- **No exercises section.** Anything that would have been an exercise becomes a numbered
  section with its own scenario and figure, or it is cut.
- **Nothing is left implicit that a reader in a different language could get wrong.** Rounding
  mode, clamping order, line-wrapping rule, default state of any global switch, what happens
  out of bounds: all stated in prose _and_ pinned by a scenario.

## How scenarios are written

- `←` assigns. `a = b` on floats means within `0.0001`; a different tolerance is written in the
  open as `± ε`. Colors compare component-wise with the same rule. Integer triples like
  `(0, 188, 255)` are file pixel values and compare exactly unless `± 1` is written.
- Three tiers, as in `plan.html` → Testing: exact scalars, scalars with tolerance, and golden
  image diffs (`max_channel_difference(ppm, ref) ≤ 1`). Chapter 1 uses all three.
- Never pin a byte whose pre-rounding value sits near `.5`; check margins with the reference
  implementation before pinning (the encoded-space half gray lands on 127.4999 and flips).
- Scenario names say what is being shown, not what function is called: "x is the column and y
  is the row", not "test pixel_at".
- One `.feature` file per chapter section, named `chapterNN-<section>.feature`. The chapter
  prints every scenario in each file, whole, via a `data-feature` block (see below).
- Scenarios that toggle global state (`Given linear blending is off`) are explicit; every other
  scenario expects the default, and the chapter tells the reader to reset between scenarios.
- **A scenario must be able to fail on the mistake it exists for.** Round 1 of reader testing
  found a `>= 70` line wrap that passed every scenario: the pinning example broke at 67 columns, so
  the boundary was never exercised. Pin boundaries exactly (a line of exactly 70 characters), and
  when a scenario claims to test a branch, put a value on each side where the branches actually
  disagree by more than the tolerance.
- **Helpers that tests depend on get their own scenarios**, including their failure modes:
  `max_channel_difference` on files of different sizes returns 255, and there is a scenario for it,
  because otherwise a transposed render compares as identical.
- Step order is legal Gherkin: `Given` and `When` never follow `Then`. Load reference files in a
  `Given`, produce the PPM in a `When`, and put every assertion after.
- **Probe a clamp somewhere the placement matters.** Round 2 found that clamping the result of
  the browser-mode mix instead of its ends passed every scenario, because the only probe was at
  t = 0 where both agree. Test at t = 0.5.
- **Probe each half of a compound rule separately.** The size rule was tested with 5×3 vs 3×5,
  where widths already differ; a width-only check passed. Add the 5×3 vs 5×4 case.
- A render whose pattern is symmetric under x↔y (a checkerboard in a square) can't detect a
  transposed writer, and doesn't need to: the output is identical. Don't contort the picture
  for that; the canvas feature's asymmetric scenario is what catches a swapped convention.
- In render scenarios every `ppm_pixel` probe carries `± 1`, consistently, for the same reason the
  reference diff does. Unit scenarios for the PPM writer stay exact.

## Ground truth lives in `reference/`

- `reference/impl/renderer.py` is the author-side reference implementation. It mirrors the book's
  API names exactly, is never printed, and exists so that every number in a scenario was produced
  by running code.
- `reference/impl/run_features.py` executes every `.feature` file against it with a tiny
  step-pattern runner. **It must pass before any commit that touches `features/` or the
  reference.** When you add a new step shape to a scenario, teach the runner that shape.
- `reference/impl/render.py` regenerates `reference/chapter-NN/*.ppm`. Regenerate after any
  change to a render, and commit the PPMs (`.gitignore` allows `reference/**/*.ppm`).
- Numbers quoted in prose (188, 0.7354, 183 distinct values) come from the reference, never from
  memory or a calculator.

## Chapter HTML

- Chapters live in `chapters/chapter-NN.html`, zero-padded, linking `../assets/book.css` and
  `../assets/book.js`. No build step to read them; `./build.py` inlines for publishing.
- Test blocks are `<div class="test" data-feature="chapterNN-x.feature"><p class="label">…</p>
  <pre><code></code></pre></div>`. **Never hand-edit the `<pre><code>` contents.** Run
  `./tools/sync_features.py` to fill them from `features/`; `--check` fails if they drift or if
  a chapter's feature file isn't printed. Run it before committing.
- Figures are drawn with `Plate.add(id, aspect, draw)` in a `<script>` at the end. A figure that
  depicts a render the reader makes must reproduce it from the same program (same dimensions,
  colors and byte conversion), not an approximation.
- Available boxes: `.test` (scenarios), `.trap` (the chapter's trap), `.gui` (In the GUI aside,
  ≤60 words, real control names), `.note` (how to read the book: notation, where files live).

## Voice (see `plan.html` → The rhythm of a chapter, which is authoritative)

Casual, funny, second person, contractions. Never _simply_, _just_, _obviously_, _trivially_,
_of course_, _clearly_, never _we_ meaning _you_, no exclamation marks. Open on a concrete
problem. Admit when something is horrible. Jokes come out of the material. Check with:
`sed -e 's/<[^>]*>//g' chapters/chapter-NN.html | grep -n -iwE 'simply|just|obviously|trivially|of course|clearly|we'`

## Architectural decisions already made (don't reopen)

- The canvas stores **linear light** from chapter 1. `color(0.5, 0.5, 0.5)` is half the photons.
  `canvas_to_ppm` clamps, encodes, scales to 255 and rounds to nearest, in that order.
- Output is plain-text P3 in chapter 1, binary P6 from chapter 2.
- `mix(a, b, t)` is the book's one blending primitive, with a global linear-blending switch that
  defaults on. Off means encode, lerp, decode, which is what browsers do.
- Writes outside the canvas are silently ignored.
- Readers are presumed able to read Gherkin. No plain-table duplicates of scenarios.
- Chapter 4 follows _The Ray Tracer Challenge_'s names: `point(x, y)` has `w = 1`, `vector(x, y)`
  has `w = 0`, `matrix3` takes nine numbers row by row, `M[r, c]` is row then column,
  `translation/scaling/rotation/shearing`, `inverse`, `m * p`. Angles are radians. A positive
  rotation turns x toward y, which the book says out loud is clockwise on the y-down canvas.
- `approx_scale(m)` is `sqrt(|det|)` of the 2×2 part. The chapter explains the alternatives
  (largest singular value, longest column) and why this one; don't swap it.
- Shapes are transformed through the inverse (`transformed(shape, m)`), points through the matrix
  (`transform_points`, `segment`, `outline`). The pen-space question is chapter 4's trap.
- Chapter 5 paths: `path()`, `move_to`, `line_to`, `close`, `subpaths(p)` with `.points`/`.closed`,
  `edges(p)` treats every subpath as closed, `bounds(p)` of an empty path is `(0, 0, 0, 0)`.
  `line_to` with no subpath acts as `move_to`; after `close` it starts a new subpath at the closed
  one's first point. Insideness uses the half-open rule `a.y ≤ y < b.y`; positive winding is
  clockwise on screen (same sign as `cross`); the boundary belongs to the top and left. Fill rules
  are the strings `"nonzero"` and `"evenodd"`, via `filled(p, rule)`.
- Chapter 6 sweep: `edge_table` drops edges with `a.y = b.y` exactly and sorts by `(y_top, x_top)`;
  ties beyond that are unordered and never pinned. Rows sample at `row + 0.5`; an edge is active
  when `y_top ≤ y < y_bottom`; `fill_span` fills pixels whose centers lie in `[x0, x1)`.
  `fill_path_aliased` must equal `rasterize_centers(filled(p, rule))` exactly, and the scenarios
  say so via `max_coverage_difference`. Never pin the length of the star's edge table: two of
  its vertices differ in the last bit of y.
- Chapter 7 analytic fill: an `accumulator(w, h)` holds two numbers per cell, `area` and `cover`.
  `add_cell` folds a deposit left of the buffer onto column 0 as pure cover and drops one right of
  it. `accumulate_row`'s area is the midpoint rule (`height · (1 − x_at_midpoint)`), which is exact
  for a straight edge. `accumulate(a, b)` carries a positive height heading up the canvas so the
  left-to-right running sum in `resolve` equals chapter 5's `winding_at` exactly. `apply_rule` is
  `min(1, |w|)` for nonzero and a triangle wave for even-odd. `fill_path(p, rule, w, h)` replaces
  `fill_path_aliased` from here on. The proof it's exact: for a simple polygon
  `ink(fill_path(p)) = polygon_area(p)` (the shoelace area), which the 8×8 supersampler can't match.
  It agrees with the supersampler exactly only on grid-aligned shapes; elsewhere the analytic one is
  the truth. Trap: exact only under a box filter and for a shape considered alone — the shared-edge
  seam is chapter 9's, not a bug here.
- Chapter 8 curves: `quadratic`/`cubic` hold control points. `point_at`/`split_at` are de Casteljau;
  `derivative` is the tangent; `curve_bounds` is tight via derivative roots and is named
  `curve_bounds` (not `bounds`) so it doesn't shadow chapter 5's path `bounds`. `flatten(c, tol)`
  subdivides at `0.5` until `flatness` (max control-point distance to the chord) ≤ tol, and must be
  done AFTER the device transform (`transform_curve` then flatten). The path type is unchanged:
  curves reach the fill through `flatten_into_path`, which `line_to`s the flattened points. SVG
  `arc(x1,y1,rx,ry,phi,large,sweep,x2,y2)` is the endpoint→center conversion with radius correction
  (grow both radii together), `phi` in radians (SVG's attribute is degrees; convert at the chapter 20
  parser), returns `none` for coincident endpoints or a zero radius; `arc_point(a, t)` walks it. The
  two flags pick one of four arcs. The runner learned `none`/None comparison and the
  `accumulate`/`accumulate_row`/`add_cell` mutation steps.
- Chapter 9 compositing: a `pixel(r, g, b, a)` is premultiplied linear light (r,g,b in [0, a]);
  `from_color`/`opaque` premultiply, `pixel_color` divides back out (transparent reads black),
  `lerp_pixel` averages straight down the premultiplied channels (the reason premultiply is a
  correctness requirement, reused by chapter 11). `over(src, dst) = src + (1 − src.a)·dst` is
  `paint_through` generalized. `composite(op, src, dst)` is the twelve Porter-Duff operators as
  `Fa·src + Fb·dst` with a `(Fa, Fb)` table. `blend(mode, src, dst)` is source-over with a blend
  function; `blend("normal") == over`; twelve separable modes plus hue/saturation/color/luminosity,
  all in linear light (browsers use encoded space, so numbers differ — chapter 1's lane). A `layer`
  is a premultiplied-pixel buffer; `flatten_layer(layer, bg)` composites it over an opaque
  background to a canvas — named `flatten_layer`, NOT `flatten`, so it doesn't shadow chapter 8's
  curve `flatten` in the runner's flat namespace. The canvas stays opaque RGB; chapters 1-8 are
  untouched. Trap: conflation — two abutting opaque shapes composite to 0.75 along the shared edge,
  not 1.0, a seam every renderer has.
- Chapter 10 paint: a `Paint` answers `paint_at(paint, x, y)`. `solid(c)` ignores the point; the
  gradients turn it into a parameter and read `sample_stops(stops, t)` (a `stop` is `(offset,
color)`, binary search, interpolate in linear light). `extend(t, mode)` is pad/repeat/reflect.
  `linear_t` projects onto the axis; `radial_t` solves the two-circle quadratic and returns the
  LARGEST t whose interpolated radius is non-negative (not the first root by discriminant sign — that
  passes whenever only one root is valid, which every simple scenario is; a reader round caught it),
  and `none` for points no circle reaches (a focal gradient's cone); `conic_t` is the angle. `paint_fill(c,
cov, paint)` samples per pixel center and is byte-identical to `paint_through` for a solid.
  Ordered dither: `BAYER4`, `dither_threshold`, `to_byte_dithered`, `canvas_to_p6_dithered` — a
  flat value splits across the two bytes around it. Trap: a focal point outside the end circle makes
  `radial_t` return `none`, and `paint_at` returns the last stop there (not black). NOTE: the plan's
  suggested test "r0 = r1 reduces to a linear gradient" is false for the standard two-circle form
  (that case is a genuine quadratic); pinned the true reductions instead — concentric is distance
  over radius, focal runs focal→end-circle. Interpolation and dither are in linear light (browsers
  differ), consistent with chapter 1.
- Chapter 11 images: an `Image` is a premultiplied-linear `Pixel` buffer (chapter 9); `read_image`
  decodes a PPM's bytes from sRGB to linear (opaque). `image_texel(img, ix, iy, extend)` folds
  out-of-range indices by clamp/repeat/reflect. The samplers `sample_nearest`/`sample_bilinear`/
  `sample_bicubic` (Catmull-Rom, `catmull(t)` public) all work in texel-CENTER space — the source
  coord minus 0.5, since a texel's centre is at `tx + 0.5`. The identity transform must be
  bit-exact under every filter; that is the test that catches a dropped half-pixel offset.
  `image_paint(img, m, filter, extend)` is a chapter-10 `Paint` of kind "image" that samples
  through `inverse(m)` (walk destination→source). To let it join `paint_at` without editing chapter
  10, chapter 10 gained a `PAINT_KINDS` registry (kind→sampler, mirroring chapter 2's shape
  `KINDS`); chapter 11 registers "image" into it. Minification: `downsample` (2×2 box average, which
  preserves the whole-image average), `mip_chain`, `mip_level_for(scale)`. Trap: the half-pixel
  offset. All sampling/averaging is premultiplied, in linear light.
- Chapter 12 clipping/masks/groups: a clip is a coverage buffer; `multiply_coverage(a, b)` applies
  one (commutes, so nesting is order-free; `full_clip` is a no-op). `clip_rect`/`clip_path` are
  fills that produce a clip. A soft mask is the same multiply with fractional values (`soft_mask` is
  a radial falloff). Groups reuse chapter 9's `layer`: `push_group` (a transparent layer),
  `paint_into(l, cov, col, alpha)` (a child, src-over), `scale_opacity(l, o)` (× every premultiplied
  channel), `pop_group_with_opacity(group, base, o)` (scale then composite). A group at opacity 1 is
  pixel-identical to drawing its children directly; below 1 it differs from per-child opacity at
  overlaps, because the group flattens before the opacity applies — that is Plate 12. Trap: a group
  buffer should be sized to its bounding box, not the canvas (the book keeps canvas-sized for
  readability, but says so). Runner learned the `set_layer_pixel` mutation step.
- Chapter 13 stroking: `stroke_to_path(path, width, cap, join, miter_limit)` builds the stroke as a
  UNION of primitives — a rectangle per segment, a join wedge per interior vertex, a cap per open end
  — returned as subpaths of one path filled nonzero (the inner-turn overlap winds twice, stays
  inside). No new rasterizer; the only drawing op is fill. Joins: miter (tip at `h/sin(θ/2)`, public
  `miter_length`; falls back to bevel when `miter_length/h > miter_limit`, default 4 ≈ 29°), round
  (arc radius h about the vertex), bevel (triangle). Caps: butt (nothing), round (semicircle), square
  (extend a half-width). Outer side of a turn = sign of `cross(d_in, d_out)`. Degenerate handling:
  dedupe consecutive points; a single-point subpath is a dot (round → disc radius h, square → square,
  butt → nothing); a 180° reversal bevels via the limit (miter at infinity). The plate overlays the
  generated outline in magenta (chapter 3's `line_wu`, integer endpoints, so round the outline coords)
  over the gray fill. Trap: zero-length segments / duplicates / reversals all divide by zero naively.
- Chapter 13 (revised while writing 14): two bugs survived three byte-exact reader rounds because
  the readers transcribed the figure JS. (1) The round join's arc must sweep the SHORT way from one
  outer offset point to the other (`a1 = a0 + ang_between(a0, a1)`); the long way is the inner side
  and leaves a notch, which the shipped Plate 13 had. (2) Every emitted piece must wind the same way
  (`emit` reverses any piece whose `polygon_area` is positive, so all pieces are counterclockwise on
  screen, negative area), or a rectangle and a wedge overlapping around a tight bend cancel to zero
  under nonzero and leave holes. Pinned by the `polygon_area(o) = -4981.625` and `u_turn()`
  coverage scenarios. Lesson recorded under testing: LOOK at every render (convert to PNG and view it)
  before pinning it; byte-exact reader agreement proves transcription, not correctness.
- Chapter 14 offsetting: `tangent_at`/`normal_at` (quarter turn toward +y, the right of travel on
  screen, chapter 13's +h side; a vanishing derivative at an end is nudged 1e-4 inward),
  `offset_point(c, t, d)`, `second_derivative`, `curvature = cross(v, a)/|v|^3` (positive
  clockwise, like `cross`). The offset's speed factor is `1 - curvature*d` (NOT 1 + κd: positive κ
  and positive d are both the clockwise side); `cusps(c, d)` finds its sign changes on 64 samples +
  40 bisections. `fit_offset` is one cubic through the three offset points with the curve's end
  tangents (2x2 cross-product solve; parallel tangents fall back to chord/3 handles and the error
  check catches the U-turn). `offset_error` is at 17 matched parameters (a bound, pessimistic);
  `distance_to_curve` is 65 samples + 32 ternary rounds. `offset_curve` splits at cusps then halves
  to tolerance (depth cap 16); `sub_curve` is two splits. `stroke_curve_to_path` is ONE closed
  outline (right offset forward, end cap points, left offset backward, start cap points) filled
  nonzero: the fold on the inside of a tight bend stays in the outline and nonzero fills it (verified
  pixel-for-pixel against the distance ground truth with round caps; even-odd shows the hole). No
  cusp trimming, no intersection finding. `flatten_then_stroke` is the chapter 13 way, kept for the
  trap (flatten first is fine for pixels, wrong as geometry). Paths stay polylines: a multi-curve
  path is stroked by flattening; the tiger will flatten.
- Chapter 15 dashes: `path_length` (closed subpaths include the closing segment); curve length by
  the chord table `arc_length_table(c, n)` (n explicit everywhere, 256 in the scenarios),
  `arc_length`, `t_at_length` (binary search + linear interpolation, clamped to 0/1),
  `point_at_length`, `split_at_length`. `normalize_pattern`: odd → doubled; negative entry or zero
  sum → empty → `dash` returns a copy of the path (solid). `dash(p, pattern, phase)` walks each
  subpath by arc length from its start, straight through vertices (a dash keeps its corner), restarts
  the pattern per subpath, phase taken modulo the sum (negative wraps), zero-length segments skipped,
  a zero-length dash is a single-point subpath (a dot under round caps), a dash that would begin
  exactly at the subpath's end is NOT emitted. Closed subpaths walk the closing segment; if the last
  dash ends at the start and the first begins there they are joined (last absorbs first); one dash
  covering the loop comes back closed. Plate: `golden_spiral()` (seven quarter-circle cubics, radii
  x phi, flattened into ONE subpath) dashed [16, 10], each dash stroked 7 wide round-capped.
- Chapter 13 (revised again while writing 17): a closed subpath whose last point equals its first
  (every glyph contour arrives that way from `flatten_into_path` + `close`) gave the stroker a
  zero-length closing segment and a division by zero. `stroke_to_path` now drops that last point
  after dedupe; pinned by the square-that-ends-where-it-began scenario (`polygon_area = -84`:
  four 10x2 rectangles plus four unit miter squares).
- Chapter 13 (revised again while writing 20): the arc step count for round joins and caps was
  never stated in the prose (readers could only get it from the figure JS), and a round cap's sweep
  `a0 + pi - a0` rounds to pi plus an ulp depending on the last bit of `atan2`, so `ceil(pi/(pi/16))`
  gave 16 steps on one machine and 17 on another. The rule is now in the prose and the feature:
  `n = max(2, ceil(|delta| / (pi/16) - 1e-9))`, a cap always 16 steps; pinned by the
  harbor-dash scenario (a cap Python used to make 17 steps). Chapter 15's two spiral references
  moved by at most 1 in 85 bytes; every figure script's `arcSteps` carries the epsilon.
- Font data: `reference/fonts/Roboto-Regular.ttf` (Apache 2.0, license alongside) is the source;
  `tools/ttf_to_json.py` (author-side sfnt parser: head/maxp/hhea/hmtx/cmap 4+12/loca/glyf/GPOS
  PairPos/GSUB liga) writes `reference/chapter-16/roboto.json`, 177 glyphs: printable ASCII,
  Latin-1 letters (mostly composites), their accent components, f_i and f_l. Post format 3 has no
  names, so glyph names come from the cmap (AGL names for punctuation and accents, the character
  itself for letters and digits, `uniXXXX` otherwise, ligatures `f_i`). ONE schema for chapters
  16-19 with optional sections (plan question 03): `units_per_em`, `ascender`, `descender`,
  `line_gap`, `cmap` (string codepoint → name), `glyphs` (name → `{advance, contours: [[x, y,
on]...], components: [{glyph, transform: [a, b, c, d, dx, dy]}]}`), optional `kern`
  (`[left, right, value]`, 2171 pairs, chapter 18) and `ligatures` (`[[parts], result]`, chapter
  19). The figure JS of chapters 16+ inlines a small subset (`var GLYPHS=...`, the glyphs the
  figures draw) because file:// pages can't fetch the JSON; regenerate it when a figure needs a
  new glyph (the one-off in the session scratch: names reachable from "aeéRgloHmburi" + space).
- Chapter 16 glyphs: `load_font` (Font with `glyphs[name].contours` as (x, y, on) tuples and
  `.components` as (name, [six]) pairs, `cmap` int→name), `glyph_name` (.notdef when missing),
  `glyph_advance`, `glyph_count`. `implied_points` inserts the midpoint between consecutive
  off-curve points (wrapping) and rotates to start on-curve; `contour_curves` is quadratics only
  (a straight edge is a quadratic with its control point at the chord midpoint, so every piece is
  the same shape). `component_matrix([a,b,c,d,dx,dy]) = matrix3(a, c, dx, b, d, dy, 0, 0, 1)`
  (TrueType's x' = a x + c y + dx). `glyph_outline` is font units, y up, components recursively
  through their matrices; `glyph_bounds` is the union of chapter 8's tight `curve_bounds`, (0, 0,
  0, 0) for an empty glyph. THE FLIP LIVES IN ONE PLACE: `text_matrix(font, size, x, y) =
translation(x, y) * scaling(s, -s)`; `glyph_path(font, name, m, tol)` transforms then flattens
  each quadratic (chapter 8's rule) and closes each contour; `contour_path` does one. Fill nonzero.
  After the flip TrueType's outer contours have positive `polygon_area` and counters negative;
  `ink` of the filled o equals outer minus inner exactly. Plate: the a with its control polygon.
- Chapter 17 rasterizing type: `subpixel_of(x)` → (whole, quarter) with round-to-nearest quarter
  and carry; `glyph_bitmap(font, name, size, quarter)` → `Bitmap(coverage, left, top)` sized to
  floor/ceil of the device bounds shifted by the quarter, origin at x = quarter/4 (ink identical
  across quarters, pinned); `paint_bitmap(c, bm, x, y, col, linear)` composites through chapter
  1's `mix` with the linear flag (the first named fudge: text stacks blend in encoded space);
  `glyph_cache`/`cached_bitmap` (same object on a hit)/`cache_size`; `atlas`/`atlas_add` is shelf
  packing (new shelf under the tallest so far; `none` when it doesn't fit); `embolden(font, name,
size, amount)` = fill + chapter 13 stroke of the outline, added and clamped, bitmap grown one
  pixel all round (the second named fudge, stem darkening); LCD: `LCD_TAPS = (1/3, 1/3, 1/3)`,
  `lcd_filter` (zero padding, so a row's ink is preserved), `lcd_coverage` rasterizes through
  `scaling(3, 1) * text_matrix` into a 3w buffer and filters every row (its ink is exactly 3x the
  gray ink), `paint_lcd` mixes each channel through its own stripe. `pen_advance` and a naive
  `draw_text` (advance only, no kerning) exist for the renders; chapter 18 owns layout. Trap: LCD
  assumes the physical stripe order. Hinting is deliberately absent. Runner learned
  `paint_bitmap`/`paint_lcd` mutation steps.
- Chapter 18 layout: a `Placement` is `(name, x, y)` in fractional pixels; `layout_run(font, text,
size, x, y, kerning)` places EVERY character (spaces, `.notdef`), the pen moving by the kern pair
  BEFORE each glyph after the first; `run_advance` is the total. `kern(font, l, r)` is font units, 0
  when absent, order matters. `ascent`/`descent` (positive)/`line_height` = (asc − desc + gap)·s.
  `break_lines` is greedy on spaces: a candidate fits when `run_advance ≤ measure` (pinned exactly
  on the boundary), a word wider than the measure sits alone and overflows, runs of spaces collapse.
  `layout_line(..., align, kerning)` with `"left" | "right" | "center" | "justify"`; justify spreads
  the slack over the spaces and a line with no space is laid out left; `layout_paragraph` stacks
  baselines by `line_height` from y and lays a justified paragraph's last line left, answering one
  flat list. `draw_run` goes through chapter 17 (`subpixel_of` + `glyph_bitmap` + `paint_bitmap`)
  with the baseline rounded halves-up to a row; it equals `draw_text` at whole pixels (pinned diff
  0). The kerning flag is always passed explicitly in scenarios (no default-argument scenarios, for
  readers in languages without them). Trap: `layout_run_rounded` (pen rounded per glyph) drifts 15
  px over one 11 px line of i's and l's. Plate: THROUGH_LINE four ways. Runner learned `draw_run`.
- Chapter 19 shaping: font data for Arabic is DejaVu Sans (Bitstream Vera licence, redistributable,
  `reference/fonts/DejaVuSans.ttf` + `DejaVu-LICENSE.txt`), converted by `tools/ttf_to_json.py
--arabic` into `reference/chapter-19/dejavu-arabic.json` (170 glyphs: letters, tatweel, 8 harakat,
  space, Arabic and ASCII punctuation, every init/medi/fina form, lam-alef ligatures). Chosen over
  Noto/Amiri because its init/medi/fina are plain GSUB single substitutions and its mark attachment
  is one above and one below anchor class; the Noto fonts decompose letters into skeleton + dots
  (multiple substitution), which is not a field guide. Three optional schema sections, read by the
  chapter 16 loader: `joining` (codepoint string → dual/right/none/transparent; Unicode's table
  copied into the file; tatweel recorded as dual), `forms` (glyph → {init, medi, fina} names),
  `marks` (mark → [class, x, y]) and `anchors` (base → {class: [x, y]}). Glyph names are `beh`,
  `beh.init`, `lam_alef.fina`, `kasra`; component skeletons keep `gNNNN`. Pipeline per run:
  `glyph_buffer` (one `Shaped(glyph, cluster, dx, dy)` per character) → `apply_forms(font, text,
buffer)` (form_of: joins backward when dual/right and the nearest non-transparent before is dual;
  forward when dual and the nearest non-transparent after is dual/right) → `apply_ligatures`
  (greedy left to right, longest rule first, result takes the FIRST part's cluster, never fed back)
  → `attach_marks` (base = nearest non-mark before; offset = base anchor − mark anchor; mark takes
  the base's cluster; no anchor → (0, 0) and its own cluster; no mark-to-mark stacking, said so).
  `shape` runs forms/marks only when the font has those tables, so Latin is ligatures alone.
  `itemize` cuts on script changes; common characters join the run BEFORE them (standard), which
  is what makes the trailing comma jump in `mixed_demo`: that is the bidi trap shown on purpose, not
  a bug. `position(font, buffer, size, x, y, direction, kerning)` walks the LOGICAL buffer: ltr pen
  from x rightward, rtl pen from x + advance leftward (subtract before placing), so a run always
  occupies x..x+advance; marks never move the pen and sit at base origin + (dx·s, −dy·s). No buffer
  reversal (HarfBuzz reverses instead; the chapter says so). `caret_offsets(buffer, length)` /
  `caret_positions(font, buffer, length, size, x, direction, kerning)` take the text length
  explicitly. Plate: characters-in / glyphs-out boxes with cluster joins, office and kitab side by
  side. Nothing of UAX 9/14/29 is implemented: the trap box surveys them.
- Chapter 20 SVG: the XML library is allowed; the book asks `parse_xml` (root, local names),
  `attribute` (text or none), `children` (elements only), `find_by_id` (whole document). Numbers:
  `read_number(s, i)` → (value, next) or (none, i), a second point or a sign ends a number, `e` needs
  a digit; `number_list` (whitespace + at most one comma); `read_flag` one char. `path_commands(d)` →
  absolute M L C Q A Z only (H/V→L, S/T→C/Q reflecting only after C/S resp. Q/T, repeats of M are
  L, Z resets current point, radii abs, at an error the commands so far). `arc_cubics` = chapter 8
  center form, n = ceil(|delta|/(pi/2) - 1e-6) (a quarter circle lands a hair past pi/2; pinned),
  handles 4/3 tan(d/4), exact endpoints, zero radius → one straight cubic at chord thirds.
  `build_path(cmds, m, 0.1)` transforms then flattens, drops a lone-moveto subpath. `commands_bounds`
  tight (curve_bounds). `parse_transform` degrees, left-to-right product, broken → identity.
  `parse_color` decodes sRGB bytes to linear, 17 names (HTML 4 + orange). `computed_style(el,
parent)`: 15 properties (table in §20.6), style attr beats presentation attrs, `inherit`, invalid
  ignored, url(#id) kept as text. `shape_commands` per the spec's equivalent paths (circle from the
  right point, four sweep-1 arcs). `view_box_matrix(vb, aspect, w, h)`. `transformed_paint(p, m)`
  registered in PAINT_KINDS samples at inverse(m); `paint_server` = ctm × bbox (objectBoundingBox
  default) × gradientTransform; no stop-opacity. Walker: layer, document order, fill then stroke via
  `draw_coverage`; stroke in USER space (device path back through inverse, dash, stroke_to_path,
  forward); opacity<1 or clipped group → own layer, `mask_layer`, pop_group_with_opacity; clip =
  union 1-(1-a)(1-b) of children under clip-rule in the user space of the referencing element;
  flattened over white. The reference crops fills to device bounds (identical bytes; the book's
  walker fills the whole canvas: 28 s for the tiger in Python vs 1.8 s cropped, chapter 21's
  opener). Documents: tiger.svg (from plan.html), harbor.svg and rose.svg generated by
  `tools/make_scenes.py`. Figure JS contains the whole walker (a regex XML reader stands in for the
  library) and redraws all four renders byte for byte. Runner learned `draw_coverage`.
- Chapter 21 fast: float stays. Work is counted, not timed: `stats()` {cells, blends, copies};
  `fill_path_counted` (cells += w·h), `draw_coverage_counted` (blends where k > 0);
  `render_svg_with(text, w, h, mode, st)`, mode "whole" | "bounded" | "tiled", every mode byte-
  identical to chapter 20 (pinned diff 0). `fill_bounds` = floor(min) .. floor(max)+1 cut to the
  canvas; `fill_path_bounded` shifts the path by (-x0,-y0) (coverage differs ~1e-15 from chapter 7:
  xa+xb rounds differently; scenarios use ≤ 1e-6), returns a `Window`; `coverage_in`,
  `full_coverage`, `draw_window`. Tiles 16, canvas-aligned; `classify_tiles`: outside window empty;
  partial if a cell got a NONZERO deposit, or the running sums arriving at the tile's left edge are
  not within 1e-6 of one whole n on EVERY row (a horizontal edge deposits nothing — a top-row-only
  classifier painted the harbor's hills 11 rows too far; rows outside the window arrive at 0);
  else solid iff apply_rule(n) = 1. `fill_path_tiled` resolves partial tiles only (sparse
  accumulator). `draw_tiled`: solid tile + solid paint + alpha 1 → copies (bit-identical to the
  blend), else blends; paint colour hoisted. `composite_span`/`composite_span4` (no k>0 branch,
  no FMA), `layers_equal`. Tiger: whole 61,762,500 cells / 29 s Python; bounded 1,395,287 / 1.9 s;
  tiled 816,480 + 207,872 copies. Measured truth vs the plan: bounds is the big win (44x), tiles
  1.7x on the tiger, 2.8x on the harbor; the chapter says so. Whole mode blends ~850k pixels of
  coverage ~1e-16 (running-sum crumbs) — the trap. Plate: `work_map()` 910x450, tiger + per-tile
  partial/solid counts from `tile_work`. Figure JS = chapter 20 walker with an onFill hook +
  classify port, byte-exact.
- Chapter 22 booleans: every coordinate snapped to 1/256 px (`grid(v) = floor(v*256+0.5)`), held as
  whole grid units within +-1024 px, so `orient` is exact even in doubles. `seg(a, b, wa, wb)` stores
  lo/hi in the sweep order (`lex_less`: y then x) and re-signs the windings when it swaps. `meet(s, t)`
  kinds none/end/cross/touch/overlap with split lists; `crossing_point` is the EXACT crossing rounded
  halves up by `(2N + beta) div 2beta` (64-bit; N ~ 2^59). `split_segments` = merge, find, cut (split
  points ordered by dot(q - lo, hi - lo)), merge, repeat until a pass finds nothing (the pass that finds
  nothing is counted; the 3-segment example (2,0)-(10,12), (9,0)-(6,7), (7,4)-(3,7) needs 3 passes).
  `merge_segments` sums windings, drops (0,0), sorts by lo then hi. Classification `winding_beside` is
  chapter 5's winding_at at the doubled midpoint with the half-open rule in lex order and f counting when
  orient(f.lo, f.hi, m) > 0; first pair is the side where the segment doesn't count, second adds its own
  windings (its left, or below when horizontal). `keep_edges` directs kept edges inside-on-the-right
  (clockwise). `stitch`: first unused pair in sweep order, at each vertex the unused edge turning furthest
  right, stop at the start vertex, drop collinear vertices, rotate to topmost-then-leftmost, sort
  contours: results are canonical so scenarios compare point lists. Three finders give identical splits:
  "brute" (every pair), "sweep" (active list, drop hi not after s.lo), "bentley-ottmann" (ordered status,
  exact rational events (X/D, Y/D) needing ~100-bit compares, the textbook U/L/C handling, tests only
  neighbours; `sweep_stats()` counts tests/events/passes, pinned). `combine(a, ra, b, rb, op)` ops
  union/intersection/difference/xor; `simplify(p, rule)`. Plate: Roboto g (nonzero) vs chapter 5's
  star (even-odd) four ways; demo `seal()` is 61 combines. Benchmark `struck_line(n)`. Trap:
  `float_crossing` lies on neither segment; the grid moves crossings by <= 1/512 px.
- Chapter 23 fields: negative inside; `clamp(0.5 - d)` is coverage. `sd_polygon` signs by winding_at
  (so a self-crossing nonzero path has buried edges: simplify first, pinned). Quadratic distance exact via
  `solve_cubic`; cubic by Newton from nine seeds PLUS both ends (without the ends a scenario fails).
  Chapter 14's `distance_to_curve` is fooled by looping cubics (pinned as >= 5.4 vs the true 5.379229);
  chapter 23's `brute_distance` refines every local-minimum sample, and `weyl_points` (R2 sequence) makes
  the 10,000 test points. Field ops are one line each; `smooth_min` polynomial. EDT is Felzenszwalb with a
  finite far value w^2 + h^2 (exact, equals brute force). Atlases: `bake_box` is chapter 17's box grown
  by spread; SDF/MSDF/MTSDF; edge colouring (corner = dot <= 0 or |cross| > sin 3; none -> white; one ->
  cyan/white/magenta thirds; more -> alternate cyan/magenta, odd -> last yellow); per channel nearest by
  true distance with the orthogonality tie-break at ends, then pseudo-distance; no error-correction pass
  (it changed almost nothing; strokes under ~2 texels notch, shown with k at 16 px). Glows/shadows read
  the MTSDF true channel (the median makes far-field false edges). Trap: min is not the union's field
  inside (the peanut shrunk by 20 splits in two). Renders are slow in Python (~2 min for the plate
  feature); every figure script redraws all nine byte for byte.
- Chapter 24 GPU: `stencil_buffer(p, w, h, ox, oy)` adds `triangle_winding(anchor, a, b)` (chapter 5's
  half-open rule per triangle) over each triangle's bbox; spokes cancel so it EQUALS winding_at at every
  pixel (pinned: 0 mismatches). Loop–Blinn: (u, v) = (s/2 + t, t) from barycentrics, inside_curve is
  s > 0 and u^2 - v < 0, glyph = chord fan + signed curve slivers; equals the 0.001-flattened glyph at
  every pixel. MSAA patterns 1 / 4 (D3D rotated) / 16 (rooks, y = (5k + 3) mod 16) / 64 (ch2 grid);
  on the sliver 64 regular == 16 rotated (0.0375). Pipeline: `encode_svg` = chapter 20 walker emitting
  Fill/Push/Pop (clip parts as (device path, rule)); stages flatten/bin (deposits in segment order,
  filed by tile)/coarse (chapter 21 classification + arriving sums read from bins to the left;
  `cull_groups` drops empty push/pop per tile)/fine (per-tile block stack). Byte-identical to chapter
  20 for tiger/harbor/rose, and under `lcg_shuffle` (Fisher–Yates, x <- (1103515245x + 12345) mod
  2^31: needs 64-bit, JS needs BigInt). Unhappy path: STACK_DEPTH = 2 blocks incl. the tile's own;
  rose spills 200. Paint is already a shader (`shade_tile`). Demo: tiger assembled in shuffled order.
- Chapter 25 raster editor (bonus B, one chapter): brush dab profile (hard inside hardness*r, linear to
  r), `stamp_positions` spaced by arc length (spacing*2r, leftover carried), stroke mask builds up
  1-(1-m)(1-flow k), opacity caps; `flood_mask` scanline stack (8-conn reaches one further),
  tolerance per channel in bytes, `select_color`, `anti_alias_mask` (outside 4-neighbours get 0.5),
  `naive_depth` shows recursion = area. `median_cut` over DISTINCT colours weighted by count (cut
  where 2*running >= total, never after the last), palette = weighted mean rounded halves up; dithers
  in LINEAR light (threshold, ordered via ch10 Bayer on green, Floyd–Steinberg 7/3/5/1). 8-bit BMP:
  offset 1078, bottom-up rows padded to 4, palette BGR0, colours-used = palette length. Selections are
  coverage (union/subtract/intersect, box-blur feather); floating layer premultiplied; `History`
  saves rectangles, redo cleared by a new edit. Dab distance uses sqrt(dx*dx+dy*dy), not hypot.
  Runner learned move_floating/drop_floating/history_fill/undo/redo.
- Runner learned `≥`. Figure JS `mag` must be `sqrt(x*x+y*y)` to mirror chapter 4's `magnitude`
  (Math.hypot differs in the last bit and flipped one byte of the spiral).
- Gherkin data tables are allowed for matrices only: `Given the following matrix M:` and
  `Then X is the following matrix:`. The runner understands exactly those two table steps.

## Testing a chapter with reader agents

Before declaring a chapter done, have subagents implement it cold, as readers:

1. Stage an isolated scratch directory per agent with `./tools/readers.py stage <lang> <N> <dir>`:
   the language's existing code from `readers/<lang>/`, the built chapters 1..N, their feature
   files and reference images. Nothing else: no `plan.html`, no reference implementation, no other
   agents' work. **Tell the agent, in so many words, that the book's repository exists elsewhere on
   this machine and it must not read or write it**, and give only the absolute scratch path. Two
   haiku agents in the chapter-2 round found `readers/<lang>/` in the repo, worked there instead,
   and one consulted `reference/impl/`; their feedback for that round is compromised. After a
   round, run `git status` before committing anything and treat any change under `readers/` that
   you didn't collect yourself as contamination.
   1b. Collect with `./tools/readers.py collect <lang> <N> <dir>`: code comes back to
   `readers/<lang>/`, `FEEDBACK.md` goes to `readers/feedback/chapterNN-<lang>.md`, renders and
   copies of the book do not come back. Every reader's README must run its tests from its own
   directory, which the staging layout satisfies.
   1c. The prompt is `tools/reader_prompt.md`; fill in the placeholders rather than improvising.
   Ten agents at once can hit the org's monthly spend limit mid-round (the chapter-4 round lost
   seven of ten that way, four of them after their code was complete). Check the limit before a
   round, launch in two waves, and collect each reader the moment it finishes. A reader cut off
   after its tests pass can still be collected: run its suite yourself, revert any mutation it
   left in place, and leave a note in its feedback file saying the feedback is the author's.
2. Spread agents across model tiers (haiku, sonnet, opus 4) and language families (dynamic, managed,
   systems). Tell them to translate every scenario, write the renders to `out/` with the
   reference filenames, and write a candid `FEEDBACK.md` (ambiguities, hard-to-translate steps,
   failures with actual vs expected, prose problems, concrete changes).
3. Diff their `out/*.ppm` against `reference/` with `max_channel_difference`. Anything > 1 is a
   bug in the chapter, the reference, or the agent; find out which.
4. Every ambiguity two or more agents report is a chapter bug. Fix the prose or the scenario,
   re-sync, re-run the reference runner, and re-test.
5. Run a second round in languages no first-round agent used, so the fixes are tested cold.
   5b. **Catch-up pass.** Fixes from a round add scenarios that the already-collected readers never
   saw. Before the next chapter, stage every reader again at the current chapter and run a small
   "bring the tests up to date with features/, fix what fails, say what failed" agent per
   language. A new scenario that fails previously-green reader code is the strongest evidence a
   scenario earns its place (the zero-length `thick_line` was a division by zero in every
   implementation). Opus agents are capped by the org's monthly limit; use sonnet for catch-ups.
   5c. If the session's scratch directory disappears, agents' unfinished work is lost with it.
   Collect finished readers promptly, and stage new runs under `${TMPDIR}2d-readers/`.
6. Ask agents to try to break the suite ("find a wrong implementation that still passes"). The
   most valuable round-1 finding came from an agent doing that unprompted.
7. **Look at every render before pinning it.** Convert the PPM to PNG (a 20-line stdlib script:
   zlib + the PNG chunk format) and view it with the Read tool, zoomed where the geometry is
   fiddly. Plate 13 shipped with a notch in its round join and holes waiting in every wide stroke
   around a tight bend, and three readers matched it byte for byte, because they transcribed the
   figure JS (see the memory note on the JS leak). A reader round measures agreement with the
   reference, not the reference's correctness; only eyes and an independent ground truth (chapter
   14's `distance_to_curve` check) do that. Run the figure JS under node against the PPMs too
   (`scratchpad/jscheck.js` pattern: stub `Plate`, eval the script, diff the bytes).

## Git

- No `Co-Authored-By` trailers of any kind.
- Commit as work lands. Never push unless explicitly asked.
- Before committing: `./reference/impl/run_features.py && ./tools/sync_features.py --check`.
