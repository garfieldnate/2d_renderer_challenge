# Chapter 16-17 catch-up (Java) — FEEDBACK

## Result

Full suite, chapters 1-17, run from this directory:

| Chapter | Scenarios | Pass | Fail |
|---|---|---|---|
| 1  | 66 | 66 | 0 |
| 2  | 35 | 35 | 0 |
| 3  | 38 | 38 | 0 |
| 4  | 76 | 76 | 0 |
| 5  | 32 | 32 | 0 |
| 6  | 34 | 34 | 0 |
| 7  | 34 | 34 | 0 |
| 8  | 23 | 23 | 0 |
| 9  | 45 | 45 | 0 |
| 10 | 24 | 24 | 0 |
| 11 | 17 | 17 | 0 |
| 12 | 13 | 13 | 0 |
| 13 | 22 | 22 | 0 |
| 14 | 27 | 27 | 0 |
| 15 | 28 | 28 | 0 |
| 16 | 23 | 23 | 0 |
| 17 | 20 | 20 | 0 |

Total 557 scenarios, all green.

`max_channel_difference` for every chapter 16-17 render, `out/*.ppm` vs `reference/**/*.ppm`: all **0** (byte-exact) — `glyph.ppm`, `plate-16.ppm`, `composite.ppm`, `sizes.ppm`, `flip.ppm`, `subpixels.ppm`, `smoothing.ppm`, `lcd.ppm`, `plate-17.ppm`.

## Catch-up

Went through every `features/chapter16-*.feature` and `features/chapter17-*.feature` line by line against `src/Chapter16Tests.java`/`Chapter17Tests.java`. Three real deltas, all fixed:

1. **`chapter16-composites.feature`'s hand-written font, boolean on-curve flags.** The feature's last scenario now writes the bump glyph's contour as `[[0, 0, true], [100, 200, false], [200, 0, true]]` (JSON booleans), where the Java test's literal string still had `[[0, 0, 1], [100, 200, 0], [200, 0, 1]]` (numeric 0/1). This did **not** fail before the fix — `Json.asBoolean` already accepted both `Boolean` and `Double` (0/1), a deliberate hedge the code already had (see its own comment). But the test was no longer a faithful transcription of the feature, so a reader translating cold from the feature file into another language would produce different literal JSON than what this suite exercised. Fixed by changing the Java string literal to `true`/`false` to match the feature exactly. Suite still green after the change (as expected, since the parser already handled it) — this was a fidelity fix, not a bug fix.

2. **`chapter17-plate.feature`, new scenario "draw_text steps the pen by each advance and answers where it stopped".** This scenario did not exist in `Chapter17Tests.java` at all — it's new. It calls `draw_text(canvas, font, "Ha", 11, 2, 11, color(0, 0, 0), true)` directly and asserts the returned pen position (`15.8252 ± 0.0001`) plus two pixels. The Java code had a `drawText` helper in `Figures.java`, but it was `private`, used only internally by `smoothingDemo()`/etc., and never called from a test. **This would have failed to compile as a scenario** because nothing outside `Figures` could call it. Fix: made `Figures.drawText` `public` (no logic change — it already returned the pen's final position) and added the scenario to `Chapter17Tests.registerPlate()`. Passes: pen advances to `15.8252`, matching `2 + pen_advance(font,"H",11) + pen_advance(font,"a",11)`, and the two pinned pixels match.

3. **`chapter-17.html` §17.2 now prints pseudo-code for `atlas_add`.** Comparing it line by line against `Atlas.java`'s `add()` turned up a real algorithm mismatch, not just a doc gap: the printed pseudo-code opens a new shelf **only** when the bitmap doesn't fit to the right (width check); a bitmap that fits width-wise but is taller than everything already on the shelf stays on that shelf, and the shelf just grows (`shelf_h ← max(bitmap.height, shelf_h)`). The old Java code instead forced *any* bitmap taller than the current `shelfHeight` onto a brand new shelf, even when it fit fine width-wise. None of the four scenarios in `chapter17-cache.feature` happens to probe that exact case (in the "shelf packing" scenario, the bitmap that doesn't fit the first shelf also doesn't fit width-wise, so the two algorithms agree there by coincidence), so **the suite was green both before and after** this fix — it's exactly the kind of latent bug CLAUDE.md's playbook is written to catch when a future scenario does probe it. Rewrote `Atlas.add()` to match the pseudo-code's control flow exactly (including its odd-but-deliberate quirk of committing the shelf shift *before* checking whether the new shelf has room, so a failed placement can still leave the atlas primed for the next item at the new shelf's y — this quirk **is** covered by the existing scenario, via the 30×20 rectangle). Verified all seven `atlas_add` assertions and both real-glyph-atlas scenarios still pass, worked the four-rectangle sequence by hand against both the old and new code to confirm they coincide on every scenario value, and reran the whole suite.

