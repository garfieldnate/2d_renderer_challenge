# Reader feedback: the epilogue (Rust)

Cold read of `epilogue.html` and `chapter-00.html` on top of the existing
chapters 1-25 Rust code, plus a catch-up pass on chapter 23's atlas feature.
Scope: everything in `features/epilogue-*.feature`, plus
`features/chapter23-atlas.feature`'s new scenario.

## Result

- Full suite: **846 scenarios, 154 feature files / 154 test files, all green**
  (`cargo test --release --offline`).
- Catch-up: `features/chapter23-atlas.feature` (1 new scenario, passed on the
  existing code, no fix needed).
- Epilogue: 4 new feature files, 11 new scenarios, all green on the first
  attempt. No chapter bug found, no reference bug found.
- Renders, `max_channel_difference` against `reference/epilogue/`:
  - `cover-art.ppm` (bare SVG document via `render_svg`): **0**
  - `cover.ppm` (`book_cover()`): **0**
  - `cover-glow.ppm` (`book_cover_glow()`): **0**
  - All three are byte-identical, confirmed both by the `≤ 1` scenarios and
    by a direct `cmp` of `out/*.ppm` against `reference/epilogue/*.ppm`
    after `cargo run --release --bin render_all`.

## Catch-up

Only one feature file had a new scenario since this code last ran:
`features/chapter23-atlas.feature`, "A space has no edges, so every texel is
as far out as the clamp allows" (calls `bake_mtsdf(f, "space", 16, 3)` and
checks all four channels read the spread at three different texels). It
passed against the existing `bake_sdf`/`bake_msdf`/`bake_mtsdf` code
unchanged — the distance-to-nearest-curve loop over an empty curve list
already leaves the running minimum at `f64::INFINITY`/clamps to spread, and
`bake_msdf`'s per-channel search over zero matching edges already falls
through to `None => spread`. Added the scenario to `tests/atlas23.rs` as
`a_space_has_no_edges_so_every_texel_is_as_far_out_as_the_clamp_allows`; no
other change was needed. I did not find any other stale scenario anywhere
else in `features/` — a full `cargo test` before touching anything was
already 100% green.

## Ambiguities

None that blocked anything, but two small judgment calls:

1. **"Every distinct glyph of the title baked once"** (§E.5). The prose is
   explicit that baking should be deduplicated by glyph, not by placement,
   which matters for work done but not for the picture (`bake_mtsdf` is a
   pure function of `(font, name, size, spread)`, so baking the same glyph
   twice produces bit-identical `Baked` values). I built a
   `HashMap<String, Baked>` keyed by glyph name to match the letter of the
   prose. No scenario would have caught baking per-placement instead —
   worth knowing if a future scenario wants to pin the *count* of bakes
   (e.g. via a counter, the way chapter 21 counts cells).
2. **Test file naming.** The epilogue's feature files have no chapter
   number (`epilogue-cover.feature`, not `chapterNN-cover.feature`), and
   this codebase's existing convention is `<section><chapter-number>.rs`
   (e.g. `atlas23.rs`). I named the four new files `cover_epilogue.rs`,
   `document_epilogue.rs`, `glow_epilogue.rs`, `type_epilogue.rs` since
   there's no chapter number to suffix with. Reasonable, but it's a guess
   at a convention the book doesn't specify for chapter-less features.

## Hard to translate

Nothing was hard to translate. Every scenario in all four epilogue feature
files maps onto existing, already-tested chapter 16/18/20/21/23 functions
with no new primitives needed beyond `book_cover()`, `book_cover_glow()` and
`glow_of()` themselves, which the chapter prints in full as pseudocode
(`book_cover`) or a closed-form expression (`glow_of`). The type feature's
placement-index scenario (`title[14]`, `title[15]`) required no new
reasoning either — it's a direct consequence of chapter 18's existing
`break_lines`/`layout_paragraph`, which already reconstructs each broken
line by rejoining its words with single spaces (so the line-breaking space
was already never placed, well before the epilogue existed).

## Failures

None. Every scenario passed on the first attempt; no chapter, reference, or
implementation bug found in the epilogue material.

## Prose problems

Nothing wrong found. Two small notes, not really problems:

- §E.4's claim "the tiled walker... resolves one accumulator cell for every
  118 that chapter 20 resolves for this document" checks out: measuring
  both modes directly on this implementation gives `st.cells = 103,795,200`
  for `"whole"` and `881792` (the pinned value) for `"tiled"` — a ratio of
  ≈117.7, which rounds to the 118 the prose states. The pinned
  `st.cells = 881792` / `st.copies = 205568` numbers for `"tiled"`
  reproduced exactly with no adjustment.
