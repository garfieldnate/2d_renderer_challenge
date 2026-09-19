# Catch-up feedback — Rust, chapters 13-15

## Result

- `cargo test --release`: 83 test binaries, 479 tests, **0 failed** (after fixes below).
- `cargo run --release --bin render_all` then a byte-level diff of every chapter 13-15 render
  against `reference/chapter-NN/`:

  | render | max_channel_difference |
  |---|---|
  | chapter-13/joins.ppm | 0 |
  | chapter-13/caps.ppm | 0 |
  | chapter-13/plate-13.ppm | 0 |
  | chapter-14/two-strokes.ppm | 0 |
  | chapter-14/fold.ppm | 0 |
  | chapter-14/offsets.ppm | 0 |
  | chapter-14/plate-14.ppm | 0 |
  | chapter-15/even-marks.ppm | 0 |
  | chapter-15/dash-strip.ppm | 0 |
  | chapter-15/spiral-dashes.ppm | 0 |
  | chapter-15/plate-15.ppm | 0 |

  All eleven are byte-exact, not merely within the ≤1 budget.

## Catch-up

Everything below was actually missing or stale in the code before this pass — each one either
failed outright or would have failed the moment the corresponding scenario ran.

- **`lopsided()`'s control points** (`src/lib.rs`). The code had
  `cubic(point(15,100), point(20,20), point(150,15), point(185,95))`; chapter-15.html §15.1's
  `lopsided()` now returns `cubic(point(15,100), point(25,85), point(100,5), point(185,95))`.
  `tests/length15.rs`'s `the_parameter_is_not_the_length` still carried the *old* curve's numbers
  (`total=225.8293`, midpoint `(88.75,37.5)`, etc.) — it was passing only because the stale test
  matched the stale implementation. Fixed the curve and the test's five pinned numbers to match
  `chapter15-length.feature` (`total=198.0971`, midpoint `(71.875,58.125)`, etc.).
- **`chapter15-plate.feature`'s `even_marks()` pixel probes** (`tests/plate15.rs`) were also stale
  from the old `lopsided()` — `(89,37)`/`(295,37)` instead of the feature's `(71,58)`/`(298,52)`.
  The render itself was already correct (it calls `lopsided()` directly), only the test's
  hard-coded probe coordinates were wrong; would have failed the moment `lopsided()` was fixed
  above, since the marks physically moved.
- **Chapter 15's spiral render renamed to `spiral-dashes.ppm`.** `tests/plate15.rs` still read
  `reference/chapter-15/spiral.ppm`, which no longer exists in `reference/` (only
  `spiral-dashes.ppm` does) — this would have failed with a file-not-found the moment the stale
  `reference/chapter-15/spiral.ppm` copy that used to satisfy it was removed. Fixed the read path,
  and `src/bin/render_all.rs` line 111, which wrote `spiral_dashes()`'s canvas to `out/spiral.ppm`
  (silently colliding with chapter 6's `spiral()` render of the same name) — now writes
  `out/spiral-dashes.ppm`, so the collision the old README called out no longer exists.
- **`normalize_pattern([6, -2])` / `dash(seg, [6, -2], 0)`** (`tests/pattern.rs`). The new probe in
  `chapter15-pattern.feature` — a pattern with a *positive* sum but a negative entry — was entirely
  untested. It did **not** fail: `normalize_pattern`'s existing `neg || sum <= 0.0` check already
  rejects on `neg` alone, independent of the sum's sign, so the implementation was already correct.
  Added the two missing assertions so this branch is actually exercised.
- **`offset_distance_error(q, -2, 0.01) = 0.707336 ± 0.0001`** (`tests/curve14.rs`). The exact-value
  probe from `chapter14-curve.feature` was missing (only the `≥ 0.7` bound was tested). Checked the
  hundred-point-walk implementation against the feature's now-exact description ("u = i / 99 times
  the number of pieces ... the last on the last piece at 1") — `offset_distance_error` in
  `src/lib.rs` already matches it exactly (`u = i/99 * n`, `idx = floor(u).min(n-1)`,
  `local_t = (u - idx).min(1.0)`). No code change needed; added the missing assertion, which passes.
- **"The fold's tip lands exactly on a half" scenario** (`chapter14-stroke.feature`, new) was
  missing entirely from `tests/stroke14.rs`. Translating it exposed a real, live bug: it pins
  `round(-17.5) = -17`, and chapter 1's `round` was `x.round() as i64` (Rust's ties-away-from-zero),
  which gives `round(-17.5) = -18`. **Fixed** `round` in `src/lib.rs` to `(x + 0.5).floor() as i64`
  (ties up / toward +infinity, i.e. `floor(v + 0.5)`), which chapter 1's own byte conversion never
  distinguished from ties-away-from-zero because it never sees a negative argument. Added the
  scenario to `stroke14.rs`; it passes with the fix and would have failed without it.
- **Chapter 13 §13.5 / chapter 14 §14.5's rounding rule reversed the earlier fix.** A previous round
  of this catch-up (see the old README "A real bug the fold scenario found" section) added
  `round_half_to_even` — ties-to-even — for `stroke_panel` and `outline_panel_rule`'s `line_wu`
  coordinates, to match what was then believed to be the reference figure's Python `pyround`. The
  book has since settled the question explicitly the *other* way: chapter 13's pseudo-code comment
  now reads `// line_wu, endpoints rounded to nearest, halves up`, and chapter 14 §14.5 says outline
  coordinates round "to the nearest pixel, halves up, the same rule chapter 1's byte conversion
  uses," calling out that a ties-to-even language "draws a different picture there and misses the
  reference by a pixel column." Removed `round_half_to_even` entirely and switched `stroke_panel`
  and `outline_panel_rule` to call chapter 1's `round` (now itself fixed to real halves-up, see
  above). Every chapter 13-15 render still diffs 0 against `reference/` with this combination — the
  hairpin's half-integer vertices land the same place under "chapter-1 round, fixed for negatives"
  as they did under "ties to even," which makes sense since `round_half_to_even(42.5) = 42` and
  `round(42.5) = 43` are the two candidates the book was choosing between, and it settled on the
  latter.
