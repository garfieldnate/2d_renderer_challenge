# The 2D Renderer Challenge — C# / .NET 8

Chapters 1, 2 and 3, implemented against a hand-rolled test runner (no
NuGet, no network; the SDK is enough).

## Build, test, render

```
export PATH="/opt/homebrew/Cellar/dotnet@8/8.0.127/libexec:$PATH"
dotnet run
```

That one command builds the project, runs every scenario from
`features/*.feature` (all three chapters), prints a pass/fail summary per
feature, and writes all renders to `out/` (P3 for chapter 1, P6 for
chapters 2 and 3).

## Chapter 3

`Lines.cs` adds `line_bresenham` and `line_wu` (plus the `plot`,
`lit_pixels` and `total_ink` test helpers). `Shapes.cs` grows one case,
`ThickLine`, built from four `HalfPlane`s exactly the way chapter 2's
`Circle` and `Rectangle` are — no new rasterizer needed. A zero-length
`ThickLine` has no direction to be flush against, so its caps push out
by half the width too, same as its sides, making a width-by-width
square. `Renders.cs` adds `ray_ends`, `fan_bresenham`, `fan_wu`,
`fan_coverage` and `plate_03`.

`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm` and
`out/plate-03.ppm` all match `reference/chapter-03/*.ppm` byte for byte.

## Notes for chapter 1 and 2 readers

`Mix.Blend(a, b, t)` takes an optional fourth argument that overrides the
global linear-blending switch for that one call only, without changing
the switch itself. `Paint.PaintThrough` always blends in light,
regardless of the switch — coverage isn't a browser color. Reading a
`CoverageBuffer` outside its bounds returns 0, the same way writing
outside it is ignored.
