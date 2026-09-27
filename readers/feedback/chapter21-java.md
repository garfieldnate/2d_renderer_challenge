# Reader feedback: Java, chapters 20-21

Cold read of chapter 20 (Rendering SVG) and chapter 21 (Making It Fast) from the chapter text
and the `features/chapter20-*.feature` / `features/chapter21-*.feature` scenarios alone, on top
of the existing chapters 1-19 code in this directory. I did not read the book's own repository,
another reader's code, or `reference/impl/`; everything below comes from `chapter-20.html`,
`chapter-21.html`, the feature files, and running the suite in this directory.

## Result

Every scenario in `features/chapter20-*.feature` and `features/chapter21-*.feature` is
translated and green, one for one -- no scenario skipped, weakened, or special-cased:

| Chapter | Feature file | Scenarios |
|---|---|---|
| 20 | chapter20-numbers | 5 |
| 20 | chapter20-pathdata | 12 |
| 20 | chapter20-building | 10 |
| 20 | chapter20-document | 3 |
| 20 | chapter20-shapes | 6 |
| 20 | chapter20-transform | 6 |
| 20 | chapter20-style | 7 |
| 20 | chapter20-viewbox | 7 |
| 20 | chapter20-paint | 8 |
| 20 | chapter20-groups | 8 |
| 20 | chapter20-walker | 8 |
| 20 | chapter20-plate | 3 |
| **20 total** | | **83 / 83 passed** |
| 21 | chapter21-bounds | 3 |
| 21 | chapter21-counting | 3 |
| 21 | chapter21-tiles | 6 |
| 21 | chapter21-spans | 3 |
| 21 | chapter21-simd | 2 |
| 21 | chapter21-plate | 4 |
| **21 total** | | **21 / 21 passed** |

Chapters 1-19: all 693 previously-existing scenarios still green (nothing in chapters 20/21's
new shared-file edits disturbed them; see Catch-up below for the one real fix chapters 1-19
needed).

Renders, `max_channel_difference` against `reference/`:

| Render | Diff |
|---|---|
| `aspect_demo.ppm` | 0 |
| `harbor.ppm` | 0 |
| `rose.ppm` | 0 |
| `tiger.ppm` (also `plate_20()`) | 0 |
| `work_map.ppm` (also `plate_21()`) | 0 |

All five diff exactly 0, not just within the scenarios' own `<= 1` budget. I converted each to
PNG and looked at it (tiger, harbor, rose, aspect_demo, work_map) before trusting the byte
match: the tiger has its stripes, whiskers, green eyes and pink mouth in the right places;
`work_map.ppm`'s tile grid traces the tiger's silhouette in magenta with a scatter of cyan
solid-fill tiles; harbor is a night harbor scene with moon/sun/lighthouse/sailboat; rose is a
12-fold rose window; `aspect_demo` is the same little house-with-sun-and-mountain drawing fit
five different ways, two of the five leaving white letterboxing. Nothing looked like a
transposed axis or a doubled/missing pass.

## Catch-up

