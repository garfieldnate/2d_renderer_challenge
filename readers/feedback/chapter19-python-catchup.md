# Chapter 18-19 catch-up pass (Python reader)

## What changed

`features/chapter18-*.feature` and `features/chapter19-*.feature` gained 5
scenarios since this code last ran (611 -> 616 total). `test_runner.py`
globs every `.feature` file and parses steps generically (no hand-curated
scenario list), so no scenario needed manual "adding" -- running the suite
against the current `features/` directory was enough to pick all of them
up. Scenario counts by file, now vs. the 611-scenario baseline recorded in
the old README:

- `chapter18-aligning.feature`, `chapter18-plate.feature`: chapter 18 went
  from 20 to 21 scenarios (net +1 across these files).
- `chapter19-ligatures.feature`, `chapter19-marks.feature`,
  `chapter19-position.feature`, `chapter19-plate.feature`: chapter 19 went
  from 27 to 31 scenarios (net +4 across these files).

Without the old feature files to diff against, I couldn't attribute each
new scenario to a specific file with certainty (only that the six files
above are where the task said scenarios had been gained). What I *can*
say with certainty, from actually running the suite: of the 616 scenarios
now in `features/chapter18-*.feature` and `features/chapter19-*.feature`,
exactly one failed on the pre-catch-up code.

## The one failure, and the fix

`chapter19-position.feature`, scenario "A mark between two glyphs neither
moves the pen nor breaks their kern pair":

```
caret_positions(toy, b, 3, 10, 10, "ltr", true) = [10, 15, 21]
```

Old code produced `[10, 16.0, 21.0]` -- the middle checkpoint was off by
one kern unit (kern pair is -100 in font units, size 10, units_per_em
1000, so 1 pixel).

Root cause, in `renderer.py`'s `caret_positions`: it recorded a cluster's
checkpoint (the pen position) *before* applying the kern adjustment for
the glyph about to be placed, then applied kern and advance afterward.
`position()` (which places the actual glyphs) applies kern *first*, then
records the placement, then applies the advance. The two functions
disagreed on ordering, and it never showed up before because no earlier
scenario had a caret checkpoint sitting exactly at a kerned pair with a
mark in between them (the mark is what makes `prev_glyph` skip over the
gap and still find the kern pair).

Fix: reordered `caret_positions` so that, for both `"ltr"` and `"rtl"`,
the kern adjustment against `prev_glyph` is applied first, *then* the
checkpoint is recorded if the cluster changed, *then* the glyph's own
advance is applied. This exactly mirrors `position()`'s
kern-then-place-then-advance order. Verified by hand for both directions
against the scenario's expected `[10, 15, 21]` (ltr) and `[21, 16, 10]`
(rtl) before running the suite, and both now pass along with every other
scenario (616/616 total).

## Ambiguities / things worth a second look

None found. The fix brings `caret_positions` in line with the existing,
already-correct `position()` function's ordering, so there's no remaining
disagreement between "where a glyph is placed" and "where the caret
before/after it stands." No scenario looked wrong or under-specified;
`buffer_advance`, `position`, `attach_marks`, and `caret_offsets` were all
already correct for this same font/buffer (the scenario's earlier
assertions on `b[1].dx`, `b[1].dy`, `run[1].x/y`, `run[2].x/y`, and
`buffer_advance(...)` all passed against the pre-fix code -- only the
caret checkpoint ordering was wrong).

## Renders

Regenerated `out/chapter-18/*.ppm` and `out/chapter-19/*.ppm` (9 files:
`kerning.ppm`, `breaking.ppm`, `drift.ppm`, `plate-18.ppm`,
`ligature.ppm`, `forms.ppm`, `word.ppm`, `mixed.ppm`, `plate-19.ppm`).
All 9 diff `max_channel_difference` 0 against `reference/chapter-18/` and
`reference/chapter-19/`. `caret_positions` is used by the `_caret_ticks`
helper in `ligature.ppm` and `plate-19.ppm`; both stayed byte-exact,
meaning the reference renders' caret ticks never happened to land at a
kerned checkpoint (the bug was invisible in the renders and only caught
by the new scenario's explicit assertion).

## Suite state

`python3 test_runner.py`: 616 scenarios, 616 passed, 0 failed.
