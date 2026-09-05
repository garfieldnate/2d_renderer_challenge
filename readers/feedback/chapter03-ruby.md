# Ruby reader feedback — catch-up pass

## What was new

Comparing `features/*.feature` against the existing suite turned up these scenarios with
no corresponding test:

- Chapter 1: `mix`'s "The light's way never clamps", "The switch can be passed instead of
  set" (the optional 4th argument), "The browser's way clamps each end before encoding it"
  probed at t=0.5, and PPM's "The same width with a different height is still a different
  size".
- Chapter 2: "The center question is not 'at least half'", "A buffer need not be square"
  and "A rectangle, by asking each center" (rasterize_centers), "Neither need the buffer be
  square here" (rasterize), and P6's "Rows go top to bottom", "The binary writer clamps
  too", "Pixel bytes that look like whitespace are still pixel bytes". Also, "Setting
  coverage outside the buffer is ignored, and reading it gives 0" existed but never
  actually read the out-of-bounds cells, and "The arithmetic is on light, whatever the
  switch says" never turned linear blending off, so it wasn't testing the thing it claimed
  to.
- Chapter 3: "lit_pixels reads like a page", "A line of no length is a square", "A wider
  line" (width 3), "An off-axis line runs through pixel centers, not corners", "A line that
  starts above the canvas" (Wu, row -1), "A Wu line of one point", and the plate.feature
  steep-ray probes (`ppm_pixel` at (102–104, 120)) plus the `max_channel_difference` vs.
  reference for both `fan_bresenham` and `fan_wu` (previously only `fan_coverage` and
  `plate_03` were diffed against the reference PPMs).

## What failed, and why

Only one real implementation bug turned up: **zero-length `thick_line`**. When `x0,y0 ==
x1,y1`, the direction vector is undefined, and the code picked an arbitrary fallback
direction `(1, 0)` but only used it for the perpendicular side-planes — the two end-cap
planes stayed flush at the single point, so the "rectangle" collapsed to a zero-width
sliver along `x = point.x`. `coverage_at` came back 0 everywhere instead of the pixel being
fully covered. Fixed by backing both end caps off by `width/2` too when `len == 0`, turning
it into a proper width-by-width square (`renderer.rb`, `ThickLine#initialize`).

Two smaller correctness gaps, not covered by any failing assertion but caught while
implementing the new scenarios:
- `mix` had no way to override `$linear_blending` per call. Added an optional 4th
  parameter (`mix(a, b, t, linear_blending = nil)`).
- `paint_through` mixed using the *global* `$linear_blending` switch, so with it off,
  painting through coverage would (incorrectly) use browser-style encoded-space math
  instead of light. Fixed by calling `mix(current, paint_color, cov, true)` to force light
  arithmetic regardless of the switch. (No existing assertion caught this because the one
  scenario meant to test it never actually flipped the switch — see above.)

Every other new scenario (off-axis thick_line, width-3 thick_line, Wu line starting above
the canvas, Wu single point, lit_pixels ordering, coverage_at outside the buffer, the
steep-ray plate probes) already produced the exact values the feature files expect —
they just weren't pinned yet.

## Ambiguity

None. The prose in chapters 1-3 and every new scenario were unambiguous; the only surprise
was that "The arithmetic is on light, whatever the switch says" is worded as a claim about
`paint_through`'s behavior under the *off* setting, but the existing test never set it off,
so it silently degenerated into re-testing the on/default path.

## Final counts

- Chapter 1: 64 runs, 782 assertions, 0 failures (was 60/774)
- Chapter 2: 35 runs, 187 assertions, 0 failures (was 28/148)
- Chapter 3: 41 runs, 177 assertions, 0 failures (was 35/139)

All scenarios in all `.feature` files pass. `out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
`out/fan-coverage.ppm`, and `out/plate-03.ppm` regenerated and diff at 0 against
`reference/chapter-03/`.
