# Reader feedback — Rust, chapters 16-17 (plus the chapter 13 catch-up)

Cold read from `chapter-16.html`/`chapter-17.html`, their `features/*.feature`
files, and the code already in this directory. I did not read, and could not
read, anything outside this staged directory — no `plan.html`, no reference
implementation, no other reader's work.

## Result

- **Catch-up**: 1 new scenario (`chapter13-degenerate.feature`), 6/6
  scenarios green after the fix (was 5/6 with the fix missing).
- **Chapter 16**: 5 feature files, 23 scenarios, 23/23 green.
  Renders: `glyph.ppm`, `plate-16.ppm`, `composite.ppm`, `sizes.ppm`,
  `flip.ppm` — `max_channel_difference` = **0** against every reference
  (not merely ≤ 1).
- **Chapter 17**: 5 feature files, 19 scenarios, 19/19 green.
  Renders: `subpixels.ppm`, `smoothing.ppm`, `lcd.ppm`, `plate-17.ppm` —
  `max_channel_difference` = **0** against every reference.
- Full suite (`cargo test --release`, chapters 1-17): 522 tests passed, 0
  failed, across 93 test binaries.
- `cargo run --release --bin render_all`: all 61 renders in ~1.1s wall time
  (see **Timing**).

## Catch-up

`chapter13-degenerate.feature` gained "A closed subpath that ends where it
began has no zero-length closing segment" since this code last ran. Before
the fix, this scenario **failed**: a closed square built as five explicit
points (the fifth repeating the first) plus `close()` produced a
zero-length closing segment on top of the real one (`(0,0)` to `(0,0)`),
whose direction is `0/0` — `stroke_to_path` still ran (no panic, since
`normalize` of a zero vector just produces NaNs that get pushed silently
into geometry no scenario happened to probe until this one), but the
resulting outline had `9` subpaths instead of `8`, and `polygon_area`
differed from `-84`. §13.2's pseudo-code and §13.4's trap changed to say
"if closed and pts ends where it began, drop that end too" — implementing
exactly that (drop the duplicate last point when it coincides with the
first, before building segments, only when `closed`) fixed it and needed
no other change. Chapters 1-15 were otherwise still fully green; nothing
else regressed.

## Ambiguities

- **The on-curve flag's JSON type.** §16.1's schema says a contour point is
  `[x, y, on]` with no type given for `on`. The real font
  (`roboto.json`) writes JSON booleans (`true`/`false`) — confirmed by
  reading a few bytes of the file. But the hand-written-font scenario in
  `chapter16-composites.feature` ("A font can be written by hand...") writes
  `1`s and `0`s instead: `"contours": [[[0, 0, 1], [100, 200, 0], [200, 0,
  1]]]`. A JSON parser that only accepts booleans crashes on that scenario.
  I made the loader accept either (any nonzero number counts as on) and
  named the accessor `as_flag` to say so. This should be stated in prose,
  or the scenario's literal should use `true`/`false` for consistency with
  the real file it's meant to emulate.
