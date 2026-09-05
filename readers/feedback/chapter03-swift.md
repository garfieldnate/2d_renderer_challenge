# Chapter 3 — Swift reader feedback

## Ambiguities

- **`ray_ends()` rounding tie-break.** The pseudo-code says `round(80 + 72 * cos(a))`
  without stating the tie-break for `.5`. I used Swift's `.rounded()` (half away from
  zero), matching the convention chapter 1 already established for `channelToByte`. None
  of the 12 fan angles actually lands on an exact `.5`, so this guess was never
  exercised — if a future chapter reuses `ray_ends()`-style rounding at an angle that
  does land on a half, the tie-break needs to be stated and pinned the way chapter 1
  pins `channelToByte`'s.
- **`thick_line` with `length` very small but not exactly zero.** The pseudo-code branches
  on `length = 0` (I implemented it as an exact `Double == 0.0` check, true only when both
  endpoints are the same integer pixel). No scenario exercises a segment that's short but
  nonzero, so a reader who computes `length` a different way (e.g. rounds it first) could
  pass every scenario with a slightly different degenerate-case boundary. Not a bug I hit,
  just an untested seam.
- **`plot`'s "skip a weight of zero" vs. the canvas's own out-of-bounds guard.** The prose
  says plot "also drops writes off the canvas and, as a shortcut rather than a rule, skips
  a weight of zero." `Canvas.writePixel` already silently drops out-of-bounds writes, but
  `Canvas.pixelAt` does **not** bounds-check (it indexes the array directly) — so `plot`
  has to guard bounds itself before calling `pixel_at`, or it crashes instead of no-oping,
  on the very scenario ("A line that starts above the canvas") built to test this. Worth
  being explicit in prose that `plot`'s guard is load-bearing precisely because `pixel_at`
  isn't safe to call out of bounds, unlike `write_pixel`.

## Hard to translate

- Comparing `lit_pixels(c) = [(x, y), ...]` needed a small custom helper (`eqPts`) because
  Swift tuples aren't `Equatable` by default. Not hard, just an extra few lines that a
  reader in a language with structural tuple equality (Python, Rust with derive, etc.)
  wouldn't need.
- Nothing else in chapter 3 was awkward in Swift. The four-half-plane `thick_line` maps
  onto the existing `Shape`/`inside` abstraction with zero friction — this is the payoff of
  chapter 2's "a shape is a question" design showing up again.

## Failures

None of my own translation attempts failed against the reference once I had the pseudo-code
right — all 37 chapter-3 scenarios passed on the first build. But confirming "chapters 1
and 2 pass" turned up a real gap that predates this round and is outside what I was asked
to fix, so I'm flagging it rather than burying it:

- **`features/chapter01-mix.feature` and `features/chapter01-ppm.feature` have scenarios
  that `Sources/Tests.swift` never translated.** Chapter 1's suite reports 59/59 passing,
  but that's 59 *translated* scenarios, not all scenarios in the current feature files.
  Missing from mix: "The light's way never clamps", "The switch can be passed instead of
  set" (a `mix(a, b, t, linear)` 4-arg overload doesn't exist in `Renderer.swift` at all),
  "The browser's way clamps each end before encoding it", "The ends of a mix are its inputs
  either way, when they're in range". Missing from ppm: "A line of exactly 70 characters is
  allowed", "Counting the distinct values in a file", "Files of different sizes are as
  different as it gets", "The same width with a different height is still a different
  size". I checked by hand: `mix()`'s browser-mode branch does **not** clamp before encoding
  (`let ea = encode(a), eb = encode(b)` with no `clamp01` first), so "The browser's way
  clamps each end before encoding it" would fail as written today. I did not fix this — it
  wasn't part of this round's brief (chapter 3 plus the seven named chapter-2 items) and
  chapter 3 never touches the linear-blending switch or out-of-range colors through `mix`,
  so it doesn't block anything here. But it means "chapter 1 passes" is true only in the
  narrow sense of "the tests that exist pass," which is exactly the kind of drift this book
  says it never wants. Recommend a lint that diffs `Scenario:` names in `features/*.feature`
  against what `Tests.swift` claims to cover, per chapter, before trusting a green run.

## Mistakes that stay green

I tried all eight suggested mistakes, one at a time, rebuilding and running the suite for
each, then reverted. All eight were caught — none passed the chapter-3 suite:

- **Bresenham `err` initialized to 0 instead of `dx / 2`:** caught, 6 failures (four line
  scenarios plus both fans in Plate 3).
- **Bresenham `err <= 0` instead of `err < 0`:** caught, 3 failures — exactly the tie-rule
  scenario plus the two others whose slopes cross a half. "At an exact half the line stays
  on its row one step longer" earns its name.
- **Steep swap forgotten (Bresenham):** caught, 3 failures, headlined by "A steep line steps
  along y" as advertised.
- **Wu weights swapped (`1 - f` and `f` reversed):** caught hard, 9 failures — every Wu
  scenario with an off-integer slope, plus Wu's fan and Plate 3.
