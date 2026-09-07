# Reader feedback — Rust, chapters 7-8

## Result

- Catch-up (chapters 1-6): all green, nothing newly broken. `cargo test --release` before
  touching anything: every existing test file passed (0 failed) across all of chapters 1-6.
- Chapter 7: 34 scenarios translated, all passing.
  - `chapter07-cells.feature` → `tests/cells.rs`: 5/5
  - `chapter07-row.feature` → `tests/row.rs`: 4/4
  - `chapter07-walk.feature` → `tests/walk.rs`: 8/8
  - `chapter07-resolve.feature` → `tests/resolve.rs`: 2/2
  - `chapter07-fill.feature` → `tests/fill.rs`: 10/10
  - `chapter07-plate.feature` → `tests/plate_07.rs`: 5/5
- Chapter 8: 21 scenarios translated, all passing.
  - `chapter08-curves.feature` → `tests/curves.rs`: 5/5
  - `chapter08-bounds.feature` → `tests/bounds8.rs`: 3/3
  - `chapter08-flatten.feature` → `tests/flatten8.rs`: 5/5
  - `chapter08-arc.feature` → `tests/arc.rs`: 5/5
  - `chapter08-plate.feature` → `tests/plate_08.rs`: 3/3
- Renders, `max_channel_difference` against `reference/`, all exactly **0** (not just ≤ 1):
  - `needles.ppm`: 0
  - `soft-square.ppm`: 0
  - `star-exact.ppm`: 0
  - `spiral-smooth.ppm`: 0
  - `plate-07.ppm`: 0
  - `drops.ppm`: 0
  - `flower.ppm`: 0
  - `plate-08.ppm`: 0
- Whole suite (chapters 1-8): 0 failures, `cargo run --release --bin render_all` writes 28
  files to `out/`.

## Catch-up

Nothing to report — chapters 1-6 were untouched and still pass in full before I added a single
line for chapter 7. `fill_path_aliased` (chapter 6) stays in the library unmodified, since chapter
7's own scenarios diff against it directly.

## Ambiguities

- **`soft_square()`, `star_exact()`, `spiral_smooth()` have no pseudocode or figure source**,
  unlike `needle_path()`/`rays()`/`sunburst()`, which the chapter prints in full (both as a
  pseudocode block and as the actual JS the figure runs). The prose only says: "soft_square() fills
  a small square whose edges land on pixel centers," "star_exact() fills chapter 5's star both
  ways," "spiral_smooth() is chapter 6's spiral of stars, now smooth." None of that fixes canvas
  size, magnification, panel layout, or which ink to use. I reverse-engineered all three from the
  pinned pixel values plus the reference PPM (working backward through the sRGB encode to confirm,
  e.g., that `(36, 36) = (134, 109, 59)` is exactly `mix(BG, INK, 0.25)` at a quarter-covered pixel,
  which told me the square is `polygon((1.5,1.5)-(5.5,1.5)-(5.5,5.5)-(1.5,5.5))` on an 8x8 buffer
  magnified 24x). That worked, but it inverts the book's own TDD relationship: a reader is supposed
  to derive the render from the prose and have the scenario catch mistakes, not derive the render
  from the reference image the scenario is diffing against. Concretely, what I built:
  - `soft_square()`: 8x8 canvas, the same polygon as the fill.feature "square whose edges sit on
    pixel centers" scenario, filled nonzero, painted with the sunburst's first ink, magnified 24x.
  - `star_exact()`: chapter 5's `star()`, filled both rules on two 160x160 panels
    (`fill_path`, not `rasterize_centers`/`rasterize_within`), side by side, unmagnified.
  - `spiral_smooth()`: chapter 6's `spiral()` body unchanged except `fill_path_aliased` →
    `fill_path`; unmagnified (320x320), unlike `plate_06` which additionally magnifies by 2.
- **`derivative(c, t)`, `curve_bounds(c)`, `polyline_length`, `flatten_length` have no reference
  source at all**, not even prose-adjacent pseudocode — only a paragraph of algebra description
  ("solve the derivative for its roots... a quadratic's derivative is linear... a cubic's is
  quadratic"). I implemented the standard Bezier hodograph (control points of the derivative curve
  are `n * (p[i+1] - p[i])`, a curve one degree lower) and solved the resulting linear/quadratic
  directly by degree, since those are the only two degrees this book ever produces. This is
  correct and passes every scenario, but it's the one place in chapters 1-8 where the reader needs
  outside Bezier-math background rather than being handed the shape of the algorithm the way §7.2's
  midpoint-rule prose hands you the trapezoid formula outright.
