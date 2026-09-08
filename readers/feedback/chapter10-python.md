# Feedback: Chapters 9-10 (Python)

## Result

Catch-up (chapters 1-8): 340/340 scenarios pass, nothing newly broken.

Chapters 9-10 combined: 409/409 scenarios pass, 0 failures.

Per-file scenario counts:
- chapter09-pixels.feature: 5/5
- chapter09-over.feature: 5/5
- chapter09-porterduff.feature: 14/14 (12 from the Scenario Outline + 2)
- chapter09-blend.feature: 15/15 (12 from the Scenario Outline + 3)
- chapter09-plate.feature: 5/5
- chapter10-stops.feature: 4/4
- chapter10-extend.feature: 6/6 (from the Scenario Outline)
- chapter10-gradients.feature: 6/6
- chapter10-dither.feature: 3/3
- chapter10-plate.feature: 5/5

Full suite (chapters 1-10): 409/409.

Render `max_channel_difference` against `reference/`, all exact:
- `porter-duff.ppm`: 0
- `plate-09.ppm`: 0
- `blend-modes.ppm`: 0
- `seam.ppm`: 0
- `three-gradients.ppm`: 0
- `plate-10.ppm`: 0
- `extend-modes.ppm`: 0

## Catch-up

Chapters 1-8 unaffected: reran their 340 scenarios in isolation before touching anything, all green. No mutation of existing files was needed.

## Ambiguities (what I had to guess)

