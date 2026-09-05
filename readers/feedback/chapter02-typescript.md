# Chapter 2 feedback — TypeScript / Deno reader

88 scenarios green (60 chapter 1, 28 chapter 2). All four renders are **byte-identical**
to the references, not merely within the ±1 the scenarios allow. Nothing in the chapter
was wrong. Below is what cost me time and what the scenarios don't catch.

## Ambiguities

**"byte 12 of p6 = 255"** — 0-based or 1-based is never stated. The header is 11 bytes,
so byte 12 is the first pixel byte only if you count from 1. I got there by arithmetic
from "A 2-by-1 canvas is 11 bytes of header and 6 bytes of pixels", which is the sentence
doing the work; the scenario alone is a coin flip. Same for **"length(p6) = 17"**: bytes,
not characters. In a language where the obvious move is to decode the blob to a string,
188 is not valid UTF-8 on its own and you get a replacement character; the length happens
to still be 17 here, so the mistake would hide.

**"it's `mix(pixel, color, coverage)`, the same mix as chapter 1, in light."** Chapter 1's
`mix` carries a global naive/linear switch. Does `paint_through` respect it or force light?
"the same mix as chapter 1" says respect it; "in light" and the scenario title *The
arithmetic is on light* say force it. I forced it (`mix(..., linear = true)`). **No
scenario distinguishes the two**, because the switch defaults on and nothing turns it off
before the paint scenarios run — I confirmed this with a mutation (below). One sentence
would settle it.

**`read_file` now returns bytes.** The chapter frames this as a P3/P6 question, but the
real consequence is a type question: chapter 1's plate scenario does
`max_channel_difference(ppm, ref)` where `ppm` is a *string* from `canvas_to_ppm` and
`ref` is now *bytes*. So the readers have to take a union in the same argument position,
which is a bigger change than "look at the first two bytes" implies. I used
`type Ppm = string | Uint8Array` and normalised in one `parse`. The chapter's claim that
"nothing changes for chapter 1's tests" held exactly — all 60 stayed green untouched.

**`center_inside`** appears only in the feature file. §2.4 names `coverage_buffer`,
`coverage_at`, `set_coverage`, `ink` and `rasterize_centers` in prose but never this one,
and its return type is a *number* (`= 1` / `= 0`) where the sibling `inside` returns a
*boolean* (`= true`). I inferred number from the `= 1`. That inconsistency is deliberate-
looking but unexplained.

**Reads outside a coverage buffer.** "as with the canvas, writes outside the buffer are
dropped" covers writes only; `coverage_at` out of bounds is unspecified. I left it
unchecked (returns undefined). Likewise **`set_coverage` with a value outside 0..1** —
unspecified, I don't clamp.

**Mismatched sizes in `paint_through`.** Never addressed. Both `painted_twice` and
`plate_02` go out of their way to build 80×40 buffers by copying 40×40 ones, which is a
strong hint the sizes must match — but the hint is in pseudocode, not prose.

## Hard to translate

Nothing genuinely hard. Three friction points:

- The byte-level assertions (`p6 begins with "..."`, `byte n of p6`) need a small new
  vocabulary that chapter 1's line-oriented helpers (`lines 4-7 of ppm are`) don't cover.
  Two ten-line helpers.
- *The center of pixel (x, y) is (x + 0.5, y + 0.5)* has **two `Given` blocks separated by
  a `Then`**. That isn't legal Gherkin ordering and a real Cucumber runner would complain.
  Straight-line code, so harmless here, but it will bite anyone driving the .feature files
  directly.
- The scenario name **"The plate"** collides with chapter 1's "The plate". Deno reports
  bare test names, so I had to rename mine to "The plate (chapter 2)". Every chapter is
  presumably going to do this. Prefixing the plate scenarios would help.

## Failures

None. Every chapter-2 scenario passed on the first run of the first implementation, and
`cmp` says all four outputs match `reference/chapter-02/*.ppm` byte for byte. The only
place I could plausibly have gone wrong and not noticed is the argument order of `mix`
inside `paint_through` — and *Paint over something that isn't black* catches the swap
(0.4/0.15 vs 0.8/0.05), so the chapter has that covered.

## Mistakes that stay green

I ran 31 mutations. 26 were caught, often by several scenarios. These five survived:

- **`paint_through` honours the naive-blending switch** (`mix(px, col, k)` instead of
  forcing light). 88/88 green. This is exactly the ambiguity above, and it's the one that
  matters: the scenario named *The arithmetic is on light* cannot fail, because nothing
  ever turns the switch off. A scenario that sets naive blending on, paints, and still
  expects 188 would close it.
- **`ink()` rounds every value to the nearest 1/8 before summing.** 88/88 green. The
  disc's ink is *exactly* 78.5 either way (I checked: the rounding errors cancel to zero),
  and the rectangle's values are already multiples of 1/8. So both `ink` assertions in the
  chapter are far looser than they look. The per-pixel `coverage_at(cov, 3, 8) = 0.96875`
  is what actually pins the buffer; `ink` pins almost nothing.
- **The P6 writer skips the clamp** (`encode(v)` with no 0..1 clamp first). 88/88 green.
  Chapter 1's *Colors out of range are clamped, not wrapped* is a P3-only scenario, and no
  chapter-2 scene ever produces an out-of-range color, so the binary path's clamp is
  completely untested. One two-pixel P6 scenario with `color(1.5, 0, -0.5)` fixes this.
