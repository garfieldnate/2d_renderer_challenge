# Reader feedback — Chapter 1, implemented in C11

Setup: clang, C11, libc + libm only, a ~90-line assert harness in `src/harness.c`.
One C function per Gherkin scenario in `src/tests.c`; the two scenario outlines are
expanded to one scenario per example row. `make test` runs them from the project root.

**All 59 scenarios pass.** All five renders are *byte-identical* to the reference PPMs,
not merely within the ±1 the scenarios allow — including the line wrapping, which no
scenario pins for those files. That is a strong signal the chapter is specified tightly.
Most of what follows is small.

---

## Ambiguities

**1. `ppm_pixel` is described as needing something it just threw away.**
> "`ppm_pixel(ppm, x, y)` splits the text on whitespace, skips the four header tokens and returns the three whole numbers at pixel (x, y)."

To index pixel `(x, y)` you need the width, which is header token 2 — the description
tells you to skip it and never mentions reading it. Trivial to work out, but it is the
one place a five-line function isn't five lines from the description alone. I read the
width off token 2 before skipping.

**2. `max_channel_difference` on files of different sizes is undefined.**
> "`max_channel_difference(a, b)` does the same to two files and returns the largest difference between any pair of corresponding numbers."

"Does the same" presumably includes skipping the four header tokens, but a 5×3 canvas and
a 3×5 canvas have the same token count and identical body semantics under that reading, so
a transposed render would compare as *identical*. Given §1.3's warning that "a transposed
render looks almost plausible", that's an unfortunate blind spot in the one function the
book uses to catch bad renders. I made mismatched token counts return 255 and left the
header out of the comparison. Say explicitly what happens when the dimensions differ.

**3. The docstring steps don't say what "lines 4-7 of ppm are" compares.**
Is the expected block the four lines joined by `\n` with no trailing newline, with one,
or is it a prefix match on the raw text? I guessed "joined, no trailing newline". A reader
who guesses "prefix of `ppm` from the start of line 4" gets a passing test for the wrong
reason on the header scenario and a failing one here.

**4. `every pixel of c is …` and `5000 pixels of c are …` are never defined in §1.1.**
§1.1 promises to settle the notation "once", and it covers `←`, `=`, `≠`, `±`, operators
and `round`. It doesn't cover these two aggregate steps, and "5000 pixels of c are
color(1,1,1)" is ambiguous between *exactly* 5000 and *at least* 5000. I read it as
exactly, compared with the default tolerance.

**5. `distinct_values(ppm)`.**
> "Count them with `distinct_values`, which is the set of all the numbers after the header: 183 of them"

Set *cardinality*, not the set. And "after the header" resolves the header question, but
the only scenario that uses it is a ramp whose rows are all identical, so per-row versus
whole-file is untested. Fine here, but if a later chapter reuses it on a non-uniform image
the reader has a 50/50 guess baked in.

**6. `pixel_at` out of bounds.** Writes outside are pinned by a scenario; reads are not
mentioned at all. I return black. Chapter 6 will hit this.

**7. Does `mix` clamp before encoding in the naive branch?**
§1.5 says "Clamp before you encode, because encode is only defined on 0..1 and will
happily hand you … the square root of something negative if you feed it garbage." The
naive `mix` calls `encode` directly on canvas colors, and §1.2 explicitly permits those to
be negative or above 1. `mix(color(-0.1,0,0), …)` with the switch off produces NaN in a
straightforward implementation. No scenario exercises it, so I left it unclamped and
matching the pseudocode exactly, but the two sections quietly contradict each other.

**8. "if the line would grow past 70 characters" — does the separating space count?**
It has to, and the 10-pixel scenario pins it exactly (67 chars, then break because
67+1+3=71). Unambiguous *after* you check against the scenario; the sentence alone isn't.

---

## Hard to translate

Very little. The scenarios are small and imperative, which suits a C harness.

- **The `Given` after `Then` ordering** in four scenarios (`The gray match, as a file`;
  `One pixel in four`; both reference-comparison scenarios in `limits`; `The plate`) is
  not legal Gherkin ordering — a `Given` appears after `When`/`Then` steps. Cucumber
  tolerates it, but it reads badly and it means the "load the reference file" step can't be
  hoisted into a `Background`. Since the book's own framing is "written in Gherkin, the
  plain-English format that Cucumber runs", these should be `And ref ← read_file(…)` or the
  read should move to the top.

