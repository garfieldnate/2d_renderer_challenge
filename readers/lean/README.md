# The 2D Renderer Challenge — Lean 4

Chapter 1: colors, canvas, sRGB transfer functions, PPM output, mixing.
Chapter 2: shapes, binary P6, magnify, the coverage buffer, supersampling,
painting through coverage.
Chapter 3: Bresenham's line, Wu's line, a line as a thin rectangle rasterized
through chapter 2's coverage buffer.

Lean 4.29.1, pinned by `lean-toolchain`. Core Lean only — no external packages.
Run everything **from this directory** so `reference/...` and `out/...` resolve.

```sh
lake build              # build the library and both executables
lake exe tests          # 134 scenarios (62 ch1, 35 ch2, 37 ch3); non-zero exit on failure
lake exe render         # write out/*.ppm
```

`lake exe render` writes `out/{gray-match,quarter-match,ramp,clamp-pair,plate-01}.ppm`
(chapter 1, P3), `out/{disc-centers,disc-coverage,painted-twice,plate-02}.ppm`
(chapter 2, P6), and `out/{fan-bresenham,fan-wu,fan-coverage,plate-03}.ppm`
(chapter 3, P6). All thirteen come out byte-identical to `reference/`.
`fan_coverage` is the slow one — see below.

## Layout

| file | what |
| --- | --- |
| `Renderer.lean` | the whole library, in chapter and section order |
| `Tests.lean` | `lake exe tests` — runs all three chapters and prints per-chapter counts |
| `Suite/Harness.lean` | the check helpers (`eqF`, `eqC`, `eqTri`, `eqByte`, `eqPixels`, …) |
| `Suite/Chapter01.lean`, `Suite/Chapter02.lean`, `Suite/Chapter03.lean` | one named check per Gherkin scenario |
| `Render.lean` | `lake exe render` |
| `features/` | the book's Gherkin scenarios (the specification) |
| `reference/chapter-0N/` | the book's reference images, read by some scenarios |

## Notes for the next chapter

- Names follow the book, camelCased: `writePixel`, `canvasToPpm`, `canvasToP6`,
  `halfPlane`, `centerInside`, `rasterizeCenters`, `paintThrough`, `plate02`,
  `lineBresenham`, `lineWu`, `thickLine`, `litPixels`, `totalInk`, `plate03`.
- `Canvas` and `Coverage` are **values**: `writePixel`/`setCoverage` return a new
  one. Write `let mut c := canvas w h` and `c := writePixel c x y col` inside
  `Id.run do`; `Array.set!` updates in place while the array is uniquely
  referenced, so this costs what the book's pseudo-code costs. `lineBresenham`
  and `lineWu` are the same pattern: a `let mut c := c0` threaded through a
  `for` loop (an `Id.run do` for Bresenham, an honest `IO Canvas` do-block for
  Wu, since `plot` calls `mix`). It reads exactly like the pseudo-code, one
  `c :=`/`c ←` per write.
- A `Shape` is a one-field structure holding `Float → Float → Bool`. New shapes
  need no new type: `⟨fun x y => ...⟩`. `thickLine` builds one from four
  `halfPlane`s combined with `&&`, same as the book's pseudo-code, no new
  machinery.
- `x`, `y` are `Int` in `writePixel`, `pixelAt`, `coverageAt`, `setCoverage`, so
  out-of-range writes drop as the book requires. `Nat` coerces automatically.
  **`Int` does *not* coerce to `Float`** — there's no `Int.toFloat` in core
  Lean. `intToFloat` (sign + `Int.natAbs.toFloat`) fills the gap; every chapter
  3 function that mixes `Int` pixel coordinates with `Float` geometry
  (`lineWu`, `thickLine`) goes through it.
- Floor of a `Float`, as an `Int`, is `(Float.floor x).toInt64.toInt` —
  `Float.floor` first, then convert. `x.toInt64` alone **truncates toward
  zero**, which only differs from floor when `x` is negative and non-integral;
  chapter 3's "starts above the canvas" scenario is the one that notices.
- Colors: `+`, `-`, `c1 * c2` (Hadamard). **Scaling needs an explicit Float**:
  `c * (2.0 : Float)`.
- `mix a b t` reads the global linear-blending switch (an `IO.Ref`), so it is
  `IO Color`. `mix a b t (some true)` passes the switch instead of setting it
  (`paintThrough` uses this to force linear regardless of what the caller set);
  `mixWith linear a b t` is the pure form.
- PPM readers (`ppmPixel`, `distinctValues`, `maxChannelDifference`) take a
  `String` or a `ByteArray` through the `PpmBytes` class, and auto-detect P3 vs
  P6. `readFile` returns `ByteArray`.
- **Do not use `Array.qsort` on image data.** It is quadratic on the long runs
  of equal bytes an image is made of; `distinctValues` counts with a bucket per
  value instead. See FEEDBACK.md.
- **`fan_coverage` took ~25 seconds** on this machine (`lake exe render`,
  compiled with `lake build`'s default settings), the same ballpark the book
  quotes for Python/Ruby, not the "quarter of a second" it quotes for a
  compiled language. `Shape` as a struct wrapping a closure, with `thickLine`
  combining four more closures under `&&`, costs more indirection per `inside`
  call than the book's reference implementation presumably pays; 20 million
  calls times that overhead adds up. Not fixed here — chapter 3 doesn't ask
  for it, and the pixels are correct — but worth knowing before chapter 6
  leans on the same rasterizer harder.