- **"A square cap extends a half-width past the end"** (`chapter13-degenerate.feature`) was missing
  from `tests/degenerate.rs` — not called out in the task brief, found by the file-by-file
  comparison. Not a code bug (`stroke_to_path` already produces the pinned points); just an
  untranslated scenario. Added it.

Everything else in `features/chapter13*.feature`, `chapter14*.feature`, `chapter15*.feature` was
checked scenario-by-scenario against the corresponding `tests/*.rs` file and already matched
(chapter13-stroke, chapter13-miter, chapter13-plate, chapter14-curvature, chapter14-fit,
chapter14-offset, chapter14-plate, chapter15-closed, chapter15-dash were all already faithful and
current).

## Ambiguities

- Nothing in the current `features/chapter13-15*.feature` files was ambiguous once read alongside
  chapter-13.html §13.5 and chapter-14.html §14.5's prose — the "halves up" rule is stated in both
  the pseudo-code comment and the prose, in the open, which is exactly what let this catch-up catch
  the regression instead of having to guess.
- One thing worth flagging for the book, not the code: chapter 1's own `round` doc comment ("No
  scenario in this chapter lands on a half, so the tie-breaking rule doesn't matter") is still true
  *for chapter 1*, but it's no longer true for the renderer as a whole once chapter 14 pins a
  negative half through the same function. A reader who implements `round` as `x.round()` in a
  language where that ties away from zero (Rust, Java, C's `round()`, Python's `round()` does NOT —
  it ties to even) will pass every chapter 1-13 scenario and then fail chapter 14's
  `round(-17.5) = -17` with no warning beforehand that `round` needed to handle negative halves
  specially. A one-line forward-reference in chapter 1 ("this rule gets pinned on a negative number
  in chapter 14") would have saved the debugging step here.

## Failures (before fixes, actual vs expected)

- `stroke14.rs`, new scenario: `round(-17.5)` — actual `-18` (Rust `f64::round`, ties away from
  zero), expected `-17` (book: ties up, `floor(v + 0.5)`). **Renderer's fault** (chapter 1's `round`
  was implemented with the wrong tie-break for negative arguments, latent since chapter 1 because no
  chapter 1 scenario is negative).
- `plate15.rs`, `marks_by_parameter_and_by_length`: probes at `(89,37)`/`(295,37)` no longer match
  `chapter15-plate.feature`'s `(71,58)`/`(298,52)` once `lopsided()` is corrected — this is a stale
  test, not a rendering bug; the render itself (`even_marks()`) was always going to move once
  `lopsided()`'s control points were fixed, since it draws that exact curve.
  **Prior test's fault**, not the renderer's.
- `plate15.rs`, `the_spiral_dashed`: `read_file("reference/chapter-15/spiral.ppm")` — that file no
  longer exists in `reference/chapter-15/` (only `spiral-dashes.ppm` does), so this would fail with
  an I/O error rather than a value mismatch. **Prior test's fault** — filename never updated after
  the book renamed the render.
- No actual pixel or scenario value in `reference/` disagreed with a correct implementation anywhere
  in chapters 13-15; every failure traced to code lagging the book (the `round` tie-break) or a test
  lagging a data change (`lopsided()`, the spiral filename).

## Prose problems

None found in chapter-13.html, chapter-14.html or chapter-15.html during this pass — both the
halves-up rounding rule and the hundred-point `offset_distance_error` walk are stated exactly and
in the open, in prose and pseudo-code, which is what made this catch-up mechanical rather than a
guessing game.

## Concrete changes

- `src/lib.rs`:
  - `round(x)`: `x.round() as i64` → `(x + 0.5).floor() as i64` (ties up, not away from zero).
  - Removed `round_half_to_even`; `stroke_panel` and `outline_panel_rule` now call `round` for both
    coordinates of every `line_wu` endpoint.
  - `lopsided()`: control points updated to `(15,100), (25,85), (100,5), (185,95)`.
- `src/bin/render_all.rs`: chapter 15's spiral render now written to `out/spiral-dashes.ppm`
  (was `out/spiral.ppm`, colliding with chapter 6's `spiral()`).
- `tests/length15.rs`: `the_parameter_is_not_the_length`'s five pinned numbers updated for the new
  `lopsided()`.
- `tests/plate15.rs`: `marks_by_parameter_and_by_length`'s two pixel probes corrected; `spiral.ppm`
  reference path changed to `spiral-dashes.ppm`.
- `tests/pattern.rs`: added the `normalize_pattern([6, -2])` / `dash(seg, [6, -2], 0)` assertions.
- `tests/curve14.rs`: added the exact `offset_distance_error(q, -2, 0.01) = 0.707336 ± 0.0001`
  assertion.
- `tests/stroke14.rs`: added the whole "fold's tip lands exactly on a half" scenario
  (`the_folds_tip_lands_exactly_on_a_half_and_is_drawn_one_row_down`).
- `tests/degenerate.rs`: added the missing "A square cap extends a half-width past the end"
  scenario.
- `README.md`: rewrote the chapter 13/14 rounding-mode note to describe the halves-up correction
  (superseding the earlier ties-to-even fix) and updated the `out/` filename-collision note now that
  `spiral-dashes.ppm` no longer collides with chapter 6's `spiral.ppm`.
