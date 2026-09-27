# Feedback: chapters 20 and 21, Rust reader (plus catch-up on 1-19)

## Result

All 694 tests pass (`cargo test --release --offline`). Every scenario in `features/` has a test.

| chapter | feature file | scenarios | pass |
|---|---|---|---|
| 20 | document | 3 | 3 |
| 20 | numbers | 5 | 5 |
| 20 | pathdata | 12 | 12 |
| 20 | building | 10 | 10 |
| 20 | transform | 6 | 6 |
| 20 | style | 7 | 7 |
| 20 | shapes | 6 | 6 |
| 20 | viewbox | 7 | 7 |
| 20 | paint | 8 | 8 |
| 20 | walker | 8 | 8 |
| 20 | groups | 8 | 8 |
| 20 | plate | 3 | 3 |
| **20** | | **83** | **83** |
| 21 | counting | 3 | 3 |
| 21 | bounds | 3 | 3 |
| 21 | tiles | 6 | 6 |
| 21 | spans | 3 | 3 |
| 21 | simd | 2 | 2 |
| 21 | plate | 4 | 4 |
| **21** | | **21** | **21** |

max_channel_difference against `reference/`, from `out/` (binary P6):

| render | max diff |
|---|---|
| chapter-20/aspect_demo | 0 |
| chapter-20/harbor | 0 |
| chapter-20/rose | 0 |
| chapter-20/tiger | 0 |
| chapter-21/work_map | 0 (82 before I changed my reading of the inset rule, see Failures) |

Chapter 15's four renders are also 0 against the updated references.

The chapter 20 code passed all 83 scenarios on its first run, and harbor, rose and tiger matched the
references byte for byte on that same run. The spec is tight. The two things I could not get from
the text are `aspect_demo`'s layout and the work map's inset at the canvas edge.

## Catch-up

There were far more new scenarios than the brief said. This code had last run against an older
`features/`. What I found by matching every scenario name and its numbers against the tests:

New scenarios (all translated and added):

- ch03-wu "The weights are applied in light, whatever the switch says". **FAILED**: `plot` blended
  through `mix`, which follows the global switch. Fixed by using `mix_with(.., true)`, as the text
  says.
- ch04-matrices "Invertibility is an exact test against zero". **FAILED**: `is_invertible` used
  `approx_eq(det, 0)`, so `scaling(0.0001, 1)` was called singular. Fixed to `det != 0.0`.
- ch13-stroke "A round cap is a semicircle of sixteen steps, whatever the rounding". **FAILED**: the
  first cap came out 17 steps (18 points). Fixed by adding the `- 0.000000001` to `arc_steps`. The
  scenario earns its place.
- ch04-drawing "A union of nothing is inside nowhere". Passed. The feature file was also renamed
  from `chapter04-shapes.feature` to `chapter04-drawing.feature`, and I updated the test header.
- ch04-plate "side_by_side puts the first canvas on the left", ch04-tuples "magnitude and dot look
  at x and y only", ch05-rules "Even-odd counts negative windings too", ch06-edges "A nearly
  horizontal edge is still an edge", ch06-sweep "A bow tie has four crossings on a row", ch08-arc
  "A half circle is the boundary the acos clamp guards", ch08-flatten "A curve scaled up needs more
  points", ch09-blend "A non-separable blend that overflows is clipped", ch10-gradients "When both
  roots are valid the larger one wins", ch11-mip "Downsample averages premultiplied". All passed on
  the old code.

Changed scenarios:

- ch03-plate: Bresenham's fan and Wu's fan gained three and two pixel probes and a reference diff.
  They pass.
- ch15: the reference images changed. Diff is 0.

Also fixed without a failing scenario: `radial_t` tried the two roots in the fixed order
`(-b+s)/2a` then `(-b-s)/2a`. That is largest-first only when `a > 0`, and the new "larger one wins"
scenario has `a > 0`. The roots are now sorted explicitly. I did not construct a case where both
roots are valid and `a < 0`, so this may be unreachable. If it is reachable, the scenario doesn't
pin it.

## Ambiguities (what I guessed)

