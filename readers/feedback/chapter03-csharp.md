# Chapter 3 feedback

## Ambiguities

- **Rounding direction in `ray_ends()`.** The pseudocode just says `round(...)`.
  Every value in the twelve endpoints happens to be nowhere near a half-integer,
  so round-half-up vs. round-half-to-even vs. round-half-away-from-zero are all
  indistinguishable here. I used `MidpointRounding.AwayFromZero` (C#'s
  `Math.Round` defaults to banker's rounding, which would have been a silent,
  untested divergence from "round" as plain English). Worked, but the chapter
  never actually exercises the tie case it could have chosen to pin.
- **What "isn't black" means for `lit_pixels`.** I used exact equality
  (`Red != 0 || Green != 0 || Blue != 0`), not a tolerance. Since every pixel
  written by `line_bresenham` is either untouched (exactly `(0,0,0)` from
  `Canvas`'s default) or exactly `col`, and Wu's `plot` explicitly skips a
  weight of zero (so it never writes a nonzero-but-negligible pixel), exact
  equality happens to be safe. The chapter doesn't say so explicitly, though,
  and a tolerance-based version would have been just as defensible.
- **Zero-length `thick_line`.** `x0=y0=x1=y1` divides by zero when normalizing
  the direction vector. No scenario exercises it, so I guarded it (falls back
  to direction `(1, 0)`) rather than leaving a `NaN` shape, purely for safety —
  this is unverified by any test.

## Hard to translate

- `lit_pixels` and `total_ink` are test helpers with no feature-file "Given"
  syntax of their own — they only appear inside `Then` clauses. Translating
  them meant reading the prose (§3.1, §3.2) rather than the feature file to
  learn their contracts (reading order, "sum of the red channel"). Routine,
  but worth flagging: the feature files alone are not self-contained specs
  for this chapter the way chapters 1–2 mostly were.
- The plate scenarios (`fan_bresenham`, `fan_wu`, `fan_coverage`, `plate_03`)
  are specified only as pseudocode in prose, not in the `.feature` file
  (which just checks their output). I translated the pseudocode directly
  rather than the JS figure code in the `<script>` (which takes a bounding-box
  shortcut around each ray for `fan_coverage` — a legitimate rendering
  optimization for a browser figure, but not what `fan_coverage()`'s own
  pseudocode says: it rasterizes the *full* 160×160 canvas per ray). Getting
  byte-identical output despite that shortcut existing right there in the
  chapter took a careful re-read to confirm the JS was a figure-drawing
  convenience, not the spec.

## Failures

None in the final suite. Two things surprised me enough to double-check
before trusting them:

- `chapter03-quad`'s "grid is blind along the diagonal" scenario asserts
  `ink(cov) = 9.7188` (exact, default tolerance 0.0001) **and**
  `ink(cov) = 9.8995 ± 0.25` in the same scenario — the second assertion is
  strictly weaker and always true given the first. Not a bug, just an odd
  scenario shape (reads like two drafts of the same check left in after an
  edit); flagging in case it's not intentional.
- `fan_coverage()`'s ink figure ("twenty million inside tests... twenty
  seconds") described an interpreted-language number. Compiled (Release,
  post-JIT-warmup), the entire 119-scenario suite plus every render write
  finishes in well under a second. Not a failure, just a reminder that the
  "it's slow" lesson doesn't reproduce under .NET the way the chapter
  implies it will for the reader trying this at home.

## Mistakes that stay green

Deliberately reintroduced five plausible bugs one at a time and reran the
suite:

