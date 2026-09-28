# Reader feedback: chapters 24-25 (Python)

This is a cold read of chapter 24 ("Doing It the GPU's Way") and chapter 25 ("The Raster Editor
Detour") on top of the existing Python implementation of chapters 1-23. Everything below is from
implementing the chapters from the prose and the `.feature` files alone, with no access to the
book's own repository or reference implementation.

## Result

- Chapter 24: 24/24 scenarios pass across `chapter24-loopblinn.feature`, `chapter24-msaa.feature`,
  `chapter24-pipeline.feature`, `chapter24-plate.feature`, `chapter24-shader.feature`,
  `chapter24-stencil.feature`, `chapter24-unhappy.feature`.
- Chapter 25: 25/25 scenarios pass across `chapter25-brush.feature`, `chapter25-flood.feature`,
  `chapter25-plate.feature`, `chapter25-quantize.feature`, `chapter25-select.feature`.
- Combined with the existing scenarios from chapters 1-23, the full suite is **876** scenarios, all
  green (`python3 test_runner.py`; `Total: 876, Passed: 876, Failed: 0`). Chapters 1-23 actually
  hold 827 scenarios, not the 826 this repository's README stated before this pass — a
  one-scenario drift left over from before the chapter 22-23 catch-up pass, whose own commit
  message says "827 scenarios green" while the README's summary line was never updated to match.
  827 + 24 + 25 = 876; fixed the README's count as part of this pass (see Catch-up).
- Every render matches its reference at `max_channel_difference` 0 (not just the `<= 1` the
  scenarios themselves ask for):

  | Chapter | Render | max_channel_difference | Time to render |
  |---|---|---|---|
  | 24 | `plate-24.ppm` | 0 | 0.69 s |
  | 24 | `msaa-demo.ppm` | 0 | 0.84 s |
  | 24 | `spill-map.ppm` | 0 | 3.33 s |
  | 24 | `tiger-assembly.ppm` | 0 | 4.08 s |
  | 25 | `plate-25.ppm` | 0 | 0.53 s |
  | 25 | `dither-strip.ppm` | 0 | 0.09 s |
  | 25 | `halo-demo.ppm` | 0 | 0.58 s |
  | 25 | `brush-demo.ppm` | 0 | 0.18 s |
  | 25 | `paint-by-script.ppm` | 0 | 2.34 s |

  None of these needed reverse-engineering from the reference PPM the way chapter 12's
  `clip_demo` did — the prose for both chapters states every geometric parameter (coordinates,
  colours, brush settings, sample counts) precisely enough to transcribe directly, and every one
  of the nine renders matched byte-for-byte on the first attempt once the underlying algorithm
  scenarios were green. That is a real change in how these two chapters are written compared to
  some of the earlier ones, and it shows in how little guessing this pass needed (see
  Ambiguities).

## Catch-up

Chapters 1-23's own scenarios were run, unmodified, before writing a line of chapter 24 or 25 code,
specifically to separate "existing bug this pass tripped over" from "new chapter, new scenario."
All of them (827, not the README's stated 826 — see Result) passed as they stood. So there was
nothing to fix in the existing chapters — every scenario chapter 24 and 25 needed was new, and no
earlier render's bytes moved. The README's summary line was simply never updated after the
chapter 22-23 catch-up pass landed at 827; fixed it here since it's a one-word count, not a code
change.

Two small gaps surfaced in the *existing* API while writing chapter 24's own scenarios, neither a
bug in previously-passing behaviour, both because chapter 24 is the first caller to exercise them
this way:

- `radial_gradient(c0, r0, c1, r1, stops, mode)` had no default for `mode`, but
  `chapter24-shader.feature`'s "A gradient asked in any order is the same gradient" scenario calls
  it with five arguments: `radial_gradient(point(20, 20), 0, point(40, 30), 50, [stop(0,
  color(1, 0, 0)), stop(1, color(0, 0, 1))])`. Every other chapter (10, 20, ...) always passed all
  six. Gave it `mode="pad"` to match the default extend mode used everywhere else in the book;
  this is additive (every existing six-argument call site is untouched) and chapters 1-23's own
  827 scenarios still pass unchanged.
- `max_group_depth(commands)` is defined once but is asked, across the chapter's own scenarios, to
  walk two different shapes of list: a scene's own `Push`/`Pop` command *objects* (as in
  `chapter24-unhappy.feature`'s `max_group_depth(rose.commands)`, where `rose` is a `Scene`) and a
  tile's `("push", ...)`/`("pop",)` *tuples* (implied by the chapter's own prose describing the
  same walk over a tile's command list, though no scenario happens to call it that way). It checks
  `isinstance` for both shapes rather than assuming one.

## Ambiguities

- **`inside_curve`'s domain.** The scenario "The control points carry (0, 0), (1/2, 0) and (1, 1)"
  pins `loop_blinn_uv(quadratic(point(0, 0), point(5, 0), point(10, 0)), point(3, 1)) = none` for
  a *degenerate* (collinear) quadratic. The prose says `loop_blinn_uv` is `none` "when det = 0",
  which is unambiguous, but it left me checking by hand whether `curve_terms`/`loop_blinn_stencil`
  needed a separate guard for this case too (they do, and already have one — a curve with
  `det == 0` is skipped entirely in the sliver pass, per "for every curve with det != 0").
- **Invalid `clip-path` references inside `encode_svg`.** Chapter 20's `clip_coverage` treats a
  `clip-path` that doesn't resolve to a real `<clipPath>` (a `url(#nonexistent)`, or a reference to
  something that isn't a `clipPath`) as *no restriction at all* (`full_clip`, coverage 1
  everywhere) while still switching the element into its own layer if it's a group. Encoding that
  distinction as a *list* of clip parts is awkward — a list of zero parts means "clips everything"
  (the `union` starts at 0 and stays there), the exact opposite of "no restriction." I chose to
  make an invalid reference produce `None` from `_gpu_clip_parts`, and to treat `None` as "no clip
  at all" for both the own-layer decision and the paint step, which is a narrower construction of
  own-layer than chapter 20's (an element with an invalid clip-path attribute and opacity 1 now
  draws in place rather than through a redundant own-layer/no-op-clip round trip). None of
  `tiger.svg`, `harbor.svg`, `rose.svg`, or the chapter's one ad-hoc clip scenario has an invalid
  `clip-path` reference, so this never differs in the tested documents — flagging it because it's
  a real, if narrow, divergence from chapter 20's stated behaviour that no scenario currently
  exercises either way.
