# Reader feedback — Java, chapters 24 and 25

Cold read: chapter HTML + feature files + the existing chapters 1-23 Java code only.
No access to the book's own repository, no reference implementation, no other reader's work.

## Chapter 24 — Doing It the GPU's Way

### Result

- 22/22 `chapter24-*.feature` scenarios green (`Chapter24Tests`, 5.8 s total, mostly the
  scenario that runs `render_svg_gpu` on the tiger/harbor/rose twice each).
- All four renders diff **0** against `reference/chapter-24/*.ppm` (not just within the ≤1
  budget the scenarios ask for): `plate-24.ppm`, `msaa-demo.ppm`, `spill-map.ppm`,
  `tiger-assembly.ppm`.
- Chapters 1-23 all still green after the catch-up pass below: 805/805.

### Catch-up (chapters 1-23)

Before touching chapter 24 I diffed every `features/chapterNN-*.feature` scenario name
against what `ChapterNNTests.java` actually registers. Five scenarios existed in `features/`
but had never been translated into a test, in five different chapters:

- `chapter05-rules.feature` — "Even-odd counts negative windings too"
- `chapter06-edges.feature` — "A nearly horizontal edge is still an edge"
- `chapter06-sweep.feature` — "A bow tie has four crossings on a row, and they must be sorted"
- `chapter09-blend.feature` — "A non-separable blend that overflows is clipped back into range"
- `chapter10-gradients.feature` — "When both roots are valid the larger one wins"
- `chapter11-mip.feature` — "Downsample averages premultiplied, so a transparent texel adds
  nothing"

All five passed the moment they were added — no bug in the existing code, only missing
coverage. (I also chased down several more candidates a crude scenario-count diff flagged;
all of those turned out to be present already under a slightly different scenario name, a
line-wrapped Java string literal, or folded into one `scenario()` call that loops over a
`Scenario Outline`'s examples instead of registering one per row — not real gaps.)

### Ambiguities

- **`bin_stage`'s deposit count depends on *not* reusing chapter 7's optimized accumulator.**
  The prose says bin_stage makes "chapter 21 sparse deposits, one per call of the
  accumulator's `add` that isn't dropped." Chapter 7's own `Fill.accumulateRow` (reused
  everywhere else in this codebase) special-cases the portion of an edge that falls left of
  the buffer into *one* deposit for the whole portion, rather than one per grid cell it
  crosses. If you reuse that optimization here, you get the same final coverage and a
  byte-identical picture, but a *smaller* `deposit_count`. The only way to know which one the
  book means is the pinned number itself (`deposit_count(bins) = 119876` for the tiger); nothing
  in the prose says "don't fold, walk every cell" in so many words. I wrote a fresh,
  deliberately un-optimized `Pipeline.depositsOf` that walks `floor(xa)` to `floor(xb)`
  unconditionally and pushed the clamp/fold/drop decision into the bin callback, which
  matched on the first try — but only because I happened to translate the figure JS's own
  `depositsOf` line for line rather than reusing `Fill.accumulateRow`. A reader who wrote the
  pipeline from the prose alone, reusing their existing chapter 7 accumulator code (the
  obvious thing to do, and *not* wrong for the rendered picture), would fail this one
  scenario with no clue why the picture is fine but the count is off. Worth a sentence in the
  chapter saying so explicitly.
- **Loop-Blinn's `(u, v, s)` tuple order.** `loop_blinn_uv` answers `(u, v, s)`, not the
  more natural derivation order `(s, t) -> (u, v)`. Easy to get right by just plugging in the
  scenario's own worked numbers, but worth flagging since it's the one place a transcription
  slip (returning `(u, v, t)` intead of `(u, v, s)`, say) would silently pass every scenario
  that only checks scalar equalities without printing which field is which.

### Hard to translate

- `cull_groups`'s own scenario hands it a list of bare tuples (`("push", 1, none)`,
  `("fill", 1)`, `("pop",)`) that don't match any real production type (a real `Fill`
  command carries a paint, an alpha, a rule...). I gave the algorithm a tiny shared interface
  (`CullOp`, `isPush()`/`isPop()`) implemented both by the real per-tile `TileFill`/`TilePush`/
  `TilePop` records and by a local record built just for that one scenario in
  `Chapter24Tests`, so the exact same generic method (`CullOp.cullGroups`) runs both. Cleaner
  than duplicating the algorithm for a toy input.
- Nothing else in this chapter needed unusual Java: the whole compute pipeline reuses chapter
  5's `Path.edges()`, chapter 7's `Fill.applyRule`, chapter 20/21's SVG/style/paint machinery,
  and chapter 9's premultiplied compositing verbatim.

### Failures

None outstanding. Every scenario is green, every render diffs 0.

### Prose problems

