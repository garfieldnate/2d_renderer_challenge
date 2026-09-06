# Reader feedback — TypeScript / Deno, chapters 5 and 6

Implemented cold from the chapter text and the `.feature` files alone, on top of the existing
chapters 1-4 TypeScript code. Both chapters translated first try into passing tests with no
prose ambiguity that changed a result — the one real bug found was in chapter 3's code, caught
by a scenario that had never been translated before this round (see Catch-up).

## Catch-up (before chapter 5)

Diffed every `features/chapter0{1,2,3,4}-*.feature` scenario name against the existing test
files. Five scenarios existed in the feature files but had never been translated:

- `matrices_test.ts`: **"Invertibility is an exact test against zero"** — passed unchanged.
  `is_invertible` already used exact `determinant(M) !== 0`.
- `tuples_test.ts`: **"magnitude and dot look at x and y only"** — passed unchanged.
- `plate_04_test.ts`: **"side_by_side puts the first canvas on the left"** — passed unchanged.
  `side_by_side` existed in `canvas.ts` from chapter 4 but had no scenario at all.
- `drawing_test.ts`: **"A union of nothing is inside nowhere"** — passed unchanged.
  `union([])` already returned `false` for everything.
- `wu_test.ts`: **"The weights are applied in light, whatever the switch says"** — **failed**.

The last one is a real bug. Chapter 3's prose (§3.2) says plotting a Wu pixel is
`mix(pixel_at(c, x, y), col, weight, true)` — forced to linear light — "whatever the global
switch says." The existing `plot()` in `src/line.ts` called `mix(pixel_at(c, x, y), col, weight)`
with no fourth argument, so it defaulted to the global `linear_blending()` switch instead of
forcing `true`. With the switch on (the default, and the only state any existing scenario or
render ever used) this is invisible — `mix`'s default parameter equals `true` anyway — so every
render and every previously-existing scenario stayed green with the bug in place. The moment the
new scenario turned the switch off, actual vs expected was `color(0.214, 0.214, 0.214)` vs
`color(0.5, 0.5, 0.5)` at `pixel_at(c, 1, 0)`: the naive browser-mode mix of two encoded 1.0/0.0
values at t=0.5. Fixed by passing `true` explicitly in `plot`. All chapter 1-4 renders and
scenarios still pass afterward (207 → 212 passing, plus the one new scenario itself).

This is exactly the kind of bug the book's own rules describe (a global-switch scenario that
never got written), and it sat invisible for two whole chapters because nothing ever turned the
switch off inside a Wu-line test until now.

## Chapter 5 — Paths and Insideness

### Result

32 scenarios pass, across 4 files: `paths_test.ts` (10), `winding_test.ts` (9), `rules_test.ts`
(9), `plate_05_test.ts` (4). Full suite: 244 passing after chapter 5 (212 carried over + 32).

Renders, `max_channel_difference` against `reference/chapter-05/`:
- `star-centers.ppm`: **0**
- `star-coverage.ppm`: **0**
- `plate-05.ppm`: **0**

All three are byte-identical to the reference, not merely within tolerance.

### Ambiguities

None that changed a result. The one place I had to make an internal decision the chapter doesn't
pin: `bounds()`'s return shape. The scenarios only ever compare it as four numbers
`(min x, min y, max x, max y)`, never through a named accessor, so I picked
`{minX, minY, maxX, maxY}` as the TypeScript shape. Any shape would have worked; this is a
translation detail, not a chapter gap.

### Hard to translate

Nothing serious. Gherkin's `(a, b)` edge pairs became `{a: Tuple, b: Tuple}`; nothing needed a
new comparison helper beyond `assert_bounds` (added to `src/assert.ts`, same shape as
`assert_tuple`/`assert_matrix`).

### Failures

None, once the chapter 3 catch-up bug above was fixed. Every chapter 5 scenario passed on first
implementation.

### Prose problems

None found. `winding_at`'s pseudocode (§5.2) was followed literally and matched the reference
exactly, including the pentagram numbers pinned to four decimals. `star()`'s pseudocode likewise
reproduced `point(80.5, 10.5)`, `point(121.645, 137.1312)`, etc. exactly.

