# FEEDBACK — JavaScript reader, catch-up pass

## New scenarios found and added

Chapter 1: `mix`'s optional 4th argument ("The switch can be passed instead
of set"), "The browser's way clamps each end before encoding it", "The
light's way never clamps" (existed as a scenario but had no test at all —
found only by a systematic scenario/test name diff), and four PPM scenarios
("A line of exactly 70 characters is allowed", "Counting the distinct values
in a file", and the two "files of different sizes" cases).

Chapter 2: three P6 scenarios (rows top-to-bottom, binary clamping, bytes
that look like whitespace), four coverage/centers scenarios ("Neither need
the buffer be square", "The center question is not 'at least half'", "A
buffer need not be square", "A rectangle, by asking each center"), and
"reading outside the buffer gives 0" folded into the existing
out-of-bounds-write test.

Chapter 3: `lit_pixels reads like a page`, two Wu scenarios (line starting
at row -1, a one-point line), and three thick-line scenarios (zero-length
square, a width-3 line, an off-axis line).

## Failures found and fixed

1. **`paint_through` didn't force linear blending.** With the global switch
   off, `paint_through` used `mix()`'s ambient (browser) mode and produced
   wrong output. Fixed by having `paint_through` call `mix(current, color,
   cov, true)`. Caught by "The arithmetic is on light, whatever the switch
   says," which I had to strengthen — the old test never actually turned
   the switch off.

2. **`mix`'s browser-mode branch didn't clamp before encoding.** `encode()`
   on an out-of-range light value (e.g. `-0.2`) went straight into
   `Math.pow` of a negative base to a fractional exponent → `NaN`. Fixed by
   clamping both colors to `[0, 1]` before encoding in the non-linear
   branch. Caught by "The browser's way clamps each end before encoding it."

3. **Zero-length `thick_line` covered the entire plane.** With `x0==x1,
   y0==y1`, direction and normal were both `(0, 0)`, so every half-plane's
   normal was zero and `inside()` was true everywhere (dot product with
   the zero vector is always `0 >= 0`). Fixed per the chapter's stated rule:
   a zero-length line gets direction `(1, 0)` and its two ends are pushed
   apart by half the width each. Caught by "A line of no length is a
   square" (previously untested; `ink` would have blown past 1 for an 8×8
   buffer).

4. `mix` gained an optional 4th parameter (`useLinear`, defaulting to the
   global switch) to satisfy "The switch can be passed instead of set" —
   an interface change, not a bug, but it's what let fix #1 be a one-line
   call rather than a save/restore dance around the global.

## Ambiguity

None found in the new scenario prose — the Gherkin was concrete enough to
implement and check by hand (e.g. computing the Wu-line-above-canvas ink by
tracing the algorithm) before wiring up assertions. The zero-length
thick-line scenario is well hedged by the chapter's own prose ("gets (1, 0)
… pushed apart by half the width each"), so there was no guessing involved.

## Final counts

- Chapter 1: 67/67 passing
- Chapter 2: 36/36 passing
- Chapter 3: 38/38 passing
- **Total: 141/141 passing, 0 failures**

All chapter 3 renders regenerated and byte-identical (max channel diff 0)
to `reference/chapter-03/*.ppm`: `out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
`out/fan-coverage.ppm`, `out/plate-03.ppm`.
