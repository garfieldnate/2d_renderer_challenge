# Feedback: chapters 20 and 21 (Python)

Written cold, from `chapter-20.html`, `chapter-21.html` and `features/chapter2[01]-*.feature`
alone, on top of the existing chapters 1-19 Python implementation. I did not read any other
reader's code or the book's reference implementation.

## Result

617 scenarios from chapters 1-19 (616 plus one new chapter 13 catch-up scenario) all pass.
Chapter 20 adds 83 scenarios (document 3, numbers 5, pathdata 12, building 10, transform 6,
style 7, shapes 6, viewbox 7, paint 8, walker 8, groups 8, plate 3). Chapter 21 adds 21
(bounds 3, counting 3, tiles 6, spans 3, simd 2, plate 4). **Total: 721 scenarios, 720 pass, 1
fails** (see Failures).

Renders, `max_channel_difference` against `reference/`:

| chapter | file | diff | notes |
|---|---|---|---|
| 20 | `harbor.ppm` | 0 | |
| 20 | `rose.ppm` | 0 | |
| 20 | `tiger.ppm` | 0 | |
| 20 | `aspect_demo.ppm` | 185 | no shipped source; see Failures |
| 21 | `work_map.ppm` | 0 | |

Every chapter 2-19 render is still byte-exact (re-diffed all of them after this pass's
`test_runner.py` and chapter 13 fixes, to make sure neither regressed anything: no diffs).

## Catch-up