- Whether `arc`'s two flag parameters should be `bool` or `0`/`1` integers: the prose calls them
  "two flag bits," but Rust's natural type for a yes/no SVG flag is `bool`. I used `bool` and
  translated the scenario's numeric `0`/`1` literals to `false`/`true` in the test file. Not really
  a chapter ambiguity, just a Rust-specific choice worth recording.
- Float equality: `ink(cov) = 300.0` for the scaled triangle scenario failed on the first pass
  under Rust's literal `assert_eq!` (got `300.00000000000006`, from floating-point drift through the
  accumulator's midpoint-rule arithmetic after a non-uniform scale). CLAUDE.md's own convention
  ("`a = b` on floats means within `0.0001`") is exactly right here and I switched every float
  scenario assertion to `approx_eq`/`approx_eq_eps`, matching how the existing chapter 1-6 tests
  already do it (I'd initially and wrongly used `assert_eq!` for chapter 7-8, copying the plate
  tests' style for `c.width`/`c.height`, which really are exact integers).

## Hard to translate

- `arc`'s degenerate/`None` case combined with a named-field result (`a.corrected`, `a.rx`,
  `a.ry`) pushed naturally toward `Option<Arc>` with a public struct, which Rust makes easy, but a
  reader coming from a language without sum types would have to decide the same thing chapter 4/5
  already decided for other "maybe nothing" results in this codebase (there wasn't a precedent for
  an `Option`-returning constructor before this chapter, since `Shape`/`Path` builders never fail).
- `add_cell`'s `row` parameter is never bounds-checked in the reference JS (only `x` is, both
  directions) because the caller (`accumulate`) always clips the row range to the buffer first.
  Rust's array indexing would panic on an out-of-range row rather than silently doing nothing, so
  `add_cell` is stricter than `add_cell`'s own scenarios exercise: none of them call it with a row
  outside `0..height`. It works today because nothing else calls it that way, but it's a sharp edge
  a translator could hit if they reused `add_cell` in a context the chapter didn't anticipate.

## Failures

None. Every translated scenario passes, both against `approx_eq`/`approx_eq_eps` and against the
reference PPMs (`max_channel_difference` is 0, not merely ≤ 1, for all eight chapter 7-8 renders).

## Prose problems

- §7.6 ("Putting it together"): `soft_square()`, `star_exact()`, `spiral_smooth()` are named and
  scenario-pinned but never given pseudocode or a figure, unlike every other named render in
  chapters 1-8. See Ambiguities above — this is the concrete instance of CLAUDE.md's own rule
  ("each render is a named function... so scenarios can call it") being followed for the scenario
  half but not the prose half.
