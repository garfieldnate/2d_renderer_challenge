# Reader feedback — Rust, chapters 18-19

Cold implementation of chapter 18 (*Setting a Line of Text*) and chapter 19
(*Shaping, a Field Guide*) on top of the existing chapters 1-17 code, from
`chapter-18.html`/`chapter-19.html` and `features/chapter{18,19}-*.feature`
alone. This file only covers chapters 18-19; earlier chapters' feedback (if
any) is not reproduced here.

## Catch-up (chapters 1-17)

No feature file under `chapter01`-`chapter17` had a scenario the existing
`tests/*.rs` didn't already cover. I wrote a small script that extracted
every `Scenario`/`Scenario Outline` title from every `chapter0*`/`chapter1[0-7]*`
feature file, slugified it, and looked for a `#[test]` function with a
matching or near-matching name; every one of the ~65 "misses" it flagged
turned out to be a test that exists under different wording (e.g. the
feature's "Two numbers that differ by less than the tolerance are equal"
is `tests/equality.rs::two_numbers_within_tolerance_are_equal`) or a
macro-expanded scenario outline (`tests/stroke.rs`'s chevron-join outline).
`cargo test --release` on the pre-existing code was fully green before I
touched anything (525 tests across 93 binaries at that point — the count
grew to 572 across 105 binaries, +47 tests in 12 new binaries, after
chapters 18-19 were added). I did
not need to change any chapter 1-17 code or test, only extend the `Font`
struct and `load_font` with six new optional fields (`kern`, `ligatures`,
`joining`, `forms`, `marks`, `anchors`) — additive, so nothing that
constructs or reads a `Font` from chapters 1-17 needed to change.

## Chapter 18: Result

- 20 scenarios across 5 feature files, all translated 1:1 into
  `tests/metrics18.rs` (4), `tests/kerning18.rs` (3), `tests/breaking18.rs`
  (4), `tests/aligning18.rs` (3) and `tests/plate18.rs` (6). All 20 pass.
- Renders: `kerning.ppm`, `breaking.ppm`, `drift.ppm`, `plate-18.ppm` all
  diff **0** against `reference/chapter-18/` (not merely `<= 1`).

## Chapter 19: Result

- 27 scenarios across 7 feature files: `tests/itemize19.rs` (3),
  `tests/buffer19.rs` (1), `tests/ligatures19.rs` (3), `tests/arabic19.rs`
  (5), `tests/marks19.rs` (4), `tests/position19.rs` (6), `tests/plate19.rs`
  (5). All 27 pass.
- Renders: `ligature.ppm`, `forms.ppm`, `word.ppm`, `mixed.ppm`,
  `plate-19.ppm` all diff **0** against `reference/chapter-19/`.

## Catch-up: chapter 16's loader

`chapter-16.html`'s own note (repeated in the book's own project memory)
said the loader would need to accept optional sections a later chapter's
font file carries. I extended `Font`/`load_font` once, up front, with all
six fields chapters 18 and 19 between them need (`kern`/`ligatures` for
18; `joining`/`forms`/`marks`/`anchors` for 19), all read through a new
`Json::get_opt` that returns `None` instead of panicking when a top-level
key is missing — Roboto has `kern`/`ligatures` but not the Arabic four;
DejaVu Sans has all six. No chapter 16/17 test needed to change: they
construct `Font` only through `load_font`, never a struct literal.

## Ambiguities

- **`kern_demo`'s tick color, and where a tick belongs to which row.**
  §18.2's prose says "cyan on the kerned row and dim on the other" and the
  feature's own prose repeats it, but neither the chapter's pseudo-code
  section nor `chapter18-plate.feature` states the *exact* geometry of the
  ticks (are they per-placement, or per-caret-offset; does the run's own
  end also get a tick). I read the chapter's embedded figure JS
  (`kernDemo` in `chapter-18.html`'s trailing `<script>`) to resolve this:
  a tick at every placement's `x` plus one more at `x + run_advance`. I
  did not treat the JS as authoritative on faith — I derived the same
  answer independently from "a tick at every placement's x and at the
  run's end" in `chapter18-plate.feature`'s own prose, and the JS only
  confirmed the reading and supplied the exact y-extents (`y+3` to
  `y+12`) that the prose doesn't spell out numerically. Render diffed 0
  either way once I had it right, so this cost one iteration, not a bug.
- **`alignment_plate`'s panel geometry** (`x = 20 + (k mod 2) × 320`,
  `y = 24 + (k div 2) × 108`, hairline y-extents `y − 14` to
  `y + (n−1)·line_height + 5`) is stated in prose in §18.6 but the exact
  arithmetic is only fully pinned by the figure JS; I transcribed it
  faithfully rather than reverse-engineering it from pixel values, since
  the chapter's own pseudo-code block (`alignment_plate()`) already gives
  the loop structure in the book's pseudo-code convention, not just JS.
