# Reader feedback — Rust, chapters 5-6

Cold reader, Rust (stdlib only). Chapters 1-4 were already implemented in this
scratch directory when I started (210 tests, all green); I did the step-0
catch-up against `features/` for those first, then implemented chapters 5 and
6 in order.

## Step 0: catch-up on chapters 1-4

I diffed every `features/chapter0{1,2,3,4}-*.feature` scenario name against
the existing `tests/*.rs` (name-slugging plus manual `grep` verification for
every apparent mismatch, since a lot of scenario names lose punctuation
differently than my slugger guessed — e.g. `isn't` becomes `isnt` in the test
name, not `isn_t`). Every scenario in every chapter 1-4 feature file already
has a corresponding, passing test. `cargo test --release` before I touched
anything: 210 passed, 0 failed. No catch-up code changes were needed. (Minor
note for whoever reads this later: `mix.rs` has one extra test,
`linear_blending_is_on_by_default`, that isn't a 1:1 scenario translation —
looks like a carried-over default-state sanity check from an earlier round,
harmless.)

## Chapter 5 — Paths and Insideness

### Result

| feature file | scenarios | pass/fail |
|---|---|---|
| chapter05-paths.feature | 10 | 10 pass |
| chapter05-winding.feature | 9 | 9 pass |
| chapter05-rules.feature | 9 | 9 pass |
| chapter05-plate.feature | 4 | 4 pass |

`max_channel_difference` against reference:
- `star-centers.ppm`: **0**
- `star-coverage.ppm`: **0**
- `plate-05.ppm`: **0**

All three renders are byte-identical to the reference PPMs, not just within
tolerance.

### Catch-up

N/A for this chapter (new chapter, not a catch-up round).

### Ambiguities

