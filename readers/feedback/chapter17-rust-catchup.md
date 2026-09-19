# Rust reader — chapter 16/17 catch-up feedback

## Result

- `cargo test --release`: 523 scenarios green, 0 failed, across 90 `tests/*.rs`
  files (one per `features/*.feature` file, Scenario Outlines expanded per
  row) plus a 0-test doctest crate. Clean `cargo build --release` after
  `touch src/lib.rs`, no warnings.
- `cargo run --release --bin render_all` then compared every chapter 16/17
  render in `out/` against `reference/chapter-{16,17}/` with
  `max_channel_difference` (via a throwaway test, removed before finishing):

  | render | max_channel_difference |
  |---|---|
  | glyph.ppm | 0 |
  | plate-16.ppm | 0 |
  | composite.ppm | 0 |
  | sizes.ppm | 0 |
  | flip.ppm | 0 |
  | subpixels.ppm | 0 |
  | smoothing.ppm | 0 |
  | lcd.ppm | 0 |
  | plate-17.ppm | 0 |

  Every chapter 16/17 render is byte-exact against the reference, not merely
  within the ± 1 budget the scenarios ask for.

## Catch-up

Compared every `features/chapter16-*.feature` and `features/chapter17-*.feature`
file against its `tests/*.rs` line by line (not just the two flagged files),
by diffing content and by cross-checking `Scenario` counts against `#[test]`
counts for every chapter-16/17 test file. Found exactly the two changes the
task description named, nothing else:

1. **`chapter16-composites.feature`, "A font can be written by hand..."**
   The hand-written font JSON in the scenario now writes the on-curve flag
   as `true`/`false` instead of `1`/`0`. `tests/composites16.rs` still had
   the old `1`/`0` literals. This did **not** fail on the old code —
   `Json::as_flag` in `src/lib.rs` already accepted both a JSON boolean and
   a 0/1 number (a decision made when the numeric form was still live in
   the feature file), so the stale test string still parsed and passed.
   Fixed by updating the JSON literal in the test to match the current
   scenario text exactly (`[0, 0, true], [100, 200, false], [200, 0, true]`).
   No production code changed. Left the numeric fallback in `as_flag` in
   place (harmless, but now dead as far as `features/` goes — see
   Ambiguities) and corrected its doc comment plus the README paragraph
   that described the old dual-format rationale, since both were now wrong
   about which literal the scenario uses.

2. **`chapter17-plate.feature`, new scenario "draw_text steps the pen by
   each advance and answers where it stopped"**. This scenario did not
   exist in `tests/plate17.rs` at all — it's new, not a changed value.
   Added `draw_text_steps_the_pen_by_each_advance_and_answers_where_it_stopped`
   to `tests/plate17.rs`: fills a white 30×14 canvas, calls
   `draw_text(&mut c, &f, "Ha", 11.0, 2.0, 11.0, black, true)`, and checks
   the returned pen position against `15.8252 ± 0.0001` and against
   `2.0 + pen_advance(H) + pen_advance(a)`, plus `pixel_at(c, 3, 6)` and
   `pixel_at(c, 29, 6)`. `draw_text` already returned the right value (it
   already returned `pen: f64`, matching the API) — the function itself
   needed no change, only the missing test. Passes as written.

3. **`chapter16-plate.feature` description now states `composite_demo`'s,
   `sizes`'s and `flip_trap`'s exact geometry** (sizes, origins, inks). No
   scenario text or pinned value changed, so no test changed. Re-verified
   by rendering and diffing all four renders at 0 — the implementation
   already matches the now-explicit geometry.

4. **`chapter-17.html` §17.2 now prints pseudo-code for `atlas_add`**. No
   feature/scenario text changed (`chapter17-cache.feature`'s four
   scenarios and their values are unchanged), so no test changed. Compared
   the printed pseudo-code against `src/lib.rs`'s `atlas_add` anyway, since
   this is exactly the kind of case CLAUDE.md's own history flags ("a
   scenario must be able to fail on the mistake it exists for") — see
   Ambiguities below for what that comparison turned up.

