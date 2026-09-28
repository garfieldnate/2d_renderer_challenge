# Catch-up pass: chapters 24-25

## What changed in features/ since this code was written

- `chapter24-plate.feature`'s prose now names the plate's moved star
  `centred_star()` (it was `plate_star_24()` in the code — the old name
  avoided colliding with chapter 22's `plate_star`, but the book settled on
  `centred_star` instead). No scenario calls it by name directly (it's only
  used internally by `plate_24()`), so this was a rename with no behavior
  change: `src/lib.rs`'s `plate_star_24` → `centred_star`, doc comment
  updated to match.
- `chapter25-brush.feature` gained a new scenario, "Opacity caps the stroke
  however often it crosses itself": a four-point stroke that doubles back on
  itself, brush opacity 0.5, must read exactly 0.5 coverage where it
  overlaps, not more.
- `chapter25-quantize.feature` gained two new scenarios: "Median cut's ties"
  (the widest-channel tie picks the earliest box; a channel-width tie picks
  red before green before blue) and "Three inks" (`threshold`/`error_diffuse`
  against a three-entry grayscale palette, not just black/white).
- `chapter24-shader.feature`'s existing scenario already passed `"pad"` as
  the radial gradient's extend mode in both the feature and the existing
  test — no drift there.
- Every other chapter 24/25 feature file (`loopblinn`, `msaa`, `pipeline`,
  `stencil`, `unhappy`, `flood`, `plate25`, `select`) matched its test file
  scenario-for-scenario; nothing else was missing or changed.

## What failed on the existing code and why

Nothing failed. `median_cut`'s tie-break logic (earliest box on a width tie,
red-before-green-before-blue on a channel-width tie) and `threshold`/
`error_diffuse`'s general N-entry palette support were already correct —
hand-traced both new median-cut cases against the algorithm before adding
the tests, and they land exactly on `[(0, 10, 0), (10, 0, 0)]` and
`[(0, 0, 0), (10, 0, 0), (105, 0, 0)]`. `paint_stroke`'s opacity is already
applied to the whole accumulated mask after `stroke_mask` builds it, not
folded into each dab, so the self-crossing stroke already capped at exactly
0.5 coverage. The only actual code change was the `centred_star` rename,
which is cosmetic (no test called the old name, so nothing could have
failed on it, but it kept the code in sync with the chapter prose).

## What I changed

- `src/lib.rs`: renamed `plate_star_24` → `centred_star` (3 occurrences: the
  function, its doc comment, and its one call site in `plate_24`).
- `tests/quantize25.rs`: added `median_cuts_ties` and `three_inks`.
- `tests/brush25.rs`: added `opacity_caps_the_stroke_however_often_it_crosses_itself`,
  and imported `canvas`, `color`, `fill`, `paint_stroke`, `pixel_at`.

## Final counts

`cargo test --release --offline`: 834 passed, 0 failed, across all test
binaries (chapters 1-25). No warnings.
