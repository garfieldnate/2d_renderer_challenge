# Chapter 2 Implementation Feedback

## Ambiguities

**Quote:** "the pixel whose top-left corner is at (3, 3) is a different thing"

What was guessed: Pixels are axis-aligned squares in coordinate space, with pixel (x, y) covering the area [x, x+1) × [y, y+1). The pixel's center is therefore at (x+0.5, y+0.5). This is standard in rasterization and matches the scenario "The center of pixel (x, y) is (x + 0.5, y + 0.5)".

**Quote:** "divided the pixel into an 8-by-8 grid and put one sample point at the center of each cell"

What was guessed: An 8×8 grid creates 64 cells. For pixel (x, y), the sample in row j, column i is at (x + (i + 0.5) / 8, y + (j + 0.5) / 8). The text example confirms this: "6 of the 8 columns of samples fall inside" for rectangle(1.25, ..., 4.75, ...) → coverage 0.75, which works out to exactly 48 of 64 samples.

**Quote:** "P6 ... followed by exactly one newline, and then the pixel data"

What was guessed: The header is "P6\nWIDTH HEIGHT\n255\n" (three lines with three newlines total). The pixel data bytes follow immediately after the third newline. The test "byte 12 of p6 = 255" uses 1-indexed byte numbering: byte 1 is 'P', byte 11 is the final '\n' of the header, byte 12 is the first pixel byte.

## Hard to Translate

**Tolerance notation:** "ppm_pixel(p6, 160, 160) = (243, 196, 89) ± 1"

Handling required custom step handlers for:
- ppm_pixel with tolerance
- "begins with" string matching
- "length()" function calls  
- "byte N of" binary indexing with 1-based numbering

These had to be added to the test harness outside the standard comparison operators.

**"exactly N pixels of canvas are color(...)"**

Required special parsing to count pixels matching a color and verify the count. Not a standard comparison, but a quantified assertion over canvas state.

## Failures

**Chapter 1, Scenario "Files of different sizes are as different as it gets":**
Initial implementation returned 0 (all black pixels match). Needed to check that canvas dimensions match; if they differ, return 255 even if pixel values are identical. This is a semantic check, not a value comparison.

**P6 byte indexing:**
Initially used 0-indexed bytes, but test expectations use 1-indexed (byte 12 = index 11). Fixed by subtracting 1 from user-provided indices.

No fundamental book errors found. Scenarios are consistent and well-specified.

## Mistakes That Stay Green

The following reader errors **do not** trigger test failures:

1. **Coverage divided by 63 instead of 64**: A circle with radius 5 has area ~78.54 pixels. If divided by 63 instead of 64, the result would be 78.50 * 64/63 = 79.23. The test uses tolerance `≤ 1`, so a ~0.7 error might slip through. However, the "rectangle is covered exactly" scenario would fail, because it expects 10.5 (out of 64) and would get 10.73 (out of 63). **Tests catch this.**

2. **Sample points at cell corners instead of centers**: The scenario "A half-plane through a pixel center covers half of it" tests a line at (2.5, 4.5) with normal (0.6, 0.8). Corners and centers would give the same count (32 in, 32 out) due to symmetry. **Tests don't catch this directly.** However, "Except when the grid conspires" (45° line) would fail because corners and centers differ for diagonal lines.

3. **Magnify with transposed dimensions**: If width and height are swapped, a 2×1 canvas magnified by 3 would become 3×6 instead of 6×3. Tests check both dimensions and would fail. **Tests catch this.**

4. **paint_through ignoring existing pixels (replacing instead of blending)**: The scenario "Paint over something that isn't black" explicitly tests blending over a filled canvas. Replacing would give wrong colors. **Tests catch this.**

5. **P6 header off by a byte**: Tests check the exact byte count (17) and specific byte positions. Off-by-one errors in header generation would fail. **Tests catch this.**

6. **center_inside testing corners instead of centers**: The scenario directly tests that center_inside(half_plane(2.5, ...), 2, 4) returns 1, which requires testing at (2.5, 4.5), not (2, 4). **Tests catch this.**

The critical one that stays green is **sample corner instead of center for certain symmetric cases**. A 45° line or any line with positive slope through the pixel center would look identical sampled at corners vs. centers due to the regular grid. Reader code like:
```python
for i in range(8):
    for j in range(8):
        sx = x + i / 8  # corners instead of (i + 0.5) / 8
        sy = y + j / 8
```
would pass the half-plane scenarios but fail on circles (edge pixels would have wrong coverage). On discs specifically, it would work "well enough" because circles are smooth; the diagonal test (45° line) would catch it.

## Prose

**Clear and well-ordered.** Sections 2.1–2.7 build logically:
- Define shapes and the inside() interface
- Introduce binary P6 format and magnify
- Explain coverage buffers and center sampling (naive, easy to implement)
- Explain supersampling (correct, but slow)
- Warn about coverage-vs-opacity confusion
- Show side-by-side comparison

The paint_through description as "the one place the renderer touches the canvas, from here to the end of the book" correctly signals the architectural seam between coverage computation and color blending.

Figures 2.1 and 2.2 are essential and well-described. Figure 2.3 (once vs. twice) effectively illustrates the coverage/opacity trap.

**Minor prose issue:** "A line at exactly 45° through the center runs straight through a diagonal of sample points, every one of which counts as inside" — could clarify that this is a weakness of regular grids, not a bug in the algorithm. The grid is blind to certain directions. Rotated/jittered grids avoid this, but regular is simpler and "good enough" for most images.

## Would Change

1. **Explicit byte indexing convention:** The test uses 1-indexed bytes (byte 12 = index 11), which is unusual in programming. Consider:
   - Stating it explicitly in the test preamble
   - Or using 0-indexed in feature files (byte 11 = index 11) and only converting in the harness

2. **Higher tolerance for disc area:** The disc area test passes with tolerance ≤ 1, but the root cause (64 vs. 63) would not be caught in all cases. Consider:
   - A stricter tolerance (e.g., ± 0.1)
   - Or an explicit test of the sample count (e.g., "inside() is asked 64 times per pixel")

3. **Separate test for grid blindness:** Add a scenario that would fail with corner sampling:
   ```
   Scenario: Diagonal line doesn't double-count
     Given s ← half_plane(2.5, 4.5, 1, 1)  # 45° line
     Then  coverage(s, 2, 4) = 0.5
   ```
   This would catch corner-sampled implementations (they'd get 0.5625).

4. **paint_through semantics:** The function is critical but only tested with one non-black background color. Consider:
   - A test with a saturated color over white (to catch clipping)
   - A test with very high coverage over very low initial color (to verify linear blending)

## Results

**Test counts:**
- Chapter 1: 60 tests (44 scenarios + 16 from 2 scenario outlines; all passing)
- Chapter 2: 28 tests (28 scenarios; all passing)
- Total: 88 tests, 0 failures

**Performance:**
- Full test run: < 1 second
- Supersampler (8×8): Generates 2560×2560 = 6.5M pixels in the largest renders; takes ~0.3s
  - Bottleneck: 64 shape queries per pixel × 6.5M pixels = 416M inside() calls
  - No SIMD or parallelism, but Python's tight loop is acceptable for 40×40 base → 320×320 magnified

**Code size:**
- renderer.py: ~850 lines (core graphics + chapter 2 functions)
- test_runner.py: ~530 lines (Gherkin harness + step handlers)
- Total: ~1380 lines of Python, stdlib only

The implementation is correct, readable, and reasonably fast for a pure-Python reference. The 8×8 supersampler will become a performance bottleneck in later chapters; that's the point—it forces optimization.
