# Catch-up pass: chapters 18-19

Compared every scenario in `features/chapter18-*.feature` and
`features/chapter19-*.feature` against the existing `tests/*.rs`. Six new
scenarios were missing (all recently added upstream); nothing else in those
twelve feature files had changed steps. All six passed on the existing code
with no fixes needed — the implementation already handled every case
correctly.

## New scenarios added

- `tests/aligning18.rs` — "The last line stays left even when it has spaces
  to stretch" (`features/chapter18-aligning.feature`). Pins that
  `layout_paragraph` lays out a justified paragraph's last line as "left".
  Passed as-is: `layout_paragraph` already special-cases the last line
  (`let mode = if align == "justify" && i == lines.len() - 1 { "left" } else { align };`).

- `tests/ligatures19.rs` — two scenarios from
  `features/chapter19-ligatures.feature`:
  - "The longest rule that matches wins, on a font written by hand to have
    two" — a toy font with `a_b`, `a_b_c` and `a_b_a` rules; `abc` must
    become one `a_b_c` glyph, not `a_b` + `c`.
  - "A result is never fed back into the rules" — `aba` must become
    `a_b` + `a` (2 glyphs), not `a_b_a` (1 glyph), because the `a_b` result
    of the first match isn't re-examined against the `a_b_a` rule.
  Both passed as-is: `apply_ligatures` already sorts rules longest-first
  and matches against the original `buffer`, never against `out` (the
  glyphs already emitted), so a result is structurally never fed back.

- `tests/marks19.rs` — "shape chooses the forms before it looks for
  ligatures" (`features/chapter19-marks.feature`). Shapes Arabic
  "سلام" (seen-lam-alef-meem) through `shape` end-to-end and checks the
  lam-alef ligature only happens after `apply_forms`. Passed as-is: `shape`
  already runs `apply_forms` before `apply_ligatures`.

- `tests/position19.rs` — "A mark between two glyphs neither moves the pen
  nor breaks their kern pair" (`features/chapter19-position.feature`). Toy
  font, text `"a*b"` (`*` maps to a zero-width "dot" mark glyph). Checks
  `buffer_advance`, `position`, and all three `caret_positions` directions
  still see the `a`/`b` kern pair across the mark. Passed as-is: `position`
  and `buffer_advance` both skip mark entries without advancing `prev`, so
  the kern lookup between `a` and `b` is unaffected by the mark sitting
  between them in the buffer.

- `tests/plate18.rs`, `tests/plate19.rs`, and the remaining chapter18/19
  feature files (`breaking`, `kerning`, `metrics`, `arabic`, `buffer`,
  `itemize`) already had 1:1 test coverage — nothing to add there.

## Fixes

None. Every new/changed scenario passed against the existing implementation
on the first run; no code in `src/lib.rs` was touched.

## Renders

Regenerated `out/` with `cargo run --release --bin render_all`. All nine
chapter 18/19 renders diff exactly 0 against `reference/chapter-18/` and
`reference/chapter-19/` (`kerning.ppm`, `breaking.ppm`, `drift.ppm`,
`plate-18.ppm`, `ligature.ppm`, `forms.ppm`, `word.ppm`, `mixed.ppm`,
`plate-19.ppm`).

## Full suite

`cargo test --release` — 105 test binaries, all green, 0 failures, chapters
1-19.

## Ambiguities / suspected bugs

None found. No README changes were needed (the run/test commands are
unchanged).
