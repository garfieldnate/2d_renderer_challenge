# Reader feedback: Python, chapters 16-17

Cold read, Python 3 stdlib only (plus `json` for the font). Full suite: 561 scenarios,
558 pass, 3 fail (all chapter 16 plate renders, all failing only the whole-image
`max_channel_difference ≤ 1` budget -- every pinned scalar/tuple/pixel-probe assertion in
those same scenarios passes). Full run of `test_runner.py`: ~111s wall clock.

## Catch-up (chapter 13, pre-existing code)

`features/chapter13-degenerate.feature` gained one scenario since this code last ran:
*"A closed subpath that ends where it began has no zero-length closing segment."* It is new
(not present before this session) and it **failed** on the existing code: `stroke_to_path`
built the segment list for a closed subpath by appending `(pts[-1], pts[0])` unconditionally,
and when the path's own last `line_to` already lands back on the first point (then `close()`
is called too), that pair is a literal zero-length segment. `_seg_rect` normalizes `b - a`
for that segment and raises `ValueError: Cannot normalize a zero-length vector`, crashing the
whole run (the test harness doesn't catch step-level exceptions, so one bad scenario takes
down every scenario after it in the file list -- worth knowing before you add a scenario that
can throw).

Fix: in `stroke_to_path`, after `_dedupe_points`, additionally drop the last point of a
*closed* subpath when it coincides with the first (`magnitude(pts[-1] - pts[0]) <= 1e-9`),
before building the closing segment. All five `chapter13-degenerate.feature` scenarios pass
now, and chapters 1-15 are green (518 -> still 518 scenarios there, this fix touches no test
counts, only correctness).

## Chapter 16: What a Glyph Is

**Result:** 24 scenarios total across `chapter16-{font,contours,composites,path,plate}.feature`.
21 pass. 3 fail, all in `chapter16-plate.feature`, all on `max_channel_difference`:

| render | max_channel_difference | budget |
|---|---|---|
| `glyph.ppm` | 29 | ≤ 1 |
| `plate-16.ppm` | 29 | ≤ 1 |
| `composite.ppm` | 0 | ≤ 1 |
| `sizes.ppm` | 0 | ≤ 1 |
| `flip.ppm` | 37 | ≤ 1 |

Render time for all five chapter 16 plates: ~4.3s (dominated by `glyph_plate`'s many small
`stroke_to_path`/`fill_path` calls for each control-point marker).

**Ambiguities.** The chapter gives full, literal pseudocode for exactly one render
(`glyph_plate`/`plate_16`); `composite_demo`, `sizes`, and `flip_trap` are only *named and
described* in the `chapter16-plate.feature` prose block ("composite_demo() draws eacute with
its two components in two inks and its bounds as a hairline box. sizes() draws g at 12, 24, 48
and 96 pixels on one baseline. flip_trap() draws R through text_matrix on the left and through
a scale that forgot to turn y over on the right.") with no sizes, positions, or exact colors
given anywhere. I reverse-engineered all three from the reference PPMs (same technique the
existing README already documents for chapter 10's stop table and chapter 12's clip demo):

- `composite_demo`: `text_matrix(font, 240, 50, 190)` on a 240x240 canvas, `e` in `INKS[0]`
  and `acute` in `INKS[1]` (the same orange/blue used since chapter 7), bounds box as a
  hairline in the chapter 13 stroke magenta. Matched the reference exactly (diff 0) once I
  applied each component's *own* transform (`component_matrix` from `eacute`'s component list)
  rather than drawing the bare `acute` glyph unshifted -- my first attempt drew `acute` at its
  own (unshifted) glyph-space position, which put it nowhere near the `e`. The chapter's prose
  never says a composite demo has to walk `font.glyphs[name].components` itself; a reader could
  easily reach for `glyph_path(font, "acute", m, tol)` directly and get a silently-wrong picture
  (both glyphs render, just not aligned) rather than a crash.
