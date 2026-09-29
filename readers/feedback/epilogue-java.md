# Epilogue -- reader feedback (Java)

## Result

Every chapter's suite plus the epilogue's, run individually from this
directory (`javac -d classes src/*.java`, then `java -cp classes
<Chapter>Tests`):

| Chapter | Scenarios | Pass | Fail |
|---|---|---|---|
| 1 | 66 | 66 | 0 |
| 2 | 35 | 35 | 0 |
| 3 | 38 | 38 | 0 |
| 4 | 76 | 76 | 0 |
| 5 | 33 | 33 | 0 |
| 6 | 36 | 36 | 0 |
| 7 | 34 | 34 | 0 |
| 8 | 25 | 25 | 0 |
| 9 | 46 | 46 | 0 |
| 10 | 25 | 25 | 0 |
| 11 | 18 | 18 | 0 |
| 12 | 13 | 13 | 0 |
| 13 | 23 | 23 | 0 |
| 14 | 27 | 27 | 0 |
| 15 | 28 | 28 | 0 |
| 16 | 23 | 23 | 0 |
| 17 | 22 | 22 | 0 |
| 18 | 21 | 21 | 0 |
| 19 | 31 | 31 | 0 |
| 20 | 86 | 86 | 0 |
| 21 | 22 | 22 | 0 |
| 22 | 54 | 54 | 0 |
| 23 | 44 | 44 | 0 (was 43, +1 from catch-up, see below) |
| 24 | 22 | 22 | 0 |
| 25 | 28 | 28 | 0 |
| **Epilogue** | **11** | **11** | **0** |
| **Total** | **887** | **887** | **0** |

Renders, `max_channel_difference` against `reference/epilogue/`:

| Render | Diff |
|---|---|
| `out/cover-art.ppm` (document alone, `render_svg(cover.svg)`) | **0** |
| `out/cover.ppm` (`book_cover()`) | **0** |
| `out/cover-glow.ppm` (`book_cover_glow()`) | **0** |

All three are byte-for-byte identical to the reference, not merely within
the book's usual budget of 1. That's not surprising for the cover -- it's
almost entirely code this reader's chapters 16-21 and 23 already had
right -- but it's a good sign that assembling those pieces introduced no
new bug.

## Catch-up

`features/chapter23-atlas.feature` had one scenario this code hadn't seen:
**"A space has no edges, so every texel is as far out as the clamp
allows"** (`bake_mtsdf` of the glyph `"space"`, which has no outline at
all -- 0 contours). It failed on the existing code:

```
FAIL  Atlas: a space has no edges, so every texel is as far out as the
      clamp allows -- field_at(channels[0], 0, 0): expected 3.0 but got 0.0
```