- **Layer vs. canvas for the blend-mode plate.** Section 9.4/9.6 never says whether `blend_strip()`'s backdrop square lives on paper or on a transparent layer. I first painted the square straight onto a paper-filled canvas (the way `porter_duff_table()`'s tiles get *flattened*, i.e. after the fact). That reproduces the `"normal"` and `"lighten"` tiles byte-for-byte but is wrong for every mode that reacts to a dark backdrop (`multiply`, `darken`, `color-burn`, ...): outside the square, my paper-backed canvas hands those modes a near-black backdrop, and e.g. `color-burn(paper, orange)` burns to black, while the reference shows plain orange there (i.e. the mode fades to plain source-over where the destination doesn't reach, per the prose in §9.4 — "fading to plain source-over where they don't [overlap]"). The fix was to build the square as a genuine transparent `Layer` (alpha 0 outside it), blend the circle over that layer's pixels directly, and only flatten over paper at the very end. The chapter says this exact thing about `over` in general but doesn't connect it explicitly to how the blend-mode figure has to be constructed; a sentence in §9.6 next to the `porter_duff_table` pseudocode saying "the blend strip is built the same way, as layers, not paper" would have saved a wrong first render.
- **`porter_duff_table`/`blend_strip`/`seam` geometry and colours are nowhere in the prose.** The chapter gives no coordinates for the "blue square" and "orange circle," no colour values, and no dimensions for `seam()`'s triangles. Chapter 1's own rule ("numbers quoted in prose come from the reference, never memory") isn't honoured here even for the *reader*: there's no pseudocode analog of chapter 8's `flower()`/`spots` list. I reverse-engineered all of it from `reference/chapter-09/*.ppm` by decoding bytes back to linear light and solving for exact geometry:
  - Circle: `circle_path(38, 38, 20, 48)` filled with `fill_path(..., "nonzero")` — not the primitive `circle()` shape rasterized with chapter 2's 8×8 supersampling, which does *not* reproduce the reference (max diff 0.05 in coverage at the boundary). The book has to be using the polygon-approximation circle from chapter 5 for this figure, but never says so.
  - Square: `polygon((10,10),(42,10),(42,42),(10,42))`, filled the same way.
  - Colours: orange `color(0.95, 0.55, 0.1)`, blue `color(0.2, 0.5, 0.85)` — close to but *not* the same as the `INKS` orange/blue used in chapters 6-8 (`0.9`/`0.55` vs `0.95`/`0.5`), which cost some time assuming reuse before the bytes disagreed by more than 1.
  - `seam()`: renders on an 80×80 canvas (triangles at `(4,4)`-`(76,76)`, split by the *main* diagonal, not the anti-diagonal I guessed first) and magnifies by 4. The reference's seam is exactly one *base* pixel wide per row, blown up into a visible 4×4 block — without noticing the magnify, my first two geometry guesses (anti-diagonal, various margins) all produced a diagonal that only ever touched pixel *corners*, so cov1/cov2 were always exactly 0 or 1 and no seam ever appeared, anywhere, for any position I tried.
- **The chapter 10 "sunset" stop table is never given**, only described as "five colours dark to pale." Same problem: `three_gradients()`'s pseudocode says `stops ← the sunset table` and nothing else. I fit a piecewise-linear model against the reference's linear-gradient diagonal (least-squares per candidate breakpoint, in linear light, decoded from the PPM bytes) and the data supports exactly **four** stops, not five: `(0, color(0.05, 0.02, 0.15))`, `(0.35, color(0.75, 0.15, 0.25))`, `(0.7, color(0.98, 0.6, 0.15))`, `(1.0, color(1.0, 0.95, 0.75))`. Adding a plausible fifth breakpoint anywhere between 0.7 and 1.0 improved the least-squares residual by under 6%, i.e. within 8-bit quantization noise — there's no detectable fifth colour in the actual pixels. Either the reference implementation truly uses four stops and the prose is off by one, or there's a fifth stop whose neighbours are colinear enough with it to be invisible in an 8-bit render. Either way, a reader has no way to get this from the text; it should be printed the way chapter 8 prints `INKS` and `spots`.
- **`extend_strip()`'s "short gradient" and layout are also unstated.** Reverse-engineered as: an 80×90 base canvas (bands of 30 rows: pad, repeat, reflect, in that order) magnified by 2 to 360×180; axis `point(60, *)` to `point(100, *)` in base coordinates; stops `color(0.1, 0.15, 0.5)` at 0 and `color(1.0, 0.7, 0.1)` at 1. Confirmed exact (max diff 0) once found, but this took the same decode-and-fit process as the sunset table, plus noticing the column-pairing artifact in the reference bytes that gave away the ×2 magnify factor.

## Hard to translate

- Nothing structural was hard to translate given the existing `renderer.py` conventions (`Shape`/`Path`/`CoverageBuffer` machinery from earlier chapters slots straight into `paint_shape`/`paint_fill`). The non-separable blend helpers (`Lum`/`Sat`/`ClipColor`/`SetLum`/`SetSat`) are the standard W3C/PDF compositing-spec algorithm; the chapter names them but never writes the formulas out, so I had to bring them from outside knowledge and then verify every constant against the four `blend("hue"/"saturation"/"color"/"luminosity", ...)` scenario values by hand before trusting them. They matched to the last digit, so the omission is a documentation gap, not an ambiguity that changes behavior — but a reader without that background (which is most of the target audience, given the chapter's own framing of these as needing "three small helpers from the compositing spec") has nothing to go on beyond "Lum(C) is 0.3R + 0.59G + 0.11B" and one sentence each for Sat/set_lum/set_sat with no formulas.

## Failures

None outstanding. Every scenario in `features/chapter09-*.feature` and `features/chapter10-*.feature` passes as written; no scenario needed weakening or was left red.

## Prose problems

- **§9.4/§9.6** (blend-mode figure): doesn't say the blend-mode plate composites over a transparent layer rather than paper (see Ambiguities above). A reader who paints the backdrop square directly onto paper (the natural reading of "paint a shape into it," reusing chapter 2's `paint_through` mental model literally) gets 8 of 16 tiles wrong.
- **§9.6** (`porter_duff_table`, `blend_strip`, `seam`): no geometry or colour constants given at all, unlike every prior chapter's "one-off fun" renders (chapter 7's `needles`/`rays`, chapter 8's `flower`'s `spots` list), which print every magic number the reader needs. This chapter is the first to break that pattern; see Ambiguities for what had to be reverse-engineered instead.
- **§10.6** (`three_gradients`, `extend_strip`): same problem, worse — the stop table is the entire point of the section ("Nothing about the stops changed between the three panels") and it's never printed. A reader has no way to reproduce `plate-10.ppm` from the text; the golden-image scenario becomes unfalsifiable prose-wise (it pins the reference bytes but doesn't teach how to arrive at them).
- **§9.5**: names `Lum`/`Sat`/`set_lum`/`set_sat` and gives `Lum`'s formula and `Sat`'s formula, but not `set_lum`'s or `set_sat`'s (just prose: "shifts a colour to a target brightness and clips it back into range," "stretches it to a target saturation"). Given the book's stated rule that "every suggested implementation is specified," this section is the one place in chapters 1-10 that doesn't specify an implementation the chapter explicitly tells you to write ("worth writing once because they're a tidy little bit of colour science").

## Mutation results

