# The 2D Renderer Challenge — TypeScript / Deno

Chapters 1 through 4, one test file per feature file. Run both from this directory.

```sh
deno test --allow-read            # every scenario in features/
deno run --allow-write --allow-read src/render.ts   # writes the pictures to out/
```

`src/` holds the renderer; `tests/` holds one file per `features/*.feature`;
`out/` gets chapter 1's pictures as P3 text and chapters 2, 3 and 4's as binary P6.

| file | what's in it |
| --- | --- |
| `src/color.ts` | a color is three floats of light |
| `src/srgb.ts` | encode / decode between light and file values |
| `src/mix.ts` | interpolation, and the one global linear-blending switch |
| `src/canvas.ts` | the pixel grid, `write_pixel`, `magnify`, `clone`, `side_by_side` |
| `src/ppm.ts` | P3 text out, P6 bytes out, and reading either back |
| `src/tuple.ts` | chapter 4: `point`, `vector`, `add`/`sub`, `magnitude`, `normalize`, `dot`, `cross` |
| `src/matrix.ts` | chapter 4: `matrix3`, multiply, `transpose`, `determinant`, `inverse`, `translation`/`scaling`/`rotation`/`shearing`, `approx_scale` |
| `src/shape.ts` | `inside`: circle, rectangle, half-plane, `intersection`, `thick_line`, and chapter 4's `segment`, `union`, `transformed`, `outline` |
| `src/coverage.ts` | the coverage buffer, 8×8 supersampling, `paint_through` |
| `src/line.ts` | chapter 3: `line_bresenham`, `plot`, `line_wu` |
| `src/scenes.ts` | every picture the book asks for |
| `src/assert.ts` | test-only helpers: comparisons, `lit_pixels`, `total_ink`, and chapter 4's `assert_tuple`/`assert_matrix` |

207 scenarios pass: 98 from chapters 1–2, 37 from chapter 3, 72 from chapter 4
(11 tuples, 17 matrices, 16 transforms, 6 `approx_scale`, 13 segment/union/
transformed/outline, 9 plate 4). `out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
`out/fan-coverage.ppm`, `out/plate-03.ppm`, `out/fan-both-orders.ppm` and
`out/plate-04.ppm` all come out byte-identical to `reference/chapter-0{3,4}/`.

Chapter 3's `thick_line(x0, y0, x1, y1, width)` is now a one-line call into
chapter 4's `segment(point(x0+0.5, y0+0.5), point(x1+0.5, y1+0.5), width)`,
as the chapter asks; every chapter 3 scenario still passes unchanged.

See `FEEDBACK.md` for notes on the chapter.
