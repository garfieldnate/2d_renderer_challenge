# Chapter 13 reader feedback — Java

## Result

- Chapter 13: **15/15 scenarios pass.**
- Full suite, chapters 1-13: **443/443 scenarios pass**, 0 failures.
- Renders, each against `reference/chapter-13/*.ppm`:
  - `joins.ppm`: `max_channel_difference = 0`
  - `plate-13.ppm`: `max_channel_difference = 0`
  - `caps.ppm`: `max_channel_difference = 0`

Everything passed on the first implementation attempt; no scenario needed
weakening, and none was left failing.

## Catch-up

Chapters 1-12's existing test suites (`Chapter01Tests` through
`Chapter12Tests`) were run unmodified before touching anything. All 428
scenarios across those twelve chapters still pass. Nothing was newly broken
by anything already in this reader's code -- chapter 13 was pure addition
(`Stroke.java`, chapter-13 additions to `Figures.java`, and
`Chapter13Tests.java`; no existing file's behavior changed).

## Ambiguities

- The stroker's algorithm (how to place the join wedge, which side of the
  turn is "outer," the exact arc-stepping rule, the closed-form miter
  length's angle convention) is not fully spelled out in prose to the point
  a cold implementation could derive it unambiguously from §13.1-§13.4
  alone. The prose describes the *pieces* (rectangle, wedge, cap) and the
  *failure modes* (division by zero, miter runaway) precisely, but the exact
  geometric recipe -- e.g., "offset by the perpendicular of the unit
  direction, choose the sign of that perpendicular by the sign of
  cross(d_in, d_out)" -- is not written out as pseudocode the way
  `stroke_to_path`'s outer shape (§13.2) is. What rescued this reader is
  that the chapter's own figure-drawing JavaScript (embedded in
  `chapter-13.html`'s `<script>` block, used to draw Figures 13.1-13.3 and
  Plate 13) *is* a complete, working reference stroker -- `segRect`,
  `joinShape`, `capShape`, `dedupe`, `strokeToPath`, `arcSteps`. That code is
  clearly meant as the plate-drawing implementation, not as material the
  reader is supposed to read, but for a stroker chapter with a failure mode
  this fiddly, being able to check the plate's own JS against my
  independent Java port was the difference between "probably right" and
  "diffs 0." A reader without access to `chapter-13.html`'s raw source (i.e.
  reading only the rendered book, not its HTML) would have had a much
  harder time getting `joinShape`'s sign convention and `capShape`'s
  semicircle-direction right without guessing and checking against the
  reference PPMs by trial and error.
- `miter_length(d_in, d_out, h)`'s exact angle convention is not derivable
  from "theta is the turn's interior angle" alone. Working the two example
  values back through the formula shows that `theta` is the angle between
  `-d_in` and `d_out` (equivalently, `pi` minus the angle between `d_in` and
  `d_out` directly) -- not, say, the signed turn angle, or the angle between
  `d_in` and `d_out` un-reversed. Both scenario values are consistent with
  this reading and with no other simple reading I tried first (I initially
  assumed `theta` was the raw angle between `d_in` and `d_out`, which
  matches the first example by coincidence -- both are 90 degrees either
  way -- but fails the second by a wide margin: `h/sin(30°) = 4`, not the
  scenario's `2.309401`). A sentence spelling out "the angle between the
  incoming direction reversed and the outgoing direction" (or an explicit
  small ASCII diagram) would have saved the back-and-forth.
