# The 2D Renderer Challenge — Swift

Chapters 1–4. Plain `swiftc`, no SwiftPM, no dependencies, no network.
Run everything from this directory.

```sh
./build.sh          # swiftc -O -o run Sources/*.swift
./run               # runs all 210 scenarios, per-chapter counts, exits non-zero on failure
./run render        # writes out/ — chapter 1 as P3, chapters 2-4 as P6
```

`Sources/Renderer.swift` is the renderer (sections numbered as in the book),
`Sources/Tests.swift` is one `scenario` per Gherkin scenario in `features/`,
`Sources/main.swift` is the entry point.

Chapter 2 writes `out/disc-centers.ppm`, `out/disc-coverage.ppm`,
`out/painted-twice.ppm` and `out/plate-02.ppm`; chapter 3 adds
`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm` and
`out/plate-03.ppm`; chapter 4 adds `out/fan-both-orders.ppm` and
`out/plate-04.ppm`. All ten are byte-identical to `reference/`.

Build with `-O`. Unoptimized the suite takes noticeably longer, especially
the chapter 3/4 rasterizations.

`fan_coverage()` — twelve 160x160 rasterizations at 64 samples/pixel — took
0.020s standalone with `-O` on this machine (`./run render` prints the timing
each time). `paint_through` always mixes in linear light, regardless of the
`linearBlending` switch (see § 2.5); it does not call the switchable `mix()`.

## Chapter 4 — Points, Vectors, Transforms

`Tuple` is (x, y, w): `point(x, y)` sets w = 1, `vector(x, y)` sets w = 0.
The usual arithmetic (`+`, `-`, unary `-`, `*` and `/` by a scalar,
`magnitude`, `normalize`, `dot`, `cross`) all live on `Tuple`.

`Matrix3` is nine `Double`s, row by row, with `M[r, c]` as a subscript.
`matrix3(...)` builds one from nine numbers (what a Gherkin data table
becomes when translating a scenario by hand); `identity()`, `transpose`,
`determinant`, `is_invertible` (→ `isInvertible`), and `inverse` follow the
book's cofactor-expansion pseudocode exactly, including the transpose
folded into the assignment (`cells[c * 3 + r] = cofactor(...) / d`).
`translation`, `scaling`, `rotation`, `shearing` each build a `Matrix3`;
`approx_scale` (→ `approxScale`) is `sqrt(abs(m[0,0]*m[1,1] - m[0,1]*m[1,0]))`.

`segment(a, b, width)` is chapter 3's `thick_line` factored out to real
endpoints; `thickLine` is now a one-liner on top of it, and every chapter 3
scenario for it still passes (byte-identical renders, confirmed by diffing
`out/` against `reference/chapter-03/` after the refactor). `union`,
`transformed` (backed by `inverse`, empty when the matrix isn't invertible),
`transformPoints`, and `outline` (closed, points-through-`m`-first, drawn as
one shape so shared corners are painted once) round out the chapter.

`fanPoints`, `fanTransformed`, `fanBothOrders`, `letterF`, `fGhost`,
`fBothOrders`, `plate04`, plus the small `copyCanvas` and `sideBySide`
helpers, implement § 4.6's two renders.

## Testing this chapter

Ran the full suite (`./run`), rendered (`./run render`), and diffed
`out/fan-both-orders.ppm` and `out/plate-04.ppm` against
`reference/chapter-04/` — both byte-identical (max_channel_difference = 0).
Also tried six plausible reader mistakes (transposed matrix multiply, sine
negated in `rotation`, `approx_scale` defined as the longest column instead
of sqrt(determinant), `transformed` applying `m` instead of `inverse(m)`,
`outline` not closing its last edge, `letterF` built from `vector` instead
of `point`, and rotating by 30 read as radians) as one-line mutations to
`Renderer.swift`, one at a time, and confirmed at least one chapter 4
scenario failed for every one of them before reverting. Details in
`FEEDBACK.md` (not part of this reader submission).
