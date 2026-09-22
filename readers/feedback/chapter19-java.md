# Reader feedback — Java — Chapters 18 and 19

Implemented cold, from `chapter-18.html`/`chapter-19.html` and the
`features/chapter18-*.feature` / `features/chapter19-*.feature` files alone,
on top of the existing Java code for chapters 1-17. This file covers both
chapters together since they share one round.

## Catch-up (chapters 1-17)

The existing code already reflected the chapter 16-17 catch-up pass
recorded in `README.md` (Atlas edge cases, the `chapter16-composites.feature`
scenario renames). Running the full chapter 1-17 suite cold, before touching
anything, gave 559/559 green with every render at `max_channel_difference`
0 — matching the count in the last committed catch-up note exactly, so no
scenario had been added to chapters 1-17 since this code last ran. The only
real chapter 16 catch-up work this round was **not** a new scenario but a
prerequisite the chapter 16 note called out explicitly: `Font`/`Fonts.loadFont`
had no way to read `kern` (needed by chapter 18) or `ligatures`/`joining`/
`forms`/`marks`/`anchors` (needed by chapter 19). All five sections are now
optional — read when present (`root.containsKey(...)`), defaulted to empty
otherwise — so Roboto (kern + ligatures only) and the Arabic font (all five)
both load through the same `Fonts.loadFont`, and no chapter 1-17 test or
render changed.

## Result

- Chapter 18: 20/20 scenarios green. Renders: `kerning.ppm` diff 0,
  `breaking.ppm` diff 0, `drift.ppm` diff 0, `plate-18.ppm` diff 0.
- Chapter 19: 27/27 scenarios green. Renders: `ligature.ppm` diff 0,
  `forms.ppm` diff 0, `word.ppm` diff 0, `mixed.ppm` diff 0, `plate-19.ppm`
  diff 0.
- Full suite, chapters 1-19: 606/606 scenarios green, every render
  byte-exact against `reference/`.

## Ambiguities (what the prose left me to guess, and what I guessed)

- **Chapter 18: draw order for `kernDemo`/`breakDemo`/`driftDemo`.** These
  three have no printed pseudocode, only the `Feature:` prose in
  `chapter18-plate.feature`, and that prose lists "glyphs, then a dim
  baseline, then ticks, then a magenta bracket" without saying whether that
  listing order is also the *paint* order. `alignmentPlate()` *does* have
  printed pseudocode, and it draws hairlines before `draw_run` — glyphs
  painted last, on top. I guessed the same order for the other three and
  got `max_channel_difference` in the 15-140 range (see Failures below);
  the correct order, confirmed by comparing both orders against the
  reference bytes pixel by pixel, is the *opposite*: glyphs first, then
  every annotation on top of them. `alignmentPlate` and the other three
  render functions disagree with each other on this, and nothing in the
  prose says so.
- **Chapter 18: the magenta kerning bracket.** I first drew it as one
  connected four-point polyline (`(kernedEnd,84)→(kernedEnd,180)→
  (unkernedEnd,180)→(unkernedEnd,84)`, closed=false) through one
  `strokeToPath` call, since "joined along y = 180" reads like one path.
  That was wrong at the two corners (`max_channel_difference` 65, six
  pixels off near `y=180`). The reference draws it as **three separate**
  stroked segments (two verticals, one horizontal) that overlap slightly
  where they meet, giving a small double-coverage darkening at each
  corner that a single joined path's round join doesn't produce. I only
  found this by diffing individual corner pixels against the reference.
