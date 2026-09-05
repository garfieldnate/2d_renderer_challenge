# Chapter 2 — reader's feedback

Implementation: C11, clang, `make test` / `make render` from this directory.
All 87 scenarios pass (59 chapter 1, 28 chapter 2) and all four chapter-2
renders are byte-identical to `reference/chapter-02/`.

## Ambiguities

* **"byte 12 of p6 = 255"** — the base is never stated. I guessed 1-based, from
  the chapter's own arithmetic: "A 2-by-1 canvas is 11 bytes of header and 6
  bytes of pixels", so byte 12 is the first pixel byte, and that makes the three
  asserted bytes (255, 0, 188) land on red₀, green₀, green₁. Consistent, but the
  reader has to derive it. One clause in §2.2 would fix it.
* **"length(p6) = 17"** and *"your `read_file` now returns bytes rather than
  text"* — the chapter never says what shape that is. In a language without
  NUL-terminated strings this is free; in C a P6 buffer has NULs in it, so a
  length has to travel with the pointer. I introduced
  `typedef struct { unsigned char *data; size_t len; } Bytes` and changed
  `read_file` and `canvas_to_p6` to return it.
* **`max_channel_difference(p3, p6) = 0`** — this one scenario passes a text
  handle and a byte handle to the same function. I guessed the intent is "the
  readers accept either format" rather than "convert first", and made the three
  readers take `Bytes` with a `_Generic` macro at the call site so a `char *`
  still works. See *Hard to translate*.
* **"Sizes still have to match"** — a 2×1 and a 1×2 canvas have the *same number*
  of channel values (6) and both are black. Chapter 1's `max_channel_difference`
  compared value counts only, and it passes every chapter-1 scenario; it returns
  0 here, not 255. The chapter never says the comparison has to look at the
  header dimensions. I added a width comparison. Worth a sentence in §2.2,
  because this is the only thing in the chapter that silently invalidates a
  chapter-1 function.
* **`center_inside(s, 2, 4) = 1`** — `1`, not `true`. I made it return a
  coverage number (double), which is what `rasterize_centers` wants anyway, but
  the chapter never introduces `center_inside` in prose at all; it only appears
  in the feature file.
* **Unspecified, no scenario:** `paint_through` when canvas and coverage differ
  in size; `coverage_at` outside the buffer (§2.4 says *writes* are dropped and
  is silent on reads); `magnify` with k ≤ 0; a P6 file with a maxval other than
  255. I assumed: canvas dimensions win, reads clamp to 0, k ≥ 1, maxval ignored.
* **`rectangle`'s "top" and "bottom"** — the prose says "left, top, right and
  bottom", and the example `rectangle(1.25, 2.0, 4.75, 5.0)` has top < bottom,
  which is only "top" in a y-down canvas. Fine once you notice, but "top" and
  "bottom" carry an orientation the chapter hasn't stated yet.

## Hard to translate

* The mixed-type `max_channel_difference(p3, p6)` call. C11 `_Generic` handles it
  in four lines (`#define AS_BYTES(x) _Generic((x), Bytes: …, char *: …)`), which
  keeps every chapter-1 call site untouched, but it is the least book-like code
  in the project. A dynamically typed reader will not notice this scenario at all.
* `p6 begins with "P6\n2 1\n255\n"` — has to be `memcmp` over 11 bytes, not a
  string compare, because what follows is binary. Trivial once said; the feature
  file's quoted-string syntax actively suggests the wrong thing.
* "Scenario: The center of pixel (x, y) is (x + 0.5, y + 0.5)" has a second
  `Given t ← half_plane(2.6, 0, 1, 0)` *after* a block of `Then`s. That is not
  valid Gherkin ordering and no runner would accept it; I inlined both shapes in
  one test body. Same scenario is the only one in the chapter that does this.
* `ink(cov) = 78.5` followed by `ink(cov) = 78.5398 ± 0.1` in the same scenario
  reads like a contradiction until you work out that coverage is always a
  multiple of 1/64 and 78.5 × 64 = 5024 exactly. It is a nice fact, but it is
  hidden; a comment in the feature file ("exactly 5024/64") would save the reader
  ten minutes of suspecting their own arithmetic.
* `exactly 9 pixels of m are color(1, 0, 0)` reused chapter 1's `count_pixels`
  helper; no trouble.

## Failures

None. Nothing in the chapter disagreed with my implementation, and the four
reference images matched byte for byte on the first run, including
`distinct_values(disc-centers) = 5` and every `± 1` probe. The chapter's
pseudocode for `disc_centers`, `painted_twice` and `plate_02` is complete and
literal enough to transcribe directly.

