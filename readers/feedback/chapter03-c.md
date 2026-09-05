# C11 reader — catch-up feedback

Final: **134 scenarios, 134 passed, 0 failed** (chapter 1: 62, chapter 2: 35, chapter 3: 37).
Was 118/118 before this pass; 16 new scenarios were missing from `src/tests.c`, plus one
scenario in every chapter was renamed or its assertions extended in the feature files since
`tests.c` was last synced, and a few had drifted stale (present in `tests.c`, gone from the
`.feature` files).

## Real bugs the new scenarios found

- **`thick_line` with equal endpoints** ("A line of no length is a square", ch3-quad). The
  code already guarded the `len == 0` division, but it only picked an arbitrary direction
  `(1, 0)` for the normal — it left the start/end caps flush at the single point `(x0+0.5,
  y0+0.5)`, so the shape's "length" half-planes still allowed only `x == cx`, a
  zero-area sliver. `rasterize` sampled it as coverage 0 everywhere. Fix: when the segment
  has no length, push the two end caps out by `width/2` too (`cap` in `thick_line`), same as
  the sides, turning it into an actual `width`-by-`width` square.
- **`paint_through` honored the global blending switch** ("The arithmetic is on light,
  whatever the switch says", ch2-paint). With `linear_blending` off, `paint_through` was
  lerping in encoded space like the rest of `mix`, so `pixel_at` came back `0.2140` instead of
  `0.5`. The book's rasterizer isn't supposed to know the switch exists. Fixed by having
  `paint_through` call the new explicit-argument form, `mix4(..., true)`, instead of the
  three-argument global-reading one.
- **Browser-mode `mix` clamped the result instead of the ends** ("The browser's way clamps
  each end before encoding it", ch1-mix). `encode()` was being called directly on
  out-of-range light values (e.g. `-0.2`), which the transfer function isn't defined for
  and which doesn't match what a browser actually does. Fixed by clamping each endpoint to
  `[0, 1]` before encoding, inside the shared `mix1` helper.
- **`mix`'s optional fourth argument didn't exist** ("The switch can be passed instead of
  set", plus the browser-clamp and plate scenarios above). Added `mix3`/`mix4` and a
  variadic-macro dispatch on argument count in `renderer.h` so both `mix(a, b, t)` and
  `mix(a, b, t, linear)` compile; `mix4` never touches the global.

Everything else that was missing (zero-length square aside, none of these were code bugs —
`coverage_at` outside the buffer, the Wu row-`-1` floor case, the Wu one-point line, the
lit_pixels reading order, the new P6 whitespace-byte and off-square-buffer scenarios, the
extra fan probes) turned out to already be handled correctly; they just weren't pinned by a
test yet.

## Housekeeping (feature files had drifted from `tests.c`)

- Removed from `tests.c`: "Linear blending is on by default" and "The switch was left on"
  (chapter 1) — no longer in any `.feature` file.
- Removed two `sRGB` example rows (`0.0031308 → 0.0405`, `0.04045 → 0.0031`) that are no
  longer in `chapter01-srgb.feature`'s Examples tables.
- Renamed to match the `.feature` titles exactly: "The plate" → "Plate 1" and "Plate 2";
  "Setting coverage outside the buffer is ignored" → "...and reading it gives 0" (and added
  the `coverage_at` assertions the new title promises); "The arithmetic is on light" → "...,
  whatever the switch says" (and added `Given linear blending is off`); "The ends of a mix
  are its inputs either way" → "..., when they're in range".
- `ink(cov) = 9.7188` → `9.71875`, the exact value the feature file now pins (both were within
  tolerance of each other, so this wasn't a failure, just drift).
- `chapter01-ppm.feature` had grown four scenarios ("A line of exactly 70 characters is
  allowed", "Counting the distinct values in a file", "Files of different sizes are as
  different as it gets", "The same width with a different height is still a different
  size") that were never added when the feature file picked them up.
- `main.c` was missing `fan-bresenham.ppm` and `fan-wu.ppm` from `make render`'s output list
  (only `fan-coverage.ppm` and `plate-03.ppm` were written); both scenarios in
  `chapter03-plate.feature` now also diff against the corresponding reference file, which
  they didn't before.

## Ambiguity

None worth flagging. The only thing that took real tracing to confirm was that the Wu
"starts above the canvas" and "one point" scenarios, and the coverage/rasterize non-square
scenarios, needed no code changes at all — the existing `floor()`-based split and the general
half-plane math already handled them; they were just untested.

## make render

`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm`, and `out/plate-03.ppm` are
all written as P6 and byte-identical to `reference/chapter-03/`. All chapter 1 (P3) and
chapter 2 (P6) outputs are also byte-identical to their references.