- **Chapter 18: what "the pen rounded to a whole pixel after every glyph"
  means, precisely (§18.6's trap).** Two readings fit the sentence: (a)
  round the *cumulative* pen after each glyph is placed, carrying the
  rounded value forward, or (b) round each glyph's *own* advance and step
  by that. These are provably the same sequence for a run of *identical*
  characters (which is all the pinning scenario tests: `round(int + x) =
  int + round(x)`), so the scenario can't distinguish them, but they'd
  differ for `driftDemo`'s mixed text. I implemented (b) — literally
  `pen += round(penAdvance(glyph))` — which is what the chapter's own
  scenario formula (`20 * round(pen_advance(...)) - run_advance(...)`)
  suggests directly.
- **Chapter 18: the "rounded run's end" for `driftDemo`'s magenta tick.**
  Is it the sum of every rounded step (so it's forced to a whole pixel),
  or the last glyph's rounded placement plus its own *true* (unrounded)
  advance? I first tried the former (206.0, a whole number) and got
  `max_channel_difference` 57. The reference uses the latter
  (205.66943359375, fractional, anti-aliased over two pixel columns after
  the ×3 magnify) — i.e. "the run's end" always means "last glyph's origin
  plus its real width," never mind how that origin got there.
- **Chapter 19: `applyForms` indexes by `e.cluster()`, not by buffer
  position.** The prose says "swaps each glyph for its form's glyph"
  without saying which character a mid-pipeline glyph's form comes from.
  Since `applyForms` always runs on the fresh `glyphBuffer` output (cluster
  == index there), it doesn't matter in practice, but I switched to
  `e.cluster()` after reconstructing the reference figure JS's own
  `applyForms`, which does the same, for exact fidelity if this function
  is ever called on an already-modified buffer.
- **Chapter 19: `clusters(buffer)` — sorted or insertion order?** The
  prose says "distinct clusters in order" without saying which order.
  Clusters are never observed to go backwards along a real buffer (a mark
  always takes a *preceding* base's cluster), so insertion order and
  numeric-ascending order coincide on every scenario. I sorted explicitly
  to match the reference figure JS's `clustersOf`, which does
  `.sort((a,b) => a - b)`.
- **Chapter 19: an unattached mark's placement in `position()`.** No
  scenario positions a buffer whose very first entry is a mark with no
  base at all (only `attachMarks` in isolation is tested that way). I fell
  back to placing such a mark at the plain run-start `x` (matching the
  reference figure JS's `baseX` variable, which starts at `x` regardless
  of direction) rather than the direction-dependent pen value, since
  that's what the one piece of ground truth I have (the JS) does.

## Hard to translate

Nothing in either chapter needed real translation gymnastics — Java's
`String` is UTF-16 code units and every scenario's Arabic text stays
within the BMP, so `text.charAt(i)` lines up one-to-one with codepoints
exactly the way chapter 16-17's existing code already assumed. Records
(`Placement`, `GlyphEntry`, `Item`, `Ligature`, `MarkAnchor`) made the
buffer/placement plumbing painless. The one mild friction: Gherkin's
`(a, b, c)` tuple literals (`font.marks["kasra"] = ("below", 512, 0)`,
`font.ligatures[1] = (("lam.medi", "alef.fina"), "lam_alef.fina")`) don't
map onto a single assertion helper, so those two scenarios needed a few
separate field-by-field `assertEquals`/`assertDoubleEq` calls instead of
one tuple comparison — mechanical, not a design problem.

## Failures (during development, all fixed before this report)

All of these were caught and fixed before the final state above; none is
outstanding.

- `kernDemo()`: first attempt drew annotations before glyphs (matching
  `alignmentPlate`'s pseudocode order) → `max_channel_difference` 65.
  Fixed by drawing glyphs first (see Ambiguities).
- `kernDemo()`'s magenta bracket: one joined polyline → 6 pixels wrong at
  the corners, worst delta 65. Fixed by drawing three separate segments
  (see Ambiguities).
- `breakDemo()`: same annotation-order issue → `max_channel_difference` 15.
  Fixed the same way.
- `driftDemo()`: annotation order (142) *and* the rounded-run's-end
  formula (57, after fixing the order) both wrong on the first two
  attempts. Fixed by drawing glyphs first and using
  `lastRoundedPlacement.x + trueAdvance` for the rounded end (see
  Ambiguities).
- Everything else (`Layout`, `Shaping`, both test files) matched every
  scenario's numbers on the first run once written from the prose — no
  arithmetic bugs, only the render-order and render-geometry guesses
  above.

## Prose problems

- **§18.6 / `chapter18-plate.feature`**: as above, the render functions'
  paint order (glyphs vs. annotations) is never stated, and the one
  render that *does* print pseudocode (`alignmentPlate`) uses the
  opposite order from the other three. A one-line rule ("annotations
  paint last, except in `alignmentPlate`, where the paragraph text paints
  last instead") would have saved three rounds of pixel-diffing. Given
  this book's own stated policy of never leaving an implementation detail
  to the reader's guess, this is exactly the kind of gap the policy exists
  to catch.
- **§18.6, the trap**: "round the pen to a whole pixel after every glyph"
  is genuinely ambiguous between rounding the cumulative pen and rounding
  each step (see Ambiguities); the two readings happen to coincide for
  the pinning scenario's all-`i` example. A sentence distinguishing them,
  or a scenario with mixed characters, would remove the ambiguity — right
  now the *render* (mixed text) is the only place the distinction would
  show up, and it's checked only by `max_channel_difference`, not a named
  pixel that isolates the effect.
- **§19.6, `caret_positions` for rtl**: the prose ("the pen where each
  cluster's first glyph is placed... For rtl the first position is the
  run's right end") reads as if it's describing the same pen-tracking walk
  for both directions, but the actual rule (glyph's own origin plus its
  own advance, independent of any kern pull from the *next* glyph) is a
  different and more specific claim that only shows up once you reconcile
  it against the reference figure JS. Every `rtl` scenario in
  `chapter19-position.feature` uses `kerning = false`, which is exactly
  the one setting where "pen before this glyph's kern+advance" and "this
  glyph's own origin + its own advance" give identical numbers — so the
  ambiguity is real and currently untested. A `kerning = true` rtl caret
  scenario (the Arabic font's kern table happens to be empty, so it'd need
  a synthetic font, or the same test structure applied to a hypothetical
  kerned rtl font) would pin this down and is the single most valuable
  scenario I'd add.
- Otherwise both chapters' prose was unusually precise — every numeric
  example in §18.1-18.5 and §19.1-19.6 that I hand-verified against the
  implementation before writing any Java matched to the stated tolerance
  on the first try, which is not something I can say about every chapter
  in this series.

## Mutation results

Five mutations tried (the five suggested), each applied, tested, and
reverted:

1. **Kerning applied after the glyph instead of before** (in
   `Layout.layoutRun`: place, advance, *then* add kern, instead of kern,
   place, advance). Caught: 6 of 20 chapter 18 scenarios failed (the two
   `TAVERN`-kerning scenarios, both `layoutLine`/`layoutParagraph` justify
   scenarios — since justify's slack depends on `run_advance`, which
   shifts too — and all three of `kerning.ppm`/`plate-18.ppm`'s render
   diffs). Also caught cross-chapter: 1 of 27 chapter 19 scenarios failed
   (`Position: a buffer straight from the cmap positions exactly as
   layout_run lays it out`, which cross-checks `Shaping.position` against
   `Layout.layoutRun` directly).
2. **Justify stretching the last line** (`layoutParagraph`: dropped the
   `align.equals("justify") && i == lines.size() - 1 ? "left" : align`
   guard, so every line including the last gets justified). **Caught by
   nothing** — 20/20 chapter 18 scenarios still passed, all four renders
   still diffed 0. The one paragraph scenario's last line ("dog") happens
   to be a single word, and `layoutLine`'s own justify branch requires a
   space in the text; without one it falls through to the `else` branch,
   where `"left"`'s shift is 0 — identical to what `"justify"` produces
   for a single word by coincidence, not by the rule actually firing.
   **This is the most valuable finding of the round.** A paragraph whose
   last line has *more than one word* at a measure that makes it end
   ragged (not exactly full) would catch this immediately; right now
   nothing does.
3. **The rtl pen placing the first glyph at `x` instead of the right end**
   (`Shaping.position`: `pen = x` unconditionally instead of `x +
   bufferAdvance(...)` for rtl). Caught: 6 of 27 chapter 19 scenarios
   failed (both rtl position scenarios, the mark-offset scenario, the
   caret-position scenario, and two of the five plate renders).
4. **A ligature result fed back into the rules** (`applyLigatures`
   rewritten to splice the result back into the buffer being scanned and
   re-try it against the rule table at the same index, instead of skipping
   past it). **Caught by nothing** — 27/27 chapter 19 scenarios passed,
   `ligature.ppm` and `plate-19.ppm` both still diffed 0 against the
   reference bytes. Neither font's ligature table has any rule whose
   `parts` could match a glyph name that is itself somebody else's
   `result` (`f_i`, `f_l`, or any `lam_alef*` variant), so there is no
   input in the whole suite where "fed back" and "not fed back" produce
   different output. This is a second real gap, though a narrower one
   than #2: it would take a font with a genuinely chainable ligature rule
   (e.g. `a b -> ab`, `ab c -> abc`) to expose it, and neither shipped
   font has one.
5. **A mark's cluster left as its own** (`attachMarks`: use `e.cluster()`
   instead of `base.cluster()` when a mark successfully attaches). Caught:
   4 of 27 chapter 19 scenarios failed (both marks-feature scenarios that
   check a mark's cluster directly, the rtl caret-offsets scenario, and
   the `word.ppm` render).

Three of five mutations were caught, several times over. The two that
weren't (#2 and #4) share a pattern: both are bugs that only manifest on
an input shape the current scenario set doesn't happen to construct (a
multi-word ragged justified last line; a chainable ligature). Both are
listed under Concrete changes below.

## Concrete changes I'd make

1. Add a `layout_paragraph` scenario whose last line, under `"justify"`,
   has at least two words and doesn't end exactly at the measure — this
   is the single highest-value addition; see mutation #2.
2. State the paint order for `kernDemo`/`breakDemo`/`driftDemo` explicitly
   in prose (or print their pseudocode the way `alignmentPlate` gets it),
   and say outright that it's the opposite of `alignmentPlate`'s order.
3. Either state explicitly that a ligature's `result` is never itself a
   valid `parts[i]` for another rule in the book's own font data (so "not
   fed back" is unobservable by construction and stated as a design
   property, not just an implementation note), or add a small synthetic
   ligature-rule scenario with a genuinely chainable rule so the "not fed
   back" behavior has a scenario that can fail on it.
4. Add one `kerning = true` rtl `caret_positions` scenario (needs a
   synthetic font or an extension to the Arabic font's kern table) to pin
   down whether an rtl caret boundary is adjusted by the kern pull from
   the glyph after it. Right now this is only knowable by reading the
   reference figure JS, which a cold reader (per this project's own
   methodology) isn't supposed to do.
5. `chapter18-plate.feature`'s magenta-bracket description ("joined along
   y = 180") reads as one connected path; state explicitly that it's
   three separate strokes that overlap at the corners (or, if a single
   joined path is intended and the reference is what's wrong, fix the
   reference). As written, a reader who takes "joined" literally — the
   natural reading — gets `max_channel_difference` 65 and has to
   pixel-diff to find out why.

## Timing

Both chapters compile in the same `javac -d classes src/*.java` pass as
everything else (whole-project rebuild, cold: ~2-3s on this machine).
Running each chapter's test class standalone, including JVM startup, all
scenarios, and writing all of that chapter's renders to `out/`:

- `Chapter18Tests`: ~0.42s wall clock (four renders: 320×190, 340×150,
  780×132 post-×3-magnify, 660×236).
- `Chapter19Tests`: ~0.37s wall clock (five renders, largest 540×210).

Neither chapter is a meaningfully bigger renderer workload than chapters
16-17; both are dominated by JVM startup, not rasterization. The full
chapter 1-19 suite (all nineteen `ChapterNNTests` classes run in sequence)
finishes in a few seconds total.