- **Wu `Int(y)` (truncation) instead of `floor(y)`:** caught by exactly one scenario, "A
  line that starts above the canvas" — precisely the row -1 case the chapter calls out by
  name, and precisely the only case where truncation and floor disagree here (`y0 = -1`,
  slope positive, so `y` goes negative for the first couple of columns). No other scenario
  would have caught this; the chapter's own claim about this being "the port bug this
  chapter sees most" and needing its own targeted scenario checks out exactly.
- **`thick_line` half-planes all facing outward (normals negated):** caught overwhelmingly,
  11 failures — inverting all four turns the rectangle into (essentially) its own
  complement, so nearly every coverage scenario disagrees.
- **`thick_line` built from pixel corners instead of centers:** caught, 6 failures. As the
  chapter predicts, the axis-aligned "ink is the length" outline and the diagonal "grid is
  blind" scenario both still pass (a whole-pixel shift doesn't change total length-derived
  ink for those specific inputs) — it's "An off-axis line runs through pixel centers, not
  corners" plus the coverage-value scenarios that catch it, exactly as advertised.
- **`lit_pixels` in column-major order:** caught by exactly two scenarios — "lit_pixels
  reads like a page" (built for this) and "A line going up and to the right" (whose
  reading-order is non-monotonic in a way column-major order gets wrong).

No mistake from the list survived. This is a well-pinned chapter.

## Prose

- **The FMA trap box, checked against `swiftc -O` on arm64:** the "Except that the grid is
  blind along the diagonal" scenario (expecting `ink(cov) = 9.71875` exactly) passed as
  written, first try, with `swiftc -O` on Apple Silicon (Swift 6.0.3, arm64-apple-macosx15).
  So the trap as described (ARM C/C++ compilers fusing multiply-adds by default and flipping
  an exact-zero dot product to `-5e-17`) does **not** bite this Swift toolchain — either
  because `swiftc` doesn't contract floating-point multiply-adds by default the way a C
  compiler does, or because the particular expression shape in `halfPlane`'s dot product
  didn't get fused here. Worth a one-line note in the trap box itself: this is a real,
  compiler- and flag-dependent hazard for C/C++ and maybe others, but Swift readers
  shouldn't expect to reproduce it just by using `-O`, and the box currently reads as if
  every optimizing compiler does this.
- **The `fan_coverage()` timing claim is generous for a compiled language.** The chapter
  says "a quarter of a second on a JIT or in a compiled language." Standalone (not
  interleaved with other test timings), `fan_coverage()` took **0.020s** here — better than
  10x faster than the quarter-second figure. Not wrong, since the number's presumably meant
  as a worst-case compiled-language anchor next to "ten to twenty seconds in Python or
  Ruby," but a reader timing their own Swift/C/Rust port and seeing 20ms might reasonably
  wonder if they missed the point of the section (that it's slow *relative to Bresenham*,
  not slow in absolute terms). A range, or an explicit "this varies a lot by language and
  hardware," would head that off.

## Would change

- Ship (or point to) a scenario-name-diff lint between `features/*.feature` and
  `Sources/Tests.swift` per chapter, run as part of `./build.sh` or a `--check` step. The
  chapter-1 drift above would have been caught immediately instead of by hand-auditing.
- State the `ray_ends()` rounding tie-break explicitly in prose (even though no current
  angle exercises it), since the book is otherwise careful to pin every rounding mode.
- Soften the "a quarter of a second" framing for `fan_coverage()`'s timing, or give a
  wider range, since native/compiled numbers can come in an order of magnitude under that.

## Results

- Build: `swiftc -O` (Swift 6.0.3, arm64-apple-macosx15, plain `swiftc`, no SwiftPM).
- Chapter 1: 59/59 passing (as translated; see Failures above for scenarios in
  `features/chapter01-{mix,ppm}.feature` that were never translated and would not all
  pass as-is).
- Chapter 2: 35/35 passing, up from 28 — added the 7 named catch-up scenarios (buffer
  need-not-be-square for both `rasterize_centers` and `rasterize`, the asymmetric
  rectangle-by-centers scenario, the "not at least half" center-question scenario, P6 row
  order, P6 clamping, P6 whitespace-byte pixels, and `paint_through` forcing linear
  blending). Fixed a real bug in the process: `paintThrough` was calling the
  switch-respecting `mix()`, so with `linearBlending = false` it silently did browser-style
  math; it now always mixes in linear light directly, per § 2.5.
- Chapter 3: 37/37 passing, all new. `out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
  `out/fan-coverage.ppm` and `out/plate-03.ppm` are byte-identical
  (`max_channel_difference = 0`) to `reference/chapter-03/`.
- Full suite: 131/131 passing in 0.56s (`-O`); slowest chapter-3 scenario is "The fan as
  twelve thin rectangles" at ~31ms (image-diff overhead, not the render itself).
- `fan_coverage()` timed standalone (12 rasterizations of a 160x160 canvas at 64
  samples/pixel): **0.020s**.
- Broke-the-suite round: all 8 suggested mistakes (Bresenham `err` init, Bresenham tie
  rule, steep swap, Wu weight swap, Wu floor-vs-truncate, thick_line outward normals,
  thick_line from corners, lit_pixels column-major) were caught by the existing scenarios.
  None stayed green.