Ran `./tools/readers.py`-equivalent by hand (there's no `tools/` in this scratch directory, so I
just re-ran the existing suite before touching chapter 20): one new scenario had appeared in
`chapter13-stroke.feature` since this code last ran — "A round cap is a semicircle of sixteen
steps, whatever the rounding" — and it failed on the existing code. `_arc_steps` computed
`ceil(delta / (pi/16))` with no epsilon; on this machine a semicircle's floating-point sweep comes
out as `16.000000000000004`, which `ceil`s to 17 instead of 16, giving a round cap 17 steps
instead of the promised 16. Fixed by subtracting `0.000000001` before the ceiling, matching
exactly the formula the chapter's own prose states (`n = max(2, ceil(|delta| / (pi/16) -
0.000000001))`) — the existing code had implemented the rule from an earlier draft that didn't
have the epsilon written down yet. All 617 chapter 1-19 scenarios pass with the fix; no other
regressions.

Chapter 15's reference images were also flagged as possibly having changed "by at most 1". I
regenerated all four (`even-marks.ppm`, `dash-strip.ppm`, `spiral-dashes.ppm`, `plate-15.ppm`) and
diffed them: all four are 0. No drift found in this copy of `reference/`.

## Ambiguities

- **Shape geometry attributes and percentages/units.** §20.6 says a *style* number "may carry
  `px`, which means nothing", and §20.9 says a *gradient coordinate* may be "a number or a
  percentage". Neither §20.7 (basic shapes) nor §20.3 (path data) says whether `x`/`y`/`width`/
  `height`/`cx`/`r`/etc. on a shape can carry `px` or `%`. I read them as bare numbers only
  (`read_number` straight off the attribute text), since no scenario exercises a percentage or a
  `px` suffix on a shape attribute, and real SVG's percentage-of-viewport behavior for these
  isn't described anywhere in the chapter. If a scenario is added later that does test this, my
  guess is the more conservative one to walk back.
- **`own_layer`'s pseudocode is shorthand for something written out in prose right below it.**
  §20.12's pseudocode has `own ← style.opacity or (clip and el is svg or g)`, which read literally
  (`style.opacity` as a truthy Python value) is nonsense — every element's opacity is a positive
  number, always truthy. The paragraph directly under it spells out the real rule ("an element
  whose opacity is below 1, ..."), which is what I implemented. Not really an ambiguity once you
  read both, but the pseudocode alone would mislead a reader who skipped the prose.
- **`aspect_demo()`'s drawing.** See Failures — this isn't so much an ambiguity as a real gap:
  the chapter gives no source for this render at all, unlike every other one.

## Hard to translate

- **Comparison steps with raw XML/text containing `=` inside quotes.** Nothing to do with
  Python specifically — this is a `test_runner.py` limitation the earlier chapters never
  exercised. Chapter 20 is the first chapter whose scenarios inline literal markup directly in a
  one-line `Then <expr> = <expected>` step, e.g.
  `Then length(shape_commands(parse_xml("<rect width='10' height='6' ry='-3'/>"))) = 5`. The
  existing `parse_comparison` was a single non-greedy regex
  (`r'^(.*?)\s*(...)\s*(.*?)...$'`) that happily split on the *first* `=` it found in the whole
  string — the one inside `width='10'` — rather than the real comparison operator at the end,
  and then failed to `eval` the resulting garbage left-hand side with "unterminated string
  literal". Fixed by replacing the regex with a small character-by-character scanner that tracks
  which quote (if any) it's inside and the bracket/paren depth, and only treats `=`/`<`/`>`/`≤`/
  `≥`/`≠`/`±` as real when they're outside both. This isn't a chapter bug; it's a step shape the
  runner hadn't needed to handle before, in the same spirit as the chapter 19 whitespace-collapse
  fix noted in the existing README.
- Everything else translated directly: XML parsing onto `xml.etree.ElementTree`, the six-op path
  command records, matrices, the style cascade, gradients, the walker, tiles — all of it maps
  onto plain Python data (lists, dicts, small classes with public attributes) the same way
  chapters 1-19 already did. No step shape needed the runner taught anything new besides the
  parser fix above.

## Failures

**`chapter20-viewbox.feature` / "One drawing, five ways to fit it" (`aspect_demo`).** Every other
image render in chapters 20-21 is driven by a file the reader is handed
(`reference/chapter-20/{harbor,rose,tiger}.svg`) or by numbers stated in the prose. `aspect_demo()`
is neither: §20.8 says only "One portrait drawing in five landscape viewports" and gives the
figure caption ("The dark border is the viewBox's edge, stroked two user units wide") but never
states the drawing's own geometry (viewBox size, circle center/radius, the two-mountain shape,
colors) or the layout of the five panels on the 660×110 canvas. I reverse-engineered it by
scanning `reference/chapter-20/aspect_demo.ppm` for pixel transitions (row/column scans at several
Y values, per panel) and solved for:
- Canvas layout: a 10px `PAPER`-colored margin before, between and after five 120×90 content
  cells (`10 + 5×(120+10) = 660` wide, `10+90+10 = 110` tall) — not `132×110` panels with no
  margin, my first (wrong) guess.
- The drawing: `viewBox="0 0 60 80"`, a background rect `#f4d8a8`, a circle `cx=30 cy=26 r=14`
  `#e8553a`, two triangles (a "mountain range") at `#3b5b7a` with vertices approximately
  `(2,79)-(22,44)-(49,79)` and `(23,79)-(44,52)-(59,79)`, and a border `rect x=1 y=1 width=58
  height=78` stroked `#1a1a1a` width 2 (inset by half the stroke width so the *outer* edge of the
  stroke lands exactly on the viewBox's true edge, which is what makes the border read as "the
  viewBox's edge" in the caption).

This reconstruction hits **every named `ppm_pixel` assertion in the scenario exactly** (all seven:
`(70,39)`, `(240,50)`, `(280,50)`, `(335,50)`, `(150,95)`, `(590,27)`, `(5,5)`), and reads
correctly at thumbnail scale side by side with the reference. But the scenario's final assertion,
`max_channel_difference(p6, ref) ≤ 1` over the *whole* image, still fails: **actual 185, expected
≤ 1**. The remaining error is almost certainly in the triangle/circle vertex coordinates being
close-but-not-exact (I measured them to about ±1-2 device pixels, i.e. ±0.5-1 user unit, which is
the resolution raster measurement can give you) — the true drawing was very likely authored with
clean integers I couldn't recover exactly from a raster scan. This is the book's fault, not the
reader's or the reference's: reproducing a reference image byte-for-byte from a raster alone,
with no source, is not something any reader should be expected to do, and the chapter should
either ship an `aspect_demo.svg` the way it ships the other three documents, or state the
drawing's geometry in prose the way every other pinned render in this book does (CLAUDE.md's own
rule: "every suggested implementation is specified"). I left the scenario in place, failing
honestly, rather than weaken the tolerance or delete it.

## Prose problems

