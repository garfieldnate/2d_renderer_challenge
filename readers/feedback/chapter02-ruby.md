# Chapter 2 Implementation Feedback

## Ambiguities

**Disc render function definitions missing**: The chapter prose doesn't explicitly define `disc_centers()` and `disc_coverage()`, only mentioning them in test scenarios. I inferred they should render a 40×40 circle and magnify by 8 to reach 320×320, based on the pattern in `painted_twice()` and `plate_02()` which both magnify by 6. The reference images confirmed this guess, but explicit pseudocode would help.

**Coverage buffer initialization semantics**: The feature files show coverage buffers created without explicit initialization to 0, but it's clear they must start empty. Explicitly stating "all values default to 0" would reduce guessing.

**Byte indexing in P6 tests**: The Gherkin syntax "byte 12 of p6" uses 1-based indexing while Ruby's `bytes[]` is 0-indexed. This forced a translation step where "byte 12" means `bytes[11]`. A note like "byte positions are 1-indexed in scenarios" would clarify.

## Hard to Translate

**Binary file handling**: Ruby's automatic UTF-8 encoding made binary P6 file parsing fragile. Reading binary files without specifying `Encoding::ASCII_8BIT` caused invalid byte sequence errors. The parser needed defensive logic to extract headers without assuming the entire data is text-safe.

**Shape-based rasterization**: The conceptual jump from "is this point inside?" to "how much of this pixel is inside?" needed careful implementation. The 8×8 sampling grid is clearly defined but requires careful coordinate handling—sample at `(pixel_x + (i + 0.5) / 8, pixel_y + (j + 0.5) / 8)`, not at integer boundaries.

**P6 parsing across formats**: Supporting both P3 and P6 made the pixel reader complex. Detecting format, parsing mixed binary/text headers, and finding the pixel data start position all needed special handling. A unified binary format throughout would simplify code.

## Failures

None. All tests pass against the reference images with max difference ≤ 1 byte per channel.

## Mistakes That Stay Green

**Divided by 63 instead of 64**: If coverage calculation used `count / 63.0` instead of `count / 64.0`, the error (~0.8%) would pass most tests but fail on pixel-perfect comparisons like the disc tests. The suite catches this when comparing to reference images.

**P6 header byte misalignment**: An extra space in the header shifts all pixel bytes by 1. The test suite catches this immediately because `ppm_pixel()` reads bytes from the wrong offsets.

**paint_through as assignment**: If `paint_through()` just set pixels instead of mixing, the edge pixels of painted shapes would be wrong. The test "Paint over something that isn't black" specifically catches this.

**shape.inside() vs center sampling**: If rasterization tested corners instead of centers (e.g., `inside(s, x, y)` instead of `inside(s, x + 0.5, y + 0.5)`), edge pixels would be systematically wrong. The disc tests would fail.

**Coverage divided by wrong denominator** is the subtlest—a difference of 1.6% in coverage. The reference image comparison catches it.

## Prose

**Excellent conceptual explanation**: The section explaining the core problem ("A pixel is a little square...") and the solution (coverage as a number 0–1) is clear and motivates the rest.

**Good pseudocode**: The pseudocode for `painted_twice()`, `plate_02()`, etc. is readable and translatable. Indentation and variable names are clear.

**Color terminology**: Mixing "paint" (the drawing color), "light" (the blending space), and "coverage" (the rasterization value) correctly shows they're different things. The warning about coverage ≠ opacity (Section 2.7) is valuable.

**Figure captions are informative**: "Same circle, same grid, same paint. Everything from here on is a faster way of computing the right-hand picture." clearly states what's being compared.

## Would Change

**Explicit render function pseudocode**: Add pseudocode for `disc_centers()` and `disc_coverage()` instead of assuming they're obvious variants. Readers will guess wrong and waste time.

**P6 format decision rationale**: Explain *why* P6 is introduced in chapter 2 (size, speed for larger images). Currently it's "a quick detour."

**Sample count for 8×8 grid**: Explicitly state "8 samples per dimension, 64 total" up front. Some readers will try 4×4 or 10×10 and wonder why results are wrong.

**Coordinate system note**: "All coordinates are real numbers, not pixel indices. Pixel (x, y) refers to the square from (x, y) to (x+1, y+1). The center is (x + 0.5, y + 0.5)." earlier in the chapter would prevent confusion.

**Error handling guidance**: "If paint_through receives a coverage value outside [0, 1], clamp it" or "it's an error"? Current implementation doesn't validate, but users might assume it does.

## Results

**Chapter 1**: 60 tests, 0 failures
**Chapter 2**: 28 tests, 0 failures
**Total**: 88 tests, 0 failures

All reference image comparisons pass with `max_channel_difference <= 1`.

Output images generated:
- `disc-centers.ppm`: 320×320, rendered in ~0.3s
- `disc-coverage.ppm`: 320×320, rendered in ~0.3s
- `painted-twice.ppm`: 480×240, rendered in ~0.2s
- `plate-02.ppm`: 480×240, rendered in ~0.2s

**Time hotspots**: Rendering is fast because the 40×40 rasterization is cheap. The magnify step (copying pixels into larger blocks) is O(width × height) but negligible. No optimization needed.

**Code size**: 
- Chapter 1 functions: ~450 lines
- Chapter 2 additions: ~280 lines
- Tests: Chapter 1 ~600 lines, Chapter 2 ~300 lines

Clean separation of concerns—shapes, coverage buffers, rasterization, and painting are independent modules.
