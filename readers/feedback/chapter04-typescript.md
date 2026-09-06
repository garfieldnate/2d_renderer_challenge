# Chapter 4 reader feedback — TypeScript / Deno

## Result

- 207 scenarios total, all passing: 135 carried over from chapters 1–3
  (unchanged) plus 72 new from chapter 4.
  - `chapter04-tuples.feature` → 11 scenarios, `tests/tuples_test.ts`
  - `chapter04-matrices.feature` → 17 scenarios, `tests/matrices_test.ts`
  - `chapter04-transforms.feature` → 16 scenarios, `tests/transforms_test.ts`
  - `chapter04-scale.feature` → 6 scenarios, `tests/scale_test.ts`
  - `chapter04-shapes.feature` ("Transforming what you draw") → 13 scenarios,
    `tests/drawing_test.ts`
  - `chapter04-plate.feature` → 9 scenarios, `tests/plate_04_test.ts`
- Refactoring `thick_line` to call the new `segment` (chapter 3's `+0.5`
  moved into the caller) left all 37 chapter-3 scenarios green, no changes
  needed to their test file.
- `out/fan-both-orders.ppm` and `out/plate-04.ppm`: **byte-identical** to
  `reference/chapter-04/` (checked with `cmp`, not just `max_channel_difference`
  — both come out 0). Nothing needed a re-derivation or a guess about a tie-break.

## Ambiguities