Per the instructions, I brought the existing chapter 1-19 code up to date with `features/`
before starting chapter 20. Diffing the feature files against `Chapter13Tests.java` by hand
(there's no automated cross-check in this Java setup) turned up exactly one gap:
`chapter13-stroke.feature`'s "A round cap is a semicircle of sixteen steps, whatever the
rounding" scenario had never been translated -- `Chapter13Tests.java` had 22 registered
scenarios where the feature files now total 23. Translated it (a stroked near-zero-length
segment at an odd angle, `stroke_to_path(seg, 0.8, "round", "miter", 4.0)`, pinning both cap
subpaths at exactly 17 points): it passed immediately on the existing `Stroke` code, so this
was a missing test, not a bug. All 23 chapter 13 scenarios are green now.

I checked chapter 15 for the "reference images changed by at most 1" note too: the existing
code's `spiral-dashes.ppm`/`plate-15.ppm` already diff by <= 1 against the current
`reference/chapter-15/*.ppm` (documented in the README's own chapter 15 section from a prior
round), and no chapter 15 scenario was missing (28 scenarios in `features/`, 28 already
registered). No change needed there.

I did not re-run the full reader-testing protocol (staging fresh copies, `tools/readers.py`,
etc.) since that infrastructure isn't present in this scratch directory and the task was scoped
to catch-up + chapters 20/21.

## Ambiguities

- **Chapter 20 redefines `flatten_into_path` and this isn't said anywhere in prose.** Chapter
  8's own `flattenIntoPath` (used unchanged by chapters 9-19) appends every point of
  `flatten(c, tol)`, including the curve's own first point, to the path with `line_to` --
  concretely, `Curves.flattenIntoPath` in this codebase does not deduplicate. Chapter 20's own
  figure JS (`chapter-20.html`, in the shared helpers `Plate.source` lists) defines a
  *different* `flattenIntoPath` that explicitly drops the flattened curve's first point when it
  equals the path's current point. The two happen to agree whenever a curve is the only thing
  in its subpath, which is most of chapters 8-19's own scenarios, so the discrepancy stayed
  invisible until chapter 20 pinned exact point counts for a path built from more than one
  curve command in a row (an arc split into two cubics, or back-to-back `Q`s): `length(subpaths(
  build_path(path_commands("M0 0 Q10 0 10 10"), identity(), 0.1))[0].points) = 13` and `length(
  subpaths(build_path(path_commands("M0 0 A5 5 0 0 1 10 0"), identity(), 0.1))[0].points) = 17`
  both failed by exactly the number of curve-to-curve joins in the path (1 and 2) until I wrote a
  chapter-20-local `flattenIntoPathNoDup` in `SvgBuilder.java` matching chapter 20's own JS
  instead of reusing `Curves.flattenIntoPath`. I did not touch the shared `Curves.flattenIntoPath`
  itself, since chapters 8/16 pass with the duplicate and the chapter 16 section of this same
  README already documents that duplicate as accepted (a zero-length edge, "harmless"). **This
  is worth stating in the chapter's own prose**: a reader who ports `flatten_into_path` once in
  chapter 8 and reuses it everywhere (which every other chapter's own text explicitly invites,
  "built directly on chapter 8's ... flatten") will get chapter 20's own pinned point counts
  wrong, silently, with no scenario pointing at *why* -- the failure just says "expected 13 got
  14" with no hint that the fix is a different `flatten_into_path`, not a bug in `build_path`'s
  walk.
- **`fill_bounds`'s empty check.** The feature prose says "(0, 0, 0, 0) for an empty path", and
  I first read that as "a path with no edges" (matching chapter 5/6's own convention that a
  subpath under two points contributes no edges). The actual chapter 21 JS checks `!p.length`
  (no *subpaths*, not no edges) before computing `pathBounds`, which itself walks every point of
  every subpath regardless of length -- so a lone single-point subpath (which does happen: a
  degenerate cap, or a stroke of a zero-length segment) has a real, nonempty bounding box (a
  single point) and must count toward the window. I initially used `p.edges().isEmpty()`, which
  is wrong (see Failures below); fixed to `p.subpaths().isEmpty()`. The feature's own prose
  doesn't distinguish these two readings, and both give the same answer on every literal
  scenario in `chapter21-bounds.feature` -- only "the tiger, bounded" (`st.cells = 1395287`)
  actually exercises a real single-point subpath somewhere in the tiger's ~300 shapes and
  catches the wrong reading. See Failures.
- **`work_map()`'s tile-square inset at the grid's own edge.** The prose says "each inset one
  pixel from its tile's edges (the tile's first and last row and column are left as paper)" and
  doesn't say what happens when a tile is short (the last row/column of the 29x29 grid is only 2
  pixels, since 450 = 28*16 + 2). My first reading computed the inset against the tile's *actual*
  clipped pixel size, which makes a short tile's inset range empty (nothing to draw) --
  wrong: the reference clearly paints an inset square there too (`ppm_pixel(p6, 637, 449)` and
  neighbours). The fix was to always use the *nominal* 16-pixel square for the inset (`dx, dy`
  from 1 to 14 inclusive) and let the canvas's own "writes outside the canvas are silently
  ignored" rule clip the parts that fall off -- exactly the mechanism chapter 1 already commits
  to, just not mentioned in this section's own prose. I'd add one sentence saying so.