- The exact hairpin-reversal case (§13.4's trap prose: "the miter limit
  catches it -- the tip is at infinity, so it bevels") does not match the
  reference JS's actual behavior at an *exact* 180-degree reversal: when
  `d_out` is exactly `-d_in`, `cross(d_in, d_out)` is exactly zero (not
  merely small), and the reference's `joinShape` returns `null` -- no join
  wedge at all, not a bevel. The bevel-fallback behavior described in prose
  is what happens for a reversal that is *close to* 180 degrees but not
  exact (there the cross product is a small nonzero number, the miter tip
  is enormous, and the limit check falls back to a bevel as described).
  This is a fine distinction with no practical consequence for filled
  output (both "no wedge" and "a degenerate near-zero-area bevel" paint
  the same pixels), and no scenario exercises the exact-reversal case, so
  it isn't a scenario bug -- just a spot where the prose's "so it bevels"
  overstates what the exact edge case does. Ported faithfully to match the
  reference; flagging in case a future chapter's scenario probes exactly
  this boundary.

## Hard to translate

Nothing chapter-13-specific was hard to translate into this Java codebase's
existing idiom. `Path`/`Subpath`/`Bounds`/`Tuple` from chapters 4-5 already
had everything the stroker needed (mutable subpath builder, `.close()`,
`.bounds()`, vector arithmetic including `cross`/`dot`/`normalize`), and
`Path.edges()`'s "every subpath is closed regardless of the flag" rule
(chapter 5's convention) meant the generated rectangles/wedges/caps didn't
need any special closing logic beyond calling `.close()` for tidiness -- the
fill would have been correct either way. The one new piece of vocabulary
needed was a 2D perpendicular (`perp(v) = vector(-v.y, v.x)`), which isn't
in the existing `Tuple` API; added as a private helper inside `Stroke`
rather than growing `Tuple`'s public surface, since nothing else in the
book (so far) needs a bare perpendicular operator.

## Failures

None. Every scenario in `features/chapter13-*.feature` passed as written,
with no tolerances loosened.

## Prose problems

- §13.3 ("the turn's interior angle"): as described above under
  Ambiguities, the phrase doesn't pin down which of the two supplementary
  angles (`theta` vs. `pi - theta`) is meant, and the two example values in
  the "closed form" scenario only disambiguate it by back-solving. A
  worked example in prose (even just naming the angle for the chevron's own
  vertex) would remove the need to guess.
- §13.4's trap ("the miter limit catches it -- the tip is at infinity, so
  it bevels" for a hairpin reversal): technically true only in the limit,
  not at the exact reversal, where the reference implementation's turn-zero
  check fires first and skips the join entirely rather than falling back to
  a bevel. Not scenario-visible (no scenario feeds an exact 180-degree
  reversal to `stroke_to_path`), so this is a nit, not a bug -- flagged for
  precision's sake, since the chapter is otherwise scrupulous about this
  kind of boundary.
- The exact geometric recipe for `joinShape`/`capShape` (sign conventions,
  arc-stepping resolution `pi/16`, the `1e-9`/`1e-12` degenerate
  thresholds) exists only in the figure-drawing JavaScript inside
  `chapter-13.html`, not in the chapter's prose or printed pseudocode. Every
  other named render in chapters 7-12 that this reader has seen either
  prints its pseudocode in the chapter body (`needle_path()`, `rays(i)`,
  `flower_at`) or is simple enough to derive directly; chapter 13's
  `stroke_to_path` pseudocode (§13.2) covers only the *shape* of the
  algorithm (rectangle, then join, then cap) and leaves the actual
  perpendicular-offset and sign-of-turn arithmetic to be inferred. This
  reader could only get a bit-exact match by reverse-engineering the
  embedded JS, which (per this project's own stated rule that the
  book-repository stroker is "never printed" for other reference material)
  seems like an oversight rather than intentional -- worth either printing
  the geometric recipe as pseudocode the way other chapters do, or
  explicitly acknowledging that the figure JS is fair game to read.

## Mutation results

Five plausible mistakes were introduced into `Stroke.java`, one at a time,
each reverted before the next:

1. **Wrong outer side of a join's turn** (flipped the sign of `s = turn > 0
   ? -1 : 1`): caught by 4 scenarios (`join=round`'s point count, the
   miter-tip-location scenario, and 2 of the 3 plate scenarios).
2. **Miter that never falls back to a bevel** (dropped the `miterLimit`
   check entirely, always returning the 4-point miter shape): caught by 1
   scenario ("the miter limit switches the join to a bevel past its
   threshold" -- a 4-vs-3-point count check). Did **not** affect any of the
   three renders, since the plate's own miter panel uses the default limit
   (4.0), which never triggers the fallback for that chevron -- worth
   noting that the render scenarios alone would not have caught this
   mistake; the dedicated miter-limit scenario is load-bearing here.
3. **Offset by the full width instead of half** (`h = width` instead of
   `width / 2`): caught by 9 of the 15 scenarios, including all three
   renders. The most obviously-wrong mistake, and the suite reflects that.
4. **Round cap sweeping the wrong semicircle** (flipped the sign choosing
   which side of `pi` the cap's arc sweeps): caught by exactly 1 scenario
   ("Plate 13: the three caps," via `max_channel_difference`) -- the two
   specific `ppm_pixel` probes in that scenario (at the segment's interior,
   not the cap's bulge) did not detect it. The render-diff check is
   load-bearing for this mistake; the probes alone would have let it
   through.
5. **Not dropping duplicate consecutive points** (skipped `dedupe`
   entirely): caught by 1 scenario ("duplicate consecutive points are
   dropped," a subpath-count mismatch: 3 subpaths instead of 1). This one
   is interesting: it did not crash. The zero-length segment produces a
   `NaN` unit direction, which propagates into a `NaN`-cornered rectangle
   and a `NaN`-cornered join wedge, both of which just get silently added
   as extra (garbage) subpaths -- Java doesn't throw on `NaN` arithmetic,
   it just propagates it. The scenario still catches the mistake (wrong
   subpath count), but a scenario that only checked, say, `bounds(o)`
   rather than an exact subpath count could plausibly have missed this,
   since `NaN` poisons bounds in a way that might or might not trip an
   equality check depending on how bounds are computed. Worth knowing that
   the existing degenerate scenario's specific assertion shape (count, not
   just "does it render okay") is what catches this.

**No mutation survived every scenario.** All five were caught by at least
one scenario each; two of the five (#2 and #4) were caught by only a single
scenario and would not have been caught by the render `ppm_pixel` probes or,
in #2's case, by any render at all -- the dedicated non-render scenarios
("the miter limit switches...", the join-style-and-point-count table) are
doing real work that the plates alone don't cover.

## Concrete changes

- Add a worked numeric example to §13.3 pinning which of the two
  supplementary angles "the turn's interior angle" refers to (see Prose
  problems).
- Either print `joinShape`/`capShape`'s geometric recipe as pseudocode in
  §13.1/§13.2 (matching how §7.6 prints `needle_path()`/`rays(i)` and §8.3
  prints `petal()`), or explicitly note that the chapter's embedded
  plate-drawing JavaScript is intended as readable reference material for
  this chapter, the way `reference/impl/renderer.py` is for the whole book.
  As written, a reader who only reads the rendered HTML (not its source)
  has no path to bit-exact joins/caps short of trial-and-error against the
  reference PPMs.
- Consider a scenario that exercises the miter-limit fallback *inside* a
  render (not just the standalone subpath-count scenario), since mutation
  #2 above shows the current plate never triggers that branch at all --
  it would strengthen the render's coverage of the chapter's actual
  headline feature (the ratio switch).
- Consider a scenario that probes a cap's bulge pixel specifically (not
  just the segment's interior, as the current two `ppm_pixel` probes in
  "the three caps" do), since mutation #4 shows the existing probes miss a
  wrong-semicircle mistake that only the full-image diff catches.

## Timing

- Full `javac -d classes src/*.java` (all 13 chapters' source, ~70 files):
  about 1.1 s wall (parallel javac).
- Chapter 13 alone (`Chapter13Tests`, 15 scenarios plus 3 renders): ~115-155
  ms.
- Full suite, chapters 1-13 run sequentially (13 separate `java` process
  launches): ~7.3 s wall, dominated by JVM startup overhead (13 process
  launches) rather than actual test or render work -- chapter 13's own
  contribution is a small fraction of that.
- Wall-clock time for this whole task (reading the chapter and its four
  feature files, reading the existing chapter 1-12 Java sources for
  convention, implementing `Stroke.java` and the chapter-13 additions to
  `Figures.java`, writing and passing all 15 scenarios on the first
  attempt, verifying 0-diff renders, running 5 mutation trials, and writing
  this file and the README update): under an hour of wall time in this
  session.
