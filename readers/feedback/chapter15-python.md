# Feedback: chapters 14 and 15 (Python reader)

Full suite: **517/517 scenarios pass**, all eight new renders (`two-strokes.ppm`, `fold.ppm`,
`offsets.ppm`, `plate-14.ppm`, `even-marks.ppm`, `dash-strip.ppm`, `spiral.ppm`, `plate-15.ppm`)
and the three re-rendered chapter 13 plates (`joins.ppm`, `plate-13.ppm`, `caps.ppm`) diff **0**
against `reference/`.

## Catch-up (chapter 13 revision)

Before touching chapter 14 I re-ran the existing chapter 1-13 code against the current
`features/`, per instruction 0. `features/chapter13-stroke.feature` had scenarios the old code
did not satisfy:

- **"A chevron's join is a different shape for each join style" (round case)** — failed:
  `length(subpaths(o)[2].points) = 24`, expected `13`.
- **"The round join is an arc across the outer gap, not around the inside"** — failed outright
  (wrong point values).
- **"Every piece winds the same way, so overlapping pieces add instead of cancelling"** — failed:
  `polygon_area(o) = 4829.7`, expected `-4981.625`.
- **"A wide stroke around a tight bend overlaps itself and stays solid"** — crashed:
  `u_turn()` did not exist in the code at all.
- `chapter13-plate.feature`'s `"The three joins"` and `"Plate 13"` — failed, `max_channel_difference = 198`.

Everything else in chapters 1-13 (`chapter13-degenerate.feature`, `chapter13-miter.feature`, and
the rest of `chapter13-stroke.feature`) was already green, so I take those to be pre-existing,
unchanged scenarios.

Root causes and fixes, all in `renderer.py`:

1. **Round join swept the long way.** `_join_shape`'s `"round"` branch picked `a1` by testing
   the *outer-side sign* (`s`) against whether `a1 < a0`, which is not the same thing as "the
   short way round." Replaced it with the wrapped angular difference
   `((a1 - a0 + pi) % (2*pi)) - pi`, which always takes the short way regardless of how `a0`/`a1`
   happen to compare numerically.
2. **Pieces weren't oriented consistently.** `stroke_to_path` appended every rectangle/join/cap
   subpath as computed, with no check on which way it wound. Added a shared `_emit` helper that
   reverses a piece's points whenever its signed area is positive, so every piece is
   counterclockwise on screen before it's appended — this is what the `u_turn()` scenario and the
   `polygon_area` scenario exist to catch.
3. **`polygon_area` had to become signed.** The scenario pins `polygon_area(o) = -4981.625` (a
   negative number), but the existing implementation returned `abs(total) / 2`. Removed the
   `abs()`. I checked this doesn't disturb chapter 7: every chapter 7 scenario that compares
   `ink(...)` to `polygon_area(...)` already relies on shapes wound so their signed area is
   already positive (clockwise on screen, matching `ink`'s always-non-negative coverage sum), so
   dropping `abs()` doesn't change any of those values — confirmed by re-running the full
   chapter 7 suite, still green.
4. **`u_turn()` was simply missing.** Added it per the chapter's own prose description (nine
   points on the upper half of a circle of radius 10 about `(50, 50)`, 180° to 360° in steps of
   22.5°).

After these four fixes, all of chapters 1-13 pass (persisted through my later chapter 14/15
work), and I regenerated and re-diffed `joins.ppm`, `plate-13.ppm`, `caps.ppm` — all 0.

## Chapter 14 — Offsetting Curves

**Result:** 26 scenarios across `chapter14-{curvature,curve,fit,offset,plate,stroke}.feature`,
all pass. Renders: `two-strokes.ppm` 0, `fold.ppm` 0, `offsets.ppm` 0, `plate-14.ppm` 0.