- `side_by_side(a, b)` is named and described ("a four-line helper... copies
  a into the left half... and b into the right") but never gets its own
  scenario — it's only exercised indirectly inside `fan_both_orders` and
  `f_both_orders`, where both canvases happen to be the same height. I
  implemented it as `canvas(a.width + b.width, max(a.height, b.height))`,
  top-aligned, but that choice (pad vs. crop, which corner) is never pinned.
  Harmless here since every call site uses equal heights, but it's exactly
  the kind of helper the chapter's own rule ("helpers that tests depend on
  get their own scenarios") says should be pinned.
- `is_invertible`'s tolerance: every scenario's determinant works out to an
  exact 0 or a comfortably-nonzero float, so `determinant(M) !== 0` (no
  epsilon) passes everything. But the book is explicit about tolerances
  everywhere else (`assert_eq` defaults to 0.0001) and silent here. A matrix
  built as a product of several transforms (as in "The inverse of a
  transform is a transform") could in principle land a determinant at
  1e-14 instead of exactly 0 in a different language's float arithmetic. I
  went with strict inequality since that's what the given numbers need, but
  a reader who builds `is_invertible` with an epsilon (say, comparing
  against 0.0001) would also pass every current scenario — so this
  function's contract isn't fully pinned either.

## Hard to translate

- Nothing was actually hard. Gherkin data tables (`Given the following
  matrix M:`) have no runner in this project — each chapter's tests are
  hand-written `Deno.test` blocks, not executed Cucumber — so I did exactly
  what the chapter's own "Tables in scenarios" note says to do: read the
  table as a direct call to `matrix3(...)`, row by row. That note is a nice
  touch; without it I'd have had to guess whether tables should become a
  matrix-comparison helper of their own.
- `≠` mapped onto `assert_matrix_ne`/`assert_tuple_ne`, mirroring the
  existing `assert_color_ne` convention already in `src/assert.ts`. Trivial.

## Failures

None. Every scenario passed on the first implementation that followed the
chapter's formulas literally (cofactor expansion, the transposed-cofactor
inverse, the rotation matrix as given, `sqrt(|det|)` for `approx_scale`).
Both renders are byte-identical to the reference PPMs, so there's no
rounding or ordering discrepancy to chase.

## Prose problems

- §4.2/§4.5 naming collision risk: this project's existing convention
  (established in chapters 1–3) names test files after the feature's topic
  word, dropping the chapter prefix (`chapter02-shapes.feature` →
  `shapes_test.ts`). `chapter04-shapes.feature` collides with that name —
  its actual content ("Transforming what you draw": `segment`, `union`,
  `transformed`, `outline`) has nothing to do with chapter 2's `shapes_test.ts`
  (circle/rectangle/half-plane `inside` checks). I had to invent
  `drawing_test.ts` to avoid overwriting/confusing the two. Cosmetic, but a
  reader following the established naming convention mechanically would hit
  this exact collision. Suggest renaming the feature file to
  `chapter04-drawing.feature` or `chapter04-outline.feature` to match its
  `Feature:` title and avoid the clash.
- No other issues: every formula, every pseudo-code block (minor/cofactor/
  inverse, the four transform matrices, `approx_scale`), and every plate
  program transcribed directly into working code with zero adjustment. This
  is the cleanest chapter of the four so far to translate cold.

## Mutation results

Tried four plausible reader mistakes, one at a time, reverting each before
trying the next (backups diffed clean afterward):

1. **Negate the sine in `rotation()`** (rotate the wrong way). Caught hard:
   13 scenarios failed, including the most direct one, "A positive rotation
   turns x toward y", plus every downstream scenario that composes a
   rotation (chained transforms, "Rotating about a point that isn't the
   origin", both plate-4 scenarios).
2. **`transformed()` applies `m` instead of `inverse(m)`.** Caught: 5
   scenarios failed — "A circle seen through a scale is an ellipse", "The
   transform is applied in the order the matrix says", and the three
   shape-space/device-space pen scenarios in §4.5.
3. **Wrong `approx_scale`: longest column instead of `sqrt(|det|)`.** Caught:
   4 scenarios failed, exactly where the chapter says the two definitions
   disagree — "A non-uniform scale is reported as the geometric mean", "A
   shear that preserves area reports 1", "A collapsed transform reports 0"
   (longest column reports 1 or ~4.47 instead of 0 for a matrix whose
   columns are both nonzero but linearly dependent), and "Under a
   non-uniform scale the compromise shows". The uniform-scale scenario
   still passed, as expected — the two definitions agree there.
4. **`outline()` doesn't close** (loop to `pts.length - 1`, dropping the
   last-back-to-first edge). Caught: 3 scenarios failed, both outline
   scenarios directly and, gratifyingly, "Plate 4" itself — the F is a
   closed polygon, so an open outline changes its rendered shape.

No mutation slipped through undetected. I did not find the "wrong
implementation that still passes" the task asked me to hunt for, but the two
ambiguities above (`side_by_side`'s unpinned edge behavior, `is_invertible`'s
unpinned tolerance) are the closest candidates: neither has a scenario that
would catch a reasonable alternate implementation.

## Concrete changes I'd make

1. Rename `chapter04-shapes.feature` to something whose topic word doesn't
   collide with chapter 2's (e.g. `chapter04-drawing.feature`), matching its
   own `Feature: Transforming what you draw` title.
2. Add one scenario for `side_by_side` in isolation (two small canvases of
   different, recognizable colors — doesn't even need different heights) so
   the helper is pinned the way the chapter's own rule asks for.
3. Consider stating an explicit tolerance for `is_invertible` near zero, the
   way `assert_eq` states 0.0001 elsewhere — even a single sentence ("a
   determinant with |d| < 1e-9 counts as zero") would remove the one place
   left where two reasonable implementations could diverge without any
   scenario noticing.

## Timing

- `fan_both_orders()`: ~517ms (two 160×160 rasterizations at 64 samples/pixel,
  12-segment union each).
- `plate_04()`: ~567ms (two more 160×160 rasterizations, 10-segment outline
  unions, plus the home ghost, then a 2× magnify).
- Full `src/render.ts` (all 15 pictures, chapters 1–4): 1.75s wall clock,
  compiled and run by Deno with no separate build step.
- Full test suite (207 scenarios, `deno test --allow-read`): ~2s.
