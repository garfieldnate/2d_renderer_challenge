# The 2D Renderer Challenge — working notes for Claude

A test-driven book that builds a 2D vector renderer from nothing, modeled on *The Ray Tracer
Challenge*. Read `plan.html` (the outline and writing guide) and `README.md` before touching
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
- **Chapter-end programs are printed** as short pseudo-code (30 lines or fewer) *and* pinned by
  a scenario. Pseudo-code ranges are inclusive at both ends, and the chapter says so.
- **No exercises section.** Anything that would have been an exercise becomes a numbered
  section with its own scenario and figure, or it is cut.
- **Nothing is left implicit that a reader in a different language could get wrong.** Rounding
  mode, clamping order, line-wrapping rule, default state of any global switch, what happens
  out of bounds: all stated in prose *and* pinned by a scenario.

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

Casual, funny, second person, contractions. Never *simply*, *just*, *obviously*, *trivially*,
*of course*, *clearly*, never *we* meaning *you*, no exclamation marks. Open on a concrete
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
- Chapter 4 follows *The Ray Tracer Challenge*'s names: `point(x, y)` has `w = 1`, `vector(x, y)`
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
2. Spread agents across model tiers (haiku, sonnet, opus) and language families (dynamic, managed,
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