- **`naive_depth(w, h)`.** The prose describes an actual recursive four-way flood fill and asks
  for "the deepest chain of calls in flight." Simulating that literally in Python for the
  `naive_depth(200, 200)` case means either 40,000 real stack frames (risking a native stack
  overflow independent of `sys.setrecursionlimit`, since the interpreter's C stack is finite too)
  or an iterative re-implementation of call-tree depth bookkeeping. I derived the closed form
  instead: for a fully-matching empty canvas, the right-left-down-up order visits the whole
  rectangle along one continuous boustrophedon (snake) path with no wasted backtracking, so the
  deepest call chain is exactly `w * h` — verified by hand for `naive_depth(4, 3) = 12` and cross-
  checked against the scenario's own `naive_depth(200, 200) = 40000`, both of which match a plain
  `w * h`. This is the one function in either chapter answered by derivation rather than
  transcription; a future scenario with a *non-rectangular* matching region (an L-shape, say) would
  be a good test of whether that derivation actually generalises, since right now nothing pins it
  for anything but a solid rectangle.

## Hard to translate

Nothing in either chapter needed a workaround for "Python 3, standard library only." The heaviest
new machinery — `bisect` for chapter 24's per-row arriving-sum lookups in `coarse_stage` — is
already stdlib, matching how chapter 22 used `heapq`/`fractions` and chapter 20 used
`xml.etree.ElementTree`. Everything else (the compute pipeline's stages, the stencil buffers, the
brush/flood-fill/quantization machinery) is plain arithmetic and dictionaries.

The one place worth naming: chapter 24's `coarse_stage` is specified as reading "the bins of the
tiles to its left" to compute the arriving sum at a tile's own left edge, which taken completely
literally would mean re-scanning every earlier tile's bin list for every later tile — quadratic in
the number of tiles across a row for every draw. Since the scenarios only pin `coarse_stage`'s
*results* (the command lists it produces, via `command_count` and the final rendered bytes), not
its internal reads, I instead group each draw's deposits once (by cell, and by row with a sorted
prefix-sum table) and answer an arriving-sum query with a binary search. It reads the same
information the bins hold, just organised for the query rather than literally iterating tile by
tile; the tiger's 305 draws and 4004 post-cull commands come out in well under a second either way
at this book's canvas sizes, but the literal reading would not have scaled cleanly to a much wider
canvas.

## Failures

None. Every scenario in both chapters passed once written, including the four
`Scenario Outline` render comparisons and both direct byte-probe scenarios per chapter
(`ppm_pixel` checks in `chapter24-plate.feature` and `chapter25-plate.feature`).

## Prose problems

- §24.5's description of `coarse_stage` is dense enough (it is, deliberately, the chapter's
  hardest paragraph) that I had to read it three or four times against `chapter21-tiles.feature`'s
  own `classify_tiles` before the "arriving sum... added left to right from 0" line clicked as
  "the same running-sum idea as chapter 21, just computed from a different data structure." A
  worked numeric example the size of the square-as-four-triangles one in §24.1 — even a tiny
  2-tile-wide, 1-draw case — would have saved that re-reading. This is a suggestion, not a
  complaint that anything was wrong: once matched against chapter 21's own algorithm it was
  unambiguous, and no scenario was left unclear by it.