## Chapter 6 — Filling a Polygon

### Result

37 scenarios pass, across 4 files: `edges_test.ts` (6), `spans_test.ts` (16), `sweep_test.ts`
(12), `plate_06_test.ts` (3). Full suite: 281 passing after chapter 6.

Renders, `max_channel_difference` against `reference/chapter-06/`:
- `spiral.ppm`: **0**
- `plate-06.ppm`: **0**

Both byte-identical to reference.

Every `fill_path_aliased` scenario also carries its own `max_coverage_difference` check against
chapter 5's `rasterize_centers(filled(p, rule), w, h)` and every one comes out **0**, including
the star under both rules (5480 vs 3780 ink) and a star put through an arbitrary
translation·scaling·translation matrix. The chapter's central claim — pixel-for-pixel identical
to the slow reference — held on first implementation with no numeric slop anywhere.

### Ambiguities

None that changed a result. One place worth confirming rather than reporting as a bug: the
chapter's trap (§6.1) claims the star's edge table has 5 entries on paper, not 4, because two of
its vertices that should be at the same height differ in the last float bit
(`58.86881039375369` vs `58.86881039375366` in the author's Python). I checked this directly in
my own implementation:

```
edges(star()).length     = 5
edge_table(star()).length = 4
```

In this TypeScript/V8 build, `Math.sin`/`Math.cos` produced *exactly* equal y for both vertices
(`58.86881039375366` for both), so the near-horizontal edge is genuinely horizontal here and gets
dropped, giving 4 entries, not 5. This is precisely what the chapter warns readers to expect —
"what your sin does in the last bit is between you and your libm" — and precisely why no scenario
pins the star's table length. Confirmed working as designed, not a bug; flagging only because
it's a nice real-world instance of the chapter's own caveat.

### Hard to translate

Nothing. `(x, direction)` crossing pairs and `(x_start, x_end)` span pairs both mapped cleanly
onto TypeScript tuples `[number, number]`.

### Failures

None. Every chapter 6 scenario passed on first implementation.

### Prose problems

None found. The `fill_path_aliased` pseudocode (§6.3) was transcribed nearly verbatim into
`src/sweep.ts` and matched the reference exactly, including the two half-open comparisons the
chapter specifically warns about (`table[next].y_top <= y` for joining the active list,
`e.y_bottom > y` for leaving it) and the "starts on a sample height is active, ends on one is
not" scenario, which exercises exactly that asymmetry.

## Mutation results

Deliberately broke `src/path.ts` and `src/sweep.ts` in ways a reader plausibly would, ran the
suite, then reverted. Six mutations tried; five caught, one **not caught**:

1. **`crossings` half-open → both-inclusive** (`y <= b.y` on both branches instead of
   `y < b.y`/`y < a.y`). Caught: "A ray through a vertex counts it once" (expected 1, got 2) and
   "A diamond wound twice has winding number 2" (expected 2, got 4).

2. **`inside_evenodd` without `Math.abs`** (`winding_at(...) % 2 === 1` instead of
   `Math.abs(winding_at(...) % 2) === 1`). **Not caught — every one of the 281 scenarios still
   passed.** JavaScript's `%` keeps the sign of its left operand, so `-1 % 2 === -1`, not `1`; a
   path with an odd *negative* winding number would be wrongly reported as outside under
   even-odd. No scenario in chapter 5 or chapter 6 ever calls `inside_evenodd` at a point whose
   winding number is negative — every even-odd probe in both chapters' features happens to land
   on a nonnegative winding number (0, 1, or 2). This is the most valuable finding from this
   round: a real, silent, single-character-fixable bug (drop `Math.abs`) that the entire suite is
   blind to. Concrete fix: add a scenario that probes `inside_evenodd` on a loop wound the
   "wrong" way at an odd multiplicity — e.g. reverse `polygon(point(5, 0), point(0, 5),
   point(5, 10), point(10, 5))` (winds -1 through its center) and assert
   `inside_evenodd(p, 5, 5) = true`.

3. **`rasterize_within` using `floor` instead of `ceil` for the box's upper bound.** Caught by 4
   scenarios ("The star by coverage", "Plate 5", "Rasterizing within the bounds gives the same
   coverage", "The box is inclusive of the pixels it touches").

4. **Active-edge-list departure test `e.y_bottom >= y` instead of `e.y_bottom > y`.** Caught:
   "An edge that starts on a sample height is active there, and one that ends there is not"
   (expected 0, got 1 at the row the edge's bottom sits on).

5. **Active-edge-list arrival test `table[next].y_top < y` instead of `<= y`.** Caught by the
   same scenario as #4 (expected 1, got 0 — one row late joining).

6. **`fill_span`'s right edge `Math.ceil(x1 - 0.5)` instead of `Math.ceil(x1 - 0.5) - 1`.**
   Caught by 3 scenarios ("fill_span fills the pixels whose centers are in the span", "The span
   is half-open at its right end", "A span may run off either side of the buffer").

7. **Forgetting to sort the active list's crossings by x each row in `fill_path_aliased`.**
   Caught by 5 of 15 scenarios in `sweep_test.ts`/`plate_06_test.ts` ("A polygon circle", "The
   star, both rules, matches chapter 5 pixel for pixel" (ink 5480 → 3204), "A transformed star
   fills where the transform put it" (ink 60 → 34), "The spiral", "Plate 6"). The rectangle and
   both triangle scenarios still passed — with only two active edges per row on those shapes,
   insertion order and sorted order coincide, so a shape simple enough not to need the sort can't
   tell you it's missing.

The book's own half-open-rule warnings (§5.2, §6.1, §6.2, §6.3) are well-calibrated: every
mutation of a `<`/`<=` boundary the chapters call out by name was caught by a dedicated scenario.
The one gap (#2) is in a rule the chapters describe correctly in prose ("even-odd: inside when
the winding number is odd") but never test with a negative operand.

## Concrete changes

1. Add a scenario exercising `inside_evenodd` (or `spans_from_crossings`/`fill_path_aliased`
   under `"evenodd"`) at a point with a negative odd winding number, per mutation #2 above.
2. Chapter 3's wu.feature already has the scenario that would have caught the `plot()` bug in
   `src/line.ts`; it just hadn't been translated by this codebase yet. No chapter change needed —
   this is purely a reader-process note: run the catch-up step before *every* chapter, not just
   when a chapter's own feature files change, since a scenario can go untranslated for chapters
   at a time without the suite ever turning red.
3. Nothing to change in chapters 5 or 6 themselves — both were unusually precise. The
   `winding_at` and `fill_path_aliased` pseudocode blocks are good enough to transcribe
   mechanically and get a byte-identical renderer out the other end.

## Timing

Full suite (`deno test --allow-read --allow-write`, 281 scenarios, chapters 1-6): ~6s.
Full render (`deno run --allow-write --allow-read src/render.ts`, 20 pictures, chapters 1-6):
~2.7s.

Chapter 5/6 scenes in isolation (single run each, this machine):

| scene | time |
| --- | --- |
| `star_centers()` (chapter 5, 64x cheaper) | 22.8 ms |
| `star_coverage()` (chapter 5, 8x8 supersampled `rasterize`) | 170.0 ms |
| `plate_05()` (both of the above, twice each) | 183.1 ms |
| `spiral()` (chapter 6, 24 stars, scanline sweep) | 88.5 ms |
| `plate_06()` (`spiral()` + `magnify`) | 75.9 ms |

The number worth noting: `spiral()` fills *24* five-pointed stars with the sweep in 88.5 ms,
less time than `star_coverage()` takes to fill *one* star's two panels (170 ms) with chapter 5's
brute-force supersampled `rasterize`. That's chapter 6's whole argument, visible in a single
`time` comparison on compiled-enough code: TypeScript under V8 doesn't need Python's ~70x gap to
show the sweep is the right algorithm, but the gap is still there and still growing with edge
count × pixel count, exactly as promised.
