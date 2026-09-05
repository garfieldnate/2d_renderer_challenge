# Chapter 3 — reader's feedback

C11, clang 17 on arm64 macOS. Chapters 1 and 2 were already here and untouched
except for one struct field and one `case`.

## Ambiguities

**"err ← dx / 2 // integer division"** — clear, but the chapter never says what
type `err` is afterwards. A reader who writes `err ← dx / 2.0` and keeps
everything else in floating point passes all nine Bresenham scenarios *and*
reproduces plate-03 byte for byte. That one is actually provably equivalent
(for odd `dx` the real `err` is always exactly the integer one plus 0.5, and the
`err < 0` test can never separate `e` from `e + 0.5` when `e` is an integer), so
no harm done — but the prose makes it sound load-bearing when it isn't. The
load-bearing part is `dx / 2` versus `0` or `dx`, and that *is* caught.

**"thick_line(x0, y0, x1, y1, width)"** — `width` is a parameter of the function
and of nothing else in the chapter. Every scenario passes 1. I guessed
"half-width = width / 2 measured perpendicular from the centerline", which the
prose does say ("offset by half the width along n"), but nothing tests it: see
Mistakes that stay green.

**`ray_ends` rounding.** "round(80 + 72 * cos(a))" doesn't say which way ties go.
I used C's `lround` (half away from zero). No endpoint lands on a tie for these
twelve angles, so it doesn't matter, but the scenario would not have told me.

**`plot(c, x, y, col, weight)` "also drops writes off the canvas and skips a
weight of zero".** Both are no-ops given chapter 1: `write_pixel` already drops
out-of-bounds writes, and `mix(a, b, 0)` returns `a` bit-exactly. So the
sentence describes belt-and-braces, not behaviour, and I couldn't tell whether
it was meant to matter. It doesn't — deleting the zero-skip changes nothing.

**`lit_pixels` "every pixel that isn't black".** Exactly black, or
black-within-tolerance? I used exactly. It matters more than it looks: Wu's
`y0 + (x - x0) * slope` for a slope of 1/3 gives `1.9999999999999998` at one
step, so one pixel gets weight `2.2e-16` and becomes technically lit. That step
happens in "A steep line weights across columns", which happens not to check
`lit_pixels`. If it did, an exact-equality `lit_pixels` would fail through no
fault of the reader.

**`total_ink` "the sum of every pixel's red channel".** Since every chapter-3
line is white, red/green/blue are interchangeable, so the specificity is
untested — which is fine, but see below for what it does hide.

## Hard to translate

**Scenario outlines that share a name.** `S(F, name)` takes a string, so the
four rows of "The ink depends on the angle" needed generated names
(`... [12, 2, 11]`). Minor, and the same shape as chapter 2's outlines.

**`lit_pixels(c) = [(0, 0), (1, 1), ...]`** — the only step in three chapters
that compares two *lists*. It needed a new harness type (`PixelList`), a
variadic macro so `{{0,0},{1,1}}` survives the comma splitting, and a diff
printer. About 45 lines of harness for nine scenarios. Worth it; the diff
printer paid for itself immediately.

**`thick_line` had to widen `Shape`.** Chapter 2's `Shape` is
`{kind; double a, b, c, d;}` passed by value. Four half-planes need sixteen more
doubles, so `Shape` went from 40 to 168 bytes and `inside` is called ~20 million
times by value. Measured cost: nothing detectable, C copies it in registers /
stack slots. In a language where that copy is a heap allocation this would hurt
and the chapter gives no warning.

## Failures

One real failure, and it is the book's number that is right and the *compiler*
that is wrong.

**`ink(cov) = 9.7188` gave 9.65625.** Cause: clang defaults to
`-ffp-contract=on` for C11, so `(x - px) * nx + (y - py) * ny` is compiled as an
fma. Four of the sixty-four sample points in the diagonal scenario sit *exactly*
on the half-plane through the start point (`x + y = 5` with both coordinates
sixteenths, so the two products cancel exactly in IEEE double). The fma keeps the
first product at full precision, the cancellation is no longer exact, the value
comes out at about `-5.5e-17`, and four samples flip from inside to outside:
622/64 becomes 618/64. Fixed with `#pragma STDC FP_CONTRACT OFF` in
`renderer.c`. This is worth a `.trap` box in the chapter: the scenario silently
requires exact tie handling on a boundary, and half the toolchains in the world
will fuse that expression by default. Any reader on gcc `-O2`, clang, or a JIT
with fma will see 9.65625 and have no idea why.

