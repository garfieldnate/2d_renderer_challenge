# The 2D Renderer Challenge — Java

Chapters 1-8, hand-rolled test runner, no JUnit, no network.

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
java -cp classes Chapter07Tests
java -cp classes Chapter08Tests
```

Each run prints one `PASS`/`FAIL` line per scenario, a pass/fail total, and
then writes that chapter's renders to `out/` (chapter 1 as P3, chapters 2-8 as
P6): `out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
`out/plate-02.ppm`, `out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
`out/fan-coverage.ppm`, `out/plate-03.ppm`, `out/fan-both-orders.ppm`,
`out/plate-04.ppm`, `out/star-centers.ppm`, `out/star-coverage.ppm`,
`out/plate-05.ppm`, `out/spiral.ppm`, `out/plate-06.ppm`, `out/needles.ppm`,
`out/soft-square.ppm`, `out/star-exact.ppm`, `out/spiral-smooth.ppm`,
`out/plate-07.ppm`, `out/drops.ppm`, `out/flower.ppm`, `out/plate-08.ppm`.

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

## Chapter 7

Analytic antialiasing: `Accumulator(w, h)` (the book's `accumulator(w, h)`),
two numbers per cell -- `areaAt(x, y)`, `coverAt(x, y)`, `addCell(x, row,
area, cover)` (a deposit left of the buffer folds onto column 0 as pure
cover; one right of it is dropped). `Fill.accumulateRow(acc, row, x0, x1,
height)` deposits one edge's piece of one row, splitting it at cell
boundaries and weighting each slice's area by how far left of its cell the
piece's midpoint sits. `Fill.accumulate(acc, a, b)` walks a whole edge down
the rows it crosses (heading up the canvas is a positive height, down is
negative; horizontal is dropped). `Fill.applyRule(winding, rule)` and
`Fill.resolve(acc, rule)` turn the accumulator into a `CoverageBuffer` by one
left-to-right running sum per row. `Fill.fillPath(p, rule, w, h)` is the
fill from here on, replacing chapter 6's `fillPathAliased`.
`Fill.polygonArea(p)` is the shoelace formula, unsigned.

Watch out for near-vertical edges that aren't bit-identical in x at both
ends (a rotation by exactly pi/2 doesn't produce a clean 0): treating
`x0 == x1` by exact equality sends such an edge through the general
multi-cell branch, where `height * segWidth / dx` divides by a dx of a few
`1e-14` and the area blows up by a dozen orders of magnitude. `Fill` guards
this with a small epsilon (`VERTICAL_EPSILON`); it's what chapter 6's
spiral, re-filled exactly, turned up immediately.

`Figures` adds `needlePath()`, `needles()`, `softSquare()`, `starExact()`,
`spiralSmooth()`, `sunburst()`, and `plate07()`. §7.6 now prints
`needle_path()` and `rays(i)` in full, and both match the chapter's
pseudocode exactly: every wedge (a needle or a ray) is `add_wedge(p, cx, cy,
r, angleDeg, halfDeg)`, a triangle from the center to two points at radius
`r` on the angles `angleDeg - halfDeg` and `angleDeg + halfDeg` -- not a
perpendicular offset from a single radial endpoint, which was this reader's
earlier (wrong) guess. See FEEDBACK.md's Catch-up section for what that
guess got wrong and by how much.

## Chapter 8

Curves: `Curve.quadratic(p0, p1, p2)` / `Curve.cubic(p0, p1, p2, p3)` hold a
Bezier's control points. `Curves.pointAt(c, t)` is de Casteljau's
construction; `Curves.splitAt(c, t)` keeps the pyramid's two edges as two
new curves; `Curves.derivative(c, t)` is n times de Casteljau on the
control points' successive differences; `Curves.transformCurve(c, m)` takes
every control point through `m`.

`Curves.curveBounds(c)` is the tight box: the derivative is itself a lower
degree Bezier, so its zero (linear for a quadratic's derivative, the
quadratic formula for a cubic's) is solved directly per axis rather than by
search, and the curve is evaluated at those roots (kept within `[0, 1]`)
and at both ends.

`Curves.flatness(c)` is the farthest an interior control point strays from
the chord between the ends; `Curves.flatten(c, tolerance)` recursively
`splitAt(0.5)` until every piece is flat enough and returns the endpoints,
first to last. `Curves.polylineLength`/`Curves.flattenLength` measure it.
`Curves.flattenIntoPath(p, c, tolerance)` appends a flattened curve to a
path with `lineTo` -- `Path`'s own rule for no current point, or a line_to
right after a close, does the rest.

The SVG elliptical arc: `Arc.arc(x1, y1, rx, ry, phi, largeArc, sweep, x2,
y2)` is the W3C endpoint-to-center conversion (radii grown together when
they're too small to reach, `corrected` set; `null` for coincident
endpoints or a zero radius -- Java's "none"). `Arc.arcPoint(a, t)` walks it.

`Figures` adds `flower()` and `plate08()` from the chapter's own
`flower_at`/`flower`/`plate_08` pseudocode, plus `drops()`. §8.3 and §8.5
now print `petal()`'s two cubics, the three flowers' exact spots (center,
scale, petal count, turn), and `teardrop()`'s two cubics, and all three
match the chapter's pseudocode exactly (the teardrop is its own shape in a
60 by 60 box, not the petal reused at a different scale). `drops()`,
`flower()` and `plate08()` all diff 0 against the reference bytes now. See
FEEDBACK.md's Catch-up section for what the earlier guesses got wrong.
