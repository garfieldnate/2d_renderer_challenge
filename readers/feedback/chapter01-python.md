# Chapter 1 Feedback: The Canvas and the Color

## Results
- **Total scenarios:** 59
- **Passed:** 59
- **Failed:** 0

Completed in approximately 1.5 hours.

## Ambiguities

None significant. The prose is precise and the notation conventions are clearly defined upfront:
- The tolerance rules for floating-point comparisons are explicit
- The coordinate system (origin top-left, y downward) is stated clearly
- The distinction between light values (0-1) and file values (0-255) is unambiguous

One minor point: the book says "Ranges in these programs are inclusive at both ends: `0..99` is a hundred values" but uses Python-style loops. I interpreted this to mean inclusive on both ends, which the scenarios confirm.

## Hard to Translate

The Gherkin feature file format required building a custom parser since pytest isn't available by default and translating Gherkin to native pytest syntax would lose the book's notation. The main translation challenges:

1. **Scenario Outlines with Examples tables:** Required custom table parsing to expand parameterized scenarios into individual test cases.

2. **Docstrings in steps:** The triple-quoted blocks in steps like `Then lines 1-3 of ppm are """..."""` needed special handling to:
   - Preserve line-by-line comparison semantics
   - Strip common leading indentation (standard Gherkin behavior)
   - Associate the docstring with the preceding step

3. **Operator overloading expectations:** Python uses `+`, `-`, `*` naturally for Color operations, but the implementation had to distinguish between `color * scalar` and `color * color` (Hadamard product) via `isinstance` checks in `__mul__`.

4. **Procedure calls with side effects:** Steps like `When write_pixel(c, 2, 3, red)` don't assign variables but execute functions for their effects. The test runner had to detect these and evaluate them without expecting return values.

5. **Pixel value extraction from text:** The PPM reader (`ppm_pixel`) had to parse whitespace-separated values and map 2D coordinates to flat array indices, requiring knowledge of image width.

## Failures

None. All 59 scenarios pass, including:
- 20 sRGB encoding/decoding tests (covering the threshold boundaries)
- 7 PPM format tests (including the 70-character line wrapping constraint)
- 4 rendered image tests (gray_match, quarter_match, ramp, clamp_pair)
- 2 platform tests (gray_match against reference, plate_01 against reference)

## Prose

The chapter is exceptionally well-written:

- **Clear motivation:** The opening hook ("What number is exactly halfway between black and white?") immediately establishes why this chapter matters.
- **Precise specifications:** The notation section is complete and the rendering pipeline (clamp → encode → scale → round) is spelled out step-by-step.
- **Gentle introduction:** Starting with Color, then Canvas, then sRGB, then PPM gradually builds complexity without overwhelming.
- **Good examples:** The checkerboard figure and the encoding curve figure make the 128 vs. 188 distinction visceral.

The only minor organizational note: the PPM header specification could have been inline with the function description rather than appearing only in scenarios, but this is a trivial point given the scenarios test it thoroughly.

## Would Change

1. **Tolerance precision:** When testing values like 0.2159 (five decimal places), the default tolerance of 0.0001 sometimes feels loose. A few scenarios might benefit from explicit ±0.00001 annotations to tighten expectations, particularly around the sRGB threshold boundaries.

2. **Function naming:** The asymmetry between `canvas_to_ppm`, `read_file`, and helper functions like `ppm_pixel`, `max_channel_difference` is fine, but consistency could improve if all file I/O and PPM utilities were grouped under a namespace (e.g., `PPM.pixel`, `PPM.difference`). This is purely stylistic.

3. **Scenario organization:** The gray_match and quarter_match scenarios could explicitly call out which assertion is testing the checkerboard pattern (via pixel count) versus the solid gray region, since the 5000 and 2500 pixel counts are the "proof" that the rendering is correct.

4. **Edge case testing:** The canvas bounds checking tests only verify silence on out-of-bounds writes; a scenario testing out-of-bounds *reads* (which should return black) might make the contract even clearer, though the current tests imply this.

## Hard to Follow / Missing

None identified. The ordering (numbers first, then structs, then I/O, then rendering) is logical. The trap section on linear blending appropriately warns about a philosophical difference before introducing the mix function. The figure captions are informative.

## Implementation Notes

- The sRGB functions are copied exactly as given, including the thresholds (0.0031308 and 0.04045) and coefficients—this precision is crucial.
- The PPM line wrapping uses greedy packing: append each value if it fits within 70 characters, otherwise start a new line. This is specified clearly enough in the scenarios.
- The global `_linear_blending` flag must be reset to `True` before each scenario to ensure test isolation.
- Color comparison with tolerance is component-wise: all three channels must be within tolerance, not just the magnitude of the difference.

## Time Hotspots

- **Feature file parsing:** Building the custom test runner took ~40% of the time, mostly debugging the docstring indentation handling and scenario outline expansion.
- **Implementing the Color/Canvas classes:** ~20% of the time, straightforward once the operator overloading strategy was clear.
- **sRGB encode/decode and PPM:** ~20% of the time; getting the line wrapping and byte conversion logic right required careful attention to the order of operations (clamp before encode, round after scale).
- **Debugging test runner edge cases:** ~20% of the time; procedure calls vs. assignments, pixel comparison semantics, and PPM text parsing all needed iteration.

The actual rendering functions (gray_match, quarter_match, ramp, clamp_pair, plate_01) were quick—each took minutes once the core functions worked.