**Nothing else failed.** Both reference images (`fan-coverage.ppm`,
`plate-03.ppm`) came out byte-identical, not merely within ±1, on the first run
after the fma fix.

## Mistakes that stay green

56 mutations, 4 that are genuinely wrong and survive, 4 that survive because
they are provably equivalent. Everything else dies. One line each:

Caught (52) — Bresenham `err = 0` (5 scenarios fail); `err = dx` (7);
`err <= 0` instead of `< 0` (3); steep swap forgotten (2); swap-back forgotten,
always `write_pixel(c, x, y)` (2); loop `x < x1`, endpoint exclusive (8); first
pixel skipped (9); no left-to-right swap (2); `ystep` always +1 (2);
`dy` without `abs` (2); `err = (dx + 1) / 2` (2). Wu weights swapped (7);
`round` instead of `floor` (4); `ceil` instead of `floor` (5); only the nearer
pixel plotted at weight 1 (5); steep swap forgotten (4); no left-to-right swap
(2); `plot` writing `col` instead of `mix` (7); `plot` ignoring the existing
pixel (2); `y = y0 + x * slope`, dropping `- x0` (3); `slope` using
`abs(y1 - y0)` (2); weights biased by 1e-3 (3). `thick_line` sides facing
outward (8); built from pixel corners, no `+ 0.5` (3); only one endpoint gets
`+ 0.5` (8); `half = width` (full width per side) (8); end planes facing the
wrong way (8); ends exclusive, `<= 0` (2); one side half-plane dropped (7);
sides not offset off the centerline (8). `lit_pixels` column-major (1);
`lit_pixels` rows bottom-up (6); `total_ink` summing all three channels (9);
`total_ink` counting lit pixels instead of summing (5). `ray_ends` truncating
instead of rounding (3); degrees used as radians (5); `-sin` for y (1);
radius 71 (4). Fan center at (79, 79) (3); `fan_coverage` center at (79, 79)
(1); only 11 rays drawn (1); rays 2 pixels wide (1); `fan_coverage` painted
twice (1); `fan_coverage` not magnified (1); `plate_03` not magnified (1);
plate halves swapped (1); ink color `0.92, 0.92, 0.92` (4); paper
`0.02, 0.02, 0.02` (3).

**STAYS GREEN — `thick_line` ignores its `width` argument entirely**
(`half = 0.5` hardcoded). All seven quad scenarios and both reference plates
pass. `width` is a parameter of the chapter's signature and nothing tests that
it is read. One scenario — `thick_line(0, 3, 7, 3, 2)` with
`coverage_at(cov, 3, 2) = 1` and `ink(cov) = 14` — would close it. This is the
one I'd actually add.

**STAYS GREEN — `line_wu` without the `dx = 0 ? 0` guard.** A zero-length Wu
line divides 0 by 0, `slope` is NaN, `floor(NaN)` is NaN, and the cast to int is
undefined behaviour. Bresenham has "A line of one point"; Wu has no counterpart,
and the fan never draws one. The chapter's own pseudocode contains the guard, so
a reader copying it is fine — but a reader who writes Wu from the description
gets a landmine that never fires until chapter 6 hands it a degenerate edge.

**STAYS GREEN — `thick_line` without its zero-length guard.** Same shape of bug:
`thick_line(3, 3, 3, 3, 1)` divides by a zero length and every half-plane normal
is NaN, so `inside` is false everywhere and `ink` is 0 rather than 1. The
chapter doesn't mention the case at all, and nothing tests it.

**STAYS GREEN — `total_ink` summing the blue channel** (or green) rather than
red. Harmless here because every chapter-3 line is white, but the feature file
says "the red channel" as if it were pinned, and it isn't.

Equivalent mutants — green, but I checked they cannot be distinguished:
`err = dx / 2.0` in floating point (argued above); `plot` not skipping weight 0
(`mix(a, b, 0) == a` exactly); normal taken as `(d.y, -d.x)` instead of
`(-d.y, d.x)` (mirrors a symmetric rectangle onto itself); fan rays drawn
end-to-center instead of center-to-end (which is precisely the property the two
"doesn't depend on which end" scenarios exist to guarantee).

## Prose

The chapter reads very well and the order is right: algorithm, picture, "look at
what's wrong with the picture", better algorithm, "look at what's *still* wrong",
reveal. §3.3's opening paragraph is the best paragraph in the book so far.

**The numbers all hold.**
- **"18% less paint"** — Wu's ink is 11 for the axis-aligned 10-length rays and
  9 for the 3-4-5 ones; 9/11 = 0.818, so 18.2% less. Confirmed.
