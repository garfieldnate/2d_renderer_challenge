# Chapter 24-25 catch-up (second pass)

## What changed in features/

- `chapter25-brush.feature`: new scenario "Opacity caps the stroke however
  often it crosses itself".
- `chapter25-quantize.feature`: new scenario "Median cut's ties" (widest-channel
  tie -> red before green before blue; box-selection tie -> earliest box), and
  a new "Three inks" scenario for `threshold`/`error_diffuse` against a
  three-entry palette.
- `chapter24-shader.feature`: the gradient scenario now passes `radial_gradient`'s
  sixth argument explicitly as `"pad"` instead of relying on the default.
- `chapter24-plate.feature`: prose renamed the star helper from `plate_star()`
  to `centred_star()` (it clashes with chapter 22's `plate_star()` in this
  runner's flat namespace). Not a runnable step in any scenario, since
  `plate_24()` is the only entry point actually called.

Total scenario count: 876 -> 879 (chapter 25: 25 -> 28).

## What failed on the existing code

Nothing. All three new scenarios passed unmodified:

- The brush's `paint_stroke` already built up `stroke_mask`'s flow-based
  coverage across overlapping dabs first, then multiplied the whole mask by
  `opacity` once at the end — the crossing-stroke scenario needs exactly that
  order (opacity folded per-dab would cap below 0.5 wherever the stroke
  overlaps itself more than once).
- `median_cut`'s channel-tie check was already `if wr >= wg and wr >= wb: red
  elif wg >= wb: green else: blue`, so a red/green width tie already picks
  red, matching the new scenario.
- The box-selection loop already used `if w > best_width` (strict), so a
  tie between two boxes' widest-channel widths already keeps whichever box
  was found first (the earliest one), matching the new scenario.
- `radial_gradient(..., "pad")` already worked since the first catch-up
  pass gave it a `mode="pad"` default; passing it explicitly is a no-op.

## What was changed

Cosmetic only, to track the book's rename: `renderer.py`'s private
`_ch24_plate_star()` is now the public `centred_star()` (docstring updated,
its one call site in `plate_24()` updated, `plate_24()`'s own docstring
updated to say `centred_star()`). No behavior change; no scenario depends on
the name since it was never called from a step.

## Final counts

879/879 scenarios pass (`python3 test_runner.py`, ~11.5 minutes on this
machine). All chapter 2-25 renders remain byte-exact against `reference/`
(`max_channel_difference` 0), including all four chapter 24 renders and all
five chapter 25 renders re-checked by `chapter24-plate.feature` and
`chapter25-plate.feature`'s own scenarios.
