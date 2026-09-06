# The 2D Renderer Challenge — C# / .NET 8

Chapters 1 through 4, implemented against a hand-rolled test runner (no
NuGet, no network; the SDK is enough).

## Build, test, render

```
export PATH="/opt/homebrew/Cellar/dotnet@8/8.0.127/libexec:$PATH"
dotnet run
```

That one command builds the project, runs every scenario from
`features/*.feature` (all four chapters), prints a pass/fail summary per
feature, and writes all renders to `out/` (P3 for chapter 1, P6 from
chapter 2 on). Everything - build, 206 scenarios, all thirteen renders -
finishes in well under ten seconds.

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

## Notes for chapter 1 and 2 readers

`Mix.Blend(a, b, t)` takes an optional fourth argument that overrides the
global linear-blending switch for that one call only, without changing
the switch itself. `Paint.PaintThrough` always blends in light,
regardless of the switch — coverage isn't a browser color. Reading a
`CoverageBuffer` outside its bounds returns 0, the same way writing
outside it is ignored.
