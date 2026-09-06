# The 2D Renderer Challenge — chapters 1 to 6, in C11

Run everything from this directory (the tests read `reference/` by relative path).

    make          # build bin/tests and bin/render (clang, -std=c11, libm)
    make test     # every scenario in features/, chapters 1 to 6
    make render   # write the chapters' pictures into out/

`make test` prints a per-chapter subtotal and then a total; it exits non-zero if
anything failed. `TIMING=1 ./bin/tests` adds a per-feature time.

`make render` writes chapter 1's pictures as P3 text (`out/gray-match.ppm`,
`quarter-match`, `ramp`, `clamp-pair`, `plate-01`), chapter 2's as P6 binary
(`out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
`out/plate-02.ppm`), chapter 3's as P6 binary (`out/fan-bresenham.ppm`,
`out/fan-wu.ppm`, `out/fan-coverage.ppm`, `out/plate-03.ppm`), chapter 4's
as P6 binary (`out/fan-both-orders.ppm`, `out/plate-04.ppm`), chapter 5's as
P6 binary (`out/star-centers.ppm`, `out/star-coverage.ppm`, `out/plate-05.ppm`)
and chapter 6's as P6 binary (`out/spiral.ppm`, `out/plate-06.ppm`). Everything
from chapter 2 on is byte-identical to the matching file under `reference/`.

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
and `plot` (chapter 3's antialiased line, one pixel of `paint_through`) both
always call the four-argument form with `true`: the browser-style switch has
no business inside the rasterizer, so painting ignores it even when a
scenario has turned it off.

Chapter 5 adds `Path` (`path`, `path_free`, `move_to`, `line_to`, `close`), a
list of `Subpath`s exposed as public fields the way `Canvas` exposes
`width`/`height`/`pixels`: `p->subpaths[i].points[j]`, `p->subpaths[i].closed`,
`p->n_subpaths` (the book's `length(subpaths(p))`). `edges(p, &n)` and
`bounds(p)` are real functions, since they're derived views, not stored data;
`edges` hands out a heap array the caller frees. `polygon(p1, p2, ...)` is a
variadic macro over `polygon_pts(pts, n)`, built the same way the book writes
it (a compound literal array under the hood, mirroring `EQ_PIXELS`'s trick in
the test harness). `crossings` and `winding_at` walk each subpath's points
directly, with wraparound, rather than materializing `edges()`, because
`coverage()` calls them up to sixty-four times a pixel. `filled(p, rule)` is a
new `ShapeKind`, `SHAPE_FILLED_PATH`, holding a private deep copy of the path
(`shape_free` gives it back) and an `int rule` (0 nonzero, 1 evenodd) instead
of the book's string, since the string only has to survive the call that
reads it. `rasterize_within(shape, box, w, h)` sits next to chapter 2's
`rasterize`/`rasterize_centers`. `star`, `star_panel`, `star_centers`,
`star_coverage` and `plate_05` are chapter 5's picture.

Chapter 6 adds the classical scanline fill: `EdgeEntry` (`edge_table`,
`x_at`), `Crossing` (`crossings_on_row`), `Span` (`spans_from_crossings`,
`spans`, `fill_span`) and `fill_path_aliased`, which sweeps rows with an
active edge list built by walking chapter 5's `edge_table` once, front to
back. `max_coverage_difference` sits next to chapter 1's
`max_channel_difference`, for the same reason: it has to return something
meaningful (1) when the two buffers are different sizes, or a transposed
sweep could compare equal to the reference. `transform_path(p, m)` is
`transform_points` with the subpath structure and closed flags kept, used by
`unit_star`, `spiral` and `plate_06`.

One naming collision worth flagging: `close` is also a POSIX function
(`<unistd.h>`, closing a file descriptor). Nothing in this project includes
`<unistd.h>`, so the book's `close(Path *)` is the only `close` in scope and
the build is clean, but a project that also touches file descriptors would
need to rename one of the two.
