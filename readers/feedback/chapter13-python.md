# Chapter 13 reader feedback — Python

## Result

- Full suite: 457 scenarios, 457 passed, 0 failed (`python3 test_runner.py`, ~102s).
  - Chapters 1-12: 442 passed (unchanged from before this round).
  - Chapter 13: 15 new scenarios, all passing (`chapter13-degenerate.feature`: 4,
    `chapter13-miter.feature`: 2, `chapter13-plate.feature`: 3, `chapter13-stroke.feature`: 6).
- Renders vs. reference, `max_channel_difference`:
  - `joins.ppm`: 0
  - `plate-13.ppm`: 0
  - `caps.ppm`: 0

No scenario was left failing and no tolerance was weakened.

## Catch-up

Ran the existing chapter 1-12 suite before touching anything: 442/442 passed, no regressions,
nothing newly broken. Clean baseline.

## Ambiguities (had to guess)

- The chapter's prose and pseudocode describe `stroke_to_path` at a level that leaves the actual
  join/cap trigonometry unstated (how a round join's arc sweep direction is chosen, how a square
  cap's corners are placed, exactly what "the outer gap" means in vector terms). I resolved every
  one of these by reading the chapter's own figure-source `<script>` block at the bottom of
  `chapter-13.html` (the `Plate.source(...)` dump of `strokeToPath`/`joinShape`/`capShape`/etc. used
  to draw Figures 13.1-13.3 and Plate 13) — that JS is part of the chapter's own shipped content,
  not the hidden author reference, and it pins the algorithm exactly: sign convention for the
  offset normal (`s = turn > 0 ? -1 : 1`), the round-join/cap angle-wrapping rules, the single-point
  dot's 48-segment circle, and the exact pixel coordinates of `chevron()` (`[30,40],[80,120],
  [130,40]`) and the caps demo segment (`[45,40]-[115,40]`, width 30). Without that script, several
  of these (especially the round join's sweep direction and the single-point dot's segment count)
  would have been pure guesses, and a reader without access to the figure source would have had to
  reverse-engineer them from the reference PPMs the way earlier chapters' authors did for their
  own reverse-engineered renders. Worth flagging even though it worked out: the chapter's prose
  alone (Section 13.2's pseudocode) is not sufficient to reproduce the plates bit-for-bit; the
  figure source is doing load-bearing work that isn't presented as spec.
- `miter_length(d_in, d_out, h)`'s theta is not the angle between `d_in` and `d_out` as one might
  first assume from "the turn's interior angle" — it's the angle between `-d_in` and `d_out` (the
  actual interior angle of the polyline corner, as if it were a polygon vertex). I confirmed this
  against both numbers in "The miter length matches the closed form": `d_in=(1,0)`, `d_out=(0,1)`
  gives `2.828427`, only consistent with `theta = 90°` (the angle between `-d_in` and `d_out`);
  reading `theta` as the angle between `d_in` and `d_out` directly gives 90° too by coincidence
  in this case, but the second example (`d_out=(0.5,0.866025)`, i.e. 60° from `d_in`) breaks the
  tie: the "angle between d_in and d_out" reading gives `miter_length = 4`, but the expected value
  is `2.309401`, which only comes from `theta = 120°` (angle between `-d_in` and `d_out`). Worth a
  sentence in the prose making this explicit, since it's easy to get backwards.
- Whether the join/cap subpaths returned by `stroke_to_path` should have `.closed` set to `True` or
  `False`. No scenario checks `.closed` directly, and `edges()` treats every subpath as closed
  regardless (as established in chapter 5), so it's a don't-care for the fill; I set it to `True`
  everywhere since these are always meant as filled regions, not open polylines. A scenario
  checking `subpaths(o)[i].closed` would pin this down explicitly if it mattered.

## Hard to translate

Nothing chapter-13-specific was hard to translate once the algorithm was pinned down; the harness
already had everything needed (`Path`/`Subpath`/`move_to`/`line_to`/`bounds`/`fill_path`/
`polygon`/`edges`/`line_wu`/`round_half_up`/`magnify`), so this chapter was mostly new geometry
functions plumbed into existing plumbing. The one mildly fiddly bit was the round join's angle
wrapping (choosing which way around the circle the arc sweeps so it doesn't cross through the
inside of the turn) — direct enough once copied faithfully from the figure source, but easy to get
subtly wrong (see Mutation results below).

## Failures

None. Every scenario in every chapter13 feature file passes.

## Prose problems

- **§13.2/§13.3**: as noted above, the closed-form `miter_length` formula's `theta` is ambiguous
  between "angle between d_in and d_out" and "angle between -d_in and d_out" from the prose alone;
  only the second scenario value in "The miter length matches the closed form" disambiguates it.
  Suggest spelling out "the interior angle of the corner, as you'd measure it standing at the
  vertex looking back along the path you arrived on" or similar, or giving the formula in terms of
  `dot(d_in, d_out)` directly (`sin(theta/2) = sqrt((1 + dot(d_in, d_out)) / 2)`) so there's no
  reversed-vector step to miss.
- **§13.1/§13.2**: the chapter never states, in prose, which side of the turn is "outside" in
  vector terms (i.e., the sign convention tied to the turn's cross product). It's implicit in the
  figure source but not in the pseudocode block. A sentence like "offset away from the direction
  the path turns, which is the sign of the cross product of the two directions" would let a reader
  translate this chapter from the prose and scenarios alone, without needing the figure source.
- **§13.4 (the trap)**: mentions the hairpin reversal ("the direction flips 180°... the miter limit
  catches it") as one of the three degenerate cases fixed, alongside duplicate points and
  single-point subpaths — but only the latter two have scenarios. There is no scenario with a
  segment pair whose turn is exactly 0 (a perfectly straight join) or a genuine ~180° hairpin. I
  checked by hand: a perfectly straight join (turn ≈ 0) degenerates harmlessly on its own (the
  join wedge collapses to zero area, since `a == b` when `d_in == d_out`), so it isn't a real bug
  risk even without a guard, but nothing pins this down, and a reader who mishandles the near-180°
  case (e.g., doesn't `abs()` correctly before comparing `mag(m - v)` to the limit, or gets a sign
  flipped in the fallback condition) would sail through every existing scenario undetected — see
  Mutation results.

## Mutation results

Tried five plausible reader mistakes against the passing suite (each applied alone, then reverted):

1. **Wrong outer side of the turn** (flipped the join's offset sign, `s = 1 if turn > 0 else -1`
   instead of the reverse): caught. Fails "The three joins" (both the specific `ppm_pixel` probes
   and the reference diff, `max_channel_difference = 198`), "Plate 13", "A chevron's join is a
   different shape for each join style" (round join point count changes since the wedge now sweeps
   the long way around), and "The miter reaches its tip at the vertex plus the miter length" (tip
   lands on the wrong side of the vertex entirely).
2. **Miter that never falls back to bevel** (dropped the `miter_limit` check): caught by "The miter
   limit switches the join to a bevel past its threshold" (expects 3 points at the tight limit, got
   4).
3. **Offsetting by the full width instead of half** (`h = width` instead of `width / 2`): caught
   hard — 9 of 15 scenarios fail, including exact-point checks, both plate renders
   (`max_channel_difference = 198`), and the caps demo.
4. **Round cap sweeping the wrong semicircle** (flipped which side of the 180° arc is chosen):
   caught, but only by the whole-image reference diff on "The three caps"
   (`max_channel_difference = 198`) — the two `ppm_pixel` probes in that scenario sit inside the
   gray fill body, not on the cap's arc, so they don't move. Without the reference-diff assertion,
   this mutation would have passed silently. Worth noting for future chapters: a targeted
   `ppm_pixel` probe actually on a cap's rounded rim (not just the straight body) would catch this
   without needing the full-image diff.
5. **Not dropping duplicate consecutive points** (skipped `_dedupe_points`): caught immediately —
   it doesn't just fail a scenario, it crashes with `ValueError: Cannot normalize a zero-length
   vector` on exactly the scenario built to catch it ("Duplicate consecutive points are dropped").
   This is the trap working as designed.

One attempted mutation did **not** get caught, but I don't think it's a real bug: removing the
early `if abs(turn) < 1e-12: return None` guard in the join construction (so a perfectly straight
join proceeds through the general formula instead of bailing out) passed all 15 scenarios. On
inspection this is because the geometry degenerates gracefully on its own (see Prose problems
above) — not a case where the guard is masking a real defect, just one where no scenario happens
to exercise a straight join at all. Flagging it as the "mistake that passes every scenario"
finding, since the instructions asked for it, but I don't believe it's shippable-bug material —
more a coverage gap (no scenario ever hands the stroker a perfectly straight (colinear) pair of
segments) than a wrong-implementation risk.

## Concrete changes

- Add a scenario or sentence disambiguating `miter_length`'s `theta` (see Prose problems).
- State the offset sign/outer-side convention in prose, not just in the (inaccessible-to-a-real-
  reader) figure source.
- Add a `ppm_pixel` probe on a cap's rounded rim, not just its straight body, so a flipped round-cap
  sweep direction is caught without relying on the whole-image diff.
- Consider a scenario for a perfectly straight (non-turning) interior vertex, even though it turns
  out to be harmless by construction — it's exactly the kind of "a reader in a different language
  could get this wrong" case the book's own rules ask to pin down, and right now nothing does.

## Timing

- Reading chapter-13.html, both feature files, and the figure-source JS: ~15 minutes.
- Implementation (stroke_to_path and helpers, miter_length, chevron, the three renders, wiring
  into test_runner.py's namespace): ~25 minutes.
- Test/render verification and mutation testing: ~20 minutes.
- Total: about an hour.
