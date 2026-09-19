# Reader feedback — Rust, chapters 14-15 (and a chapter 13 catch-up)

Implemented cold, from `chapter-14.html`/`chapter-15.html` and their `.feature` files alone,
on top of the existing chapters 1-13 Rust code. This file covers the catch-up pass, then
chapter 14, then chapter 15, in that order, as instructed.

## Result

- Catch-up (chapters 1-13): all green after the fix below. 477 tests total across the whole
  suite pass at the end (0 failed).
- Chapter 14: 4 feature files, 23 scenarios (including the two outline-scenarios), all pass.
  Renders: `two-strokes.ppm`, `fold.ppm`, `offsets.ppm`, `plate-14.ppm` — every one diffs
  **0** against `reference/chapter-14/` (not merely within tolerance), after fixing a real
  rounding bug the render comparison itself found (see Failures).
- Chapter 15: 5 feature files, 22 scenarios, all pass. Renders: `even-marks.ppm`,
  `dash-strip.ppm`, `spiral.ppm`, `plate-15.ppm` — every one diffs **0** against
  `reference/chapter-15/`.
- Full suite: `cargo test --release` — 83 test binaries, 477 tests, 0 failures.

## Catch-up

`features/chapter13-stroke.feature` had grown two scenarios since this code last ran:

- "Every piece winds the same way, so overlapping pieces add instead of cancelling" — pins
  `polygon_area(o)` as a **negative** number (`-4981.625`). The existing `polygon_area` took
  `.abs()` of the shoelace sum, so this failed immediately (`assert_eq!` on sign). Chapter 7's
  own scenarios (`ink(cov) = polygon_area(p)`) still pass with the `.abs()` removed only because
  every shape those scenarios use (`polygon`, `circle_path`, `star()`, `needle_path()`) happens
  to be wound clockwise on screen already, which the signed formula treats as positive too —
  that's a property of how those fixtures were authored, not a rule the type system enforces,
  so it's worth re-checking if a future chapter's scenario adds a counterclockwise-wound shape
  to `fill.rs`.
- "The round join is an arc across the outer gap, not around the inside" and "A wide stroke
  around a tight bend overlaps itself and stays solid" — the round join was sweeping the long
  way round in some cases (the exact bug the chapter's own prose describes three earlier readers
  hitting). Both failed before the fix (`round_join_has_twenty_four_points` in the old test
  expected 24 points; the correct answer, and what the current feature file pins, is 13).

Both were fixed together: `polygon_area` now returns the signed area, and `join_shape`'s round
branch now takes the shortest angular path between the two offset points via a new `ang_between`
helper, instead of picking a direction from the sign of the turn. `push_closed_subpath` (the
stroker's `emit`) now reorients every piece counterclockwise (`polygon_area > 0` triggers a
reverse) before appending it, matching the chapter's own `emit` pseudocode. `u_turn()` (nine
points on a circle, matching the feature file's prose exactly) was added since it didn't exist
yet. `tests/stroke.rs` was rewritten in full to match the current feature file (it was missing
five of eleven scenarios and had one wrong expected value); `tests/miter.rs`, `tests/degenerate.rs`
and `tests/plate_13.rs` needed no source changes, but the two `plate_13.rs` render comparisons
(`the_three_joins`, `plate_13_test`) only started passing once the join fix landed — they'd been
silently red before this session started.

After the fix, chapters 1-13 are fully green and `reference/chapter-13/*.ppm` were re-checked
(not regenerated — this codebase doesn't own the reference; it diffs against it) and all match
within tolerance.

## Ambiguities

- **`dash_count`'s definition.** Neither the prose nor any scenario in `chapter15-*.feature`
  gives a formula for `dash_count(p, pattern, phase)` beyond one pinned value
  (`dash_count(sp, [16, 10], 0) = 17`) and the name itself. I implemented it as
  `subpaths(dash(p, pattern, phase)).len()`, which matches the one pinned number and is the only
  reading of the name that doesn't require guessing at some other definition (e.g., "on-segments
  only, excluding a merged closed loop" would need its own rule for the closed case that nothing
  in the text specifies). Flagging this because it's the one function in these two chapters with
  no JS reference source and no pseudocode — everything else had at least one of those to check
  against.
