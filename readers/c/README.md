# The 2D Renderer Challenge — chapters 1 to 4, in C11

Run everything from this directory (the tests read `reference/` by relative path).

    make          # build bin/tests and bin/render (clang, -std=c11, libm)
    make test     # every scenario in features/, chapters 1 to 4
    make render   # write the chapters' pictures into out/

`make test` prints a per-chapter subtotal and then a total; it exits non-zero if
anything failed. `TIMING=1 ./bin/tests` adds a per-feature time.

`make render` writes chapter 1's pictures as P3 text (`out/gray-match.ppm`,
`quarter-match`, `ramp`, `clamp-pair`, `plate-01`), chapter 2's as P6 binary
(`out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
`out/plate-02.ppm`), chapter 3's as P6 binary (`out/fan-bresenham.ppm`,
`out/fan-wu.ppm`, `out/fan-coverage.ppm`, `out/plate-03.ppm`) and chapter 4's
as P6 binary (`out/fan-both-orders.ppm`, `out/plate-04.ppm`). Everything from
chapter 2 on is byte-identical to the matching file under `reference/`.

Layout: `src/renderer.h` and `src/renderer.c` are the renderer, `src/tests.c` is
one function per feature file and one `S(...)` block per scenario,
`src/harness.c` is the assert helpers, `src/main.c` writes the pictures.

Chapter 3 adds `line_bresenham`, `plot`, `line_wu` and the `thick_line` shape
(a fourth `ShapeKind`, four inward-facing half-planes stored in `Shape.h`), plus
`ray_ends`, `fan_bresenham`, `fan_wu`, `fan_coverage` and `plate_03`.
`lit_pixels` and `total_ink` are test helpers and live in `src/harness.c`.

Chapter 4 adds `Tuple` (`point`, `vector`, `tuple_add`/`_sub`/`_neg`/`_scale`/
`_div`, `magnitude`, `normalize`, `dot`, `cross`) and `Matrix3` (`matrix3`,
`m3_at`, `identity`, `transpose`, `minor`, `cofactor`, `determinant`,
`is_invertible`, `inverse`, the four transforms and `approx_scale`), plus the
`segment`, `union_of` and `transformed` shapes, `outline`, `transform_points`,
`side_by_side`, `fan_points`, `letter_f`, `fan_transformed`, `fan_both_orders`,
`f_both_orders` and `plate_04`. `thick_line` is now one line on top of
`segment`, so chapter 3's scenarios exercise chapter 4's code.

Three things the book's names cost in C:

* `union` is a keyword, so the book's `union(shapes)` is `union_of(parts, n)`.
* `minor` is a macro in `<sys/types.h>` outside strict ANSI mode, so
  `renderer.h` `#undef`s it before declaring the function.
* `A * B` and `A * p` are `mul(a, b)`, a `_Generic` macro in `renderer.h` that
  picks `m3_mul` or `m3_mul_tuple` by the type of the second argument.

A `Shape` can't contain itself, so a union owns a heap array of its parts and a
transformed shape owns a heap copy of its base. `union_of`, `transformed` and
`outline` allocate; `shape_free` gives it back and is a no-op for leaf shapes.
Copying a composite `Shape` by value shares the children, so free the copy or
the original, not both.

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