- **`Scenario: Linear blending is on by default`** cannot fail under the harness rule the
  chapter itself mandates two paragraphs earlier ("Reset it before each scenario"). It
  tests my harness, not my renderer. Keep it, but say so — or make it the one scenario
  that runs without the reset.

- **`Scenario: The switch was left on`** builds a 400×180 canvas purely to observe a
  boolean. Cheap enough, but combining it with `The plate` would halve the suite's runtime
  (see Results).

- **Operators.** C has no operator overloading, so `c1 + c2` became `color_add(c1, c2)`
  and `c * 2` became `color_scale(c, 2)`. §1.1 explicitly blesses this. No friction.

---

## Failures

None. 59/59.

Two things worth flagging even though they passed:

**The chapter's tie-breaking claim is wrong.**
> "`round(x)` rounds to the nearest whole number. No test in this book lands exactly on a half, so it doesn't matter which way your language breaks ties."

Ramp column 129 encodes to **188.5006** of 255 — 0.0006 above the tie. Columns 193, 160,
217, 167 and 110 are all within 0.02. Those are inside the spread you get between
`pow` implementations, which is exactly the spread the ±1 allowance exists for. It happens
to be harmless: I checked that flipping *any* single near-tie column still leaves
`distinct_values` at 183, and the reference comparison allows ±1. But the sentence as
written is an overclaim, and `distinct_values(ppm) = 183` is an exact assertion sitting
downstream of eleven near-ties. Reword to "no test lands close enough to a half for tie
direction to matter, and the reference comparisons allow ±1 anyway" — and maybe say you
checked.

**`encode(0.5)*255 = 187.516`**, so the chapter's headline number 188 has 0.016 of margin
against rounding to 187. Double precision has ~5 orders of magnitude of room there, and
even float32 has ~3, so it's safe. But the whole chapter rests on that one rounding, and
it's tighter than a reader would assume from the prose.

**The at-threshold example rows are decorative.**
> "The scenarios test on both sides of both thresholds, because the classic bug is getting the branch backwards"

True for the 0.0025/0.01 and 0.04/0.05 pairs. But the rows *at* the thresholds
(`0.0031308 → 0.0405`, `0.04045 → 0.0031`) can't catch anything: the two branches agree
to 3×10⁻⁸ there, far inside the 10⁻⁴ tolerance. They can't distinguish `<` from `≤`, and
they can't catch a slightly wrong threshold constant. They look like they're testing the
branch and they aren't.

---

## Prose

Clear, and ordered so that each section only needs the one before it. I read it once,
straight through, and wrote the code from it without going back. Specific notes:

- **The §1.5 four-step list is the best thing in the chapter.** "Clamp, encode, ×255,
  round," with the reason for the order stated right after. That paragraph is why my
  output came out byte-identical on the first run.

- **§1.6 needs the range convention earlier.** The `gray_match` pseudocode uses `0..99`,
  and "Ranges in these programs are inclusive at both ends" appears *after* the code block.
  Move it to §1.1 with the rest of the notation, or above the first block that uses it. It
  matters again in `plate_01` (`top .. top + 39`), where off-by-one is a live risk.

- **`plate_01`'s pseudocode uses syntax §1.1 never introduces**: `ramps ← [ (a, b), (a, b) ]`
  and `for i, (a, b) in ramps` are Python destructuring in what is otherwise
  language-neutral notation. Every other block in the chapter uses only assignment, `for x
  in a..b`, and calls. Spelling this one out as two explicit iterations would cost three
  lines and one fewer thing to decode.

- **The gap rows in `plate_01` are stated twice and never quite pinned.** "The five rows
  between the bands, and the five after the last one, stay black" — but there are *three*
  gaps (rows 40-44, 85-89, 175-179), and the sentence describes two of them. It's
  recoverable from the pseudocode, and the scenario checks rows 42 and 87, so nothing broke.
  But "the five after the last one" is doing a lot of work for the trailing gap.

