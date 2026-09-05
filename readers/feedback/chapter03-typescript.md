# Feedback: catching up to the current feature files

Starting point: 119 scenarios passing. After syncing to the current
`features/*.feature`, **135 scenarios pass, 0 fail** (98 chapters 1–2, 37
chapter 3: 10 Bresenham, 12 Wu, 10 thin-rectangle, 5 plate).

## New scenarios added

- Chapter 1: `The light's way never clamps`, `The switch can be passed
  instead of set`, the t = 0.5 clamp probe folded into the browser-clamp
  scenario, `The same width with a different height is still a different
  size`.
- Chapter 2: `The center question is not "at least half"`, `A buffer need
  not be square`, `A rectangle, by asking each center`, `Neither need the
  buffer be square here`, `Rows go top to bottom`, `The binary writer clamps
  too`, `Pixel bytes that look like whitespace are still pixel bytes`, and
  the out-of-bounds reads in `Setting coverage outside the buffer is
  ignored, and reading it gives 0`.
- Chapter 3: `lit_pixels reads like a page`, `A line of no length is a
  square`, `A wider line`, `An off-axis line runs through pixel centers, not
  corners`, `A line that starts above the canvas`, `A Wu line of one point`,
  and the steep-ray pixel probes plus the reference-image diffs for
  `Bresenham's fan` and `Wu's fan` (the fan tests previously checked a few
  pixels but never diffed against `reference/chapter-03/fan-*.ppm`).

## What actually failed, and why

- **`thick_line` with `x0 == x1, y0 == y1`.** The zero-length branch picked
  an arbitrary direction (`dx = 1, dy = 0`) and fed it through the same
  four-half-plane formula used for a real segment. That formula bounds the
  shape between the start and end points *along* the line direction — with
  zero length, "along" and "across" collapse onto the same axis, so the
  intersection degenerates to a single infinitely thin vertical strip
  (`x == 3.5` exactly) instead of a `width`-by-`width` square. Coverage
  sampling never lands exactly on `x == 3.5`, so `coverage_at` came back 0
  everywhere and `ink` was 0, not 1. Fixed by special-casing `len === 0` to
  return `rectangle(ax - h, ay - h, ax + h, ay + h)` directly. Caught by
  `A line of no length is a square`.
- **`coverage_at` didn't bounds-check.** It indexed straight into
  `cov.values` with no guard, unlike `set_coverage`, which does. For most
  out-of-range `(x, y)` this aliased onto a real (and, in the existing
  tests, always-zero) cell rather than crashing, so the old
  `Setting coverage outside the buffer is ignored` test passed by accident.
  It would have surfaced the moment a real value sat at the aliased index,
  and it did surface as `undefined` for `(1, 3)` against a `4x3` buffer,
  since `3*4+1 = 13` is past the 12-element array. Fixed with the same
  bounds check `set_coverage` already had. Caught by adding the three
  explicit `coverage_at(...) = 0` assertions the feature scenario actually
  specifies (the old test only checked `ink(cov) = 0`, which doesn't
  exercise reads at all).
- Everything else (Wu's `floor`-not-`trunc` handling of negative `y`,
  `paint_through`'s light-space arithmetic, the fan renders) was already
  correct; the gaps were in test coverage, not the implementation.

## Ambiguities

None found in the new scenario text — all values checked out against the
existing implementation or a small `deno run` probe before being pinned, so
nothing needed to be worked out from prose alone.

## Final counts

135 scenarios pass, 0 fail. `out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
`out/fan-coverage.ppm`, and `out/plate-03.ppm` are byte-identical to
`reference/chapter-03/`. (`render.ts` also didn't write the two fan-line
renders before; added them alongside the fixes above.)