- **Whether `stroke_curve_to_path`'s result should go through chapter 13's winding-orientation
  fix.** After the catch-up above, every piece chapter 13's stroker emits is reoriented
  counterclockwise before being appended, because *multiple* pieces need to agree to avoid
  cancelling where they overlap. Chapter 14's `stroke_curve_to_path` produces exactly *one*
  subpath (the whole outline), so there's no second piece to disagree with, and the scenarios
  pin its first and last points by construction (`offset_point(hairpin(), 0, 30)` and
  `offset_point(hairpin(), 0, -30)` respectively) — reorienting the whole subpath would still
  satisfy the fill correctness but would silently break those two point-identity checks by
  reversing the list. I read the chapter's own pseudocode (`return one closed subpath through
  pts // fill it nonzero`) as deliberately not mentioning reorientation, and left it out; the
  scenarios agree with that reading exactly.
- **`offset_distance_error`'s exact sampling scheme.** The prose says "100 points spread along
  the result" but doesn't say whether that's 100 evenly spaced by parameter-per-piece, by
  fraction of total piece count, or by arc length, and there's no JS source for it (it's not
  used by any figure). I distributed 100 samples proportionally across the pieces by parameter
  (`u = i/99 * n_pieces`, floor to pick the piece, remainder as its local `t`), which is the
  simplest reading and happened to satisfy both the tight `≤ 0.01` bound and the loose `≥ 0.7`
  fold-detection bound on the first try, but a different sampling scheme (by arc length, say)
  would very likely also satisfy both given how loose the thresholds are. If this function is
  ever pinned more precisely, the sampling method needs to be nailed down in prose.

## Hard to translate

Nothing in either chapter fought the language. The two-tuple return of `split_at`/`sub_curve`
and the `Option<Vec<Tuple>>` of `join_shape`/`cap_shape` were already established idioms from
chapter 8/13; chapter 14's recursive `offset_into` and chapter 15's stateful `dash` walk are both
ordinary loops/recursion with no borrow-checker friction once the per-subpath dash list is built
as a local `Vec<(Vec<Tuple>, bool)>` before being pushed into the output `Path` (trying to build
directly into `Path` while mutating a `cur: Option<&mut Subpath>` handle across loop iterations
would have fought the borrow checker for no benefit — building a plain local `Vec` first and
committing it afterward sidesteps that entirely).

## Failures

One real bug, found by the render comparisons, not by any unit scenario:

**`two_strokes()` and `fold_demo()` (chapter 14) initially failed `max_channel_difference` by up
to 82/255** in a handful of pixels clustered at `(80, 42)`/`(80, 43)` in `fold.ppm` and the
mirrored `(238-242, 42-43)` in `two-strokes.ppm`. Actual vs. expected at `(80, 42)`:
mine `(206, 206, 212)` (plain gray fill, no line) vs. reference `(237, 124, 196)` (full magenta
outline); at `(80, 43)` the two were swapped. That's not antialiasing noise (which would show a
smooth gradient of small differences) — it's a whole magenta scanline sitting one pixel off
between the two renders.

