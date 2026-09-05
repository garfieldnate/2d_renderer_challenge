# Chapter 1 feedback — Swift implementation

Toolchain: Apple Swift 6.0.3, plain `swiftc` (no SwiftPM, no dependencies, no network).
`./build.sh` builds `./run`; `./run` runs the scenarios, `./run render` writes `out/`.
Sources in `Sources/{Renderer,Tests,main}.swift`, ~500 lines total.

**All 59 scenarios pass on the first run, and all five renders are byte-identical to the
reference images — not just within the ±1 tolerance, identical.** So the chapter works. Everything
below is about the places where it works despite the text rather than because of it.

---

## Ambiguities

**1. `ppm_pixel` is told to throw away the thing it needs.**
> "`ppm_pixel(ppm, x, y)` splits the text on whitespace, skips the four header tokens and returns
> the three whole numbers at pixel (x, y)."

You cannot compute the index of pixel (x, y) without the width, which is header token 2 — one of the
four you just skipped. I parse the header, keep `width`, then drop the first four tokens. Trivial to
work out, but the one sentence in the chapter that describes the function describes it wrongly, and
it is the function every later chapter depends on.

**2. The 70-character wrap boundary is unspecified *and* untested — and it matters.**
> "before adding a value, if the line would grow past 70 characters, start a new line instead."

"past 70" reads as `> 70` (a 70-character line is legal). But the pinning scenario is a 10x2 canvas
whose longest line is 67 characters, so it cannot discriminate. **I built a variant with `>= 70`
instead of `> 70` and all 59 scenarios still passed** — while its `plate-01.ppm` is byte-different
from the book's reference, because plate-01 is the one image with lines of exactly 70 characters
(240 of them). `max_channel_difference` compares numbers, not whitespace, so it never notices.
A reader who guesses the boundary the other way gets a green suite and a file that is not the
book's. The chapter says "The scenario pins exactly where a ten-pixel row breaks, so there's nothing
to guess." There is exactly one thing to guess, and that scenario doesn't pin it.

**3. `encode` / `decode` are defined on scalars, then applied to colors without comment.**
The srgb feature header says "Both take and return numbers between 0 and 1." Then § 1.7 writes
`mix(a, b, t) = decode( encode(a) + (encode(b) - encode(a)) * t )` where `a` and `b` are colors, and
`encode(b) - encode(a)` is color subtraction. "Both are component-wise" appears in the next
paragraph and is doing a lot of load-bearing work for a throwaway clause. I added `Color` overloads.

**4. "5000 pixels of c are color(1, 1, 1)" — exactly, or at least?**
I read it as exactly (and it is: the checkerboard is 100x100 half-on, the other two thirds are
0.2159 and 0.5). Read as "at least", the step is nearly vacuous. Same for the 2500 in quarter_match.
One word ("exactly") fixes it.

**5. `max_channel_difference` on mismatched dimensions is undefined.**
Not exercised in this chapter, but the chapter promises "every later chapter does too", and the
first time a reader's canvas is the wrong size this function decides what they see. I return 255 as
a poison value; zip-to-shortest would silently report a small difference for a badly-sized render,
which is the worst possible behaviour.

**6. `quarter_match`'s right half is never stated in prose.**
§ 1.6 says "it should match a solid patch of `color(0.25, 0.25, 0.25)`" and then, separately,
"200 by 100, pattern on the left half, solid on the right". Solid *what* is left to inference. The
scenario pins it. Minor, but `gray_match` got full pseudocode and this one got a sentence.

**7. `≤` vs `<` on the tolerance.**
The feature header says `|a - b| ≤ 0.0001`; the prose says "within 0.0001 of each other". Nothing
lands on the boundary — I checked, the tightest sRGB table row is `encode(0.0031308)` at
|d| = 0.0000501, so every row has 2x headroom. Worth one sentence saying the tables were chosen with
headroom, so readers don't chase a marginal failure that isn't there.

**8. The `± 1` is applied inconsistently to `ppm_pixel` steps.**
`chapter01-plate.feature` writes `ppm_pixel(ppm, 200, 20) = (128, 128, 128) ± 1`, but
`chapter01-gray-match.feature` writes `ppm_pixel(ppm, 150, 50) = (128, 128, 128)` with no tolerance,
and both numbers come out of the same `pow`. If cross-language `pow` drift can flip a rounding —
which is the stated justification for `max_channel_difference ≤ 1` — it can flip these too. Either
all the reference-render pixel probes get `± 1` or none do, with an explanation.

## Hard to translate

**Nothing was hard. Three things were mildly annoying.**

- **`Given` steps appearing after `Then` steps.** Four scenarios (gray-match x2, ramp, clamp-pair,
  plate) do `Then …` / `Given ref ← read_file(…)` / `Then …`. Real Cucumber tolerates it; every
  Gherkin linter I've met complains, and it reads like the scenario was edited in two passes. `And`
  would work fine there since `read_file` has no side effects.
- **The global `linear blending` switch needs a Before hook my runner doesn't have.** I wrote
  `linearBlending = true` as the literal first line of all seven mix scenarios plus the two plate
  ones. That's the chapter's own advice, so it's fair, but see "Would change".
- **Swift 6 rejects the mutable global outright.** `var linearBlending = true` at file scope is an
  error under `-swift-version 6` (concurrency-unsafe global). Workarounds are
  `nonisolated(unsafe) var` or a `@MainActor` wrapper, neither of which a reader on chapter 1 wants
  to be reasoning about. I compiled in Swift 5 language mode, which is `swiftc`'s default. Any
  reader who reaches for a SwiftPM package with `swift-tools-version: 6.0` will hit this on their
  first `swift build` and have no idea why.
