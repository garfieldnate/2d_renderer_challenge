# Reader feedback — Rust, chapters 22 and 23

Cold read from `chapter-22.html`/`chapter-23.html` and `features/chapter22-*.feature`/
`features/chapter23-*.feature` alone, on top of the existing chapters 1-21 code. Every
scenario was translated, implemented, and is green; every named render is byte-identical
to `reference/`. Praise is kept to a minimum below; problems are not.

## Result

Chapter 22: 56 scenarios across 9 feature files (`grid`, `meet`, `split`, `sweep`,
`bentley`, `inside`, `combine`, `robust`, `plate`), all green, 53 `#[test]` functions
(one `Scenario Outline` — "what each operation calls inside", 4 examples — shares one
parameterized test, this project's established convention; everything else is 1:1).
`plate-22.ppm` and `seal.ppm`: `max_channel_difference` 0 against `reference/chapter-22/`
(verified twice — once through the project's own scenario, once independently with a
throwaway Python P6 parser, to rule out the tool checking itself).

Chapter 23: 36 scenarios across 9 feature files (`primitives`, `curves`, `render`,
`free`, `smooth`, `transform`, `atlas`, `compose`, `plate`), all green, 36 `#[test]`
functions. All nine named renders (`primitive_fields`, `error_map`, `fields_vs_paths`,
`fillets`, `transform_demo`, `atlas_corners`, `trap_shrink`, `title`) plus `plate_23`:
`max_channel_difference` 0 against `reference/chapter-23/`, independently verified the
same way.

Whole suite: 789 tests (`cargo test --release --offline`), 0 failures, chapters 1-23.

## Catch-up

Before touching chapter 22, I compared every `features/chapter{01..21}-*.feature`
scenario count (727, counting `Scenario Outline` rows) against the existing test suite
(700 passing `#[test]` functions) and got a 27-scenario gap that looked like it needed a
catch-up pass. Spot-checking about a dozen of the specific "missing" scenarios (by
grepping the corresponding `tests/*.rs` file for the scenario's actual assertions,
not just a slugified name match) turned up zero real gaps: every one was a naming
mismatch (`two_numbers_within_tolerance_are_equal` vs. a literal slug of "Two numbers
that differ by less than the tolerance are equal", or an `Outline` whose rows are
macro-generated with names like `encode_0_5` rather than counted 1:1) or an already-
collapsed loop test (chapter 9's Porter-Duff table, chapter 22's own inside-rule
scenario, above). I did not find a single scenario added to chapters 1-21 since this
code last ran that the existing suite doesn't already cover. No changes were made to
any chapter 1-21 test file or to `src/lib.rs`'s existing (pre-chapter-22) code.

## Ambiguities

- **`roboto()`**: chapter 23's features call it directly (`Given f ← roboto()`), but no
  earlier chapter defines a shared loader — every chapter 16-21 test file has its own
  private `font()` helper that calls `load_font(read_file(...))`. I added one public
  `roboto()` to `src/lib.rs` (used by chapter 22's `plate_glyph`/`text_path`/`struck_line`
  too, and by every chapter 23 scenario and render that needs Roboto), rather than
  duplicating the load in every test file. Guessed, not stated.
- **Ink colours**: chapter 22 and 23's prose says "chapter 16's paper", "chapter 7's
  orange ink", "dim", "pale", "magenta", "cyan" without repeating the RGB triples;
  I reused the exact values already established for those names in chapters 7/9/16
  (`orange = (0.9, 0.55, 0.1)`, `paper = (0.02, 0.02, 0.025)`, etc.) under new
  `CH22_*`/`CH23_*` constants rather than a single shared set, matching how every
  earlier chapter already keeps its own copy (`CH13_PAPER`, `CH16_PAPER`, ... are all
  the same three numbers, never a shared constant). Consistent with existing style, but
  worth a shared `PAPER`/`ORANGE` if a chapter 24 needs the same colours again.
  Confirmed correct by every render's `max_channel_difference = 0`.
- **`struck_line(n)`'s text string**: "the word Pathfinder n times with a space between"
  — read as `n` copies of "Pathfinder" joined by single spaces (`"Pathfinder Pathfinder"`
  for `n=2`, no trailing space). Confirmed by the pinned `length(segs) = 787` for `n=1`
  and the exact test counts for `n=1` and `n=2` in `sweep22.rs`/`bentley22.rs` — both
  matched on the first attempt, so the guess was right.
- **`title()`'s "moved by (8, 8)"**: read as applying only to the shadow pass (the first
  of the four `draw_effect` calls), not to all four — a drop shadow is conventionally
  offset from the glyph it shadows, and the render confirmed it. See **Prose problems**
  for the ordering ambiguity this sat next to.