- `sizes`: baseline `y = 80`, `x = 8`, gap `8` between glyphs (not the `10` I guessed first).
  Matched exactly (diff 0).
- `flip_trap`: `text_matrix(font, 60, 35, 60)` for the correct panel (gray fill, no outline),
  and `translation(35, 60) * scaling(scale, scale)` (the same size/position, `y`-scale not
  negated) for the wrong one, filled solid in magenta -- **not** an outline overlay the way
  `caps_demo`/`joins_plate` do it in chapter 13. I guessed outline-over-gray first (matching
  the chapter 13/14 convention) and it was visibly wrong once diffed against the reference
  (a hollow rectangle instead of a solid R). There is also an un-mentioned horizontal "baseline"
  guide line, `color(0.16, 0.16, 0.18)`, two pixels tall, spanning the full width of each
  120x120 panel, centered on the baseline row, drawn before the glyph. Nothing in the chapter
  text mentions this guide line at all; I found it only by diffing byte-for-byte against
  `reference/chapter-16/flip.ppm`. Got composite/sizes to 0 diff; flip_trap's residual 37 (see
  Failures) is the one render I could not fully close.
- `glyph_plate`'s "hairline through every point of the contour ... width 1" line has no stated
  color. I reverse-engineered `color(0.28, 0.28, 0.32)` (which forward-computes to byte
  `(144, 144, 153)` exactly, matching a flat run of reference pixels away from any marker).
  The chapter also doesn't say whether the hairline is a Wu antialiased 1px line (chapter 3) or
  a filled 1-wide stroke outline (chapter 13's `stroke_to_path`) with round/miter/bevel joins.
  A Wu line through the raw vertices badly overshoots at corners (round join bulges show up as
  a large, spurious blob at every vertex where the true image has a crisp corner); a
  `stroke_to_path` outline with a `"miter"` join gets close (see Failures) but not exact.

**Hard to translate.** Nothing structural -- `Font`/`Glyph` map onto plain classes, contours
onto lists of `(x, y, bool)` tuples, components onto `(name, [a,b,c,d,dx,dy])` tuples, all of
which the existing Gherkin runner already round-trips via generic tuple/list comparison. The
one place I had to think was `glyph_outline`'s return shape: the scenario
`length(glyph_outline(font, "e")) = 2` only makes sense if `glyph_outline` returns *one list of
quadratics per contour* (2 contours) rather than a flat list of quadratics (which would be
many more than 2). The chapter's prose ("its own contours as quadratics, followed by each
component's outline...") reads equally well either way; only the scenario's exact number pins
the nested-list shape. Worth a sentence in the chapter saying so explicitly.

**Failures (whose fault).**
- `glyph.ppm`/`plate-16.ppm`, diff 29: after fixing the hairline's color, the join style
  (`"miter"`, `width=1.0`, `stroke_to_path`+`fill_path`) gets a flat run of hairline pixels to
  byte 140 where the reference has 144, and the adjacent antialiased row to 56 where the
  reference has 57 -- both off by single digits, isolated to the handful of pixels along
  near-horizontal hairline segments. I tried `"bevel"`/`"round"` joins and widths 1.0/1.5/2.0;
  none reproduced both rows exactly at once (width 1.5 gets row-1 exact but overshoots row-2).
  My best guess is the reference hairline isn't drawn through `stroke_to_path` at all but
  through some other coverage convention the chapter doesn't specify (e.g. a rectangle built
  directly from the segment's own analytic coverage rather than a join-aware stroke outline).
  This is a chapter/scenario gap, not a bug in my geometry: every scenario in
  `chapter16-{font,contours,composites,path}.feature` that pins an actual number passes, and
  the two pinned pixel probes in this very scenario (`ppm_pixel(160,160)`, `ppm_pixel(10,10)`)
  also pass -- only the blanket image diff catches the residual.
- `flip.ppm`, diff 37: isolated to the baseline row(s) where the correct/incorrect R's edge
  meets the un-documented baseline guide line. I confirmed (by testing a range of fractional
  baseline y-values) that the mismatch is not a simple sub-pixel offset of the whole glyph --
  shifting `y` by fractions of a pixel never got the diff below ~29-32, and 60.0 (my final,
  integer choice) is already among the best. Likely either the guide line has some
  antialiasing/thickness convention I didn't reconstruct, or the R itself is rasterized with a
  slightly different `tolerance` at the exact baseline edge. Author's/chapter's fault for not
  specifying `flip_trap` at all, mine for not fully reverse-engineering the last few pixels.

**Prose problems.**
- §16.3: "glyph_outline is then the same thing for every glyph" is true in spirit but the
  *shape* of the return value (list-of-lists-of-quadratics vs. a flat list) is only pinned by
  a scenario's `length(...)` count, never stated in prose. Say "one list of quadratics per
  contour" explicitly.
- §16.5's `glyph_plate` pseudocode says "hairline through every point of the contour ...
  width 1" with a bare `// width 1` comment but never says what color, unlike every other mark
  in the same pseudocode block (`in magenta`, `in cyan`). Since it's the only element of the
  plate whose color has to be guessed, and the reference apparently uses a fourth, otherwise
  unused ink, worth naming it (`color(0.28, 0.28, 0.32)` reverse-engineered here) the same way
  chapter 13's `_STROKE_GRAY`/`_STROKE_MAG` got named.
- The `chapter16-plate.feature` prose block for `composite_demo`/`sizes`/`flip_trap` is the
  *feature file's* one-paragraph summary, not chapter prose with pseudocode -- these three
  renders are the only ones in chapters 1-17 so far with literally zero pseudocode anywhere
  (every other chapter through 15 gives at least a `func():` block per the CLAUDE.md rule that
  "every suggested implementation is specified"). This is the one place in the book (so far)
  where that rule seems to have slipped for a render.

## Chapter 17: Rasterizing Type Well

**Result:** 17 scenarios total across
`chapter17-{bitmap,cache,fudge,lcd,plate}.feature`. All 17 pass, including all four renders:

| render | max_channel_difference | budget |
|---|---|---|
| `subpixels.ppm` | 0 | ≤ 1 |
| `smoothing.ppm` | 0 | ≤ 1 |
| `lcd.ppm` | 0 | ≤ 1 |
| `plate-17.ppm` | 0 | ≤ 1 |

Render time for all four: ~0.28s (tiny canvases, no thousands of small marker shapes the way
chapter 16's plate has).

Unlike chapter 16, `lcd_plate` comes with full, literal pseudocode, and `subpixel_strip`/
`smoothing_demo` are specified precisely enough in the `chapter17-plate.feature` prose
("l at 11 pixels with its pen at x = 4, 4.25, 4.5 and 4.75 in four 10 by 14 panels ... magnified
eight times"; "Hamburg at 11 pixels three ways ... magnified four times") that my first
reverse-engineered attempt (pen starting at `x = 2.0`, `y = 11`, 72x14 rows before magnifying)
matched the reference byte-for-byte with no tuning at all. Chapter 17 is a good demonstration
of what chapter 16's missing pseudocode cost: the same amount of guessing (canvas size, pen
start, baseline) produced an exact match here because the prose pinned everything the
pseudocode didn't spell out, where chapter 16's three under-specified renders didn't have that
prose safety net.

**Ambiguities.**
- `glyph_bitmap`'s flattening tolerance is never given a number anywhere (unlike, say, chapter
  16's `glyph_path(font, name, m, 0.1)` scenarios, which always pin `0.1` explicitly in the
  Gherkin). I used `0.1` throughout (`_BITMAP_TOLERANCE`), matching chapter 16's convention,
  and every pinned coverage/ink value in `chapter17-bitmap.feature`,
  `chapter17-cache.feature`, and `chapter17-fudge.feature` matched to the stated tolerance
  (`0.0001`-`0.001`) on the first try, so `0.1` is almost certainly right, but the chapter
  never says so -- worth a sentence.
- `embolden`'s doubled outline is "the fill plus chapter 13's stroke of its outline, amount
  wide". I stroked the glyph's *flattened path* (`glyph_path`'s output, already device-space
  polylines) rather than re-flattening the raw curve outline at a different tolerance for the
  stroke; this matched the pinned `ink` values exactly, but the chapter doesn't say whether the
  stroke should walk the same flattened polyline the fill uses or something computed
  independently. Since it matched, I'm fairly confident this is what's intended, but a chapter
  that's this careful about "every render whose pattern is symmetric... can't detect X" (per
  CLAUDE.md's own house rules) could use a sentence pinning this too.