**Ambiguities (what I guessed, and what I'd pin down):**

- *The pixel-rounding convention for the outline's magenta overlay.* This is the one real find of
  the chapter. `two_strokes()`/`fold_demo()` draw the generated outline over the fill with
  `line_wu`, same as chapter 13's plates, which round each endpoint with chapter 1's
  `round_half_up` before drawing. Doing the same thing for chapter 14 rendered every scenario's
  numeric checks correctly but missed `max_channel_difference ≤ 1` by 82 (`two-strokes.ppm`) and
  198 (`fold.ppm`). I diffed pixel-by-pixel and found the mismatch concentrated at one point,
  exactly on the hairpin's axis of symmetry, where the outline has a vertex at **exactly**
  `y = 42.5` (not floating-point noise — I printed the value with `repr()` and it's `42.5` on the
  nose, since the hairpin and its offset are exactly mirror-symmetric there). `round_half_up`
  sends that to row 43; the reference lands it on row 42. Python's built-in `round()`
  (round-half-to-even; `42` is even) matches the reference. I only found this because chapter
  13's own figure JS in the book uses plain `Math.round` (round-half-up, matches
  `round_half_up`) for its `Buf.wu`, but chapter 14's figure JS uses a hand-written `pyround`
  that explicitly implements round-half-to-even — a real, deliberate difference between the two
  chapters' own reference code that the prose never mentions. Nothing in chapter 13 or 14's text
  says which convention a stroke/offset plate's line-drawing helper should use; a reader has no
  way to know this matters until they hit this exact tie. **Concrete fix:** either say so in
  prose (e.g. "round pixel coordinates for debug overlays with the language's default round, not
  `round_half_up`"), or better, nudge `hairpin()`'s control points so the swallowtail tip isn't
  exactly symmetric and doesn't land on a hard tie at all — this is exactly the "never pin a
  value that sits near .5" principle from your own notes, just applied to a line-drawing
  coordinate instead of a color byte.
- *`cusps(c, d)`'s "64 evenly spaced parameters."* I first read this as 64 samples inclusive of
  both endpoints, `t = i/63` for `i = 0..63`. Every scenario passed. Only when chasing the
  `two-strokes.ppm` mismatch above did I check the book's own figure JS and find it actually
  samples `t = i/64` for `i = 0..64` (65 points, one more than "64" suggests, because it keeps an
  initial `f(0)` outside the loop and then samples `i = 1..64`). Switching to match made no
  difference to any test outcome — bisection converges to the same root from either bracketing,
  so this ambiguity is currently untestable by any scenario in the book. I switched anyway to
  match the reference exactly, but this is worth being precise about in prose since it's a
  genuinely different sampling scheme that only coincidentally gives the same answers here.
- *`offset_distance_error`'s "100 points spread along the result."* Not fully specified how the
  100 samples are distributed across a multi-piece result. I distributed them evenly across
  piece *count* (not piece arc length), i.e. `u = i/99 * len(pieces)`. Every scenario using this
  function is an inequality (`≤ 0.01`, `≥ 0.7`), so this choice is untestable either way; a
  length-weighted distribution would give different exact numbers but satisfy the same
  inequalities.

**Hard to translate:** nothing chapter-specific; the pseudocode in §14.1-14.6 is given as
literal formulas and translated almost mechanically. The one piece of friction was purely
mechanical: this project's `test_runner.py` keeps one big hand-written `namespace` dict mapping
every callable name into `evaluate_expression`'s `eval` scope, so every new top-level function
(`tangent_at`, `offset_point`, `cusps`, ... seventeen names for this chapter alone) has to be
added there by hand or every scenario using it silently `NameError`s. Not a chapter-content
issue, just a place a reader loses time if they forget the step.

**Failures:** none remaining.

**Mutation results:**

| # | Mutation | Caught? | How |
|---|---|---|---|
| 1 | `normal_at` returns the tangent turned the *wrong* quarter turn (offset on the wrong side) | Yes | 18 of 26 chapter 14 scenarios fail immediately — essentially every scenario that touches `offset_point` |
| 2 | `cusps` looks for `1 + curvature*d` changing sign instead of `1 - curvature*d` | Yes | 11 scenarios fail, including the cusp-count and cusp-position scenarios directly |
| 3 | `offset_curve` doesn't split at cusps (fits the whole curve as one region) | Yes | 8 scenarios fail: piece counts, chained-endpoint scenario, and both plate images |
| 4 | `stroke_curve_to_path` skips "drop the last point if it equals the first" | **Barely** — 1 of 517 | Only `point_count(..., "round", ...) = 88` fails (89 vs 88). The primary, more prominent scenario (`length(subpaths(o)[0].points) = 58`, butt caps) never exercises this line at all, because with butt caps the outline's first and last points are on opposite sides of the curve and never coincide. |

No mutation slipped past every scenario, but #4 is thin: a single indirect point-count check is
the only thing standing between this rule and silently going unenforced. See concrete changes
below.

**Concrete changes I'd make:**

1. Pin the pixel-rounding convention for plate-drawing helpers, or remove the tie by nudging
   `hairpin()` off-symmetric.
2. Spell out `cusps`'s exact sample formula (`t = i/64, i = 0..64`, 65 samples) rather than "64
   evenly spaced parameters," even though no current scenario would catch the difference.
3. Add a scenario that checks `stroke_curve_to_path`'s "drop duplicate closing point" rule
   directly (e.g. assert the specific point list of a case where the outline actually closes up),
   not just via a round-cap point count.

**Timing:** `two-strokes.ppm` 0.12s, `fold.ppm` 0.12s, `offsets.ppm` 0.59s, `plate-14.ppm` 0.95s
(wall clock, single core, nothing parallelized).

## Chapter 15 — Dashes

**Result:** 28 scenarios across `chapter15-{closed,dash,length,pattern,plate}.feature`, all
pass. Renders: `even-marks.ppm` 0, `dash-strip.ppm` 0, `spiral.ppm` 0, `plate-15.ppm` 0.

**Ambiguities:**

- `dash_count(p, pattern, phase)` is used once, in `chapter15-plate.feature`
  (`dash_count(sp, [16, 10], 0) = 17`), and is never defined in either chapter's prose or the
  feature file's `Feature:` preamble — every other new helper in this book gets a one-line
  definition there. I inferred it means `length(subpaths(dash(p, pattern, phase)))` from the
  scenario alone (it does, and the scenario passes), but this is a guess a reader has to make
  from naming convention rather than being told.
- Everything else in this chapter is given as literal pseudocode (`dash`'s walk, `normalize_pattern`'s
  rules) precise enough that translation was closer to transcription than design.

**Hard to translate:** nothing. Lists, modular arithmetic, and the walk's state machine map onto
Python directly; the only real decision (how to represent "current open dash," `None` vs. an
in-progress list) is exactly what the pseudocode already suggests.

**Failures:** none.

**Mutation results:**

| # | Mutation | Caught? | How |
|---|---|---|---|
| 1 | Reset `i`/`remaining`/`on` to the start of the pattern at every polyline vertex, instead of carrying state across segments | Yes | 11 scenarios fail, spanning `chapter15-dash.feature`, `chapter15-closed.feature`, and both spiral plate scenarios |
| 2 | Apply phase with the wrong sign (`ph = (-phase) % total`) | Yes | 3 scenarios fail, all in `chapter15-dash.feature`'s phase scenarios |
| 3 | Don't append the closing point for a closed subpath before walking (drop the "walked around its closing segment" rule) | Yes | 3 scenarios fail, all in `chapter15-closed.feature` — exactly the feature file named for this behavior |

No mutation went undetected here; this chapter's test coverage is noticeably tighter than
chapter 14's (every rule in the prose has a scenario that would break if you got it backwards).

**Concrete changes I'd make:** give `dash_count` a one-line mention in `chapter15-plate.feature`'s
`Feature:` block, the way every other helper gets one. Nothing else — this chapter's prose and
scenarios were the easiest translation of the two.

**Timing:** `even-marks.ppm` 0.26s, `dash-strip.ppm` 0.14s, `spiral.ppm` 0.78s, `plate-15.ppm`
1.30s. Full suite (517 scenarios, chapters 1-15, including every render a scenario produces
inline): ~108s wall clock on this machine.
