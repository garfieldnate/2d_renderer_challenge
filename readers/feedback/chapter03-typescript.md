# Chapter 3 — reader's feedback (TypeScript / Deno)

31 new scenarios, all green on the first run, both renders byte-identical to
`reference/chapter-03/`. That is a well-pinned chapter, and it also means the
scenarios never told me anything — so most of what follows comes from the 45
mutations I ran against them.

## Ambiguities

- **"`err ← dx / 2` // integer division"** and *"The tie rule falls out of
  `err ← dx / 2` with integer division."* I used `Math.floor(dx / 2)`. But the
  integer division is **not** what pins the tie rule. With integer `dx`/`dy` and
  the test `err < 0`, plain real division is *exactly* equivalent: when `dx` is
  odd every `err` is offset by +0.5, and `err_int < 0 ⟺ err_int + 0.5 < 0` for
  integers. I mutated it to `dx / 2` (real) and all 119 scenarios still pass.
  What actually pins the tie rule is **floor vs. ceil** (`Math.ceil(dx/2)` fails
  2 scenarios) and **`< 0` vs. `<= 0`** (fails 3). Worth rewording — a reader
  who takes the sentence at face value will look for the wrong thing.
- **"`lit_pixels(c)` returns every pixel of the canvas that isn't black."**
  Exact `!== 0` on all three channels, or `color_eq` against black with the
  chapter-1 epsilon? I used exact. It happens not to matter (every weight in the
  chapter is an exact half, third, or seventh), but it will matter the moment a
  weight comes out as 1e-17. Also: `lit_pixels` is only meaningful on a canvas
  that was never `fill`ed, which the chapter never says — on the fan, everything
  is lit.
- **"`plot(...)` ... also drops writes off the canvas and skips a weight of
  zero."** I implemented the skip, but it is a no-op: `mix(a, b, 0)` returns `a`
  bit-for-bit. Removing it changes nothing and no scenario notices. If it's
  meant as a performance note, say so; as written it reads like correctness.
- **`thick_line(..., width)`.** I read "offset by half the width along `n`,
  facing inward" as two planes at `±width/2` with normals `∓n`. The text names
  only one offset direction and leaves the mirror implicit. Every scenario uses
  `width = 1`, so this guess is untested (see below).
- **`ray_ends()` — "round"**. Half-way ties and negative arguments are
  unspecified. No endpoint here lands on a `.5`, so JS `Math.round`, C `round`,
  and Python's banker's `round` all agree by luck. Fine, but say it's luck.