Root cause: the hairpin curve and its +30 offset fold are exactly symmetric about `x = 80`, so
the fold's own self-crossing point lands at the exact coordinate `(80.0, 42.5)` — a genuine
half-integer tie, not a near-miss. `stroke_panel` (reused here from chapter 13 for the magenta
outline overlay) rounds outline coordinates with Rust's `f64::round()` before handing them to
`line_wu`, and Rust's `round()` ties away from zero (`42.5 -> 43`). The book's own reference
figure JS uses a distinct `pyround` helper (Python-style, ties to even, `42.5 -> 42`) for exactly
this purpose — a fact that's easy to miss because chapter 13's own scenarios and renders never
happen to produce an exact `.5` coordinate, so the wrong tie-break shipped invisibly for two
chapters. This is a bug in the existing (pre-chapter-14) Rust code, not in the book: fixed by
adding `round_half_to_even` and switching the two `line_wu`-facing panel functions
(`stroke_panel`, and this chapter's `outline_panel_rule`) to use it, while leaving chapter 1's
`round()` (used for channel-to-byte conversion, which really is ties-away-from-zero in the
reference) untouched. This is the single most useful thing this reader round found — a latent,
untested rounding-convention mismatch that only a maximally-symmetric render happened to expose.
Whose fault: the existing (this session's own, from an earlier catch-up) reader code, for reusing
the wrong tie-break; not the chapter's prose, which never states the rule explicitly but is
consistent about it in its own reference source once you go looking.

No other failures. Every numeric scenario (point positions, counts, distances, curvature values,
cusp parameters) matched on the first implementation attempt.

## Prose problems

- §14.4: "walk 100 points along the result and ask `distance_to_curve` how far each one is" is
  the only place in either chapter that describes an algorithm without a JS source or a precise
  enough spec to nail down the sampling scheme (see Ambiguities above). Everything else in these
  two chapters was either pseudocode, a JS reference function, or unambiguous prose.
- §15.1's claim "With 256 chords the chapter 8 curve comes out at 7.99995" matches this
  implementation's `arc_length(c, 256)` exactly (`7.999952` to 6 places, consistent with the
  chapter's rounding for display), so no correction needed there — flagging only that it's worth
  double-checking prose numbers like this stay in sync if `arc_length_table`'s algorithm is ever
  tweaked, since nothing forces the printed number to track the code except this kind of
  scenario.
- No other prose problems found. Both chapters read as intended: §14.2's stall explanation
  matches the `curvature`/`cusps` behavior exactly, and §15.3's pseudocode for `dash` translated
  to Rust with no surprises once put next to the JS reference.

## Mutation results

Six deliberate mutations, three per chapter, tested and reverted (see `README.md`'s "Mutation
testing (chapters 14-15)" section for the full write-up with exact scenario names). Summary:

| Chapter | Mutation | Caught by |
|---|---|---|
| 14 | Offset normal flipped (`-perp` instead of `perp`) | All 5 `offset.rs` scenarios, immediately |
| 14 | Cusp condition sign flipped (`1 + κd` instead of `1 - κd`) | Both `curvature.rs` cusp scenarios |
| 14 | `offset_curve` skips cusp-splitting | 1/5 `curve14.rs`, 3/4 `stroke14.rs` (not the two scenarios whose curve never reaches its stall radius) |
| 15 | Dash walk resets pattern state every vertex | 5/8 `dash15.rs`, 2/5 `closed15.rs` |
| 15 | Phase applied with the wrong sign | 3/8 `dash15.rs` (only the nonzero-phase scenarios, as expected) |
| 15 | Closed subpath not walked around its closing segment | 3/5 `closed15.rs` (every scenario using the square; the two-open-subpaths scenario is naturally unaffected) |

**No mutation survived every scenario.** The closest calls (chapter 14's cusp-split removal,
chapter 15's phase flip) were only silent on scenarios that structurally couldn't exercise the
mutated behavior in the first place (a curve that never folds; a phase of zero), not on
scenarios that should have caught the bug and didn't. That's a genuinely different, weaker
finding than round 1's chapter-13 mutations, two of which *were* silent on scenarios that should
have caught them (see `README.md`) — these two chapters' scenario sets have no equivalent gap
that this round's testing found.

## Concrete changes I'd make

1. Pin `offset_distance_error`'s exact sampling method in prose (by parameter-per-piece vs. by
   arc length) — see Ambiguities. Low priority since the thresholds are loose enough that it
   doesn't currently matter, but it's the one underspecified algorithm in either chapter.
2. Consider a scenario that exercises `dash`/`stroke_to_path` at an exact half-integer
   coordinate deliberately (the way chapter 1 already warns against pinning a *scenario value*
   near `.5`, but nothing stops a *render* from landing a real coordinate there by construction,
   as chapter 14's symmetric hairpin does by accident). A targeted scenario would have caught
   the rounding-mode bug this round found without needing a full render diff to surface it.
3. `out/`'s single flat namespace has exactly one collision across all fifteen chapters:
   chapter 6's `spiral()` and chapter 15's `spiral_dashes()` (written as `spiral.ppm`) both
   target the same filename. Harmless for the tests (which always compare against
   `reference/chapter-NN/`, never against `out/`), but a `render_all` run followed by "open
   `out/spiral.ppm`" silently shows chapter 15's picture, not chapter 6's. Namespacing `out/` by
   chapter number would remove the one surprise in an otherwise-flat directory.
4. `stroke_curve_to_path`'s doc comment (mine, in `src/lib.rs`) now says explicitly why it skips
   the winding-orientation fix chapter 13's stroker applies to every other piece it emits — worth
   the author double-checking that reasoning holds if this function is ever extended to combine
   more than one curve's offset into a single outline (a multi-curve path, which the chapter's
   own prose says explicitly this book doesn't build).

## Timing

`cargo run --release --bin render_all` (all 52 renders, chapters 1-15, cold `cargo build`
already done) completes in about 1.1-1.3 seconds total on this machine; chapters 14 and 15's
eight renders are a small fraction of that; the release build's the same brute-force-coverage
figures from chapters 2/3/5 that the top-level README already calls out as the slow ones.
`cargo test --release` for the full suite (83 test binaries, 477 tests) completes in
about 1.2-1.4 seconds, dominated by process-startup overhead across that many binaries rather
than any individual test; no single scenario in chapters 14 or 15 takes measurably long (the
cusp bisection is 64 samples × 40 bisections, the distance-to-curve search is 65 samples × 32
ternary rounds — both trivial at f64 speed).
