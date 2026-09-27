# Reader feedback: Java, chapters 22 and 23

Implemented cold, from `chapter-22.html`/`chapter-23.html` and
`features/chapter22-*.feature`/`chapter23-*.feature` alone, on top of the
existing chapters 1-21 Java code. No access to the book's own repository or
reference implementation; every number below comes from running this code.

## Result

**Catch-up (chapters 1-21):** all 722 existing scenarios still pass,
unchanged, with the code as collected. I did not find any new scenario in
`features/chapter01-*.feature` through `chapter21-*.feature` that the
existing `Chapter01Tests.java`-`Chapter21Tests.java` didn't already cover
(scenario counts per feature file, including `Scenario Outline` expansions,
match the existing test counts exactly). Nothing needed fixing here.

**Chapter 22:** 53 scenarios, 51 pass, 2 fail (both in
`chapter22-bentley.feature`, both a real, understood discrepancy in
`bentley-ottmann`'s own internal bookkeeping at large scale -- see
Failures). Both renders diff **0** against the reference bytes:

| render | max_channel_difference |
|---|---|
| `plate-22.ppm` | 0 |
| `seal.ppm` | 0 |

**Chapter 23:** 43 scenarios, all pass. All eight renders diff **0** against
the reference bytes:

| render | max_channel_difference |
|---|---|
| `primitive-fields.ppm` | 0 |
| `error-map.ppm` | 0 |
| `fields-vs-paths.ppm` | 0 |
| `fillets.ppm` | 0 |
| `transform-demo.ppm` | 0 |
| `atlas-corners.ppm` | 0 |
| `trap-shrink.ppm` | 0 |
| `plate-23.ppm` | 0 |
| `title.ppm` | 0 |

Total across both chapters: 96 scenarios, 94 pass, 2 fail, both understood
and left in place rather than deleted or weakened.

## Catch-up

Covered above: I ran the whole existing chapters 1-21 suite before touching
anything, and separately compared each `chapterNN-*.feature` file's scenario
count (including `Scenario Outline` × `Examples` expansions) against what
`Chapter{01..21}Tests.java` currently exercises. They matched exactly, and
all 722 scenarios were already green, so there was nothing to bring up to
date this round for the earlier chapters. (The most recent commits on this
reader's own history show chapters 8, 20 and 21 were already caught up in
the previous round.)

## Ambiguities

- **Chapter 22, `combine`'s internal finder.** The chapter says outright
  "The finder doesn't change the answer; use any," so this isn't really an
  ambiguity, but it's a choice I had to make: `BoolCombine.combine` always
  calls `Splitting.splitSegments(..., "sweep", ...)` internally. I didn't
  wire a way to ask `combine` for a specific method, since nothing in the
  feature files ever needs one.
- **Chapter 22, Bentley-Ottmann's tie-break "the one earlier in segs
  first."** It isn't stated whether "segs" means the *original* list handed
  to `find_splits`, or the current pass's (already merged, already partly
  cut) list. I used the latter (the index into whichever list is actually
  passed to `find_splits`/`BentleyOttmann.findSplits` for that call), since
  that's the only list the function has a static index into at all. Every
  scenario that exercises this tie-break (the horizontal-segment-last case,
  the three-segments-through-one-point case) passed with this reading, so
  I'm fairly confident it's right, but the prose doesn't say so explicitly.
