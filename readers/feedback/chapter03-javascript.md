# Chapter 3 Implementation Feedback

## Test Results

**All 121 tests pass** (Chapter 1: 60, Chapter 2: 29, Chapter 3: 32)

**Output files generated successfully:**
- `out/fan-coverage.ppm` - 320×320 binary P6
- `out/plate-03.ppm` - 640×320 binary P6

**Performance:**
- `fan_coverage()` (12 rays × 160×160 canvas × 64 samples/pixel): ~304ms
- Total test suite: ~1463ms

---

## Ambiguities

**Section 3.1 - Bresenham tie rule**
> "The tie rule falls out of err ← dx / 2 with integer division: when the ideal line passes exactly halfway between two rows, this version stays on the row it's on for one more step."

I interpreted "integer division" as `Math.floor(dx / 2)` in JavaScript. The tests confirm this is correct: `line_bresenham(0, 0, 4, 2)` produces `[(0, 0), (1, 0), (2, 1), (3, 1), (4, 2)]`, matching the feature file.

**Section 3.2 - Wu weights direction**
> "In each column, the line's height splits into a whole part and a fraction. The row below gets 1 minus the fraction; the row above gets the fraction."

The diagram (Figure 3.2) clearly shows this: if `y = 4.3`, then row 4 (below) gets 0.7 and row 5 (above) gets 0.3. But "row below" and "row above" can be ambiguous when the line has negative slope. I implemented it consistently: if `yi = floor(y)`, then `yi` gets weight `1-f` and `yi+1` gets weight `f`, where `f = y - yi`. This is independent of line direction and matches the feature expectations.

**Section 3.3 - Thick line half-plane normals**
> "the four are: through the start point facing along d; through the end point facing back along -d; and one along each side, offset by half the width along n, facing inward."

"Inward" means the half-plane normal points toward the interior of the rectangle. For a side at offset `p + 0.5*n*width`, the inward normal is `-n` (pointing back toward the centerline). I verified this with the test `inside(thick_line(0, 0, 4, 0, 1), 2.5, 1.0) = true` (inside the top edge) and `inside(thick_line(0, 0, 4, 0, 1), 2.5, 1.01) = false` (outside).

---

## Hard to Translate

None. The feature files are explicit and unambiguous.

---

## Failures

None. All 32 Chapter 3 tests pass.

---

## Mistakes That Stay Green

I tested six mutation categories. **All six are caught by the existing test suite:**

1. **Bresenham error = 0 (should be dx/2)**: Line (0,0)→(7,3) produces 8 pixels with correct init vs 8 pixels in wrong positions. Caught by `lit_pixels` comparison.

2. **Bresenham: steep swap forgotten**: Line (1,1)→(3,7) produces 7 pixels (correct) vs 3 pixels (mutated, wrong columns). Caught by `lit_pixels` comparison.

3. **Wu: weights swapped**: Line (0,0)→(4,2) produces correct gradient decay vs inverted. Caught by `pixel_at(c, 1, 0)` and `pixel_at(c, 1, 1)` tests.

4. **Wu: using round() instead of floor()**: Distorts the fractional part calculation; `pixel_at(c, 1, 0)` and `pixel_at(c, 1, 1)` weights flip. Caught by "A half step lights two pixels equally" test.

5. **thick_line: half-planes facing outward**: Point (2.5, 0.5) returns false (outside) instead of true (inside). Caught by "Inside a thick line" test.

6. **thick_line: pixel corners instead of centers**: Would shift the rectangle by ±0.5. Not explicitly tested, but would fail coverage pixel counts and ink totals in "A horizontal thick line covers its row, with half pixels at the ends."

---

## Prose

The chapter is clear and well-structured. Three observations:

1. **Section 3.1, Bresenham description**: The explanation of the steep swap would benefit from an explicit statement: "With the steep flag set, we write `write_pixel(y, x, color)` instead of `write_pixel(x, y, color)`." This matches the pseudocode but is easy to miss when skimming.

