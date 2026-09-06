# The 2D Renderer Challenge — Java

Chapters 1-6, hand-rolled test runner, no JUnit, no network.

## Compile, test, render

Run from this directory (`reference/` and `features/` resolve as relative paths):

```
javac -d classes src/*.java
java -cp classes Chapter01Tests
java -cp classes Chapter02Tests
java -cp classes Chapter03Tests
java -cp classes Chapter04Tests
java -cp classes Chapter05Tests
java -cp classes Chapter06Tests
```

Each run prints one `PASS`/`FAIL` line per scenario, a pass/fail total, and
then writes that chapter's renders to `out/` (chapter 1 as P3, chapters 2-6 as
P6): `out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
`out/plate-02.ppm`, `out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
`out/fan-coverage.ppm`, `out/plate-03.ppm`, `out/fan-both-orders.ppm`,
`out/plate-04.ppm`, `out/star-centers.ppm`, `out/star-coverage.ppm`,
`out/plate-05.ppm`, `out/spiral.ppm`, `out/plate-06.ppm`.

## Chapter 3

Lines: Bresenham (`Lines.lineBresenham`), Wu (`Lines.lineWu`), and a line as
a thin rectangle (`ThickLine`, a `Shape` built from four `HalfPlane`s and
rasterized with chapter 2's supersampler). `Lines.litPixels` and
`Lines.totalInk` are the chapter's test helpers.

## Chapter 4

Points and vectors: `Tuple` (`Tuple.point(x, y)`, `Tuple.vector(x, y)`), with
`add`/`subtract`/`negate`/`scale`/`divide`, `magnitude`/`normalize`, and the
static `Tuple.dot`/`Tuple.cross`.

Matrices: `Matrix` (`Matrix.matrix3(...)`, `Matrix.identity()`), row-major,
`get(r, c)`, `multiply` (matrix-by-matrix and matrix-by-tuple), `transpose`,
`minor`/`cofactor`/`determinant`, `isInvertible`, `inverse`.

Transforms: `Transforms.translation/scaling/rotation/shearing`, each
returning a `Matrix`, plus `Transforms.approxScale(m)` (§4.4: the square
root of the absolute value of the determinant of the upper-left 2 by 2).

Shapes, extended: `Segment` (chapter 3's `ThickLine` with real `Tuple`
endpoints instead of pixel indices; `ThickLine` is now a one-line wrapper
around it, per the chapter's refactor), `Union` (inside when any part is),
`Transformed` (a shape seen through a matrix's inverse). `Shapes` holds the
two free functions: `transformPoints(points, m)` and `outline(points, m,
width)` (the closed polygon through the points after `m`, as one `Union` of
`Segment`s, so shared corners are painted once).

`Figures` adds `fanPoints`, `letterF`, `fanTransformed`, `sideBySide`,
`fanBothOrders`, `fBothOrders`, and `plate04`.

## Chapter 5

Paths: `Path` (`new Path()` for the book's `path()`), with `moveTo`/`lineTo`/
`close`, `subpaths()` (a list of `Subpath`, each a mutable `points` list plus
a `closed` flag), `edges()` (a list of `Edge(a, b)`, every subpath treated as
closed for filling purposes regardless of the flag), and `bounds()` (a
`Bounds(minX, minY, maxX, maxY)` record, `(0, 0, 0, 0)` when empty).
`Paths.polygon(points...)` and `Paths.circlePath(cx, cy, r, n)` build paths
directly.

Insideness: `Winding.crossings(p, x, y)` and `Winding.windingAt(p, x, y)`,
both the half-open rule from the chapter's trap (`a.y &lt;= y &lt; b.y`, never
`&lt;=` at both ends). `Winding.insideNonzero`/`insideEvenodd` are one line on
top of `windingAt`. `Paths.filled(p, rule)` ("nonzero" or "evenodd") is a
`Shape` (`FilledPath`) that goes through chapter 2's rasterizer.
`Paths.rasterizeWithin(shape, bounds, w, h)` is chapter 2's `rasterize`
restricted to the pixels the box touches.

`Figures` adds `star()`, `starPanel(rule, method)`, `starCenters()`,
`starCoverage()`, and `plate05()`.

## Chapter 6

The scanline sweep: `TableEdge(yTop, yBottom, xTop, slope, direction)` and
`EdgeTable.edgeTable(p)` (sorted by `y_top` then `x_top`, horizontal edges
dropped), `EdgeTable.xAt(edge, y)`. `Crossing(x, direction)` and
`Span(x0, x1)`; `Spans.crossingsOnRow(table, y)`,
`Spans.spansFromCrossings(xs, rule)`, `Spans.spans(p, rule, row)`, and
`Spans.fillSpan(cov, row, x0, x1)` (half-open at the right end).
`Sweep.fillPathAliased(p, rule, w, h)` is the classical active-edge-list
sweep, pixel-identical to chapter 5's `rasterizeCenters(filled(p, rule), w,
h)`. `CoverageBuffer.maxCoverageDifference(a, b)` is chapter 1's
`maxChannelDifference` for coverage buffers (1 when the sizes differ).
`Paths.transformPath(p, m)` takes every point of every subpath through `m`,
closed flags and all, leaving the original untouched.

`Figures` adds `unitStar()`, `spiral()`, and `plate06()`.