Also checked, found already consistent (no changes needed):
- `features/chapter17-plate.feature`'s new prose describing `subpixel_strip()`, `smoothing_demo()`, `lcd_plate()`, `plate_17()` exact geometry — `Figures.java`'s implementations already matched it (they were reverse-engineered from the chapter's figure JS in an earlier round, per this repo's own README history, and that JS was the same source the prose now documents).
- `features/chapter16-plate.feature`'s new prose stating `composite_demo()`/`sizes()`/`flip_trap()`'s exact geometry (canvas sizes, origins, text_matrix use, ink assignment, hairline widths) — already matched byte-for-byte in `Figures.java`.
- The real `roboto.json` reference font already stores on-curve flags as JSON booleans (`true`/`false`), confirmed with a raw grep of the file, so no parser change was needed there.

## Ambiguities

None new this round. The one open ambiguity from the original chapter 16/17 authoring — `composite_demo()`/`sizes()`/`flip_trap()`'s exact geometry not being pinned by pseudo-code, only by prose — is resolved as of this feature-file update: the `Feature:` descriptions now state canvas sizes, origins, sizes, and ink order explicitly, so a cold reader no longer needs the chapter's figure JS as a secondary source. Worth confirming the prose stayed in sync if `chapter16-plate.feature` changes again.

## Failures

None. Every scenario in every `features/chapter16-*.feature` and `features/chapter17-*.feature` file passes, chapters 1-15 unaffected (their suites still pass, unchanged), and all nine chapter 16/17 renders are byte-identical to their references.

## Prose problems

- `chapter-17.html` §17.2's pseudo-code for `atlas_add` is a good example of the "iron rule" doing its job even without a new failing scenario: writing it down surfaced a real divergence between two implementations that happened to agree on every value the current feature file checks. If a future scenario for chapter 17 wants to probe "a bitmap taller than the shelf but narrower than the remaining width," it would have caught this on its own; recommend adding one, since right now the only thing that caught it was manually reading the pseudo-code against the Java line by line. A scenario like: an atlas where a first bitmap is (10, 5), then a second bitmap (5, 8) is added (fits width-wise: 10+5=15 ≤ atlas width, but is taller than shelf_h=5) — expected placement (10, 0), not a new shelf at (0, 5) — would pin this exactly and is a one-line addition to the existing "Shelf packing" scenario's table.
- No other prose problems found this pass; the added descriptive sentences in `chapter16-plate.feature` and `chapter17-plate.feature` read as unambiguous and matched the existing (already-correct) implementation exactly.

## Concrete changes

Files touched:
- `src/Chapter16Tests.java` — hand-written font JSON literal changed from `[0, 0, 1]`/`[100, 200, 0]`/`[200, 0, 1]` style flags to `true`/`false`, to match `chapter16-composites.feature` verbatim.
- `src/Figures.java` — `drawText` changed from `private` to `public` (no behavior change) so it's callable from `Chapter17Tests` per the new scenario.
- `src/Chapter17Tests.java` — added the scenario "Plate 17: draw_text steps the pen by each advance and answers where it stopped" to `registerPlate()`, calling `Figures.drawText` directly and asserting the returned pen position and two pixels exactly as the feature file states.
- `src/Atlas.java` — rewrote `add()` to match `chapter-17.html` §17.2's printed pseudo-code exactly (a bitmap that fits width-wise no longer gets bumped to a new shelf just for being taller than what's already there; the shelf grows instead). All existing scenario values unaffected — verified by hand and by rerunning the suite.
- `README.md` — updated the Chapter 16 paragraph about `composite_demo`/`sizes`/`flip_trap` (their geometry is now pinned by the feature file's own prose, not only the chapter's figure JS), the Chapter 17 paragraph describing `Atlas.add`'s algorithm (to match the corrected pseudo-code-following implementation), and the paragraph about `drawText` (now public, called directly by a scenario, no longer just an internal helper "never named as something a scenario calls directly").

No new dependencies, no network use, no files touched outside this directory.