**Hard to translate.** Nothing at all. Every new function name in `chapter17-*.feature`
mapped onto a direct Python function with no impedance mismatch, including
`atlas_add(...) = none`/`(x, y)` tuple comparisons and `bitmap(coverage_buffer(w, h), 0, 0)`
as a bare public constructor -- both already-supported shapes in the existing runner (`none`
comparison, tuple comparison) needed no changes.

**Failures.** None outstanding. Two bugs found and fixed during development, both against my
own first-draft code, not the chapter:
1. `lcd_coverage`'s first draft repositioned the glyph's origin by `3*x` inside an *unscaled*
   `text_matrix`, which just moves a normal-width glyph sideways in a 3x-wide buffer instead of
   *stretching* it 3x horizontally. `ink(cov3)` came out equal to `ink(gray)` (one-third of the
   expected `24.592896`) until I built the matrix by hand as
   `translation(3*x, y) * scaling(3*scale, -scale)` instead of going through `text_matrix`
   (which only offers a uniform scale). Worth flagging in the chapter: `lcd_coverage` is the
   one place in chapters 16-17 that needs a *non-uniform* scale, and `text_matrix` can't build
   one.
2. First draft's `glyph_bitmap` height/width formula was right the first time (matched
   `chapter17-bitmap.feature` immediately) -- no issue there, but I mention it because it was
   the one place I expected an off-by-one and didn't get one: `floor(-ymax)` to
   `ceil(-ymin) - 1` is a genuinely well-specified formula, unlike chapter 16's under-specified
   renders.