## Mistakes that stay green

Twenty-nine mutations, each built and run against the full suite. Four survive.

**Stays green — the interesting ones:**

1. **`canvas_to_p6` emits rows bottom-up.** Not caught by anything. This is the
   classic PPM/BMP confusion and the chapter introduces a brand-new writer with
   no row-order scenario. It survives because every chapter-2 picture is exactly
   vertically symmetric (I checked: all four are), and the only small P6
   canvases in the feature files are 2×1 and 1×2 — one row, or an all-black
   image. Chapter 1's row-order coverage is all P3. This is the most valuable
   hole in the chapter.
2. **`rasterize_centers` implemented as `coverage(s, x, y) >= 0.5`.** Not
   caught. The "center of pixel" scenario uses `half_plane(2.6, 0, 1, 0)` at
   pixel (2,4), where the sampled coverage is 0.375 — the threshold rule agrees.
   And for a radius-16 disc the two rules agree on all 1600 pixels, so
   `disc-centers.ppm` and `plate-02.ppm` come out identical. So a reader can
   miss the entire point of §2.4 versus §2.6 and still ship a green suite.
3. **`paint_through` loops over the coverage buffer's dimensions instead of the
   canvas's.** Not caught; every scenario uses matching sizes. Low stakes now,
   but it is exactly the kind of thing chapter 3 will trip over.
4. **`coverage_at` without a bounds check.** Not caught — but the chapter only
   specifies writes, so this is a spec gap, not a reader error.

**Caught** (failing scenarios in parentheses):

* Samples at cell corners `i/8` instead of `(i+0.5)/8` — caught (7).
* Samples at the far corner `(i+1)/8` — caught (8).
* `center_inside` tests the pixel corner `(x, y)` — caught (4), including
  "The center of pixel (x, y) is (x + 0.5, y + 0.5)".
* Coverage divided by 63 — caught (8).
* An 4×4 sample grid instead of 8×8 — caught (5).
* P6 header ends with a space instead of a newline — caught (1, the header
  scenario only; no reference-image scenario notices).
* P6 reader skips two header bytes instead of one — caught (5).
* P6 reader assumes a fixed 11-byte header — caught (4).
* P6 reader uses the height as the row stride — caught (3).
* `canvas_to_p6` emits each row right-to-left — caught (4).
* `magnify` transposed — caught (4).
* `magnify` sampling `(x+1)/k` — caught (6).
* `paint_through` ignoring the existing pixel — caught (7).
* `paint_through` with the mix arguments swapped — caught (6).
* `paint_through` mixing in sRGB instead of light — caught (7).
* `half_plane` with the normal's sign flipped — caught (4).
* `half_plane` with the boundary excluded (`> 0`) — caught (3).
* `half_plane` normalising the normal (and so mishandling the boundary) — caught (3).
* `rectangle` with an exclusive boundary — caught (1) — **only** by
  "A point inside a rectangle". The `rasterize` rectangle scenario does not
  notice, because no sample point lands exactly on 1.25 or 4.75 (samples are at
  x + (i+0.5)/8, never at a multiple of 1/4). The chapter's claim that the
  rectangle is "exact" is about column counts, not about the boundary rule.
* `circle` with an exclusive boundary — caught (1), by `inside(s, 13, 8)`.
* `set_coverage` without the bounds check — caught (1). Note it is caught by
  arithmetic, not by a crash: two of the three out-of-range writes land inside
  the same allocation and make `ink` non-zero.
