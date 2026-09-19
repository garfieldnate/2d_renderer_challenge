# Chapter 16-17 catch-up (Python)

## Result

- `python3 test_runner.py`: **564 scenarios, 564 passed, 0 failed** (up from 561/564 before this
  pass — three chapter 16 plate scenarios were failing on the glyph plate's whole-image diff).
- Every chapter 16 and 17 render, freshly generated to `out/chapter-16/` and `out/chapter-17/`,
  diffs `max_channel_difference` **0** against `reference/`:
  - `glyph.ppm`: 0 (was 29)
  - `plate-16.ppm`: 0 (was 29)
  - `composite.ppm`: 0 (already 0)
  - `sizes.ppm`: 0 (already 0)
  - `flip.ppm`: 0 (was 37)
  - `subpixels.ppm`, `smoothing.ppm`, `lcd.ppm`, `plate-17.ppm`: 0 (already 0, chapter 17
    untouched by this pass)

## Catch-up

§16.5's prose now states the exact geometry, inks and hairline definition for `glyph_plate`,
`composite_demo`, `sizes` and `flip_trap`. Before this pass those four functions existed but were
reverse-engineered from the reference PPMs (the previous round's README said so explicitly), and
three of the five renders they produce didn't quite land:

- **`glyph_plate()` / `plate_16()`** (`chapter16-plate.feature`, "The glyph and its control
  points" / "Plate 16"): failed before (`max_channel_difference` 29). Two bugs in the
  reverse-engineered code:
  1. The control-polygon hairline used a guessed color `color(0.28, 0.28, 0.32)` and joined
     segments with `"miter"`. §16.5 pins the color as `dim = color(0.3, 0.3, 0.34)` and a
     hairline as "chapter 14's: the path stroked with butt caps and **round** joins, filled
     nonzero" — the join kind matters visibly at the polygon's sharp corners near the spine of
     the *a*, which is exactly where the diff piled up.
  2. The on-curve squares were painted with `INKS[1] = color(0.2, 0.55, 0.85)` (a blue borrowed
     from the chapter's component-ink palette) instead of the newly-named
     `cyan = color(0.2, 0.75, 0.9)`.
  Fix: added module constants `_GLYPH_CYAN = color(0.2, 0.75, 0.9)` and
  `_GLYPH_DIM = color(0.3, 0.3, 0.34)` in `renderer.py`, and changed the control-polygon stroke
  call from `("butt", "miter")` to `("butt", "round")`.
- **`flip_trap()`** (`chapter16-plate.feature`, "The flip, forgotten"): failed before
  (`max_channel_difference` 37). Two bugs:
  1. The baseline guide was a filled 2-pixel-tall rectangle (`baseline_y - 1` to `baseline_y +
     1`) in a guessed color `color(0.16, 0.16, 0.18)`, painted *before* the glyph. §16.5 says
     "each with a dim hairline along y = 60" — a 1-wide hairline stroke (chapter 14's
     stroke_to_path, butt/round, filled nonzero) in `dim`, and the reference draws it *after* the
     glyph so it sits on top where the two overlap (the glyph's descender crosses the baseline in
     the right-hand "forgotten flip" panel).
  2. Ordering: painting the rectangle first and the glyph second gives a different blended result
     at the overlap than painting the glyph first and the hairline second, since neither shape has
     full coverage everywhere they touch.
  Fix: rewrote `_flip_trap_panel` to fill the glyph first, then stroke the 1-wide `dim` hairline
  from `(0, baseline_y)` to `(w, baseline_y)` (open, not closed) over it, matching the reference
  byte for byte.
- **`chapter17-cache.feature`** gained two scenarios ("A taller bitmap that fits the width stays
  on the shelf and raises it"; "A bitmap the atlas can never hold leaves the shelf alone"): both
  **already passed** against the existing `atlas_add`. The existing implementation's room check
  (`at.shelf_y + h > at.height`, using only the incoming bitmap's height) is mathematically
  equivalent to the newly-printed pseudocode's `shelf_y + max(bitmap.height, shelf_h) >
  atlas.height`, given the loop invariant that `shelf_y + shelf_height <= atlas.height` always
  holds after a successful placement (when `h > shelf_h`, `max(h, shelf_h) = h` so the two checks
  agree; when `h <= shelf_h`, the invariant makes the simpler check trivially true, agreeing with
  the pseudocode's `false`). No code change needed; verified by inspection and by the passing
  scenarios.
- **`chapter16-composites.feature`**'s JSON-boolean hand-written font scenario ("Bounds are tight,
  not the control box...") already passed — `load_font` uses `json.loads`, which already maps
  JSON `true`/`false` to Python `True`/`False`, so no on/off-curve flag handling needed changing.
- **`chapter17-plate.feature`**'s pinned `draw_text` return value ("draw_text steps the pen by
  each advance and answers where it stopped") already passed — the existing `draw_text` already
  returned the pen's final x position.
- Renamed scenarios in `chapter16-composites.feature` required no code changes (renames don't
  change behavior); confirmed by name against the current feature file and by the full suite
  passing.

Net: this catch-up pass was almost entirely the chapter16-plate.feature fix; the chapter 17 atlas
scenarios and the chapter 16 composites/JSON-boolean items were catching up code that was already
correct.

## Ambiguities

None outstanding. The three previously-ambiguous renders (`glyph_plate`, `flip_trap`, and by
extension `plate_16`) are now fully specified by §16.5's prose (inks named, hairline defined,
canvas/origin/baseline stated for every render) and the feature file's header paragraph restates
the same facts, so there was nothing left to infer.

## Failures

None. 564/564 scenarios pass; every chapter 16-17 render is byte-exact.

## Prose problems

None found in this pass — §16.5 reads as a complete spec now. One thing worth double-checking
editorially: the prose says "hairline through every point of the contour, taken through m, closed,
in dim // width 1, butt caps, round joins" in the `glyph_plate` pseudocode, and separately the
feature file's header repeats "A hairline is chapter 14's: the path stroked with butt caps and
round joins, filled nonzero, 1 wide unless said otherwise." Both are consistent and non-redundant
(the pseudocode comment is a convenience for the reader following along; the feature header is the
formal pin), so this isn't a problem, just worth noting it was checked.

## Concrete changes

All in `renderer.py`, chapter 16 renders section:

1. Replaced `_GLYPH_CYAN = INKS[1]` with `_GLYPH_CYAN = color(0.2, 0.75, 0.9)` (the chapter's
   newly-named `cyan`).
2. Replaced `_GLYPH_HAIRLINE = color(0.28, 0.28, 0.32)` with `_GLYPH_DIM = color(0.3, 0.3, 0.34)`
   (the chapter's newly-named `dim`), and renamed its uses accordingly.
3. In `glyph_plate()`, changed the control-polygon hairline stroke's join from `"miter"` to
   `"round"`.
4. In `flip_trap()` / `_flip_trap_panel()`, replaced the filled 2px baseline rectangle
   (`color(0.16, 0.16, 0.18)`, drawn before the glyph) with a proper 1-wide hairline stroke
   (`_GLYPH_DIM`, butt caps, round joins, open polyline from `(0, baseline_y)` to `(w,
   baseline_y)`) drawn *after* the glyph fill, matching draw order and geometry to §16.5.
5. Updated `README.md`'s "Run Tests" paragraph (564/564 passing, all chapter 16/17 renders
   byte-exact, no more residual mismatches) and its chapter 16 implementation note (named colors
   instead of "reverse-engineered", removed the now-stale claim that `composite_demo`/`sizes`/
   `flip_trap` have no pseudocode/spec — they do now, in §16.5).

No dependency, test, or reference file changes; no scenario needed a code change beyond the four
`glyph_plate`/`flip_trap` fixes above.
