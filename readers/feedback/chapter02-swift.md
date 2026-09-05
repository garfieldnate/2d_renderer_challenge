# Chapter 2 — reader's feedback

Swift, plain `swiftc -O`, no SwiftPM. Chapter 1 was already implemented; this is chapter 2
built on top of it.

## Ambiguities

**"it's `mix(pixel, color, coverage)`, the same mix as chapter 1, in light."** Chapter 1's
`mix` reads a global `linear blending` switch (§1.7), and chapter 1's own `plate_01` turns
that switch off and on again mid-render. So "the same mix as chapter 1" and "in light" are
in tension: does `paint_through` call `mix` and inherit the switch, or does it force linear
blending? I called `mix` plainly and inherit the switch. The scenario "The arithmetic is on
light" only pins this down when the switch happens to be on, which it is by default — so
both readings pass. Please say which one you mean.

**"byte 12 of p6 = 255"** — 1-based. Nothing in §2.2 or the feature file says the base, and
the answer is only recoverable by counting: `"P6\n2 1\n255\n"` is 11 bytes, so byte 12 is
the first pixel byte, so it must be 1-based. That's a decision a statically typed
implementation has to make before anything compiles. One clause in §2.2 ("byte 1 is the
`P`") fixes it.

**"skip the single whitespace byte after the last one."** I skip exactly one byte, as
written. A reader who skips *all* trailing whitespace passes all 28 scenarios (see Mistakes
that stay green). Also unaddressed: real P6 files may carry `#` comments in the header. I
assume they don't.

**"Your `read_file` now returns bytes rather than text; a P3 file is text that happens to be
stored in bytes, so nothing changes for chapter 1's tests."** In a dynamic language, sure.
In Swift, "nothing changes" is only true because I made `ppm_pixel`, `distinct_values` and
`max_channel_difference` accept both a `String` and a `[UInt8]`. The chapter states the
requirement as a property of the file format; it is actually a requirement on the
*signatures* of three functions, including `max_channel_difference(p3, p6)` with one
argument of each type. Worth saying out loud.

**`ink(cov) = 78.5` and `ink(cov) = 78.5398 ± 0.1` in the same scenario.** The first has no
`±`, so it inherits the book's default 0.0001 tolerance and asserts the sum is *exactly*
78.5. It reads at first like an author who wrote an approximate number and forgot the
tolerance. It isn't: 5024 samples land inside, 5024/64 = 78.5 on the nose. That's a sharp
and good assertion, and it deserves a sentence saying it's deliberate, because a reader
who sees it fail by 0.02 will assume the book was being loose and widen the tolerance.

**Reads outside a coverage buffer.** §2.4 specifies that *writes* outside the buffer are
dropped, and there's a scenario. It says nothing about `coverage_at` outside the buffer. I
return 0. No scenario either way.

**`magnify(c, k)` for k ≤ 0** is unspecified. I don't handle it.

## Hard to translate

**The polymorphic PPM readers.** Swift has no duck typing, so `ppm_pixel(p3, …)`,
`ppm_pixel(p6, …)` and `max_channel_difference(p3, p6)` across `String` and `[UInt8]`
needed a `PPMSource` protocol with a conditional conformance on `Array`. That plumbing was
the single largest chunk of chapter-2 work, and none of it is about graphics. A note that
statically typed readers will want one "PPM bytes" type here would save an hour.

**`inside` and `center_inside` look like the same call and aren't.** `inside(s, 2.5, 7)`
takes real coordinates; `center_inside(s, 2, 4)` takes pixel indices; `inside` returns a
boolean and `center_inside` returns a number (1 or 0). The feature files give no type
hints, and the two names differ by one word. Given that §2.4's whole point is that the
mathematical point (3, 3) and the pixel (3, 3) are different things, having the two
functions be so nearly identical in appearance is a little cruel — though I concede that
may be intentional.

**`Shape`.** "A shape is a function from a point to yes or no" translates cleanly (a struct
wrapping a closure), and it was the nicest part of the chapter to implement.

## Failures

None. All 28 chapter-2 scenarios passed on the first build, and all four renders came out
**byte-identical** to `reference/chapter-02/`. Chapter 1's 59 kept passing.

One piece of chapter-1 code had to change: `max_channel_difference` compared byte *counts*
to decide "different sizes: not comparable". The new scenario "Sizes still have to match"
(a 2×1 against a 1×2) has equal byte counts, so the old version silently returned 0. That's
the chapter catching a real bug, and it's the best-earned scenario in the file — but §2.2
presents it as a new test for a new format, when it's actually a bug fix to chapter 1's
function. Say so.

## Mistakes that stay green

I ran 25 plausible reader errors as source mutations. Five survive.

1. **`rasterize_centers` writes `set_coverage(y, x, …)` — the transposed buffer. 28/28
   pass.** This is the finding I'd most want fixed. Every shape `rasterize_centers` is
   tested against is symmetric under transposition (`circle(8, 8, 5)`, and the disc in all
   three plates), and every buffer it fills is square. Chapter 1 has a scenario *for exactly
   this mistake* — "x is the column and y is the row" — and chapter 2 has no equivalent for
   the rasterizers. The same mutation applied to `rasterize` is caught by exactly one
   scenario, the rectangle, and nothing else. **Fix: give `rasterize_centers` one assertion
   on an asymmetric shape, the way the rectangle scenario already does for `rasterize`.**

2. **`canvas_to_p6` writes rows bottom-up, BMP-style. 28/28 pass.** Every chapter-2 picture
   is vertically symmetric — the discs are centred at y = 20 in a 40-row buffer, so row y
   and row 39−y are identical — and the two header scenarios use a 1-row canvas. The four
   reference comparisons can't see it either. Chapter 1's P3 scenarios *would* catch a
   flipped P3 (the gray-match checkerboard isn't vertically symmetric), so this is purely a
   gap in the new format's coverage. **Fix: one `ppm_pixel` on a P6 of something that isn't
   top-bottom symmetric.**

3. **`coverage_at` returns 1 (or anything) for out-of-bounds reads. 28/28 pass.**
   `set_coverage` gets an out-of-range scenario; `coverage_at` doesn't.

4. **The P6 reader skips *all* whitespace after the maxval instead of exactly one byte.
   28/28 pass.** Harmless, arguably more correct than the spec, but §2.2 is emphatic about
   "the single whitespace byte" and nothing enforces it.

5. **The P6 header uses a space instead of the final newline.** Caught, but by exactly one
   step — the literal `p6 begins with "P6\n2 1\n255\n"`. My own reader parses such a file
   fine, so `max_channel_difference` against all four references still returns 0 and the
   picture scenarios see nothing. One assertion stands between a reader and a
   quietly-nonconforming writer.

Caught, for the record — chapter 2 failures shown, chapter 1 stayed green throughout:

- Sample points at cell corners instead of centres — 7 scenarios.
- `center_inside` tests the pixel corner instead of the centre — 4 scenarios (the chapter
  promises "There's a scenario for it"; there are four, and the picture comparisons catch
  it too).
- Coverage divided by 63 — 8 scenarios.
- `paint_through` ignores the existing pixel — 5 scenarios.
- `paint_through` swaps `mix`'s two colors — 6 scenarios (note "Half coverage is half the
  paint" does *not* catch it: mix(black, white, ½) = mix(white, black, ½)).
- `paint_through` blends the way browsers do — 7 scenarios.
- `magnify` transposed — 4 scenarios.
- `magnify` rounds to the nearest source pixel — 6 scenarios.
- `half_plane` normal's sign flipped — 4 scenarios.
- `half_plane` with a strict inequality (boundary excluded) — 3 scenarios.
- 4×4 or 16×16 sample grid instead of 8×8 — 5 scenarios each.
- `ink` is the mean instead of the sum — 4 scenarios.
- `distinct_values` counts distinct pixels instead of channel values — 1 scenario.
- P6 header with an extra newline — 6 scenarios.
- `rectangle` with an exclusive boundary — 1 scenario only, `inside(s, 1.25, 2.0) = true`.
  The rasterize scenario is blind to it: no sample point ever lands on 1.25 (see Prose).
- `circle` with an exclusive boundary — 1 scenario only, `inside(s, 13, 8) = true`.
- `max_channel_difference` comparing byte counts (chapter 1's version) — 1 scenario.
- `painted_twice` / `plate_02` with the halves swapped — 1 scenario each.
- `set_coverage` without the bounds check, and a P6 header with the trailing newline
  dropped — both **crash** rather than fail. Caught loudly, but the reader gets a Swift
  index trap instead of a scenario name.

## Prose

**Order is good.** Each tool arrives immediately before it's needed, and §2.2 and §2.3 are
flagged as a detour rather than pretending to be part of the argument. The one exception is
that §2.3 introduces the loupe before there is anything to look at; the magnifier would
land better after §2.5 produces the first picture.

**The numbers hold.** I checked all of them. 25π = 78.53981…; `rasterize_centers` on
`circle(8, 8, 5)` gives exactly 80; `rasterize` gives exactly 78.5 (5024 samples of 64);
the 45° conspiracy is exactly 36/64 = 0.5625; the rectangle's 10.5 is exactly 3 rows ×
(0.75 + 1 + 1 + 0.75). Every reference image matched byte for byte.

**§2.6's explanation of the 0.5625 is a step short.** "A line at exactly 45° through the
centre runs straight through a diagonal of sample points, every one of which counts as
inside" — true, and the reason *every one counts* is the boundary rule from §2.1, which
isn't mentioned here. Concretely: 8 sample points have dot product exactly 0, and they land
inside only because the half-plane includes its boundary. A reader who chose `> 0` instead
of `>= 0` gets 0.4375 and has to work backwards through two sections to find out why. One
clause — "because the half-plane includes its boundary, all eight of those tie points count"
— closes it.

**"its edges at 1.25 and 4.75 land on sample boundaries" is loosely worded.** They land on
*cell* boundaries of the sample grid, not on sample *points*. That is precisely the
distinction §2.4 spends a paragraph teaching, and it gets blurred in the sentence that
depends on it most. It also has a consequence worth stating: because no sample ever lands
exactly on 1.25, the rectangle's "boundary included" rule is invisible to `rasterize` — the
only thing testing it is the `inside` scenario in §2.1.

**Missing: what `paint_through` does when the canvas and the buffer are different sizes.**
Both `painted_twice` and `plate_02` go to the trouble of building an 80×40 buffer to match
an 80×40 canvas, which strongly implies they must match, but the chapter never says it and
no scenario checks it.

**§2.7 is the best writing in the book so far.** "Every 2D renderer on earth has that seam
and nobody mentions it" is the sentence that made me actually render `painted_twice` and
look at it instead of just running the test.

**"It's slow."** See Results — at the sizes this chapter uses, it isn't, and the sentence
sends readers looking for an optimization they don't need for six more chapters.

## Would change

1. Add an asymmetric-shape assertion for `rasterize_centers` (mistake 1).
2. Add one P6 `ppm_pixel` on a vertically asymmetric image (mistake 2).
3. Add a `coverage_at`-out-of-bounds scenario, matching `set_coverage`'s.
4. State the byte index base in §2.2.
5. State whether `paint_through` honours or ignores chapter 1's linear-blending switch.
6. Say in §2.2 that `max_channel_difference` has to start comparing dimensions rather than
   byte counts — it's a change to chapter 1's code, not just a new test.
7. In §2.6, connect the 0.5625 to the "boundary included" rule.
8. Note that `ink(cov) = 78.5` is exact on purpose.
9. Rephrase "It's slow".

## Results

**Chapter 1: 59 scenarios, 59 passed, 0 failed. Chapter 2: 28 scenarios, 28 passed, 0
failed. 87 total.** All four chapter-2 renders byte-identical to the references.

Whole suite: **0.49 s with `-O`, 3.90 s without** — 8×, so the `-O` warning is well placed.

Time hotspots, and they are not where the chapter says they'll be:

```
  294.7 ms  Plate 1 :: The plate                       <- chapter 1, P3 string building
   73.4 ms  The gray match :: The gray match, as a file <- same
   36.0 ms  The edges of the range :: Clamping ...      <- same
   11.7 ms  Painting through coverage :: The disc by centers
   10.5 ms  Coverage is not opacity :: The disc, once and twice
   10.3 ms  Plate 2 :: The plate
    7.1 ms  The better question :: The disc by coverage
```

Chapter 1's `plate_01` alone is 60% of the run, and it's the P3 *text* writer, not
arithmetic. All nine chapter-2 scenarios that render a picture total about 40 ms. The
supersampler the chapter warns about does 40 × 40 × 64 = 102,400 shape queries per picture
in 7 ms. Moving the reference images to P6 bought far more than the sampler cost.