Nothing else in chapters 1-17 had drifted: every other `tests/*.rs` file's
`Scenario`/`#[test]` count matched its feature file, and spot-diffing the
chapter-16/17 files not named in the task (`chapter16-contours`,
`chapter16-font`, `chapter16-path`, `chapter17-bitmap`, `chapter17-cache`,
`chapter17-fudge`, `chapter17-lcd`) against their tests line by line found
no other drift.

## Ambiguities

- **`atlas_add`'s printed pseudo-code and this implementation diverge on
  one failure path, silently.** The pseudo-code checks
  `bitmap.width > atlas.width or bitmap.height > atlas.height` *before*
  touching shelf state, so a definitely-too-wide bitmap arriving on a
  non-empty shelf returns `none` leaving the current shelf untouched. This
  Rust `atlas_add` instead tries to fit the bitmap on the current shelf
  first; on failure it always closes that shelf and opens a new (empty)
  one, *then* discovers on the next loop iteration that the bitmap is
  still too wide for the atlas and returns `None` — leaving a shelf closed
  that the pseudo-code would have left open. For the scenario's own seven
  calls the two algorithms happen to land on the same shelf position
  afterward (traced by hand; see `README.md`'s chapter 17 notes), so no
  current scenario catches the difference. But nothing in
  `chapter17-cache.feature` pins the atlas's internal shelf state after a
  failed `atlas_add`, or calls `atlas_add` again afterward to observe where
  the *next* bitmap lands — so a scenario with different atlas dimensions
  could expose it. This is worth either a scenario that adds one more
  bitmap after a too-wide failure and checks where it lands, or a prose
  note that shelf state after a failed `atlas_add` is unspecified.
- The `as_flag` numeric fallback (`Json::Number(n) => *n != 0.0`) is now
  untested by anything in `features/`. It's harmless to keep (real fonts
  and the current hand-written-font scenario both write booleans), but if
  the intent is that the schema is strictly boolean now, it's a piece of
  never-exercised leniency a stricter reader implementation elsewhere might
  reasonably have dropped instead of kept — worth the author deciding
  on purpose rather than by omission.

## Failures

None. Every scenario passes; every chapter 16/17 render is byte-identical
to its reference.

## Prose problems

None found this pass beyond the atlas_add pseudo-code/implementation gap
above, which is a code-vs-prose consistency question rather than a prose
clarity problem — the printed pseudo-code itself reads fine and is easy to
translate.

## Concrete changes

- `tests/composites16.rs`: hand-written font JSON literal changed from
  `[0, 0, 1], [100, 200, 0], [200, 0, 1]` to
  `[0, 0, true], [100, 200, false], [200, 0, true]` to match the current
  `chapter16-composites.feature`.
- `tests/plate17.rs`: added the `draw_text_steps_the_pen_by_each_advance_and_answers_where_it_stopped`
  test (imports `canvas`, `color`, `colors_eq`, `draw_text`, `fill`,
  `pixel_at` in addition to what was already imported).
- `src/lib.rs`: reworded `Json::as_flag`'s doc comment — it previously said
  the hand-written-font scenario writes `1`/`0`; it now writes `true`/
  `false` like everything else, so the comment now describes the numeric
  branch as an untested lenient fallback instead of something a live
  scenario exercises. No behavior change.
- `README.md`, chapter 16 notes: reworded the paragraph about the on-curve
  flag's JSON encoding to stop claiming the hand-written-font scenario uses
  `1`/`0`.
- `README.md`, chapter 17 notes: reworded the `atlas_add` paragraph to
  reflect that the chapter now prints pseudo-code for it (it previously
  said the chapter gives none), and to record the shelf-state divergence
  above instead of silently matching output only. Reworded the
  `pen_advance`/`draw_text` sentence, which said `draw_text` "isn't pinned
  by name in any scenario" — it now is, directly, by the new plate
  scenario.
