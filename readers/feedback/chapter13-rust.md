# Chapter 13 — Rust reader feedback

## Result

- 15 new scenarios, all translated and passing: `chapter13-stroke.feature`
  (6, one `Scenario Outline` expanded into 3 macro-generated tests),
  `chapter13-miter.feature` (2), `chapter13-degenerate.feature` (4),
  `chapter13-plate.feature` (3).
- Full suite, chapters 1-13: 418 tests, 0 failed (whole run ~1.2s release).
- Renders, `max_channel_difference` against `reference/chapter-13/`:
  - `joins.ppm` — **0**
  - `caps.ppm` — **0**
  - `plate-13.ppm` — **0**
  All three diff exactly 0, not merely within the `<= 1` the scenarios ask
  for.
- Nothing left failing. No scenario needed weakening or skipping.

## Catch-up

Ran the existing chapters 1-12 suite before touching anything: 403 tests
(418 total minus the 15 new ones), all green, no regressions from the
prior round's code. Nothing newly broken.

## Ambiguities

- The chapter's pseudocode (§13.2) says "for each interior vertex: emit
  join(...)" and "if subpath is open: emit cap at each end," but never
  says what to do with a *closed* subpath under `stroke_to_path` — does
  the last point join back to the first with its own wedge, and are caps
  skipped entirely? No scenario exercises a closed subpath through
  `stroke_to_path` at all (the miter feature's "closed form" scenario
  is about the closed-form *equation*, not a closed *path*). I
  implemented the natural generalization (wrap segment + join at the
  seam, no caps) by reading the chapter's own reference JS, which the
  chapter prints in full as its figure/plate source — but the JS's
  `strokeToPath` takes an explicit `closed` boolean on a raw point array,
  which sidesteps the question of what a `Path`'s own `.closed` flag
  means to the stroker. This is a real gap: a reader without access to
  that JS (or reading less carefully) has no scenario forcing them one
  way or the other. **Fix**: add a scenario stroking a closed triangle
  and pinning subpath/point counts, the same way the open-chevron
  scenarios do.
- The public `miter_length(d_in, d_out, h)` scenario gives `d_in`/`d_out`
  as if they were two path segment directions, but doesn't say in prose
  which angle `theta` is — "the turn's interior angle" is used, but the
  natural reading of "the angle between `d_in` and `d_out`" (both taken
  as forward directions) gives a *different* number than the one the
  scenario pins. I had to reverse-engineer that `theta` is actually the
  angle between *`-d_in`* and `d_out` (the angle you'd measure standing
  at the vertex, looking back the way you came and ahead to where you're
  going) by solving the two closed-form examples by hand. Once found, it
  matched the chevron's actual miter tip distance exactly, which is
  reassuring, but the prose doesn't spell out the reversal and a reader
  could easily build the "obvious" (unreversed) version, get numbers
  that are wrong by a supplementary angle, and not know why. **Fix**: say
  in §13.3, "the angle between the reversed incoming direction and the
  outgoing one" or show the vertex-diagram with the angle marked.

## Hard to translate

- Nothing especially hard mechanically — `Tuple`'s `point + vector =
  point` and `vector * scalar = vector` arithmetic (established since
  chapter 4) made every offset computation (`v + n * h`) a one-liner with
  no new helper types needed. The trickiest part was translating the
  round cap's sweep-direction logic (`((outw - a0) % 2pi + 2pi) % 2pi`,
  then re-fold into `(-pi, pi]`, then pick `+-pi`) faithfully rather than
  "simplifying" it — see Mutation results below for why that logic is
  exactly as fiddly as it looks and worth keeping intact.
- Scenario Outline translation used this project's existing
  `macro_rules!` convention (see `tests/wu.rs`'s `ink_case!`) rather than
  a runtime loop, so each Examples row is its own named `#[test]` and
  fails individually and legibly.

## Failures

None. Every scenario passed on the first implementation that matched the
chapter's own reference JS (embedded as the plate's figure source) byte
for byte in geometry, so there was nothing to debug against a reference
render — the diffs were 0 from the first `cargo test` run.

## Prose problems

- **§13.2** (the `stroke_to_path` pseudocode): doesn't say what a closed
  subpath does. See Ambiguities above.
