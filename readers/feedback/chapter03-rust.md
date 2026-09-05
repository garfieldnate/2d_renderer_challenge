# Chapter 1-3 catch-up — Rust reader

## Final counts

All 138 scenarios pass: chapter 1 (66), chapter 2 (35), chapter 3 (37). 0 failures.
`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm`, `out/plate-03.ppm`
regenerated and diff exactly 0 against `reference/chapter-03/`.

## New scenarios found and ported

- Chapter 1 `mix`: "The light's way never clamps", "The switch can be passed instead
  of set", "The browser's way clamps each end before encoding it".
- Chapter 1 `ppm`: "A line of exactly 70 characters is allowed", "Counting the
  distinct values in a file", "Files of different sizes are as different as it
  gets", "The same width with a different height is still a different size".
- Chapter 1 `plate`: two new probes ((200,132), (200,177)) in the existing scenario.
- Chapter 2 `centers`: "The center question is not 'at least half'", "A buffer need
  not be square", "A rectangle, by asking each center"; the existing "outside the
  buffer" scenario also gained `coverage_at` reads it hadn't ported yet.
- Chapter 2 `coverage`: "Neither need the buffer be square here".
- Chapter 2 `p6`: "Rows go top to bottom", "The binary writer clamps too", "Pixel
  bytes that look like whitespace are still pixel bytes".
- Chapter 3 `bresenham`: "lit_pixels reads like a page".
- Chapter 3 `quad`: "A line of no length is a square", "A wider line", "An off-axis
  line runs through pixel centers, not corners".
- Chapter 3 `wu`: "A line that starts above the canvas", "A Wu line of one point".

## Bugs the new scenarios found (the useful part)

1. **`mix`, browser mode, didn't clamp.** It encoded `a` and `b` directly, so
   `color(1.5, 0.5, -0.2)` fed `encode()` a negative light value and produced
   nonsense. Fixed by clamping each end to 0..1 *before* encoding (not the mixed
   result — that's the exact trap the book warns about, and it only shows at
   `t = 0.5`, not `t = 0`). Caught by "The browser's way clamps each end before
   encoding it."
2. **`coverage_at` had no bounds check at all.** A negative `x`/`y` cast straight
   to `usize` (wrapping to a huge index) and a positive out-of-range one indexed
   past the end of the `Vec` — both panicked instead of returning 0. This had been
   hiding because the one test that exercised out-of-range coordinates only
   checked `ink(cov) = 0`, never called `coverage_at` on them. Fixed with an
   explicit bounds check before the cast, and the test now actually calls
   `coverage_at` at (-1,1), (4,1), (1,3).
3. **`paint_through` respected the linear-blending switch.** It called the
   switch-aware `mix()`, so with blending off it ran the browser's
   encode/lerp/decode instead of compositing in light — wrong for the one place
   in the renderer that isn't supposed to care about the switch. Added
   `mix_with(a, b, t, linear)` and had `paint_through` call it with `linear: true`
   unconditionally. The existing test for this ("The arithmetic is on light,
   whatever the switch says") never actually set the switch off, so it passed by
   accident; fixed the test to flip it first, which is what exposed the bug.
4. **`thick_line` with equal endpoints divided by zero.** Segment length 0 made
   `dx /= len` a `0.0 / 0.0 = NaN`, producing a garbage shape instead of the
   width-by-width square the chapter promises. Fixed per the book's own
   pseudocode: zero length gets direction `(1, 0)` and the two coincident ends
   pushed apart by half the width each.

## Ambiguity

Nothing serious. `mix`'s "switch can be passed instead of set" doesn't map onto a
default-argument overload in Rust, so it's a separate `mix_with(a, b, t, linear)`
function rather than a 4th optional parameter on `mix` — any reader in a language
without optional args will hit the same fork.

## The 9.71875 diagonal scenario

Passes exactly as written: `assert!(approx_eq(ink(&cov), 9.71875))`. `half_plane_inside`
computes `dx * nx + dy * ny` as two ordinary multiplies and an add, no `mul_add`
anywhere in the renderer, and rustc/LLVM does not contract that into an FMA by
default (unlike C/C++, which often leave contraction on) — confirmed on this
machine (Apple Silicon, `cargo test --release`) by the test coming back green with
the exact value rather than 9.65625.
