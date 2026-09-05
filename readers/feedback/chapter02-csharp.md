# Chapter 2 feedback

## Ambiguities

- **1-based byte indexing.** "byte 12 of p6 = 255" never states whether byte 1 is the first byte. Chapter 1 established 1-based line access (`Line(ppm, oneBasedNumber)`), so I assumed the same for bytes and it worked out (`Ppm.Byte`, mirroring `Ppm.Line`). Worth saying once, explicitly, since a byte offset is exactly the kind of thing that's fatal to get backwards.
- **"Skip the single whitespace byte after the last one"** (§2.2) — "the last one" is the maxval token, confirmed only by knowing the PPM format already, not by anything in the scenario text. The scenario itself (`p6 begins with "P6\n2 1\n255\n"`) does pin it down if you write the header text out fully, so this is a minor ambiguity, resolved by the example.
- **Read contract for `coverage_at`/`pixel_at` on out-of-bounds.** The chapter specifies writes outside a buffer are dropped, but never says what a read outside the buffer does. I followed Canvas's existing precedent (`PixelAt` has no bounds check at all) and gave `CoverageAt` the same non-defensive behavior. This only works because `paint_through` is always called with a canvas and coverage buffer of identical size in every scenario — nothing forces that pairing, and nothing tests a mismatched pair.
- **"exactly 9 pixels of m are color(1, 0, 0)"** (magnify) — "exactly" is ambiguous between float-tolerant equality and literal `==`. I reused chapter 1's tolerance-based counting idiom (`Check.NumbersEqual`) rather than bit-exact comparison, consistent with how chapter 1's plate tests counted white pixels.

## Hard to translate

- `disc_centers()`, `painted_twice()`, `plate_02()` are plain pseudocode, not Gherkin — they're referenced from a scenario step (`Given c ← disc_centers()`) but defined in prose above it. Translating them was mechanical, not ambiguous, but it's extra work outside the Given/When/Then vocabulary the rest of the chapter uses, and it's easy to transcribe a loop bound wrong by hand. (I didn't, but it's the one place a translator supplies logic the feature file doesn't pin down step-by-step.)
- The P6 reader needs a byte-level header tokenizer distinct from chapter 1's "split the whole string on whitespace" parser, because a P6 pixel byte can *equal* a whitespace character (10, 32, 13, 9) and corrupt a naive split. None of the four reference images happen to contain such a byte in a position that would expose a naive implementation, so this correctness requirement is stated in prose ("look at the first two bytes... skip the single whitespace byte") but not actually exercised by any scenario. A reader who tokenized P6 the same way as P3 would still pass every test in this chapter.

## Failures

None. Every scenario in every `chapter02-*.feature` file passed on the first run, and all four `out/*.ppm` renders are byte-for-byte identical to the reference files (`cmp` clean). No book-vs-implementation mismatch to report this chapter.

## Mistakes that stay green

I mutated the implementation six ways to see what the suite would miss:

1. Sample points at cell corners (`i/8`) instead of centers (`(i+0.5)/8`) — caught, 7 failures.
2. Testing pixel corner `(x, y)` instead of center `(x+0.5, y+0.5)` in `rasterize_centers` — caught, 4 failures.
3. P6 header missing its trailing newline (off by one byte) — caught hard: 8 failures, several as raw overflow exceptions rather than clean assertion mismatches, because the header parser then reads a pixel byte as part of the maxval token.
4. `paint_through` mixing from black instead of the canvas's existing pixel — caught, 7 failures, and precisely by the scenarios that exist for this ("Zero leaves it alone...", "painted twice, is three quarters").
5. Coverage divided by 63 instead of 64 — caught, 8 failures.
6. Magnify with x/y transposed — caught overall (`chapter02-magnify` failed straight away on its 2×1, deliberately non-square fixture), **but** with one real blind spot: the `disc_centers()`/`disc_coverage()` picture scenarios (chapter02-paint / chapter02-coverage) did **not** notice the transpose. Both discs are circles centered on the diagonal of a square canvas, and a circle centered on the diagonal is symmetric under swapping x and y — so every spot-pixel check and the full `max_channel_difference` against the reference PPM come out identical whether or not the magnifier is transposed. It's only caught because `chapter02-magnify.feature` tests magnify in isolation on an asymmetric 2×1 canvas, and because `painted_twice()`/`plate_02()` place their discs off-center in an 80×40 (non-square) canvas. If a reader trusted only "does my disc picture look right" and skipped the plain magnify unit tests, this bug would ship invisibly in half the renders.

## Prose

Genuinely good chapter — the pixel-isn't-a-point framing in the opener and §2.7's "coverage is not opacity" are the two strongest passages in the book so far, because they name a *mechanism* for the bug rather than just warning "here's a gotcha." A few small things:

- The disc's ink is asserted twice in the same scenario, `= 78.5` (default ±0.0001 tolerance) and again `= 78.5398 ± 0.1`. The surrounding prose explains why both are worth showing (staircase count vs. true area), so it's not actually redundant, but it reads oddly close together on the page — a sentence tying the two assertions together explicitly, right at the scenario, would save a re-read.
- Four separate render scenarios (disc-by-centers, disc-by-coverage, painted-twice, plate) each pair a few spot-pixel checks with a full `max_channel_difference ≤ 1` against the reference file. The full-file diff already subsumes the spot checks — nothing the spot checks catch, the file diff doesn't also catch, in every case I tried. They're good for narrating *why* a scenario failed if it does, so I wouldn't cut them, but a one-line note admitting they're diagnostic sugar over the real assertion (the file diff) would be honest about the redundancy.
- The chapter never says out loud that a circle centered on a canvas's diagonal is transpose-symmetric — which is exactly why the isolated magnify tests, not the picture tests, are what protect against a transposed magnifier. Worth a one-line footnote; see "Mistakes that stay green" above.

## Would change

- State the 1-based byte/line indexing convention explicitly once (a "note about the book itself" aside would do it), instead of leaving it to be inferred from chapter 1's precedent.
- Give `coverage_at`/`pixel_at` an explicit out-of-bounds read contract, even if it's just "undefined — callers are expected to only read in bounds," so `paint_through`'s implicit same-size assumption isn't left to a translator's guess.
- Add a footnote (or a scenario) calling out that the picture-comparison scenarios can't detect a transposed magnifier when the shape is centered on the canvas's diagonal, and that this is exactly why the plain `magnify` scenarios exist on a non-square canvas.

## Results

- Chapter 1: 60/60 passing (unchanged baseline, re-verified before and after chapter 2 work).
- Chapter 2: 28/28 passing (all new).
- Total: 88/88 passing.
- All four required renders (`out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`, `out/plate-02.ppm`) are byte-for-byte identical to `reference/chapter-02/*.ppm`.
- Time hotspot: not the math — every shape/rasterizer/paint/magnify function matched the book on the first run. The real time went into `Ppm.cs`: designing a single `PpmPixel`/`DistinctValues`/`MaxChannelDifference` API that accepts P3 text, P6 bytes, or a mix of both (as `chapter02-p6.feature` requires directly comparing a P3 and a P6 file) without touching a single existing chapter 1 call site. The `PpmData` implicit-conversion wrapper made that free once found, but finding it took longer than writing the rasterizer. Second hotspot: the byte-level P6 header tokenizer, needed because pixel bytes can collide with whitespace byte values and a naive whitespace-split (chapter 1's approach) would corrupt the parse — not tested by any scenario, but necessary for correctness (see "Hard to translate").
