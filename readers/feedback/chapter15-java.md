# FEEDBACK — Java reader, chapter 13 catch-up, chapters 14 and 15

Working directory: this one. Everything below was run with
`javac -d classes src/*.java` then `java -cp classes Chapter<NN>Tests` from
here, `reference/` and `features/` resolving as relative paths.

## Catch-up (chapter 13, revised since this code last ran)

**Result.** Before touching anything, chapter 13's suite was 13/15 green:
`Plate 13: the three joins` and `Plate 13: Plate 13` both failed on
`max_channel_difference(p6, ref) <= 1`; `Plate 13: the three caps` passed.
After the fixes below, 21/21 (the suite grew by six scenarios). All three
chapter 13 renders re-rendered and diff 0 against `reference/chapter-13/`.

**What was new or changed, and what failed.** Comparing `Chapter13Tests.java`
against the current `features/chapter13-stroke.feature` and
`chapter13-degenerate.feature` turned up six scenarios present in the
`.feature` files but absent from the Java suite: "the round join is an arc
across the outer gap, not around the inside", "the join sits on the outer
side of the turn", "every piece winds the same way, so overlapping pieces
add instead of cancelling", "a wide stroke around a tight bend overlaps
itself and stays solid", "a closed subpath strokes to segments and joins,
with no caps" (all in `chapter13-stroke.feature`), and "a square cap extends
a half-width past the end" (`chapter13-degenerate.feature`). The existing
"chevron's join is a different shape" scenario outline also had a stale
expected value: `round` was pinned at `24` points, which was the *old*,
buggy round join's point count (it swept the long way around the vertex);
the current feature file pins `13`.

Translating the missing scenarios and fixing the stale one exposed two real
bugs in `Stroke.java`, not just gaps in the test file:

1. **The round join swept the wrong way.** Its angle-wrapping logic
   (`if (s > 0 && a1 < a0) a1 += 2*pi; if (s < 0 && a1 > a0) a1 -= 2*pi;`)
   picked a wrap direction from the *sign of the turn*, not from which
   arc is actually shorter, so on the chevron in the scenarios it swept
   244 degrees through the inside of the bend instead of 116 degrees
   through the outside -- the exact "notch" bug CLAUDE.md's chapter 13
   commit describes fixing once already, apparently regressed or never
   fully applied to this reader's copy. Fixed by computing the signed
   shortest angular difference (`angBetween`, wrapped to `(-pi, pi]`) and
   sweeping by that, unconditionally. Verified against the pinned point
   `subpaths(o)[2].points[6] = point(78.797, 132.944)`.
2. **Pieces didn't all wind the same way.** `Fill.polygonArea` returned
   `abs(shoelace sum)`, and nothing in `Stroke` normalized a piece's point
   order. The new "winds the same way" scenario pins
   `polygon_area(o) = -4981.625` (negative, i.e. signed), which the old
   `polygonArea` could never return. Fixed both ends: `Fill.polygonArea`
   dropped its `Math.abs`, and `Stroke` now routes every emitted piece
   through `emit()`, which reverses a piece's points if *its own* signed
   area comes out positive, so every piece is counterclockwise on screen
   before it's kept. Re-checked every chapter 7 scenario that uses
   `polygon_area` afterward (`ink(cov) = polygon_area(p)` for a handful of
   named polygons) -- all still pass, because every polygon chapter 7 pins
   happens to already wind in the direction that makes signed and unsigned
   equal. Also added `Figures.uTurn()` (nine points on a semicircle,
   radius 10, from 180 to 360 degrees in 22.5-degree steps), since the new
   "wide stroke around a tight bend" scenario needs a `u_turn()` helper
   that didn't exist in this reader's `Figures.java` yet.

## Chapter 14 — Offsetting Curves

**Result.** 26/26 scenarios pass on the first full run after implementation
(no chapter-14 scenario ever failed against a correct implementation).
Breakdown: offset 5, curvature 4, fit 4, curve 5, stroke 4, plate 4.
Renders: `two-strokes.ppm` 0, `fold.ppm` 0, `offsets.ppm` 0, `plate-14.ppm`
0 (all `max_channel_difference` against `reference/chapter-14/`).

Two of the four plate scenarios failed on the *first* attempt
(`max_channel_difference <= 1`) despite every non-plate scenario already
being green and every pixel *probe* in those same plate scenarios passing.
Root cause: `outlinePanel`'s magenta trace rounds each outline coordinate to
a pixel with plain round-half-up (`Numbers.round`, i.e. `Math.round`).
`hairpin()`'s control points are left-right symmetric, so the flattened
outline has a vertex sitting exactly on a half-integer y-coordinate at its
peak, and round-half-up there disagreed with the reference implementation's
Python-style round-half-to-even by one pixel, smearing a short run of extra
magenta near the top of the two-strokes and fold-demo panels. This is not a
chapter bug; it's a byte-exactness bug in this reader's own line-drawing
helper. Fixed by adding `Numbers.roundHalfEven` (mirroring the reference's
own `pyround`: round, then nudge down by one if the input was exactly a
half-integer and the naive round came out odd) and switching both
`outlinePanel` (chapter 14) and `tracedPanel` (chapter 13) to it. Since it
only changes behavior exactly at a `.5` tie, chapter 13's renders -- which
apparently never hit one -- are unaffected (still diff 0).

