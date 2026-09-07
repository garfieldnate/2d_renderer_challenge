# Reader feedback: Python, chapters 7-8

## Result

All 338 scenarios pass (283 carried over from chapters 1-6, 55 new). Per-chapter scenario counts:

- Chapter 7 — 34 scenarios: `chapter07-cells` 5, `chapter07-row` 4, `chapter07-walk` 8, `chapter07-resolve` 2,
  `chapter07-fill` 10, `chapter07-plate` 5.
- Chapter 8 — 21 scenarios: `chapter08-curves` 5, `chapter08-bounds` 3, `chapter08-flatten` 5, `chapter08-arc` 5,
  `chapter08-plate` 3.

`python3 test_runner.py` tail:

```
Total: 338, Passed: 338, Failed: 0
```

Every render's `max_channel_difference` against its reference, computed directly (not just the `<= 1` scenario
budget):

| Render | max_channel_difference |
|---|---|
| needles.ppm | 0 |
| soft-square.ppm | 0 |
| star-exact.ppm | 0 |
| spiral-smooth.ppm | 0 |
| plate-07.ppm | 0 |
| drops.ppm | 0 |
| flower.ppm | 0 |
| plate-08.ppm | 0 |

Every chapter 7/8 render is byte-identical to its reference, not merely within the 1-byte budget.

## Catch-up

Ran chapters 1-6 alone first (feature files for 7/8 moved aside, then restored) to confirm nothing already
built was disturbed: 283/283 still pass, unchanged from before this session. Nothing was newly broken.

## Ambiguities

The biggest thing I had to guess, twice, was **how the picture-producing functions (`needles`, `soft_square`,
`star_exact`, `spiral_smooth`, `sunburst`/`plate_07`, `drops`, `flower`/`plate_08`) are actually built** — the
prose describes them in words ("needles() sets the same twelve thin triangles..."), gives pseudo-code for
`sunburst()`/`plate_07()` and `flower_at()`/`flower()`/`plate_08()`, but says nothing about exact canvas sizes,
magnification factors, or panel layout for `needles()`, `soft_square()`, `star_exact()`, `drops()`. I did not
guess blind: the chapter HTML embeds the *actual JavaScript that draws the figures* (`needlePath()`, `rays()`,
`sunburst()`, `teardrop()`, `petal()`, `flowerAt()`, `flower()`, the whole `accumulator`/`accumulate`/`resolve`
pipeline, and the full SVG `arc()` conversion), in a `<script>` block at the end of the chapter. That is legitimate
material — it's in the chapter file I was told to read, not in the forbidden `reference/impl/` — and it let me
reconstruct every render exactly (all diffs are 0, not just ≤ 1). Two things I still had to *infer* rather than
read off directly, because no JS function of the right name exists for them:

- `needles()`, `soft_square()`, `star_exact()`: none of these appear in the figure JS (only `needlePath()`
  does, used by `fig70` at native 60x60 for the HTML figure). I inferred from the scenario dimensions
  (`c.width = 480, c.height = 240` for `needles()`; `192 = 8*24` for `soft_square()`; `320x160` = two
  160x160 star panels for `star_exact()`) and the pixel probes that each is: fill at native low resolution,
  `magnify()` by the same integer factor the HTML figure uses for display, and (for `needles`/`drops`)
  `side_by_side` the two panels. This worked (diff 0), but it's a guess a differently-inclined reader
  could get wrong in a way no scenario would catch except the final `max_channel_difference` check — there's
  no scenario step that says "and it's magnified by 4" the way `plate_06`'s doc explicitly says "magnified
  by 2". Suggest either naming the magnification factor in prose (as the ch5/ch6 plates do) or adding a
  scenario field (e.g. `ink(needles()) = ...` or a probe at a coordinate that only makes sense at one specific
  scale) that pins the scale factor independently of the reference-image diff.
- `drops()`, by contrast, *is* spelled out in the figure JS (`function drops()`, using `teardrop()` and
  `flattenIntoPath` at two tolerances), so that one was a direct translation, not a guess.

Net: the embedded figure JS is doing a lot of the "every render pinned exactly" work that the CLAUDE.md
ground rule wants from `reference/impl/`, but it's inconsistent — some renders (`sunburst`, `teardrop`/`drops`,
`petal`/`flower`) have their generating function spelled out, others (`needles`, `soft_square`, `star_exact`)
only have a lower-level piece (`needlePath`) and I had to reconstruct the composition. A reader without my
willingness to reverse-engineer pixel bounding boxes from the raw reference PPM (which is what I did to confirm
the `needles()` panel layout before trusting it) would have a much harder time and could easily land on a
"close but not exact" render that still fails only the final image-diff scenario, with no earlier scenario to
tell them where they went wrong.

## Hard to translate