## Hard to translate

- **`shape_commands`/`build_path`/`view_box_matrix` all read a document element's attributes as
  free-form text and default/validate per-attribute** (`§20.2`, `§20.6`, `§20.7`, `§20.8`).
  Nothing here was hard to translate as such, but it's a lot of small, independent parsing rules
  (percentages vs bare numbers, `px` suffixes that mean nothing, clamped/monotonic gradient
  offsets, `read_flag` needing no separator) that don't compose the way earlier chapters'
  functions did -- I ended up with `SvgStyle.parseProperty` as one large `switch` over property
  names rather than the generic table-driven loop the reference JS uses (`for (k in PROPS)`),
  since Java doesn't have an easy generic "get/set property by string name on a typed struct"
  without reflection; I wrote small `getProp`/`setProp` dispatchers instead, which is more code
  than the JS but no different mechanically.
- **`javax.xml`'s namespace handling** doesn't match the book's "local name, whatever the
  prefix" rule directly if you turn namespace-awareness on (an undeclared prefix like `s:` in
  `<s:svg xmlns:s='...'>` parses fine either way, but I didn't want to depend on the namespace
  URI resolving correctly for every test document). I parsed with `setNamespaceAware(false)` and
  stripped everything up to and including a `:` in the raw tag/attribute name myself, matching
  the chapter's own regex-based reference parser's `local(n)` helper exactly, rather than
  trusting the DOM's own `getLocalName()`. This is a deliberate implementation choice, not a
  gap, but another reader relying on `getLocalName()` with namespace-awareness on on a document
  where a namespace prefix is *used but not declared* (not tested by any scenario here) could
  get a different, possibly-throwing, result.
- Nothing in chapter 21 was hard to translate; it's arithmetic and bookkeeping on machinery
  chapters 1-20 already built. The one genuinely new data structure, `TiledCoverage`, needed a
  little care because the scenarios read it two ways -- generically through `coverage_in`
  (any pixel, dispatched by type) and specifically through `draw_tiled` (tile by tile, for the
  copy/blend counting) -- and those two paths must agree pixel-for-pixel without duplicating the
  tile-resolution logic. See the mutation-testing note below for where I initially only wired up
  one of the two paths correctly.

## Failures (found and fixed before this feedback was written)

1. **`fill_bounds` used `p.edges().isEmpty()` instead of `p.subpaths().isEmpty()` as its "empty
   path" check.** Actual: `Bounds: the tiger, bounded` scenario's `st.cells` was `1395286`,
   expected `1395287` -- off by exactly one cell, i.e. exactly one shape's fill or stroke
   resolved a 1-pixel-smaller (or absent) window than it should have. Root cause: somewhere in
   the tiger's ~300 paths, a stroke or fill produces a path with a lone single-point subpath
   (no edges, but a real point), and my `fillBounds` treated that as "nothing to fill" (matching
   my own edges-based intuition, not the reference's subpaths-based one), returning
   `(0,0,0,0)` and skipping the one pixel that point's own tiny bounding box should have
   contributed to the window's cell count. Fixed by changing the guard to check
   `p.subpaths().isEmpty()`. Author's fault (ambiguous prose, not caught by any narrower
   scenario) as much as mine; see Ambiguities.
2. **`Figures.workMap()`'s tile-square inset computed against the tile's clipped (not nominal)
   pixel size**, leaving the last tile row/column's inset region empty. Actual:
   `max_channel_difference(p6, ref)` was `82` at `(637, 449)` and 27 other pixels, all in the
   canvas's last row (`y = 449`, the short edge of the 29-tile grid). Expected: those 28 pixels
   should show a colored (magenta) inset square like every other tile with the same partial
   count; mine left them paper. Fixed by using the nominal 16-pixel tile size for the inset loop
   bounds unconditionally and letting `Canvas.writePixel`'s existing off-canvas silent-drop rule
   clip the parts that don't exist. See Ambiguities.