- Scenario Outlines expanded fine as a loop over a `[(Double, Double)]` array of rows, one
  `scenario()` call per row with the row values interpolated into the test name. No friction.

## Failures

None. 59/59 on the first run, and all five renders are byte-identical to the references, so I have
no disagreement with the book to report. The one thing I'd have liked to be caught and wasn't is
the wrap-boundary variant in Ambiguity 2 — that is a case where the suite is green and the output
is wrong, and it's a gap in the tests rather than a failure of mine.

## Prose

**The ramp's step sizes cost me a re-read.**
> "The dark end of your ramp skips twelve file values in its first step, then eight, then five"

The line right above it is `0 0 0 13 13 13 22 22 22 28 28 28`, whose first differences are 13, 9, 6.
"Twelve, eight, five" is counting *skipped* values (the gaps between, exclusive), which is correct
but is a different quantity from the one the reader is staring at. I computed 13, saw "twelve", and
stopped to check whether the reference file or the prose was wrong. Say "jumps by thirteen, then
nine, then six", or say "skips twelve *intervening* values".

**The plate's black rows are miscounted in prose.**
> "The five rows between the bands, and the five after the last one, stay black."

There are four such gaps, not two: rows 40–44, 85–89, 130–134, 175–179. The sentence describes one
pair and leaves the reader to generalize. The pseudocode is exact, so no harm done, but the sentence
directly under the pseudocode should agree with it.

**0.216 vs 0.2159.** The prose says "Decode 128/255 and you get 0.216" and the PPM scenario writes
`color(0, 0, 0.216)`, while the srgb and gray-match scenarios both use `0.2159`. Both encode to 128
so nothing breaks, but two different numbers are presented as the same constant three sections
apart, and a reader defining `let g = 0.216` for `gray_match`'s middle third will fail the
`pixel_at(c, 150, 50) = color(0.2159, …)` step by 0.0001 — right on the tolerance boundary. Pick one
value or say explicitly that the middle third is `decode(128 / 255)`, computed, not typed.

**Structure was otherwise good.** § 1.4 → § 1.5 → § 1.6 is the right order: you cannot write
`gray_match` before you have `decode`, and you cannot check it before you have the PPM writer. The
"clamp before you encode" paragraph and the "round, don't truncate" warning both landed before I
could make the mistake. § 1.1's notation section is worth its length.

**The opening works.** 128 vs 188 as a hook is genuinely good, and having the reader render the
figure themselves in § 1.6 rather than take the figure on faith is the right call.

## Would change

1. **Add one scenario with a line of exactly 70 characters** so the wrap boundary is pinned. A 24-
   or 25-pixel-wide fill would do it. Right now the wrap rule is the only thing in the chapter you
   can get wrong and still be green.
2. **Fix the `ppm_pixel` description** to say it keeps the width from the header.
3. **`mix(a, b, t, linear:)` with the global as the default value**, rather than a global that
   `plate_01` toggles 1600 times inside its inner loop. The current design makes the "switch was
   left on" scenario depend on the *textual order* of two assignments in a loop body, and it makes
   the whole renderer thread-hostile from chapter 1. Keeping the global as a default argument gives
   you the debugging switch the chapter (correctly) wants, without the ordering hazard.
4. **Say "exactly 5000 pixels"** / "exactly 2500".
5. **Make `± 1` consistent** across all reference-render `ppm_pixel` steps.
6. **Define `max_channel_difference` for mismatched sizes** now, before eight chapters build on it.
7. **Replace the post-`Then` `Given` steps with `And`.**
8. **One line in § 1.4** saying `encode`/`decode` are lifted to colors component-wise, since § 1.7
   uses them that way.
9. **A Swift note** (or a general note for statically-checked languages) that the global switch may
   need an escape hatch — Swift 6 language mode, Rust, and anything with a borrow checker or a
   concurrency checker will all push back on it.
10. **Give `quarter_match` the same two lines of pseudocode `gray_match` got.** It's the one figure
    where the reader has to assemble the spec from three separate sentences.

## Results

| | |
|---|---|
| Scenarios (outlines expanded per Examples row) | **59** |
| Passed | **59** |
| Failed | **0** |
| Total suite time (`swiftc -O`) | **0.72 s** |
| Total suite time (`swiftc -Onone`) | 3.15 s |
| Renders byte-identical to reference | **5 of 5** |

Scenario count by feature: equality 3, colors 6, canvas 6, srgb 22 (10 encode rows + 8 decode rows
+ 4 plain), ppm 7, gray-match 3, mix 7, limits 3, plate 2.

Time hotspots (`-O`), all of them I/O and token-parsing rather than rendering:

| ms | scenario |
|---|---|
| 504 | Plate 1 :: The plate |
| 113 | The gray match :: The gray match, as a file |
| 49 | The edges of the range :: Clamping changes the color |
| 31 | The gray match :: One pixel in four |
| 30 | The edges of the range :: Encoding stretches the dark end |

Everything else is under a millisecond. The five reference-image scenarios are 99% of the runtime,
and nearly all of that is `read_file` plus splitting 216,000 whitespace tokens into `Int`s for
`max_channel_difference`, not the rendering. If chapter 20 has fifty of these, the suite will be
slow for a reason that has nothing to do with the renderer — worth a note that
`max_channel_difference` is worth writing as a streaming comparison rather than two full token
arrays.
