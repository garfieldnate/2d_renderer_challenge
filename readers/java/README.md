# The 2D Renderer Challenge — Java

Chapters 1-17, hand-rolled test runner, no JUnit, no network. Chapter 16's
font file (`reference/chapter-16/roboto.json`) is read with a small
hand-written JSON reader (`Json.java`) -- no library, as the chapter asks.

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
java -cp classes Chapter09Tests
java -cp classes Chapter10Tests
java -cp classes Chapter11Tests
java -cp classes Chapter12Tests
java -cp classes Chapter13Tests
java -cp classes Chapter14Tests
java -cp classes Chapter15Tests
java -cp classes Chapter16Tests
java -cp classes Chapter17Tests
```

Each run prints one `PASS`/`FAIL` line per scenario, a pass/fail total, and
then writes that chapter's renders to `out/` (chapter 1 as P3, chapters 2-17 as
P6): `out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
`out/plate-02.ppm`, `out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
`out/fan-coverage.ppm`, `out/plate-03.ppm`, `out/fan-both-orders.ppm`,
`out/plate-04.ppm`, `out/star-centers.ppm`, `out/star-coverage.ppm`,
`out/plate-05.ppm`, `out/spiral.ppm`, `out/plate-06.ppm`, `out/needles.ppm`,
`out/soft-square.ppm`, `out/star-exact.ppm`, `out/spiral-smooth.ppm`,
`out/plate-07.ppm`, `out/drops.ppm`, `out/flower.ppm`, `out/plate-08.ppm`,
`out/porter-duff.ppm`, `out/plate-09.ppm`, `out/blend-modes.ppm`,
`out/seam.ppm`, `out/three-gradients.ppm`, `out/plate-10.ppm`,
`out/extend-modes.ppm`, `out/two-filters.ppm`, `out/plate-11.ppm`,
`out/three-filters.ppm`, `out/opacity.ppm`, `out/plate-12.ppm`,
`out/clip-demo.ppm`, `out/joins.ppm`, `out/plate-13.ppm`, `out/caps.ppm`,
`out/two-strokes.ppm`, `out/fold.ppm`, `out/offsets.ppm`, `out/plate-14.ppm`,
`out/even-marks.ppm`, `out/dash-strip.ppm`, `out/spiral-dashes.ppm`,
`out/plate-15.ppm`, `out/glyph.ppm`, `out/plate-16.ppm`, `out/composite.ppm`,
`out/sizes.ppm`, `out/flip.ppm`, `out/subpixels.ppm`, `out/smoothing.ppm`,
`out/lcd.ppm`, `out/plate-17.ppm`.

Chapter 15's dashed spiral render is `spiral-dashes.ppm`, not `spiral.ppm` --
it used to share that name with chapter 6's spiral figure, which meant running
the whole suite in order left only chapter 15's file on disk (`out/spiral.ppm`
belonged to chapter 6, `out/spiral-dashes.ppm` to chapter 15, and the two
never collide now).

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

## Chapter 9

Premultiplied pixels: `Pixel` (`r`, `g`, `b`, `a`, each channel already
scaled by alpha), `Pixel.CLEAR`, `Pixel.fromColor(c, a)`, `Pixel.opaque(c)`,
instance methods `pixelColor()` (un-premultiplies, black for a transparent
pixel) and `pixelAlpha()`, and `Pixel.lerpPixel(x, y, t)` -- straight down
the premultiplied channels, which is the whole point: half of opaque red
and half of nothing comes out red at half alpha, not muddy grey.

Compositing: `Compositing.over(src, dst)` and `Compositing.composite(op,
src, dst)`, one of the twelve Porter-Duff operator names (`"clear"`,
`"src"`, `"dst"`, `"src-over"`, `"dst-over"`, `"src-in"`, `"dst-in"`,
`"src-out"`, `"dst-out"`, `"src-atop"`, `"dst-atop"`, `"xor"`), each nothing
but its own choice of the two coefficients `Fa`/`Fb` in a private lookup
table.

Blending: `Blend.blend(mode, src, dst)` is source-over with the overlap
passed through `Blend.blendColor(mode, backdrop, source)` first. The twelve
separable modes are one-line functions of two channels; the four
non-separable ones (`"hue"`, `"saturation"`, `"color"`, `"luminosity"`) go
through the compositing spec's `Lum`/`Sat`/`clipColor`/`setLum`/`setSat`
helpers, private to `Blend`.

Layers: `Layer(w, h)` is a buffer of `Pixel`, starting `CLEAR`.
`Layers.paintShape(layer, cov, color)` paints one shape's coverage into a
layer, the way chapter 2 painted onto a canvas. `Layers.compositeLayers(op,
src, dst)` and `Layers.blendLayers(mode, src, dst)` combine two layers
pixel by pixel; `Layers.flattenLayer(layer, bg)` is `over` against an
opaque background, read off into an ordinary `Canvas`.

`Figures` adds `porterDuffTable()`, `plate09()`, `blendStrip()`, and `seam()`
(the conflation trap: two opaque triangles sharing a diagonal, each
composited src-over the one before, leaking a lighter seam where the
antialiased edges land on the same pixels twice). All four diff 0 against
the reference bytes.

## Chapter 10

Paint is a function of position: `Paint` (`paintAt(x, y)`), with a static
`Paint.solid(c)` factory backed by `Solid`. The stop table: `Stop(offset,
color)` (a record, with a static `Stop.stop(...)` matching the book's
name), and `Stops.sampleStops(stops, t)` (binary search, straight blend in
linear light between the bracketing pair) plus `Stops.extend(t, mode)`
(`"pad"`/`"repeat"`/`"reflect"`).

The three gradients, each a plain data class implementing `Paint` and
constructed directly (`new LinearGradient(p0, p1, stops, extend)`, etc.,
matching the `Circle`/`Segment` convention rather than a static factory):
`LinearGradient.linearT(x, y)`, `RadialGradient.radialT(x, y)` (returns
`Double`, `null` for the book's `none` when no root of the quadratic has a
non-negative radius), and `ConicGradient.conicT(x, y)`. Each class's
`paintAt` samples the stop table through `extend`; a radial gradient's
`paintAt` takes the last stop's color on `none` rather than propagating it,
per §10.3's trap.

`Painter.paintFill(c, cov, paint)` sits next to `paintThrough`: for every
covered pixel it samples `paint.paintAt` at the pixel's center and blends
the result in through the coverage, in linear light. A solid paint makes it
`paintThrough` exactly.

Ordered dithering: `Dither.BAYER4` (the 4x4 matrix), `Dither.ditherThreshold(x,
y)`, `Dither.toByteDithered(light, x, y)`. `Ppm.toByte(light)` is now public
(clamp, encode, scale to 255, round -- the same conversion `canvasToPpm` and
`canvasToP6` always used); `Ppm.canvasToP6Dithered(c)` is `canvasToP6` with
every channel rounded through `toByteDithered` instead.

`Figures` adds `threeGradients()`, `plate10()` (which is `threeGradients()`,
per the chapter's own pseudocode), and `extendStrip()`. All three diff 0
against the reference bytes.

## Chapter 11

Images: `Image` (`width`, `height`, plus a package-private `raw(ix, iy)`) is
a plain grid of premultiplied `Pixel`s, opaque for every image this chapter
builds. `Images.readImage(p6)` is chapter 1's PPM writer run backwards --
parse the P6 header, decode each byte from sRGB to linear light, store an
opaque premultiplied pixel. `Images.image(w, h, pixels)` builds one directly.
`Images.imageTexel(img, ix, iy, extend)` (the three-argument overload
defaults to `"clamp"`) is the pixel at an integer texel, an out-of-range
index folded back in by `"clamp"`/`"repeat"`/`"reflect"`, the same three
modes as a gradient's extend, one dimension up.

Sampling: `Sampling.sampleNearest/sampleBilinear/sampleBicubic(img, sx, sy,
extend)` (each also has a two-argument overload defaulting to `"clamp"`) all
work in texel-centre space -- the source coordinate minus 0.5, per the
chapter's trap -- though `sampleNearest` writes that as a plain `floor(sx)`
because the subtraction and a round-to-nearest cancel out algebraically.
`Sampling.catmull(t)` is the four Catmull-Rom weights `sampleBicubic` uses
over its sixteen texels. `Sampling.sample(img, sx, sy, filter, extend)`
dispatches by the filter's name, the way `Stops.extend` dispatches by mode.
Every blend goes through `Pixel.lerpPixel`, so it's premultiplied throughout.

`ImagePaint` implements chapter 10's `Paint`: `new ImagePaint(img, m, filter,
extend)` walks a device point back through `m`'s inverse to find where in
the image to sample -- the only way every output pixel is filled exactly
once, instead of leaving gaps under magnification or overlaps under
rotation.

Minification: `Images.downsample(img)` is the box average of each 2x2 block,
premultiplied channels alike; `Images.mipChain(img)` halves repeatedly down
to a single pixel; `Images.mipLevelFor(scale)` is `floor(-log2(scale))`
(with a tiny epsilon guarding an exact power of two from floating-point
wobble), clamped to never go below level 0. These are exercised in isolation
by their own scenarios; no render in this chapter minifies an image, so
nothing wires a mip level into `ImagePaint` -- the chapter's own pseudocode
for `image_paint` doesn't either.

`Figures` adds `sprite()` (an 8-by-8 sprite built as a canvas, written to a
PPM with `Ppm.canvasToP6` and read straight back with `Images.readImage`, so
the round trip in the chapter's own words is real), `magnified(img, k,
filter)`, `twoFilters()`, `plate11()` (which is `twoFilters()`), and
`threeFilters()`. All three renders diff 0 against the reference bytes.

## Chapter 12

Clipping: `Clipping.multiplyCoverage(a, b)` is the whole operation, cell by
cell. `Clipping.fullClip(w, h)` is coverage 1 everywhere. `Clipping.clipRect`
and `Clipping.clipPath` are only fills that produce a clip -- `clipPath` is
chapter 7's `Fill.fillPath` under a name that says what the caller means to
do with the result, because there was never a difference between a clip and
a shape.

Soft masks: `Clipping.softMask(cx, cy, r, w, h)` is a radial falloff,
coverage 1 at its centre dropping to 0 at radius `r` (clamped there), and it
multiplies in exactly the way a hard clip does.

Groups: `Groups.pushGroup(w, h)` starts a fresh transparent `Layer`.
`Groups.paintInto(layer, cov, color, alpha)` draws one child through its
coverage at a given opacity and returns a new layer, src-over the one handed
in -- it does not mutate its argument. `Groups.scaleOpacity(layer, opacity)`
lowers every premultiplied channel together, alpha included.
`Groups.popGroupWithOpacity(group, base, opacity)` scales the whole
flattened group by opacity once, then composites it over base -- at opacity
1 this is pixel-identical to drawing the children straight onto base, and
below 1 it differs at every overlap, because the group's overlaps were
already resolved before the opacity applied instead of being composited
twice.

`Figures` adds `perChild()` and `groupOpacity()` (the plate's two halves,
built from `threeCircles()`, three overlapping circles in three inks on a
150 by 150 stage), `opacityPlate()` (the two side by side), `plate12()`
(`opacityPlate()` magnified by 2), and `clipDemo()` (one pentagram -- reusing
`unitStar()` from chapter 6, placed at centre (75, 75) with radius 60 --
shown clipped hard to a circle of radius 45 on the left and multiplied by a
soft mask of radius 70 on the right, both centred on the star). All four
renders diff 0 against the reference bytes. **`clip_demo()`'s exact geometry
is not given anywhere in the chapter** -- unlike every other named render in
chapters 11 and 12, it has no printed pseudocode and no figure JS to copy;
see FEEDBACK.md's Prose problems section for how it was found instead.

## Chapter 13

Stroking is filling: `Stroke.strokeToPath(path, width, cap, join, miterLimit)`
turns a stroked path into a plain, fillable outline -- one rectangle per
segment (`segRect`, the ends offset by half the width along the segment's
perpendicular), one join wedge per interior vertex (`joinShape`: `"bevel"` a
triangle, `"round"` an arc about the vertex, `"miter"` the two outer edges
extended to their intersection, falling back to a bevel past the miter
limit), and one cap shape per open end (`capShape`: `"butt"` nothing,
`"square"` a rectangle a half-width past the end, `"round"` a semicircle),
all as subpaths of one output `Path`. There is no new rasterizer -- the
result is handed straight to chapter 7's `Fill.fillPath(o, "nonzero", w,
h)`, and every generated subpath is closed so `Path.edges()`'s
always-closed convention (from chapter 5) does the right thing with it. The
public `Stroke.miterLength(dIn, dOut, h)` is the closed form, `h / sin(theta
/ 2)` with `theta` the interior turn angle (the angle between the reversed
incoming direction and the outgoing one) -- independent of the stroker's own
geometric construction of the same point, so the two can be (and are)
checked against each other.

The degenerate cases from §13.4: `Stroke` drops consecutive duplicate
points before doing anything else (a doubled vertex never becomes a
zero-length segment to divide by), and a subpath of a single point (after
dedup) isn't rejected -- with a round cap it's a filled dot of radius `h`,
with a square cap a square of the same half-width, with a butt cap nothing
at all. A join whose turn is numerically zero (a straight run, or an exact
180-degree reversal) emits no wedge, since there's no defined "outer side"
either way.

`Figures.chevron()` is the plate's open "V" (`(30, 40)` to `(80, 120)` to
`(130, 40)`). `Figures.joinsPlate()` strokes it three ways (miter, round,
bevel), each panel a gray nonzero fill of the generated outline with the
outline itself traced over it in magenta via chapter 3's `Lines.lineWu`
(rounding the outline's coordinates to integers first, per the chapter's own
instruction). `Figures.plate13()` is `joinsPlate()` magnified by 2.
`Figures.capsDemo()` strokes one horizontal segment three ways (butt, round,
square) the same way. All three renders (`joins.ppm`, `plate-13.ppm`,
`caps.ppm`) diff 0 against the reference bytes.

**Catch-up (chapter 13 revised since this code last ran):** the round join's
arc used to sweep whichever way `atan2` happened to wrap to, which drew the
long way around the vertex on some turns -- a notch at the point of a
chevron. `Stroke.joinShape`'s round case now always takes the *shortest*
signed angle from the first outer offset point to the second
(`angBetween`), which is the outer arc on every turn direction, never the
inner one. Separately, the pieces a stroke assembles (rectangles, join
wedges, caps, dots) didn't all wind the same way, so under nonzero fill a
piece wound one way could cancel a piece wound the other where they
overlapped -- invisible on a single gentle chevron (neighbours happen to
agree there) but a real hole in a wide stroke around a tight bend, where
rectangles from opposite sides of the bend reach across and overlap the
joins. `Stroke` now runs every piece through `emit`, which reverses it if
`Fill.polygonArea` of just that piece comes out positive (clockwise on
screen), so every piece is counterclockwise before it's kept.
`Fill.polygonArea` itself changed from the chapter 7 return value (absolute
value of the shoelace sum) to the signed shoelace sum, because chapter 13's
own scenario now pins its sign (`polygon_area(o) = -4981.625`, not the
absolute value) -- chapter 7's own scenarios only ever compare it against
`ink()`, which is nonnegative, and every polygon chapter 7 pins happens to
wind in the direction that makes the signed and unsigned values equal, so
that change didn't disturb any chapter 7 test. Five stroke.feature scenarios
existed in the feature file but not yet in `Chapter13Tests` (the round
join's true shape, the join's side, the winding-consistency polygon-area
check, the tight U-turn stroke, and the closed-triangle stroke); all five
are translated now, and one square-cap degenerate scenario
(`chapter13-degenerate.feature`'s "half-width past the end") was missing
too and is added. All 21 chapter 13 scenarios are green and `joins.ppm`,
`plate-13.ppm` and `caps.ppm` are re-rendered and diff 0 against
`reference/chapter-13/`.

## Chapter 14

Offsetting curves: `Offset.tangentAt(c, t)` is chapter 8's `derivative`,
normalized, at a `liveT` that's nudged `1e-4` into the curve when the raw
derivative is (numerically) zero -- a handle Illustrator dropped exactly on
its anchor. `Offset.normalAt(c, t)` is that tangent turned a quarter turn
toward `+y` (`vector(-tan.y, tan.x)`), which on this y-down canvas is the
right side of travel, the same side chapter 13's `+h` rectangles used.
`Offset.offsetPoint(c, t, d)` is `point_at(c, t)` plus `d` times that
normal.

`Offset.secondDerivative(c, t)` is one degree further down de Casteljau's
ladder than chapter 8's `derivative` -- constant for a quadratic, a linear
blend of two constants for a cubic. `Offset.curvature(c, t)` is
`cross(v, a) / |v|^3`, `v` and `a` the first and second derivatives at the
same (possibly nudged) `t`; its sign matches chapter 4's `cross`, positive
where the curve turns clockwise on screen, the same side positive `d`
points to. `Offset.cusps(c, d)` finds where `1 - curvature(t) * d` changes
sign: 64 evenly spaced samples, then 40 bisections wherever two neighbours
disagree, tracking the invariant sign through the bisection rather than
re-deriving it from scratch each round (matching the reference
implementation's own bisection exactly, not just its endpoints).

`Offset.fitOffset(c, d)` is the one cubic with the curve's own end tangents
whose midpoint lands on the true offset's midpoint at `t = 0.5` -- a 2x2
cross-product solve for the two handle lengths, `a` and `b`, that falls
back to a third of the chord when the end tangents are parallel (no unique
solve exists then). `Offset.offsetError(c, d, fitted)` is the worst miss
over 17 matched parameters (`t = i / 16`). `Offset.distanceToCurve(c, p)`
is the honest measure: the nearest of 65 samples at `t = i / 64`, then 32
rounds of ternary search between that sample's two neighbours -- the
prose specifies the bracket as the sample's immediate neighbours, not the
whole curve, so the search stays local to the right basin even when the
curve loops back near `p` elsewhere.

`Offset.subCurve(c, t0, t1)` is two splits. `Offset.offsetCurve(c, d,
tolerance)` splits `c` at its cusps, then fits, halves and refits each
piece (`offsetInto`, recursive, capped at 16 halvings) until
`offsetError` is within tolerance. `Offset.offsetDistanceError(c, d,
tolerance)` walks 100 points evenly spread by piece index across the
result and takes the worst `|distance_to_curve(c, point) - |d||`.
`chapter14-curve.feature`'s own description now states the walk exactly:
`u = i / 99` times the number of pieces for `i = 0` to `99`, each point
taken on piece `floor(u)` at parameter `u - floor(u)`, the last point on
the last piece at `t = 1`. `WALK_POINTS = 100` in `Offset` already matched
that parameterization exactly, so no code changed here -- but the feature
now also pins an exact value on the fold case (`offset_distance_error(q,
-2, 0.01) = 0.707336 ± 0.0001`), not only a `>=` bound, so a reader whose
walk used a different `u` (say, `i / 100`, or without clamping the last
point to `t = 1`) would now fail a scenario instead of merely passing a
looser one.

`Offset.strokeCurveToPath(c, width, cap, tolerance)` is one closed subpath:
the `+h` offset's pieces flattened forward, the end cap's points
(`Stroke.capShapePublic`, a small new public wrapper around chapter 13's
private `capShape` so this chapter can reuse it without duplicating the
geometry), the `-h` offset's pieces flattened backward, the start cap's
points, deduplicated (`Stroke.dedupePublic`, the same reuse), with the
last point dropped if it equals the first. `Offset.flattenThenStroke(c,
width, cap, tolerance)` is yesterday's way: flatten, then chapter 13 with
round joins.

`Figures` adds `hairpin()`, `arch()`, `outlinePanel` (a gray nonzero-or-
even-odd fill of an already-built outline with its edges traced in
magenta, factored out of chapter 13's `tracedPanel` so this chapter can
show an outline it didn't build by calling `Stroke.strokeToPath` itself),
`twoStrokes()`, `foldDemo()`, `hairline` (one open polyline stroked
hairline-thin and painted through the canvas), `offsetsPlate()`, and
`plate14()`. All four renders (`two-strokes.ppm`, `fold.ppm`,
`offsets.ppm`, `plate-14.ppm`) diff 0 against the reference bytes.

**Rounding an outline's traced edges.** Tracing an outline's edges in magenta
(`outlinePanel` here, chapter 13's `tracedPanel`) rounds each endpoint to an
integer pixel first with `Numbers.round` -- round to nearest, halves up
(`floor(v + 0.5)`), chapter 1's rule, per chapter 13 §13.5's and chapter 14
§14.5's pseudocode comments. Chapter 14's hairpin is left-right symmetric, so
its flattened outline has two vertices sitting exactly on a half-integer
coordinate at the fold's tip (`(80, 42.5)` and `(80, -17.5)`, pinned in
`chapter14-stroke.feature`); halves-up rounds those to `43` and `-17`. An
earlier revision of this code used round-half-to-even there instead (to match
a since-fixed quirk in the reference implementation's rounding), which rounds
`42.5` to `42` and `-17.5` to `-18` -- both a row off from what the book's
own halves-up rule, and the current reference, actually draw. `Numbers` now
has only `round` (halves up); the half-to-even helper is gone.

## Chapter 15

Dashes: `Length.pathLength(p)` sums every subpath's segments, closing
subpaths included. `Length.arcLengthTable(c, n)` is `n + 1` running chord
lengths through `point_at(c, i / n)`; `Length.arcLength(c, n)` is its last
entry. `Length.tAtLength(table, s)` binary-searches the table for the
chord that spans `s` and interpolates linearly inside it -- `0` before the
start, `1` past the end. `Length.pointAtLength` and `Length.splitAtLength`
hand that parameter to chapter 8's `point_at` and `split_at`.

`Dash.normalizePattern(pattern)` doubles an odd-length pattern (so the
second cycle's on/off parity matches the first's), and returns empty for a
pattern with a negative entry or a nonpositive sum -- both of which `dash`
treats as "draw solid" by returning an unmodified copy of the path.
`Dash.dash(path, pattern, phase)` walks every subpath by arc length from a
phase-adjusted start (`phase` taken modulo the pattern's sum, wrapped
positive), stepping the smaller of what's left in the current pattern
entry and what's left in the current segment, straight through vertices
without resetting the pattern -- a dash spanning a corner keeps going, and
zero-length segments are skipped so they can never stall the walk on a
zero step. A zero-length pattern entry is legal and becomes a one-point
subpath (a dot under chapter 13's round cap, nothing under butt). For a
closed subpath, the walk continues around the closing segment back to the
start; if the walk is still "on" both when it left the start and when it
returns, the last dash absorbs the first (or, if one dash covered the
whole loop, that single subpath is marked closed instead of duplicating
its start point).

`Figures` adds `lopsided()` (a cubic with one short handle and one long one,
control points `(15, 100)`, `(25, 85)`, `(100, 5)`, `(185, 95)`, so its
parameter and its arc length disagree), `evenMarks()`, `wave(dy)`,
`dashStrip()`, `goldenSpiral()` (seven quarter circles, each `phi` times the
radius of the last and tangent to it, flattened into one open subpath), and
`spiralDashes()` (the spiral stroked hairline-thin, then dashed 16-on/
10-off and each resulting dash stroked separately, 7 wide with round
caps, in the next of three inks -- painted one dash at a time in sequence,
matching the reference implementation's own per-dash paint calls rather
than filling all the dashes together in one pass, which matters at the
antialiased edges where two dashes' outlines come close). `Figures.plate15()`
is `spiralDashes()` magnified by 2. All four renders (`even-marks.ppm`,
`dash-strip.ppm`, `spiral-dashes.ppm`, `plate-15.ppm`) diff 0 or 1 against
the reference bytes (`spiral-dashes.ppm` and `plate-15.ppm` differ by 1 in a
handful of pixels, within the `<= 1` budget every plate scenario allows).

**Catch-up: `lopsided()`'s control points changed upstream.** The chapter's
own `lopsided()` moved its second control point from `(20, 20)` to
`(25, 85)` and its third from `(150, 15)` to `(100, 5)` -- the middle handle
now leans much closer to the start, so the parameter-vs-length mismatch the
figure exists to show is more pronounced (`arc_length` went from `225.8293`
to `198.0971`, and the parameter/length midpoints separated further). This
reader's code had the old control points hardcoded (there's no way to derive
them from the chapter's prose alone; they only show up in the figure's own
JS in chapter-15.html §15.1), so `chapter15-length.feature`'s and
`chapter15-plate.feature`'s pinned values for `even_marks()`,
`point_at(lopsided(), 0.5)`, `point_at_length`, and `t_at_length` all had to
be re-copied from the new figure source, not derived.

**Catch-up (chapter 13 revised again since the last round): a closed
subpath that ends where it began.** A path that explicitly draws back to
its own start point with a final `line_to` and then calls `close` (rather
than relying on `close` alone to draw the last edge) used to grow a
zero-length closing segment on top of the real one -- `Stroke.strokeToPath`
built a segment rectangle from a point to itself, dividing by zero in
`unit_dir`. `Stroke.strokeToPath` now drops a closed subpath's last point
first when it sits within the dedupe epsilon of the first, exactly the same
epsilon the existing duplicate-point rule already used. One new scenario in
`chapter13-degenerate.feature` (a stroked 10x10 square drawn with an
explicit closing `line_to`) pins `length(subpaths(o)) = 8` and
`polygon_area(o) = -84`; it failed before the fix (dividing by zero produced
`NaN` points and burst the subpath count and `polygon_area`) and is green
now. All 22 chapter 13 scenarios pass and chapters 1-15's own suites are
unaffected.

## Chapter 16

A font is JSON: `Json.java` is a small hand-written recursive-descent
parser (objects, arrays, strings, numbers, booleans, null) -- exactly the
subset chapter 16 asks for, no library. `Font` (`unitsPerEm`, `ascender`,
`descender`, `lineGap`, `cmap`, `glyphs`), `Glyph` (`advance`, `contours`,
`components`), `Component` (`glyph`, `transform`) and `ContourPoint` (`x`,
`y`, `on`) are plain data classes; `Fonts.loadFont(text)` builds a `Font`
from the parsed tree, `Fonts.glyphName`/`glyphAdvance`/`glyphCount` read
what they say (`glyphName` answers `.notdef` for a codepoint the font
lacks).

`Contours.impliedPoints(contour)` walks a loop of `ContourPoint`s, inserting
an on-curve midpoint between any two consecutive off-curve points (the loop
wraps, so the last and first count as a pair too), then rotates the result
to start on an on-curve point. `Contours.contourCurves(contour)` calls that
internally and turns the expanded loop into chapter 8 `Curve`s: from each
on-curve point, either straight through the next on-curve point (a
quadratic with its control point at the edge's own midpoint) or through the
off-curve point between them.

`Glyphs.componentMatrix(t)` builds the `matrix3` for a component's six-number
transform `[a, b, c, d, dx, dy]` (TrueType's own letters-in-a-slightly-
surprising-order convention, `x' = a·x + c·y + dx`, `y' = b·x + d·y + dy`).
`Glyphs.glyphOutline(font, name)` is every contour as quadratics, in font
units, y up -- a glyph's own contours through `contourCurves`, then every
component's own outline (recursively) taken through its matrix.
`Glyphs.glyphBounds(font, name)` unions chapter 8's `curveBounds` over every
quadratic, `(0, 0, 0, 0)` for an empty glyph (no contours, no components,
e.g. `space`).

`Glyphs.textMatrix(font, size, x, y)` is the one place the font's y-up,
baseline-origin coordinates turn into the canvas's y-down, corner-origin
ones -- `translation(x, y) * scaling(s, -s)`, `s = size / units_per_em` --
and it is the *only* place: nothing else in `Glyphs`, `Contours`, or
`Fonts` ever negates a y. `Glyphs.glyphPath`/`contourPath` take every
quadratic of the outline through a matrix, flatten in device space (after
the transform, never before, per chapter 8's own rule), and close each
contour into its own subpath -- built directly on chapter 8's
`Curves.transformCurve`/`flatten` and chapter 5's `Path`, with no
deduplication of the point that repeats at each curve boundary within a
contour (harmless: a zero-length edge contributes nothing to `Fill`'s
accumulator or to `Winding`, so it doesn't perturb any pinned area or
coverage value).

`Figures` adds `glyphPlate()`, `plate16()`, `compositeDemo()`, `sizes()`,
and `flipTrap()`, matching the chapter's own printed pseudocode for
`glyph_plate()`/`plate_16()` exactly. `composite_demo()`, `sizes()` and
`flip_trap()` have no printed pseudocode in the chapter text, but
`chapter16-plate.feature`'s own `Feature:` description now states their
exact geometry in prose (canvas sizes, `text_matrix`/origin/size for each
glyph, which component goes in which ink, the hairline bounding box, the
baseline positions) -- so their implementation is pinned by the feature
file's words, not just by the chapter's figure JS. All five renders
(`glyph.ppm`, `plate-16.ppm`, `composite.ppm`, `sizes.ppm`, `flip.ppm`) diff
0 against the reference bytes.

## Chapter 17

`Subpixel` (`whole`, `quarter`) and `Bitmaps.subpixelOf(x)` split a
fractional pen position into a whole pixel and the nearest quarter,
carrying into the next whole pixel when the fraction rounds all the way up.
`Bitmap` (`coverage`, `width`, `height`, `left`, `top`) is a `CoverageBuffer`
of its own plus the two integers saying where its corner sits relative to
the pen. `Bitmaps.glyphBitmap(font, name, size, subpixel)` takes chapter
16's `glyphBounds`, scales and shifts them by the quarter, rounds outward
(`floor`/`ceil`), and fills the path into a buffer exactly that size through
a `textMatrix` whose origin is the quarter offset by the buffer's own
corner; an empty glyph (`space`) is a zero-by-zero bitmap.
`Bitmaps.paintBitmap(canvas, bitmap, x, y, color, linear)` mixes every
covered pixel toward the color by its coverage, `linear` picking chapter
1's blending lane directly (not the global switch -- an explicit parameter,
per the feature's own wording).

`GlyphCache` is a `Map` keyed by `(name, size, subpixel)`;
`cachedBitmap`/`size()` are one line each. `Atlas` packs `Bitmap`s into one
big `CoverageBuffer`, shelf by shelf, following `chapter-17.html` §17.2's
printed pseudocode for `atlas_add` exactly: a bitmap wider or taller than
the whole atlas is rejected immediately; otherwise, if it doesn't fit to
the right of the current shelf, a new shelf opens at `shelfY + shelfHeight`
(unconditionally -- that shift happens even if the bitmap then turns out
not to fit vertically either, so the *next* item's shelf still opens at
that same y, which is what the packing scenario's 30x20 rectangle relies
on); a bitmap that fits width-wise stays on the current shelf even if it is
taller than everything placed there so far -- the shelf just grows
(`shelfHeight = max(shelfHeight, bm.height)`), it is not bumped to a new
shelf. `AtlasSpot` (`x`, `y`) or `null` (the book's "none") is what `add`
answers.

`Bitmaps.embolden(font, name, size, amount)` is the glyph's own fill plus
chapter 13's stroke of every one of its (already-closed) subpaths, `amount`
wide, `"butt"`/`"round"`, added and clamped to 1, in a bitmap grown a pixel
all round (`floor(...) - 1` / `ceil(...) + 1`) to make room for the grown
ink.

`Lcd.LCD_TAPS` is `(1/3, 1/3, 1/3)`; `Lcd.lcdFilter(v)` replaces every value
with the average of itself and its two neighbours, zero beyond the ends.
`Lcd.lcdCoverage(font, name, size, x, y, w, h)` rasterizes the glyph through
`scaling(3, 1) * textMatrix(...)` into a buffer `3w` wide, filtering every
row. `Lcd.paintLcd(canvas, cov3, color)` mixes each of a pixel's three
channels through its own stripe's coverage, always in linear light (the
book doesn't give `paint_lcd` a `linear` flag the way `paint_bitmap` has
one).

`Glyphs.penAdvance(font, name, size)` is `glyph.advance * size /
units_per_em`. `Figures.drawText(canvas, font, text, size, x, y, color,
linear)` is public: it steps the pen by `penAdvance`, places each glyph at
its own nearest quarter via `subpixelOf`, and answers the pen's final
position, per `chapter17-plate.feature`'s scenario that now calls it
directly and pins both that return value and two of its painted pixels.
`Figures` also adds `subpixelStrip()`, `smoothingDemo()` (which calls
`drawText` for its top two rows), `lcdPlate()`, and `plate17()`, built from
the chapter's own figure JS (`chapter-17.html`'s
`subpixelStrip`/`smoothingDemo`/`lcdPlate` functions -- `§17.5`'s printed
pseudocode covers `lcd_plate()`/`plate_17()` only). All four renders
(`subpixels.ppm`, `smoothing.ppm`, `lcd.ppm`, `plate-17.ppm`) diff 0 against
the reference bytes.

**Catch-up: two new atlas scenarios in `chapter17-cache.feature`, both
already true of `Atlas`.** "A taller bitmap that fits the width stays on
the shelf and raises it" and "A bitmap the atlas can never hold leaves the
shelf alone" are now pinned. `Atlas.add`'s existing logic already handles
both: a bitmap too wide for the whole atlas returns `null` before touching
`shelfY`/`currentX`/`shelfHeight` at all, so a rejected too-wide bitmap
never disturbs the current shelf, and `shelfHeight = max(shelfHeight,
bm.height)` already lets a taller-but-narrow-enough bitmap grow the shelf
in place rather than bump to a new one. Only `Chapter17Tests.java` changed
-- two scenarios translated, both green on the first run, no bug found.
Separately, `chapter16-composites.feature` renamed two scenarios (the
tight-bounds claim now belongs to the hand-written bump scenario, and the
`o`/`H` bounds check is now "Two more real glyphs' bounds"); the test
names in `Chapter16Tests.java` are updated to match, with no change to
their bodies. All 23 chapter 16 scenarios and all 22 chapter 17 scenarios
are green, and every chapter 16/17 render still diffs 0 against
`reference/`.
