# Reader feedback: Python, chapters 18-19

Cold implementation from chapter text and `.feature` files alone. No prior chapter's code was
touched except `Font`/`load_font` (extended, additively) and `test_runner.py` (one generic bug
fix, described under Chapter 19's Catch-up). All chapters 1-17 tests still pass after both
chapters landed.

## Catch-up (chapters 1-17)

Ran the full chapters 1-17 suite before touching anything: 564/564 green, matching the count the
existing README already claimed. No new scenarios had been added to those feature files since the
code last ran, so there was nothing to fix here. (Chapter 19 did expose a latent bug in the test
harness itself — see Chapter 19's Catch-up below — but that bug was invisible to chapters 1-17's
own scenarios, so it doesn't show up as a catch-up failure for them.)

---

## Chapter 18: Setting a Line of Text

### Result

20/20 scenarios green (`chapter18-metrics`, `-kerning`, `-breaking`, `-aligning`, `-plate`). All
four renders byte-exact against `reference/chapter-18/`:

| render | max_channel_difference |
|---|---|
| `kerning.ppm` | 0 |
| `breaking.ppm` | 0 |
| `drift.ppm` | 0 |
| `plate-18.ppm` | 0 |

### Catch-up

None specific to chapter 18 (see the top-level Catch-up section).

### Ambiguities

- **Draw order inside the demos.** The prose for `kern_demo()`/`break_demo()`/`drift_demo()`/
  `alignment_plate()` says *what* each render contains (a hairline here, a tick there, text at
  such-and-such position) but never says what's drawn on top of what. This matters as soon as a
  hairline is thick enough to cross a glyph's own ink (the default hairline width in this chapter
  is 1px, not the 0.5px `alignment_plate` uses for its own baselines, so the effect is visible).
  I guessed "glyph over hairline" everywhere at first (matching how chapter 16/17's demos read),
  which byte-matched `break_demo` and `alignment_plate` immediately but was wrong for
  `kern_demo`: there the reference draws the *hairline over the glyph* (glyph ink shows through
  the tick/baseline lines at partial coverage, not the reverse). I found this by rendering,
  diffing against the reference, and reading off which of the two plausible mixed colors
  (`mix(gray, dim, 0.5)` vs `mix(paper, dim, 0.5)`) matched the actual bytes at the differing
  pixels — the two give visibly different byte triples, so the diff is unambiguous once you know
  to check it. I'd guess this inconsistency is not intentional on the author's part (nothing in
  the prose suggests kern_demo should behave differently from the other three), but I'm reporting
  what the reference actually does, not what I think it should do.
- **`drift_demo`'s "rounded pen" trap, exact definition.** "The pen rounded to a whole pixel after
  every glyph" is precise about *where each glyph is placed* (place at the current — already
  whole — pen, then advance, then round for the *next* glyph) but doesn't say what "the rounded
  run's end" means for the magenta bracket, since there is no glyph *after* the last one to round
  for. I initially rounded after the last glyph too, which is internally consistent but wrong: the
  bracket's right (rounded) end sits at the un-rounded pen position after the last glyph's advance
  — i.e., the rounding scheme only ever decides where the *next* glyph goes, and there is no next
  glyph at the end of the string. Found this the same way, by diffing a single vertical hairline's
  antialiasing (a `205.67` fractional position vs. my `206` integer position) — the byte-level
  antialiasing pattern only makes sense for a fractional endpoint, which pinned it exactly.
- **`kern_demo`'s ink for the glyphs isn't named in §18.6's prose or the plate feature text**
  beyond "the renders use chapter 16's inks". I used `gray` for the glyphs, `dim` for the
  non-highlighted baseline/ticks, and `cyan`/`dim` for the tick color split the prose does specify
  ("cyan on the kerned row and dim on the other"). This matched on the first try.

### Hard to translate

Nothing chapter-18-specific was hard to express in Python; `layout_run`/`run_advance` share one
internal pen-walk helper (`_run_walk`) precisely so the "kerned pair is narrower by exactly the
kern" scenario can't accidentally pass with two independently-drifting implementations.

### Failures (before fixing)

Two renders failed on the first pass, both by construction bugs rather than misreadings of the
layout math (which was right first try — all 15 non-render scenarios passed immediately):

- `kern_demo`: `max_channel_difference` 26 against the reference, isolated to rows straddling each
  baseline. Actual: my glyph-then-hairline draw order gave `(206,206,212)` (pure glyph ink) at a
  probe pixel; reference wanted `(181,181,188)` (glyph ink blended 50% with `dim`). Fixed by
  drawing the hairline/ticks *after* the glyph run in each row of the loop.
- `drift_demo`: `max_channel_difference` 57, isolated to the magenta bracket's rounded-end column.
  Actual: my bracket line was crisp (centered exactly on the integer `206`); reference showed
  antialiased partial coverage consistent with a `205.669`-ish center. Fixed per the ambiguity
  above (don't round the pen after the *last* glyph, only between glyphs).

### Prose problems

- §18.5/§18.6 (the plate feature's own prose block) never states draw order for any of the four
  demos, and it matters for `kern_demo` specifically (see Ambiguities). A sentence like "glyphs
  paint over the hairlines, not the reverse" (or the opposite, if that's what's intended) would
  have saved the diff-and-guess step.
- The trap paragraph in §18.5 ("Keep the pen fractional and round only when you paint") describes
  the mistake precisely but doesn't say how the *demonstration render* resolves the "end of the
  rounded run" question, which is exactly the corner case a reader has to invent an answer for.
  Since the render is pinned by scenario (rightly — this is the book's whole "every step is
  pinned" rule), the render's own construction needed one more sentence of pseudocode, the way
  `break_lines` and `layout_line` got theirs.

### Mutation results

Tried three plausible mistakes, restored `renderer.py` from a backup between each:

1. **Kerning applied after the glyph instead of before** (mutated `_run_walk` to advance the pen
   by the glyph's own width first, then apply the kern adjustment, shifting the *next* glyph
   instead of the current one). Caught hard: 6 of 20 scenarios failed, including the one aimed
   directly at it ("The pen moves by the pair before the second glyph is placed") and both render
   scenarios that use kerning.
2. **Justify stretching the last line of a paragraph** (removed `layout_paragraph`'s
   `align == "justify" and i == len(lines) - 1` special case, so every line — including the
   last — gets the full justify treatment). **Not caught by any scenario.** Every paragraph text
   pinned by the existing scenarios (`"the quick brown fox jumps over the lazy dog"` at two
   different measures, and `THROUGH_LINE` in `alignment_plate`) happens to break so its *last*
   line is a single word ("dog", "drew."). `layout_line`'s own justify branch already guards on
   "has at least one space" before spreading anything, so a single-word last line is
   indistinguishable from a correctly-left-aligned one regardless of whether the "last line is
   left" rule exists at all. This is the same shape of gap the book's own testing notes warn
   about (a boundary that's never actually exercised) — I'd add a scenario whose last line has at
   least two words under a measure that leaves visible slack, e.g. break
   `"the quick brown fox jumps over the lazy dog and one more"` at a measure that lands two words
   on the final line.
3. **Baseline rounds toward zero instead of half-up** (`draw_run` truncates `p.y` with `int()`
   instead of `round_half_up`). Caught: 3 of 20 scenarios failed, including the scenario written
   specifically for it ("The baseline rounds to a pixel row, halves up") plus both `break_demo`
   and `plate_18`'s renders, which use non-integer baselines internally via `line_height`.

---

## Chapter 19: Shaping, a Field Guide

### Result

27/27 scenarios green (`chapter19-itemize`, `-buffer`, `-ligatures`, `-arabic`, `-marks`,
`-position`, `-plate`). All five renders byte-exact against `reference/chapter-19/`:

| render | max_channel_difference |
|---|---|
| `ligature.ppm` | 0 |
| `forms.ppm` | 0 |
| `word.ppm` | 0 |
| `mixed.ppm` | 0 |
| `plate-19.ppm` | 0 |

### Catch-up

Found and fixed a real bug in `test_runner.py` itself, exposed (not caused) by chapter 19.
`parse_features`'s step-line parser split every step on `.split()` and rejoined with
`' '.join(...)`, which silently collapses any run of multiple consecutive spaces — including ones
that sit *inside a quoted string literal* in the step text. This has apparently been latent since
chapter 1 (any Gherkin step with `"  two spaces  "`-style text in it would be affected), but no
earlier chapter's scenarios depended on the exact character count of a string containing a double
space. Chapter 18's `break_lines(font, "  two  spaces ", 11, 100, true) = ["two spaces"]` scenario
has exactly this shape and still happened to pass, because `break_lines`'s own output collapses
whitespace anyway (via `text.split()`), so the harness's corruption of the *input* string was
invisible in the *output* comparison. Chapter 19's `itemize("  12 ")[0].end = 5` scenario is the
first one that pins a raw *character offset* into a string with a double space, and it failed
outright (`itemize` correctly returned an item of length 4, matching the harness's already-mangled
4-character string `" 12 "`, not the intended 5-character `"  12 "`). Fixed by splitting the step
line only on the *first* run of whitespace (to peel off the `Given`/`When`/`Then`/`And` keyword)
and leaving the rest of the line untouched. Reran the full 1-19 suite after the fix: still 611/611
green, so the fix didn't disturb anything that was passing by relying on the old behavior.

### Ambiguities

- **`arabic_forms`'s exact neighbor-search rule** ("the nearest non-transparent character before
  it is dual") reads unambiguously in prose, but a reader has to notice that "non-transparent" is
  doing real work: the search must skip *only* `"transparent"`-typed neighbors (vowel marks), not
  `"none"`-typed ones (spaces, and any letter that simply isn't a joiner). I initially had to
  double check this against the `"ب ب"` (beh space beh) scenario, which is exactly the case that
  would come out wrong (both behs isolated, not joined across the space) if a reader skipped
  `"none"` characters too when hunting for a neighbor. Validated by hand against all six
  scenarios in `chapter19-arabic.feature` before writing any code, which caught this ambiguity
  before it became a bug rather than after.
- **`caret_positions` for right-to-left runs** is genuinely subtle and I don't think the prose
  fully disambiguates it without the scenario's numbers. "The pen where each cluster's first
  glyph is placed" is true and sufficient for `"ltr"` (where a glyph's own placement *is* the pen
  position immediately before its advance is applied), but for `"rtl"` the glyph's *placement* is
  its position *after* its own advance/kern is subtracted — i.e. its left edge, not the pen
  checkpoint "before" it in reading order. The caret for "before this cluster" in RTL is that
  cluster's *right* edge (one checkpoint earlier in the pen walk), not its placement.x. I worked
  this out by treating `caret_positions` as its own pen-walk (recording a checkpoint the moment a
  new cluster is about to be processed, in buffer/logical order, for both directions) rather than
  trying to derive it algebraically from already-computed placements — that formulation turned out
  to unify both directions correctly. A worked example in the prose (the way `break_lines` and
  `layout_line` get pseudocode) would remove the ambiguity; right now it's only pinned by the
  numbers in the scenario, which is enough to get it *right* but not enough to know *why* without
  reverse-engineering.
- **`cluster_plate`'s boxes are outlines, not fills.** Neither the plate's own prose ("a cyan box
  spanning...", "a dim box from 46 above the baseline to 12 below") nor `forms_demo`'s box
  ("a dim hairline along y = 60 ... 4 left of the origin to 68 right of it" — this one at least
  says "hairline") makes it obvious that "box" here means a stroked rectangle outline rather than
  a filled one. I built a filled rectangle first (reasonable reading of "box"), which produced a
  plate that was structurally right (all the pinned single-pixel checks in the scenario passed —
  they happen to land on ink or on box borders, not box interiors) but off by 113-199 in
  `max_channel_difference`, entirely inside what should have been each box's *interior*, which the
  reference leaves as plain background. Confirmed by scanning a single column through a box
  vertically in the reference and finding only a one-row-thick line at each edge with background
  in between.
- **Draw order for `cluster_plate`'s boxes, connector, and glyphs.** Three separate elements
  overlap in the bottom row (a cyan box border, a magenta connector line touching that border, and
  glyph ink that can cross a box's edge), and the plate's prose doesn't state a z-order for any of
  them. Reverse-engineered by diffing: (1) glyphs must be drawn *before* the cyan box outline
  (the box border needs to stay visible as a clean line even where it crosses a glyph, so it has
  to paint on top, not get painted over), and (2) the magenta connector must be drawn *after* the
  cyan box (their shared endpoints, where a connector touches a box's top edge, come out more
  magenta-dominant in the reference than a "box painted last" order would give). The top row's dim
  box, by contrast, is drawn *before* its glyph (glyph wins there) — I didn't find a single
  consistent story ("later-drawn thing always wins") that explains both rows; I just matched what
  the reference actually does in each case.

### Hard to translate

Nothing here needed a Python-specific workaround. `GlyphEntry`/`Item`/`Placement` are plain
classes with the attributes the scenarios dot into (`.glyph`, `.cluster`, `.dx`, `.dy`,
`.start`, `.end`, `.text`, `.script`, `.direction`, `.name`, `.x`, `.y`) — the generic
`evaluate_expression`/`compare_values` machinery in `test_runner.py` already handles arbitrary
attribute access and tuple/list comparison, so no new step shapes were needed for any chapter 19
scenario once the whitespace bug above was fixed.

### Failures (before fixing)

All 22 non-render scenarios (itemize, buffer, ligatures, arabic, marks, position) passed on the
first implementation attempt with zero iteration, once the itemize whitespace bug above was
diagnosed and fixed — worth calling out since that's unusual and suggests the chapter's prose and
scenarios are, section for section, tightly specified for the pure-logic parts. The five renders
needed real iteration:

- `ligature_demo`/`word_demo`/`mixed_demo`: `max_channel_difference` 37/26/26. All three were the
  same bug (glyph/hairline draw order — see Ambiguities), fixed identically in each.
- `forms_demo`: `max_channel_difference` 26, same bug, opposite direction (hairline-then-glyph was
  already what I had, but I'd made the same "glyph on top" assumption as the other three and had
  to swap it back for this one specifically once I noticed the byte pattern wanted the opposite of
  what `ligature_demo` wanted).
- `plate_19`: `max_channel_difference` 199, from filling the boxes solid instead of stroking their
  outlines (see Ambiguities), which also cascaded into the connector-vs-box-vs-glyph ordering
  question once the boxes were the right *shape*.

### Prose problems

- §19.5/§19.6's prose is precise about *what* `attach_marks`/`position` compute but the RTL caret
  behavior (see Ambiguities) is only fully pinned by the scenario's raw numbers, not explained.
  This is defensible under the book's own "no plain-table duplicates of scenarios" rule, but caret
  placement is subtle enough (two candidate readings, both internally consistent, only one
  matching the reference) that I'd make an exception and spell out which pen-value a caret
  corresponds to in each direction, the way `layout_line`'s four alignments each get a clause.
- §19.8's `cluster_plate()` pseudocode says "dim box" / "cyan box" for the two annotation
  rectangles without the word "hairline" or "outline" that `forms_demo`'s prose paragraph uses for
  a very similar element one section earlier. Given the chapter's own convention (chapter 16's
  "hairline" vocabulary, reused throughout 17-19) already has a word for "stroked, not filled",
  using it consistently here would remove the ambiguity outright.
- Everything else in §19.1-19.6 (itemizing, the joining-type neighbor search, ligature greediness,
  mark attachment, position/caret math) matched the prose and pseudocode exactly on the first
  pass — no complaints there.

### Mutation results

Tried three plausible mistakes, restored `renderer.py` from a backup between each:

1. **A mark's cluster left as its own instead of taking its base's** (`attach_marks` still
   computes `dx`/`dy` correctly but stops overwriting `cluster`). Caught: 3 of 27 scenarios
   failed, including both scenarios written directly for mark attachment and the RTL caret-position
   scenario (which depends on `clusters()`/`caret_offsets()` collapsing the kasra into kaf's
   cluster).
2. **The RTL pen starting at `x` instead of `x + buffer_advance`** (so the first buffer entry
   lands at the *left* end instead of the right). Caught hard: 5 of 27 scenarios failed, including
   both render scenarios that use an RTL run and the scenario written directly for it ("Right to
   left, the first glyph lands at the right end").
3. **A ligature result fed back into the rules** (rewrote `apply_ligatures` to replace a matched
   span in place and re-scan from the *same* position, so a freshly-produced ligature glyph name
   could in principle match another rule). **Not caught by any scenario.** Neither Roboto's two
   ligature rules (`f i → f_i`, `f l → f_l`) nor DejaVu's eight lam-alef rules have a rule whose
   left side names another rule's *result* glyph (nothing rewrites into `f_i`+`X` or
   `lam_alef.fina`+`X`), so re-scanning after a substitution is behaviorally identical to skipping
   past it for every string any scenario tries. This is the ligature-chapter's version of chapter
   18's justify-last-line gap: the prose states the "never fed back" rule explicitly and correctly
   (§19.3: "A result is never fed back into another rule"), but no scenario's font data actually
   has two rules that chain, so the rule is asserted but not exercised. A scenario needs either a
   font with a genuine two-step chain (e.g. a made-up rule `a b → ab` plus `ab c → abc`, fed the
   string `"abc"`) or, more realistically for the real font data on hand, a check that a matched
   ligature's *own result name* never appears as a match target in a *subsequent* iteration when
   there happens to be a rule that could (superficially) apply to it, to prove the implementation
   isn't just getting lucky.

---

## Concrete changes I'd make

1. State draw order in every render's pseudocode/prose the same way `break_lines` states its
   greedy algorithm — "glyphs paint over hairlines" (or the reverse) is a one-clause addition per
   render and would have skipped four of the seven render-iteration cycles in this session
   entirely.
2. Say "outline"/"hairline" instead of bare "box" wherever a chapter means a stroked rectangle,
   consistent with the vocabulary chapters 16-18 already established.
3. Add one scenario per chapter that exercises the "never fed back" / "last line stays left" rules
   stated in prose but never actually forced to matter by the given font data or paragraph text —
   both are currently assertions the reader has to take on faith, not facts a wrong implementation
   would get caught contradicting.
4. Spell out the RTL caret-position pen-value (right edge vs. left edge / placement vs. checkpoint)
   in one more sentence in §19.6, the way each of chapter 18's four alignments gets its own clause.
5. (Repo-wide, not chapter-specific.) Fix `test_runner.py`'s step-line whitespace collapsing —
   already done as part of this session's catch-up, see above — since it silently corrupts any
   future scenario that pins a string literal containing consecutive spaces.

## Timing

All nine renders together take under 4 seconds (`plate_18` ~1.8s and `plate_19` ~1.3s dominate;
the other seven are all well under 0.5s each). The full 1-19 suite (611 scenarios, including every
render scenario) runs in a little over a minute from a cold process.
