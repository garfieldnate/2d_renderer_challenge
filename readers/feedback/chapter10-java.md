# Reader feedback: chapters 9 and 10 (Java)

Cold implementation of chapter 9 (Compositing) and chapter 10 (Paint Servers
and Gradients) on top of the existing chapters 1-8 Java code, from the
chapter HTML and `.feature` files alone. No other files in the book's
repository were read or consulted.

## Result

| Chapter | Scenarios | Pass | Fail |
|---|---|---|---|
| 1 | 66 | 66 | 0 |
| 2 | 35 | 35 | 0 |
| 3 | 38 | 38 | 0 |
| 4 | 76 | 76 | 0 |
| 5 | 32 | 32 | 0 |
| 6 | 34 | 34 | 0 |
| 7 | 34 | 34 | 0 |
| 8 | 23 | 23 | 0 |
| 9 | 45 | 45 | 0 |
| 10 | 24 | 24 | 0 |
| **Total** | **407** | **407** | **0** |

Renders, `max_channel_difference` against `reference/chapter-0N/*.ppm`:

| File | Diff |
|---|---|
| `out/porter-duff.ppm` | 0 |
| `out/plate-09.ppm` | 0 |
| `out/blend-modes.ppm` | 0 |
| `out/seam.ppm` | 0 |
| `out/three-gradients.ppm` | 0 |
| `out/plate-10.ppm` | 0 |
| `out/extend-modes.ppm` | 0 |

Every render diffs exactly 0, not just within the ≤1 budget. Chapters 1-8
were already reader-tested clean; nothing about their code changed except
`Ppm.java` (see Prose problems / API note below).

## Catch-up

Ran `Chapter01Tests` through `Chapter08Tests` before touching chapter 9.
All 338 scenarios passed and every one of that range's renders was already
present and correct in `out/`. Nothing newly broken. No mutation left over
from a previous round was found in `readers/`-style contamination, since
this scratch directory holds only this reader's own chapters 1-8 code.

## Ambiguities

- **§9.6, `blend_strip()` and `seam()` have no printed pseudocode.**
  `porter_duff_table()`/`plate_09()` are printed in full; the plate feature
  names `blend_strip()` and `seam()` and describes them in prose ("shows the
  sixteen blend modes", "two opaque triangles that share the diagonal") but
  never prints their bodies. I reverse-engineered both from the chapter's own
  in-browser figure-drawing JavaScript (`blendGrid()`/`seamBytes()` in the
  `<script>` block at the end of `chapter-09.html`), which is legitimately
  part of the chapter file, not the withheld reference implementation. Both
  renders came out diffing 0 against the reference PPMs, which confirms the
  JS and the Python reference agree, but a reader without JavaScript literacy
  (or one who didn't think to read the figure-drawing script) has no printed
  spec to work from for these two renders. Same issue, smaller stakes, for
  chapter 10's `extend_strip()`.
- **The gap and background color between `three_gradients()`'s three
  panels is untested.** The scenario pins pixels inside each 150x150 panel
  and an overall width of 458 (`= 150*3 + 4*2`), which nails the gap width at
  4px, but no scenario probes a pixel inside that gap, so its color (I used
  the paper color, matching every other multi-panel figure in the book) is
  unverified. A single `ppm_pixel` probe at e.g. `(151, 75)` would pin it.
- **`paint_fill`'s skip-when-uncovered isn't specified as an optimization
  vs. a requirement.** The prose says "for every covered pixel it samples
  paint_at", which reads as license to skip sampling where coverage is zero,
  and the one scenario that exercises it doesn't distinguish "paint sampled
  everywhere, but zero-coverage pixels are unaffected" from "paint sampled
  only where covered" (both give the same canvas). Worth a line in prose
  since a gradient with a division by zero at some out-of-shape point would
  behave differently under the two readings.

## Hard to translate

- **`radial_t`'s "largest root" instruction doesn't match the literal
  algorithm needed.** §10.3 says "take the larger root whose radius isn't
  negative", but the straightforward implementation (compute both roots,
  filter by validity, take the max of what's left) is *not* what the
  reference JS does, and more importantly is not the same computation in
  general: when the quadratic's leading coefficient `a` is negative (which
  happens whenever the radius spread `dr²` exceeds the center distance
  squared -- true of every gradient this chapter's scenarios exercise,
  including the plain concentric case and the offset-focus case),
  `(-b+s)/(2a)` and `(-b-s)/(2a)` swap places: the *first* root computed by
  the textbook quadratic formula is the *smaller* one, not the larger. The
  reference JS handles this correctly by checking both roots' validity in a
  fixed order and returning the first valid one -- but that only produces
  "the largest valid root" by accident of which cases the book happens to
  test (all of them have negative `a`). See **Mutation results** below: I
  implemented it two ways and the "wrong" way (always take the `(-b-s)/(2a)`
  root, no validity check on the other one first) passes all 24 chapter 10
  scenarios, because none of the three gradient scenarios has `a > 0`. I
  matched the reference JS's actual algorithm (try both roots in the
  `(+,-)` order, first valid one wins) rather than the prose's "take the
  largest", since that's what's provably correct against the reference
  bytes, but a reader who does what the prose says literally (max of the
  valid roots) gets a chapter that reads as complete and passes every test
  while silently computing the wrong gradient for two circles of similar
  radius far apart.
