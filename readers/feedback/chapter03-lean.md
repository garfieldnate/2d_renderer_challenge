# Chapter 3 — Lean reader feedback

Translated cold against the existing Lean chapter 1/2 code, working only inside the staged
scratch directory. Did not consult the book's own repository.

Before starting chapter 3, brought chapter 2 up to date: the staged code had only 28 of the 35
scenarios in the current `features/chapter02-*.feature` files. Added the seven missing ones
(coverage outside the buffer returning 0 on read, non-square `rasterize`/`rasterizeCenters`
buffers, an asymmetric-rectangle case for `rasterizeCenters`, P6 row order, P6 clamping, P6
bytes that look like whitespace, and `paint_through` forcing linear blending) and found one
real bug while doing it: `paintThrough` called `mix` without forcing the switch, so "The
arithmetic is on light, whatever the switch says" would have failed the moment linear blending
was off. Fixed by passing `(some true)` to `mix`. All 35 chapter-2 scenarios pass now.

## Ambiguities

- **`plot`'s linear-blending behavior isn't stated.** § 2.5 says `paint_through`'s mix is
  "forced to the light's way: `mix(pixel, color, coverage, true)`", explicitly. § 3.2 only says
  "you paint it: `mix(pixel_at(c, x, y), col, weight)`" — no mention of forcing. I implemented
  `plot` with the default `mix` (reads the global switch), which happens to match every scenario
  because no chapter-3 scenario ever turns the switch off. If the intent is "plot behaves like
  paint_through," a scenario should say so explicitly (see "Mistakes that stay green").

- **`thick_line`'s zero-length threshold.** The pseudo-code says `if length = 0`, and I used exact
  float equality (`len == 0.0`). Nothing pins whether a near-zero (but not exactly zero) segment
  should also become a square; the only scenario uses identical endpoints, which reach `len == 0`
  by construction on any reasonable implementation. Not a real ambiguity in practice, just an
  unexercised corner.

## Hard to translate

- **No `Int → Float` coercion in core Lean.** Every other numeric conversion in the existing code
  (`Nat → Float`) is free, but chapter 3's pixel coordinates are signed (`Int`, because Wu's
  "starts above the canvas" scenario needs negative `y`) and get mixed into float geometry
  constantly (`lineWu`, `thickLine`). Had to write `intToFloat` by hand
  (`if i < 0 then -(i.natAbs.toFloat) else i.natAbs.toFloat`). Every reader who reaches for a
  cast here will hit this the same way.
- **No `Float → Int` floor in core Lean either.** `Float.toInt64` truncates toward zero, not
  floor; `Float.floor` returns a `Float`. Getting the book's floor-not-truncate rule right meant
  chaining them: `(Float.floor x).toInt64.toInt`. Since they agree once the float is already an
  integer, this is safe, but it's an easy place to silently reach for `.toInt64` alone and get
  truncation instead — which is exactly the bug the chapter is warning about, just moved one
  layer down into "how does your language even floor a float into an integer."
- **`by` is a reserved word.** Writing `thick_line`'s four half-planes as `(ax, ay)` and
  `(bx, by)` — the natural transliteration of the book's own variable names — doesn't compile:
  `by` opens a tactic block in Lean. Renamed to `byy`. Cosmetic, but worth knowing before another
  Lean reader loses ten minutes to the same thing.
- **No `Float.pi` in core Lean.** Needed a literal constant for `ray_ends()`'s degree-to-radian
  conversion.

## Failures

None against the chapter itself once the code was right — every chapter-3 scenario passed on
first full run after fixing two compile errors (`Int.toFloat` doesn't exist; `by` as an
identifier). Those were caught by the compiler, not by a wrong scenario, so I don't count them
as chapter bugs. The one real bug found (`paintThrough` not forcing linear blending) was a
holdover from before chapter 2's feature files gained their forcing scenario, not something
chapter 3 introduced or should have caught.

## Mistakes that stay green

Deliberately mutated a correct implementation eight ways and reran the suite each time. All
eight were caught:

