# Chapter 4 reader feedback — Java

## Result

All chapters pass, cold, translating every scenario in every `.feature` file with no
weakened tolerances and no skips.

| Chapter | Scenarios | Pass | Fail |
|---|---|---|---|
| 1 | 66 | 66 | 0 |
| 2 | 35 | 35 | 0 |
| 3 | 37 | 37 | 0 |
| 4 | 72 | 72 | 0 |

Chapter 4 breakdown (72 total, matches `grep -c '^  Scenario:' features/chapter04-*.feature`):
tuples 11, matrices 17, transforms 16, scale 6, shapes 13, plate 9.

Renders, `max_channel_difference` against `reference/chapter-04/`:

- `out/fan-both-orders.ppm`: **0** (byte-identical to the reference, confirmed with `cmp`)
- `out/plate-04.ppm`: **0** (byte-identical to the reference, confirmed with `cmp`)

Chapter 1-3 renders were re-verified unchanged after the `ThickLine`/`Segment` refactor
(all three chapters' plate scenarios still pass, and `out/*.ppm` still `cmp`-identical to
their references).

## Ambiguities

None that blocked translation. The chapter is unusually precise for this stage of the
book: every one of the "how big is a transform" candidates is spelled out with a formula,
the rotation direction is stated and re-stated, and the pseudo-code for `fan_points`,
`letter_f`, `fan_transformed`, `fan_both_orders`, `f_both_orders` and `plate_04` left
nothing to guess. Two small judgment calls, neither of which the prose forced but neither
of which had another reasonable answer:

- `outline`'s edge count: the prose says "the union of the segments between consecutive
  points, last back to first" — I read that as exactly `n` edges for `n` points (closing
  the last point back to the first), which the "outline is one shape" scenario's expected
  `length(lit_pixels(c)) = 20` confirms (a 4-point rectangle needs 4 edges, not 3, to have
  a coverage of 0.75 in the corner and 0 inside).
- Where to put `Tuple`'s constructor. It's package-private (no modifier), so `Matrix` and
  `Transformed` can build a raw `(x, y, w)` result directly instead of laundering
  everything through `point`/`vector`. Not spelled out anywhere, but there wasn't another
  sane place to put "the result of `A * v` might have any `w`" — the chapter is explicit
  that `w = 2` is possible and meaningless, so the constructor has to allow it.

## Hard to translate

Nothing structural. The Gherkin data tables (`Given the following matrix M:`) don't exist
as a first-class construct in a hand-rolled Java runner, so each table became a call to
`Matrix.matrix3(...)` written out in reading order, exactly as the chapter says to do "if
you're translating by hand." That's a direct, mechanical translation with no judgment
involved.

## Failures

