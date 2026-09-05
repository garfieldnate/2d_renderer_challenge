# Chapter 2 feedback

## Ambiguities

- **The pseudocode's loop bounds.** `disc_centers()`, `painted_twice()`, and
  `plate_02()` all write:
  ```
  for y in 0..39:
    for x in 0..39:
  ```
  on 40-wide/40-tall buffers. Read as a half-open range (Rust/Python `0..39`)
  this misses row/column 39 entirely; read as Ruby's inclusive `..` it covers
  all 40. I guessed inclusive — full 40×40 copy — because that's the only
  reading that produces a complete disc, and it's what made the renders
  byte-identical to the reference PPMs. But the book uses `←` for assignment
  (not Ruby syntax) and nowhere else states its range convention, so this was
  a guess confirmed only by the reference image, not by the prose.

- **`center_inside(s, x, y) = 1` / `= 0`.** Every other boolean in this
  chapter and chapter 1 is written `= true` / `= false` (see
  `inside(s, 8, 8) = true` two paragraphs earlier in the same feature file).
  `center_inside` alone uses `1`/`0`. I read it as a boolean and translated
  `center_inside(s, 2, 4) = 1` to `assert!(center_inside(...))`. A stricter
  reading would have `center_inside` return a number, matching coverage's
  0–1 range instead of `inside`'s boolean — the chapter doesn't say why this
  one function breaks the pattern.

- **`max_channel_difference` on mismatched dimensions.** "Sizes still have
  to match" (chapter02-p6.feature) asserts `max_channel_difference(p6a, p6b)
  = 255` for a 2×1 canvas against a 1×2 canvas — same pixel count, transposed
  shape. Nothing in §2.2's prose says what the function should do when
  widths/heights disagree; I inferred "can't be compared, so report maximum
  difference" from the scenario's title and return 255 as a sentinel when
  width or height differs, rather than zipping the raw byte streams
  positionally (which would have given 0, since both canvases start solid
  black). This is a guess about intent, not a transcription.

## Hard to translate

- **Ties to a helper the chapter never names.** Every disc/plate scenario
  compares `ppm_pixel(...)` against a tuple `±1`. Chapter 1's own
  `tests/plate.rs` had already solved this with a local
  `assert_pixel_within` helper; I copied that same helper into every new
  chapter-2 test file (`paint.rs`, `coverage.rs`, `twice.rs`, `plate_02.rs`)
  rather than introduce a shared test-support module, since "one test file
  per feature file" was the mandate and there's no existing convention for
  cross-file test helpers in this package.
- The three named pseudocode functions aren't Gherkin at all — they're prose
  algorithms referenced from inside scenarios (`Given c ← disc_centers()`).
  Translating pseudocode into idiomatic Rust needed judgment calls (see the
  loop-bounds ambiguity above) that a straight Gherkin-to-`#[test]`
  transcription doesn't require anywhere else in the book so far.

## Failures

None. Every scenario passed against the first implementation that matched
my reading of the spec, and all four required renders
(`disc-centers.ppm`, `disc-coverage.ppm`, `painted-twice.ppm`,
`plate-02.ppm`) came out byte-for-byte identical (`cmp`) to
`reference/chapter-02/*.ppm` — not merely within the scenarios' `±1`
tolerance.

## Mistakes that stay green

I deliberately broke six things a reader could plausibly get wrong, ran the
suite after each, then reverted:

| Mistake | Caught? |
|---|---|
| `coverage()` samples cell corners (`i/8`) instead of centers (`(i+0.5)/8`) | Yes — 5/6 `chapter02-coverage` scenarios fail |
| `center_inside`/`rasterize_centers` tests `(x, y)` instead of `(x+0.5, y+0.5)` | Yes — the dedicated "center of pixel" scenario fails, plus the disc-by-centers render and Plate 2 |
| P6 reader off by one byte (forgets to skip the whitespace byte after maxval) | Yes — every scenario that *reads* P6 data fails (the write-only "header, then bytes" scenario doesn't, since it only checks the writer) |
| `magnify` transposes x/y | **Partially.** `chapter02-magnify.feature` catches it directly, and so do `twice`/`plate_02` (80×40 canvases). But `disc_centers()`/`disc_coverage()` are a circle centered on a *square* 40×40 canvas's diagonal — transposing x/y leaves that image pixel-for-pixel identical, so the disc-by-centers and disc-by-coverage render scenarios stay green under this bug. If the book's only worked examples for `magnify` were the discs, this would be a real blind spot; it isn't, because the magnify feature file tests an asymmetric 2×1 canvas directly. |
| `paint_through` ignores the existing pixel (always mixes from black) | Yes — 7 failures across paint/twice/plate_02, including the plain "paint over something that isn't black" scenario, which exists for exactly this reason |
| `coverage()` divides by 63 instead of 64 | Yes — all 6 `chapter02-coverage` scenarios fail, plus twice/plate_02 |

Five of six are caught hard, by design; one (the transpose) is caught only
because the chapter happens to ship a feature file that isn't built from a
symmetric shape. Worth knowing: the chapter's own showcase renders (the
discs) would not have caught it alone.

## Prose

- §2.2's description of the P6 reader ("look at the first two bytes... skip
  the single whitespace byte after the last one") is unusually precise —
  mechanical enough to implement directly without guessing. More of the book
  written at this level of precision would remove most of the ambiguities
  above.
- §2.7 ("Coverage is not opacity") is the best paragraph in the chapter: it
  names the bug before the reader can see it, explains *why* it's not a bug
  in the code, and the `painted_twice` figure lands it. Good sequencing.
- The inconsistency between Gherkin's explicit `true`/`false` and
  `center_inside`'s bare `1`/`0` (noted above) reads like a typo rather than
  a deliberate choice.

## Would change

- Pick one range convention for the book's pseudocode and say so once,
  ideally in the first chapter that uses a loop — "0..39" reading as
  inclusive-both-ends cost real time to resolve and was only confirmed by
  matching the reference PPM, not by re-reading the prose more carefully.
- State explicitly what `max_channel_difference` should do on a dimension
  mismatch, rather than leaving it to be inferred from a scenario's title.
- Either make `center_inside` return `true`/`false` like every other
  predicate in the chapter, or explain why it doesn't.
- A one-line footnote on whether "byte N" in the P6 feature is 0- or
  1-indexed would save a translator the same arithmetic check I had to do
  (byte 12 = index 11 = the first pixel byte).

## Results

- Chapter 1: 59/59 passing (unchanged by this chapter's work).
- Chapter 2: 28/28 passing (matches the 28 `Scenario:` lines across
  `features/chapter02-*.feature`, outlines expanded per row where present —
  there are none in chapter 2).
- Total: 87/87, `cargo test --release`.
- All four required renders are byte-identical to their references, not just
  within tolerance.
- Time: warm `cargo test --release` for the whole suite (both chapters) runs
  in about 0.15s. The same suite in the debug profile runs in about 3.6s —
  roughly 24x slower, dominated by `coverage()`'s brute-force 64
  samples/pixel over the 320×320 and 480×240 disc/plate renders (~6.5M and
  ~4.9M shape queries respectively). Not "slow" in absolute terms at this
  canvas size, but release is clearly the right default going forward, and
  `README.md` says so.
