# Chapter 3 feedback

## Ambiguities

- **thick_line's construction has no pseudocode.** Bresenham and Wu both get
  literal, line-by-line pseudocode ("here it is, complete"). `thick_line`
  gets only prose: "Build it from four half-planes. With d the unit
  direction... and n the unit normal... the four are: through the start
  point facing along d; through the end point facing back along -d; and one
  along each side, offset by half the width along n, facing inward." That's
  enough to get the *shape* right, but which side gets `+n` and which gets
  `-n`, and which of those two gets an inward normal of `+n` vs `-n`, is
  left for the reader to work out from "facing inward." I derived it by
  hand from the "Inside a thick line" scenario's seven assertions (solved
  for the half-plane boundaries algebraically, then checked the sign
  convention against `inside(s, 4.5, 0.5) = true` / `inside(s, 4.6, 0.5) =
  false`) rather than from the prose. It came out right, but a chapter this
  precise about tie-breaking in Bresenham (§3.1: "Other books initialize
  the error differently... the tests pin this one") could afford four more
  lines of pseudocode here too.

- **`round()` in `ray_ends()`.** Not specified as round-half-up, round-half-
  even, etc. Never matters for these twelve angles (no coordinate lands on
  x.5), so it's moot in practice, but it's the same kind of tie-breaking
  question the chapter is usually careful about elsewhere.

- **Exact vs. approximate "isn't black" in `lit_pixels`.** Never actually
  ambiguous in practice -- Wu's `plot` skips a weight of exactly zero, so a
  pixel is either untouched (exactly black) or touched (never exactly
  black) -- but the spec doesn't say whether the comparison should be exact
  or tolerant. I used the existing `Color.approxEquals`.

## Hard to translate

- `lit_pixels(c) = [(x, y), ...]` and `ray_ends() = [(x, y), ...]` needed a
  list-of-pairs equality assertion that didn't exist in the chapter 1/2
  test infrastructure (which only ever compared scalars, colors, triples,
  or single objects). Wrote a small `assertPoints` helper; not hard, just
  one more piece of scaffolding the earlier chapters hadn't needed.
- The two `Scenario Outline` tables (Wu's ink-by-angle, thick_line's ink-
  by-angle) translate to a loop over row arrays registering one named
  scenario per row -- mechanical, no real friction, matches how chapter 1/2
  never had outlines to deal with.

## Failures

None, in the final implementation -- all 31 chapter 3 scenarios pass, and
chapters 1 (59) and 2 (28) still pass unchanged. `out/fan-coverage.ppm` and
`out/plate-03.ppm` are byte-identical (sha1) to
`reference/chapter-03/{fan-coverage,plate-03}.ppm`.

## Mistakes that stay green

I hand-introduced the seven bugs the task asked about and reran the chapter
3 suite (31 scenarios) against each, one at a time:

| Mistake | Scenarios failing | Notes |
|---|---|---|
| Bresenham `err ← 0` instead of `dx / 2` | 5 / 31 | Caught hard: 4 direct pixel-list scenarios plus the plate. |
| Steep swap forgotten (steep always false) | **2 / 31** | Only the dedicated "A steep line steps along y" scenario and "Plate 3: the plate" catch it. **"Plate 3: Bresenham's fan" itself passes** -- its five spot-checked pixels (axis rays, the ray at exactly 30°, and one always-lit/always-dark boundary pair) never happen to fall in a gap the broken steep handling creates. Only the byte-exact reference comparison in the *plate* scenario notices. A renderer with a real steep-line bug could look "basically fine" under the fan-specific scenario. |
| Wu weights swapped (`f` / `1-f` reversed) | 7 / 31 | Caught hard and immediately, including the fan. |
| Wu `round` instead of `floor` | 4 / 31 | Caught cleanly by the fractional-weight scenarios. |
| thick_line side half-planes facing outward | 8 / 31 | Caught immediately -- the shape becomes empty, so ink drops to 0 everywhere. Impossible to miss. |
| thick_line from pixel corners, not centers | **3 / 31** | Only "Inside a thick line" (the one exact-boundary scenario), one of the two coverage-at-specific-pixels checks, and the fan-as-rectangles render catch it. All four "ink is the length, whatever the angle" rows and the diagonal grid-blindness scenario **still pass**, because a uniform half-pixel translation of the whole segment doesn't change a rectangle's *area*, and none of those scenarios pin down *position*, only *ink*. A systematic off-by-half-pixel bug survives most of the outline table. |
| `lit_pixels` in column-major order | **1 / 31** | Only "A line going up and to the right" catches it -- it's the one scenario whose lit pixels aren't simultaneously non-decreasing in both x and y, so it's the only one where row-major and column-major traversal disagree on ordering. Every other Bresenham/Wu scenario draws a line that moves monotonically down-right (or is a single row/column), so the two traversal orders coincide by accident. This is the weakest spot in the suite: a completely wrong `lit_pixels` implementation passes 30 of 31 scenarios. |

The general pattern: scenarios that pin an exact list of pixels or an exact
per-pixel color are strong; scenarios that only check an aggregate (`ink`,
`total_ink`) are weak against bugs that preserve the aggregate while
breaking position (translation, transposition, reordering).

## Prose

Very good chapter -- the tightest of the three so far. The reveal in §3.3
(Wu is secretly doing bad coverage estimation, one column at a time) is the
best moment in the book so far and the ink-by-angle numbers land it
concretely (11 vs. 9, "up to 18% less paint"). The "In the GUI" aside
(Pencil vs. Brush) is a nice one-paragraph payoff for readers who don't
have a graphics background.

One claim doesn't transfer to this language: "Twelve rasterizations of a
160-by-160 canvas at 64 samples a pixel is twenty million inside tests,
and in an interpreted language that's twenty seconds for one picture."
In this Java implementation, `fan_coverage()` takes about 47ms (JIT-warmed)
and the entire 31-scenario chapter 3 suite runs in ~130ms wall clock. The
lesson ("special-purpose primitives are a local optimum, but the naive
rasterizer is still correct") survives fine, but the specific "twenty
seconds" number reads oddly for anyone running this in a compiled
language, and might be worth hedging ("in Python or Ruby" or similar)
rather than stated as if universal.

## Would change

- Give `thick_line` the same literal pseudocode treatment Bresenham and Wu
  get, for the reason above -- it's the one function in the chapter whose
  exact half-plane construction is left to be reverse-engineered from a
  single scenario.
- Add one more Bresenham/Wu scenario whose points are *not* monotonic in
  both axes (the fan itself has several, but the unit scenarios don't),
  so a column-major `lit_pixels` bug is caught by more than one line in
  the feature file.
- Consider a scenario that checks a specific *non-axis, non-30°* pixel of
  `fan_bresenham()` mid-ray, to make the fan scenario itself sensitive to
  a broken steep swap instead of relying entirely on the full-image plate
  comparison to catch it.

## Results

- Chapter 1: 59 / 59 passed.
- Chapter 2: 28 / 28 passed.
- Chapter 3: 31 / 31 passed (9 Bresenham + 10 Wu + 7 quad + 5 plate,
  outline rows expanded).
- `out/fan-coverage.ppm` and `out/plate-03.ppm` match
  `reference/chapter-03/*.ppm` byte-for-byte.
- Time: whole chapter 3 suite ~130ms wall clock (JVM already warm).
  `fan_coverage()` (12 rasterizations at 64 samples/pixel over a
  160×160 canvas, ~19.6M `inside` calls) is the one real hotspot at
  ~47ms; every other figure and every unit scenario is low single-digit
  milliseconds or less. As noted above, this is nowhere near the "twenty
  seconds" the chapter describes -- that estimate is clearly written with
  an interpreted-language reader in mind.