1. **`aspect_demo()` has no specification outside the figure code.** Figure 20.4's caption says
   "one portrait drawing in five landscape viewports". The scenario pins 660×110 and seven pixels.
   Nothing in the prose or the feature gives the drawing (the 60×80 SVG with a rect, circle, polygon
   and a 2-wide border), the panel size (120×90), the offsets (10 + 130k, 10), the order of the five
   aspect values or the paper colour. I took all of it from `ASPECT_SVG`/`aspectDemo` in the
   chapter's script, because there was no other source. This breaks the iron rule: the render is
   pinned, but the reader has to transcribe JS to make it.
2. **Work-map squares at the cut-short bottom row of tiles.** The plate feature says each square is
   "inset one pixel from its tile's edges (the tile's first and last row and column are left as
   paper)". The tiles feature says an edge tile "is cut short by the canvas". For the bottom tiles
   (rows 448–449), the literal reading leaves both rows as paper. The reference paints row 449: it
   insets the full 16-px square and then clips. I now match the reference. As first written from
   the text, 84 pixels in row 449 differed by up to 82.
3. **Do clip fills count in `Stats`?** Not stated. I don't count them, and my harbor and rose
   `cells` match the table exactly (both files have clips), so the reference doesn't either. Say so.
4. **A shape-level clip in "bounded" and "tiled" mode** is unspecified, and none of the three
   documents has one (their clips are on groups, so they go through `mask_layer`). I multiply the
   clip into the window. In tiled mode every non-empty tile becomes partial with its values times
   the clip.
5. **Frame of the tiled accumulator.** The pseudo-code keys cells by canvas `(x, row)` with no
   translation, so I don't translate. That makes tiled values bit-identical to chapter 7's, while
   bounded differs in the last bits. The feature is silent on this.
6. **`paint_server` with one stop on a zero-width bbox.** The order of the degenerate checks isn't
   given. I reject the zero bbox first (SVG says the element isn't rendered). No scenario tells the
   two orders apart (see Mutation results).
7. `rgb()` accepts only comma-separated components. `fill-opacity`/`opacity` accept a number with an
   optional `px` and no `%`. An unknown alignment word in `preserveAspectRatio` falls back to
   `xMidYMid`. A nested `<svg>` is walked as a `<g>` (the pseudo-code does that).
8. Degrees to radians: `d * PI / 180` or `d.to_radians()` (which is `d * (PI/180)`). Pixels are
   unaffected, but harbor's blend count moved by 42. I kept `to_radians`.

## Hard to translate

- Gherkin's `none` became `Option`: `read_number`/`read_flag` return `(Option<f64>, usize)`, and
  `parse_transform(none)` is `parse_transform(None)`, so every other call site needs `Some("...")`.
  `view_box_matrix(none, none, ..)` works the same way.
- `s.fill = color(...)` and `s.fill = "url(#sky)"` compare a field that can be a colour or a string.
  I used an enum `SvgPaint { None, Color, Url(String) }` and matched on it in the tests.
- "`transformed_paint` joins chapter 10's registry of paint kinds": Rust's `Paint` is a closed enum,
  so joining meant adding a `Transformed` variant and a match arm in `paint_at`. This edits
  chapter 10's code.
- `coverage_in` and `full_coverage` take "a window, a plain buffer or a tiled coverage": a
  `CoverageSource` trait.
- The scenario named "Plate 21" collides with the function `plate_21` in the test's namespace, so
  the test is called `plate_21_test` (same as the earlier plates).
- chapter 7's `add_cell`/`accumulate` operate on the dense `Accumulator`. To store "only the cells
  deposited into" with bit-identical deposits, I made them generic over a `CellSink` trait instead of
  copying them. The public chapter 7 API is unchanged.
- §21.5 names "Rust's `std::simd`". That is nightly-only. On stable I used `[f64; 4]` lane loops,
  which LLVM vectorizes, and relied on Rust never contracting `a*b + c` into FMA on its own. The
  text should say `std::simd` is unstable.

## Failures

None remaining. The only discrepancy is not tested: **the §21.7 table's `blends` column for harbor
and rose doesn't reproduce.** Mine: harbor whole/bounded/tiled 526,548 / 428,770 / 338,676 (table
526,696 / 428,819 / 338,744); rose 1,162,064 / 655,457 / 531,040 (table 1,167,017 / 654,793 /
531,929). `cells` and `copies` match the table exactly for all three documents in all three modes.
Every tiger number matches, and every render is byte-identical. The blend count includes the 1e-16
crumbs (and near-zero values in partial tiles), so it depends on the last bits of the geometry.
Changing only `*PI/180` to `to_radians` moved harbor's whole-mode count by 42. That's the
reference's fault only in the sense that the table presents blends as if they were stable. The prose
should say they aren't, or the table should only claim tiger blends.