Both were caught by the render/plate scenarios' own whole-image `max_channel_difference`
check, not by any narrower unit-style scenario -- consistent with this project's own standing
note (`CLAUDE.md`'s "look at every render") that the coarse check is sometimes the only thing
that catches a real bug.

## Prose problems

- §20.4 ("From commands to a path"): as covered above, doesn't say chapter 20 uses its own
  `flatten_into_path`, different from chapter 8's. A single sentence next to "C and Q are
  cubics and quadratics from the current point, taken through m and then flattened into the
  path" -- something like "flattening here drops a curve's own first point when it lands on the
  path's current point, so consecutive curves don't leave a zero-length edge at the join" --
  would have saved the bounce.
- §21.5 ("the plate", `chapter21-plate.feature`'s own prose) doesn't say what to do for a short
  edge tile's inset square; see Ambiguities and Failures #2.
- Everything else in chapter 20/21's prose I could check against a scenario checked out exactly
  as written; I didn't find a claim that was flatly wrong the way earlier chapters' README
  entries describe (e.g. chapter 15's `lopsided()` control points, chapter 13's round-join
  sweep direction). Chapter 20 in particular is unusually generous with exact pinned numbers in
  its own feature-file prose (colour bytes, gradient math, viewBox alignment factors) -- I
  didn't have to guess a single geometric constant the way chapter 12's `clip_demo()` forced the
  previous reader to reverse-engineer from the figure JS.

## Mutation results

Five deliberate mistakes, each undone immediately after checking:

| # | Mutation | Caught by | Result |
|---|---|---|---|
| 1 | `parse_transform`'s `matrix(a b c d e f)` built row-major (`matrix3(a,b,c,d,e,f,...)`) instead of column-major | `Transform: matrix lists its six numbers column by column` | caught (1 scenario) |
| 2 | `view_box_matrix` swapped `min`/`max` for `meet`/`slice` | `ViewBox: meet fits...`, `...alignment words...`, `...slice fills...`, `...origin moves...`, `...five ways to fit it` (the render) | caught (5 scenarios) |
| 3 | `rect`'s rounded-corner `rx`/`ry` clamp to half the side removed | `Shapes: a corner radius is at most half a side, and one radius stands for both` | caught (1 scenario) |
| 4 | `Tiles.drawTiled`'s "look up a solid paint's colour once per tile" applied to *any* paint, not just a solid one (i.e. a gradient on a fully-covered tile would sample only its top-left corner instead of every pixel) | `Plate: the harbor and the rose, every way, byte for byte` (`harbor tiled` diverges from `harbor` rendered the ordinary way) | caught -- I expected this one to slip through (none of `chapter21-spans.feature`'s own scenarios use a gradient), but harbor.svg happens to have a gradient-filled shape landing on at least one fully-solid tile, and the byte-for-byte cross-check with chapter 20's own `render_svg` catches it anyway |
| 5 | `fill_path_bounded` skipped shifting the path by `(-x0, -y0)` before accumulating (filled it in the window's own small buffer using the *original*, un-shifted coordinates) | `Bounds: a bounded fill resolves only its window...`, `Bounds: the tiger, bounded`, `Plate: the harbor and the rose, every way, byte for byte` (`harbor bounded`) | caught (3 scenarios) |

**The one mutation that passed every scenario** (the most useful finding, per the task's own
instructions): transposing `TiledCoverage.coverageAt`'s tile lookup from `classes[ty][tx]` to
`classes[tx][ty]` (and the matching `partials[...]` lookup) passed all 83 chapter 20 scenarios
and all 21 chapter 21 scenarios, including every render's `max_channel_difference` check and
every exact `st.cells`/`st.copies`/`tile_work` count. Root cause: `coverageAt` is *not* on the
hot path the actual renders exercise -- `SvgWalker`'s real drawing goes through
`Tiles.drawTiled`, which reads `t.classes[ty][tx]`/`t.partials[ty][tx]` directly rather than
through `coverageAt`. The only things that call `coverageAt` (via `Coverage.coverageIn`/
`fullCoverage`) are the `coverage_in`/`full_coverage` scenarios themselves and the
shape-level-clip fallback path (never exercised by harbor/rose/tiger, since their only
clip-paths are on `<g>` elements, handled by a different code path entirely). And the one
scenario that *does* call `coverage_in` on a real `TiledCoverage`
(`chapter21-tiles.feature`'s "Only partial tiles are resolved...") happens to use a square
(`polygon(4,4; 60,4; 60,60; 4,60)`) that's symmetric under x/y transposition, so querying
`(30, 30)`, `(2, 2)`, `(4, 30)` can't tell `classes[ty][tx]` from `classes[tx][ty]` apart. I
confirmed the bug is real (not just theoretically) with an ad hoc asymmetric probe shape outside
the test suite (a wide-but-short rectangle): `coverage_in` at a point in an actually-partial tile
came back `0` instead of a fractional coverage, and at another point it threw a
`NullPointerException` reading `partials[ty][tx]` for a tile whose *transposed* cell had never
been resolved. **Concrete suggestion**: `chapter21-bounds.feature`'s or `chapter21-tiles.feature`'s
`coverage_in`/`full_coverage` scenarios should probe an asymmetric shape (different width and
height, the same lesson chapter 5's own testing notes already give for the canvas size rule:
"a shape that's symmetric under x<->y can't detect a transposed writer, and doesn't need to").
I did not add such a scenario myself (out of scope for a reader), but flagging it here since the
task explicitly asks for this exact kind of finding.

## Concrete changes I'd make

1. State chapter 20's own `flatten_into_path` redefinition in §20.4's prose (see Prose problems).
2. State the short-tile inset rule in §21.5 (see Prose problems).
3. Add an asymmetric-shape probe to one of chapter 21's `coverage_in`/`full_coverage` scenarios
   on a `TiledCoverage`, for the reason given in Mutation results.
4. Minor, not a bug: `fill_bounds`'s prose ("(0, 0, 0, 0) for an empty path") could say
   explicitly "a path with no subpaths" rather than leaving "empty" to be inferred, since chapter
   5 already trained readers to think of "no edges" (a subpath under two points) as the natural
   reading of "nothing there," and that reading is wrong here.

## Timing

Wall-clock, this machine, JIT-warmed (one throwaway call, then the average of 5), no other load
controlled for -- exactly the kind of number the chapter says not to trust across machines, given
only for interest:

| Render | Time |
|---|---|
| `harbor()` | 241 ms |
| `rose()` | 278 ms |
| `tiger()`, mode `"whole"` (chapter 20 as written) | 422 ms |
| tiger, mode `"bounded"` | 56 ms (7.5x faster than whole) |
| tiger, mode `"tiled"` | 225 ms (1.9x faster than whole) |
| `workMap()` (renders the tiger tiled once, plus `tile_work`'s own full second pass) | 472 ms |

The counted-work numbers (`st.cells`/`st.blends`/`st.copies`, all pinned exactly by the
scenarios) tell the real story better than wall-clock does, per the chapter's own point: mode
`"whole"` resolves `61,762,500` accumulator cells for the tiger (`303` shapes/strokes times
`202,500` cells each, chapter 7's "resolve the whole canvas whatever the path" cost paid every
time); `"bounded"` cuts that to `1,395,287` (a 44x reduction in cells resolved, only a 7.5x
wall-clock win here since cell-resolution isn't the only cost -- path building, stroking and
`Layer` painting are unchanged between modes and dominate more as the counted work shrinks);
`"tiled"` resolves `816,480` cells (fewer than bounded, since bounded still resolves every
cell of its rectangular window while tiled skips whole solid/empty tiles inside that
rectangle too) and turns `207,872` of the pixels it does write into plain copies instead of
blends. My own work-counter numbers agree exactly with the pinned scenario values in every
case (`61,762,500` / `1,395,287` / `816,480` + `207,872` copies), so I trust the chapter's
own implied ordering (`whole` > `bounded` > `tiled` in work done) is exactly right; my
wall-clock ordering agrees (`tiled` and `bounded` both beat `whole`) but doesn't show `tiled`
beating `bounded` in wall time the way the cell counts alone would suggest, because per-tile
bookkeeping (classification, the row-prefix-sums table) and the `Solid`-paint copy fast path
have their own fixed costs that a 64-pixel accumulator resolve in `"bounded"` mode doesn't pay.
