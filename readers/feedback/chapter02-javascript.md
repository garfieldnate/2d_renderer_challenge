# Chapter 2 Feedback

## Ambiguities

- **P6 header format**: "followed by exactly one newline" could be clearer about whether there's a newline after the last number, or whether the entire header ends with one newline. The spec is correct but tersely stated.
- **Half-plane boundary**: "boundary included" is stated correctly but the dot-product test `>= 0` for a boundary could benefit from a worked example (e.g., a half-plane at x=2.5, what's on the boundary vs inside).
- **Sample points location**: The description doesn't justify why the 8×8 grid uses `(i + 0.5) / 8` (center of sub-cell) rather than cell corners. This is a critical detail that affects results significantly.

## Hard to Translate

- **Byte indexing mismatch**: Gherkin scenarios use 1-indexed byte numbers ("byte 12 of p6") while JavaScript uses 0-indexed arrays. Translating required remembering to subtract 1. A note in the test format spec would help.
- **Integer encoding assumptions**: The code must clamp, encode, scale, and round in that exact order. The PPM spec doesn't enforce order, but it matters here. Chapter 1 does specify it, but it's easy to forget when implementing P6.
- **Reference image comparison**: Comparing with tolerance `<= 1` for binary files works, but there's no guidance on why 1 is the right threshold (rounding error + possible minor implementation differences).

## Failures

- **Initial P6 indexing error**: Test expected `p6[11]=255, p6[12]=0, p6[15]=188` (using 0-indexed) but Gherkin says "byte 12/13/16" (1-indexed). Spent 20 minutes on this.
- **painted_twice logic**: Initially painted the entire canvas twice instead of the right half twice. The Gherkin and HTML both show this clearly, but the phrasing "paint the same shape twice" could be misread as "paint again" (which I did). The HTML reference code is precise: `if (x >= 40)` makes it unambiguous.
- **max_channel_difference on mismatched sizes**: The code only iterated through the first canvas's tokens, so mismatched dimensions silently compared only the common subset. The test expects 255 when dimensions differ, which makes sense—files that don't match are maximally different.

## Mistakes That Stay Green

- **Sample point origin**: If I had used cell corners `(i / 8, j / 8)` instead of `((i + 0.5) / 8, (j + 0.5) / 8)`, all tests would pass but results would be wrong (off-by-half-pixel). The reference images force this to be correct.
- **Coverage division by 63 vs 64**: If I had divided by 63 (one fewer sample), tests would still pass (tolerance is ±0.1 on ink). This is not caught until ink values are very tightly specified.
- **Pixel center definition**: If I had used `(x, y)` instead of `(x + 0.5, y + 0.5)` for rasterize_centers, tests for rectangles on sample boundaries would fail (0.75 instead of 0.5), but the disc test would stay green (would just shift the edge by half a pixel).
- **P6 header whitespace**: If I had written "P6 \n" (space instead of newline after 6), the parser would still work if lenient. The strict header format test catches this, but a more flexible parser would hide the error.

## Prose

- **Section 2.1 (Shapes)**: Clear and direct. The three shapes are well chosen. Good progression from simple (circle) to weird (half-plane).
- **Section 2.2 (P6)**: Could benefit from a byte-level example (show exact bytes of "P6\n2 1\n255\n" + pixel data). Saying "a quarter the size" is correct but "25% of P3 size" might be clearer (and true for small images; for large images, header overhead is negligible).
- **Section 2.3 (Magnify)**: Very clear. The comment about what image viewers do is helpful context.
- **Section 2.4 (Coverage)**: Excellent explanation of pixel-as-square vs point-in-square. Figure 2.1 is key here. The description of the center test is clear. The 8×8 sampling is stated but not justified (why 64, not 16 or 256?). This isn't a flaw, just leaves the reader wondering.
- **Section 2.8 (Putting it together)**: The pseudocode is clean. The commentary about "faster way to compute the same number" is good foreshadowing.

## Would Change

- **Sample count justification**: Explain why 8×8 is chosen (compromise between quality and speed; 64 samples enough for visible differences).
- **Magnify spec**: Explicitly state the output canvas has `width * k` and `height * k` pixels (obvious in hindsight, but helpful upfront).
- **P6 example**: Show the hex dump of a 2×1 red/green canvas in P6 format, with byte positions labeled.
- **Test file format**: Clarify whether Gherkin "byte N" is 1-indexed or the implementation can choose; or just commit to 1-indexed in all test specs.
- **Error handling**: Acknowledge that files with mismatched dimensions should error or be treated as maximally different (document the choice).

## Results

- **Tests**: 60 chapter 1 + 29 chapter 2 = 89 total, all passing.
- **Chapter 1 breakdown**: 3 equality + 6 colors + 8 canvas + 12 sRGB + 8 PPM + 7 gray-match + 6 limits + 7 mix + 2 plate + 1 write = 60 tests.
- **Chapter 2 breakdown**: 4 shapes + 3 P6 + 2 magnify + 6 coverage-buffer + 5 coverage-method + 6 paint + 2 twice + 1 plate + 1 write = 29 tests.
- **File sizes**: P6 disc (320×320, 3 channels) is 307 KB; equivalent P3 would be ~1.2 MB. Magnify introduces a 6× factor (480×240), final P6 output is 330 KB.
- **Visual quality**: The difference between centers and coverage is immediately obvious at 8× magnification. Painting twice visibly thickens the edge without doubling the interior, demonstrating why coverage ≠ opacity.
- **Performance**: Rendering the 320×320 magnified disc takes ~35 ms (dominated by the 8×8 coverage loops, which do 2.56M point-in-circle tests). No performance issues at this scale.

## Summary

Chapter 2 is well-structured and teaches a crucial lesson: rendering isn't binary. The progression from shapes → coverage → painting is logical. The code maps directly to the pseudocode. One small gotcha (byte indexing convention) aside, the material is clear and the tests are thorough. The chapter doesn't ask for anything complex (no anti-aliasing tricks, no acceleration), just brute-force coverage and blending, which is perfect for building intuition before optimization.
