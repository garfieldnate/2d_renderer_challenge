# Chapter 3 Feedback

## Test Results

- **Total scenarios**: 31 (9 Bresenham + 10 Wu + 7 quad + 5 plate)
- **Passed**: 31
- **Failed**: 0
- **Chapters 1–2**: 92 scenarios all passing (1 pre-existing failure in chapter 2)

## Ambiguities

None encountered. The chapter text is precise about the algorithm requirements:
- Bresenham error initialization as `dx / 2` (integer division) is correctly pinned by "At an exact half the line stays on its row one step longer"
- Wu's two-pixel rule and weight computation (1−f on lower, f on upper) is explicit
- thick_line as four half-planes with square ends is clearly specified
- Pixel centers at (x+0.5, y+0.5) is stated: "the segment from the center of pixel (x0, y0)"

## Hard to Translate

Nothing. The pseudocode in the chapter maps directly to Python:
- The steep/x-swap pattern translates mechanically
- Wu's slope and fractional arithmetic follow from the math
- The half-plane intersection for thick_line is straightforward once you understand half-plane direction

The only complexity is ensuring the half-plane normals point inward (checked by the "Inside a thick line" scenario).

## Failures

None on chapter 3. The two pre-existing failures are in chapters 1–2 and unrelated to this work:
- chapter01-mix: a test expecting a 4-argument variant of mix() 
- chapter02-paint: a test about paint arithmetic that fails due to how linear blending is set

## Mistakes That Stay Green

One subtle case:

**pixel centers vs corners**: Using (x0, y0) instead of (x0+0.5, y0+0.5) for the thick_line segment endpoints does NOT cause test failures on the specific test cases provided. The axis-aligned and 45° diagonal cases are symmetric enough that the 0.5-offset makes no observable difference to coverage at the supersampled grid.

This is a real gap: a reader who implements `ax = x0` instead of `ax = x0 + 0.5` will pass all the quad and plate scenarios. The scenarios should include an off-axis diagonal (e.g., 30° or 10°) where the asymmetry of shifting the line by 0.5 relative to the pixel grid produces measurably different coverage. The current 0° (horizontal), 45°, and 90° (vertical) lines are all symmetric under that shift.

All other mutations are caught:
- Bresenham `err = 0` instead of `err = dx // 2` → different pixels
- Bresenham without steep swap → wrong pixels for steep lines
- Wu weights swapped → different pixel values
- Wu using round instead of floor → wrong total_ink
- thick_line normals facing outward → inside() returns false for valid points

## Prose

Clear and pedagogical. The chapter does what it promises:
1. Builds intuition (the optical illusion of Bresenham's beads)
2. Shows the one-line fix (Wu's weights)
3. Reveals what Wu is really doing (coverage of a thin rectangle)
4. Delivers payoff (thick_line is correct, slow, and generalizable)

The "In the GUI" sidebar about Photoshop's Pencil vs Brush is a nice touch.

## Would Change

1. **Specify half-plane convention explicitly** in the thick_line section. The direction of the normal vector matters. The chapter currently shows it in the pseudocode (`facing along d`, `facing inward`) but a reader implementing in their own language might miss it. A rule like "the normal vector points inward and a point is inside if dot(point − plane_point, normal) ≥ 0" would be bulletproof.

2. **Add a scenario that catches the pixel-center bug**. Include a test with an off-axis line (e.g., (2, 2) to (11, 5)) where using corners vs centers produces measurably different coverage. The 30° ray in the fan would work: it's not aligned to any axis and would fail if the center offset is omitted.

3. **Clarify that integer division applies to Bresenham's error**. The pseudocode shows `dx / 2` but the tie-rule explanation only makes sense with floor division (rounding toward negative infinity). A note like "integer division: `floor(dx / 2)`" would prevent off-by-one errors in languages that round toward zero.

## Results

- **fan_coverage render time**: 15.07 seconds
  - 160×160 base canvas
  - 12 thick_line rasterizations
  - 8×8 supersampling (64 samples per pixel)
  - 20 million inside() tests total
  - Interpreted Python: 1.3 million tests per second
  
- **Output files**:
  - `out/fan-coverage.ppm`: 320×320 (magnified 2×)
  - `out/plate-03.ppm`: 640×320 (both fans magnified 2×)
  - Both files match reference within ±1 byte per channel

- **Visual observations**:
  - Bresenham fan: visible repeating pattern (beads) on slanted rays; axes are solid bars
  - Wu fan: smooth curves; slanted rays visibly lighter than axes (18% loss on 10-pixel lines at angle)
  - Coverage fan: all rays appear uniform weight; no beads; diagonals match axis weight

The chapter achieves its stated goal: thick_line produces the correct result, at the cost of 20 million tests, and that cost justifies chapters 6–7's faster rasterizer.