**Ambiguities.**
- `offset_distance_error`'s "walk 100 points along the result" is never
  pinned exactly -- every scenario using it is an inequality (`<=` or
  `>=`), never an exact value. I chose to spread the 100 points evenly by
  *piece index* (parameter `s` running 0 to `numPieces`, not by arc
  length, since chapter 14 has no arc-length machinery yet -- that's
  chapter 15), which satisfies every scenario's bound with room to spare.
  A reader who instead spread the 100 points by *segment count* within
  each piece, or evaluated only at `t=0.5` per piece, would likely also
  pass every pinned bound; the chapter doesn't need to specify this more
  tightly, but it's worth knowing the scenario doesn't discriminate
  between implementations here the way most of this book's scenarios do.
- `distance_to_curve`'s ternary-search bracket ("between that sample's two
  neighbours") I read as `[t[i-1], t[i+1]]` around the nearest sample
  `i` (clamped at the ends of `[0, 1]`), which is what makes every pinned
  value match exactly, so I'm confident it's the intended reading -- but
  the prose alone permits other reasonable brackets (e.g. always using a
  fixed-width window rather than clamping at the array ends).

**Hard to translate.** Nothing forced an awkward shape in Java. The
pseudocode for `fit_offset`, `offset_curve`/`offset_into`, and
`stroke_curve_to_path` mapped onto Java close to line-for-line; the only
real design choice was exposing chapter 13's private `capShape` and
`dedupe` as thin public wrappers (`Stroke.capShapePublic`,
`Stroke.dedupePublic`) rather than re-implementing that geometry a second
time in `Offset.java` -- duplicating it risked exactly the kind of drift
that caused the round-join regression in the catch-up above.

**Failures.** None outstanding. The two rounding-tie plate failures above
were found and fixed during this round; see the Result note.

**Prose problems.** None that blocked implementation. The `offset_distance_error`
under-specification above (§14.4) is the only place I'd suggest tightening,
per CLAUDE.md's own "probe a clamp/rule where it matters" standard --
right now no scenario can tell an author's exact walk apart from a
plausible near-miss.

**Mutation results.** Three deliberate bugs, all caught:
1. *Offset normal on the wrong side* (`normalAt` returns
   `vector(tan.y, -tan.x)` instead of `vector(-tan.y, tan.x)`): 18 of 26
   scenarios failed immediately, starting with the very first one
   (`normal_at(q, 0)` came back negated).
2. *Cusp/stall condition with the wrong sign* (`stallFactor` returns
   `1 + curvature * d` instead of `1 - curvature * d`): 11 of 26 failed --
   cusp counts flipped between the "outside" and "inside" cases
   (`cusps(q, 2)` went from 0 to 2 and `cusps(c, -2)` from 2 to 0), which
   cascaded into wrong piece counts and wrong plate pixels.
3. *Offset curve that doesn't split at cusps* (`offsetCurve`'s parameter
   list hardcoded to `[0, 1]`, ignoring `cusps(c, d)` entirely): 8 of 26
   failed. Notably, the two `chapter14-curvature.feature` scenarios that
   call `cusps` directly still passed (the mutation only touches
   `offsetCurve`, not `cusps` itself) -- it was the piece-count and
   plate scenarios downstream (`length(pieces) = 6`, the two-strokes and
   fold-demo renders) that caught it. No mutation escaped detection.

## Chapter 15 — Dashes

**Result.** 28/28 scenarios pass on the first full run. Breakdown: length
6, pattern 4, dash 8, closed 5, plate 5. Renders: `even-marks.ppm` 0,
`dash-strip.ppm` 0, `spiral.ppm` 1 (within the `<= 1` budget), `plate-15.ppm`
1 (also within budget) against `reference/chapter-15/`.

**Ambiguities.** None that changed a result. The one genuine judgment call
was `dash_count`, used in one scenario
(`dash_count(sp, [16, 10], 0) = 17`) but never defined in prose or
pseudocode anywhere in the chapter -- it's obviously
`length(subpaths(dash(path, pattern, phase)))`, and implementing it as
exactly that one-line wrapper (`Dash.dashCount`) matches the pinned value,
so there was nothing to guess wrong.