## Prose problems

- §20.12 pseudo-code: `own ← style.opacity or (clip and el is svg or g)` should be
  `style.opacity < 1 or ...`. As written it reads as truthiness of a number.
- §20.12 `draw_shape`: `fill_path(...) × clip` where clip may be "nothing". Say that "× nothing" is
  a no-op.
- §20.8 / viewbox feature: the feature says `none` is `scaling(sx, sy) × translation(-min-x,
  -min-y)`, but no scenario has a non-zero origin under `none` (see Mutation results).
- §21.3's bold claim "816,480, down from 1,395,287 … a factor of 1.7" checks out. But in Rust the
  tiled mode is *slower* than bounded on the tiger (22.6 ms vs 21.0 ms): the HashMap and the per-row
  sort cost more than the 580k cells saved. The chapter's "measure first" lesson holds more strongly
  than the chapter says. It's worth a sentence that the ranking depends on the language.
- §21.6 says clips and groups still use canvas-sized buffers. In Rust that is now the dominant cost
  of harbor and rose in every mode (~44 ms bounded/tiled vs ~90–116 ms whole). Each of harbor's ten
  halo circles makes and composites a full 480×320 layer. Worth saying outright that this is where
  the time goes after §21.3 in a compiled language.

## Mutation results

Each mutation was applied alone, all chapter 20/21 tests were run, and the mutation was reverted.
The suite is green afterwards.

Caught (and by what):

- matrix() filled row by row → "matrix lists its six numbers column by column"
- transform list multiplied right to left → "A list applies right to left", harbor
- stroke in device space (no inverse), or device space with width × approx_scale → tiger renders
  and counts, harbor, rose
- flatten before the transform → tiger renders
- arc piece count without the 0.000001 → "A quarter circle is one cubic…" (the 8.3/1.1 case)
- relative arc end not offset by the current point → harbor, rose only (see below)
- S reflecting only after C, not after S → the S-after-S scenario, tiger
- opacity inherited → "Inherited properties…", group scenarios, harbor
- presentation attribute beating style → "A style declaration beats…"
- gradientTransform before the bbox matrix → "gradientTransform applies inside…", harbor
- radial focal/centre swapped → focal scenario, harbor, rose
- group opacity applied per child → group-opacity scenario, harbor
- clip built without the element's own transform → "A clip lives in the user space…"
- clip union as max → union scenarios
- unknown elements walked into → "What isn't drawn", clip scenarios
- dash offset ignored → harbor only
- lone movetos kept → "A moveto on its own is dropped…"
- `#rgb` ×16 → colour scenario, tiger
- stop offsets allowed backwards; rect radius uncapped; meet/slice swapped; skew in radians; odd
  polyline number padded; group clip pushed down to shapes → caught (the last only by harbor)
- 21: fill_bounds with ceil; classifier checking the top row only; `n` by floor; partial rows from
  0; copy at any alpha; copy for gradient paints; FMA in composite_span4; dropped leftover pixels;
  bounded fill not moved; blends counted at k = 0; arriving sum including the cell on the edge;
  exact-equality uniform test → all caught

**Not caught by any scenario:**

1. **`preserveAspectRatio="none"` dropping the viewBox origin** (`scaling(sx, sy)` without the
   translation). The only `none` scenarios have origin (0, 0), and so does `aspect_demo`. Add
   `view_box_matrix("10 20 60 80", "none", 120, 90) * point(10, 20) = point(0, 0)`.
2. **opacity / fill-opacity / stroke-opacity not clamped** to [0, 1]. Nothing probes 1.5 or -0.5.
3. **stroke-miterlimit below 1 accepted.** The table says "at least 1", but nothing probes 0.5.
4. **clipPath children styled from `initial_style()` instead of the clipPath's computed style.**
   The feature says the child's clip-rule is "computed from the clipPath's style". No scenario puts
   clip-rule on the clipPath element itself. Add `<clipPath clip-rule='evenodd'><path d='…ring…'/>`.
5. **"An invalid value is ignored" vs "reset to initial"** for stroke-width and fill-rule: in the
   inherit scenario the parent's values (1, nonzero) equal the initial ones, so a reset passes. Only
   `stroke='#nope'` (parent blue) really tests it. Give the parent `stroke-width='3'
   fill-rule='evenodd'`.
