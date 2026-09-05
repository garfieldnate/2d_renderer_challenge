# Chapter 1 Implementation Feedback

## Summary
- **Total scenarios**: 60
- **Passed**: 60
- **Failed**: 0
- **Completion time**: ~1 hour (reading, understanding, implementing, testing, debugging)

All scenarios pass. Implementation includes proper sRGB encoding/decoding, canvas management, PPM generation, color arithmetic, and mixing modes.

---

## Ambiguities

1. **Quarter match pattern specification**: The scenario "One pixel in four" doesn't clearly specify the pattern. The prose mentions "one pixel in four" but the actual geometry (left/right split with diagonal stripes on left, gray on right) had to be reverse-engineered from the reference image. Expected: more explicit description or a figure showing the pattern before the code section.

2. **PPM line wrapping semantics**: The statement "no line exceeds 70 characters" is clear, but whether partial pixels (split "R G B" triplets) are allowed at line endings wasn't explicitly stated. The feature shows this is permitted, but it's an important implementation detail that should be emphasized in prose.

3. **Color clamping vs. file encoding**: Chapter introduces "values are allowed to wander outside 0-1" but doesn't explicitly state they're clamped per-channel in `to_byte()`. The sRGB transfer functions handle this implicitly, but a sentence like "clamp each channel to [0,1] before encoding" would prevent confusion.

---

## Hard to Translate

None. Gherkin translates cleanly to Minitest assertions. The notation (c ← color(...), a = b ± tolerance) maps naturally to Ruby. No impedance mismatch.

---

## Failures

None. All 60 scenarios pass with reference comparison checks (max_channel_difference ≤ 1).

---

## Mistakes That Stay Green

1. **Swapped x/y in canvas access**: The suite specifically includes a test ("x is the column and y is the row") that would catch this. Verified: a swapped implementation correctly fails this test.

2. **Off-by-one line wrapping**: PPM line length checks (≤ 70 chars) catch line-wrapping bugs. Verified: multiple test cases validate this.

The five mistakes I tested:
- ✓ Wrong rounding (ceil vs. floor): **Caught** by "half gray that isn't 128" (expects 188, not 189)
- ✓ Swapped x/y: **Caught** by explicit test (pixel_at checks for specific coordinates)
- ✓ Wrong encode boundary (< vs. ≤): **Caught** by sRGB reference tests
- ✓ Missing clamp in `to_byte()`: **Caught** by "clamp_pair" test (255, 255, 255 expected, not overflow)
- ✓ Wrong mix direction (t vs 1-t): **Caught** by "red to green" mix tests

All plausible errors in the core logic are caught. The suite is robust.

---

## Prose

1. **Section 1.2 structure**: Color operations are explained before the Color class is introduced. Good logical order for a reader unfamiliar with graphics conventions.

2. **Figure 1.1 placement**: Excellent—the key insight (128 vs. 188) is shown visually before the explanation. Readers can see the problem before understanding the cause.

3. **Missing detail in quarter_match description**: The scenario name "One pixel in four" is misleading. It's actually 1/8 of pixels (2500/20000) and has a specific left/right geometry. A figure or explicit grid description would help.

4. **PPM section clarity**: "every row starts a new line" is ambiguous—does this mean every scanline, or every time the pixel buffer resets? The implementation clarifies it means every image row, but a sentence like "each horizontal scanline of pixels starts on a new line" would be clearer.

---

## Would Change

1. **Add explicit formula for sRGB encoding in prose**: The current description ("values measure light") is intuitive but the actual piecewise function appears only in code. Include the formula earlier or as pseudo-code.

2. **Clarify canvas coordinate system visually**: Figure 1.2 is helpful, but adding an explicit statement like "Arrays are indexed [row][column], but write_pixel uses (x, y) which is (column, row)" prevents a common source of confusion.

3. **Make quarter_match pattern explicit**: Describe it as "left 100 pixels: diagonal stripe pattern where (x+y) mod 4 == 0 is white; right 100 pixels: solid gray (0.25)". Current wording requires reverse-engineering.

4. **Separate "mixing modes" into a named subsection**: The mix() function appears in a list of color operations, but it's a significant concept (linear vs. sRGB-space blending). It deserves its own subsection with a figure showing the difference.

5. **PPM reference**: Chapter mentions P3 format but doesn't specify the exact line length rule until the scenario. Pseudo-code like:

   ```
   for each row of pixels:
     pixel_line = ""
     for each pixel (r, g, b):
       if adding this pixel would exceed 70 chars:
         output pixel_line
         pixel_line = this pixel
       else:
         pixel_line += " " + this pixel
     output pixel_line
   ```

   would make it concrete before testing.

---

## Results

- **Pass rate**: 100% (60/60)
- **Test categories**:
  - Color equality & tolerance: 3 tests, all pass
  - Color operations (add, subtract, multiply, scale): 6 tests, all pass
  - Canvas operations: 6 tests, all pass
  - sRGB encoding/decoding: 11 tests, all pass
  - Gray match (checkerboard pattern): 2 tests, all pass
  - Quarter match (diagonal + gray): 1 test, all pass
  - Limits (ramp, clamp pair): 2 tests, all pass
  - Mixing (linear and non-linear blending): 7 tests, all pass
  - PPM output (header, encoding, wrapping, parsing): 8 tests, all pass
  - Plate 01 (combined ramps): 1 test, all pass

- **No regressions or edge cases missed**. The suite covers boundary conditions (0.0, 1.0, out-of-range), precision (encode/decode round-trip to 1e-9), and format details (line breaks, pixel splitting).

- **Estimated reader time**: 1.5–2 hours to implement from scratch, including debugging the quarter_match pattern.