- §24.6's prose states "the rose nests them two deep, and 200 pushes... find the stack full and
  spill," which reads at first as if 200 is the number of *nested* pushes, when it is actually
  `fr.spills` — the count of push events that occurred once the stack already held
  `STACK_DEPTH` (2) blocks, across *all* 625 tiles the rose's canvas is cut into, not a per-tile or
  per-nesting-level count. The scenario itself (`fr.spills = 200`, `fr.tiles = 625`) disambiguates
  this immediately, so it's a two-minute confusion rather than a real problem.
- Chapter 25 §25.1's `stamp_positions` prose and `paint_stroke`'s "makes the mask from
  stamp_positions when by_distance is true and from the events themselves when it's false" read
  cleanly and translated on the first pass with no surprises — worth naming as a contrast to some
  earlier chapters' brush/stroke prose, which needed more reconstruction.

## Mutation results

Three mutations, one from each of the traps the chapters call out by name, all caught:

1. **Dropped the `s > 0` guard in `inside_curve`** (chapter 24's own named trap: "u² − v is
   negative on the far side of the chord too... and s... is what says you're on the curve's
   side"). Caught by three different scenarios at three different levels: the direct unit
   scenario ("u² - v < 0 is the sliver between the curve and its chord", a straight `= false`
   check flipping to `true`), the glyph-agreement scenario ("A glyph without flattening agrees
   with one flattened to a thousandth of a pixel", `winding_mismatches` jumping from 0 to 3658),
   and `chapter24-plate.feature`'s render comparison (`max_channel_difference` jumping to 183 and
   a named pixel probe failing outright). This is the strongest-covered trap in either chapter.
2. **Used an unrotated 2x2 sample grid for `sample_pattern(4)`** instead of the rotated
   "no two samples share a row or column" pattern (the chapter's own point in §24.3: "rotate the
   grid... and the same four samples give it five [levels]"). Caught by both the direct pattern
   scenario (`sample_pattern(4)[2]` no longer matches) and, more to the point, by "More samples
   come closer to chapter 7" — the unrotated grid's worst-pixel error against chapter 7's exact
   fill came out at `0.2375`, more than double the rotated grid's pinned `0.1125`, so the scenario
   would have caught the mutation even if the direct pattern-values scenario didn't exist.
3. **Diffused chapter 25's `error_diffuse` in encoded (sRGB) bytes instead of linear light** — the
   chapter's own named trap ("most programs diffuse in encoded values, the chapter 1 mistake
   again"). Caught immediately by "Two inks three ways: error diffusion keeps the light": the
   4-pixel `ramp_canvas(4, 1)` case flips from the pinned `[0, 0, 1, 1]` to `[0, 1, 1, 1]`, because
   encoded-space diffusion pushes the ramp's midpoint dark pixel over the threshold a step early.

No mutation survived a scenario. I did not find a "passes every scenario" mistake this round —
worth saying plainly since the instructions call that out as the most valuable possible finding
and I don't want to imply I found one where I didn't.

## Concrete changes I'd make

- Add a tiny worked numeric example to §24.5's `coarse_stage` paragraph (see Prose problems).
- Give `radial_gradient` (and, for consistency, `linear_gradient`/`conic_gradient`) a default
  `mode="pad"` in the book's own reference implementation and pseudocode, not just this reader's
  copy, since chapter 24 is already written assuming a five-argument call works.
- Consider a scenario that pins `naive_depth` (or an equivalent) against a *non-rectangular*
  matching region, so an implementation that quietly assumes "the recursion always snakes the
  whole rectangle" (mine included) has something to fail against if that assumption is wrong.

## Timing

Full suite (`python3 test_runner.py`, 876 scenarios, chapters 1-25):

```
Total: 876, Passed: 876, Failed: 0
python3 test_runner.py  566.79s user 2.58s system 76% cpu 12:27.72 total
```

(Run twice for confidence — once mid-pass and once against the final committed state — landing at
12:27.72 and 15:07.64 wall-clock respectively; the spread is machine load, not anything that
changed between the two runs, and both came back 876/876.)

Chapter-24/25-only subsets run in isolation (excluding chapters 1-23's own slower renders — the
SVG walker and the distance-field baking in chapters 20-23 dominate the full-suite wall clock, not
anything new here):

- `chapter24-*.feature` (24 scenarios): a few seconds.
- `chapter25-*.feature` (25 scenarios): a few seconds.
- Individual chapter 24/25 renders: see the Result table above (0.09 s to 4.08 s each; the
  slowest, `tiger-assembly.ppm`, runs the tiger's whole 841-tile grid through the fine stage four
  times over — once per checkpoint snapshot — which is the honest cost of "stop and show the
  picture partway through," not a performance bug).