**Prose problems.** None found. Chapter 17 is the tightest-specified chapter of the two: every
render has either literal pseudocode (`lcd_plate`) or a prose description precise enough to
reconstruct exactly (`subpixel_strip`, `smoothing_demo`).

## Mutation testing (both chapters)

Six mutations tried, one per plausible mistake, each reverted after checking:

| # | Ch | Mutation | Caught by |
|---|---|---|---|
| 1 | 16 | `implied_points` skips the wrap-around (last-to-first) pair | `chapter16-contours.feature`: "A loop of off-curve points implies a midpoint between each pair" (`7 = 8`) |
| 2 | 16 | `component_matrix` swaps `b`/`c` (wrong TrueType letter order) | `chapter16-composites.feature`: "A component transform is a matrix" *and* the hand-written "bump" scenario |
| 3 | 16 | Flip applied a second time in `contour_path` (on top of `text_matrix`'s) | Catastrophic, as expected -- 15+ scenarios across chapters 16 and 17 fail once any glyph is drawn upside-down twice |
| 4 | 17 | `glyph_bitmap`'s bounding-box math ignores the quarter-pixel shift (but the fill matrix still uses it) | `chapter17-bitmap.feature`: "A quarter to the right moves the ink, not the amount of it"; also `chapter17-cache.feature`'s different-quarter scenario |
| 5 | 17 | `lcd_filter` pads with the edge value instead of zero | `chapter17-lcd.feature`: "The filter's taps sum to one and spread a spike over three stripes" -- **and only that scenario**. Neither `lcd_coverage`'s ink-triples-check nor `paint_lcd`'s per-channel-stripe check noticed, because a real glyph's LCD coverage buffer never has non-zero coverage running all the way to column 0 or `3w-1` at this size, so the boundary condition never gets exercised by the render-level scenarios. This is exactly the "helpers get their own scenarios, including their failure modes" principle from CLAUDE.md, applied correctly here -- `lcd_filter`'s unit scenario is the only thing standing between a shipped edge-padding bug and a passing suite. |
| 6 | 17 | `atlas_add` never opens a new shelf (returns `None` on overflow instead of wrapping) | `chapter17-cache.feature`: "Shelf packing places bitmaps left to right, then opens a new shelf" -- and *not* by "The atlas holds the bitmap's coverage where it said", which only packs two bitmaps that both fit on the first shelf |

One additional deliberate "try to break it" attempt, per the instructions:

| # | Ch | Mutation | Result |
|---|---|---|---|
| 7 | 16 | `glyph_bounds` uses the raw *control points* of every quadratic instead of chapter 8's `curve_bounds` (the exact trap the chapter's own prose names: "not the box of the control points, which pokes out past the curves") | **Not caught by the scenario named for exactly this** ("Bounds are tight, not the control box", `glyph_bounds(font, "o")`/`glyph_bounds(font, "H")`). Both values came out byte-identical to the tight-curve-bounds answer, because `H` is all straight edges (whose "control point" is my own straight-edge midpoint, never outside the endpoint box, so it can't discriminate at all) and, apparently coincidentally, `o`'s real quadratic control points in this specific Roboto data don't happen to stick out past its true tight bounds either. The mutation *was* caught, but only by the unrelated, hand-written `chapter16-composites.feature` scenario ("A font can be written by hand, and a bump's bounds stop where the curve does" -- `bump`'s control point at `(100, 200)` sits well outside its true peak at `(100, 100)`, so that scenario's `(0, 0, 200, 100)` vs. the mutated `(0, 0, 200, 200)` catches it cleanly). **This is the single most useful finding of this round**: the scenario whose name promises to test "tight vs. control box" doesn't actually exercise that distinction for either of its two real-font examples; only the synthetic hand-built font does. Fix: either pick an `o`/`H`-family glyph (or a different real glyph) whose control polygon demonstrably pokes out past its curve, or note explicitly that the hand-written `bump` scenario is the one carrying this guarantee. |

## Concrete changes I'd make

1. Give `composite_demo`, `sizes`, and `flip_trap` real pseudocode blocks the way `glyph_plate`
   and `lcd_plate` get them -- they're the only renders in the book so far with none at all.
2. Name the hairline's color in `glyph_plate`'s pseudocode (it names every other ink used).
3. Say explicitly that `glyph_outline` returns one list of quadratics *per contour*.
4. Pin a flattening tolerance for `glyph_bitmap` (I used `0.1`, matching chapter 16, and it
   worked, but the chapter never says so).
5. Point out that `lcd_coverage` needs a non-uniform scale and so can't be built from
   `text_matrix` alone -- the one place in these two chapters where that's true.
6. Retarget (or add to) the "Bounds are tight, not the control box" scenario: neither `o` nor
   `H` from the real font actually distinguishes tight bounds from control-point bounds; only
   the hand-written `bump` scenario does.
7. Document `flip_trap`'s baseline guide line -- it appears in the reference PPM with no
   mention anywhere in the chapter text.

## Timing

- Full `test_runner.py` (561 scenarios, chapters 1-17): ~111s wall clock.
- Chapter 16's five renders (`glyph_plate`/`plate_16`/`composite_demo`/`sizes`/`flip_trap`):
  ~4.3s combined, almost all of it `glyph_plate`'s ~30 small `stroke_to_path`+`fill_path` calls
  for the control-point markers.
- Chapter 17's four renders (`subpixel_strip`/`smoothing_demo`/`lcd_plate`/`plate_17`):
  ~0.3s combined.