- **Whether `run_advance`'s kerning parameter has to match `break_lines`'s
  own kerning parameter for the line-width check.** The prose says "a
  line's width is measured with the same kerning the run will be laid out
  with", which I read as: `break_lines` takes one `kerning` flag and uses
  it both for measuring candidates and (implicitly, since it's the same
  flag threaded through by the caller) for the eventual layout. There's
  no separate "layout kerning" parameter anywhere in the API, so there
  was nothing to get wrong here — noting it because the prose reads as if
  it's warning against a mistake that the signature itself doesn't allow.

Chapter 19 read cleaner — the prose is unusually precise about the join
rule, the greedy ligature walk, and the RTL pen — and I didn't have to
guess anything I'd call a real ambiguity. The one place I checked twice
was **which cluster a re-matched ligature and a re-parented mark are
compared by name against** in `cluster_plate`'s bottom-row coloring rule
("glyphs whose names changed from the top row... are magenta"): the
prose says "changed from the top row" without saying compared *how*
(same buffer position? same cluster? same glyph name anywhere in the
raw row?). I read it as "glyph name not present anywhere in the raw
per-character buffer" (a set-membership check, not a positional one),
which is what produced a byte-exact `plate-19.ppm`.

## Hard to translate

Nothing didn't map onto Rust. The one piece of friction worth naming:
`position`'s mark branch needs the *previous non-mark's own placed x*
(`base_x`), not the pen. I kept a running `base_x` alongside `pen`
(mirroring the chapter's own JS closure variable of the same name)
rather than reconstructing it from the output vector, which would have
needed a second pass or an index-chasing loop. `apply_forms` indexing a
character-indexed `Vec<String>` (`arabic_forms`'s output) by a
buffer entry's `cluster` field relies on the invariant that forms run
before ligatures (so cluster == original character index at that point in
the pipeline); I leaned on `shape`'s own fixed step order to guarantee
it rather than re-deriving the character index some other way, which
matches the chapter's own stated pipeline order ("forms first, then
ligatures").

## Failures

None. Every scenario passed on the first implementation that compiled
against every pinned number simultaneously (i.e., I did not need to
special-case or "fix" a scenario — the few iterations mentioned above
under **Ambiguities** were resolved before I ran the tests, by reading
the figure JS, not by weakening a scenario after a failure).

## Prose problems

- §18.5 says draw_run's baseline "rounds to the nearest row, halves up: at
  16 pixels the baselines land on rows 24, 43, 62, 80." I could not find
  where those four specific numbers come from in the text around it (no
  scenario or figure in chapter 18 lays out four lines at 16 pixels with
  those baselines); they may be a leftover from an earlier draft of
  `alignment_plate` or `break_demo`. It didn't block anything since the
  claim itself (rounding rule) is separately pinned exactly by
  `chapter18-plate.feature`'s own scenario, but a reader who goes looking
  for where "24, 43, 62, 80" comes from will not find it.
- Chapter 19 §19.7's "What was left out" section is candid to the point
  of being one of the more useful pieces of prose in the book — it names
  UAX 9/14/29 and says exactly what's missing and why the comma jumps in
  `mixed_demo`. No problem there; flagging it as a place other chapters'
  "trap" sections could learn from, since it explains a *known, accepted*
  gap rather than a bug to fix.
- The `sed -e 's/<[^>]*>//g'` voice-check command in `CLAUDE.md` mangles
  inline `<=`/`>=` inside the chapter's own embedded JS (it eats `<=` as
  if it were a tag opener), which cost me one detour chasing what turned
  out to be my own extraction artifact, not a chapter bug — `scriptOf`'s
  actual source has `cp<=0x6FF` etc. intact when read from the raw HTML.
  Not a chapter problem, but worth recording since another agent doing
  the same voice-check grep on chapter 19 would see the same corruption
  and might misdiagnose it as a chapter typo.

## Mutation results

Six deliberate bugs, tested and reverted, three per chapter (see
`README.md`'s "Mutation testing (chapters 18-19)" section for the full
narrative). Summary:

| # | Chapter | Mutation | Caught? |
|---|---|---|---|
| 1 | 18 | Kerning applied after the glyph, not before | Yes — 6 scenarios (`kerning18.rs`, `aligning18.rs`, `plate18.rs`) |
| 2 | 18 | Baseline floored instead of rounded halves-up | Yes — 1 unit scenario + 2 render diffs |
| 3 | 18 | Justified paragraph's last line also stretched | **No — survived the entire suite** |
| 4 | 19 | RTL pen starts at `x` instead of `x + buffer_advance` | Yes — 6 scenarios (`position19.rs` ×3, `plate19.rs` ×3) |
| 5 | 19 | Ligature result fed back into the rules | **No — survived the entire suite** |
| 6 | 19 | A mark keeps its own cluster instead of its base's | Yes — 2 scenarios in `marks19.rs` |

Two of six survived every scenario and every render:

- **#3** — every justified paragraph in this chapter's scenarios and
  renders (the unit scenario's `"the quick brown fox jumps over the lazy
  dog"` and the plate's `THROUGH_LINE`) happens to break its last line on
  a single word (`"dog"`, `"drew."`), and a one-word line has no spaces
  to stretch (`layout_line`'s justify branch requires `gaps > 0`), so
  "force the last line left" and "just use the paragraph's own alignment"
  produce byte-identical output on every fixture in the book.
- **#5** — none of the ligature rules in either font used by this chapter
  (Roboto's `f i -> f_i`, `f l -> f_l`; DejaVu's Arabic `lam.X alef.Y ->
  lam_alef[.Y]` rules) ever produce a glyph name that is itself the
  left-hand side of another rule, so "don't feed a result back in" and
  "feed it back in and let it hit a fixed point" agree on every buffer
  this book ever builds.

Both are the strongest kind of finding this project's testing philosophy
is built to surface: the *rule* is correctly stated in prose, correctly
named by a scenario title, and correctly implemented, but the pinned
*data* never actually forces the two possible implementations apart. See
**Concrete changes** for what would close each gap.

## Concrete changes

1. **Add a justify scenario whose last line has two or more words.**
   Something like `break_lines`-ing a text at a measure chosen so the
   final line is, say, `"the lazy dog"` rather than `"dog"` alone, then
   asserting that the multi-word last line's *first word after a space*
   sits exactly where left-alignment would put it (not shifted by any
   slack-per-gap), the way `justify_stretches_the_spaces_not_the_letters`
   already does for a non-last line. This single scenario would catch
   mutation #3.
2. **Add a ligature-chaining scenario**, even a synthetic one outside the
   real font data if needed: a font (or a hand-built buffer, the way
   `chapter16-font.feature` has a hand-written-font scenario) with a rule
   whose result glyph is also another rule's first part, and a pinned
   assertion that the buffer comes out *not* re-ligated. This is exactly
   analogous to chapter 15's zero-length-dash and chapter 13's
   duplicate-closing-point scenarios — a case the prose calls out by name
   but no real font's data happens to exercise. This would catch
   mutation #5.
3. Both gaps are in the *feature files*, not the chapter prose (which
   states both rules correctly) — no chapter text needs to change, only
   `chapter18-aligning.feature` and `chapter19-ligatures.feature` gaining
   one scenario apiece.
4. Minor: `chapter-18.html` §18.5's "24, 43, 62, 80" baseline-row example
   (see **Prose problems**) could either be tied to an actual figure/
   scenario or dropped, so a reader doesn't go looking for where it comes
   from.

## Timing

`cargo run --release --bin render_all` writes all 70 renders (chapters
1-19) in about 1.2-1.4 seconds wall-clock, dominated by the earlier
chapters' brute-force rasterizers (chapter 2/3's per-pixel supersampling,
chapter 5's double star rasterization). Chapters 18-19's own nine renders,
timed individually in isolation:

| Render | Time |
|---|---|
| `kerning.ppm` (`kern_demo`) | 5.0 ms |
| `breaking.ppm` (`break_demo`) | 10.7 ms |
| `drift.ppm` (`drift_demo`) | 4.9 ms |
| `plate-18.ppm` (`plate_18`) | 37.6 ms |
| `ligature.ppm` (`ligature_demo`) | 2.3 ms |
| `forms.ppm` (`forms_demo`) | 3.4 ms |
| `word.ppm` (`word_demo`) | 1.5 ms |
| `mixed.ppm` (`mixed_demo`) | 2.9 ms |
| `plate-19.ppm` (`plate_19`) | 11.4 ms |

`plate_18` is the slowest of the nine (four full justified/centered
paragraphs of `THROUGH_LINE`, each glyph going through chapter 17's
`fill_path` rasterizer once per bitmap plus hairlines for every baseline
and measure edge) but is still under 40 ms; `cargo test --release` for
just the 12 new test files finishes in well under 0.1 s total. Neither
chapter needed any change to keep `--release` comfortably fast — nothing
here approaches chapter 2/3's per-pixel supersampling cost.