Nothing hard, mechanically — `test_runner.py`'s generic `eval`-based step matcher needed zero new step-pattern
code for either chapter; every new scenario reduced to `var ← expr`, `expr = expr [± tol]`, or a bare procedure
call, all already handled. The only addition to the runner itself was registering the new function names in
its `namespace` dict, plus `'none': None` (for `arc(...) = none`, chapter 8's degenerate-arc scenario) — `true`/
`false` were already mapped to Python booleans but nothing mapped `none`.

## Failures

None. Every scenario passed on the first full run after implementation (I did not need multiple rounds of
fixes against the reference PPMs — the embedded figure JS made the renders exact from the start). I want to
flag this as slightly suspicious from a "did I actually test anything" standpoint: it means my Python
implementation and the chapter's own reference JS agree closely enough that I can't distinguish "I implemented
the spec" from "I transcribed the reference." For the low-level accumulator/resolve/curve/arc math I did derive
the algorithm from prose + scenarios first and only cross-checked against the JS afterward (documented in my
own reasoning, not visible to you, but the derivation matched byte-for-byte), so I'm confident the *math* is
independently verified by the scenarios. The *render composition* (which canvas sizes, which magnification,
which colors) is more transcribed than derived, per the Ambiguities section above.

## Prose problems

- §7.1: "A deposit left of the buffer folds onto column 0, where it becomes all cover" is a little
  underspecified about the discarded `area` argument. The prose doesn't say explicitly that the incoming
  `area` value is *thrown away* and replaced by the incoming `cover` value (not merely that cover becomes
  cover, which sounds like a no-op) — you can only get this from the scenario numbers (`add_cell(acc, -2, 0,
  0.3, 0.7)` → `area_at = 0.7`, not `0.3` or `0.3+0.7` or `1.0`). One extra clause ("...both area and cover are
  set to the full cover value...") would remove the need to reverse-engineer from numbers.
- §7.3: the sign convention ("heading up the canvas carries a positive height") is stated as matching
  "chapter 5's winding number, cell for cell" — but chapter 5's `winding_at` and chapter 6's `edge_table`
  both give `+1` to an edge whose *second* point has the larger `y` (heading *down*, in `a→b` order), which is
  the *opposite* convention from chapter 7's `accumulate(a, b)` (`+1` when `a.y > b.y`, i.e. heading up in
  `a→b` order). I checked this by hand against `winding_at`'s actual code and it really is flipped relative to
  chapters 5/6's `direction` field. It happens not to matter for anything observable, because `apply_rule`
  only ever consumes `|w|` — see the mutation-testing note below, this is the exact case I checked for and it's
  an equivalent mutant precisely because of that `abs()`. But the claim "comes out as chapter 5's winding
  number, cell for cell" reads as a literal claim about matching signs, and it isn't true sign-for-sign; it's
  only true in magnitude/rule-outcome. Worth either softening the claim ("...the same winding number in
  magnitude...") or dropping the chapter-5 comparison, since it invites exactly the kind of cross-check I did
  that turns up a discrepancy in something that doesn't matter.
- §8.4, the arc trap: calls out two gotchas (radii too small, degrees-vs-radians) but not a third that's just
  as real in a from-scratch implementation: `acos(dot/length)` needs the argument clamped to `[-1, 1]` because
  floating-point rounding can push it a hair outside that range (this is exactly what `Math.acos` callers
  learn the hard way in every geometry codebase). I mutated my own implementation to drop the clamp
  (`math.acos(dot_ / length)` instead of `math.acos(max(-1.0, min(1.0, dot_ / length)))`) and **every single
  scenario still passed** — see Mutation results below. This is worth a scenario or at least a sentence in the
  trap, because right now nothing in the suite would catch a reader who skips the clamp, and it's a classic
  latent crash (`ValueError: math domain error` in Python, `NaN` silently in JS) waiting for a slightly
  different set of control points or a different reader's floating-point rounding to trigger it.
- §8.3 says flattening should happen "after the shape has been scaled to its final size, not before," which
  `flower_at`'s pseudocode enforces implicitly by calling `transform_curve` before `flatten_into_path`, but
  there's no scenario that would catch a reader who gets this backward (flattens first, then transforms the
  resulting polyline) — see Mutation results. The only thing that catches it is the full-image
  `max_channel_difference` diff on `flower()`/`plate_08()`, not any of the specific `ppm_pixel` probes. A
  scenario that specifically counts flattened points before vs. after a large scale-up (the way
  `chapter08-flatten.feature`'s "A tighter tolerance uses more points" already does for tolerance) would pin
  this more directly and explain *why* it matters, not just that the final picture looks wrong.

## Mutation results

I tried six plausible reader mistakes, reverting each before trying the next:

1. **Integer division in the area share** (`accumulate_row`'s `share = height * (hi - lo) / dx` changed to
   `//`): caught immediately and broadly — 9 scenarios fail across `chapter07-row`, `chapter07-fill`,
   `chapter07-plate`, `chapter08-plate` (curves compose fills too). Most direct catch: "A piece that spans
   several cells shares its height by width" (expects `0.1667`, integer division gives `0.0`).
2. **Wrong sign on the winding** (flipped `sign = 1.0 if a.y > b.y else -1.0` to its opposite, consistently):
   caught, but *only* by the 6 low-level `chapter07-walk.feature` scenarios that pin `accumulate()`'s literal
   `area_at`/`cover_at` sign for an isolated edge. Every fill/resolve/render scenario still passes — this is
   an equivalent mutant from the perspective of anything downstream of `apply_rule`, because both fill rules
   consume `abs(w)`. Confirms that `chapter07-walk.feature` is pulling weight no other file does, and that
   the chapter's claim of matching chapter 5's sign exactly is not actually testable end-to-end (see Prose
   problems above).
3. **`min`/clamp confusion for nonzero** (`min(1.0, abs(w))` → `max(0.0, min(1.0, w))`, i.e. clamping instead
   of taking the absolute value first): caught directly by `apply_rule(-0.25, "nonzero") = 0.25` (gives `0.0`
   instead), and *also* by `chapter08-plate.feature`'s `flower`/`plate_08` (petals cross with negative winding
   somewhere chapter 7's own renders apparently don't). Interesting that no chapter 7 render scenario caught
   it — only the low-level `apply_rule` scenario and chapter 8's renders did.
4. **Even-odd fold dropped** (`t if t <= 1.0 else 2.0 - t` reduced to just `t`, i.e. sawtooth instead of
   triangle wave): caught by 4 scenarios, both the direct `apply_rule(1.25, "evenodd") = 0.75` unit check and
   three render/ink scenarios in `chapter07-fill`/`chapter07-plate` (the star's even-odd ink and `star_exact`'s
   pixel/image diff).
5. **Missing `acos` clamp** (chapter 8's `angle_between`, dropped the `max(-1.0, min(1.0, ...))` guard before
   `math.acos`): **caught by nothing. All 338 scenarios still pass.** This is the "wrong implementation that
   still passes" finding — see Prose problems above for the suggested fix.
6. **Flatten-before-transform** (rewrote `flower_at` to flatten each petal curve in local/unit space first,
   then transform the resulting polyline points, instead of transforming the curve and flattening in device
   space): caught, but only by the whole-image `max_channel_difference` on `chapter08-plate.feature`'s "The
   flowers" and "Plate 8" (204 vs the ≤1 budget) — none of the specific `ppm_pixel` probes for `flower()`
   caught it, because they only check ink/hole presence at specific spots, not smoothness. This is exactly the
   "the fix arrives coarse-vs-fine as a whole-image effect" lesson §8.3 describes, so it's fitting that only
   the whole-image diff catches it — but it does mean a reader who breaks this exact thing and only checks
   the pixel probes (skipping the reference-image diff, e.g. because they don't have the reference PPM handy)
   would see every specific assertion pass.

I also checked the large_arc/sweep branch (flipped the `if not sweep and delta > 0` / `elif sweep and delta < 0`
condition pair): caught cleanly by 3 scenarios in `chapter08-arc.feature`, including the four-arcs-same-endpoints
scenario and the rotated-ellipse scenario. Not surprising, but confirms that feature earns its keep.

## Concrete changes I'd make

1. Add one sentence to §7.1 stating explicitly that a left-of-buffer deposit's `area` argument is discarded
   and replaced by `cover` (not merged with it), rather than leaving readers to infer this from the numbers.
2. Soften or drop the "comes out as chapter 5's winding number, cell for cell" claim in §7.3, or add a
   footnote noting the sign is chapter 7's own convention and only needs internal consistency, not agreement
   with chapters 5/6's `direction` field.
3. Add a sentence (or a scenario) to §8.4's trap about clamping `acos`'s argument to `[-1, 1]` — this is a
   real, silent latent bug (`ValueError`/`NaN`) that nothing in the current suite catches.
4. For `needles()`, `soft_square()`, and `star_exact()` in §7.6, either give the magnification factor and
   panel arrangement in prose (the way "spiral() is the 320 by 320 picture and plate_06() is it magnified by 2"
   already does for chapter 6) or add pseudo-code the way `sunburst()`/`flower()` already get. Right now these
   three are the only chapter 7/8 renders without either, and nothing but the final reference-image diff would
   tell a reader who guessed a different but plausible layout that they got it wrong.
5. Consider a scenario for chapter 8 that counts flattened-point totals for a curve flattened before vs.
   after a large scale transform, at the same nominal tolerance, mirroring the existing "tighter tolerance
   uses more points" scenario — this would pin the flatten-after-transform rule directly rather than relying
   on it only showing up as an image-diff failure.

## Timing

Roughly: 20 minutes reading chapter 7 (HTML + all `.feature` files, including working out the analytic-coverage
algorithm by hand against every scenario's numbers before writing code), 25 minutes implementing and wiring
chapter 7 into `renderer.py`/`test_runner.py`, 20 minutes reading chapter 8 and its feature files plus locating
and reading the embedded figure JS (which required grepping for `<script>` blocks and re-reading the raw HTML
since the naive HTML-to-text stripping mangled `<`/`>` comparison operators inside `<script>` tags), 25 minutes
implementing chapter 8, 10 minutes generating and diffing all renders, 20 minutes on mutation testing (6
mutations, reverting between each), 10 minutes on README/FEEDBACK. Total: a little over two hours.
