# The 2D Renderer Challenge — TypeScript / Deno

Chapters 1, 2 and 3, one test file per feature file. Run both from this directory.

```sh
deno test --allow-read            # every scenario in features/
deno run --allow-write --allow-read src/render.ts   # writes the pictures to out/
```

`src/` holds the renderer; `tests/` holds one file per `features/*.feature`;
`out/` gets chapter 1's pictures as P3 text and chapters 2 and 3's as binary P6.

| file | what's in it |
| --- | --- |
| `src/color.ts` | a color is three floats of light |
| `src/srgb.ts` | encode / decode between light and file values |
| `src/mix.ts` | interpolation, and the one global linear-blending switch |
| `src/canvas.ts` | the pixel grid, `write_pixel`, `magnify` |
| `src/ppm.ts` | P3 text out, P6 bytes out, and reading either back |
| `src/shape.ts` | `inside`: circle, rectangle, half-plane, `intersection`, `thick_line` |
| `src/coverage.ts` | the coverage buffer, 8×8 supersampling, `paint_through` |
| `src/line.ts` | chapter 3: `line_bresenham`, `plot`, `line_wu` |
| `src/scenes.ts` | every picture the book asks for |
| `src/assert.ts` | test-only helpers: comparisons, `lit_pixels`, `total_ink` |

119 scenarios pass: 88 from chapters 1–2, 31 from chapter 3
(9 Bresenham, 10 Wu, 7 thin-rectangle, 5 plate). `out/fan-coverage.ppm` and
`out/plate-03.ppm` come out byte-identical to `reference/chapter-03/`.

See `FEEDBACK.md` for notes on the chapter.