- **"About twenty lines"** for a 12-line pseudocode listing is a small thing but I noticed it.

- **The one genuine stop-and-re-read** was §1.7's naive `mix`:
  `mix(a, b, t) = decode( encode(a) + (encode(b) - encode(a)) * t )`.
  I had to convince myself the outer `decode` was right rather than a typo, because the
  result goes onto a canvas that holds light — and then that it *round-trips* through the
  PPM writer's `encode`, which is why the plate's naive gray midpoint is exactly `t*255`.
  One sentence saying "the naive path decodes back into light because the canvas holds
  light, so the PPM writer will re-encode it and the file value is just the interpolated
  one" would have saved me five minutes and a scratch calculation.

- **The pitch works.** I did not believe 188 before I rendered it, and I did after. The
  ramp section — "183 of them, out of 256 slots" — is the part I'll remember.

---

## Would change

1. **Add a transposition-proof step to `max_channel_difference`,** or add a scenario that
   compares a 5×3 render to a 3×5 one and expects a failure. Right now the book's own
   anti-transposition tool can't see a transposition.
2. **Move "ranges are inclusive at both ends" into §1.1** with the rest of the notation.
3. **Define `every pixel of c is …` and `N pixels of c are …` in §1.1**, and say whether
   the count is exact.
4. **Fix the `Given`-after-`Then` ordering** in the four reference-comparison scenarios.
5. **Say what `ppm_pixel` does about the width token**, since it needs a token it skips.
6. **Soften the tie-breaking claim** in §1.1 (ramp column 129 is 0.0006 from a half).
7. **Drop or annotate the at-threshold rows** in the sRGB outlines; they don't test the
   branch and they imply they do.
8. **State whether `encode`/`decode` may be called outside 0..1**, since `mix`'s naive path
   does exactly that on a canvas §1.2 says may hold 1.7 or -0.5.
9. **One sentence on the naive `mix` round-trip** through the PPM writer (see Prose).
10. **Consider shipping a tiny `ppm_to_png` or a viewer hint.** "Open it at 100% zoom and
    lean back" is the payoff of the whole chapter, and on macOS nothing in the default
    toolchain opens a P3 file. That's a two-minute yak shave sitting directly on top of the
    chapter's emotional beat.

---

## Results

**59 scenarios, 59 passed, 0 failed.** (3 equality + 6 colors + 6 canvas + 22 sRGB
[10 + 8 outline rows + 4] + 7 PPM + 3 gray-match + 7 mix + 3 limits + 2 plate.)

All five renders match the reference files **byte for byte**, not just within ±1:

| render | size | max channel difference vs reference |
|---|---|---|
| `out/gray-match.ppm` | 300×100 | 0 |
| `out/quarter-match.ppm` | 200×100 | 0 |
| `out/ramp.ppm` | 256×32 | 0 |
| `out/clamp-pair.ppm` | 200×100 | 0 |
| `out/plate-01.ppm` | 400×180 | 0 |

**Time: 93 ms total for the suite** (`-O2`, M-series Mac). Hotspots:

| feature | ms |
|---|---|
| Plate 1 | 50.2 |
| The gray match | 30.0 |
| The edges of the range | 12.5 |
| PPM output | 0.1 |
| everything else | < 0.05 |

Nothing here needs optimizing, but the shape is informative: **all of the time is in
`canvas_to_ppm`, `read_file` and `max_channel_difference` on the reference images**, not in
rendering. `plate_01` is built twice (once per scenario) and each build is 400 columns ×
2 bands × 2 mixes of `pow`, then 216,000 numbers formatted and re-parsed, then a 721 KB
reference file parsed. Merging `The switch was left on` into `The plate` would cut the
suite by ~25 ms. `The gray match` costs 30 ms mostly because `gray_match()` runs twice and
`count_pixels` walks 30,000 pixels — again, not the arithmetic.

Total time to implement, from a cold read to green: about two hours, most of it writing
the harness and typing out 59 scenarios rather than reasoning about the renderer. The
renderer itself is 250 lines and none of it was hard. That matches the chapter's "one
evening" claim.