- `filled(p, rule)` and the borrow question. The scenario for "rasterizing
  within the bounds" does `s ← filled(p, "evenodd")` and then still uses `p`
  afterward (`bounds(p)`). In a language with ownership this means `filled`
  can't consume `p`. I made `filled` take `&Path` and clone internally
  (`Shape::Filled(Box<Path>, Rule)`), matching the existing convention that
  `inside(s: &Shape, ...)` already borrows. This isn't stated anywhere in the
  chapter (fair enough, it's a Python/JS-flavored book), but a Rust reader
  has to make this call, and cloning a whole path on every `filled()` call is
  a real cost the chapter doesn't mention. Worth a one-line note for readers
  in ownership languages, or not — I don't think it's a bug, just a thing a
  Rust/C++/Swift reader has to decide alone.
- Even-odd for negative or large winding numbers. The pseudocode says "the
  winding number is odd," which I read as `winding.rem_euclid(2) != 0` to
  handle negative windings correctly (e.g. winding = -1 is odd). No scenario
  actually pins a negative odd winding under even-odd, so this is untested by
  the suite — I only know it's right because I checked it against my own
  reasoning, not a scenario. A scenario with winding = -3 under even-odd
  would close this gap.

### Hard to translate

- `polygon(point(...), point(...), ...)` is written as a variadic call in the
  Gherkin. Rust has no variadics, so I did what chapter 4's `union(vec![...])`
  already established as the house style: `polygon(&[point(...), ...])`. Not
  a chapter problem, just noting the translation for consistency.
- Tuple-valued equality assertions like `bounds(p) = (1, 1, 9, 8)` needed a
  small local `assert_bounds` helper per test file (there's no `PartialEq`
  with tolerance for a raw `(f64,f64,f64,f64)` in the existing code). Fine,
  just boilerplate.

### Failures

None. Every scenario passed as translated, first try, once the winding/
crossings arithmetic was implemented exactly per the pseudocode in §5.2.

### Prose problems

- None found that block implementation. The half-open rule is explained
  three separate times across the two chapters (crossings, winding_at, and
  again in chapter 6 for edges/active list) and each explanation is
  consistent and sufficient on its own.
- One thing I had to read twice: "Positive is clockwise on the screen, for
  the same reason chapter 4's cross product was" (§5.2) sent me back to
  chapter 4 to re-derive why, since chapter 5 doesn't restate the sign
  convention inline. Not wrong, just a bit of a detour; a half-sentence
  reminder ("y increases downward, so a turn that looks clockwise on paper
  has a positive cross product here") would save the round trip.

## Chapter 6 — Filling a Polygon

### Result

| feature file | scenarios | pass/fail |
|---|---|---|
| chapter06-edges.feature | 6 | 6 pass |
| chapter06-spans.feature | 13 | 13 pass |
| chapter06-sweep.feature | 12 | 12 pass |
| chapter06-plate.feature | 3 | 3 pass |

`max_channel_difference` against reference:
- `spiral.ppm`: **0**
- `plate-06.ppm`: **0**

Both byte-identical to the reference.

### Catch-up

N/A (chapter 6 didn't exist before this round).

### Ambiguities

- None that required guessing. The chapter is unusually precise about every
  half-open boundary (edge table dropping horizontals, crossings_on_row,
  spans_from_crossings, fill_span, and the active-list add/drop rule), and
  gives literal pseudocode for the two functions that matter most
  (`spans_from_crossings`, `fill_span`) plus the whole sweep
  (`fill_path_aliased`). I transcribed the pseudocode close to verbatim and
  every scenario passed without adjustment.

### Hard to translate

- Nothing chapter-specific. `Edge` is a plain struct with public fields,
  matching how the book's own tests reach into `t[0].y_top` etc.
  `max_coverage_difference` needed a peek at `CoverageBuffer`'s private
  `values` field, which is fine since it's implemented in the same module.

### Failures

None.

### Prose problems

- The trap box about the star's near-horizontal fifth edge
  (58.86881039375369 vs …366) is a genuinely useful warning, and it's backed
  up correctly: my own `star()` from chapter 5 produces exactly this
  situation, `edge_table(star())` has 5 entries (not 4), and no scenario pins
  that count, exactly as promised. Nice bit of honesty in the prose — flagged
  here as praise, but the instructions say problems are more useful than
  praise, so: nothing to fix here, just confirming the claim is true rather
  than aspirational.
- No other problems found.

## Mutation results (both chapters)

Five mutations, each applied, tested, and reverted:

1. **Chapter 5 — `crossings`'s half-open rule made closed at both ends**
   (`a.y <= y <= b.y` instead of `a.y <= y < b.y`, in the shared
   `edge_crossing` helper). Caught: `a_diamond_wound_twice_has_winding_number_2`
   and `a_ray_through_a_vertex_counts_it_once` in `winding.feature` (both
   assert a `crossings` value through a vertex).

2. **Chapter 5 — `winding_at`'s "heading down" branch condition changed from
   `a.y <= y` to `a.y < y`** (half-open weakened to open at the bottom edge).
   Caught hard: 4 of 9 scenarios in `winding.feature` failed
   (`the_boundary_belongs_to_the_top_and_the_left`,
   `a_ray_through_a_vertex_counts_it_once`,
   `a_diamond_wound_twice_has_winding_number_2`, `the_polygon_circle`), plus
   `a_loop_wound_twice_vanishes_under_even_odd` in `rules.feature`. This is
   exactly the mistake the chapter's trap box warns about, and the scenario
   set catches it from five different directions.

3. **Chapter 6 — active-edge-list drop condition weakened from `e.y_bottom >
   y` to `e.y_bottom >= y`** (an edge that ends exactly on a sample height
   stays active one row too long). Caught by exactly the scenario written for
   it: `an_edge_that_starts_on_a_sample_height_is_active_there_and_one_that_
   ends_there_is_not`. Nothing else in `sweep.feature` noticed — this is a
   well-aimed scenario, not a lucky one.

4. **Chapter 6 — `edge_table`'s sort dropped the `x_top` tiebreak** (sorted by
   `y_top` only, relying on `edges(p)`'s natural order for ties). Caught
   broadly: 5 of 6 `edges.feature` scenarios failed, including the two-edge
   rectangle case — Rust's `sort_by` is stable, but `edges(p)`'s insertion
   order rarely matches ascending `x_top`, so almost every table-shaped
   scenario noticed.

5. **Chapter 6 — dropped the `sort_by` on the active list's crossings inside
   `fill_path_aliased`** (the coordinates come out unsorted after `x_at`).
   Caught by 3 of 12 `sweep.feature` scenarios
   (`a_polygon_circle`, `the_star_both_rules_matches_chapter_5_pixel_for_
   pixel`, `a_transformed_star_fills_where_the_transform_put_it`) and both
   plate scenarios (`the_spiral`, `plate_6`). **Notably, the plain
   `a_rectangle` and `a_triangle` scenarios in the same file did NOT catch
   this** — those shapes only ever have exactly two edges active on any row
   (one descending, one ascending), and the table order for two edges
   happens to already be x-ascending on every row that matters, so an
   unsorted-crossings bug is invisible on axis-aligned/triangle shapes and
   only shows up once three or more edges are live on the same row (the
   circle, the star). This is worth calling out explicitly: if a future
   reviewer wants a scenario in `sweep.feature` that fails on this specific
   mistake using the simplest possible shape (not the full star), a
   four-or-more-edge polygon with edges out of x-order in the table would do
   it more cheaply than reaching for the star every time.

All five mutations were reverted; the full suite (276 tests) is green again
and the renders re-diff to `max_channel_difference = 0`.

## Concrete changes I'd make

1. (Chapter 5) Add a scenario pinning `inside_evenodd` at a negative odd
   winding number (e.g. winding = -3), so the `rem_euclid`-vs-`%` choice for
   negative windings under even-odd is actually pinned rather than left to
   the reader's judgment.
2. (Chapter 6) Add one scenario to `chapter06-sweep.feature` on a shape with
   3+ edges live on a single row that is NOT the star or the circle — a
   simple self-intersecting bowtie or a 5+ sided non-convex polygon would do
   — specifically to catch a missing/wrong sort of the active list's
   crossings without needing 160x160 star coordinates to fail on. See
   mutation 5 above.
3. (Chapter 5, minor) A half-sentence reminder of *why* positive winding is
   clockwise on screen (y increases downward) right where §5.2 restates the
   claim, instead of only cross-referencing chapter 4, would save a flip-back
   for a reader working straight through.

Everything else: no problems found. The pseudocode blocks in both chapters
were precise enough to transcribe close to verbatim in Rust, and every
scenario passed without needing to adjust a tolerance, special-case
anything, or guess at an unstated rule.

## Timing

- `cargo run --release --bin render_all` (all 20 renders, chapters 1-6):
  ~0.9-1.2s wall clock on this machine, most of it chapter 3/5's 64-sample
  brute-force coverage rasterizations (chapter 5's `star_coverage` rasterizes
  a 160x160 star twice at 64 samples/pixel).
  `cargo test --release` (276 tests, all files): ~8s wall clock including
  compilation; sub-second once compiled.
- Direct microbenchmark, chapter 5's brute-force `rasterize_centers` vs
  chapter 6's `fill_path_aliased`, both on the star into a 160x160 buffer,
  averaged over 20 runs:
  - `rasterize_centers` (chapter 5, center question): ~2.4ms
  - `fill_path_aliased` (chapter 6, sweep): ~0.018ms
  - ratio: **~137x**, comfortably beating the "seventy times faster in
    Python" the chapter quotes (as expected — compiled code amplifies the
    gap the chapter itself predicts: "the gap grows with the canvas", and
    apparently with the language too).
