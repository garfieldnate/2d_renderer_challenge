# The 2D Renderer Challenge — TypeScript / Deno

Chapters 1 through 6, one test file per feature file. Run both from this directory.

```sh
deno test --allow-read --allow-write   # every scenario in features/
deno run --allow-write --allow-read src/render.ts   # writes the pictures to out/
```

`src/` holds the renderer; `tests/` holds one file per `features/*.feature`;
`out/` gets chapter 1's pictures as P3 text and chapters 2 through 6's as binary P6.

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
| `src/path.ts` | chapter 5: `path`/`move_to`/`line_to`/`close`, `subpaths`, `edges`, `bounds`, `polygon`, `circle_path`, `crossings`, `winding_at`, `inside_nonzero`/`inside_evenodd`, `filled`, `rasterize_within` |
| `src/sweep.ts` | chapter 6: `edge_table`, `x_at`, `crossings_on_row`, `spans_from_crossings`, `spans`, `fill_span`, `fill_path_aliased`, `max_coverage_difference`, `transform_path` |
| `src/scenes.ts` | every picture the book asks for |
| `src/assert.ts` | test-only helpers: comparisons, `lit_pixels`, `total_ink`, chapter 4's `assert_tuple`/`assert_matrix`, and chapter 5's `assert_bounds` |

281 scenarios pass: 212 from chapters 1–4 (up from 207, after catch-up added
one apiece to chapter 3's wu and chapter 4's matrices, tuples, drawing and
plate — see below), 32 from chapter 5 (10 paths, 9 winding, 9 rules, 4 plate
5), 37 from chapter 6 (6 edges, 16 spans, 12 sweep, 3 plate 6).
`out/star-centers.ppm`, `out/star-coverage.ppm`, `out/plate-05.ppm`,
`out/spiral.ppm` and `out/plate-06.ppm` all come out byte-identical to
`reference/chapter-0{5,6}/`, same as the chapter 3/4 renders.

Chapter 6's `fill_path_aliased` is checked pixel for pixel against chapter 5's
`rasterize_centers(filled(p, rule), w, h)` on every shape the tests use,
including the star under both rules — that's the chapter's whole argument,
and the scenarios hold it to zero difference, not a tolerance.

Before this round, five scenarios existed in `features/` but were never
translated into tests: "Invertibility is an exact test against zero"
(matrices), "magnitude and dot look at x and y only" (tuples), "side_by_side
puts the first canvas on the left" (chapter 4 plate), "A union of nothing is
inside nowhere" (drawing), and "The weights are applied in light, whatever
the switch says" (Wu). Adding the last one failed against the existing code:
`plot` in `src/line.ts` was mixing with the global linear-blending switch
instead of forcing `linear=true` as the chapter's prose says
(`mix(pixel_at(c, x, y), col, weight, true)`), so turning the switch off
changed Wu's antialiasing weights. Fixed by passing `true` explicitly; every
other chapter 1-4 scenario still passes.

See `FEEDBACK.md` for notes on chapters 5 and 6.