6. **An arc's last point recomputed with cos/sin instead of taken exactly.** "An arc in a path ends
   exactly at its end point" compares with ±0.0001, so "exactly" is unpinned, and no render notices.
   Either compare exactly or drop "exactly" from the scenario name.
7. **The single-stop vs zero-bbox check order in `paint_server`** (Ambiguity 6). Both orders pass.
8. **Solid-tile copies counted as 256 per tile even when the tile is cut short.** The tiger has no
   solid edge tiles (207,872 = 812 × 256), and the spans scenarios are 64×64. A 40×40 canvas spans
   scenario would pin it.
9. **`parse_transform` accepting junk inside the parentheses** (`scale(2 x)` read as `scale(2)`).
   The feature lists "an unknown name, the wrong number of numbers, a missing parenthesis". Junk
   inside isn't listed or probed.
10. Relative arc ends and dash offsets are caught *only* by the harbor/rose golden images. Every path
    scenario's arc starts at (0, 0), so relative and absolute agree there. A unit scenario
    (`path_commands("M5 5 a1 1 0 0 1 2 0")[1].args` ends at 7, 5) would localise the failure.

Equivalent, not real gaps: "a deposit counts only if its area is nonzero" (a cover-only deposit
can't happen: a folded one has area = cover). "stroke-width 0 still strokes" (a zero-width outline
fills nothing).

## Concrete changes you'd make

1. Specify `aspect_demo()` in the viewbox feature's description (the SVG, panel size, offsets, order
   of aspects, paper), as the plate features do for their renders.
2. Rewrite the work-map inset sentence to match the reference: "each square is its tile's full 16
   pixels inset by one on every side, then cut by the canvas" (or regenerate the reference with the
   literal rule).
3. Add the scenarios listed under Not caught 1, 4, 5, 8 and 10. They are cheap.
4. Say in §21.7 that blend counts include sub-visible crumbs and depend on the last bits of the
   geometry. Only the tiger's blends should be expected to reproduce exactly.
5. State that clip fills are not counted in `Stats`, and say how a shape-level clip combines with a
   window or tiles.
6. Fix `own ← style.opacity` to `style.opacity < 1` in §20.12.
7. Note that `std::simd` is unstable in Rust.

## Timing

Release build, this machine, one run each:

- Renders: aspect_demo 3.8 ms, harbor 91 ms, rose 133 ms, tiger 246 ms, work_map 80 ms. Tiger
  whole-mode is ~120× faster than the book's quoted 29 s Python reference, as expected.
- Work counters against the chapter's table (mine / table):

| doc | mode | cells | blends | copies | time |
|---|---|---|---|---|---|
| tiger | whole | 61,762,500 / same | 1,668,160 / same | 0 | 218 ms |
| tiger | bounded | 1,395,287 / same | 813,594 / same | 0 | 21 ms |
| tiger | tiled | 816,480 / same | 407,274 / same | 207,872 / same | 23 ms |
| harbor | whole | 14,592,000 / same | 526,548 / 526,696 | 0 | 89 ms |
| harbor | bounded | 737,160 / same | 428,770 / 428,819 | 0 | 44 ms |
| harbor | tiled | 259,840 / same | 338,676 / 338,744 | 80,640 / same | 44 ms |
| rose | whole | 27,840,000 / same | 1,162,064 / 1,167,017 | 0 | 116 ms |
| rose | bounded | 1,076,869 / same | 655,457 / 654,793 | 0 | 45 ms |
| rose | tiled | 543,744 / same | 531,040 / 531,929 | 2,048 / same | 57 ms |

- Bounding is the big win in Rust too (tiger 10×). Tiling adds nothing in Rust and is slightly
  slower on the tiger: hashing and sorting the sparse cells costs about what resolving them did. On
  harbor and rose, both are bottlenecked on canvas-sized group layers and clips.
- The four-wide span (`[f64; 4]` lanes, std only; `examples/span_bench.rs`): scalar 100 ms vs
  four-wide 71 ms for 4096 px × 20,000, about 1.4×, and `layers_equal` holds. On a whole render
  it's lost in the noise, as the chapter predicts. The `Pixel` array-of-structs layout is what
  limits it: the loads are strided gathers. A structure-of-arrays layer would let it go further.