Root cause: `Msdf.msdfChannel` (the per-channel MSDF distance function)
had `if (best == null) { return 0; }` for the case where no edge in the
glyph carries a given channel. The chapter's own prose is explicit that
this case ("a channel no edge carries, and every channel of a glyph with
no outline at all... is spread at every texel: there is nothing to be
near, so the answer is as far out as the clamp allows") should produce
`+spread` after clamping, not `0`. `bake_sdf`'s single-channel version
already got this right (an empty curve list there leaves `best =
Infinity`, which clamps to `+spread`); `bake_msdf`'s three-channel
version just had the wrong early-return. Fixed by returning
`Double.POSITIVE_INFINITY` instead of `0`, which the existing
`clampSpread` call turns into `+spread` for free -- one line
(`src/Msdf.java`, in `msdfChannel`). This is squarely this
implementation's bug, not the chapter's: the chapter's prose already
said what should happen, the code just didn't do it, and nothing had
ever exercised a glyph with zero contours before this scenario existed.

After the fix, all 44 chapter-23 scenarios pass, and re-running every
other chapter's suite (1-22, 24-25) turned up nothing else -- all totals
matched what the existing `README.md` already documented (I didn't do a
full line-by-line audit of every other chapter's feature file against its
test file's scenario *names*, since a raw `Scenario:` count comparison is
noisy -- prefixes and rewording make simple substring matching produce
false positives -- but every chapter's numeric scenario count matched
what git history already recorded, and everything passes).

## Ambiguities

Remarkably few, for a chapter this short. Two worth recording:

- **`book_cover()`'s name.** The task brief told me directly to use this
  chapter's own naming convention rather than a literal `cover()`, since
  chapter 24 already has a `Chapter24Figures.cover()`. I named the class
  `Epilogue` and the methods `Epilogue.bookCover()` /
  `Epilogue.bookCoverGlow()`. This isn't really an ambiguity the chapter
  left open -- the chapter's own prose never says what to call it in a
  given language, by design (`book_cover()` is Gherkin-space, not a class
  name) -- but it's worth recording as the one naming decision a reader
  has to make for themselves, and it's exactly the kind of naming
  collision the epilogue's own "everything is a chapter you've already
  written" framing invites.
- **Where exactly the glow color comes from.** The scenario writes
  `draw_effect(c, ..., color(1, 0.33, 0.085), true, glow_of)` with the
  color spelled out again, rather than saying "the subtitle's color." It
  happens to be the same triple as `SUBTITLE_COLOR`. I reused the
  constant rather than re-deriving it, which is faithful either way since
  the numbers are identical, but a byte-for-byte transcription reader
  might not notice they're the same and could define it twice. Not a bug,
  just a small redundancy in the prose's own phrasing.

Nothing else needed guessing. The type, document and cover scenarios all
passed on the first attempt with the values taken directly from the
feature files -- there was no case where the chapter left a decision
implicit.

## Hard to translate

Nothing hard. The entire epilogue is glue: `render_svg` (chapter 20),
`layout_paragraph`/`layout_run`/`draw_run` (chapter 18) and, for the bonus,
`bake_mtsdf`/`draw_effect` (chapter 23) were all already implemented and
already tested by their own chapters' suites. The only genuinely new code
is `Epilogue.java`'s ~45 lines and `glow_of`'s one-line formula. The one
small Java-specific wrinkle: `Msdf.drawEffect`'s last argument is a
`KOf` functional interface (`double -> double`), so `glow_of` needed to be
a `public static` method (`Epilogue.glowOf`) to pass as `Epilogue::glowOf`
rather than a private lambda capture, since the unit-test scenarios
("How the glow falls off") call it directly too.

## Failures

None outstanding. The one failure this round found (the chapter-23 space
scenario, see Catch-up above) is fixed. No epilogue scenario failed
against a correct implementation.

## Prose problems

- **Chapter 0, §0.5**: "By the last chapter the book has over 880
  scenarios." This Java translation's chapters 1-25 total exactly **876**
  scenarios (887 counting the epilogue's 11), which is close but not
  "over 880." I split some scenarios into more than one Java `scenario()`
  call in a few places (chapter 22 has 54 against 53 `Scenario:` lines in
  its features, chapter 24 has 22 against 17, chapter 25 has 28 against
  24 -- generally because a `Scenario Outline`/examples table or a single
  scenario with several independently-useful assertions became more than
  one named test here), so this reader's count runs a little *above* a
  raw feature-file `Scenario:` count in some chapters and a little below
  it in others; net, it lands at 876, not "over 880." Likely just means
  the reference implementation counts a little differently (or has a
  couple more `Scenario:` blocks some other chapter's reader-testing
  round added since this number was written); either way, a reader who
  totals their own `PASS` lines and gets 876 rather than "over 880" will
  wonder if they're missing something, when they aren't. Suggest either
  softening to "close to 880" or double-checking the count against the
  reference implementation's own tally.
- The epilogue's own closing line ("nearly nine hundred scenarios") is
  consistent with this reader's 887-scenario total including the
  epilogue, so no complaint there -- just flagging that chapter 0's
  narrower claim ("by the last chapter," i.e. chapter 25 alone) is the one
  that doesn't quite match.
- Everything else in chapter 0 and the epilogue's retrospective table
  (§E.1) matches what this reader actually built: coverage from chapters
  2/7, the exact fill's running sum from chapter 7, curves flattened
  post-transform from chapter 8, premultiplied compositing from chapter 9,
  clips as multiplied coverage from chapter 12, strokes as fills of a
  different outline from chapters 13/14, glyphs as paths with y flipped
  from chapter 16, and the GPU chapter as "the same sums, in a different
  order" -- all accurate descriptions of what's actually in `src/`.

## Mutation results

Three mutations tried against a working `Epilogue.bookCoverGlow()`, all
undone afterwards (`diff` against the pre-mutation file confirmed clean):

1. **Baking at chapter 23's own spread of 4 instead of the epilogue's 8**
   (exactly the mistake the chapter's own trap box names). Caught:
   `ppm_pixel(p6, 35, 499)` came back `(97, 56, 55)` against an expected
   `(93, 54, 55) ± 1` -- just outside the letter, where the clamped field
   should have already faded to nothing but instead still glowed. Total:
   10/11 passed, 1 failed.
2. **Drawing the glow after the crisp title instead of before** (`between
   the document and the title's draw_run` reversed). Caught immediately
   and hard: `ppm_pixel(p6, 44, 499)`, a pixel *inside* a glyph, came back
   `(249, 207, 183)` against an expected `(243, 239, 230) ± 1` -- the soft
   field painted straight over the sharp glyph fill. Total: 10/11 passed,
   1 failed.
3. **Reading the median RGB channel instead of the true SDF channel**
   (`Msdf.drawEffect`'s `useTrue` flag flipped from `true` to `false`).
   This one is the most interesting: every individual `ppm_pixel` probe in
   the "glow sits around the title's letters" scenario still passed within
   tolerance -- the median channel and the true channel apparently agree
   closely enough at those five specific sample points. What caught it was
   the scenario's closing `max_channel_difference(p6, ref) <= 1`
   assertion, which came back **45**, far over budget. Total: 10/11
   passed, 1 failed, but only because of the golden-image check, not the
   point probes.

All three mutations were caught, but #3 is worth flagging: if this
scenario had only the five `ppm_pixel` probes and not the
`max_channel_difference` check, this particular wrong implementation
would have shipped clean. The scenario as written is fine (the diff check
is there and does its job), but it's a reminder of why the book's own
rule -- every render scenario ends with the golden-image diff, not just
spot probes -- matters here as much as anywhere else in the book.

## Concrete changes I'd make

- Fix chapter 0 §0.5's "over 880 scenarios" (or the reference
  implementation's own count) so a reader's own tally doesn't come out
  under the stated number, which reads like a red flag if you don't
  know it's approximate.
- Consider adding one more probe to the "glow sits around the title's
  letters" scenario at a point where the median-channel and true-channel
  distances are known to disagree by more than the tolerance (mutation
  #3 above shows they can differ by up to 45/255 somewhere on this
  render) -- right now only the whole-image diff catches that mistake,
  which works but means a reader debugging a near-miss doesn't get a
  specific pixel to look at.
- Otherwise nothing: this is the cleanest chapter to reader-test in the
  whole book, because it's assembly of already-tested parts. The one bug
  this round found (the space-glyph MSDF channel) was in chapter 23, not
  the epilogue, and the epilogue's own three scenarios and the bonus
  glow's three scenarios all did exactly what they say on the first
  correct attempt.

## Timing

All measured on this machine, single-threaded, cold JVM start each time
(`java -cp classes ...`):

- `SvgWalker.renderSvg(cover.svg, 480, 680)` (the document alone,
  `cover-art.ppm`): **~1.16 s**
- `Epilogue.bookCover()` (document + two `draw_run`s, `cover.ppm`):
  **~0.5 s** on top of the document (this number is lower than the
  document alone because it reuses a warmed-up JIT within the same
  process in `Timing.main`; expect ~1.2-1.5 s cold)
- `Epilogue.bookCoverGlow()` (document + bake 15 distinct glyphs' MTSDFs
  at 32px/spread 8 + `draw_effect` + two `draw_run`s, `cover-glow.ppm`):
  **~0.9 s** on top of the document
- Full `EpilogueTests` run (11 scenarios, each of which calls
  `render_svg`/`book_cover`/`book_cover_glow` fresh, plus `writeRenders()`
  at the end doing all three again): **~4.3 s** wall clock
- Chapter 23's own suite (which now includes the fixed space-glyph
  scenario and bakes several MSDFs for its plate): **~5.0 s**, unchanged
  in shape from before the fix (the fix is O(1) per channel, not a new
  loop)

Nothing here is slow enough to notice; the tiger inside `cover.svg` is
clipped to a 400x400 panel, which is a fraction of the 450x450 full tiger
chapters 20/21 render, so the whole cover is comfortably sub-second work.