- **Shelf-packing atlas: no pseudo-code at all.** §17.2 describes shelves
  in prose only ("Bitmaps go left to right along a shelf whose height is
  set by its first bitmap; when the next one doesn't fit on the shelf, a
  new shelf opens below the tallest so far"). I initially read "the tallest
  so far" as tracking a global high-water mark across every shelf ever
  opened, which gives the wrong y-coordinate for the third shelf in the
  scenario. Reverse-engineering the actual rule from the seven `atlas_add`
  calls (see the `README.md`'s chapter 17 notes) took several attempts: the
  correct behavior is that a shelf's height, once set by its first bitmap,
  is by construction its own tallest bitmap (a taller one could never have
  fit), so "the tallest so far" just means "the shelf being closed", and a
  bitmap that fails even against a *fresh, empty* shelf (too wide for the
  atlas, or too tall to fit at that shelf's `top`) leaves that empty shelf
  in place for the next attempt rather than opening yet another one. This
  is exactly right, but only because the scenario is dense enough to pin
  it — a reader without that scenario's exact sequence (including the
  `2 × 2` bitmap landing at `(0, 16)`, not `(8, 8)`) could easily ship a
  plausible-looking packer that fails only on this one case. I'd add one
  sentence to the prose spelling out the "an empty shelf that still
  doesn't fit stays open, doesn't advance again" rule directly, since it's
  the one non-obvious branch.
- **`draw_text`'s return value and exact signature.** The prose says
  "`draw_text` steps the pen by it, each glyph at its nearest quarter" but
  no scenario calls it directly or pins its signature. I guessed
  `draw_text(canvas, font, text, size, x, y, color, linear) -> f64` (pen's
  final x), used only internally by `smoothing_demo`. Since nothing pins
  it, any reasonable shape would pass every scenario; I'd add at least one
  scenario exercising it directly (e.g. rendering two glyphs and checking
  the second one's device-space position), the same way `pen_advance` is
  pinned on its own.

## Hard to translate

- Nothing in these two chapters required inventing new Gherkin-runner step
  shapes — every scenario mapped onto plain function calls, tuple/`Option`
  comparisons, and the same `coverage_at`/`ink`/`ppm_pixel`/
  `max_channel_difference` machinery already used since chapter 2. The one
  translation choice worth naming: `Font`, `Glyph`, `Component` and
  `Bitmap` are plain public-field structs (matching this project's existing
  style for `Canvas`/`Path`/`Curve`/etc.), so a scenario's `font.units_per_em`
  or `b.width` becomes a direct field read in Rust rather than an accessor
  call.
- `f64` isn't `Hash`/`Eq`, so `GlyphCache`'s key (`(name, size, subpixel)`)
  had to go through `size.to_bits()`. Fine for this book (every scenario
  passes the identical literal back in), but worth flagging as a place a
  language without that escape hatch (or a reader who doesn't think of it)
  could stall.

## Failures

None outstanding. Two failures came up mid-implementation and were both my
own bugs, fixed before finishing (not the book's):

1. **`implied_points` missing entirely** was never wrong, but the very
   first version of `flip_trap`'s baseline hairline used chapter 5's
   `polygon(&[a, b])` (always closed) for what should have been an *open*
   two-point line. A closed 2-point subpath makes `stroke_to_path` emit
   both the forward segment and an explicit reverse segment back to the
   start, doubling the rendered width. Caught immediately by
   `max_channel_difference` on `flip.ppm` (51, not ≤ 1) — no unit scenario
   pins the hairline's width directly, so a render-level scenario was the
   only thing that could have caught this, and did. Fixed by building the
   line with `move_to`/`line_to` and no `close()`.
2. Initial `component_matrix` letter order (before double-checking against
   the four `point()` scenarios in `chapter16-composites.feature`) was
   correct on the first attempt, but I want to flag that this is exactly
   the kind of five-number juggle ("a slightly surprising order," the
   chapter's own words) that's easy to get backwards; see **Mutation
   results** for how weak the real-glyph renders are at catching that
   specific mistake.

## Prose problems

- **The figure `<script>` blocks are a complete, runnable, byte-for-byte
  reference implementation of every function in the chapter**, including
  ones the prose never gives pseudo-code for (`glyph_plate`,
  `composite_demo`, `sizes`, `flip_trap`, `subpixel_strip`,
  `smoothing_demo`, `lcd_plate`, and the whole atlas/cache/embolden/LCD
  machinery of chapter 17). This is the same "reader cold-read figure-JS
  leak" flagged in earlier rounds: a reader who opens dev tools (or, as
  here, just reads the HTML source, which any reader legitimately can) can
  transcribe rather than derive. I did read it — I could hardly not, since
  it's plain text in the file I was told to read in full — and used it to
  verify my own derivation from the prose+scenarios, not as a substitute
  for reading the prose. But it means the "no pseudo-code for `sizes`
  needs to be reverse-engineered from pinned pixels" framing (used
  honestly in chapters 7 and 12's own `README.md` notes) doesn't really
  apply here: the JS *is* the pseudo-code, just not printed as such. Worth
  either printing it as pseudo-code properly (so a reader is meant to see
  it) or stripping enough of it that a reader can't just paste it in.
- §17.2, no pseudo-code for the atlas at all (see **Ambiguities** above) —
  every other named function in these two chapters gets at least a
  paragraph walking through the exact rule; the atlas gets two sentences.
- §17.3's claim "A third of a pixel is plenty" for stem darkening is a
  judgment call, not a fact pinned by any scenario — fine as prose, but if
  a future scenario ever wants to test "is 1/3 actually a good default,"
  there's nothing to check it against besides the plate looking okay.
- Everything else read cleanly. I did not find any factual error in either
  chapter's prose against what the scenarios or the reference font
  actually contain (the vertical metrics, glyph counts, `eacute`'s
  component structure, etc. all matched exactly on the first attempt).

## Mutation results

Six deliberate mistakes, introduced one at a time in `src/lib.rs`, tested,
and reverted. `git status`-equivalent (a plain `diff` against the backup
copy) confirmed a clean revert before moving to the next.

1. **`implied_points` drops the wrap-around off-curve/off-curve pair**
   (loops `0..n-1` instead of `0..n`, appending the last point unchanged).
   Caught by exactly **one** scenario in the whole suite: "A loop of
   off-curve points implies a midpoint between each pair" (a synthetic
   4-point all-off-curve square), which goes from 8 implied points to 7.
   **Not caught** by "The dot of the i is mostly implied" — the dot's own
   last→first pair is off→on, not off→off, so its wrap doesn't need an
   implied point. **Not caught by any render** (`plate16.rs`'s 5 scenarios
   all stayed green): none of `a`, `o`, `eacute`/`e`/`acute`, `R`, or `g`
   happens to have an off-curve point immediately followed (wrapping) by
   another off-curve point at the seam. This is the strongest finding in
   this round — a real bug in the most literal reading of the wrap-around
   rule that every actual glyph in the plates is silent about.
2. **`component_matrix`'s `b` and `c` columns swapped** (`matrix3(t[0],
   t[1], t[4], t[2], t[3], t[5], 0, 0, 1)` instead of the correct
   `t[0], t[2], t[4], t[1], t[3], t[5], ...`). Caught immediately by "A
   component transform is a matrix" (2 of its 4 assertions use nonzero `b`
   or `c`) and by the hand-written-font scenario's `"twice"` glyph (whose
   second component has both `b` and `c` nonzero). **Not caught by any
   render**: `eacute`'s only real component transform in Roboto is `[1, 0,
   0, 1, 340, 0]` — pure translation, `b = c = 0` — so swapping them is
   invisible to `composite_demo`/`plate_16`.
3. **The y-flip applied a second time** in `glyph_path` (multiplying by an
   extra `scaling(1, -1)` on top of `text_matrix`'s own, which cancels it
   out — net effect identical to forgetting the flip). Caught hard:
   `the_counter_is_a_hole` (ink and coverage values all wrong) and **every
   single** `plate16.rs` scenario (`glyph_plate`, `plate_16`,
   `composite_demo`, `sizes`, `flip_trap` all fail their pixel probes and
   `max_channel_difference`). The one thing this mutation does *not* touch
   is `contour_path`, a separate function `glyph_path` doesn't call — so
   the "two contours wind opposite ways" scenario (which uses
   `contour_path`, not `glyph_path`) stays green, correctly, since that
   code path was never mutated.
4. **`glyph_bitmap`'s left/right edges ignore the quarter-pixel shift**
   (bounds computed from `bb.0 * s`/`bb.2 * s` without adding `dx`, while
   the fill's own origin still uses `dx - left`). Caught immediately by "A
   quarter to the right moves the ink, not the amount of it" (`b1.left`
   assertion) and by "A different quarter or size is a different entry"
   (`b.left`). Also caught by two `plate17.rs` render scenarios
   (`subpixel_strip` and `smoothing_demo`, both of which position glyphs at
   fractional pen positions) — this one didn't survive anything.
5. **`lcd_filter` pads with the edge value instead of zero** (`v[0]`/
   `v[n-1]` instead of `0.0` beyond the ends). Caught by exactly **one**
   scenario: "The filter's taps sum to one and spreads a spike over three
   stripes" (`lcd_filter([0, 0, 3, 0, 0])` now comes out wrong at the
   edges). **Not caught** by "Three coverages per pixel carry three times
   the ink" or "Each channel takes its own stripe" (both use a glyph whose
   ink never reaches column 0 or the last column of its own LCD buffer).
   **Not caught by any render** — `lcd_plate`/`plate_17` both stayed green.
   This is the second-strongest finding: the padding rule is only ever
   checked by one hand-built array, never by anything derived from a real
   glyph.
6. **The atlas never opens a new shelf** (the `else` branch that advances
   `shelf_top`/resets `shelf_height`/`cursor_x` deleted; a bitmap that
   doesn't fit the current shelf just returns `None` forever after).
   Caught immediately and only by "Shelf packing places bitmaps left to
   right, then opens a new shelf" — the third `atlas_add` call, which needs
   a second shelf, now returns `None` instead of `Some((0, 8))`. No render
   in either chapter uses the atlas at all (none of `glyph_plate`,
   `composite_demo`, `sizes`, `flip_trap`, `subpixel_strip`,
   `smoothing_demo`, or `lcd_plate` build one), so this mutation's only
   possible witness was that one scenario, and it worked.

**Summary**: every mutation was caught by at least one scenario, so nothing
survived outright. But three of the six (#1, #2, #5) were caught by
exactly one synthetic unit scenario apiece and by **zero** render/plate
scenarios, because the real font and the real plates happen not to exercise
the exact code path each bug lives in (no off-off wrap at a Roboto glyph's
seam; `eacute`'s only real transform has `b = c = 0`; no glyph's LCD ink
touches its buffer's edge column). That's the strongest single piece of
evidence in this round that a scenario built from a real font glyph is not
a substitute for a scenario built by hand to force the exact case — the
book already does this in a few places (the hand-written "bump"/"twice"
font in chapter 16, the four hand-picked rectangles in chapter 17's atlas
scenario), and this round is one more argument for keeping that pattern
rather than trusting Roboto's own glyph set to exercise every branch.

## Concrete changes I'd make

1. Add one sentence to §17.2 spelling out that a shelf which still doesn't
   fit a bitmap even when freshly opened (empty) stays open for the next
   attempt, rather than opening yet another shelf — see **Ambiguities**.
2. Either state explicitly that the on-curve flag may arrive as `0`/`1` as
   well as `true`/`false`, or make the hand-written-font scenario use
   `true`/`false` to match the real file it's modeling.
3. Add a scenario that exercises `implied_points`/`contour_curves` on a
   contour whose *actual* wrap (last point to first point) is
   off-curve/off-curve using a real glyph, not just the synthetic 4-point
   square — or accept that this is intentionally a "translate the rule
   correctly, even though nothing you render will notice if you don't"
   test, which is a fine thing for a book to do on purpose but is worth
   saying so.
4. Pin `draw_text` directly with its own scenario (see **Ambiguities**).
5. Consider not shipping the full JS source in every figure's `<details>`
   block for chapters this algorithmically dense — or, if the intent is
   that readers can consult it after implementing, say so, since right now
   nothing distinguishes "here is a description of the effect" figure JS
   from "here is the reference implementation you could paste in."

## Timing

`cargo run --release --bin render_all` (61 renders, chapters 1-17, cold
`cargo build --release` already done): **~1.1-1.3s** wall time for the full
run. Chapter 16/17 alone (9 of the 61 renders — `glyph.ppm`, `plate-16.ppm`
at 640×640, `composite.ppm`, `sizes.ppm`, `flip.ppm`, `subpixels.ppm`,
`smoothing.ppm`, `lcd.ppm`, `plate-17.ppm` at 288×384) is not separately
timed but is not the dominant cost — chapter 2's brute-force coverage and
chapter 3's twelve-ray fan (already noted in this `README.md`) are still
the slowest parts of the whole run. `cargo test --release` for the full
suite (522 tests) completes in well under a second of test time once
built.