- **`paint_through` iterates the coverage buffer's dimensions rather than the canvas's.**
  88/88 green — identical behaviour whenever the sizes match, which they always do here.
  Unspecified rather than wrong, but see above.
- **`set_coverage` clamps its value to 0..1.** 88/88 green. Also unspecified.

Worth noting what *is* caught, because the coverage is otherwise good: sampling at cell
corners (7 failures), `center_inside` at the pixel corner (4), `/63` instead of `/64` (8),
a flipped half-plane normal (4), exclusive circle or rectangle boundary (1 each),
`set_coverage` with no bounds check (1), a transposed `magnify` (4), `magnify` rounding
instead of flooring (5), a P6 header one byte long or one byte short (6 each), a space
instead of the newline (1 — only `p6 begins with`), the reader skipping 0 or 2 whitespace
bytes (5 each), the reader never noticing P6 (2), the reader assuming a fixed 15-byte
header (1), width/height swapped in the header (4), and a double-offset in `rasterize` (5).

One structural observation: **`max_channel_difference(...) ≤ 1` and `ppm_pixel(...) ± 1`
make every image scenario blind to a systematic off-by-one in byte encoding.** I mutated
the P6 writer to floor instead of round (i.e. not sharing `to_byte` with P3, which is the
exact mistake §2.2 warns about) and all four image scenarios passed. The only things that
caught it were the two exact-value scenarios on a 2×1 canvas: `byte 16 of p6 = 188` and
`ppm_pixel(p6, 1, 0) = (0, 188, 0)`. The whole chapter's rounding correctness rests on
those two lines. That's fine, but it's worth knowing they're load-bearing.

## Prose

The chapter is well ordered and the numbers check out. Verified by running them:

- "11 bytes of header and 6 bytes of pixels" → 17. ✓
- "its area is 25π, about 78.5 pixels. The center test says 80." → `ink` is exactly 80. ✓
- "6 of the 8 columns of samples fall inside and the coverage is 0.75 on the nose" ✓
- "the answer comes out 0.5625" → 36 of 64. ✓
- "The sample test says 78.5" → exactly 78.5, and 78.5398 ± 0.1. ✓
- Every stated pixel value in every scenario ✓ (all four references match byte for byte).

Two claims that don't hold:

- **"correct to within 1/64 for anything with a straight edge"** is wrong, and the chapter
  disproves it two sentences later. A 45° line through a pixel center has true coverage
  0.5 and sampled coverage 0.5625 — an error of 1/16, four times the claimed bound. The
  honest statement is "within 1/64 of the true area only for axis-aligned edges; up to
  1/16 out at 45°". The paragraph already explains the mechanism, it just doesn't notice
  it contradicts the sentence above it.
- **"The file is a quarter the size of the P3 version"** — measured on `plate_02` it's
  0.299, and on a darker image with more one- and two-digit values it would be closer to a
  third. "A third" or "roughly a quarter" would be safer.

Smaller things:

- "you've written it in ten lines" — `coverage` plus `rasterize` is 15 in TypeScript. Nit.
- "It's slow." Not yet, at these sizes: the whole chapter's brute-force rendering is under
  100 ms. The warning is true and useful, but a reader will not feel it, which slightly
  undercuts the setup for chapters 3-8. A word on what 64× costs at 1920×1080 would land.
- §2.2 and §2.3 are a detour, and the chapter says so. It works — but it means the reader
  builds `canvas_to_p6` and `magnify` with no picture to use them on for two sections, and
  the P6 *reader* changes (§2.2) are the fiddliest code in the chapter while being the
  least motivated at the point they appear.
- §2.7 is the best section in the chapter. "Every 2D renderer on earth has that seam and
  nobody mentions it" is exactly the right sentence, and `painted_twice` is a well-chosen
  render: the difference is unmissable at 6×.

## Would change

1. Say `paint_through` ignores the naive-blending switch (or that it honours it), and add
   a scenario that fails if you pick wrong.
2. Add a P6 clamp scenario. `canvas(2,1)`, `color(1.5, 0, -0.5)`, `byte 12 = 255`,
   `byte 14 = 0`. Two lines, closes the only real untested behaviour in the chapter.
3. Introduce `center_inside` in §2.4 prose, and say its answer is 1 or 0, not true/false.
4. Fix "correct to within 1/64" — it's the only factually wrong sentence in the chapter.
5. Say "byte 12, counting from 1" and "length in bytes" in §2.2.
6. Rename the plate scenario to "Plate 2" so chapter titles don't collide across chapters.
7. One sentence on whether `paint_through` requires the buffer and canvas to be the same
   size.

## Results

| | scenarios | result |
|---|---|---|
| chapter 1 | 60 | 60 passed, 0 failed |
| chapter 2 | 28 | 28 passed, 0 failed |
| total | 88 | 88 passed, 0 failed, 0.97 s wall |

Chapter 2 by feature: shapes 4, p6 3, magnify 2, centers 5, coverage 6, paint 5, twice 2,
plate 1.

Time hotspots: chapter 1's `plate_01` at 275 ms still dominates the suite (it's 400×180
with two `mix` calls and four `pow`s per pixel). Chapter 2's are cheap: `disc_centers`
31 ms, `painted_twice` 26 ms, `disc_coverage` 21 ms, plate 2 ~20 ms — about 100 ms for all
the 64×-sampled rendering combined. The brute-force rasterizer is not a problem at 40×40.
Mutation testing (31 full suite runs) took about 30 s.
