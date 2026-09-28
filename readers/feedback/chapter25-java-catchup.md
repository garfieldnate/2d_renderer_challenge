# Catch-up pass: chapters 24-25

## What changed in features/ since this code was written

- `chapter24-plate.feature` prose now calls the plate helper `centred_star()`
  (renamed in the book from `plate_star()`, which clashed with chapter 22's
  own `plate_star()`). No Gherkin *step* calls it directly (it's only used
  inside `plate_24()`/`msaa_demo()` etc.), so this was a rename-for-consistency,
  not a test failure -- but the reader's own `Chapter24Figures.plateStar()`
  was renamed to `centredStar()` to match, since Java's per-class namespacing
  never actually clashed with `Figures.plateStar()` (chapter 22's), unlike the
  book's flat runner namespace.
- `chapter24-shader.feature`'s gradient scenario already passed `"pad"` as
  the extend mode and the existing code already handled it correctly --
  nothing to fix there.
- `chapter25-brush.feature` gained "Opacity caps the stroke however often it
  crosses itself" -- missing from `Chapter25Tests.java` entirely. The
  production code (`Brushes.paintStroke`) already applied opacity by scaling
  the accumulated mask *after* buildup (not per-dab), which is exactly what
  caps a self-crossing stroke at `opacity` however many times it re-visits a
  pixel; only the test scenario was missing. Added it: it passed against the
  existing implementation unchanged.
- `chapter25-quantize.feature` gained two scenarios: "Median cut's ties" and
  "Three inks". Both were missing from `Chapter25Tests.java`. Traced through
  `Quantize.medianCut` by hand against the tie-break rules in the feature's
  prose (widest-channel box picked earliest on a tie, red-before-green-
  before-blue channel picked earliest on a tie): the existing code already
  implements both correctly via a strict `>` comparison (never `>=`), which
  naturally keeps the earliest index on a tie. `threshold`/`error_diffuse`
  were already palette-size-generic (not hardcoded to two entries), so the
  three-ink scenario needed no code change either -- just the missing test.

## What failed on the existing code, and why

Nothing failed once added -- every new/changed scenario turned out to be a
missing test against already-correct production code. No production bugs
found this pass.

## What was changed

- `src/Chapter24Figures.java`: renamed `plateStar()` -> `centredStar()`
  (doc comment updated too), including its one internal call site in
  `plate24()`.
- `src/Chapter25Tests.java`: added three scenarios to match the feature
  files exactly:
  - `Brush: opacity caps the stroke however often it crosses itself`
  - `Quantize: median cut's ties`
  - `Quantize: three inks`

No other source files needed changes.

## Final counts

- Chapter 24: 22/22 passing (unchanged count; only the plate-helper rename).
- Chapter 25: 28/28 passing (was 25; +3 new scenarios).
- Full suite (chapters 1-25), run from this directory: all green, 876
  scenarios total (`Total: 66/35/38/76/33/36/34/25/46/25/18/13/23/27/28/23/22/21/31/86/22/54/43/22/28`
  for chapters 1-25 respectively).