- **Chapter 22, stitching's exact "furthest right" formula.** The prose
  (§22.5) describes the *strategy* ("face back the way you came... which
  half-turn each is in, then which comes first within a half-turn") but
  never writes out the actual sign convention. I had to derive it, and got
  the sign backward on the first attempt -- see Mutation results below,
  where reverting my fix reproduces exactly that mistake. I'd suggest the
  chapter either print the formula or at least repeat chapter 4's own
  "clockwise on this y-down canvas" warning right at this paragraph, since
  that's exactly the trap here and it isn't obvious from "counterclockwise"
  alone that the *screen* sense is the opposite of the *cross-product* sense.
- **Chapter 23, `is_corner`'s `sin(3)`.** Read completely literally
  (`Math.sin(3)` in radians, not degrees), this matches every scenario
  exactly, and it's a nice bit of misdirection once you notice
  `sin(pi - x) = sin(x)` makes `sin(3 radians)` equal `sin(~8.1 degrees)`,
  matching the prose's "about eight degrees." But nothing in the feature
  text says "radians," and a reader who "fixes" this to
  `Math.sin(Math.toRadians(3))` (getting 0.0523, not 0.1411) would fail two
  of the four `is_corner` scenarios silently different from how they'd
  fail if they'd used, say, 8 degrees as the threshold directly. This is
  exactly the kind of thing worth spelling out in prose rather than leaving
  to a reader's guess about units.

## Hard to translate

- **Bentley-Ottmann's status/event bookkeeping has no natural Java shape.**
  The reference language (implicit from the pseudocode's style) can
  apparently splice a "block" out of an array and insert a new list in its
  place as one expression; in Java this is `List.subList(...).clear()` plus
  `addAll`, and the whole `Piece`/`REvent` machinery (tracking which
  original segment a live sub-segment belongs to, an exact-fraction event
  type with its own `Comparable`, a `TreeSet<REvent>` as the priority
  queue) had to be designed from scratch, none of it named in the chapter.
  Two real bugs came out of getting this design wrong the first time (see
  Failures/Mutation results): a piece whose rounded cut point overshoots its
  own remaining endpoint, and a piece that's collinear with a far-off event
  but outside its own range. Both are now guarded explicitly, both are
  commented in `BentleyOttmann.java`, and both are exactly what the two
  mutation-testing rounds below reproduce.
- **`solve_cubic`'s trigonometric branch.** "The cosine formula when there
  are three [real roots]" is one sentence; getting `Math.acos`'s argument
  clamped against floating-point overshoot (`arg` landing at `1.0000000002`
  from accumulated rounding) and guarding the `p ≈ 0` edge (where the
  formula divides by `p`) took some care Java's standard library doesn't
  give you for free. No scenario in `chapter23-curves.feature` happens to
  exercise `p ≈ 0` with three roots (it would require a very specific
  degenerate cubic), so this particular guard is defensive rather than
  scenario-driven -- worth flagging in case the intended behavior there
  differs from my guess.
- **The multi-channel bake's pseudocode lives in the printed chapter text
  (§23.9's `msdf_texel`/`pseudo_distance`), not in
  `chapter23-atlas.feature`'s own prose**, which describes the same
  algorithm in English only, less precisely (in particular the feature
  prose's phrasing of the near-tie rule doesn't make it obvious that `o`
  defaults to 0 for an interior `t`, which the printed pseudocode states
  outright). A reader working from the feature file alone, without reading
  all the way to §23.9's code block, would have a much harder time getting
  `bake_msdf` bit-exact. I'd suggest folding a version of that pseudocode's
  precision into the feature file itself, the way `chapter22-bentley.feature`
  already prints its own `handle(P)`/`test(s,t)` pseudocode.

## Failures

**`chapter22-bentley.feature`: "Bentley-Ottmann finds what every pair
finds, testing neighbours only"** (`struckSegments(1)`) --
expected `st.tests = 1659, st.events = 879`; got `1664, 882`. Root cause,
traced by hand: segment 168 (a vertical segment,
`(81005, 24730)`-`(81005, 40960)`, snapped grid units) and segment 240 (a
diagonal bar edge) genuinely cross near `y ≈ 36985.5`. `brute` computes this
crossing from the two *original, uncut* segments and gets `y = 36985.48`,
rounding down to `36985`. My Bentley-Ottmann, by the time it discovers this
crossing, has already cut segment 240 once earlier (at
`(83780, 32510)`), so it computes the crossing from segment 240's
*already-rounded remainder* (`(83780, 32510)`-`(72192, 51200)`), a line
that's very slightly rotated from the original by that earlier rounding.
That slightly different line crosses segment 168 at `y ≈ 36985.73`,
rounding *up* to `36986`. Both computations are individually correct given
the geometry each is handed; they disagree because Bentley-Ottmann's own
described algorithm (§22.3: "rounding a crossing moves it... a segment that
turns can hit something it missed") necessarily works from rounded
intermediate pieces once a segment has already been cut once, while `brute`
and `sweep` never re-derive a segment's line from a cut remainder within a
single `find_splits` call -- they always test the two *original* segments'
lines. This is the same phenomenon the chapter's own §22.3 uses to justify
`split_segments`'s multi-pass loop; it isn't a bug in my status-ordering or
event-queue logic (verified: `sweep`, which never subdivides internally,
matches `brute` exactly at this same scale, `309291`/`34326` tests exactly),
and every hand-traceable small scenario in the same feature file (the
three-segments-through-a-point case, the exact-crossing case, the
horizontal-segment-last case, the neighbours-part-and-meet-again case) is
byte-exact. I could not determine, without the reference implementation,
whether the reference's own Bentley-Ottmann has the identical property at
this scale (producing the *same* `1659`/`879`, or a *different* drifted
count of its own) or avoids it with a tie-break I haven't found. I left this
scenario failing rather than adjust the expected numbers or delete it.

**`chapter22-bentley.feature`: "The whole split, three ways, one answer"**
(`struckSegments(2)`) -- same root cause, one level up:
`split_segments(segs, "bentley-ottmann", st)` disagrees with `"brute"`/
`"sweep"`'s final segment list by the same single-grid-unit drift
(propagated through one extra pass), so `a = c` fails alongside the
`bo.tests`/`bo.events` counts (`5224`/`2823` expected).

## Prose problems

I did not find a place where the chapter's prose stated something that
turned out to be factually wrong when I ran the numbers (unlike, e.g., a
previous round's `lopsided()` control-point mismatch) -- both chapters'
printed numbers (the star's `5500.767746`/`3800.918060`, the seal and plate
pixel probes, chapter 23's every listed number) matched exactly once
implemented as literally described. My friction was entirely about *where*
a precise rule lives (see Hard to translate above: §23.9's pseudocode vs.
`chapter23-atlas.feature`'s prose) and about sign conventions the prose
describes qualitatively but doesn't spell out algebraically (§22.5's
"furthest right"). Both are flagged above with section numbers.

## Mutation results

Tried four plausible reader mistakes, reverting each afterward:

1. **Chapter 22: flip the sign convention in `Stitching`'s "furthest
   right" comparator back to the plain math-CCW cross-product sense**
   (undoing the y-down flip described above). Caught by 7 scenarios:
   "turning furthest right keeps two squares that touch at a corner apart"
   (wrong contour count), "two squares, four ways" (xor's second contour
   wrong), "the star's crossings become corners" (evenodd contour count
   5→2), "squares touching at a corner share a point and nothing else",
   "a corner resting on an edge", and both renders (`Plate 22`, `The
   seal`) failing their `max_channel_difference <= 1` check. This is the
   most valuable mutation of the four: it's a mistake this reader actually
   made once during development, and the scenarios that catch it are
   exactly the ones with a real self-touching junction, not the simpler
   single-branch cases.
2. **Chapter 22: drop the "collinear but out of range" guard in
   `BentleyOttmann.orientSign`** (return the raw cross-product sign with no
   range check). Caught by 3 scenarios, most precisely
   `chapter22-bentley.feature`'s own "A crossing between grid points is an
   exact event, split rounded" (`splits[0]` gains a spurious extra point,
   `(0, 1)`, from exactly the bug this guard exists to prevent -- a
   just-cut horizontal remainder spuriously "passing through" an unrelated
   point on the same row), plus the two large-scale scenarios already
   failing for the unrelated reason above (their counts get worse, not
   better).
3. **Chapter 23: drop `sd_box`'s inside term** (`+ min(max(qx, qy), 0)`).
   Caught by "A box, beside a side, off a corner, and inside" and
   "Rounding a box rounds its corners and nothing else" (both fail exactly
   at the *inside* probes, as expected, and pass everywhere the true point
   is outside the box), plus the `primitive_fields` render.
4. **Chapter 23: drop the two end candidates (`t = 0`, `t = 1`) from
   `nearest_t_cubic`, keeping only the nine Newton seeds.** Caught by
   exactly the one scenario built for this ("The nearest point of a cubic
   can be an end that Newton walks away from"), and the number it produces,
   `59.708...`, matches the chapter's own prose almost exactly ("a version
   without the ends says 59.7 where the answer is 50") -- strong
   confirmation that this scenario is pinning precisely the mistake the
   chapter warns about.

No mutation tried passed every scenario; I did not find a "free" bug this
round the way earlier chapters' rounds sometimes did.

## Concrete changes I'd make

- State §22.5's "furthest right" sign convention algebraically, or at
  minimum repeat the y-down/clockwise warning right there (see
  Ambiguities).
- Move (or duplicate) §23.9's `msdf_texel`/`pseudo_distance` pseudocode
  precision into `chapter23-atlas.feature`'s own prose, particularly the
  "`o` is 0 for an interior `t`" detail, so a reader translating from the
  feature file alone doesn't have to cross-reference the printed chapter
  text to get `bake_msdf` exactly right.
- Consider whether `chapter22-bentley.feature`'s benchmark scenario should
  either (a) state the tolerance under which a single-pass Bentley-Ottmann
  is allowed to disagree with `brute`/`sweep` at large scale (since §22.3
  already establishes that a single pass isn't exact in general), or (b)
  confirm harder that the reference implementation is in fact exact here,
  in which case there's a real, currently-undiscovered difference between
  my status-ordering and the reference's that I'd want to find with the
  reference implementation in hand.
- Say explicitly, in `chapter23-atlas.feature`'s own words (not just the
  chapter prose), that `is_corner`'s `sin(3)` is radians.

## Timing

Whole-suite runs (this machine, single-threaded, `javac`/`java` from the
JDK, no JIT warm-up tricks):

- Chapters 1-21: all under a second each; chapter 21 (the tiger, three
  ways) is the slowest at 2.1 s.
- Chapter 22: 53 scenarios, 725 ms total. The two large-scale
  `struckSegments`/Bentley-Ottmann scenarios dominate (a few hundred
  milliseconds each); every hand-written small scenario is instant.
- Chapter 23: 43 scenarios, 4.85 s total (includes writing all eight
  renders to `out/` afterward). Per-render highlights: `fields_vs_paths`
  (200×200, three panels each doing Newton's method or a curve-distance
  field per pixel) is the slowest single render at 894 ms; `title` (eight
  glyphs baked at `bakeMtsdf`, four `draw_effect` passes) is 146 ms;
  `atlas_corners` (four bakes, one at `bake_msdf` size 32) is 91 ms;
  everything else is under 50 ms. The two scenarios that recompute several
  renders a second time for pixel probes ("what the renders show", "Plate
  23") are correspondingly the two slowest individual scenarios, at
  1.6-1.7 s each -- not a performance problem, just doubled-up render work
  from the scenario structure.