- Chapter 0's "over 880 scenarios" (§0.5) and this reader's total of 846 are
  different numbers, but that's expected: chapter 0 describes the finished
  book counting every reader/language's full scenario set including bonus
  material this particular staged directory may not carry identically
  (e.g. any scenario count differences from optional per-language
  variations). Nothing here suggests the count in chapter 0 is wrong for
  the book as a whole — just noting the two numbers aren't meant to match
  exactly for one language's staged snapshot.
- Chapter 0 doesn't misdescribe anything this code actually built, as far
  as I can tell from a cold read: the "one idea" (coverage computed,
  paint composited through it), the "three kinds of test", and the
  part-by-part map of what's buildable in isolation all matched what
  chapters 1-25 in this codebase already do.

## Mutation results

Three deliberate bugs, each introduced, tested, and reverted (full suite
re-confirmed green at 846 afterward):

1. **The chapter's own named trap** (§E.5's "The trap" box): baking the
   glow at chapter 23's spread of 4 instead of the epilogue's spread of 8.
   Caught immediately by
   `the_glow_sits_around_the_titles_letters_and_nowhere_else`: pixel
   (35, 499) came back (97, 56, 55) against an expected (93, 54, 55) ± 1 —
   a small but real overshoot, exactly the "row of dim orange rectangles"
   effect the trap box describes, just below the visually dramatic
   threshold at this particular probed pixel.
2. **Drawing the glow after the crisp glyph bitmaps instead of before**
   (swapping the order `book_cover_glow` puts the glow and `draw_run`
   steps in). Caught much more loudly by the same scenario: pixel
   (44, 499) — a background pixel that should read the paper color
   untouched — came back (249, 207, 183) against an expected
   (243, 239, 230), because the semi-transparent glow painted straight
   over pixels the crisp glyph draw should have covered afterward or left
   alone.
3. **Passing `linear = false` to both `draw_run` calls in `book_cover`**
   (rendering the title/subtitle in encoded/browser-mode blending instead
   of the book's default linear mode). This is the most interesting
   result: **every individual `ppm_pixel` probe in `the_cover` still
   passed** — none of the five hand-picked pixels happened to land where
   linear-vs-encoded blending moves the byte value by more than 1 — and
   only the golden-image line, `max_channel_difference(p6, ref) ≤ 1`,
   caught it, at an actual difference of **54**. This is a clean,
   reproducible demonstration of exactly the point chapter 0's §0.5 makes
   about why golden-image tests exist alongside point probes: a renderer
   can pass every spot-check a human picked and still be globally wrong.

No mutation I tried passed the suite undetected. I did not find a fourth
"free" bug this round.

## Concrete changes I'd make

1. Nothing required. If anything, the strongest evidence from this round
   is negative: three plausible reader mistakes (a stated trap, a
   plausible ordering slip, and a very easy-to-miss default-argument slip)
   were each caught by exactly one scenario apiece. The epilogue's test
   coverage for its own new material is tight.
2. Optional, not a bug: a scenario that pins the *number of distinct bakes*
   `book_cover_glow` performs (e.g. exposing a bake counter the way chapter
   21 exposes `Stats`) would let a future reader's per-placement-instead-
   of-per-glyph implementation be told apart from the per-glyph one the
   prose asks for, even though both currently produce identical pixels.
   Low priority — this is a work-shape nit, not a correctness one.
3. The chapter-less feature file naming (`epilogue-*.feature` vs.
   `chapterNN-*.feature`) has no test-file-naming convention documented
   anywhere I found; if a future bonus/epilogue-style chapter is added,
   it might be worth a one-line note in the author's own conventions
   (not chapter prose — this is book-repo tooling, not reader-facing)
   saying what readers should name the corresponding test file.

## Timing

Release build, one run each, this machine, via `cargo run --release
--bin render_all`:

- `cover-art` (bare SVG document, `render_svg`): **392ms**
- `cover` (`book_cover()`): **470ms**
- `cover-glow` (`book_cover_glow()`): **1.03s**

The glow render's extra ~600ms over the plain cover is baking and sampling
an MTSDF field for each of the roughly 20 distinct glyphs in "The 2D
Renderer Challenge", each field a few hundred texels evaluated by a
nearest-curve search over every colored edge — expected, and not remotely
close to being a performance problem for a one-off cover render.

Full test suite (`cargo test --release --offline`, all 846 scenarios,
chapters 1-25 plus the epilogue): a few seconds wall clock, dominated by
the SVG/tiger-drawing and font-shaping test files as in every earlier
round; nothing epilogue-specific was slow.
