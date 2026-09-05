# C# reader: catch-up feedback

## New scenarios found and added (23 total, 111 -> 134)

- **Ch1 mix**: `The light's way never clamps`, `The switch can be passed instead
  of set` (mix's optional 4th arg), plus two renamed scenarios with an added
  t=0.5 probe (`The browser's way clamps each end before encoding it`, `The
  ends of a mix are its inputs either way, when they're in range`). Dropped
  `Linear blending is on by default`, which no longer exists in the feature
  file.
- **Ch1 ppm**: `The same width with a different height is still a different
  size`.
- **Ch1 plate**: renamed `The plate` -> `Plate 1` (same body).
- **Ch2 p6**: `Rows go top to bottom`, `The binary writer clamps too`, `Pixel
  bytes that look like whitespace are still pixel bytes`.
- **Ch2 centers**: `The center question is not "at least half"`, `A buffer
  need not be square`, `A rectangle, by asking each center`; renamed
  `Setting coverage outside the buffer is ignored` -> `...and reading it
  gives 0` with added `coverage_at` probes.
- **Ch2 paint**: renamed `The arithmetic is on light` -> `...whatever the
  switch says`, now turns linear blending off first.
- **Ch2 coverage**: `Neither need the buffer be square here`.
- **Ch2 plate**: renamed `The plate` -> `Plate 2` (same body).
- **Ch3 bresenham**: `lit_pixels reads like a page`.
- **Ch3 wu**: `A line that starts above the canvas`, `A Wu line of one
  point`.
- **Ch3 quad**: `A line of no length is a square`, `A wider line`, `An
  off-axis line runs through pixel centers, not corners`.
- **Ch3 plate**: `Bresenham's fan` and `Wu's fan` gained three steep-ray
  probes each (rows 120, columns 102-104); also found `Bresenham's fan` and
  `Wu's fan` were never diffing against their reference PPMs at all — added
  the missing `max_channel_difference(...) <= 1` checks.

## Failures found and fixed

Three real bugs, all caught by the new scenarios above, not by anything I
went looking for on my own:

1. **`CoverageBuffer.CoverageAt` threw `IndexOutOfRangeException` instead of
   returning 0** for out-of-bounds (x, y). Writes were already
   bounds-checked; reads weren't. Caught by `...and reading it gives 0`.
   Fixed with the same bounds check `WritePixel`/`SetCoverage` already use.
2. **`Paint.PaintThrough` respected the global linear-blending switch**
   instead of forcing it on. With the switch off it silently used the
   browser's encode-lerp-decode path, which the chapter never intends for
   coverage. Caught by the newly-strict `...whatever the switch says`
   scenario (turns blending off first). Fixed by giving `Mix.Blend` an
   optional 4th `bool? linear` argument that overrides the switch for one
   call, and having `PaintThrough` pass `linear: true`.
3. **Zero-length `ThickLine` collapsed to a measure-zero sliver** instead of
   a width-by-width square: with `x0==x1, y0==y1`, the two end caps sat
   exactly on top of each other (no offset), so no pixel center or sample
   point could ever satisfy both `Inside` half-planes — `ink` came out 0
   instead of 1. Caught by `A line of no length is a square`. Fixed by
   pushing the end caps out by half the width, same as the side planes,
   whenever the segment has zero length.

Everything else the new scenarios probed (`A buffer need not be square`,
non-square `rasterize`, the Wu line starting at row -1, the Wu line of one
point, `lit_pixels` ordering, thick_line width 3, the off-axis thick_line,
mix's optional 4th argument itself) already worked once written — the
existing `Coverage`/`Rasterize`/`LineWu`/`LineBresenham`/`LitPixels` code
handled them correctly; they just weren't pinned yet.

## Ambiguity

None worth flagging. The renamed scenarios (`Plate 1`/`Plate 2`, the two
mix titles, the coverage-outside-buffer title) are unambiguous — same Given/
When/Then, new title or one extra assertion — so no prose or scenario
change was needed, only bringing the runner's transcription up to date.

## The 9.71875 diagonal scenario

Passed as written, with the feature's exact literal (I tightened the
assertion from a hand-rounded `9.7188` to `9.71875`, still within the same
tolerance). Printed `cov.Ink` in both Debug and Release configs before
settling on that: both gave exactly `9.71875`, so this machine's RyuJIT
(arm64) is not fusing the half-plane's `dx * Nx + dy * Ny` into an FMA the
way the chapter's trap warns x64-with-AVX2 compilers might. No `9.65625`
observed here; a reader on different hardware might see it, per the
chapter's own caveat.

## Final counts

134/134 scenarios passing across all three chapters (was 119/119 before,
against a suite that was silently missing 23 of the book's current 134
scenarios — the pass/fail summary looked clean because the missing
scenarios simply weren't transcribed yet, not because they passed).

- Chapter 1: 82/82 (equality 3, colors 6, canvas 6, srgb 20, ppm 11, mix 9,
  gray-match 3, limits 3, plate 1)
- Chapter 2: 35/35 (shapes 4, p6 6, magnify 2, centers 8, paint 5,
  coverage 7, twice 2, plate 1)
- Chapter 3: 37/37 (bresenham 10, wu 12, quad 10, plate 5)

`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm` and
`out/plate-03.ppm` are all byte-identical to `reference/chapter-03/*.ppm`.