- **§13.3** (the miter length): `theta` is called "the turn's interior
  angle" without saying which two rays that angle is between. See
  Ambiguities above — the formula is right, the words under-specify it.
- Everything else — the six-shapes framing in §13.1, the degenerate-input
  trap in §13.4, the plate's construction in §13.5 — was unambiguous
  enough to implement directly from prose plus scenario plus the printed
  JS source, no guessing required.

## Mutation results

Five deliberate bugs, introduced one at a time in `src/lib.rs`, tested,
and reverted. All five were caught by at least one scenario; **none
survived**.

1. **Wrong outer side of a join** (flipped the `s = turn > 0.0 ? -1 : 1`
   sign in `join_shape`). NOT caught by the join-style-per-shape
   scenario or the miter-limit scenario, both of which only pin *point
   counts* (a mirrored wedge has the same point count as the correct
   one). Caught by: the miter's own tip-position scenario (the tip lands
   on the wrong side, at the wrong y), the round join's point-count
   scenario (the mirrored sweep angle needs a different number of arc
   steps, so even the count differs), and both plate reference diffs
   (`joins.ppm`, `plate-13.ppm`).
2. **Miter that never falls back to a bevel** (dropped the
   `miter_limit` check entirely). Caught immediately by
   `chapter13-miter.feature`'s own bevel-fallback scenario, which exists
   for exactly this.
3. **Offset by the full width instead of half** (`let h = width;` in
   `stroke_to_path`). Caught immediately and by nearly everything — every
   degenerate-case scenario, since even a single point's dot/square
   bounds double.
4. **Round cap swept through the wrong semicircle** (flipped the
   `d > 0.0 ? +-pi` branch in `cap_shape`'s round case). NOT caught by
   any unit scenario — nothing in `chapter13-degenerate.feature` or
   `chapter13-stroke.feature` pins a cap's own geometry directly (the
   single-point round-cap scenario uses a full-circle arc in a different
   code path, unaffected). Caught by: the caps render's reference diff
   (`caps.ppm`) — the bulge now faces into the shaft instead of away from
   it, changing pixels at the cap's tip.
5. **Skipped `dedupe_points` entirely** (used the raw, undeduped point
   list). Caught immediately: a doubled point makes a zero-length
   segment whose direction is `0/0` (NaN), and the duplicate-points
   scenario's subpath/point assertions fail once NaNs propagate through
   the rest of the geometry.

Two of the five (1 and 4) were caught **only** by a render's
`max_channel_difference`, not by any unit scenario — the strongest
argument in this chapter for pinning every render exactly rather than
trusting point-count scenarios alone. A join or cap's precise outward
geometry is only checked end to end there.

## Concrete changes

1. §13.3: state explicitly which angle `theta` is measured between (the
   reversed incoming direction and the outgoing one), not just "the
   turn's interior angle."
2. §13.2 (or a new short paragraph): say what `stroke_to_path` does with
   a closed subpath — does it join the wrap-around seam and skip caps?
   — and add a scenario stroking a closed triangle to pin it, the same
   way the open chevron pins the open case.
3. Consider a scenario that would have caught mutation 1 or 4 without
   needing the full render diff — e.g. pinning one coordinate of the
   bevel join's `a`/`b` points (not just their count), or a bounds check
   on `caps_demo`'s round-cap panel that would shift if the semicircle
   swept the wrong way. Not strictly necessary (the render diffs do
   catch both), but it would let a reader debug a wrong-side join without
   staring at 160x160 pixels.

## Timing

Implementing chapter 13 end to end — reading the chapter and all four
feature files, writing `stroke_to_path`/`miter_length`/`chevron`/
`joins_plate`/`plate_13`/`caps_demo` in `src/lib.rs`, four new test files,
wiring `render_all.rs`, verifying all three renders diff 0, and running
five mutation-testing rounds — took about one working session with no
back-and-forth debugging: every scenario passed on the first
implementation attempt, and every render diffed 0 immediately, because
the chapter prints its own reference JS as the figure/plate source and
translating it faithfully (rather than reimplementing from the prose
alone) removed nearly all of the guesswork. The only real time sink was
reverse-engineering the `miter_length` angle convention (see Ambiguities)
by solving the two closed-form scenario numbers by hand before writing
any code.