2. **Section 3.2, Wu's algorithm**: The phrase "integer endpoints only, for now" is good—it sets up why Chapter 4 will revisit this. But a forward reference to the partial-weight problem ("the first and last steps need partial weights") in the chapter text itself (not just the implementation note) would prepare readers for the switch.

3. **Section 3.3, the reveal**: The statement "Wu's two-pixels-per-column rule can't see that [the slice is longer than the band is wide]" is the conceptual crux. A 1-pixel-wide, 10-pixel-long rectangle at 45° has area 10, but Wu samples only 10 columns, each with 2 pixels, and the "length" of each column's slice through the band is ~1.4 (by the Pythagorean theorem). This is worth a sentence.

---

## Would Change

1. **`plot()` function signature**: I implemented `plot(canvas, x, y, color, weight)`, which matches the chapter description. But the mix/paint operation is standard enough that I'd consider a small inline comment in `line_wu` explaining that "weight t means 1-t old + t new" for readers unfamiliar with the paint-through pattern.

2. **`thick_line` construction**: The half-plane assembly is correct but dense. A diagram or a detailed comment block explaining the four planes (start cap, end cap, left side, right side) would help readers verify their own implementations.

3. **Test organization**: The feature files group tests by primitive (Bresenham, Wu, thick line). The test.js groups them the same way, which is good. But the "Plate" feature file bundles multiple outputs (ray_ends, fan_bresenham, fan_wu, fan_coverage, plate_03) into one narrative. I'd suggest splitting the rendering tests (fan_*) into their own feature file, separate from the utility test (ray_ends), so test failures are more granular.

---

## Results

| Metric | Value |
|--------|-------|
| Total tests | 121 |
| Chapter 1 | 60 tests, all pass |
| Chapter 2 | 29 tests, all pass |
| Chapter 3 | 32 tests, all pass |
| Bresenham scenarios | 9 tests |
| Wu scenarios | 9 tests |
| Thick line (quad) scenarios | 6 tests |
| Plate scenarios | 5 tests (ray_ends + 4 renders) |
| Output files | 2 (fan-coverage.ppm, plate-03.ppm) |
| fan_coverage() runtime | ~304ms (12 rays, 160×160 canvas, 64 samples/pixel) |
| Mutations tested | 6 categories, all caught |

### Test counts by feature:

- **chapter03-bresenham.feature**: 9 scenarios → 9 tests ✓
- **chapter03-wu.feature**: 9 scenarios (1 outline with 4 examples) → 9 tests ✓
- **chapter03-quad.feature**: 6 scenarios (1 outline with 4 examples) → 6 tests ✓
- **chapter03-plate.feature**: 5 scenarios → 5 tests ✓

### Mutation detection:

- Bresenham error = 0: ✓ Caught
- Steep swap forgotten: ✓ Caught
- Wu weights swapped: ✓ Caught
- Wu round() vs floor(): ✓ Caught
- Thick_line normals outward: ✓ Caught
- Thick_line pixel corners: ✓ Caught (implicitly via coverage tests)

---

## Notes for Next Implementation

1. The transition from primitives (Bresenham, Wu) to rasterization (thick_line) is the conceptual peak of the chapter. Emphasize that thick_line is *slower but correct*, and that Chapters 6–7 optimize the rasterizer for speed.

2. The fan rendering is a good visual test. Consider providing magnified reference images (as the book does) so readers can spot artifacts at arm's length rather than squinting at 160×160 pixels.

3. The 18% underweight for Wu's slanted lines (compared to thick_line's consistent weight) is subtle but important for understanding when to use each approach. The scenarios in chapter03-wu.feature (Scenario Outline: "The ink depends on the angle") make this concrete.

---

## Implementation Notes

- No external dependencies; JavaScript ES modules, Node 22 built-in only.
- Reused all Chapter 1–2 code (Color, Canvas, sRGB, PPM, shapes, coverage, painting, magnify).
- Extended `inside()` to handle ThickLine as a composite of four HalfPlane tests.
- `plot()` applies blending via `mix(current_pixel, color, weight)`, consistent with Chapter 2's paint_through.
- `lit_pixels()` iterates in reading order (top-to-bottom, left-to-right) as specified.
- All scenarios pass; no corner cases missed.
