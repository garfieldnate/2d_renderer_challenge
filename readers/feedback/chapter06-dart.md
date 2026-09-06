# Reader feedback: Dart, chapters 1-6

This is a cold, first-language-in-Dart implementation. There was no existing
`readers/dart/` code and no `dart` catch-up round to run — every chapter
below is implemented from the chapter text and its `.feature` files alone,
in order, chapter by chapter. Dart SDK 2.18.6, no pub packages, hand-rolled
test runner (`test/harness.dart`). `dart analyze .` is clean throughout.

Overall result: **280/280 scenarios pass**, all 20 renders diff at
`max_channel_difference = 0` against `reference/`.

---

## Chapter 1: The Canvas and the Color

**Result.** 62 scenarios (equality 3, colors 6, canvas 6, srgb 4 + 9 + 7
outline rows, ppm 11, gray-match 3, mix 9, limits 3, plate 1), all pass.
Renders: `gray-match.ppm`, `quarter-match.ppm`, `ramp.ppm`, `clamp-pair.ppm`,
`plate-01.ppm`, all diff 0 against `reference/chapter-01/`.

**Catch-up.** N/A — first reader.

**Ambiguities.** None that needed guessing. One decision, not forced by the
prose but worth naming: the book says the reference images "from here on"
(chapter 2) are P6, which implies chapter 1's own references are still P3.
I confirmed this by inspecting the reference files' magic bytes before
writing `tool/render.dart`, rather than assuming; a reader who assumes P6
everywhere would get a diff of 255 on every chapter 1 render and lose time
chasing a phantom rasterizer bug.

**Hard to translate.** Nothing chapter-specific. General Dart notes: no
tuple type in SDK 2.18 (records arrived in Dart 3), so `(0, 188, 255)`
triples became a small `RgbTriple` class, and pairs like a PPM's parsed
header became dedicated classes rather than anonymous tuples. Scenario
Outlines became Dart `for` loops over a `List<List<num>>` of example rows.

**Failures.** None.

**Prose problems.** None found.

---

## Chapter 2: Coverage

**Result.** 35 scenarios (shapes 4, p6 6, magnify 2, centers 8, paint 5,
coverage 7, twice 2, plate 1), all pass. Renders: `disc-centers.ppm`,
`disc-coverage.ppm`, `painted-twice.ppm`, `plate-02.ppm`, all diff 0.

**Catch-up.** N/A.

**Ambiguities.** None. The P6 header-parsing algorithm (read three
whitespace-delimited tokens, skip exactly one whitespace byte, treat
everything after as raw pixel bytes) is specified precisely enough that
"pixel bytes that look like whitespace" (10, 32, 10) worked on the first
attempt.

**Hard to translate.** `distinct_values` is a `Set<int>` over the flat
pixel-value list, per the chapter's own warning about naive sorting on
large images; nothing Dart-specific here.

**Failures.** None.

**Prose problems.** None found.

---

## Chapter 3: Lines

**Result.** 38 scenarios (bresenham 10, wu 9 + 4 outline rows, quad 6 + 4
outline rows, plate 5), all pass. Renders: `fan-bresenham.ppm`,
`fan-wu.ppm`, `fan-coverage.ppm`, `plate-03.ppm`, all diff 0.

**Catch-up.** N/A.