* `ink` returning the mean instead of the sum — caught (4).
* `max_channel_difference` comparing value counts only (chapter 1's version) —
  caught (1), the 2×1 vs 1×2 scenario.
* `rasterize` writing rows flipped — caught (1), by the rectangle only; the
  discs are symmetric.
* `canvas_to_ppm` (P3) emitting each row right-to-left — caught by chapter 1 (8),
  which is the contrast that makes the P6 row-order gap above so visible.

## Prose

**Where the numbers are wrong.** §2.6: *"It's also correct to within 1/64 for
anything with a straight edge."* That is false, and the chapter disproves it two
sentences later with its own 0.5625 example: a straight edge at 45° through a
pixel centre has true coverage 0.5 and sampled coverage 0.5625, an error of
**4/64**. A shallow axis-aligned edge is just as bad: a horizontal edge at
y = 4.03 has true coverage 0.03 and sampled coverage 0.0000, an error of
**1.92/64** (I measured both). The honest statement is that the *answer* is
quantised to 1/64, and that for a straight edge the *error* is bounded by half a
sample row, 4/64. As written it is the one claim in the chapter a reader could
use to justify not checking their rasteriser against something exact.

*"The file is a quarter the size of the P3 version"* — measured 0.299 for
`plate-02` (1,155,183 bytes P3 vs 345,615 P6). "About a third" is closer. Not
important, but it is a checkable number and it is off.

**Where they are right.** 25π ≈ 78.5 versus a centre count of 80: exact, `ink`
comes out to 80 and 78.5 on the nose. 17 bytes for the 2×1 P6. 0.75 for the
rectangle column. 0.5625 for the 45° half-plane. 0.5 → 0.75 for the twice-painted
edge. `distinct_values = 5` for `disc-centers` (39, 44, 89, 196, 243). All good.

**Order.** §2.5 puts the `disc_centers()` scenario *inside* the feature block and
the definition of `disc_centers()` in the paragraph *after* it, so you read a
test for a function you have not been shown. §2.6 and §2.7 do it the other way
round (pseudocode first). Pick one; pseudocode-first is right.

*"Your `read_file` now returns bytes rather than text; a P3 file is text that
happens to be stored in bytes, so nothing changes for chapter 1's tests."* — in a
statically typed language every chapter-1 call site changes, because the return
type changed. Small, but it is stated as a fact about the reader's code and it is
untrue for a large class of readers. "Nothing changes for chapter 1's *results*"
would be accurate.

**Missing.** Nothing tells the reader what `center_inside` is called or that it
exists; it appears only in the feature file. Nothing says whether the coverage
buffer's dimensions have to match the canvas's. §2.2's promise that the readers
"accept both" formats is the only hint that `max_channel_difference` needs to
compare dimensions, and it does not survive as a hint.

**Good.** The sample-point formula `(x + (i + 0.5)/8, y + (j + 0.5)/8)` is stated
once, exactly, with the row/column roles named — no ambiguity at all, which is
why the corner-sampling mistake is easy to avoid and easy to catch. §2.7 is the
best thing in either chapter so far: the trap is real, the demonstration is two
lines of code, and `painted_twice` makes it visible. The "this one function is
the seam" paragraph in §2.5 is worth the price of admission.

## Would change

1. **Add a row-order scenario for P6.** Two lines would close the biggest hole:
   `Given c ← canvas(1, 2)`, write different colors to (0,0) and (0,1), then
   assert `byte 12 of p6` is the *top* pixel's red. Every reference image in the
   chapter is vertically symmetric, so nothing else can catch a flipped writer.
2. **Add a scenario that separates the two questions.** `center_inside` is
   currently indistinguishable from "at least half the samples are inside".
   `half_plane(2.55, 0, 1, 0)` at pixel (2, 4) does it: the centre (2.5) is
   outside, so `center_inside = 0`, while `coverage = 0.5`. One line.
3. **State the byte-numbering base** in §2.2, and state that
   `max_channel_difference` compares dimensions, not just value counts.
4. **Fix the 1/64 claim** to be about quantisation, and give the real error
   bound (half a sample row, 4/64, for a straight edge).
5. **Move the `disc_centers()` pseudocode above its scenario.**
6. Mention, in one clause, that `read_file` returning bytes means a length has to
   come with it. It is the only structural change chapter 2 forces on a typed
   implementation and the chapter treats it as free.

## Results

* chapter 1: 59 scenarios, 59 passed, 0 failed.
* chapter 2: 28 scenarios, 28 passed, 0 failed (shapes 4, p6 3, magnify 2,
  centers 5, paint 5, coverage 6, twice 2, plate 1).
* `out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
  `out/plate-02.ppm` are byte-identical to `reference/chapter-02/`.
* Whole suite: 96 ms. Time hotspots (`TIMING=1 ./bin/tests`): chapter 1's
  `plate_01` 47.9 ms and `gray_match` 18.7 ms still dominate — they are P3
  writers on big canvases, and the cost is `snprintf` per channel, not the
  drawing. Chapter 2's four picture scenarios cost 4.0–4.5 ms each, of which the
  8×8 brute-force rasterizer is a small part: `rasterize` on 40×40 is 102,400
  `inside` calls, about 1 ms. The rest is `magnify` plus building the int array
  for each P6 comparison. Nothing here needs optimising; the "it's slow" warning
  in §2.6 is about chapter 5's scale, not this one's.
* Mutation testing: 29 mutants, 25 caught, 4 green (listed above).