- **Bresenham `err` initialized to `0` instead of `dx / 2`:** 6 of 37 ch.3 scenarios fail
  (four `lit_pixels` scenarios plus Bresenham's fan plus Plate 3).
- **Tie rule `err <= 0` instead of `err < 0`:** 3 fail (the shallow line, the up-and-right line,
  and "at an exact half" — the scenario written specifically for the tie rule).
- **Steep swap forgotten (Bresenham):** 3 fail — but "The pixels don't depend on which end you
  start from" *passes*, because forgetting the steep swap breaks both directions of the same
  line identically. That scenario's job is symmetry, not correctness, and it does that job; the
  steep-line scenario itself is what actually catches this.
- **Wu weights swapped (`1 - f` and `f` reversed):** 9 fail, including total_ink and pixel-level
  checks across nearly every Wu scenario and both fan renders. About as thoroughly caught as a
  mistake can be.
- **Wu using `x.toInt64` (truncation) instead of `floor`:** exactly **1** scenario fails — "A
  line that starts above the canvas" — which is precisely the scenario the chapter says exists
  for this ("a scenario starts a line at row -1 to catch it"). Confirms the chapter's own claim
  about its coverage. The failure mode is worth noting too: with truncation, a negative `f`
  makes `1 - f` exceed 1, so `pixel_at` reports an out-of-gamut color like `(1.5, 1.5, 1.5)` —
  only visible before the PPM writer clamps it, which is exactly why `pixel_at` checks (not just
  `ppm_pixel`) matter here.
- **thick_line half-planes facing outward (all four normals flipped):** 11 fail — every
  `rasterize`/`ink` scenario in `chapter03-quad.feature` plus two fan renders, since the shape
  becomes empty everywhere.
- **thick_line built from pixel corners instead of pixel centers** (dropped the `+ 0.5`): 6 fail,
  including — by name — "An off-axis line runs through pixel centers, not corners," which exists
  for exactly this mistake and does catch it.
- **`lit_pixels` in column-major order:** 2 fail — "lit_pixels reads like a page" (written for
  exactly this) and, incidentally, "A line going up and to the right" (whose pixel list isn't
  monotonic in a way that survives the reorder). The other seven `lit_pixels`-based scenarios
  happen to list pixels that read the same in row-major or column-major order for that
  particular line, so they wouldn't have caught it alone.

One mistake that plausibly *would* stay green, not on the list above: **`plot` forcing linear
blending unconditionally**, the way `paintThrough` does, instead of reading the switch. No
chapter-3 scenario ever sets the switch off before a Wu line, so this alternative choice passes
every scenario as written, same as my choice not to force it. See "Ambiguities."

## Prose

- Genuinely good chapter. The load-bearing paragraph about the tie rule (`err < 0` vs `err <= 0`,
  round-the-half-down) told me exactly what to get right before I wrote a line of Bresenham, and
  the scenario ("At an exact half the line stays on its row one step longer") is a precise,
  minimal pin for it.
- Voice check (`grep -iwE 'simply|just|obviously|trivially|of course|clearly|we'` over the
  stripped text) comes back clean — no hits.
- All five pseudo-code blocks are well inside the 30-line budget (18, 13/14, 15, 7, 9 lines).
- **The fused-multiply-add trap did not manifest for Lean, on this machine.** Ran the "Except
  that the grid is blind along the diagonal" scenario (`thick_line(2, 2, 9, 9, 1)`,
  `ink(cov) = 9.71875`) exactly as written, on Apple Silicon (arm64 macOS), and it passed on the
  nose — no `9.65625`. Lean compiles through its C backend and apparently isn't inlining an FMA
  into `halfPlane`'s `(x - px) * nx + (y - py) * ny` under its default build flags, even on ARM.
  Worth being explicit in the trap box that this is a compiler-and-flags problem, not a
  language-or-platform one: a reader on the same chip in a language/toolchain that *does*
  contract by default would see the flipped sign, and one that doesn't (apparently Lean's
  default `leanc`/clang invocation) won't. As written the trap reads like it's about the CPU;
  it's about the compiler's contraction setting.
- Minor, not a bug: `ray_ends()`'s `round` is never exercised at an exact `.5` — every one of
  the twelve angles' `cos`/`sin` values lands away from a half-integer boundary before rounding
  (the nearest thing, `cos(60°) = 0.5` exactly, produces `80 + 72*0.5 = 116.0`, already whole).
  So a reader whose `round` picked a different tie-break (round-half-to-even vs round-half-away)
  would never be caught by this render. Given the geometry, that may be unavoidable without
  picking uglier angles, so I'm noting it rather than proposing a fix.

## Would change

- Add a scenario (even a small unit one, not a render) that pins whether `plot`'s mix respects
  or ignores the global linear-blending switch — currently unstated and untested, see
  Ambiguities.
- Consider naming the trap box's cause more precisely ("your compiler's default FMA contraction
  setting" rather than implying it's inherent to ARM), since it clearly depends on the toolchain
  and not just the chip, at least for Lean's default build.

## Results

- **Chapter 1:** 62/62 passed.
- **Chapter 2:** 35/35 passed (28 pre-existing + 7 added to match the current feature files, one
  real bug fixed: `paintThrough` now forces linear blending via `mix … (some true)`).
- **Chapter 3:** 37/37 passed, first try after fixing two compile errors (missing
  `Int → Float`/`Float → Int` coercions, and `by` as a reserved identifier).
- **Total: 134/134.**
- Clean build (`rm -rf .lake/build && lake build`): ~3.1s wall.
- `lake exe tests` (all 134 scenarios, including every render + reference diff): ~28.2s wall,
  almost entirely `fan_coverage`'s 20 million `inside` tests.
- `lake exe render`, `fan_coverage` alone (timed with `IO.monoMsNow`): **~25.3 seconds**. The
  book quotes "a quarter of a second on a JIT or in a compiled language" and "ten to twenty
  seconds in Python or Ruby" for this same workload — Lean, compiled, landed in the
  Python/Ruby bracket, not the compiled-language one. Likely cause: `Shape` is a struct wrapping
  a closure, and `thickLine` composes four more closures under `&&`, so every one of the 20
  million `inside` calls goes through several indirect calls instead of inlining into straight-
  line arithmetic. Correct, not fast; not fixed here since chapter 3 doesn't ask for speed and
  every pixel matches the reference exactly, but worth flagging before chapter 6 leans on the
  same rasterizer harder.
- All four chapter-3 renders (`fan-bresenham.ppm`, `fan-wu.ppm`, `fan-coverage.ppm`,
  `plate-03.ppm`) are byte-identical to `reference/chapter-03/`, not just within tolerance —
  same for all nine chapter 1/2 renders.
