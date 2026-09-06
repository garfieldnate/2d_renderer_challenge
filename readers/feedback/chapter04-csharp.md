# Chapter 4 reader feedback — C# / .NET 8

Implemented cold, from `chapter-04.html` and `features/chapter04-*.feature` alone, on top
of the existing chapters 1-3 C# code in this scratch directory. No other reader's work,
no reference implementation, no `plan.html` was consulted.

## Result

Every scenario in every `chapter04-*.feature` file was translated and passes, and every
chapter 1-3 scenario still passes after the `ThickLine` → `Segment` refactor.

| Feature | Scenarios | Pass |
|---|---|---|
| chapter04-tuples | 11 | 11 |
| chapter04-matrices | 17 | 17 |
| chapter04-transforms | 16 | 16 |
| chapter04-scale | 6 | 6 |
| chapter04-shapes | 13 | 13 |
| chapter04-plate | 9 | 9 |
| **Chapter 4 total** | **72** | **72** |
| **All chapters (1-4)** | **206** | **206** |

Renders vs. reference:

- `out/fan-both-orders.ppm` vs `reference/chapter-04/fan-both-orders.ppm`: **byte-identical**
  (`max_channel_difference` = 0, confirmed both by the test's own check and by `cmp`).
- `out/plate-04.ppm` vs `reference/chapter-04/plate-04.ppm`: **byte-identical**
  (`max_channel_difference` = 0, confirmed both ways).

No bugs found in the chapter, the reference, or my translation — the renders matched on
the first successful build, with no debugging required.

## Ambiguities

- **Tolerance on `is_invertible`.** The chapter's pseudocode says "d ← determinant(M) //
  zero means there is no inverse" and never discusses floating-point tolerance, even
  though every other equality in the book is explicitly tolerance-based. I implemented
  `IsInvertible()` as `Determinant() != 0` (exact). Every test matrix in the scenarios
  has an exactly-representable determinant (built from small integers or exact halves),
  so this never bit me, but it's the one place in the chapter where "compare with the
  usual tolerance" quietly doesn't apply, and the chapter doesn't say so. A transform
  built by composing several rotations and scales could plausibly have a determinant
  that's mathematically zero but numerically `1e-16`, and nothing here would catch it
  falling on the wrong side of exact zero.
- **Where a "copy of a canvas" comes from.** `f_both_orders()`'s pseudocode says `a ← a
  copy of ghost` with no further detail. `Canvas` has no clone method in this codebase, so
  I guessed a plain pixel-by-pixel copy (a private `CopyCanvas` helper in `Renders.cs`)
  rather than adding a public `Clone()` to `Canvas.cs`. Reasonable, but a reader in a
  language whose canvas type is a value type (or has a built-in deep-copy) wouldn't even
  notice this was a decision.

## Hard to translate

- **`matrix3(...)` as a name.** The chapter explicitly names a builder function `matrix3`
  that takes nine numbers. Every other shape in this codebase (`Circle`, `Rectangle`,
  `HalfPlane`, `Color`) is built with `new ClassName(...)`, so I mapped `matrix3(...)` to
  `new Matrix3(...)` rather than adding a same-named static method. Faithful in spirit,
  but a strict reading of "the code uses `matrix3`" would want a method literally named
  that; I judged consistency with the existing codebase's constructor idiom more valuable
  than a literal name match. Worth being explicit in the prose that this is a *concept*,
  not a name every language needs to spell the same way (the same way `point`/`vector`
  already implicitly assume a language will spell them however it spells constructors).
- **Gherkin data tables.** `Given the following matrix M: | 1 | 2 | 3 | ...` has no table
  parser in this hand-rolled test suite (same as every other chapter) — I read the table
  by hand and wrote the nine numbers into `new Matrix3(...)` in row-major order. Trivial
  once you notice the table *is* just `matrix3`'s nine arguments with visual formatting,
  but a first-time reader translating literally could plausibly transpose a row/column
  while typing them out, which is exactly the class of bug §4.2 is worried about. (The
  scenario protects against this in the *reference* semantics, but not against a typo
  made while copying the table into source — nothing can, really.)

## Failures

None. Zero scenarios failed, in any feature, on the final run.

## Prose problems

None found. Specific things I checked and that held up:

- §4.2's claim that the scenario checks `M[1, 0]` and `M[0, 2]`, not only the diagonal —
  true, and it would catch a transposed accessor.
- §4.5's "the scenario checks the corner of a square: 0.75" — matches
  `pixel_at(c, 1, 1) = color(0.75, 0.75, 0.75)` exactly.
- §4.6's "Five rasterizations of a 160-by-160 canvas... about the same work as chapter
  3's fan" — I counted: `fan_both_orders` rasterizes 2 unions of 12 segments,
  `f_both_orders` rasterizes 3 outlines (ghost, then the F through each order) of 10
  segments each. That's 5 rasterizations, exactly as claimed.
- §4.6's timing claim, "a minute or so in Python or Ruby and well under a second
  compiled" — see Timing below; true, but only for an optimized build (see caveat).
- §4.4's worked numbers (2 for `scaling(4,1)`, 1.618 for `shearing(1,0)`'s largest
  singular value, etc.) all check out against hand computation.

The one thing I'd flag as a *near*-miss rather than a bug: the chapter never states the
tolerance/exactness question raised above under Ambiguities. It's not wrong, just silent
where the rest of the book is unusually careful to be explicit.

## Mutation results

I introduced four plausible reader mistakes, one at a time, ran the full suite, recorded
which scenarios failed, and reverted each before trying the next (confirmed byte-identical
to the pre-mutation source after each revert).

1. **Sine negated in `rotation(r)`** (rotate the wrong way). Caught hard: 13 scenarios
   failed across `chapter04-matrices` (1: "The inverse of a transform is a transform"),
   `chapter04-transforms` (6 of 6 rotation-dependent scenarios), and `chapter04-plate` (6:
   every fan/F point and pixel scenario). This is the best-covered mistake in the chapter.

2. **`Transformed` applies `m` instead of `inverse(m)`.** Caught: 5 scenarios in
   `chapter04-shapes` failed ("A circle seen through a scale is an ellipse", "The
   transform is applied in the order the matrix says", "A pen in shape space scales with
   the shape", "Dividing the width by approx_scale makes the two pens agree", "Under a
   non-uniform scale the compromise shows"). Notably `chapter04-plate` stayed green,
   because the fan and the F are built with `Outline`/`Segment` (points pushed forward
   through the matrix), not `Transformed` (which pulls queries back through the inverse) —
   correctly, since the plate never exercises that code path. Good scenario isolation, not
   a gap.

3. **`outline(...)` that doesn't close** (drops the last-point-back-to-first edge).
   Caught: 3 scenarios — both `chapter04-shapes` outline scenarios (wrong lit-pixel counts:
   16 instead of 20, and 58 instead of 76) and `chapter04-plate`'s "Plate 4" (one pixel
   sample landed on what should have been the missing closing edge of the F and came out
   as background instead of ink). `chapter04-plate`'s fan scenario was unaffected, as
   expected — the fan doesn't use `outline`, it unions rays from a shared center.

4. **`approx_scale` defined as the longest-column length** instead of
   `sqrt(|det|)` (the "cheap, plausible, wrong for shears" alternative the chapter
   itself warns about in §4.4). Caught: 4 scenarios — 3 in `chapter04-scale`
   ("A non-uniform scale is reported as the geometric mean", "A shear that preserves
   area reports 1" — this is the exact case the chapter calls out as the dangerous
   one, and the suite does catch it — and "A collapsed transform reports 0", since
   the longest-column definition doesn't go to zero when a scale axis does), and 1 in
   `chapter04-shapes` ("Under a non-uniform scale the compromise shows").

**No mutation survived.** I didn't find a wrong implementation that passed every
scenario, which is itself worth reporting plainly rather than dressing up: this chapter's
scenario set is thorough enough that I could not find the gap the assignment asked me to
look for. I'd treat that as a genuinely good sign for this chapter rather than a sign I
didn't try hard enough — the four mistakes I picked are exactly the ones the chapter's own
prose calls out as the easiest to make (negated sine, wrong transform direction, an
unclosed polygon, and the naive-but-wrong `approx_scale`), and all four are covered.

## Concrete changes I'd make

Given the above, my suggestions are minor:

1. Add one sentence to §4.2 (near "Zero means there is no inverse") stating explicitly
   whether `is_invertible` is meant as exact equality to zero or within a tolerance. The
   book is careful about this everywhere else; this is the one silent spot.
2. Optional: a scenario in `chapter04-matrices` for a matrix that is invertible but whose
   determinant, computed straightforwardly, comes out as a tiny nonzero float due to
   accumulated rounding (e.g., a long chain of compositions) — to pin whether
   `is_invertible` should tolerate that or not. Not required by anything currently in the
   chapter, and I have no evidence it would currently fail anywhere, but it's the one
   loose thread.
3. Nothing else. I looked for a wrong-but-passing implementation and didn't find one; I
   don't have a scenario-level change to propose beyond the above.

## Timing

Whole suite (`dotnet run`, Debug configuration, from a clean `bin`/`obj`): build + all 206
scenarios + all 15 renders (chapters 1-4) finished in about **8.5 seconds** wall clock.

Chapter 4's two renders specifically, measured with a `Stopwatch` around
`Renders.FanBothOrders()` and `Renders.Plate04()` (temporarily instrumented, then reverted
— not part of the committed code):

- Debug configuration (the default for plain `dotnet run`): `fan_both_orders` ≈ 1.2 s,
  `plate_04` ≈ 1.6 s (after JIT warmup, so this is steady-state, not JIT cost).
- Release configuration (`dotnet run -c Release`): `fan_both_orders` ≈ 100 ms,
  `plate_04` ≈ 125 ms.

The chapter's claim ("about the same work as chapter 3's fan... well under a second
compiled") holds for an optimized build, but a reader running the book's own suggested
command in Debug mode would see over a second per plate, which reads as a mild surprise
against "well under a second." Worth a one-line caveat in the prose (or in this codebase's
own README) that "compiled" implies an optimized build, not just "not an interpreter."