- **The four non-separable blend formulas (`Lum`/`Sat`/`clipColor`/`setLum`/
  `setSat`) are described in prose but never given as pseudocode**, unlike
  every other formula in chapters 9 and 10. The prose is enough to get the
  *shape* right (three helpers, hue/saturation/color/luminosity each one
  line combining two of them) but the exact `clipColor` clamp-toward-Lum
  formula and the `setSat` index-sort-and-redistribute construction are
  textbook (ITU/PDF-spec) details that aren't derivable from the paragraph
  alone; I matched the reference JS's `clipColor`/`setSat` verbatim. A reader
  without that JS to check against would have to already know the compositing
  spec's math or reinvent it by trial against the one pinned scenario, which
  only checks four color outputs, not the helpers individually -- so a subtly
  wrong `clipColor` (wrong which of `n`/`x` triggers first, say) has a real
  chance of surviving if it happens to agree on this scenario's four colors.

## Failures

None. Every scenario translated and passed on the implementation described
above; no chapter or reference bug found that blocks a scenario.

## Prose problems

- **§10.5, `to_byte` is used by name in a scenario (`to_byte(0.5) = 188`)
  but chapters 1-8 never named or exposed such a function** -- chapter 1
  only ever describes the conversion inline as part of `canvas_to_ppm`. This
  reader's chapter 1-8 code (from an earlier round) had it as a private
  `channelToFileValue` inside `Ppm.java`; making chapter 10's scenario pass
  required promoting it to a public `Ppm.toByte`. Not a bug, but worth
  chapter 10 flagging in prose that `to_byte` is being named for the first
  time here (or chapter 1 naming it up front), since a reader whose chapter
  1-8 code never named the conversion has to go back and refactor chapter 1
  code while implementing chapter 10.
- **§9.6**, **§10.2**, and **§10.6**: see Hard to translate / Ambiguities
  above re: `blend_strip()`, `seam()`, and `extend_strip()` having no printed
  pseudocode, unlike `porter_duff_table()`/`plate_09()`/`three_gradients()`/
  `plate_10()` in the same sections.
- **§10.3**: see Hard to translate above re: "take the larger root" not
  matching the algorithm that's actually correct (and actually tested)
  when the quadratic's leading coefficient is positive.

## Mutation results

Chapter 9 (all three caught):
- Wrong Porter-Duff coefficient (`src-in` given `(as, 0)` instead of
  `(ad, 0)`): caught by the `Porter-Duff: each operator...op=src-in`
  scenario and by Plate 9.
- Blending in encoded space instead of linear light (encode both inputs,
  run `blend_color`, decode the result): caught by 9 of the 12 separable
  scenarios (`multiply`/`screen`/`overlay`/`color-burn`/`hard-light`/
  `soft-light`/`difference`/`exclusion`; only `darken`/`lighten`/
  `color-dodge`/`normal` happened to be monotone enough to survive at this
  particular input), the non-separable-modes scenario, and the blend-mode
  strip render.
- Wrong `Lum` weights (`(r+g+b)/3` instead of `0.3R + 0.59G + 0.11B`):
  caught by the non-separable-modes scenario, `blend_color("color", ...)`,
  and the blend-mode strip render.
- Bonus: a "coverage-aware fix" for conflation (`over`'s alpha as
  `max(src.a, dst.a)` instead of `src.a + (1-src.a)*dst.a`) is caught
  immediately by the ordinary "two translucent pixels stack their alphas"
  scenario, before the conflation scenario is even reached -- the suite
  doesn't need a conflation-specific probe to catch this class of bug,
  the basic `over` scenario already does.