- §8.1-8.2: `derivative` and `curve_bounds` are described in words only. The rest of the chapter
  (de Casteljau, flattening, the arc) gives either a pseudocode block or the literal JS source; this
  is the one section that doesn't, and it's also the one section that assumes prior Bezier-math
  background (knowing that a Bezier's derivative is itself a lower-degree Bezier on scaled
  differences isn't derivable from the prose alone — the prose says "solve the derivative for its
  roots" but never states what the derivative's control points *are*).
- Everything else read clearly and matched the reference precisely on the first implementation
  attempt — no other prose ambiguity produced a wrong number anywhere.

## Mutation results

Three of six deliberate mistakes were caught immediately by an obvious scenario; the other three
are the interesting findings, because each slipped past an entire layer of the test suite and was
only caught by one specific, narrow scenario (or, in one case, by nothing at all):

1. **Flipped the winding sign in `accumulate`** (`sign = if a.y > b.y { -1.0 } else { 1.0 }`,
   backward). Caught by 6 of 8 scenarios in `chapter07-walk.feature` (which pin raw `area_at`/
   `cover_at` values). **Not caught** by `chapter07-resolve.feature`, `chapter07-fill.feature`, or
   `chapter07-plate.feature` — every render, fill, and resolve scenario passed unchanged, because
   `apply_rule` takes `|w|` for both rules, so a *globally and consistently* flipped sign is
   invisible after `resolve`. This validates pinning `accumulate`'s raw output directly rather than
   only testing through the fill.
2. **Removed `abs()` from the nonzero rule** (`w.min(1.0)` instead of `w.abs().min(1.0)`). Caught
   immediately and only by `chapter07-resolve.feature`'s direct scenario
   (`apply_rule(-0.25, "nonzero") = 0.25`). **Not caught by any fill, plate, or render scenario** —
   every polygon in every other scenario happens to be wound so its interior winding never goes
   negative. This one direct unit scenario is the single most load-bearing test in chapter 7: delete
   it and a broken nonzero rule ships invisibly, since every visual scenario in the book would still
   pass.
3. **Removed the even-odd triangle-wave fold** (returned `w.abs() % 2.0` directly instead of
   folding values above 1 back down). Caught by `chapter07-resolve.feature` directly and
   independently by `chapter07-fill.feature`'s star scenario (the fractional coverage values at the
   star's edge came out wrong). Good defense in depth here.
4. **Removed the `acos` domain clamp** in chapter 8's `angle_between` (the mistake the chapter's own
   trap box calls out by name). **Passed every single scenario in `chapter08-arc.feature` and
   `chapter08-plate.feature`** — the whole suite, unchanged. Every arc scenario in the chapter uses
   clean inputs (a radius-5 circle, integer coordinates, or one exact `π/6` rotation) whose
   dot-product ratios land at exactly `1.0`, `-1.0`, or safely inside `(-1, 1)` with zero
   floating-point drift, so the clamp is never exercised. This is the most valuable finding from
   this pass: the trap box is right that this bites, and nothing in the current suite proves the
   fix works. A scenario with a genuinely irrational radius/rotation combination (not an exact
   multiple of anything) would be needed to actually push the ratio a hair past ±1.
5. **Swapped which flag (`large_arc` vs `sweep`) triggers the `±2π` delta adjustment.** Caught
   immediately: 3 of 5 `chapter08-arc.feature` scenarios failed.
6. **Flattened each petal curve in its own unit space, then transformed the resulting polyline**,
   instead of transforming the curve first and flattening in device space (exactly the mistake
   §8.3 warns about by name). **Not caught by any of `the_flowers`'s five named pixel probes**
   (petal centers and punch-hole centers, chosen away from facet edges) — only by that same
   scenario's whole-image `max_channel_difference <= 1` check, and by `plate_8`'s. This confirms
   the chapter's claim is real and testable, but only the full-image diff enforces it; the
   individual pixel pins would have shipped the bug silently.

All six mutations were reverted after observation; `cargo test --release` and the render diff
check both confirm a clean, fully-passing state afterward.

## Concrete changes I'd make

1. Give `soft_square()`, `star_exact()`, and `spiral_smooth()` the same treatment as `needles()`/
   `rays()`/`sunburst()`: explicit dimensions, magnification, and layout in prose or pseudocode, so
   a reader doesn't have to reverse-engineer them from the reference PPM.
2. Give `derivative`/`curve_bounds` at least a named-algorithm pointer ("the derivative of a degree-n
   Bezier is a degree-(n-1) Bezier whose control points are `n * (p[i+1] - p[i])`") the way every
   other section states its rule outright. Right now it's the one place a reader without prior
   Bezier background could get stuck with no way forward except deriving calculus from a paragraph.
3. Add one `chapter08-arc.feature` scenario with deliberately messy floating-point inputs (an
   irrational radius or a rotation that isn't an exact fraction of π) specifically to exercise the
   `acos` clamp — as written, the suite can't distinguish a correct clamp from a missing one.
4. Consider a fill-level (not just `apply_rule`-level) scenario using a counter-clockwise-only
   polygon, to make sure a broken nonzero rule can't hide behind every test polygon in the book
   happening to wind the same way.

## Timing

Single continuous session. Chapter directory was staged at 17:27; this feedback was finished at
17:48 — about 20 minutes end to end, covering: reading both chapters and all ten feature files in
full, reading the existing chapters 1-6 code and test conventions, implementing chapter 7
(accumulator/fill, ~330 lines) and chapter 8 (curves/arc, ~370 lines) in `src/lib.rs`, writing 11
new test files (55 scenarios), regenerating and diff-checking all 8 renders against the reference,
running and reverting six deliberate mutations, and updating `README.md`.