- **§21.3, the tile classification rule is easy to misread as "only check the rows you have
  data for."** The prose says: "look at the running sum arriving at the tile's left edge in each
  of its rows... if on every row it is within 0.000001 of the same whole number n, [it's]
  solid/empty... and if not, partial." A reader's first instinct (mine, on the first draft) is to
  scope that "every row" check to the tile's rows *within the path's own bounds*, since that's
  where the accumulator has any data and it's the natural thing to loop over after you've already
  built `fill_bounds`-style windowing in §21.2. That's wrong, and wrong in exactly the way the very
  next paragraph warns about ("The rows can disagree with no deposit in sight... a classifier that
  only looked at each tile's top row painted those tiles solid down to y = 223") — except the bug
  isn't about only checking the *top* row, it's about only checking rows *inside the bounds
  window*, silently treating the tile's rows outside that window as if they didn't exist instead
  of comparing them (correctly, as 0) against the rows that do have data. `classify_tiles`'s own
  scenario, "A square leaves its middle tiles solid", catches this immediately and unambiguously
  (see Mutation results) — it's a well-designed scenario. But the prose's own worked example (the
  harbor's hills, y=212 through a tile band) describes the *symptom* precisely without stating
  the general rule precisely enough to keep a reader from taking the shortcut in the first place.
  I'd add one sentence: "check every row of the tile's own 16-pixel extent, not just the rows the
  path's bounds happen to cover — a row outside the bounds carries an arriving sum of exactly 0,
  and that's a real data point to compare, not a row to skip."
- **§21.7's pseudocode for `fill_path_tiled`'s resolve loop** ("for every partial tile, for every
  row r of it: ... for every column x of it: area, cover ← cells[x, r], or 0, 0") does state the
  full-tile-not-just-bounds rule correctly, in contrast to the classification prose above — I
  used it to catch my own mistake (see Mutation results, this was the same bug in two places, and
  the pseudocode being unambiguous is what let me be sure of the fix). It would be worth pointing
  the classification paragraph at this pseudocode explicitly, since the two are the same
  principle from two different entry points into the chapter and only one of them spells it out
  concretely.
- No other place needed re-reading twice, and I didn't find a wrong factual claim in either
  chapter's prose. §20.4's arc-to-cubic control point formula, §20.8's viewBox arithmetic, §20.9's
  gradient-in-a-matrix construction, and §21.2's bounds formula all worked exactly as stated on
  the first attempt against every scenario, including the tiger/harbor/rose byte-exact checks,
  which is the strongest evidence a formula is stated completely.

## Mutation results

Chapter 20:
1. **`parse_transform`'s multiplication order flipped** (`result = fn * result` instead of
   `result = result * fn`, applying functions left to right instead of right to left). Caught
   immediately by `chapter20-transform.feature`'s "A list applies right to left".
2. **Skip walking the stroke's device path back through the matrix's inverse** (stroke directly
   in device space instead of user space, chapter 4's trap again). Caught immediately by
   `chapter20-walker.feature`'s "A squashed transform squashes the pen" and "Dashes are measured
   in user space too".
3. **Flatten a cubic (`C`) in user space, then transform the flattened points, instead of
   transforming the curve and flattening the result** (violates chapter 8's "transform then
   flatten" rule, but only for `C`, not `Q`). **This is the valuable finding**: every scenario in
   `chapter20-building.feature`, including the one named exactly for this rule ("Curves are
   flattened after the transform, so a bigger curve gets more points"), still passed — because
   that scenario's own example path uses a `Q` command, not `C`, and I only mutated the `C`
   branch. Every other chapter 20 unit scenario passed too. The mutation was caught only by
   rendering the actual tiger (`max_channel_difference` 101 against a budget of 1) — the tiger's
   240 paths are almost entirely cubics. A reader who introduces this exact bug and only runs the
   fast scenarios, skipping the expensive plate render, would ship it. Concrete fix: add a `C`-based
   twin of that scenario to `chapter20-building.feature` (e.g. the same quarter-circle-ish cubic
   at identity and at `scaling(10,10)`, checking the flattened point count grows).

Chapter 21:
4. **The tile classification bug described in Prose problems above** — found live, in my own
   first draft, not as a deliberately-introduced mutation, but it's the same category of finding:
   `chapter21-tiles.feature`'s very first scenario ("A square leaves its middle tiles solid")
   failed the instant I ran it, with `t[0]` (expected all `"partial"`) coming back
   `["partial","solid","solid","partial"]`. Confirms the scenario earns its place exactly the way
   CLAUDE.md's testing notes describe.
5. **`draw_tiled` copies a solid tile whenever the paint is solid, without checking `alpha == 1`**
   (so a half-opacity fill would still get a bit-exact copy instead of a blend, at the wrong
   alpha). Caught immediately by `chapter21-spans.feature`'s "At half alpha nothing is copied"
   (`st.copies` came back 1024 instead of 0).
6. **`fill_bounds` computes `x1` with `ceil(maxx)` instead of `floor(maxx) + 1`** (wrong for a
   fractional `maxx`, e.g. `20.0` exactly: `ceil` gives 20, but column 20 needs to be included).
   Caught immediately by `chapter21-bounds.feature`'s own direct scenario, "The window under a
   path, in whole pixels".

All six mutations were reverted after confirming the failure; the suite is back to 720/721 clean.
`composite_span4`'s "no fused multiply-add" trap (§21.5) genuinely cannot be demonstrated as a
mutation in Python: Python's `+`/`*` never fuse regardless of how the four lanes are grouped, so
`composite_span` and `composite_span4` are trivially bit-identical here by construction, and no
mutation of "add the fusing back in" is expressible without hand-rolling an FMA — this trap is a
compiled-language-only finding, and I've said so in the README rather than paper over it with a
weakened scenario.

## Concrete changes I'd make

1. Ship `reference/chapter-20/aspect_demo.svg` alongside the other three documents (or state the
   drawing's geometry in prose), so the scenario is actually reproducible by a reader instead of
   requiring pixel archaeology. See Failures for exactly what's missing.
2. Add a `C`-based twin to `chapter20-building.feature`'s "flattened after the transform" scenario
   (see Mutation results, #3) — the current one only exercises `Q`, and a `C`-specific
   transform-order bug sails through every fast scenario in the chapter and is only caught by the
   full tiger render.
3. §21.3's classification prose could point at §21.7's `fill_path_tiled` pseudocode explicitly
   (which states the full-tile-not-just-bounds rule unambiguously) rather than leave the reader to
   infer it a second time from a worked example about a symptom.
4. Minor: the chapter 21 timing table's `tiled` blends column for the tiger (407,274) doesn't
   quite match what a straightforward reading of the tiled draw path produces here (407,750, a
   difference of 476 pixels out of 407k) — see Timing. Not scenario-visible (only `cells` and
   `copies` are pinned for the tiled tiger scenario), so I can't tell whether it's a genuine
   boundary-condition difference between implementations or just a rounding choice the prose
   doesn't pin down; flagging it in case it's worth a scenario that would pin `blends` too.

## Timing

My own work: roughly one long session — reading both chapters and every feature file in full,
implementing chapters 20 and 21 essentially in one pass (the whole engine rendered `tiger.svg`,
`harbor.svg` and `rose.svg` byte-exact on the *first* attempt against the reference PPMs, before
I'd even wired up chapter 21), then the tile-classification bug above, the `test_runner.py` parser
fix, and the `aspect_demo` reconstruction, which was the single most time-consuming part of the
whole pass.

Render times, this machine, this implementation (`render_svg` / `render_svg_with(..., "legacy", ...)`,
which is what chapters 20's own `harbor()`/`rose()`/`tiger()` use):

| document | mode | cells | blends | copies | time |
|---|---|--:|--:|--:|--:|
| tiger | whole | 61,762,500 | 1,668,160 | 0 | 21.1 s |
| tiger | bounded | 1,395,287 | 813,594 | 0 | 1.5 s |
| tiger | tiled | 816,480 | 407,750 | 207,872 | 3.1 s |
| harbor | whole | 14,592,000 | 523,267 | 0 | 10.0 s |
| harbor | bounded | 737,160 | 427,449 | 0 | 5.6 s |
| harbor | tiled | 259,840 | 338,569 | 80,640 | 6.8 s |
| rose | whole | 27,840,000 | 1,165,469 | 0 | 15.1 s |
| rose | bounded | 1,076,869 | 660,431 | 0 | 6.0 s |
| rose | tiled | 543,744 | 532,220 | 2,048 | 7.3 s |

Every `cells` count matches the chapter's own quoted table exactly (all nine numbers, both
documents, all three modes) — strong evidence the bounds/tile algorithms are exactly what the
book intends, independent of language. `bounded` is a clean, large win here too (14-18×), matching
the book's own Python numbers within the same order of magnitude. `tiled` is the surprise: in
this pure-Python implementation, `tiled` is consistently *slower* than `bounded` (3.1s vs 1.5s for
the tiger; 6.8s vs 5.6s for the harbor; 7.3s vs 6.0s for the rose), despite resolving far fewer
cells, because classifying tiles (a Python-level nested loop scanning every cell of every
candidate tile, twice — once for the deposit check, once for the running-sum check) costs more
per shape than the cells it saves are worth once you're already down to only the shape's own
bounded window. The book's own Python reference apparently doesn't hit this (its tiger table is
whole 29.0s → bounded 1.9s → tiled 1.6s, `tiled` faster than `bounded` there too) — either its
tile classifier is written with less per-cell Python overhead than mine (a sparse dict keyed by
`(row, col)` walked once per shape, rather than my dense-accumulator-plus-two-full-scans
approach), or a genuinely sparser storage scheme (as the chapter's own prose recommends and I
did not fully implement — I used a dense `Accumulator` scoped to the shape's bounds rather than
a true sparse map, which is the one place I knowingly took the simpler-but-not-truly-sparse route
the "storing only the cells deposited into" line describes). This is worth knowing if this code
is ever used as a base for a "make it fast" exercise in Python specifically: the chapter's central
claim (tiling helps, though less than bounding) holds for *cell counts*, which are
language-independent, but not for *wall-clock time* in an unoptimized pure-Python tile classifier.
