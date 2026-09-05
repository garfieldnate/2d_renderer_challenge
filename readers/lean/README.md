# The 2D Renderer Challenge — Lean 4

Chapter 1: colors, canvas, sRGB transfer functions, PPM output, mixing.

Lean 4.29.1, pinned by `lean-toolchain`. Core Lean only — no external packages.
Run everything **from this directory** so `reference/...` and `out/...` resolve.

```sh
lake build              # build the library and both executables
lake exe tests          # run all 60 chapter-1 scenarios; exits non-zero on failure
lake exe render         # write out/{gray-match,quarter-match,ramp,clamp-pair,plate-01}.ppm
```

## Layout

| file | what |
| --- | --- |
| `Renderer.lean` | the whole library: `Color`, `Canvas`, `encode`/`decode`, `canvasToPpm`, `mix`, the five renders |
| `Tests.lean` | `lake exe tests` — one named check per Gherkin scenario |
| `Render.lean` | `lake exe render` — writes the five pictures into `out/` |
| `features/` | the book's Gherkin scenarios (the specification) |
| `reference/chapter-01/` | the book's reference PPMs, read by some scenarios |

## Notes for the next chapter

- Names follow the book, camelCased: `writePixel`, `pixelAt`, `canvasToPpm`,
  `ppmPixel`, `distinctValues`, `maxChannelDifference`, `grayMatch`, `plate01`.
- A `Canvas` is a value, not a mutable object. `writePixel c x y col` **returns**
  a new canvas; write `let mut c := canvas w h` and `c := writePixel c x y col`
  inside `Id.run do`. `Array.set!` mutates in place when the array is uniquely
  referenced, so this costs the same as the book's pseudo-code.
- `x` and `y` are `Int`, so out-of-bounds writes (including negatives) can be
  dropped as the book requires. `Nat` arguments coerce automatically.
- Colors: `+`, `-`, and `c1 * c2` (Hadamard) work. **Scaling needs an explicit
  Float**: `c * (2.0 : Float)`, not `c * 2` — see FEEDBACK.md. `Color.scale` is
  the plain-function form.
- The global linear-blending switch is an `IO.Ref` created by `initialize`, so
  `mix : Color → Color → Float → IO Color`. `mixWith (linear : Bool) a b t` is
  the pure version if you would rather thread the flag. `Tests.lean` resets the
  switch to on before every scenario.
- To add chapter 2: put new code in `Renderer.lean` (or a new module imported by
  it) and append scenarios to `Tests.lean` with the same `r.run "name" do ...`
  shape.
