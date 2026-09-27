# Catch-up pass: chapters 22-23 vs. current features/

## Method

Diffed every `Scenario`/`Scenario Outline` title in `features/chapter22-*.feature` and
`features/chapter23-*.feature` (90 titles) against the `#[test]` functions in
`tests/*22.rs` and `tests/*23.rs` (after normalizing apostrophes/punctuation so titles map
onto Rust's snake_case). Also read every scenario's full step text side by side with its
matching test body (all 18 files, both directions) to catch a scenario whose title stayed
the same but whose numbers or steps changed. Re-read the specific rules the task called out
as notable: Bentley-Ottmann's split-recording, `stitch`'s furthest-right formula,
`is_corner`'s `sin(3)`, `bake_msdf`'s tie-break `o`, and `title()`'s four-pass rule.

## What was new or changed

One scenario was missing entirely: **"At a shared corner the furthest right turn is not the
first edge in the list"** (`features/chapter22-robust.feature`), two triangles
`polygon(point(1,0), point(3,2), point(2,4))` and `polygon(point(3,2), point(4,3),
point(4,4))` sharing only the vertex `(3, 2)`. This is the scenario mentioned in the Python
reader's commit ("two triangles touching at (3, 2) now pin it") — it exercises `stitch`
picking the furthest-right turn at a shared vertex where the *first* candidate edge in
`keep_edges`'s list order is not the correct turn (a bug the Python reader's first draft had:
picking by list order instead of by the angular comparator).

Every other scenario title, step, and pinned number in both chapters' nine feature files
each matched what was already in `tests/` byte for byte (values, tolerances, table rows,
`Examples:` rows). No other scenario was added, renamed, or had its numbers changed since
this reader's original round.

## What failed on the existing code, and why

Nothing. I added the missing scenario as
`at_a_shared_corner_the_furthest_right_turn_is_not_the_first_edge_in_the_list` in
`tests/robust22.rs` and it passed immediately, with no code changes — this reader's `stitch`
already compares candidates with the real angular comparator (`ccw_half`/`cmp_ccw_from` in
`src/lib.rs`), never by list order, so the bug the scenario exists to catch was never present
here.

## Rules re-verified against the current chapter text (no changes needed)

- **Bentley-Ottmann never cuts mid-sweep**: `find_splits_bo` (`src/lib.rs`) only ever pushes
  into an `out[idx]` list of pending split points; every `segs[idx].lo`/`.hi` used for
  `eorient`/`meet`/tests throughout the sweep stays the segment's original ends. Cutting
  happens afterwards in `split_segments`, matching the chapter's "nothing is cut during the
  sweep" paragraph.
- **`is_corner`**: `dot(a, b) <= 0.0 || cross(a, b).abs() > (3.0_f64).sin()` — `3.0` is radians,
  matches `chapter23-atlas.feature`'s scenario exactly (including the `0.980066578` /
  `0.995004165` boundary pair).
- **`bake_msdf`'s tie-break `o`**: computed as `0.0` when the nearest `t` is interior, else
  `|dot(direction_at(c, t), unit(p - endpoint))|`, and the comparator picks the smaller `o`
  only within `1e-12` of the best distance — matches the feature's wording verbatim.
- **`title()`'s four passes**: `pub fn title()` bakes every glyph once up front
  (`placements.iter().map(bake_mtsdf)`), then does four separate `for` loops over the whole
  run, one per effect (shadow, glow, fill, outline) — matches "each pass drawing every glyph
  of the run before the next pass starts," not per-glyph.

One thing I looked at but did **not** change: `stitch`'s tie-break formula as now written
("half 0 when `cross(r, v) < 0` or `cross(r, v) = 0 and dot(r, v) > 0`") disagrees, on paper,
with this code's `ccw_half` for the exact zero-cross case (this code puts the *straight-ahead*
continuation `-r` in half 0 and the *exact-reversal* `r` in half 1; the written formula does
the opposite). I could not find any scenario, in this pass or the original round, that
reaches this branch with a live candidate — the one geometry that would (a segment doubling
straight back on itself at a vertex, e.g. the spike scenario) gets cancelled by
`merge_segments` before `stitch` ever sees it, the same way `meet`'s `"touch"` branch was
already noted as invisible to `robust22.rs`'s corner-on-an-edge scenario. Flipping the branch
changes no test result either way, so I left the working, extensively mutation-tested
implementation as is rather than gamble on a prose reading of dead code; worth a second pair
of eyes (or a scenario that actually reaches it) before touching it.

## Final counts

`cargo test --release --offline`: **790 passed, 0 failed** (789 before this pass + the 1
newly-added scenario), across all 23 chapters. No production code in `src/lib.rs` changed;
the only diff is the new test in `tests/robust22.rs`.