- **"9.72"** — measured 9.71875 exactly (622 of 640 sample cells). The true area
  is 7√2 = 9.89949, so the shortfall is 1.83%, matching "off by nearly 2%".
- **"twenty million inside tests"** — 12 × 160 × 160 × 64 = 19,660,800. Confirmed.
  Worth noting the chapter is counting `inside` calls; each one on a `thick_line`
  is four half-plane tests, so it's 78.6 million dot products.
- **"twenty seconds"** — I timed a straight Python transcription of `inside`:
  0.014 s for 25,600 tests, extrapolating to 11 s for the 19.66 M, plus the
  coverage-buffer and `paint_through` passes. Twenty seconds is honest for CPython.
  In C at `-O2` it is **62 ms**, which is a fact the chapter might want to admit,
  because "the actual lesson of this chapter" is a performance lesson and it is
  three orders of magnitude softer in a compiled language. The lesson still
  holds at 4K, but 160×160 doesn't make it.
- **"at 30° the line rises 0.577 pixels per column"** — tan 30° = 0.5774. Yes.

**One sentence I had to read four times.** §3.3: "Wu's two-pixels-per-column
rule can't see that, because on a slanted line each column is a slanted slice
through the band, and the slice is longer than the band is wide." It's correct,
but the causal chain is compressed to breaking point: the column-slice of a
1-wide band at angle θ has area 1/cos θ, Wu assigns it total weight exactly 1,
so Wu undercounts by cos θ — for the 3-4-5 line, 0.8, which is where 9 versus
10 comes from. Two more clauses would do it.

**Missing.** §3.2 says "For Wu it's always the number of columns" and the next
section's numbers (11 and 9 for two lines of the same length) are entirely
explained by column count, not by weights at all. A reader can finish §3.2
believing the slanted rays are lighter *per pixel*. They aren't: every column
still carries exactly 1. They're lighter because there are fewer columns. The
plate caption ("the slanted rays are a shade lighter than the axes") reinforces
the wrong reading.

**Out of order, mildly.** `lit_pixels` and `total_ink` are introduced in §3.1
and §3.2 respectively, but `total_ink`'s definition arrives *after* the
scenarios that use it in the reader's likely reading order — the feature block
sits immediately below the paragraph and its own preamble redefines it.

## Would change

1. A `.trap` box on floating-point contraction, next to the 9.7188 scenario.
   It cost me the only debugging session of the chapter and it will hit
   everyone on a compiled language.
2. `ink(cov) = 9.7188` against the book's default tolerance of 0.0001 leaves
   0.00005 of margin — the exact value is 9.71875 and rounding to four decimals
   uses up half the budget. Write `9.71875`, or give it an explicit tolerance.
3. Add one `thick_line` scenario with a width other than 1.
4. Add "A Wu line of one point" to mirror Bresenham's, so the `dx = 0` guard
   is pinned by something.
5. `fan_wu`'s scenario checks four pixels and no reference image, while
   `fan_bresenham`'s checks five and `fan_coverage`'s checks six plus a
   reference. Wu's fan is the one whose weights are subtle; it deserves the
   reference file, not the thinnest check of the three.
6. The chapter shows `plate_03` combining Bresenham and Wu but calls Figure 3.4
   (`fan_coverage`) "the version where they aren't [lighter]". Putting the
   coverage fan into the plate as a third panel would make the whole argument
   one image.

## Results

    chapter 1: 59 scenarios, 59 passed, 0 failed
    chapter 2: 28 scenarios, 28 passed, 0 failed
    chapter 3: 31 scenarios, 31 passed, 0 failed
    118 scenarios, 118 passed, 0 failed

Chapter 3's 31 = 9 Bresenham + 10 Wu (6 + a 4-row outline) + 7 quad (2 + a
4-row outline + 1) + 5 plate.

`make render` writes `out/fan-coverage.ppm` and `out/plate-03.ppm`; both are
byte-identical to `reference/chapter-03/`.

Whole suite: 0.178 s. Time hotspots (`TIMING=1 ./bin/tests`):

    feature_plate_03      75.5 ms   (fan_coverage alone is 62 ms)
    feature_plate         47.5 ms   (chapter 1)
    feature_gray_match    18.6 ms   (chapter 1)
    feature_limits        10.6 ms   (chapter 1)
    feature_quad           0.4 ms
    feature_bresenham      0.0 ms
    feature_wu             0.0 ms

Chapter 3 is 43% of the suite's runtime and all of it is the one supersampled
fan. Everything else in the chapter is free.
