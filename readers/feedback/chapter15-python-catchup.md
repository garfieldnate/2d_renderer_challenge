# Python catch-up: chapters 13-15 (feedback)

## Result

- `python3 test_runner.py`: **518 scenarios, 518 passed, 0 failed** (up from 513/518 before this pass).
- `max_channel_difference` for every chapter 13-15 render, freshly generated to `out/chapter-NN/` and
  compared against `reference/chapter-NN/`:

  | Chapter | Render | max_channel_difference |
  |---|---|---|
  | 13 | joins.ppm | 0 |
  | 13 | plate-13.ppm | 0 |
  | 13 | caps.ppm | 0 |
  | 14 | two-strokes.ppm | 0 |
  | 14 | fold.ppm | 0 |
  | 14 | offsets.ppm | 0 |
  | 14 | plate-14.ppm | 0 |
  | 15 | even-marks.ppm | 0 |
  | 15 | dash-strip.ppm | 0 |
  | 15 | spiral-dashes.ppm | 0 |
  | 15 | plate-15.ppm | 0 |

  Every render is byte-exact against the current reference.

## Catch-up

Went through the task's list of known changes, plus a full diff-by-eye of every chapter 13-15
`.feature` file against what `test_runner.py` and `renderer.py` already handled.

- **`features/chapter15-pattern.feature`, negative-entry-with-positive-sum probe** (`normalize_pattern([6,
  -2]) = []`, `length(subpaths(dash(seg, [6, -2], 0))) = 1`): already present in the feature file and
  already passed on the old code — `normalize_pattern` already rejected any pattern containing a
  negative entry regardless of its sum, so no code change was needed here. No prior bug.
- **`lopsided()`'s new control points** (`chapter15-length.feature`'s "The parameter is not the
  length" and `chapter15-plate.feature`'s "Marks by parameter and by length"): **failed on the old
  code.** The old `lopsided()` returned `cubic((15,100), (20,20), (150,15), (185,95))`; chapter-15.html
  §15.1 and its embedded figure script (`function lopsided(){return
  [[15,100],[25,85],[100,5],[185,95]];}`) now define it as `cubic((15,100), (25,85), (100,5),
  (185,95))`. Fixed `lopsided()` in `renderer.py` to the new control points. This single fix cleared
  both failures: `arc_length(lopsided(), 256) = 198.0971` and the `even-marks.ppm` render both came
  back exact once the curve matched.
- **Chapter 15's spiral render renamed to `spiral-dashes.ppm`**: the reference directory only has
  `spiral-dashes.ppm` (no `spiral.ppm`), matching `chapter15-plate.feature`'s
  `read_file("reference/chapter-15/spiral-dashes.ppm")`. The renderer's render-script mapping in
  `README.md` still wrote it as `spiral.ppm`, which would have collided with chapter 6's `spiral.ppm`
  in a flat `out/` and mismatched the reference filename entirely. Fixed the README's render script
  and its `max_channel_difference` example to use `spiral-dashes.ppm`, and re-verified the actual
  render function (`renderer.spiral_dashes`) was already correctly named and unaffected in
  `renderer.py` — only the README's copy-paste script and prose needed the update.
- **`features/chapter14-curve.feature`'s exact `offset_distance_error` pin and hundred-point-walk
  wording**: already passed on the old code. Checked the wording against the implementation line by
  line — "u = i / 99 times the number of pieces for i = 0 to 99, each taken on piece floor(u) at
  parameter u - floor(u), the last on the last piece at 1" matches `offset_distance_error`'s
  `u = i / (n - 1) * len(pieces)` with `n = 100` (so `i / 99`), `idx = min(int(u), len(pieces) - 1)`,
  `local_t = u - idx`, and the last sample (`i = 99`) landing at `local_t = 1` on the last piece. No
  code change was needed; only confirmed the prose and code agree.