None. Every scenario passed first try once the arithmetic was right (see Mutation results
below for how I know the scenarios would have caught it if it hadn't been).

## Prose problems

Nothing wrong found. Two small things worth a second look, more nitpicks than bugs:

- §4.4 says approx_scale is "one line: `sqrt(|m[0,0]·m[1,1] - m[0,1]·m[1,0]|)`" but the
  scenario file's Feature description restates it as "the square root of the absolute
  value of the determinant of its upper-left 2 by 2," which is the same thing but only
  obviously the same thing if you already know a 2-by-2 determinant is `ad - bc`. A
  reader coming to this chapter without that fact in short-term memory (plausible, since
  §4.2's determinant discussion is about the 3-by-3 cofactor expansion, not the 2-by-2
  base case) has to reconstruct it. One clause connecting the two would remove the need
  to reconstruct anything: "...of its upper-left 2 by 2 (that's `ad - bc` for a `[[a,b],
  [c,d]]` block)."
- §4.6's Figure 4.5 caption is a nice touch (three wrong Fs with the actual bug named
  under each) but the chapter says explicitly "these are figures, not renders you're
  asked to make; the scenarios for the correct plate fail on every one of them." That's
  true and I confirmed it (see Mutation results), but a reader implementing cold has no
  way to check that claim except by reproducing the bug and running the suite
  themselves, which is exactly what a "reader agent" round is for and exactly what an
  ordinary reader with a deadline won't do. Not a scenario gap — there's no reasonable
  scenario for "does the wrong shape fail," since that's what mutation testing is for,
  not TDD — just a note that the claim is unverifiable to a reader with no more than the
  book in front of them, and it happens to be correct.

## Mutation results

Five mutations tried, all caught (source restored after each; final `Chapter04Tests` run
back to 72/72):

1. **Sine negated** (equivalent to storing the rotation matrix transposed): rotation
   turns the wrong way. Caught by 12 scenarios across matrices, transforms and plate,
   including the plate's `ppm_pixel` checks. Loudly and immediately wrong — this is the
   best-covered mistake in the chapter, as the chapter itself predicts ("every time you
   translate a diagram from a paper into code").
2. **`transformed()` applies `m` instead of `inverse(m)`**: caught by 5 scenarios
   (the ellipse scenario, the order-matters scenario, and three of the pen-in-shape-space
   scenarios). Not caught by the plate scenarios, since `plate_04` never calls
   `transformed` — it only builds outlines from transformed points. Worth knowing: if the
   book ever drops the four dedicated `transformed()` scenarios from
   `chapter04-shapes.feature`, this bug would sail through the rest of the chapter 4
   suite undetected.
3. **Wrong `approx_scale`: longest column instead of `sqrt(|det|)`.** Caught by 3 of the
   6 scale scenarios (non-uniform scale, area-preserving shear, collapsed transform) plus
   one shapes scenario (the non-uniform-scale pen-width scenario). The uniform-scale and
   reflection scenarios did *not* catch it, exactly as the chapter warns — the longest
   column agrees with the geometric mean everywhere they're supposed to agree, and
   disagrees only where the chapter says to test it.
4. **`outline` that doesn't close** (drops the last-point-to-first edge): caught by both
   outline scenarios (wrong `length(lit_pixels(c))`, 16 instead of 20 and 58 instead of
   76) and by `plate_04` (the F's outline is unclosed, so one edge of the letter goes
   missing from the render, and the `ppm_pixel` check at (48, 28) catches it directly).
5. **Points built with `vector` instead of `point`** (the Figure 4.5 left-panel mistake):
   caught by 5 scenarios. `letter_f()`'s own scenario catches it first (`f[0]` comes back
   with `w = 0` instead of `w = 1`), before the transform even runs — a point with the
   wrong `w` fails the moment it's constructed, which is exactly the "bookkeeping does
   itself" promise in §4.1 paying off in the test suite too.

No mutation passed the suite. I did not find a wrong implementation that the scenarios
miss entirely, which was itself worth checking given the assignment's emphasis on it —
this chapter's scenario set is tight.

## Concrete changes I'd make

Nothing required. If pressed for one line of prose to add, it's the `ad - bc` aside on
§4.4 noted above. Nothing else needs prose or scenario changes; the two ambiguities I
resolved were resolved by scenario numbers already in the suite, not by guessing outside
what's testable.

## Timing

- `Chapter04Tests` full run (72 scenarios plus writing both renders): 585-600 ms on this
  machine (compiled, `javac -d classes src/*.java` then `java -cp classes
  Chapter04Tests`), consistent across repeated runs.
- Isolated render timing (via a throwaway `TimeRenders.java`, not part of the committed
  suite): `fan_both_orders()` 99 ms, `plate_04()` (which includes `f_both_orders()` plus
  a 2x magnify) 108 ms. Both are five rasterizations of a 160-by-160 canvas at 64 samples
  per pixel against a union of ten to twelve segments, as the chapter estimates, and both
  land well under the chapter's "well under a second compiled" prediction.
- Full four-chapter suite (`Chapter01Tests` + `Chapter02Tests` + `Chapter03Tests` +
  `Chapter04Tests`, sequential): under 1.2 seconds total, including render writes for all
  four chapters.
