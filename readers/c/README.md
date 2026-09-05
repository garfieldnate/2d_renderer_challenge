# The 2D Renderer Challenge — chapters 1 to 3, in C11

Run everything from this directory (the tests read `reference/` by relative path).

    make          # build bin/tests and bin/render (clang, -std=c11, libm)
    make test     # every scenario in features/, chapters 1 to 3
    make render   # write the chapters' pictures into out/

`make test` prints a per-chapter subtotal and then a total; it exits non-zero if
anything failed. `TIMING=1 ./bin/tests` adds a per-feature time.

`make render` writes chapter 1's pictures as P3 text (`out/gray-match.ppm`,
`quarter-match`, `ramp`, `clamp-pair`, `plate-01`), chapter 2's as P6 binary
(`out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
`out/plate-02.ppm`) and chapter 3's as P6 binary (`out/fan-bresenham.ppm`,
`out/fan-wu.ppm`, `out/fan-coverage.ppm`, `out/plate-03.ppm`). The chapter-2
and chapter-3 files are byte-identical to `reference/chapter-02/` and
`reference/chapter-03/`.

Layout: `src/renderer.h` and `src/renderer.c` are the renderer, `src/tests.c` is
one function per feature file and one `S(...)` block per scenario,
`src/harness.c` is the assert helpers, `src/main.c` writes the pictures.

Chapter 3 adds `line_bresenham`, `plot`, `line_wu` and the `thick_line` shape
(a fourth `ShapeKind`, four inward-facing half-planes stored in `Shape.h`), plus
`ray_ends`, `fan_bresenham`, `fan_wu`, `fan_coverage` and `plate_03`.
`lit_pixels` and `total_ink` are test helpers and live in `src/harness.c`.

`src/renderer.c` sets `#pragma STDC FP_CONTRACT OFF`. Chapter 3's
`ink(cov) = 9.71875` scenario depends on sample points that land exactly on a
half-plane edge counting as inside; letting the compiler fuse `a*b + c*d` into
an fma breaks that exact cancellation and the answer comes out 9.65625.

`mix(a, b, t)` reads the global `linear_blending` switch; `mix(a, b, t, linear)`
is the same function with the switch passed explicitly instead (a variadic
macro in `renderer.h` picks `mix3` or `mix4` by argument count). `paint_through`
always calls the four-argument form with `true`: the browser-style switch has
no business inside the rasterizer, so painting ignores it even when a
scenario has turned it off.