- **`fan_coverage` — "rasterized and painted through in turn."** I called
  `paint_through` once per ray, so the twelve rays double-paint where they meet
  at the center and saturate. That is what the pseudocode says and what the
  reference file contains (I checked: byte-identical). An accumulate-then-paint
  reading gives a visibly grayer hub, and the scenario's `ppm_pixel(p6, 160,
  160)` probe catches it — good, but the prose could say "in turn" means
  "twelve separate paints".

## Hard to translate

Very little. Shipping complete pseudocode for both algorithms made this the
easiest chapter to date.

- `lit_pixels(c1) = lit_pixels(c2)` needed a list-of-pairs comparator that
  reports both lists on failure; the earlier chapters had nothing like it.
- `inside(s, 2.5, 1.0) = true` is exact-float equality on a half-plane boundary.
  It works because an axis-aligned line makes the dot product exactly `0.0`.
  The same assertion on a slanted line would be a coin flip, and the chapter
  doesn't warn that the "boundary included" rule is only reliable when the
  arithmetic is exact.
- `Scenario Outline` rows became one `Deno.test` each, as in chapters 1–2.
- The diagonal scenario asserts the same value twice:
  `ink(cov) = 9.7188` **and** `ink(cov) = 9.8995 ± 0.25`. The second cannot fail
  if the first passes. It's a comment written as a test.

## Failures

None. Every scenario passed on the first run; `out/fan-coverage.ppm` and
`out/plate-03.ppm` are `cmp`-identical to the reference files. Chapters 1–2
still pass unchanged (88/88).

## Mistakes that stay green

45 mutations, 38 caught, 7 green. Four of the seven are provably equivalent
(harmless); three are real bugs the chapter cannot see.

**Real bugs that pass all 119 scenarios:**

1. **`floor` → `trunc` in Wu.** This is the single most likely port bug — it's
   what you get from `int(y)` in Python, `(int)y` in C, `y as i32` in Rust, or
   `y | 0` in JS. No chapter-3 scenario has a negative coordinate, so `y` is
   never below zero and the two agree everywhere. It is a visible bug:
   `line_wu(c, 0, -1, 8, 3, white)` gives `pixel_at(c, 1, 0).red = 0.5` with
   floor and `1.5` with trunc — an over-bright pixel and a *negative* weight on
   the row below. **One scenario with a negative endpoint kills this.**
2. **`thick_line` ignoring its `width` argument** (hard-coding half-width 0.5).
   All seven quad scenarios pass `width = 1`. The parameter is decorative as
   far as the suite is concerned.
3. **Dropping the `dx = 0 ? 0` guard on Wu's slope.** Bresenham gets an explicit
   "A line of one point" scenario; Wu gets none, so `line_wu(c, 3, 3, 3, 3, …)`
   is never called and the `0/0 → NaN` path is never entered.

**Equivalent mutants (not gaps, just noise I checked):** `err = dx/2` in real
arithmetic (see Ambiguities); removing `plot`'s skip-zero; `total_ink` summing
green instead of red; `lit_pixels` testing only red. All four are safe *because*
the chapter only ever draws white on black — which is fine, but means the
helpers are less pinned than they look.

**Caught, but by a single thread:**

- `lit_pixels` in **column-major** order is caught by exactly one scenario,
  "A line going up and to the right" — the only expected list that isn't already
  sorted by x. Delete that one scenario and reading order goes untested.
- The **left-to-right swap** (Bresenham and Wu) is caught only by the matching
  "which end you start from" scenario plus the plate reference. Deliberate and
  well done, but there's no slack.
- **Plate halves swapped** is caught only by Plate 3's own probes/reference.

Everything else died loudly: err init 0 (5 fails), err init dx (7), ceil (2),
`<= 0` (3), steep swap forgotten (2), steep not swapped back (2), endpoints
exclusive at either end (8 and 10), `ystep` reversed (7), `dy` not absolute (2),
`err += dy` (6), write-after-step (6), Wu weights swapped (7), round (4), ceil
(5), only the nearer pixel (5), Wu steep swap forgotten (5), plot ignoring the
weight (7), plot mixing backwards (11), side half-planes outward (8), corners
instead of centers (3), full width per side (8), end caps reversed (8),
direction not normalized (8), caps dropped (6), `total_ink` over all three
channels (9), ray_ends truncating (3), degrees as radians (5), `k in 1..12` (1 —
correctly, since 360° ≡ 0° and the picture is unchanged), fan without magnify
(1), accumulate-instead-of-paint-in-turn (1).

## Prose

Clear and well ordered; §3.1 → §3.2 → the reveal in §3.3 is the best-structured
argument in the book so far. The numbers:

| claim | measured | verdict |
| --- | --- | --- |
| "18% less paint" | Wu ink 11 vs 9 → 18.2% less | ✅ |
| "comes out at 9.72" | `ink = 9.71875` | ✅ |
| "the 45° line of length 9.9" | `hypot(7,7) = 9.8995` | ✅ |
| "off by nearly 2%" | 1.83% | ✅ |
| "twenty million inside tests" | 12 × 160 × 160 × 64 = 19,660,800 | ✅ |
| "at 30° the line rises 0.577 pixels per column" | tan 30° = 0.5774 | ✅ |
| **"twenty seconds"** | **284 ms** | ❌ off by 70× |

The twenty seconds is the problem, and it's load-bearing: it's the chapter's
opening hook ("It takes twenty seconds to draw twelve of them"), it's the
Figure 3.4 caption, and §3.3 ends with *"Then go back and look at the speed,
because that's the actual lesson of this chapter."* In Deno, `fan_coverage()`
takes 284 ms; the whole render script, all eleven pictures from three chapters,
takes 0.52 s. A reader on any JIT — JS, Java, C#, JVM/CLR anything — never feels
the pain the chapter is built around, and the conclusion ("the way out isn't a
faster line algorithm, it's a faster rasterizer") arrives unmotivated. The
operation count is the honest, portable version of the claim; the wall clock
isn't. Suggest: "twenty million `inside` tests — twenty seconds in CPython,
a quarter of a second on a JIT, and still a thousand times more work than
Bresenham does."

Smaller notes:

- *"Wu's algorithm is computing the coverage of a thin rectangle, badly, one
  column at a time. The **less** is the 18%."* The italic "less" is a callback
  to "18% less paint" two paragraphs earlier, but sitting one word after
  "badly" it reads as a typo for "the *badly* is the 18%". I read it three
  times. Worth a rewrite.
- Missing: nothing tells the reader what a zero-length Wu line should do. The
  `dx = 0 ? 0` guard in the pseudocode is the only hint, and there's no
  scenario, even though Bresenham gets one.
- Missing: whether `plot` should clamp the weight, or the result. It doesn't
  matter with integer endpoints, but §3.3 reframes the weights as coverage, and
  coverage clamps — a reader may reasonably wonder.
- Small friction: `fan_wu` is described as "`fan_bresenham` with `line_wu` in
  place of `line_bresenham` and nothing else changed", and then `plate_03` needs
  both, so you either duplicate the body or factor out a helper the book never
  mentions. I duplicated, to keep the code matching the page.
- The claim "For Wu it's always the number of columns" holds and is a genuinely
  nice hinge into §3.3 — the reader can predict the 11-vs-9 outline result
  before reading it.

## Would change

1. Add one Wu scenario with a negative endpoint. `line_wu(c, 0, -1, 8, 3,
   color(1,1,1))` → `pixel_at(c, 1, 0) = color(0.5, 0.5, 0.5)`,
   `total_ink(c) = 7.5`. Two lines, and it kills the most likely port bug in
   the chapter.
2. Add one `thick_line` scenario with `width ≠ 1` — e.g.
   `thick_line(0, 3, 7, 3, 3)` with `ink(cov) = 21` — so the parameter is
   tested at all.
3. Add "A Wu line of one point", mirroring Bresenham's.
4. Add a second Bresenham scenario whose expected list isn't sorted by x, so
   reading order isn't carried by one scenario.
5. Fix the twenty seconds, or phrase it in operations.
6. Drop the `9.8995 ± 0.25` companion assertion, or make it a comment. It
   cannot fail independently of the line above it.
7. Reword the "integer division" sentence: floor-vs-ceil is the tie rule, not
   int-vs-float.

## Results

- **119 passed / 0 failed** (`deno test --allow-read`, 1.7 s wall).
  - chapters 1–2: 88 (unchanged)
  - chapter 3: 31 — bresenham 9, wu 10, quad 7, plate 5
- **Renders:** `out/fan-coverage.ppm` and `out/plate-03.ppm`, both `cmp`-clean
  against `reference/chapter-03/`. Full render script: 0.52 s for 11 files.
- **Time hotspots:** "The fan as twelve thin rectangles" 284 ms and chapter 2's
  "The plate" 275 ms are the only tests over 60 ms; together they are a third of
  the suite. Everything else in chapter 3 is sub-millisecond — Bresenham and Wu
  are as fast as advertised, and the supersampled rectangle is 300× slower for
  twelve short lines.
- **Mutations:** 45 run, 38 caught, 7 green (3 real bugs, 4 equivalent).
