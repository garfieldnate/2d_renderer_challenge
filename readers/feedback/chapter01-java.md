# Feedback — Chapter 1, "The Canvas and the Color" (Java 21 reader)

## Ambiguities

- **"5000 pixels of c are color(1, 1, 1)"** — this counts white pixels over the *whole* 300×100 canvas, but the checkerboard pattern only occupies the left 100×100 third; the middle and right thirds are solid gray, never pure white. I assumed the count is meant over the whole canvas (which happens to equal the count over just the checkerboard third, 5000 of 10000 checkerboard cells, since the other 20000 pixels are gray, not white, and contribute zero). It works out, but the step reads as if it's scanning the whole canvas for a color that structurally can only appear in one third of it. A clearer scenario would say "5000 of the 10000 pixels in the checkerboard third."
- **Quarter-match pattern boundary** — "white when x + y is a multiple of 4" is unambiguous arithmetically, but nothing in the prose or scenario explicitly says whether 0 counts as "a multiple of 4" (it does, mathematically, and `pixel_at(c, 0, 0) = color(1,1,1)` confirms it) — a reader without that scenario line might reasonably guess the pattern starts "off." Not a real ambiguity given the test, but worth noting it's the test, not the prose, that resolves it.
- **`round(x)`** — "rounds to the nearest whole number… no test in this book lands exactly on a half, so it doesn't matter which way your language breaks ties." True for this chapter's fixed inputs, but it's a soft guarantee resting on the author having checked the numbers, not on anything structural. I used `Math.round` (round-half-up for positive values), which is fine here, but the prose doesn't tell an implementer what to do if a future chapter's numbers *do* land on a half — worth flagging that the promise is chapter-scoped, not permanent.
- **`ppm_pixel`/`max_channel_difference` are described only in prose** ("splits the text on whitespace, skips the four header tokens…"), never as a step in `chapter01-ppm.feature` that pins the header-token-count itself. It's inferable (P3 / width height / maxval = 4 tokens) and it worked first try, but a one-line scenario asserting the token count would have removed the last bit of guessing.

## Hard to translate

- **Scenario Outlines** — Gherkin's `Examples:` tables don't have a first-class equivalent in a hand-rolled Java runner. I expanded each row into its own named scenario via a loop over a `double[][]` table at registration time, which reproduces "one test per example row" faithfully, but the test names ("light=0.216") are the least human-readable part of the suite compared to the rest, which read as prose. A framework with real parameterized-test support (JUnit5's `@ParameterizedTest`, TestNG) would have made this section nicer without changing the logic at all.
- **The global `linear blending` switch** — Gherkin's implicit "every scenario that doesn't say otherwise expects it on" rule has to be enforced procedurally in a hand-rolled runner (I reset `Mixer.linearBlending = true` before every scenario body executes). That's a natural translation, but it's state a real Cucumber `Before` hook would express declaratively; here it's just a line in the harness loop that's easy to forget if someone adds a new scenario file later.
- **"every pixel of c is X"** — not a named function anywhere in the API the chapter defines (`pixel_at` is 1-at-a-time), so each scenario using that phrase needed a manual double loop in the test body rather than a single assertion call. Fine for a 10×20 canvas; would be worth a real helper (`assertAllPixels(canvas, color)`) if later chapters lean on this phrasing more.

## Failures

None. All 59 scenarios pass, and all five reference PPMs (`gray-match`, `quarter-match`, `ramp`, `clamp-pair`, `plate-01`) come out byte-for-byte identical to the shipped references, not just within the ±1 tolerance the scenarios allow.

## Prose

- The chapter is well-ordered and each section's code block maps straight onto its feature file; I never had to jump backward to find a definition. The one place I re-read twice was the **PPM line-wrapping rule** ("if the line would grow past 70 characters, start a new line instead") — "would grow past" is slightly ambiguous between "exceeds 70" and "reaches 70," and the worked example in the `chapter01-ppm.feature` scenario (lines wrapping at exactly 67 characters, one 3-digit token short of 71) is what actually pins the `> 70` vs `>= 70` question, not the prose. The prose alone would let a careful reader implement either `<= 70` or `< 70` as the packing limit and only the test catches the off-by-one.
- The sRGB section's mnemonic ("Decode 128/255 and you get 0.216... Encode 0.5... you get 0.7354, which is 188 out of 255") is good motivation but uses 4-significant-figure numbers in prose (0.216, 0.7354) while the feature file's table uses the same numbers to 4 decimal places (0.216, 0.7354) — consistent, just worth noting the prose numbers and the test numbers are the same numbers, which is reassuring but not stated outright.
- `plate_01`'s pseudocode was the one snippet I had to read three times, mostly because of notation compression: `for i, (a, b) in ramps:` and `linear blending ← off` reads like assignment-as-statement rather than a function call, and it's the only place in the chapter using that "arrow assigns a global" idiom for something that's actually a side-effecting call (`Mixer.linearBlending = false`). Once translated it's exactly what's needed, but it's a small notation jump from "arrow assigns a local" everywhere else in the chapter.

## Would change

- State the header-token count for `ppm_pixel`/`max_channel_difference` explicitly (four tokens: magic, width, height, maxval), or better, put a one-line assertion of it in `chapter01-ppm.feature` — it's the one implementation detail in that section left entirely to prose with no pinning test.
- Add a `distinct_values` and `ppm_pixel` sanity scenario against a tiny hand-computed PPM (2–3 pixels) before the reader is asked to use both functions against 100×100+ generated images — right now the first real exercise of both functions is also the first reference-image comparison, so a mistake in either function is hard to separate from a mistake in the renders themselves.
- Consider naming the scenario-outline examples in the sRGB feature file (Cucumber supports a name column) so a translated-language test gets a readable name instead of raw input values — minor, but it's the one section whose test names feel mechanical rather than descriptive.
- The "5000 pixels of c are white" step would be clearer as "5000 of the 10000 pixels in 0 ≤ x < 100 are white," scoping the count to the region where white pixels can actually occur, rather than implying a scan of the full 300-wide canvas.

## Results

- **Total scenarios: 59. Passed: 59. Failed: 0.**
  - Breakdown: equality 3, colors 6, canvas 6, sRGB 22 (10 encode + 8 decode outline rows + 4 standalone), PPM 7, gray-match 3, limits 3, mix 7, plate 2.
- **Renders**: all five (`gray-match`, `quarter-match`, `ramp`, `clamp-pair`, `plate-01`) written to `out/` and byte-identical to `reference/chapter-01/*.ppm`.
- **Time**: whole suite runs in well under half a second (~0.4s including JVM startup); no hotspots. The heaviest single scenario is the plate (400×180, mixed twice per pixel, both blend modes) and it's still instantaneous. This was, as promised, an evening's work — implementation across 7 small files (~360 lines total, excluding the test harness) took under two hours including reading the chapter closely enough to write this feedback.
