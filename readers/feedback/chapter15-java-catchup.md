# Catch-up feedback: Java, chapters 1-15

This is a catch-up pass, not a fresh read. The code already implemented
chapters 1-15; `features/` and `reference/` had moved on since. This file
covers what changed, what broke, and what's still rough.

## Result

Full suite, run from this directory after `javac -d classes src/*.java`:

| Chapter | Scenarios | Pass | Fail |
|---|---|---|---|
| 1 | 66 | 66 | 0 |
| 2 | 35 | 35 | 0 |
| 3 | 38 | 38 | 0 |
| 4 | 76 | 76 | 0 |
| 5 | 32 | 32 | 0 |
| 6 | 34 | 34 | 0 |
| 7 | 34 | 34 | 0 |
| 8 | 23 | 23 | 0 |
| 9 | 45 | 45 | 0 |
| 10 | 24 | 24 | 0 |
| 11 | 17 | 17 | 0 |
| 12 | 13 | 13 | 0 |
| 13 | 21 | 21 | 0 |
| 14 | 27 | 27 | 0 |
| 15 | 28 | 28 | 0 |
| **Total** | **493** | **493** | **0** |

(Chapter 13 is 19 `Scenario:`s plus one `Scenario Outline:` with three
examples = 21 test cases; chapter 4's outline counts the same way.)

`max_channel_difference` of every chapter 13-15 render, freshly written to
`out/` and compared against `reference/`:

| Render | Diff |
|---|---|
| `caps.ppm` | 0 |
| `joins.ppm` | 0 |
| `plate-13.ppm` | 0 |
| `fold.ppm` | 0 |
| `offsets.ppm` | 0 |
| `plate-14.ppm` | 0 |
| `two-strokes.ppm` | 0 |
| `dash-strip.ppm` | 0 |
| `even-marks.ppm` | 0 |
| `plate-15.ppm` | 1 |
| `spiral-dashes.ppm` | 1 |

The two 1s are the pre-existing per-dash antialiasing seam noted by the
previous round (painting each dash separately means two dashes' edges can
land on the same pixel twice), within the `<= 1` budget every plate
scenario allows. Nothing here needed a code fix beyond what's below.

## Catch-up

Each item: what changed in `features/`/`reference/`, whether the old code
failed it, and the fix.

1. **`chapter15-pattern.feature` gained a `[6, -2]` case** (a pattern with a
   negative entry but a positive sum: 6 + (-2) = 4). **Did not fail** --
   `Dash.normalizePattern` already rejected any negative entry regardless of
   the sum (`if (negative || sum <= 0) return empty`), so the new assertion
   just needed adding to `Chapter15Tests.registerPattern()`; no production
   code changed. This is exactly the kind of scenario CLAUDE.md's "probe
   each half of a compound rule separately" rule wants: the old test only
   ever combined "negative" with "sum <= 0" (`[5, -5]`, sum 0), so a
   hypothetical implementation that checked `sum <= 0` and *then* checked
   for negatives only inside that branch would have passed every old
   scenario while being wrong. Added `normalize_pattern([6, -2]) = []` and
   `length(subpaths(dash(seg, [6, -2], 0))) = 1` per the feature (replacing
   the old `[5, -5]` dash check, matching the feature file's own choice).

2. **`lopsided()` got new control points**, read from chapter-15.html
   §15.1's embedded JS (`function lopsided(){return
   [[15,100],[25,85],[100,5],[185,95]];}` -- there is no other place in the
   chapter that states them; the prose only gives the resulting midpoints).
   Old code had `(15,100),(20,20),(150,15),(185,95)`. **Failed**: every
   pinned value in `chapter15-length.feature`'s "The parameter is not the
   length" scenario and `chapter15-plate.feature`'s "Marks by parameter and
   by length" scenario changed (`arc_length` 225.8293 -> 198.0971,
   `point_at(0.5)` (88.75, 37.5) -> (71.875, 58.125), etc.), and the
   `even-marks.ppm` reference image changed too. Fixed `Figures.lopsided()`
   to the new control points and updated every pinned value in
   `Chapter15Tests` to match the feature file exactly (including the two
   `ppm_pixel` probe coordinates, which moved because the marks moved).

3. **`chapter15-plate.feature`'s spiral render is now `spiral-dashes.ppm`**,
   not `spiral.ppm`. **Failed** on the reference lookup (old code tried to
   read `reference/chapter-15/spiral.ppm`, which no longer exists -- only
   `spiral-dashes.ppm` does). Fixed the `readReference` call and the
   `writeRenders` output filename in `Chapter15Tests`. Bonus: this also
   quietly fixes the name collision the old README documented between
   chapter 6's `out/spiral.ppm` and chapter 15's dashed spiral of the same
   name -- they're distinct files now, no workaround needed.

4. **`chapter14-curve.feature` pins `offset_distance_error` to an exact
   value** on the fold case (`offset_distance_error(q, -2, 0.01) = 0.707336
   ± 0.0001`, not only `>= 0.7`), and its feature description now states the
   hundred-point walk exactly (`u = i / 99` times piece count, floor/frac
   split, last point clamped to `t = 1` on the last piece). **Did not
   fail** -- `Offset.offsetDistanceError`'s `WALK_POINTS = 100` walk already
   matched that exact parameterization (checked the source against the
   prose line by line), so this was a pure test-suite gap: the old scenario
   only had a `>=` bound, which is satisfiable by many wrong
   parameterizations (e.g. sampling `i / 100` instead of `i / 99`, or not
   clamping the last point). Added the exact assertion to
   `Chapter14Tests.registerCurve()`.

5. **`chapter14-stroke.feature` gained "The fold's tip lands exactly on a
   half, and is drawn one row down"**, pinning
   `stroke_curve_to_path(hairpin(), 60, "butt", 0.25)`'s points 13 and 42 to
   `(80, 42.5)` and `(80, -17.5)`, plus `round(42.5) = 43` and
   `round(-17.5) = -17` directly. **Did not fail** on the geometry (points
   13 and 42 were already exactly (80, 42.5) and (80, -17.5), unaffected by
   the rounding rule -- rounding only happens at draw time in
   `outlinePanel`/`tracedPanel`, not in `strokeCurveToPath` itself), but the
   scenario didn't exist in the suite. Added it verbatim, including the two
   `Numbers.round` calls the scenario pins directly (a scenario this
   specific about a rounding tie deserves the tie tested as a scalar, not
   only through a render diff). This is the scenario the round-half-up-vs-
   half-to-even rule below exists to protect.

6. **Chapter 13's and chapter 14's outline-over-fill renders round line
   endpoints to nearest with halves up (`floor(v + 0.5)`), not
   half-to-even.** This is a *reversion*, not a new rule: the code
   contained a prior fix (documented in the old README, "A rounding fix
   that reached back into chapter 13") that added
   `Numbers.roundHalfEven` and switched both `Figures.tracedPanel`
   (chapter 13) and `Figures.outlinePanel` (chapter 14) to it, to match a
   round-half-to-even quirk that used to be in the reference
   implementation's rounding. The reference has since been fixed to use
   plain halves-up rounding (chapter 1's rule, stated explicitly now in
   chapter-13.html §13.5's pseudocode comment -- "endpoints rounded to
   nearest, halves up" -- and chapter-14.html §14.5's prose -- "rounded to
   the nearest pixel, halves up"), and `chapter14-stroke.feature`'s new
   scenario (item 5) pins the halves-up answer directly:
   `round(-17.5) = -17`, which is what `Math.round` (Java's halves-up,
   toward positive infinity) already gives, and what round-half-to-even
   would *not* give (`-17.5` rounds to the nearest even integer, `-18`,
   under that rule -- one row off). **Would have failed** the new stroke
   scenario had `roundHalfEven` stayed wired in (checked: half-to-even of
   `-17.5` is `-18`, of `42.5` is `42`, both wrong under the new rule).
   Fixed by reverting both call sites in `Figures.java` to `Numbers.round`
   and removing `Numbers.roundHalfEven` outright (dead code that would
   mislead the next reader into thinking half-to-even is still the rule
   anywhere in this book). Chapter 13's and 14's renders still diff 0
   against `reference/`, confirming the reference was fixed the same way.

## Ambiguities

- None found this round that two or more "readers" would hit -- this is a
  single-reader catch-up pass, so there's no cross-reader signal here. But
  worth flagging for a future reader round: `chapter15-pattern.feature`'s
  new `[6, -2]` scenario is a genuine trap for a reader who writes
  `normalize_pattern` by checking `sum <= 0` first and only checks for a
  negative entry as a special case of "no pattern," rather than as an
  independent condition. The prose already says "a pattern with a negative
  entry, or whose entries add up to nothing, is no pattern at all" (an
  "or", correctly), but a reader skimming for the *sum* check and treating
  "negative" as flavor text could still get this wrong. The new scenario is
  exactly the fix.

## Failures

None outstanding. Every failure encountered during this pass was in the
*old test suite* (comparing stale pinned values or reading a renamed
reference file), not in the implementation, except for one real revert
(item 6) which was a leftover fix from a previous round of the reference
implementation that the reference itself has since undone. All fixed; see
Catch-up above for actual-vs-expected on each.

## Prose problems

- None new. The chapter-13/14 pseudocode comments and chapter-15's figure
  JS were sufficient to find every changed number without guessing (the
  `lopsided()` control points specifically required going to the embedded
  JS, since the prose only states the resulting midpoints -- this matches
  the pattern already flagged in this reader's own chapter 7 and 8 feedback
  from the original round, where pseudocode had to be read exactly rather
  than approximated).

## Concrete changes

- `src/Figures.java`: `lopsided()` control points updated to `(15, 100)`,
  `(25, 85)`, `(100, 5)`, `(185, 95)`. Both `tracedPanel` (chapter 13) and
  `outlinePanel` (chapter 14) switched from `Numbers.roundHalfEven` back to
  `Numbers.round`.
- `src/Numbers.java`: removed `roundHalfEven` (unused after the above, and
  actively wrong under the book's current rule).
- `src/Chapter14Tests.java`: added the exact `offset_distance_error(q, -2,
  0.01) = 0.707336 ± 0.0001` assertion to the existing "on the inside of a
  tight bend" scenario; added the new "the fold's tip lands exactly on a
  half, and is drawn one row down" scenario.
- `src/Chapter15Tests.java`: updated the "the parameter is not the length"
  scenario's four pinned values (total, `point_at(0.5)`,
  `point_at_length`, `t_at_length`) to match the new `lopsided()`; updated
  the "marks by parameter and by length" scenario's two `ppm_pixel` probe
  coordinates and expected colors; added `normalize_pattern([6, -2]) = []`
  and its `dash` scenario; renamed the spiral-dashed render's reference
  read and `out/` write from `spiral.ppm` to `spiral-dashes.ppm`.
- `README.md`: rewrote the chapter 14 rounding paragraph to describe the
  halves-up rule (and the revert away from half-to-even) instead of the
  stale half-to-even fix; updated the chapter 15 section to state
  `lopsided()`'s new control points and explain the pinned-value change;
  replaced the `out/spiral.ppm` name-collision note (no longer true) with a
  note that `spiral-dashes.ppm` and chapter 6's `spiral.ppm` are distinct
  files now; updated the `offsetDistanceError` paragraph to note the walk
  is now pinned exactly, not only bounded, and that no code changed there
  since the existing `WALK_POINTS = 100` walk already matched the spec.