- **`bake_box`'s `spread` type**: the feature passes `spread` as a plain number (`3`),
  used both as an integer texel margin (`floor(...) - spread`) and later as a float
  clamp bound (`clamped to ±spread`). Took it as `f64` everywhere, rounding once where a
  whole texel count is needed (`bake_box`'s `left`/`top`/`right`/`bottom`). No scenario
  exercises a fractional spread, so this is unverified beyond "every pinned integer
  spread scenario matches."

## Hard to translate

- **`Field`'s per-value combinators** (`field_offset`, `field_union`, `field_xor`, ...)
  wanted a generic private `field_zip<F: Fn(f64, f64) -> f64>` helper; Rust's closures
  and generics made this pleasant (one-liner per operation), no translation friction.
- **Exact arithmetic**: the chapter explicitly names Rust's `i128` for the two spots
  that need more than 64 bits (a crossing's numerator, ~2^59, and comparing two
  crossings' exact fractional positions in Bentley-Ottmann, ~2^100). Both fit
  comfortably; no translation difficulty, but it's the one chapter so far where "just
  use `f64`" is not an option and the book says so up front.
- **`Seg`/`Tuple` equality**: every earlier chapter compares `Tuple`s with `tuples_eq`
  (a tolerance), never `==`. Chapter 22's grid points are always exact whole numbers, so
  I added `PartialEq` to `Tuple`'s derive list (previously `Debug, Clone, Copy`) and gave
  `Seg` a derived `PartialEq` too, which let `assert_eq!`/`vec![...] == vec![...]` read
  naturally in the new tests. This is the one change to a pre-existing struct's derive
  list in this round; it's additive (nothing depended on `Tuple` lacking `PartialEq`)
  and every existing chapter still uses `tuples_eq` everywhere it always did.
- **Closures capturing borrowed data across `field()`'s generic `Fn` bound**: no
  lifetime friction in the end (the generated closures never outlive the `field(...)`
  call that consumes them), though `bake_msdf`'s per-channel closures capture the
  coloured-edge list via `Rc` out of an abundance of caution rather than proving a
  bare `&Vec<_>` borrow was sufficient — harmless, one extra small allocation per bake,
  not a translation blocker.

## Failures (fixed before this report)

Two real bugs were found and fixed during translation, both described in the
**Prose problems** and README's mutation-testing notes in more detail:

1. `stitch`'s furthest-right turn had its comparator's sign backwards on the first
   attempt (see below) — caught by 3 scenarios simultaneously
   (`turning_furthest_right_keeps_two_squares_that_touch_at_a_corner_apart`,
   `two_squares_four_ways`, `the_stars_crossings_become_corners`), fixed by flipping
   `ccw_half`'s two branches.
2. `title()` drew all four effects per glyph, in run order, instead of one full pass
   per effect — passed dimension/pixel-probe scenarios but failed the exact
   `max_channel_difference ≤ 1` check by 6 (not caught by any pinned pixel value, only
   by the render diff) — fixed by baking every glyph once up front and looping over
   effects in the outer loop, glyphs in the inner.

No scenario is failing or skipped as of this report.

## Prose problems

- **§22.5, "turning furthest right"**: "Face back the way you came; the arrow you want
  is the first one you meet turning counterclockwise from there." This is correct, but
  it reads as if "counterclockwise" means the ordinary geometric sense, and it's easy to
  apply that sense directly to `cross()`'s sign without noticing that this book's own
  `cross`/`orient` convention is *clockwise-positive on screen* — so "the counterclockwise
  side of `r`" is `cross(r, d) < 0`, not `> 0`. I got this backwards on the first
  attempt and two scenarios caught it immediately (see **Failures**). A single worked
  example in the prose (the same shape as one of the two touching squares, with the
  actual `cross` sign spelled out at the decision point) would have saved a wrong first
  implementation, the same way chapter 13's miter-length section already does for its
  own sign convention.
- **§23.9, "`draw_effect` four times over the run in order"**: ambiguous between "for
  each glyph, do all four effects" and "for each effect, do the whole run" — both are
  grammatically consistent readings of "four times over the run in order: [shadow],
  [glow], [fill], [outline]." Only the second matches the reference (see **Failures**).
  Worth a sentence: "draw every glyph's shadow, then every glyph's glow, then fill, then
  outline" or similar, since a drop-shadow effect specifically depends on painting order
  across the *whole run*, not just within one glyph, whenever glyphs are close enough to
  overlap (as adjacent serifs/counters can, at this plate's scale).
- **§23.7, `is_corner`'s `sin(3)`**: not wrong, but reads like a typo until you notice
  `sin(3 radians) = sin(pi - 3) = sin(~8.11 degrees)`, which is exactly the "turns by
  more than about eight degrees" the prose promises two sentences earlier. A footnote
  ("3 radians, not degrees — it's `sin` of the *supplement* of the turn angle, which
  happens to equal `sin` of the turn angle itself") would turn a moment of "is this a
  typo?" into "oh, clever," which is presumably the intent.
- **§22.2/§22.7, `meet`'s classification order isn't fully spelled out as an algorithm**:
  the prose gives four cases ("none"/"end"/"cross"/"touch"/"overlap" — five, actually)
  as a description of *what's true* in each, not the order to test them in when more
  than one condition could look true at once (e.g. a shared endpoint that's also
  collinear). The scenarios pin enough concrete cases that the right precedence
  (collinear-first, then proper-crossing, then touch, then shared-endpoint, then none)
  is inferable, but a reader translating this cold has to reconstruct that order by
  trial against the scenarios rather than reading it directly — chapter 22's own `combine`
  pseudo-code (§22.9) is a good model for how explicit the rest of the chapter usually is.

## Mutation results

Full detail (exact numbers, which scenarios caught what) is in `README.md`'s two
"Mutation testing" sections; summary here.

**Chapter 22** — three mutations, three caught, one only just:
- Reversing `stitch`'s turn comparator: caught by 3 scenarios.
- Skipping `split_segments`'s later passes: caught by 3 scenarios (exact pass/segment
  counts).
- Deleting `meet`'s `"touch"` case (folding it into `"none"`): caught by **exactly one**
  scenario in the whole suite — its own direct unit test. Not caught by `robust22.rs`'s
  "a corner resting on an edge" scenario, which touches a vertex against an edge in
  precisely this configuration, because that scenario's uncut edge doesn't need the cut
  for its *own* final stitched shape to come out right. See **Concrete changes**.

**Chapter 23** — four mutations, four caught, one only just:
- Flipping `smooth_min`'s sign: caught immediately and everywhere (both unit scenarios,
  every render using a fillet).
- Skipping `distance_transform`'s row pass: caught immediately by 3 of 4 scenarios and
  the render suite.
- Deleting `pseudo_distance`'s past-the-end special case: caught by its own scenario and
  by two `bake_msdf` corner scenarios/renders.
- Disabling `bake_msdf`'s right-angle tie-break at a corner: caught by **exactly one
  scenario out of all 789 in the whole 23-chapter suite** — `three_channels_at_one_texel`
  — and by nothing else, including `atlas_corners()` and `title()`, both of which render
  real glyph corners through `bake_msdf`/`bake_mtsdf` at a size where a corner notch
  would plausibly be visible. See **Concrete changes**.

## Concrete changes I'd make

1. **Add a render-level scenario that actually exercises `bake_msdf`'s tie-break.**
   `three_channels_at_one_texel` is the only thing in 789 scenarios that would catch its
   removal. A glyph/spread/scale combination where two candidate edges at a corner are
   provably equidistant from a texel center (or a synthetic `color_edges`-built contour
   with two edges meeting at a right angle exactly on a texel grid line) rendered and
   diffed against a reference would close this gap; right now `atlas_corners()`'s glyph
   corners just don't happen to land on the tie condition.
2. **Add a scenario where chapter 22's `meet` "touch" case is load-bearing for the final
   stitched shape**, not just for the split list. Right now the only two touch-adjacent
   scenarios (`an_end_touching_the_middle_of_another_segment_splits_it` in
   `meet22.rs`, and "a corner resting on an edge" in `robust22.rs`) can each be satisfied
   without the split actually happening, because nothing else needs to attach at that
   exact point. A third shape meeting two others at a shared T-junction — so that
   `stitch` needs the cut vertex to route correctly — would make this the second most
   valuable finding of this round instead of a footnote.
3. **Pin `stitch`'s turn direction with a worked sign**, per the first **Prose problems**
   item — one sentence naming the actual `cross` sign at the decision point, the way
   chapter 13 does for miter angles.
4. **Disambiguate `draw_effect`'s iteration order in prose**, per the second **Prose
   problems** item — "for each effect in order, over every glyph in the run" rather
   than "four times over the run" (which reads as "four times per glyph, over the run").
5. **Give `is_corner`'s `sin(3)` a one-line footnote** explaining the radians/degrees
   coincidence — free clarity for the price of one sentence.

## Timing

All chapter 22/23 renders via `cargo run --release --offline --bin render_all`
(release build, this machine; also individually confirmed via `cargo test --release`):

| render | time |
|---|---|
| `plate-22` | 21 ms |
| `seal` | 404 ms |
| `primitive-fields` | 10 ms |
| `error-map` | 16 ms |
| `fields-vs-paths` | 2.50 s |
| `fillets` | 6 ms |
| `transform-demo` | 6 ms |
| `atlas-corners` | 56 ms |
| `trap-shrink` | 120 ms |
| `plate-23` | 941 ms |
| `title` | 249 ms |

`fields-vs-paths` is the outlier: it builds `plate_glyph_field()` and
`polygon_field(plate_star(), ...)` (each a per-pixel scan over every one of the glyph's
and star's edges/quadratics, 200×200 = 40,000 samples) twice — once directly, once again
inside `field_xor`'s two operands — with no caching between the "by path" and "by field"
halves of the panel; a shared-field cache across the whole render would likely cut this
by close to half. `seal()` (sixty-one `combine` calls, each its own Bentley-Ottmann
sweep) and `plate-23` (four glyph-field-sampling panels including a glow loop over
40,000 pixels) are the next heaviest, both still comfortably sub-second. The full
`cargo test --release --offline` run (789 tests, chapters 1-23) completes in about 33
seconds on this machine; `cargo run --release --offline --bin render_all` (86 renders
total) completes in about 7 seconds.