None found — no wrong claims, no sentence I got stuck on. (See the deposit-count ambiguity
above; that's a *gap*, not a wrong statement.)

### Mutation results

Four mutations, four caught:

1. `Stencils.triangleWinding`'s half-open rule weakened from `u.y <= y` to `u.y < y` (the
   book's own chapter 5 rule, broken on purpose). Caught by 2 scenarios (`Stencil: matches
   chapter 5's winding number everywhere`, `Loop-Blinn: a glyph without flattening agrees
   with one flattened tight`) — both go from 0 mismatches to dozens.
2. `Pipeline`'s tile classifier narrowed from "every row's arriving sum agrees" to "row 0's
   arriving sum agrees" alone — chapter 21's own historical top-row-only bug
   (`readers/`... see chapter 21's README note), re-introduced here on purpose. Caught by 3
   scenarios: the harbor/rose/tiger round-trip, the standalone clip-on-a-shape scenario, and
   `spill_map`'s render.
3. `fineTile`'s opaque-solid-tile fast path made to skip its `clip == null` check (so a fully
   opaque solid-colour fill under an active clip gets copied instead of blended). Caught by
   exactly 1 scenario — the one purpose-built for it, `Pipeline: a clip on a shape that isn't
   grouped`. No plate render happens to exercise a clipped solid fill, so this is the
   scenario earning its keep precisely as the project's own testing philosophy asks for.
4. `binStage`'s negative-x fold weakened from `x < 0` to `x <= 0` (an off-by-one at column
   0). Caught by 3 scenarios: the harbor/rose/tiger round-trip (tiger only — harbor and rose
   don't touch column 0 closely enough), `spill_map` and `tiger_assembly`.

Nothing slipped through. I'd call this chapter's scenario coverage genuinely tight.

### Concrete changes I'd make

- State explicitly, in §24.5, that `bin_stage` must deposit one entry per grid cell an edge
  crosses, even the ones that fold onto column 0 or vanish off the right edge, and that
  reusing chapter 7's `accumulate_row` (which does that folding as one optimization) will
  change `deposit_count` without changing the picture. One sentence would have saved the
  ambiguity above.
- Otherwise nothing — this was the most cleanly pinned chapter I've translated yet;
  essentially every constant in the scenarios (fragment counts, deposit counts, byte-exact
  renders in both tile orders) worked on the first implementation attempt.

### Timing

Full chapter: 5.8 s for 22 scenarios (includes rendering the tiger, harbor and rose twice
each — once in order, once shuffled — for the round-trip scenario, plus building
`tiger_assembly` four times over for its four panels). Individual renders:
`plate_24` ~80 ms, `msaa_demo` ~70 ms, `spill_map` ~310 ms, `tiger_assembly` ~430 ms. No
concern for a compiled language; the chapter's own note that this is slow in an interpreted
language doesn't apply here.

---

## Chapter 25 — The Raster Editor Detour

### Result

- 25/25 `chapter25-*.feature` scenarios green (`Chapter25Tests`, ~1.1 s total).
- All five renders diff **0** against `reference/chapter-25/*.ppm`: `dither-strip.ppm`,
  `halo-demo.ppm`, `brush-demo.ppm`, `paint-by-script.ppm`, `plate-25.ppm`.
- Chapters 1-24 all still green: 827/827.

### Catch-up

No new scenarios turned up in chapters 1-24's feature files between finishing chapter 24 and
starting chapter 25 (same session, no intervening changes to `features/`).

### Ambiguities

- **`move_floating(f, dx, dy)`: set or accumulate?** The prose says "moves it"; the only
  worked example (`paint_by_script`) and the only scenario (`A floating selection moves and
  drops`) both call it exactly once on a freshly floated selection, so "set `f.dx = dx`" and
  "`f.dx += dx`" are indistinguishable by every test in the book. I implemented accumulation
  (`+=`), since a tool called "move" that silently teleports back to the origin on a second
  call would be a strange design, but nothing pins this either way. A scenario that calls
  `move_floating` twice on the same float and checks the final position would settle it.
- **`drop_floating`'s handling of a fractional move.** Every scenario and the plate's own
  script only ever move a float by whole pixels. I round `dx`/`dy` to the nearest integer
  before compositing (there's no resampling filter defined anywhere in this chapter to
  justify anything fancier). If the book ever wants fractional drags, this needs its own
  scenario and its own stated filter.
- **`History` has no reference JS at all.** Every other section of this chapter (and every
  other chapter) has a browser-side JS implementation to check my reasoning against, even
  where it isn't printed in the chapter text. `paint_by_script`'s own "one stroke... then
  undone" step doesn't go through a `History` object in the JS — it takes a raw
  `snapshot()`/restore shortcut, because a brush stroke isn't a rectangle `history_fill` can
  express. So `History.historyFill`/`undo`/`redo`/`storedPixels` were built from
  `chapter25-select.feature`'s prose and its two worked scenarios alone, with nothing else to
  cross-check against. It happened to be enough — both scenarios (including the
  "stored_pixels drops to 17, not 33" detail after an edit-after-undo) passed on the first
  attempt — but this section had a thinner safety net than the rest of the book while I was
  writing it.

### Hard to translate

- `naive_depth(200, 200) = 40000` needs an actual 40,000-deep Java call chain. The JVM's
  default thread stack (roughly 512 KB-1 MB depending on platform) doesn't reliably hold
  that many frames of a four-argument recursive method; I run `naiveDepth` on a dedicated
  `Thread` built with an explicit 256 MB stack. A reader who just calls the recursive method
  from `main` may get an intermittent `StackOverflowError` depending on JVM defaults and
  platform — worth a note for JVM-hosted languages generally (this is exactly the chapter's
  own point about the naive fill blowing the stack, so it's fitting that even the *test* for
  it needs care in a language with a real call stack).
- Nothing else was unusual; the flood fill, brush, quantization and BMP-writing sections all
  translated directly from a mix of the printed pseudocode (flood fill) and the feature
  files' own precise prose (everything else, same situation chapters 12/16/18/23 were
  already in for their unprinted renders).

### Failures

None outstanding.

### Prose problems

None found. One design choice worth a second look rather than a correction:
`mean_light(c)` is defined as "the mean **green** light," not the mean of all three
channels or a luminance weighting. This is harmless for every scenario in the book (every
canvas it's applied to — `ramp_canvas`, and any black/white-palette `indexed_canvas` — has
r = g = b at every pixel, by construction), but the name reads as a general-purpose "how
light is this image" helper, and it would silently give the wrong number for a canvas with
independent colour channels. Not a bug as written, just a sharp edge if it's ever reused
outside this chapter's own scenarios.

### Mutation results

Four mutations tried, two caught, **two not caught**:

1. `feather` changed to clamp its sliding window to the buffer's edge instead of treating
   off-buffer samples as 0. **Caught** — `Select: off the buffer counts as unselected`
   expects `coverage_at(f, 0, 0) = 0.444444` and got `0.666667` from the clamped version.
   This is exactly the scenario the chapter's own commit history says was added for a prior
   round's mutation finding, and it still does its job.
2. `flood_mask` changed to ignore its `connectivity` argument and always grow 4-way.
   **Caught** — `Flood: eight-way connectivity leaks through a diagonal` expects
   `ink(flood_mask(c, 0, 0, 0, 8)) = 7` and got `1`.
3. **`medianCut`'s "earliest on a tie" rule for picking the widest *box*** (`w > bw` widened
   to `w >= bw`, so the *last* box of equal width wins instead of the first) — **not caught**.
   All 25 scenarios still pass.
4. **`medianCut`'s "red before green before blue" rule for picking a box's widest *channel***
   (`ws[k] > ws[ch]` widened to `ws[k] >= ws[ch]`, so blue wins over red on a tie instead of
   red) — **not caught**. All 25 scenarios still pass.

Findings 3 and 4 are the same shape of gap: `chapter25-quantize.feature`'s Scenario "Median
cut" hand-picks eight colours and `ring_canvas()`'s own colour distribution for the fifth
assertion, and neither ever produces an *exact* tie in channel range or box width at any
split the algorithm actually makes. The prose states both tie-break rules in so many words
("the earliest on a tie"; "red before green before blue when widths tie") but nothing in the
book pins either one. A reader who read only the scenarios (not the prose) could ship either
tie-break direction, or no explicit tie-break logic at all (e.g. `Collections.max` by whatever
order a language's stream/reduce happens to visit a list, which is not necessarily "first
on a tie" in every language) and pass every test. This is exactly the kind of gap the book's
own testing philosophy calls the most valuable thing a mutation round can find.

### Concrete changes I'd make

- Add one more colour to the "Median cut" scenario's input list (or a second, purpose-built
  scenario) that forces an exact tie: two colours whose boxes end up the same width, or a box
  whose red and green ranges are identical. Either would pin the box-tie or channel-tie rule
  the same way `chapter13-degenerate.feature`'s scenarios pin stroke degeneracies.
- Add a second call to `move_floating` in the floating-selection scenario (move twice, check
  the final position) to settle set-vs-accumulate.
- Consider whether `History` deserves a note in the prose that it's deliberately narrower
  than a general undo stack (rectangle-and-colour only), the way the chapter already says a
  real editor would tile its undo storage — the current text implies but doesn't say outright
  that arbitrary brush strokes need their own undo mechanism outside `History`.

### Timing

Full chapter: ~1.1 s for 25 scenarios. Individual renders: `dither_strip` ~80 ms,
`halo_demo` ~50 ms, `brush_demo` ~90 ms, `paint_by_script` ~350 ms (the slowest single piece
of work in the chapter — it runs `median_cut` over a 480x320 canvas's up-to-153,600 distinct
colours, then `error_diffuse` and a full BMP round-trip). `naive_depth(200, 200)` itself is
comparatively fast (tens of milliseconds) once given a stack large enough not to fault.
