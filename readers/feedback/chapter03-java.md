# Chapter 1-3 catch-up: feedback

## New scenarios found and added

- **Chapter 1 mix**: "The light's way never clamps", "The switch can be
  passed instead of set" (mix's optional 4th `linear` argument), "The
  browser's way clamps each end before encoding it". Renamed "the ends of a
  mix are its inputs either way" to match the feature's new title.
- **Chapter 1 PPM**: "A line of exactly 70 characters is allowed",
  "Counting the distinct values in a file", "Files of different sizes are
  as different as it gets", "The same width with a different height is
  still a different size".
- **Chapter 2 centers**: bounds-check on `coverage_at` (reading outside now
  returns 0, matching `set_coverage`'s existing rule), "The center question
  is not 'at least half'", "A buffer need not be square", "A rectangle, by
  asking each center".
- **Chapter 2 coverage**: "Neither need the buffer be square here".
- **Chapter 2 P6**: "Rows go top to bottom", "The binary writer clamps
  too", "Pixel bytes that look like whitespace are still pixel bytes".
- **Chapter 3 bresenham**: "lit_pixels reads like a page".
- **Chapter 3 wu**: "A line that starts above the canvas" (row -1),
  "A Wu line of one point".
- **Chapter 3 quad**: "A line of no length is a square", "A wider line"
  (width 3), "An off-axis line runs through pixel centers, not corners".
- **Chapter 3 plate**: Bresenham's/Wu's fan scenarios gained the
  `read_file(reference/...)` + `max_channel_difference` check and the
  steep-ray probes at (103,120)/(102,120)/(104,120) -- these were being
  rendered but never diffed against the reference PPM before.

## Failures found and fixed

- **`CoverageBuffer.coverageAt`** had no bounds check at all -- reading
  outside the buffer threw `ArrayIndexOutOfBoundsException` instead of
  returning 0 (only `setCoverage` was guarded). Exposed by "Setting coverage
  outside the buffer is ignored, and reading it gives 0".
- **`ThickLine` divided by zero** for a zero-length line: `ux = dx / len`
  with `len == 0` produced `NaN` normals, so a zero-length `thick_line`
  wasn't a square, it was nothing. Fixed per the pseudo-code: direction
  defaults to (1, 0) and the two ends are pushed apart by half the width.
  Exposed by "A line of no length is a square".
- **`Mixer`'s browser-mode mix clamped nothing** -- `mixChannel` encoded the
  raw (possibly out-of-range) channel values directly. `mix(color(1.5, 0.5,
  -0.2), color(0,0,0), 0)` came out wrong because `Srgb.encode` was fed 1.5
  and -0.2. Fixed by clamping each end to 0..1 before encoding, per "The
  browser's way clamps each end before encoding it" -- this is exactly the
  "clamp the ends, not the mixed result" trap the project notes warn about;
  t=0.5 was the probe that would have caught a wrong placement.
  Also added the `mix(a, b, t, linear)` overload; it never mutates the
  global switch.
- "A wider line" and "An off-axis line runs through pixel centers, not
  corners" needed no code change once the zero-length fix landed --
  same four-half-plane formula, just previously untested at width 3 and
  off-axis.

## Ambiguities / notes

- None of the new scenario prose was ambiguous; each translated directly.
  The trickiest part was that the `ThickLine` zero-length fix has to shift
  only the along-axis endpoints (`ax -= h`, `bx += h` in the pseudo-code,
  i.e. `sx`/`ex` here) using the *fallback* direction (1, 0), not the
  original (undefined) one -- easy to get backwards.

## The 9.71875 diagonal scenario

Passed as written, no special handling needed. `HalfPlane.inside` does
`(x - px) * nx + (y - py) * ny >= 0` with two separate multiplications and
a plain add -- Java never fuses that into a single FMA on its own (no
`--ffast-math` equivalent, and `Math.fma` is a distinct, explicitly-called
method), so the four boundary samples land on the exact zero the chapter
promises and `ink(cov)` comes out to exactly 9.71875.

## Final counts

- Chapter 1: 66/66 passed (was 59; +7 new scenarios, all from mix and PPM).
- Chapter 2: 35/35 passed (was 28; +7 new scenarios, across centers,
  coverage, and P6).
- Chapter 3: 37/37 passed (was 31; +6 new scenarios, across bresenham, wu,
  quad, and plate).

`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm`, and
`out/plate-03.ppm` are byte-identical to their `reference/chapter-03/`
counterparts.
