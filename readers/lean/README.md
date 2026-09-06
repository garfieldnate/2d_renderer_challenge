# The 2D Renderer Challenge — Lean 4

Chapter 1: colors, canvas, sRGB transfer functions, PPM output, mixing.
Chapter 2: shapes, binary P6, magnify, the coverage buffer, supersampling,
painting through coverage.
Chapter 3: Bresenham's line, Wu's line, a line as a thin rectangle rasterized
through chapter 2's coverage buffer.
Chapter 4: points, vectors, 3-by-3 matrices and their inverse, the four
transforms, `approx_scale`, `segment`/`union`/`transformed`/`outline` built on
top of them.
Chapter 5: paths (`move_to`/`line_to`/`close`), the winding number and
crossing count, `filled` under nonzero or even-odd, `rasterize_within`.
Chapter 6: the edge table, spans from crossings, the scanline sweep
(`fill_path_aliased`) as a fast, exact stand-in for chapter 5's
`rasterize_centers`, and `transform_path`.

Lean 4.29.1, pinned by `lean-toolchain`. Core Lean only — no external packages.
Run everything **from this directory** so `reference/...` and `out/...` resolve.

```sh
lake build              # build the library and both executables
lake exe tests          # 280 scenarios (62/35/38/76/32/37 by chapter); non-zero exit on failure
lake exe render         # write out/*.ppm
```

`lake exe render` writes `out/{gray-match,quarter-match,ramp,clamp-pair,plate-01}.ppm`
(chapter 1, P3); `out/{disc-centers,disc-coverage,painted-twice,plate-02}.ppm`
(chapter 2, P6); `out/{fan-bresenham,fan-wu,fan-coverage,plate-03}.ppm`
(chapter 3, P6); `out/{fan-both-orders,plate-04}.ppm` (chapter 4, P6);
`out/{star-centers,star-coverage,plate-05}.ppm` (chapter 5, P6); and
`out/{spiral,plate-06}.ppm` (chapter 6, P6). All twenty come out
byte-identical to `reference/`. `fan_coverage` and the chapter 5 coverage
renders are the slow ones — see below; chapter 6's sweep-based renders are not.

## Layout

| file | what |
| --- | --- |
| `Renderer.lean` | the whole library, mostly in chapter and section order (see the note on chapter 4 below) |
| `Tests.lean` | `lake exe tests` — runs all six chapters and prints per-chapter counts |
| `Suite/Harness.lean` | the check helpers (`eqF`, `eqC`, `eqT`, `eqM`, `eqI`, `eqTri`, `eqByte`, `eqPixels`, `eqSpans`, `eqCrossings`, `eqBounds`, …) |
| `Suite/Chapter01.lean` … `Suite/Chapter06.lean` | one named check per Gherkin scenario, one file per chapter |
| `Render.lean` | `lake exe render` |
| `features/` | the book's Gherkin scenarios (the specification) |
| `reference/chapter-0N/` | the book's reference images, read by some scenarios |

## Notes for the next chapter

- Names follow the book, camelCased: `writePixel`, `canvasToPpm`, `canvasToP6`,
  `halfPlane`, `centerInside`, `rasterizeCenters`, `paintThrough`, `plate02`,
  `lineBresenham`, `lineWu`, `thickLine`, `litPixels`, `totalInk`, `plate03`,
  `point`, `vector`, `magnitude`, `normalize`, `dot`, `cross`, `matrix3`,
  `identity`, `transpose`, `determinant`, `isInvertible`, `inverse`,
  `translation`, `scaling`, `rotation`, `shearing`, `approxScale`, `segment`,
  `union`, `transformed`, `transformPoints`, `outline`, `plate04`, `path`,
  `moveTo`, `lineTo`, `close`, `subpaths`, `edges`, `bounds`, `polygon`,
  `circlePath`, `crossings`, `windingAt`, `insideNonzero`, `insideEvenOdd`,
  `filled`, `rasterizeWithin`, `star`, `plate05`, `edgeTable`, `xAt`,
  `crossingsOnRow`, `spansFromCrossings`, `spans`, `fillSpan`,
  `fillPathAliased`, `maxCoverageDifference`, `transformPath`, `unitStar`,
  `spiral`, `plate06`.
- **Chapter 4's §§4.1–4.5 live up in the chapter 3 section of `Renderer.lean`,
  not after chapter 3's renders.** Chapter 4 redefines chapter 3's `thickLine`
  as a one-liner over `segment`, so `Tuple`, `Matrix3`, the transforms and
  `segment`/`union`/`transformed`/`outline` all have to exist *before*
  `thickLine` can be written in terms of them, and `thickLine` is used by
  chapter 3's own `fanCoverage`. Lean has no forward declarations across
  top-level `def`s in one file, so the block moved up; a comment at both ends
  says where to look. Everything chapter 4 actually *adds* — §4.6, the F, the
  fan as points, the two plates — stays after chapter 3's renders, where you'd
  expect it. If your language doesn't have this problem (most don't need one
  file in strict top-to-bottom order), you won't need this split.
- `Canvas` and `Coverage` are **values**: `writePixel`/`setCoverage` return a new
  one. Write `let mut c := canvas w h` and `c := writePixel c x y col` inside
  `Id.run do`; `Array.set!` updates in place while the array is uniquely
  referenced, so this costs what the book's pseudo-code costs. `lineBresenham`
  and `lineWu` are the same pattern: a `let mut c := c0` threaded through a
  `for` loop (an `Id.run do` for Bresenham, an honest `IO Canvas` do-block for
  Wu, since `plot` calls `mix`). It reads exactly like the pseudo-code, one
  `c :=`/`c ←` per write. `Path` is a value the same way: `moveTo`/`lineTo`/
  `close` all return a new `Path`.