Chapter 10 (three of four caught; **one survived**):
- Reflect implemented as repeat: caught by 4 of the 6 extend-mode table
  rows and the extend-strip render.
- Dither offset omitted (falls back to `floor(x + 0.5)`): caught by both
  dither scenarios.
- Focal cone painted black instead of the last stop: caught by the
  "unreachable focal pixel" scenario.
- **Survived: the wrong root of the radial quadratic.** Always returning
  `(-b - s) / (2*a)` -- skipping the "try `(-b+s)/(2a)` first, fall back to
  the other root if it's invalid" logic entirely -- passes all 24 chapter 10
  scenarios and renders `three-gradients.ppm`/`plate-10.ppm` bit-identical
  to the reference. I confirmed by hand that this mutation is a real,
  distinguishable bug (not an equivalent mutant): for a radial gradient
  between two circles of similar radius set far apart (`c0=(0,0), r0=10,
  c1=(100,0), r1=15`, so the quadratic's leading coefficient `a = cd² - dr²
  = 9975 > 0`), the correct algorithm gives `radial_t(g, 50, 0) = 0.6316`
  and the mutated one gives `0.3810` -- a different stop on the gradient
  entirely. Every scenario in `chapter10-gradients.feature` and
  `chapter10-plate.feature` happens to use gradients where `a < 0` (either
  concentric, or a small offset focal point relative to a much larger
  radius spread), which is exactly the regime where `(-b-s)/(2a)` already
  equals the correct largest-valid-root by coincidence of the sign flip
  from dividing by a negative `2a`. See Hard to translate above for the
  root cause. **Concrete fix**: add a scenario with two circles of
  comparable radius and significant center separation (so `a > 0`), which
  distinguishes the two root-selection strategies.

## Concrete changes

1. Add a chapter 10 scenario for a radial gradient whose two circles have
   comparable radii and are far enough apart that the quadratic's leading
   coefficient is positive, to close the mutation gap above. Something like
   `radial_gradient(point(0,0), 10, point(100,0), 15, stops, "pad")`, probed
   at an x between the circles, would do it.
2. Print `blend_strip()`, `seam()`, and `extend_strip()` as pseudocode in
   §9.6/§10.2, matching the treatment `porter_duff_table()`/`plate_09()` and
   `three_gradients()`/`plate_10()` already get in the same sections --
   right now they're only recoverable from the browser figure-drawing
   JavaScript at the bottom of the chapter HTML.
3. Either give `clipColor`/`setSat` as explicit pseudocode in §9.5, or add a
   scenario that checks one of them directly (not just the four composed
   blend-mode outputs), since a subtly wrong non-separable helper has a real
   chance of still agreeing with the one pinned scenario.
4. Add one `ppm_pixel` probe inside the 4px gap between `three_gradients()`'s
   panels, to pin its background color (currently only the panel-pixel
   probes and the overall width are checked).
5. Either fix §10.3's "take the largest root" line to describe the actual
   correct algorithm (try both roots, first with a non-negative interpolated
   radius wins, in the order that the quadratic formula naturally produces
   them) or add a note explaining why "largest of the valid roots" and "first
   valid root in formula order" coincide for every case the book uses but
   diverge for `a > 0`.
6. Name `to_byte` in chapter 1 (or note in §10.5 that it's being named for
   the first time there) so a reader's chapter 1 code already exposes it
   under that name instead of requiring a chapter 10 refactor.

## Timing

Reading chapter 9 + all five `.feature` files: ~10 minutes. Reading chapter
10 + all five `.feature` files: ~10 minutes. Implementation (Pixel,
Compositing, Blend, Layer/Layers, Paint/Solid/Stop/Stops, the three
gradients, Painter.paintFill, Dither, Ppm changes, both Figures sections,
both Chapter*Tests files): ~70 minutes, including three passes reading the
chapter's embedded figure JavaScript to recover `porter_duff_table()`'s
tile layout, `radial_t`'s exact root-selection order, and
`blend_strip()`/`seam()`/`extend_strip()`'s un-pseudocoded bodies, each
cross-checked by hand against the pinned scenario numbers before writing
any Java. Mutation testing (3 chapter 9 mutations + 1 bonus + 4 chapter 10
mutations, each applied, run, and reverted): ~20 minutes, including
tracking down and confirming the one surviving mutation was real rather
than equivalent. Total: a little under two hours.