**Hard to translate.** The dash walk itself (§15.3's pseudocode) translated
directly, but getting the *closed-subpath merge* (§15.4) right needed more
care than the prose pseudocode shows, since that section has no pseudocode
block at all -- only prose ("the last dash absorbs the first... unless a
single dash covers the whole loop"). The tricky part in Java specifically:
Java has no anonymous mutable closures over local `cur`/`i`/`remaining`
the way the reference's JavaScript does, so the walk has to be one flat
loop with explicit `curOpen`/`i`/`remaining`/`on` locals mutated in place
across both the segment loop and the inner step-loop -- straightforward,
but worth flagging because a reader translating this into a language with
less convenient mutable closures (or one that encourages recursion instead)
would need to think about this structure explicitly rather than transcribe
it.

**Failures.** None. Every scenario passed as soon as `Length.java` and
`Dash.java` were written from the prose and pseudocode; the two `spiral.ppm`
plate pixels landing 1 apart are within every scenario's explicit budget
and were not investigated further, since chasing a `<= 1` result inside its
own stated tolerance would be chasing noise, not a bug.

**Prose problems.** None that caused a wrong implementation. One structural
note for whoever maintains the reader-testing tooling, not the chapter
text: `Figures.java` now has two renders both named `spiral` --chapter 6's
`Figures.spiral()` (`out/spiral.ppm`) and chapter 15's
`Figures.spiralDashes()` (also written to `out/spiral.ppm`, per the
chapter's own specified reference filename). Both chapters' *tests* compare
freshly rendered canvases against `reference/`, never read back from
`out/`, so this never affects a pass/fail -- but running the full 1-15
suite in order leaves only chapter 15's picture on disk afterward at that
path. Documented in `README.md`; flagging here in case the author wants
chapter-namespaced output directories (`out/chapter-06/`, `out/chapter-15/`)
in a future revision, since a human skimming `out/` after a full run would
otherwise see the wrong spiral for chapter 6 without any error telling them
so.

**Mutation results.** Three deliberate bugs, all caught:
1. *Dash walk resets the pattern at every vertex* (added `i = 0;
   remaining = pat[0]; on = true; curOpen = false;` at the top of each
   segment's loop body, so a dash could never carry across a corner): 12
   of 28 scenarios failed, including every scenario with more than one
   segment or more than one subpath, and — tellingly — the single-segment
   scenarios (dashes on one straight line) did *not* fail, since a reset
   at the start of the (only) segment is a no-op there. That asymmetry is
   exactly why CLAUDE.md's own rule about probing "the case that actually
   exercises the branch" matters: a reader who only tested straight-line
   dashing would ship this bug.
2. *Closed subpath not walked around its closing segment* (dropped the
   `if (sp.closed && pts.size() > 1) pts.add(pts.get(0));` line): 3 of 28
   failed, exactly the three `chapter15-closed.feature` scenarios that
   depend on the closing segment being walked (the fourth, "each subpath
   starts the pattern over," uses two *open* subpaths and correctly kept
   passing).
3. *Phase applied with the wrong sign* (negated `phase` before the modulo
   wrap): 3 of 28 failed, exactly the three phase-specific
   `chapter15-dash.feature` scenarios (positive phase into a dash,
   positive phase into a gap, and the sum/negative-phase wraparound
   scenario). No mutation escaped detection in either chapter.

## Concrete changes I'd make

1. Pin `offset_distance_error`'s walk more tightly (chapter 14, §14.4) --
   right now no scenario distinguishes a correct walk from several
   plausible wrong ones, which goes against the book's own "a scenario
   must be able to fail on the mistake it exists for" rule.
2. Give chapter 15's plate renders chapter-namespaced output paths, or at
   least tell the reader in the chapter/README that `spiral.ppm` is reused
   across chapters 6 and 15 -- harmless for automated tests, confusing for
   a human running the suite end to end and then looking in `out/`.
3. Consider a scenario in chapter 13 (or a note in CLAUDE.md, which already
   tracks this class of bug) that pins a coordinate landing exactly on a
   `.5` tie for the plate's line-tracing helper, the way chapter 1 already
   does for byte rounding -- chapter 13's own geometry never happens to
   hit one, so this exact regression (round-half-up vs round-half-to-even)
   was latent in the reader's code across two chapters before chapter 14's
   symmetric hairpin curve finally exposed it.

## Timing

Both chapters compute fast; there is no render in either that took a
noticeable fraction of a second on its own. Full runs (every scenario's
computation plus writing all four PPMs), wall clock, this machine:

- `Chapter14Tests`: ~0.2-0.25s total (includes 26 scenarios, several of
  which recurse `offset_into` to depth 16 and bisect `cusps` 40 times per
  candidate root, plus writing `two-strokes.ppm`, `fold.ppm`,
  `offsets.ppm`, `plate-14.ppm`).
- `Chapter15Tests`: ~0.2-0.27s total (28 scenarios plus writing
  `even-marks.ppm`, `dash-strip.ppm`, `spiral.ppm`, `plate-15.ppm`).

Neither chapter needed any timeout or performance workaround.