- A `Shape` is a one-field structure holding `Float → Float → Bool`. New shapes
  need no new type: `⟨fun x y => ...⟩`. `thickLine`/`segment` build one from
  four `halfPlane`s combined with `&&`; `union` combines an `Array Shape` with
  `Array.any`; `transformed` wraps one more shape behind the inverse matrix;
  `filled` wraps a path's winding number. No new machinery anywhere.
- `x`, `y` are `Int` in `writePixel`, `pixelAt`, `coverageAt`, `setCoverage`, so
  out-of-range writes drop as the book requires. `Nat` coerces automatically.
  **`Int` does *not* coerce to `Float`** — there's no `Int.toFloat` in core
  Lean. `intToFloat` (sign + `Int.natAbs.toFloat`) fills the gap; every chapter
  3 function that mixes `Int` pixel coordinates with `Float` geometry
  (`lineWu`, `thickLine`) goes through it. `Tuple` (chapter 4 on) is all
  `Float`, so this only bites at the pixel/geometry boundary.
- Floor of a `Float`, as an `Int`, is `(Float.floor x).toInt64.toInt` —
  `Float.floor` first, then convert. `x.toInt64` alone **truncates toward
  zero**, which only differs from floor when `x` is negative and non-integral;
  chapter 3's "starts above the canvas" scenario is the one that notices.
  There's no `Float.ceil` in core Lean either; `ceilInt x := -(floorInt (-x))`
  (chapter 5, for `rasterizeWithin`; chapter 6, for `fillSpan`) gets it from
  `floorInt` for free.
- Colors: `+`, `-`, `c1 * c2` (Hadamard). **Scaling needs an explicit Float**:
  `c * (2.0 : Float)`. Tuples (points and vectors) follow the same pattern:
  `+`, `-`, unary `-`, `t * (s : Float)`, `t / (s : Float)`, all component-wise
  including `w`, which is what keeps a point minus a point a vector (`w = 0`)
  and a point plus a vector a point (`w = 1`) without a special case anywhere.
  `Tuple` equality (`eqT`) compares all three components, so a point and a
  vector with the same `x, y` are never equal.
- `mix a b t` reads the global linear-blending switch (an `IO.Ref`), so it is
  `IO Color`. `mix a b t (some true)` passes the switch instead of setting it
  (`paintThrough` uses this to force linear regardless of what the caller set,
  and so does chapter 3's `plot` — see FEEDBACK.md, this was a chapter 3 bug
  caught by a chapter 3 catch-up scenario, not a chapter 4/5/6 one);
  `mixWith linear a b t` is the pure form.
- `Matrix3` is `{ entries : Array Float }`, nine numbers row-major;
  `m.get r c` is `M[r, c]` (named `get`, **not** `at` — `at` is a reserved
  token in Lean 4's tactic grammar and can't be a plain identifier, even as a
  namespaced field name like `Matrix3.at`). `Mul Matrix3` is matrix product;
  `HMul Matrix3 Tuple Tuple` is a matrix times a tuple. `inverse` is the
  cofactor-matrix-transposed-and-divided-by-the-determinant construction from
  the book, written the same way the book warns you to: `entries.set! (c*3+r)
  (cofactor m r c / d)` — the `[c, r]` on the left is the transpose, and it's
  the easiest line in the file to get backwards without noticing, because
  Lean won't type-error on it either way.
- `Path`/`Subpath` are plain structures (`Array Tuple` + `Bool`, and
  `Array Subpath`). `edges(p)` treats every subpath as closed regardless of
  its flag and gives a one-point subpath zero edges by an explicit `n >= 2`
  guard, not by wrapping `(i+1) % n` and hoping. `windingAt`/`crossings`,
  `edgeTable`/`crossingsOnRow`/`spansFromCrossings` are transliterated
  straight from the book's pseudo-code, half-open comparisons and all — see
  the half-open notes in FEEDBACK.md's mutation section before changing any
  `<`/`<=` in those four functions.
- PPM readers (`ppmPixel`, `distinctValues`, `maxChannelDifference`) take a
  `String` or a `ByteArray` through the `PpmBytes` class, and auto-detect P3 vs
  P6. `readFile` returns `ByteArray`. `maxCoverageDifference` (chapter 6) is
  the same idea for `Coverage` buffers of `Float`, not `Nat`.
- **Do not use `Array.qsort` on image data.** It is quadratic on the long runs
  of equal bytes an image is made of; `distinctValues` counts with a bucket per
  value instead. `edgeTable`, `crossingsOnRow` and the sweep's per-row crossing
  list *do* use `Array.qsort` — they're always small (edges, not pixels), so
  the quadratic worst case never comes up, and the book explicitly allows
  ties to fall in any order.
- **`fan_coverage` took ~25 seconds** on this machine (`lake exe render`,
  compiled with `lake build`'s default settings), the same ballpark the book
  quotes for Python/Ruby, not the "quarter of a second" it quotes for a
  compiled language. `Shape` as a struct wrapping a closure, with `thickLine`
  combining four more closures under `&&`, costs more indirection per `inside`
  call than the book's reference implementation presumably pays; 20 million
  calls times that overhead adds up. Chapter 5's `star_coverage` and `plate05`
  (both ~4s) and chapter 4's `fan_both_orders`/`plate04` (6-9s) pay the same
  tax, worse, since a union of segments costs more per `inside` call than a
  single half-plane. Chapter 6's sweep sidesteps all of it: `spiral` and
  `plate06` render in well under a second, exactly the speedup the chapter
  promises, because the sweep never asks a pixel about an edge that doesn't
  cross its row.
