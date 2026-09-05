# The 2D Renderer Challenge — Lean 4

Chapter 1: colors, canvas, sRGB transfer functions, PPM output, mixing.
Chapter 2: shapes, binary P6, magnify, the coverage buffer, supersampling,
painting through coverage.

Lean 4.29.1, pinned by `lean-toolchain`. Core Lean only — no external packages.
Run everything **from this directory** so `reference/...` and `out/...` resolve.

```sh
lake build              # build the library and both executables
lake exe tests          # 90 scenarios (62 chapter 1, 28 chapter 2); non-zero exit on failure
lake exe render         # write out/*.ppm — chapter 1's five as P3, chapter 2's four as P6
```

`lake exe render` writes `out/{gray-match,quarter-match,ramp,clamp-pair,plate-01}.ppm`
and `out/{disc-centers,disc-coverage,painted-twice,plate-02}.ppm`. The four
chapter-2 files come out byte-identical to `reference/chapter-02/`.

## Layout

| file | what |
| --- | --- |
| `Renderer.lean` | the whole library, in chapter and section order |
| `Tests.lean` | `lake exe tests` — runs both chapters and prints per-chapter counts |
| `Suite/Harness.lean` | the check helpers (`eqF`, `eqC`, `eqTri`, `eqByte`, …) |
| `Suite/Chapter01.lean`, `Suite/Chapter02.lean` | one named check per Gherkin scenario |
| `Render.lean` | `lake exe render` |
| `features/` | the book's Gherkin scenarios (the specification) |
| `reference/chapter-0N/` | the book's reference images, read by some scenarios |

## Notes for the next chapter

- Names follow the book, camelCased: `writePixel`, `canvasToPpm`, `canvasToP6`,
  `halfPlane`, `centerInside`, `rasterizeCenters`, `paintThrough`, `plate02`.
- `Canvas` and `Coverage` are **values**: `writePixel`/`setCoverage` return a new
  one. Write `let mut c := canvas w h` and `c := writePixel c x y col` inside
  `Id.run do`; `Array.set!` updates in place while the array is uniquely
  referenced, so this costs what the book's pseudo-code costs.
- A `Shape` is a one-field structure holding `Float → Float → Bool`. New shapes
  need no new type: `⟨fun x y => ...⟩`.
- `x`, `y` are `Int` in `writePixel`, `pixelAt`, `coverageAt`, `setCoverage`, so
  out-of-range writes drop as the book requires. `Nat` coerces automatically.
- Colors: `+`, `-`, `c1 * c2` (Hadamard). **Scaling needs an explicit Float**:
  `c * (2.0 : Float)`.
- `mix a b t` reads the global linear-blending switch (an `IO.Ref`), so it is
  `IO Color`. `mix a b t true` passes the switch instead of setting it;
  `mixWith linear a b t` is the pure form.
- PPM readers (`ppmPixel`, `distinctValues`, `maxChannelDifference`) take a
  `String` or a `ByteArray` through the `PpmBytes` class, and auto-detect P3 vs
  P6. `readFile` returns `ByteArray`.
- **Do not use `Array.qsort` on image data.** It is quadratic on the long runs
  of equal bytes an image is made of; `distinctValues` counts with a bucket per
  value instead. See FEEDBACK.md.