- **`features/chapter14-stroke.feature`'s new scenario, "The fold's tip lands exactly on a half, and
  is drawn one row down"**: **failed on the old code** — `round(42.5) = 43` came back `42 = 43`.
  Root cause: `test_runner.py` mapped the Gherkin `round(...)` step to Python's own built-in `round`
  (round-half-to-even: `round(42.5) == 42`), not the book's `round_half_up` (`floor(v + 0.5)`, which
  takes `42.5` to `43` and `-17.5` to `-17`, per chapter-13.html §13.5's pseudocode comment and
  chapter-14.html §14.5's prose). Fixed `test_runner.py`'s expression namespace to map `'round':
  renderer.round_half_up`. Checked the only other feature step using bare `round(...)`
  (`chapter01-srgb.feature`: `round(encode(0.5) * 255) = 188`) is nowhere near a half-integer boundary
  (`187.516...`), so the substitution doesn't disturb it.
  - This surfaced a second, real bug alongside the test-runner mapping: `renderer.py`'s
    `_outline_panel` (used by chapter 14's `two_strokes()`, `fold_demo()`, and hence `plate_14()`)
    was **rounding its `line_wu` endpoints with Python's built-in `round()`**, with a comment
    explicitly claiming this was correct ("Endpoint pixels use Python's own round-half-to-even (not
    chapter 1's round_half_up): ... that's the convention the reference render resolves the tie
    with"). That comment was wrong — the current reference renders resolve the tie the halves-up
    way, not round-half-to-even. This was silently correct before because chapter 14's old
    `hairpin()`/outline endpoints apparently didn't previously land on an exact half float in a way
    that differed between the two rules in the *committed* reference PPMs, or the pin simply hadn't
    existed yet to catch it. Whatever the history, on the current reference PPMs (`two-strokes.ppm`,
    `fold.ppm`, `plate-14.ppm`) the fix (round_half_up) is required: before the fix,
    `two-strokes.ppm` and `fold.ppm` differed from the reference (`max_channel_difference` 82 and 198
    respectively, both from the "Two strokes" and "The fold under two rules" scenarios in
    `chapter14-plate.feature`); after switching `_outline_panel` to `round_half_up`, both renders
    became byte-exact.

## Ambiguities

- None found this round that weren't already resolved by the stated instructions. The prompt's
  pointer to chapter-13.html §13.5's pseudocode comment and chapter-14.html §14.5's prose was
  sufficient to pin down which rounding rule is current; there's no remaining doubt.

## Failures

All failures were the reader's/old code's fault, not the book's:

1. `chapter15-length.feature` / `chapter15-plate.feature`: `lopsided()`'s control points were stale
   (old reader code, not updated after the book's §15.1 changed). Actual: `arc_length = 225.83`;
   expected: `198.0971`. Fixed by copying the new control points from the chapter's own figure
   script.
2. `chapter14-stroke.feature`: the test harness's `round` mapping used Python's native round-half-to-
   even instead of the book's `round_half_up`. Actual: `round(42.5) = 42`; expected `43`. Fixed the
   harness.
3. `chapter14-plate.feature` (both "Two strokes" and "The fold under two rules"): `_outline_panel`
   used Python's native `round()` for `line_wu` endpoints, with a comment that (incorrectly, as of
   the current reference images) asserted round-half-to-even was the right convention for chapter
   14's outline plates. Fixed by switching to `round_half_up`, matching chapter 13's identical
   `_outline_panel`-style code, which was already doing this correctly.

No bugs found in the book's prose, scenarios, or reference images this round — every failure was
the implementation drifting from an updated book.

## Prose problems

None to report for chapters 13-15 this round. Re-read chapter-13.html §13.5's pseudocode comment
and chapter-14.html §14.5's rounding paragraph specifically (the task's pointers) and both are
clear and unambiguous about halves-up rounding applying to negative halves too.

## Concrete changes

- `renderer.py`:
  - `lopsided()`: control points changed from `(15,100), (20,20), (150,15), (185,95)` to
    `(15,100), (25,85), (100,5), (185,95)`, matching chapter-15.html §15.1.
  - `_outline_panel` (chapter 14's plates): `round(...)` → `round_half_up(...)` for all four
    `line_wu` endpoint coordinates; docstring corrected to describe the halves-up rule instead of
    round-half-to-even.
- `test_runner.py`: the Gherkin expression namespace's `'round'` entry changed from Python's
  built-in `round` to `renderer.round_half_up`, so `round(42.5) = 43` and `round(-17.5) = -17`
  resolve per the book's stated rounding rule rather than Python's default.
- `README.md`:
  - Scenario count updated from 517 to 518.
  - Render-script mapping and the `max_channel_difference` example updated from
    `spiral.ppm`/`renderer.spiral_dashes` to `spiral-dashes.ppm`/`renderer.spiral_dashes`
    (the function name was already right; only the output filename in the doc's copy-paste script
    was stale).
  - The "note the name collision" paragraph rewritten: chapter 15's dashed spiral is no longer
    named `spiral.ppm` (that was the point of the rename), so the per-chapter-subdirectory
    rationale is now phrased as "was the reason, still a reasonable convention" rather than an
    active, present-tense collision.
  - Chapter 14's implementation-notes bullet rewritten to describe `round_half_up`
    (`floor(v + 0.5)`) instead of the old, now-incorrect claim that chapter 14 deliberately uses
    Python's round-half-to-even.
- No changes to `features/`, `reference/`, or any chapter HTML (none were needed, and none are
  permitted from this directory).