| Mistake | Caught? | Detail |
|---|---|---|
| Bresenham `err` init to `0` instead of `dx/2` | **Yes**, hard | 5/9 bresenham scenarios fail, plus Plate 3 |
| Steep swap forgotten (Bresenham) | **Yes** | only "A steep line steps along y" + Plate 3 fail — the other 7 scenarios are shallow or exactly diagonal and don't need the swap |
| Steep swap forgotten (Wu) | **Yes** | 3/10 wu scenarios + Plate 3 fail |
| Wu weights swapped (`f` / `1-f` reversed) | **Yes**, hard | 5/10 wu scenarios + 2 plate scenarios fail |
| Wu `floor` replaced with `round` | **Yes** | 5/10 wu scenarios fail; "diagonal has uniform weights" *doesn't* catch it (integer y at every x, so floor and round agree) |
| `thick_line` half-planes facing outward | **Yes**, total | all 7 quad scenarios fail plus 1 plate scenario — an inverted half-plane empties the shape almost everywhere, impossible to miss |
| `thick_line` built from pixel corners, not centers | **Partially green** | only 2/7 quad scenarios + 1 plate scenario fail. The two "ink is the length" outline scenarios (4 angled lines) and the diagonal-blindness scenario all still pass, because shifting *both* endpoints by the same `(-0.5, -0.5)` is a rigid translation that doesn't change a shape's area or its angle relative to the sample grid — coverage-sum invariants like `ink` can't see a pure translation. Only tests that check *where* coverage lands (`coverage_at` at specific pixels, or pixel-value assertions in the plates) catch it. This is a real gap: a reader who only ran the outline scenarios and the diagonal one, skipping the horizontal-line scenario, would ship this bug undetected. |
| `lit_pixels` walks columns before rows (column-major, not reading order) | **Mostly invisible** | only 1 of 19 bresenham/wu scenarios that use `lit_pixels`/pixel-list checks fails ("A line going up and to the right"). Every other scenario's line has `x` and `y` moving in the same direction (or is exactly diagonal, `x == y`), so row-major and column-major orderings coincide by accident. This is the biggest real hole in the suite: reading order is asserted, but almost every scenario picked happens to not require it. |

## Prose

Chapter 3 is the strongest writing of the three so far. The Bresenham/Wu/
coverage progression builds real understanding (the "18% less paint" reveal
in §3.3 is genuinely satisfying), and the "special-purpose primitives are a
local optimum" closing line earns its place. Two small notes:

- The `ray_ends()` pseudocode uses `k * 30 degrees` — informal but
  unambiguous — while `line_bresenham`'s pseudocode is precise pidgin-code
  throughout. Fine, just a register shift worth knowing is intentional.
- "Two things in there are load-bearing" (steep swap, left-to-right swap) is
  a good instinct — it's exactly what the mutation testing above confirms
  matters — but the scenario `A line may run off the canvas` only ever
  tests the *count* of lit pixels (10), not their identity, so a bug that
  clips a line into a different but still-10-pixel shape would sail through.

## Would change

- Add one more Bresenham scenario with a genuinely negative-and-steep slope
  through pixels that aren't monotone in a way that makes reading order
  moot — something that actually distinguishes row-major from column-major
  the way "A line going up and to the right" does, but for a steep line too
  (right now only the shallow up-and-right case tests it).
- Tighten `thick_line`'s corner-vs-center coverage: add a scenario like
  `thick_line(0, 0, 4, 0, 1)` at asymmetric coordinates (not starting at the
  origin) so a corner/center off-by-half can't hide behind translation
  invariance the way it does now.
- Either drop or explain the redundant second assertion in "Except that the
  grid is blind along the diagonal" (`9.8995 ± 0.25` next to an exact
  `9.7188`).

## Results

- `chapter03-bresenham`: 9/9
- `chapter03-wu`: 10/10
- `chapter03-quad`: 7/7
- `chapter03-plate`: 5/5
- Chapter 3 total: 31/31
- Grand total (chapters 1–3): 119/119
- `dotnet run` (debug build + full suite + all renders): ~3.3s, dominated by
  the JIT/build step, not the scenarios themselves.
- Pre-built Release binary, all 119 scenarios + all renders, cold start to
  exit: ~0.70s.
- `out/fan-coverage.ppm` and `out/plate-03.ppm`: byte-identical to
  `reference/chapter-03/*.ppm` (`cmp` reports no difference), not merely
  within the ±1 tolerance the scenarios ask for.
- Time hotspot, measured directly (stub out `Renders.FanCoverage()` and
  rerun the Release binary): `fan_coverage()` — twelve `thick_line`
  rasterizations of a 160×160 canvas at 64 samples/pixel (~19.6M `Inside`
  calls per call site, called twice: once by its own scenario, once for the
  `out/` render) accounts for ~0.15s of the ~0.70s total, i.e. it's the
  single largest identifiable cost in the suite even though its absolute
  time is trivial. Everything else in chapters 1–3 is comparatively free.
