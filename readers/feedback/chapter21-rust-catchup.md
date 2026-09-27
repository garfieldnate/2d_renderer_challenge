# Catch-up pass: chapter08-flatten, chapter20-*, chapter21-*

Compared every scenario in `features/chapter08-flatten.feature`, all twelve
`features/chapter20-*.feature` files, and all six `features/chapter21-*.feature`
files against the tests already in `tests/`. Added or extended a test for
every scenario or assertion that was missing, ran the whole suite, and fixed
the one real bug that turned up. Full suite: `cargo test --release --offline`
— 700 tests pass, 0 fail (up from 690 before this pass; 10 new/extended test
functions, one of which caught a genuine bug).

## New/changed scenarios found, and what happened on the old code

- **chapter08-flatten**: two scenarios about `flatten_into_path` joining
  curves without repeating a point, and starting a new subpath after
  `close`, had no tests at all. Added both. **Passed immediately** — the
  existing `flatten_into_path` already implements the no-repeat/line-join/
  new-subpath-after-close rule correctly.

- **chapter20-building**: "Curves are flattened after the transform" gained
  two more cases (a cubic and an arc, both at 10x scale) beyond the original
  quadratic — this is the scenario that catches "flatten before transform"
  bugs the pinned quadratic-only version couldn't. Also "An arc in a path
  ends exactly at its end point" gained a direct `arc_cubics(...)[0].points[3]`
  check. Added both. **Passed immediately** — `build_path`'s C/Q/A branches
  already transform the curve before flattening.

- **chapter20-groups**: new scenario "A clip's shapes take their style from
  the clipPath" (a clip-rule set on the `clipPath` element itself, inherited
  by a child `path` with no clip-rule of its own). Added it. **Passed
  immediately** — `clip_coverage` already computes each clip child's style
  starting from `computed_style(cp, &initial_style())`, not from
  `initial_style()` directly.

- **chapter20-paint** — **real bug, now fixed**: new final assertion in
  "When there's nothing to paint with, and when there's one colour":
  `paint_at(paint_server(root, "url(#one)", (0, 0, 10, 0), identity()), 0, 0)
  = color(1, 0, 0)`, i.e. a *single-stop* gradient must resolve to a solid
  paint even when the bbox has zero width/height. Old code checked
  "objectBoundingBox gradient meets a zero-size box → None" *before*
  checking "one stop → solid", so a single-stop gradient on an empty box
  wrongly returned `None` (test panicked on `.unwrap()`). Fixed by moving
  the `stops.len() == 1` short-circuit in `paint_server` (src/lib.rs) ahead
  of the bbox-size check, since a solid paint never needs the bbox matrix
  at all. Two-stop-plus gradients on a zero-size box still correctly return
  `None`.

- **chapter20-style**: whole new scenario "Opacities are clamped, a miter
  limit below 1 is ignored, and so is anything that doesn't parse". Added
  it. **Passed immediately** — `apply_property` already clamps
  `opacity`/`fill-opacity`/`stroke-opacity` to `[0, 1]` and rejects a
  `stroke-miterlimit` below 1 and an unparseable `stroke-width`.

- **chapter20-transform**: new case in "Nothing, or anything broken, is the
  identity": `parse_transform("translate(1 2 x)") = identity()` (junk
  trailing a valid-looking number list). Added it. **Passed immediately**.

- **chapter20-viewbox**: the "none stretches each axis on its own" scenario
  gained a second assertion (`view_box_matrix("10 20 60 80", "none", 120,
  90) * point(10, 20) = point(0, 0)`, i.e. the origin still translates even
  under `none`). Added it. **Passed immediately**. Also confirmed
  `aspect_demo()` (Figure 20.4, formerly noted in this README as
  "only defined by the chapter's figure code") is now fully pinned by "One
  drawing, five ways to fit it" and renders byte-identical to
  `reference/chapter-20/aspect_demo.ppm` — that old ambiguity note is moot.

- **chapter20-walker**: whole new scenario "The dash offset moves the
  pattern along the path" (`stroke-dashoffset` on a walker-drawn line, no
  transform). Added it. **Passed immediately**.

- **chapter21-spans**: whole new scenario "A solid tile cut short by the
  canvas copies only the pixels on the canvas" (a tile straddling the
  canvas edge must not be counted/copied as a full 256-pixel solid tile).
  Added it. **Passed immediately** — `draw_tiled`'s per-tile fill/copy
  already clips to the canvas before counting.

- **chapter21-tiles**: "A horizontal edge makes a tile partial..." gained
  two `coverage_in` checks on `fill_path_tiled` output (spot-checking a
  solid pixel and an empty one). Added them. **Passed immediately**.

## Files checked and found already complete (no changes needed)

chapter20-document, chapter20-numbers, chapter20-pathdata, chapter20-plate,
chapter20-shapes, chapter21-bounds, chapter21-counting, chapter21-plate,
chapter21-simd.

## Ambiguities

None found this round — every new/changed scenario's wording matched a
single, unambiguous reading, and all but one (the `paint_server` empty-box
bug) already agreed with the reference implementation's behavior.

## Renders

Re-ran `cargo run --release --offline --bin render_all` and diffed `out/*.ppm`
against `reference/` byte for byte (max over all channels of all pixels):

| render        | max_channel_difference |
|---------------|------------------------:|
| aspect_demo   | 0 |
| harbor        | 0 |
| rose          | 0 |
| tiger         | 0 |
| work_map      | 0 |

All five are byte-identical to reference; no change from before this pass
(the one bug fixed — the empty-box single-stop gradient — never fires in
any of the five documents).

## Final counts

- `cargo test --release --offline`: **700 passed, 0 failed** (was 690 before
  this catch-up; +10 test functions/assertions added, all now green).
- `./` had no `run_features.py`/`sync_features.py` to run in this scratch
  copy (those live in the book's own repository, out of scope here);
  verification was cargo's test runner only, per this reader's own
  `README.md`.

No README.md counts needed updating — it doesn't state a total scenario or
test count anywhere; the per-chapter prose notes are still accurate except
the now-resolved aspect_demo ambiguity mentioned above.
