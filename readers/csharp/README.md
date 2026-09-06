# The 2D Renderer Challenge — C# / .NET 8

Chapters 1 through 6, implemented against a hand-rolled test runner (no
NuGet, no network; the SDK is enough).

## Build, test, render

```
export PATH="/opt/homebrew/Cellar/dotnet@8/8.0.127/libexec:$PATH"
dotnet run
```

That one command builds the project, runs every scenario from
`features/*.feature` (all six chapters), prints a pass/fail summary per
feature, and writes all renders to `out/` (P3 for chapter 1, P6 from
chapter 2 on). Everything - build, 279 scenarios, all nineteen renders -
finishes in well under twenty seconds.

## Chapter 6

`EdgeTable.cs` adds `Edge` (`YTop`, `YBottom`, `XTop`, `Slope`,
`Direction`) and `EdgeTable.Build(path)`, which walks `path.Edges()`,
drops every edge with `a.Y == b.Y` **exactly** (horizontal - not
clamped, not given a fake slope), and sorts what's left by `y_top` then
`x_top`. `EdgeTable.XAt(edge, y)` is `x_top + (y - y_top) * slope`.

`Sweep.cs` is the rest of the scanline fill: `CrossingsOnRow(table, y)`
(half-open, `y_top <= y < y_bottom`, sorted by x),
`SpansFromCrossings(xs, rule)` (walks the crossings, accumulating the
winding number, "nonzero" is `w != 0`, "evenodd" is `w % 2 != 0`),
`Spans(path, rule, row)` (both together for one row), `FillSpan(cov,
row, x0, x1)` (half-open at the right end: `first = ceil(x0 - 0.5)`,
`last = ceil(x1 - 0.5) - 1`, clipped to the buffer), and
`FillPathAliased(path, rule, w, h)`, the sweep itself: an active edge
list that only ever grows by taking edges off the front of the
(already-sorted) table and only ever shrinks by dropping edges whose
`y_bottom <= y` - the same half-open rule a third time, which is what
makes an edge active on the row where it starts and not on the row
where it ends. `MaxCoverageDifference(a, b)` is chapter 1's
`max_channel_difference` for `CoverageBuffer`s: 1 when the sizes differ.

`Path.cs` adds `Path.TransformPath(path, m)`: a new path with every
point of every subpath (closed flags kept) run through `m`; the
original path is untouched.

`Renders.cs` adds `UnitStar()` (chapter 5's star moved to the origin
and shrunk to radius 1: `TransformPath(Star(), Scaling(1/70, 1/70) *
Translation(-80.5, -80.5))`), `Spiral()` (24 copies of it along a
spiral, filled nonzero by `Sweep.FillPathAliased`, three inks in
rotation) and `Plate06()`.

`out/spiral.ppm` and `out/plate-06.ppm` both match
`reference/chapter-06/*.ppm` **byte for byte** (`max_channel_difference`
of 0 on both). Every `fill_path_aliased` scenario also checks its result
against chapter 5's `rasterize_centers(filled(path, rule), w, h)` with
`max_coverage_difference = 0` - the sweep and the slow reference agree
pixel for pixel on every shape the scenarios throw at it.

**Gotcha for C# readers:** `Path` collides with `System.IO.Path`, which
is a global using in this project (`ImplicitUsings`). Every reference to
the book's path type in `Program.cs` is written `Chapter01.Path` to
disambiguate; inside the library itself there's no ambiguity, since
`System.IO` isn't referenced there. A reader who names the type
something other than `Path` avoids this entirely; we kept the book's
name and qualified the few dozen call sites instead.

## Chapter 5

`Path.cs` adds `Path` (a list of `Subpath`s, each with `.Points` and
`.Closed`), built by `MoveTo`, `LineTo` and `Close()`. `LineTo` on an
empty path behaves like `MoveTo`; `LineTo` right after `Close()` starts
a new subpath at the point the closed one began (not just the new
point) - that's the one rule easy to get wrong, and it has its own
scenario and its own mutation-tested check below. `Edges()` treats every
subpath as closed regardless of the flag, so an open triangle still has
three edges; a subpath of one point has none. `Bounds()` is `(0, 0, 0,
0)` for an empty path. `Path.Polygon(points...)` and
`Path.CirclePath(cx, cy, r, n)` are the two builders the scenarios lean
on.