Chapter 9:
- Wrong `Fa`/`Fb` coefficient (`src-over`'s `Fb` changed from `1 - a_s` to `1 - a_d`): **caught**, 4 scenarios fail (`chapter09-porterduff.feature` twice, `chapter09-plate.feature` twice).
- Blending in encoded space instead of linear (encode `Cs`/`Cb` before `blend_color`, decode the result): **caught**, 10 scenarios fail, including the render (`blend-modes.ppm` diff 205).
- Wrong non-separable helper (`ClipColor` missing its `x > 1` branch, i.e. never re-clamps an over-bright channel): **caught, but barely, and only by the render.** Both direct unit scenarios for hue/saturation/color/luminosity (chapter09-blend.feature, using `color(0.9,0.2,0.2)`/`color(0.2,0.4,0.8)`) still pass, because that particular pair of colours never overflows above 1 after `SetLum`/`SetSat`. Only `blend_strip()`'s render catches it, and only just (`max_channel_difference` = 3, against a budget of 1). **This is worth flagging as a real scenario gap**: the chapter should pin a hue/saturation/color/luminosity case that actually needs the overflow-clamp branch of `ClipColor`, the way §"Probe a clamp somewhere the placement matters" asks for elsewhere in this project's own conventions.
- Treating coverage as opacity in the seam (unioning the two triangles' coverage with `max()` and painting once, instead of compositing the second triangle over the first with `over`): **caught** by `chapter09-plate.feature`'s "The seam shows in the render" (pinned pixel `(160, 160)` goes from the correct `(220, 173, 81)` to `(185, 145, 71)`). Not caught by "The conflation seam is 0.75, not 1.0," which only exercises `composite()` directly and never calls `seam()`.

Chapter 10:
- Wrong root of the radial quadratic (take the *smallest* valid `t` instead of the largest): **survived every one of the 409 scenarios in the suite, including all three chapter 10 renders.** This is the most valuable finding of the round. Every existing test case — concentric, focal, and the unreachable-pixel trap — happens to have exactly one root satisfying `r0 + t·dr ≥ 0`, so "largest" and "smallest" never disagree anywhere the suite looks. I constructed a case by hand where they do disagree and it's a real, spec-violating bug, not an equivalent mutant: two circles of equal radius `5` at `(0,0)` and `(10,0)` (`dr = 0`), queried at their exact midpoint `(5, 0)`. Both `t=0` and `t=1` solve the quadratic and both keep the radius non-negative (`r0 + t·dr = 5` either way); the correct convention (this book's, and SVG's) is the larger root, `t=1`, but the mutant returns `radial_t = 0.0`. **Concrete change**: add a scenario to `chapter10-gradients.feature` with two circles of matching or overlapping radius where two roots are simultaneously valid, pinning the larger one.
- Reflect implemented as repeat (`extend(t, "reflect")` returns `t % 1.0`): **caught**, 5 scenarios fail (4 outline rows + `extend-strip` render).
- Dither offset omitted (`to_byte_dithered` floors the scaled value without adding `dither_threshold`): **caught**, both `chapter10-dither.feature` scenarios that exercise it fail.
- Focal cone painted black (`paint_at` returns `Color(0, 0, 0)` instead of `paint.stops[-1].color` when `radial_t` is `None`): **caught** by the exact scenario written for it ("An unreachable focal pixel takes the last stop, not black"). Notably, none of the three render scenarios (`three_gradients`, `plate_10`, `extend_strip`) exercise this path at all — the rendered focal gradient never has an unreachable pixel in view — so this mutation would have survived if the dedicated unit scenario didn't exist. Good evidence the chapter's own instinct to pin this with a direct scenario (rather than relying on the plate) was the right call.

All mutations were reverted; `renderer.py` was byte-identical to its pre-mutation state after each restore (checked with `diff`), and the full suite was re-run clean (409/409) at the end.

## Concrete changes

1. Print the actual geometry/colour constants for `porter_duff_table()`, `blend_strip()`, and `seam()` in §9.6, the way chapter 8 prints `spots` and `INKS` — a list of magic numbers, not prose.
2. State explicitly that the blend-mode plate's backdrop is a layer (transparent outside the square), not paper, and that only the finished blend gets flattened.
3. Print the `set_lum`/`set_sat` formulas (or the full `ClipColor` algorithm) in §9.5 instead of describing them only in prose.
4. Add a hue/saturation/color/luminosity scenario whose colours actually need `ClipColor`'s overflow branch.
5. Print the sunset stop table (§10.6) and the extend-strip's two-stop table (or at least its axis/band layout) explicitly.
6. Add a radial-gradient scenario with two valid roots, pinning the larger one, per the mutation finding above.

## Timing

Roughly 3 hours end to end: ~45 min reading chapter text and feature files (mostly chapter 9, which is dense); ~90 min reverse-engineering the unspecified render constants (circle/square geometry and colours for chapter 9's plates, the sunset and extend-strip stop tables for chapter 10) by decoding reference PPM bytes back to linear light and fitting geometry/breakpoints; ~30 min implementation once the constants were pinned down; ~30 min mutation testing and write-up. The reverse-engineering step dominated and would have been unnecessary if the chapter printed its own numbers, consistent with this project's stated iron rule.