**Ambiguities.** None. The tie-breaking rule for Bresenham (`err < 0`,
strict) and the floor-not-truncate rule for Wu are both stated explicitly
and pinned by name ("At an exact half the line stays on its row one step
longer", "A line that starts above the canvas").

**Hard to translate.** Dart's `double.floor()` already floors toward
negative infinity (matches C's `floor`, not truncation toward zero), so the
negative-`y` Wu scenario needed no special handling — worth flagging only
because the chapter calls this out as "the port bug this chapter sees
most" for languages where the default cast does truncate.

**Failures.** None.

**Prose problems.** None found. The FMA/compiler-contraction trap in
`§3.3` doesn't apply to Dart (no `#pragma STDC FP_CONTRACT`, and the AOT/JIT
compiler doesn't silently fuse multiply-adds the way C compilers do), and
the diagonal thick-line scenario (`ink(cov) = 9.71875`) passed without
needing to disable anything.

---

## Chapter 4: Points, Vectors, Transforms

**Result.** 76 scenarios (tuples 12, matrices 18, transforms 16, scale 6,
drawing 14, plate 10), all pass. Renders: `fan-both-orders.ppm`,
`plate-04.ppm`, both diff 0.

**Catch-up.** N/A.

**Ambiguities.** None from the book. One self-inflicted implementation
snag, recorded here because another Dart reader will hit it: `Matrix3`
needs one operator (`*`) that means "matrix times matrix" in some call
sites and "matrix times tuple" in others, so its Dart `operator*` has to
return `dynamic` and the call site casts (`A * B as Matrix3`). Chaining
three matrices in one expression, `C * B as Matrix3 * A as Matrix3`,
looked like it should mean `((C*B) as Matrix3) * A) as Matrix3` — and
tracing through Dart's actual precedence table (`as` binds *looser* than
`*`) confirms it does parse that way, but it is exactly the kind of thing
that's easy to get backwards without checking, especially since a wrong
grouping would still type-check and could silently multiply in the wrong
order. I added `mm(a, b)` and `mmAll([a, b, c])` helpers and used those
for every chain of three or more, rather than trust inline chained casts.
Worth a note in the chapter for languages with operator overloading and a
similar type-test operator (C++, Kotlin, Swift all have some version of
this hazard).

**Hard to translate.** Nothing beyond the above.

**Failures.** None (the operator-precedence question above was caught by
`dart analyze` type errors during development, not by a wrong scenario
result — I want to be honest that the risk was real even though no
scenario in the current suite happened to exercise the ambiguous grouping
with values that would have exposed a mistake numerically. If you want a
regression scenario for this class of reader bug, "three matrices chained
in one expression, values chosen so left-to-right and right-to-left
association give different translations" would be worth adding — see
Mutation results below, this is adjacent to a near-miss.).

**Prose problems.** None found. The trap about pen-in-shape-space vs.
pen-in-device-space is precise and the two scenarios that pin it
(`coverage_at` diverging under `scaling(3, 1)`) are exactly as advertised.

---

## Chapter 5: Paths and Insideness

**Result.** 32 scenarios (paths 10, winding 9, rules 9, plate 4), all pass.
Renders: `star-centers.ppm`, `star-coverage.ppm`, `plate-05.ppm`, all diff
0.

**Catch-up.** N/A.

**Ambiguities.** None. The `line_to`-after-`close` behavior (new subpath
starting at the closed subpath's first point) and the "subpath of one
point has no edges" special case are both pinned by scenarios precisely
enough that there was nothing to guess.

**Hard to translate.** Nothing.

**Failures.** None.

**Prose problems.** None found.

---

## Chapter 6: Filling a Polygon

**Result.** 37 scenarios (edges 6, spans 12 + 4 outline rows, sweep 12,
plate 3), all pass. Renders: `spiral.ppm`, `plate-06.ppm`, both diff 0.

**Catch-up.** N/A.

**Ambiguities.** None. The chapter's own trap about the star's fifth,
near-zero-height edge (from a floating-point tie in two supposedly equal
`y` values) is real in this Dart implementation too — `edge_table(star())`
does come out with 5 entries, not 4, for exactly the reason described, and
the chapter correctly declines to pin that count in any scenario.

**Hard to translate.** Nothing.

**Failures.** None.

**Prose problems.** None found. This was the tightest chapter of the six:
every half-open boundary (`y_top ≤ y < y_bottom`, `x0 ≤ center < x1`) has a
scenario that would fail if it were flipped to the other inclusive/exclusive
combination — confirmed directly in mutation testing below.

---

## Mutation results

Five mutations tried against the working implementation, each applied to
`lib/renderer.dart`, tested with the full suite, then reverted (verified
byte-identical to the pre-mutation file afterward):

1. **Truncate instead of round** in the PPM channel conversion
   (`(encoded * 255).floor()` instead of `.round()`). Caught immediately
   and broadly: 13 failures across chapter01-ppm, chapter01-limits,
   chapter02-p6, and chapter02-paint, all off by exactly 1 in the direction
   truncation predicts (e.g. expected 188, got 187).

2. **Browser-mode mix clamps the blended result instead of clamping the
   ends before encoding** (the chapter's own named trap in §1.7). Caught by
   exactly one scenario, "The browser's way clamps each end before
   encoding it" — precisely the `t = 0.5` probe the chapter says is
   necessary (`t = 0` alone would not have caught it, matching the
   chapter's warning). Everything else still passed, which confirms the
   suite has exactly one line of defense here, not several — a second,
   independent probe at a different out-of-range input wouldn't hurt, but
   I'm not adding one on my own initiative since the existing one already
   does its job.

3. **Half-open rule broken in `winding_at`** (`b.y >= y` instead of
   `b.y > y` in the "heading down" branch). Caught broadly: 5 failures,
   including "A ray through a vertex counts it once" (expected 1, got 2)
   and "The polygon circle" — exactly the vertex-on-ray case the chapter
   calls its own classic bug.

4. **`approx_scale` via the full 3x3 `determinant(m)` instead of the
   upper-left 2x2 minor** (`ad - bc`). **This one passed every scenario
   (280/280 green).** This is not actually a chapter bug: §4.4 says
   outright "For every matrix in this book the bottom row is `0 0 1`, so
   the full 3-by-3 `determinant(m)` comes out the same and you can use it
   instead" — so the suite is correctly indifferent between the two
   formulations, by explicit authorial design, not by an accidental gap.
   Flagging it here only because the task asked to report anything that
   passes every scenario; this is a documented equivalence, not a finding.

5. **Half-open rule broken in the sweep's active-edge removal**
   (`e.yBottom < y` instead of `e.yBottom <= y`, so an edge stays active
   one row too long). Caught by exactly one scenario, "An edge that starts
   on a sample height is active there, and one that ends there is not" —
   again exactly the probe the chapter's own trap description predicts.

No mutation escaped the suite as a genuine bug. The closest thing to a gap
is the chapter 4 note above: chained matrix multiplications in one
expression are a real hazard for a reader using an operator-overloading
language with a similar `as`/type-test operator, and nothing in the
current scenarios would catch a reader who mis-associated such a chain,
because Dart's actual precedence (once traced through) happens to parse it
correctly regardless of how the reader intended it. I don't have a
concrete counterexample where a *wrong* left/right grouping changes the
answer (matrix multiplication is associative, so grouping alone can't
break a chain — only *order* can, and every scenario that exercises order
already uses separate statements, e.g. "Chained transformations must be
applied in reverse order"), so on reflection this is a translation risk
rather than a testing gap. Recording it anyway since it cost real time.

## Concrete changes I'd make

- None to the chapters themselves — six chapters, zero prose problems,
  zero scenario ambiguities, is a genuinely clean run. If anything, add
  one line acknowledging the `Matrix3`-as-dynamic-dispatch hazard for
  operator-overloading readers, next to the existing note in the plan
  about "some typed languages refuse `c * 2`."

## Timing

- Full test suite (`dart test/run_tests.dart`, 280 scenarios, JIT, cold
  start): ~7.4s wall (includes Dart VM startup; most of this is fixed
  overhead, not test work).
- All renders (`dart tool/render.dart`, 20 images): ~4.4s wall total.
  Per-render breakdown (JIT):
  - Chapter 1 (5 renders): 2-37 ms each, all under 40 ms.
  - Chapter 2 (4 renders): 10-21 ms each.
  - Chapter 3: `fan-bresenham` 2 ms, `fan-wu` 7 ms, `fan-coverage` 304 ms
    (twelve 160x160 coverage rasterizations of a thick-line union, matching
    the chapter's own "twenty million inside tests" estimate), `plate-03`
    22 ms (reuses the two fast fans).
  - Chapter 4: `fan-both-orders` 574 ms, `plate-04` 627 ms — both do
    several 160x160 rasterizations of a union of ten-plus segments at 64
    samples/pixel; consistent with the chapter's "well under a second
    compiled" estimate.
  - Chapter 5: `star-centers` 26 ms (cheap, center-only), `star-coverage`
    415 ms, `plate-05` 489 ms (both rasterize the star's five-edge winding
    number at 64 samples/pixel over a 160x160 canvas, twice per plate).
  - Chapter 6: `spiral` 43 ms, `plate-06` 60 ms — the scanline sweep is
    dramatically cheaper than chapter 5's per-pixel winding-number
    approach, exactly as the chapter promises ("a millisecond... in a
    compiled language the sweep is too fast to time with a stopwatch";
    Dart's JIT here is fast enough that even the *whole* 24-star spiral
    image is two orders of magnitude faster than a single chapter 5 star
    coverage panel).
