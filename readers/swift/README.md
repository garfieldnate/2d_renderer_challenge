# The 2D Renderer Challenge — Swift

Chapters 1–6. Plain `swiftc`, no SwiftPM, no dependencies, no network.
Run everything from this directory.

```sh
./build.sh          # swiftc -O -o run Sources/*.swift
./run               # runs all 284 scenarios, per-chapter counts, exits non-zero on failure
./run render        # writes out/ — chapter 1 as P3, chapters 2-6 as P6
```

`Sources/Renderer.swift` is the renderer (sections numbered as in the book),
`Sources/Tests.swift` is one `scenario` per Gherkin scenario in `features/`,
`Sources/main.swift` is the entry point.

Chapter 2 writes `out/disc-centers.ppm`, `out/disc-coverage.ppm`,
`out/painted-twice.ppm` and `out/plate-02.ppm`; chapter 3 adds
`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm` and
`out/plate-03.ppm`; chapter 4 adds `out/fan-both-orders.ppm` and
`out/plate-04.ppm`; chapter 5 adds `out/star-centers.ppm`,
`out/star-coverage.ppm` and `out/plate-05.ppm`; chapter 6 adds
`out/spiral.ppm` and `out/plate-06.ppm`. All sixteen P6 renders (plus
chapter 1's five P3 ones) are byte-identical to `reference/`.

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

## Testing chapter 4

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

## Chapter 5 — Paths and Insideness

`Path` is a class holding `[Subpath]`; `Subpath` is `{ points: [Tuple], closed:
Bool }`. `path()`, `moveTo`/`lineTo`/`close` (free functions taking the path),
`subpaths(p)`, `edges(p)` (every subpath treated as closed, one point ⇒ no
edges), and `bounds(p)` (`(0,0,0,0)` for an empty path) implement §5.1 exactly
as specified, including `lineTo` after a `close` restarting a subpath at the
closed one's first point. `polygon(points...)` and `circlePath(cx, cy, r, n)`
(first point on the right, increasing angle — clockwise on the canvas) build
on top.

`crossings(p, x, y)` uses the book's `x = a.x + t·(b.x - a.x)` formula with
the half-open span test; `windingAt(p, x, y)` is the cross-product pseudocode
verbatim, division-free. `insideNonzero`/`insideEvenOdd`, `filled(p, rule)`
(one more `Shape`), and `rasterizeWithin(shape, box, w, h)` (columns
`floor(minX)..<ceil(maxX)`, clipped) round out §5.2–5.3. `star()`,
`starPanel`, `starCenters`, `starCoverage`, `plate05` implement §5.4.

## Chapter 6 — Filling a Polygon

`Edge` is `{ yTop, yBottom, xTop, slope, direction }`; `xAt(edge, y)` is
`xTop + (y - yTop) * slope`. `edgeTable(p)` drops horizontal edges (`a.y ==
b.y` exactly — no epsilon) and sorts by `yTop` then `xTop`. `crossingsOnRow`,
`spansFromCrossings` (walks sorted crossings, accumulating the winding
number under either rule) and `spans(p, rule, row)` implement §6.2 exactly
as pseudocoded. `fillSpan(cov, row, x0, x1)` is half-open at `x1`
(`ceil(x0-0.5) ... ceil(x1-0.5)-1`, clipped, a no-op when the range inverts).
`fillPathAliased` is the classical active-edge-list sweep, read once,
front to back; `maxCoverageDifference` is chapter 1's
`max_channel_difference` for coverage buffers. `transformPath(p, m)` is
`transformPoints` with the subpath structure (and closed flags) kept, the
original untouched. `unitStar()`, `spiral()`, `plate06()` implement §6.5.

## Testing chapters 5 and 6

Ran the full suite (`./run`, 284 scenarios) and rendered (`./run render`);
diffed all five new PPMs (`star-centers`, `star-coverage`, `plate-05`,
`spiral`, `plate-06`) against `reference/` — all byte-identical
(max_channel_difference = 0). Chapter 5's coverage-based renders
(`star_coverage()` + `plate_05()`, four 64-samples-a-pixel panels) took
1.17–1.67s; chapter 6's sweep-based renders (`spiral()` + `plate_06()`,
forty-eight scanline fills of a 320×320 canvas) took 0.029–0.031s — the
chapter's whole point about the sweep, confirmed on this machine.

Catch-up before starting: five scenarios already present in the chapter
1–4 feature files had never been translated into `Tests.swift` (`The
weights are applied in light, whatever the switch says`, `magnitude and
dot look at x and y only`, `Invertibility is an exact test against zero`,
`A union of nothing is inside nowhere`, `side_by_side puts the first
canvas on the left`). Adding the first of these caught a real bug: `plot`
(chapter 3, Wu's line) was calling the switchable `mix()` instead of
`mix(..., true)`, so with `linearBlending` off, Wu's antialiasing weights
were wrongly gamma-blended. Fixed and added all five scenarios; the other
four passed on the existing code with no fix needed. Full details,
including mutation-testing results (one genuine gap found in
`crossings()`), are in `FEEDBACK.md` (not part of this reader submission).