`Winding.cs` adds `Crossings(path, x, y)` and `WindingAt(path, x, y)`,
both using the half-open rule `a.Y <= y < b.Y` (or the mirror image
heading up) so a ray through a vertex counts it exactly once.
`WindingAt` uses `Tuple2.Cross` instead of a division, exactly as the
chapter derives it. `InsideNonzero` and `InsideEvenOdd` are one-line
wrappers (`w != 0` and `w % 2 != 0` - the latter works for negative
winding numbers too, since C#'s `%` keeps the sign of the dividend).

`Shapes.cs` adds `Filled(path, rule)`, one more `IShape`, so any path
goes through the same supersampler as every earlier shape.
`Rasterizer.cs` adds `RasterizeWithin(shape, box, w, h)`, which only
visits the pixels `box` touches (`floor(min x)` to `ceil(max x)`
exclusive, clipped to the buffer).

`Renders.cs` adds `Star()` (five points on a circle of radius 70,
visited every second one), `StarCenters()`, `StarCoverage()` and
`Plate05()`; `Renders.SideBySide` (previously private, used only by
chapter 4) is now `public` since chapter 5's own scenario calls it
directly.

`out/star-centers.ppm`, `out/star-coverage.ppm` and `out/plate-05.ppm`
all match `reference/chapter-05/*.ppm` **byte for byte**.

## Chapter 4

`Tuples.cs` adds `Tuple2`, a point-or-vector: `Tuple2.Point(x, y)` sets
w = 1, `Tuple2.Vector(x, y)` sets w = 0, and `+`, `-`, unary `-`, `*` and
`/` all carry w along for the ride, which is what keeps "point minus
point is a vector" and "point plus vector is a point" true without any
special-casing. `Magnitude()`, `Normalize()`, `Dot` and `Cross` round out
the vector operations.

`Matrix.cs` adds `Matrix3`, a 3-by-3 built from nine numbers row by row
(`new Matrix3(m00, m01, ..., m22)`), with an indexer `M[r, c]`,
`operator *` for matrix-times-matrix and matrix-times-`Tuple2`,
`Transpose()`, `Determinant()` (cofactor expansion along the first row),
`IsInvertible()`, `Inverse()` (cofactors, transposed, over the
determinant - the transpose happens by writing into `[c, r]` instead of
`[r, c]`), and the four transform builders `Translation`, `Scaling`,
`Rotation` (radians; turns x toward y, which is clockwise on a canvas)
and `Shearing`. `ApproxScale()` is the square root of the absolute value
of the determinant of the upper-left 2-by-2 - the book's chosen
compromise for "how much does this stretch lengths", exact for uniform
scales and rotations, the geometric mean of the axis scales otherwise.

`Shapes.cs` grows four cases. `Segment(a, b, width)` is chapter 3's
`ThickLine` with real `Tuple2` endpoints instead of pixel indices -
`ThickLine` is now a one-line wrapper around it, `segment(point(x0 +
0.5, y0 + 0.5), point(x1 + 0.5, y1 + 0.5), width)`, and every chapter 3
scenario still passes unchanged. `Union(shapes)` is inside when any of
its shapes is. `Transformed(shape, m)` stores `inverse(m)` (or nothing,
if `m` isn't invertible, in which case nothing is ever inside) and asks
the original shape about the inverse-transformed point. `Outline.Build
(points, m, width)` takes the points through `m` and returns the union
of the segments between consecutive points, last back to first, as one
shape - so a shared corner is painted once, at the union's coverage,
not twice at the sum of two edges' coverages.

`Renders.cs` adds `FanPoints`, `FanTransformed`, `FanBothOrders`,
`LetterF`, `FBothOrders` and `Plate04`, plus two small private helpers,
`SideBySide` (copies two canvases into the left and right halves of a
wider one) and `CopyCanvas` (a plain pixel-by-pixel copy, since C#
canvases don't clone themselves).

`out/fan-both-orders.ppm` and `out/plate-04.ppm` both match
`reference/chapter-04/*.ppm` **byte for byte** (`max_channel_difference`
of 0 on both).

## Chapter 3

`Lines.cs` adds `line_bresenham` and `line_wu` (plus the `plot`,
`lit_pixels` and `total_ink` test helpers). `Shapes.cs` grows one case,
`ThickLine`, built from four `HalfPlane`s exactly the way chapter 2's
`Circle` and `Rectangle` are — no new rasterizer needed. A zero-length
`ThickLine` has no direction to be flush against, so its caps push out
by half the width too, same as its sides, making a width-by-width
square. `Renders.cs` adds `ray_ends`, `fan_bresenham`, `fan_wu`,
`fan_coverage` and `plate_03`.

(Chapter 4 refactors `ThickLine` into a one-liner over the new
`Segment`, but the four-half-planes construction and the zero-length
square are unchanged — see "Chapter 4" above.)

`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm` and
`out/plate-03.ppm` all match `reference/chapter-03/*.ppm` byte for byte.

## Catch-up (chapters 1-4)

Four scenarios existed in `features/` but weren't yet translated:
"Invertibility is an exact test against zero" (chapter04-matrices),
"side_by_side puts the first canvas on the left" (chapter04-plate, which
also meant making `Renders.SideBySide` public),
"magnitude and dot look at x and y only" (chapter04-tuples), and "A
union of nothing is inside nowhere" (chapter04-shapes). All four now
pass; none exposed a bug in the existing code, since the implementations
they check were already correct as a side effect of the general logic.

## Notes for chapter 1 and 2 readers

`Mix.Blend(a, b, t)` takes an optional fourth argument that overrides the
global linear-blending switch for that one call only, without changing
the switch itself. `Paint.PaintThrough` always blends in light,
regardless of the switch — coverage isn't a browser color. Reading a
`CoverageBuffer` outside its bounds returns 0, the same way writing
outside it is ignored.
