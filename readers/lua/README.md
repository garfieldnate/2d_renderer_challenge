# The 2D Renderer Challenge — Lua 5.4

A from-scratch Lua 5.4 implementation of chapters 1 through 6 of *The 2D Renderer
Challenge*: the canvas and sRGB, coverage-based antialiasing, Bresenham's and Wu's
lines, points/vectors/matrices, paths and the winding number, and the scanline sweep.

Standard library only. No LuaRocks, no third-party modules. A tiny hand-rolled test
runner lives in `spec/helpers.lua`.

## Run the tests

From the repository root:

```sh
lua run_tests.lua
```

This requires every `spec/chapterNN_spec.lua` file (each one a line-by-line
translation of the matching `features/chapterNN-*.feature` scenarios), runs every
registered test, and prints a pass/fail summary. Exit code is 0 iff everything
passed.

## Write the renders

```sh
lua render_all.lua
```

This writes every named render (`gray_match()`, `disc_coverage()`, `spiral()`, the
plates, and so on) to `out/`, under the same filenames the reference images use,
and prints each one's `max_channel_difference` against `reference/chapter-0N/*.ppm`.
Anything over 1 is flagged and the script exits non-zero.

## Layout

```
src/
  color.lua      chapter 1: color, sRGB encode/decode, mix, the linear-blending switch
  canvas.lua     chapter 1: canvas, write_pixel, pixel_at, fill
  ppm.lua        chapters 1-2: canvas_to_ppm (P3), canvas_to_p6 (P6), the file readers
  coverage.lua   chapter 2: coverage_buffer, magnify, paint_through, max_coverage_difference
  shapes.lua     chapters 2-4: circle/rectangle/half_plane, union, transformed,
                 thick_line, segment, outline, the two rasterizers
  lines.lua      chapter 3: line_bresenham, line_wu, plot, total_ink
  tuple.lua      chapter 4: point, vector, magnitude, normalize, dot, cross
  matrix.lua     chapter 4: matrix3, the four transforms, approx_scale
  path.lua       chapter 5: path, move_to/line_to/close, subpaths, edges, bounds
  winding.lua    chapter 5: crossings, winding_at, inside_nonzero/evenodd, filled
  sweep.lua      chapter 6: edge_table, spans, fill_span, fill_path_aliased, transform_path
  renders.lua    every named render/plate function, chapter by chapter

spec/
  helpers.lua           the test runner and shared assertion helpers
  chapterNN_spec.lua    one file per chapter, one test per scenario

run_tests.lua    entry point: runs the whole suite
render_all.lua   entry point: writes out/*.ppm and diffs against reference/
out/             renders land here (gitignored upstream; not part of this checkout)
features/        the book's Gherkin scenarios (read-only)
reference/       the book's reference PPMs (read-only)
```

## Conventions carried over from the book

- All pixel and matrix indices are 0-based at the API surface (`write_pixel(c, x, y,
  col)`, `mat_get(M, r, c)`), matching the book's own scenarios exactly, even though
  Lua tables are 1-indexed internally.
- The canvas stores linear light. Clamp, encode, scale to 255, round — in that order
  — only happens in the PPM writer.
- `mix(a, b, t, linear)` takes the global linear-blending switch as an optional 4th
  argument (the pure-function form the book offers for languages that dislike mutable
  globals); when omitted it reads `color.get_linear_blending()` / defaults to on.
  Tests that need it off use `T.with_linear_blending(false, function() ... end)`,
  which restores the previous value afterward even if the test fails, so one
  scenario's `Given linear blending is off` never leaks into the next.
- Shapes are tables of one field, `inside = function(x, y) -> boolean`. `union`,
  `intersection` (used inside `thick_line`), and `transformed` are combinators over
  that same shape.
- A path is `{ subpaths = { {points=[...], closed=bool}, ... } }`.

See `FEEDBACK.md` for what broke, what was ambiguous, and the mutation-testing
results.
