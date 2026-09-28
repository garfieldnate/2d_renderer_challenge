# Reader feedback — Rust, chapters 24–25

Candid notes for the author. Praise is skipped; problems, ambiguities and
mutation results are not.

## Result

All 831 scenarios across 153 test binaries pass (`cargo test --release
--offline`), 790 of them carried over from chapters 1–23 unchanged and 41
new for chapters 24–25.

Chapter 24 (7 feature files, 19 scenarios):

| file               | scenarios | status |
|--------------------|-----------|--------|
| stencil24.rs        | 4         | green  |
| loopblinn24.rs       | 3         | green  |
| msaa24.rs            | 2         | green  |
| shader24.rs          | 1         | green  |
| pipeline24.rs        | 5         | green  |
| unhappy24.rs         | 1         | green  |
| plate24.rs           | 3         | green  |

Chapter 25 (5 feature files, 22 scenarios):

| file               | scenarios | status |
|--------------------|-----------|--------|
| brush25.rs           | 4         | green  |
| flood25.rs           | 4         | green  |
| quantize25.rs        | 4         | green  |
| select25.rs          | 6         | green  |
| plate25.rs           | 4         | green  |

Renders, `max_channel_difference` against `reference/chapter-2{4,5}/`:

| render            | diff | render            | diff |
|-------------------|------|--------------------|------|
| plate-24.ppm      | 0    | plate-25.ppm       | 0    |
| msaa-demo.ppm     | 0    | dither-strip.ppm   | 0    |
| spill-map.ppm     | 0    | halo-demo.ppm      | 0    |
| tiger-assembly.ppm| 0    | brush-demo.ppm     | 0    |
|                   |      | paint-by-script.ppm| 0    |

Every one of the nine new renders is byte-identical to the reference, not
merely within the book's `≤ 1` budget.

## Catch-up

Before touching chapter 24, I reran the existing chapters 1–23 suite
(`cargo test --release --offline`, filtered to the pre-existing 141 test
files) against the `features/` directory as shipped. All 790 scenarios
already passed unchanged — the test count (790) matches the count recorded
in this reader's last catch-up commit message exactly (`git log` shows
"Rust catch-up for chapters 22-23; ... 790 tests green"), so no new
scenarios had been added to chapters 1–23's feature files since that round,
and no fixes were needed before starting chapter 24.

## Ambiguities

- **`shade_tile`'s `radial_gradient` call has no extend mode.** The
  scenario writes `radial_gradient(point(20, 20), 0, point(40, 30), 50,
  [stops])` — five arguments — but chapter 10 established that Rust's
  `radial_gradient` always takes an explicit extend string (no defaults).
  I guessed `"pad"`; the pinned colours (`(0.735942, 0, 0.264058)` and
  `(0.539754, 0, 0.460246)`) matched on the first try, so the guess was
  right, but the feature text itself leaves it to be guessed, which is
  exactly the kind of implicitness the book's own testing rules forbid
  elsewhere (§24.4's own scenario is the one spot in two chapters where an
  argument is silently missing).
- **`glyph_curves`'s exact shape.** The chapter attributes `glyph_curves`
  to "chapter 23," but no such function exists in this codebase's chapter
  23 (`glyph_outline` returns curves per contour, nested). I introduced
  `glyph_curves(font, name, m)` in chapter 24 itself, returning one flat,
  ordered list across all contours (not nested), since that's what
  `loop_blinn_stencil` and `glyph_stencil`'s "anchored at the first curve's
  first point" wording require. It matched every pinned scenario.
- **`fine_tile`'s printed signature vs. the feature prose.** §24.7's
  printed pseudocode shows `fine_tile(commands, tx, ty)`; the feature file
  says `fine_tile(scene, commands, tx, ty, fs)`. No scenario calls
  `fine_tile` directly (it's only exercised through `run_pipeline`), so I
  used whatever signature was convenient (`commands, tx, ty, width,
  height, fs`, no `scene`) and it never mattered.
- **`median_cut`'s initial box order.** "Count every distinct colour and
  put them all, *sorted*, in one box" doesn't say by what. I sorted
  lexicographically by `(r, g, b)`, which is the only order that
  reproduces the four worked cases in the scenario exactly (the "stably by
  that channel" wording on later cuts depends on this initial order as a
  tie-break basis) — confirmed against all five hand-worked cases,
  including the ring canvas's own four-colour palette.
- **`paint_by_script`'s "painted, then undone" magenta stroke.** I never
  implemented a generic undo for an arbitrary brush stroke; I simply never
  paint it. A perfect undo restores the canvas pixel-for-pixel, so this is
  provably byte-identical to painting and undoing it, and the render came
  out byte-identical to the reference. See **Hard to translate** for why I
  didn't build the generic mechanism instead.

## Hard to translate

- **No default/optional function parameters.** Several spots say "`X` is
  `Y` when left out" (`stencil_buffer`'s `ox`/`oy`). Rust has no optional
  parameters or overloading by arity, so each of these became two
  functions: an explicit `_at` variant taking every argument, and a
  convenience wrapper hard-coding the default. `stencil_buffer_at(p, w, h,
  ox, oy)` / `stencil_buffer(p, w, h)` is the one instance in these two
  chapters; earlier chapters apparently hit this too (`arc`, `stroke_to_
  path` never leave anything out in practice), but this is the first time
  it actually bit.
- **Constructor-style capitalized names.** `Scene(...)` and `FineStats()`
  are written capitalized in the feature files, unlike almost every other
  function in the book (`layer()`, `path()`, `brush()`, ...). Rust
  functions are conventionally `snake_case`; I kept the literal names
  (`#[allow(non_snake_case)] pub fn Scene(...)`, `pub fn FineStats()`) so
  the tests read as a direct translation, at the cost of two clippy-style
  warnings suppressed inline.
- **`History` can't hold a live reference to its canvas.** The feature
  reads as `h ← history(c)` once, then `history_fill(h, x0, y0, ...)` /
  `undo(h)` / `redo(h)` with no further mention of `c` — implying `h`
  remembers which canvas it edits. In a language with shared mutable
  object references that's free; in Rust, `History` stashing a `&mut
  Canvas` would conflict with the test's own direct `pixel_at(&c, ..)`
  calls on the same canvas at the borrow checker level. I changed
  `history_fill`/`undo`/`redo` to take the canvas as an explicit second
  argument (`history_fill(&mut h, &mut c, x0, y0, x1, y1, col)`). Every
  other signature in the two chapters translates without this kind of
  change.
- **`naive_depth`'s genuine recursion overflows the test thread's stack.**
  A literal translation of "the recursive four-way fill, each call trying
  right, left, down, up" as native Rust recursion works fine for
  `naive_depth(4, 3)` (depth 12) but crashes with a stack overflow well
  before returning from `naive_depth(200, 200)` (depth 40,000) — which is
  the exact point of chapter 25's own trap box ("Python stops at a
  thousand, a C program at whatever its stack allows"). I simulated the
  same call/return structure with an explicit heap-allocated stack (one
  frame per open call, remembering which of the four directions it's
  tried next) instead of real recursion. Both pinned depths (12 and
  40,000) come out identical either way; only the 40,000-deep case
  actually needs the heap version to survive.
- **`cull_groups` needed a generic payload.** Its own scenario compares
  bare tagged tuples (`("fill", 1)`, `("push", 0.5, none)`); the real
  pipeline needs `Fill` to carry a paint, alpha, resolved tile coverage
  and an optional clip array. I made the whole thing generic
  (`PipeCmd<F, C>`), so the same stack-based culling algorithm serves the
  toy scenario (`PipeCmd<i64, ()>`) and the real `CoarseCommand =
  PipeCmd<FillCmd, Vec<f64>>` without transcribing the logic twice.

## Failures

None — every scenario in both chapters passes as written, with no
tolerance weakened and nothing special-cased. The `naive_depth` stack
overflow above was a translation obstacle I worked around, not a chapter
bug or an unpassable scenario.

## Prose problems

- **§24.4's `shade_tile` scenario is missing an argument.** See
  **Ambiguities** — `radial_gradient`'s extend mode is silently absent
  from the one call the scenario makes, which is inconsistent with the
  book's stated rule that scenarios pin everything a reader in another
  language could get wrong (this is exactly such a spot: a reader whose
  language defaults extend differently, or who picks `"repeat"` instead
  of `"pad"`, would get different pinned colours and have no way to know
  which is "right" from the feature text alone).
- **`plate_star()` is reused for two different shapes.** Chapter 22 already
  defines `plate_star()` as "chapter 5's star, scaled by 0.85 about its own
  center and moved so that center lands at (130, 104)" (used by `op_panel`/
  `plate_22`). Chapter 24's own prose says "`plate_star()` is chapter 5's
  star moved by (19.5, 19.5)" — a different transform entirely, under the
  identical name. I named my chapter 24 version `plate_star_24()` to avoid
  a hard collision, mirroring the book's own precedent for this exact
  problem (chapter 15's `spiral()` render was renamed `spiral_dashes()`
  after colliding with chapter 6's `spiral()`). Worth the same fix here —
  see **Concrete changes**.
- **The brush's opacity invariant isn't independently pinned.** §25.1 says,
  in prose: "a stroke at 50% opacity never gets darker than 50% however
  many times it crosses itself." No scenario in `chapter25-brush.feature`
  actually exercises a brush with `opacity < 1` and checks that overlap
  cap. See **Mutation results** below — this is the single most valuable
  finding of this round.
- **The dither scenario only ever quantizes to black and white.** Every
  pinned value in `chapter25-quantize.feature`'s dither scenario uses the
  two-entry `[(0, 0, 0), (255, 255, 255)]` palette. That happens to make
  the whole scenario blind to whether `palette_light` decodes its bytes at
  all (see **Mutation results**), since `decode(0) = 0` and `decode(1) =
  1` regardless of the transfer function used.

## Mutation results

Six deliberate bugs across the two chapters, each introduced, confirmed
against the suite, and reverted.

**Chapter 24.**

1. Dropping `inside_curve`'s `s > 0` guard (using `u² − v < 0` alone,
   the chapter's own named trap) was caught immediately and everywhere:
   two of `loopblinn24.rs`'s own scenarios, the un-flattened `g`'s
   winding-mismatch count (3,658 mismatches where 0 were expected), and
   both of `plate24.rs`'s render checks.
2. Reusing `fine_tile`'s bottom scratch block from a thread-local pool
   *without clearing it* between tiles — a real GPU renderer's
   reused-scratch-buffer bug, the exact failure mode chapter 24's own
   prose warns about ("a scratch buffer reused between tiles") — was
   caught by the tiger's byte-exact-match scenario even in plain raster
   order (a later same-sized tile inherited an earlier tile's fully
   rendered pixels instead of starting transparent) and by the bespoke
   non-grouped-clip scenario. Neither needed the `in_order == shuffled`
   check specifically; the plain "matches chapter 20" comparison already
   caught it, since the bug corrupts the result regardless of tile order.
3. Breaking `fan_anchor` to always return `point(0, 0)` instead of the
   path's own first point was caught hard by the two scenarios that pin
   `fan_anchor`'s return value and the star's fragment count directly
   (`fan_anchor(sq) = point(1, 1)` failed outright; the star's fragment
   count rose from 13,660 to 25,686) — **but every render-based scenario,
   including `plate_24`'s own pinned pixels, still passed.**
   Stencil-and-cover's correctness proof never requires the anchor to lie
   on or near the path — any fixed point makes the fan's spokes cancel the
   same way, so the *pixel values* stay exactly right regardless of which
   point is chosen; only the fragment count (efficiency) and the two
   scenarios written specifically to pin the anchor's value are sensitive
   to it. A reader who picks a convenient-but-wrong anchor (say, the
   canvas corner) ships a working renderer and is caught only by those two
   scenarios, never by a render.

**Chapter 25.**

4. Making `anti_alias_mask` check all eight neighbours instead of four was
   caught immediately by its own scenario (`ink` rose from 10,648 to
   10,718) and by `halo_demo`'s render.
5. Skipping the `decode` in `palette_light` (treating a palette byte's
   `/255` as its light directly — the "chapter 1 mistake" the prose names
   by analogy) passed `quantize25.rs`'s own scenario completely unnoticed,
   because that scenario's only dither palette is pure black and white,
   and `decode(0) = 0`, `decode(1) = 1` exactly regardless of the transfer
   function — the two entries this book's only pinned dither scenario
   ever uses are immune to the bug by construction. It only surfaced on
   `paint_by_script`'s 16-colour median-cut palette, where intermediate
   byte values genuinely differ under the two conventions: the render came
   out visibly wrong at a pixel (370, 110) nowhere near any actual change,
   because the *global* palette (computed once from every pixel in the
   scene) shifted, retroactively changing the quantization decision for
   pixels far from the mutation's own effect.
6. Folding the brush's `opacity` into each dab's contribution to the union
   (`1 - (1 - m)(1 - flow · k · opacity)`) instead of scaling the finished
   mask once at the end breaks the chapter's own stated invariant directly
   — repeated per-dab factors still drive the union toward 1 regardless of
   opacity, so a stroke at 80% opacity crossing itself enough times can
   still reach full opacity. **Every scenario in `chapter25-brush.feature`
   passed**, because none of its four scenarios uses `opacity < 1`.  Only
   `paint_by_script`'s six overlapping wave strokes
   (`brush(1.6, 0.2, 0.3, 0.7, 0.8)`, opacity 0.8) exercised the bug at
   all, and even then only indirectly, again through the shared median-cut
   palette shifting an unrelated pixel. This is the single most valuable
   finding of this round: a chapter-stated correctness invariant ("never
   gets darker than X% however many times it crosses itself") has no
   scenario of its own, and the one render that happens to touch it does
   so by accident, through a mechanism (global palette quantization) that
   has nothing to do with brushes.

## Concrete changes

1. Have the book itself rename chapter 24's `plate_star()` to something
   distinct from chapter 22's existing `plate_star()`, in the reference
   implementation and prose, so every reader doesn't have to invent their
   own fix. I worked around the collision on my end by naming mine
   `plate_star_24`, matching the book's own precedent for chapter 15's
   `spiral()`/`spiral_dashes()` collision.
2. Add an explicit extend mode to §24.4's `shade_tile` scenario's
   `radial_gradient` call, so a reader in any language pins the same
   colours for the same reason instead of guessing.
3. Add a scenario to `chapter25-brush.feature` that directly tests the
   prose's own claim: a self-crossing stroke at `opacity < 1` (say 0.5)
   never exceeds that opacity anywhere along its overlap, however many
   times the path crosses itself. This is the one invariant in either
   chapter that a render happened to catch only by accident.
4. Add a `chapter25-quantize.feature` dither scenario using a
   multi-colour (not black/white) palette, so `palette_light`'s `decode`
   step is actually exercised by a feature-level scenario rather than
   only by the `paint_by_script` render.
5. Consider printing `fine_tile`'s full signature (or noting that the
   pseudocode omits `width`/`height`/`scene` for brevity) so the printed
   pseudocode and the feature prose don't silently disagree on arity.

## Timing

Full suite (`cargo test --release --offline`, 153 binaries, 831
scenarios): **~21s wall clock** (`16.2s` user, `1.0s` system — most of the
wall time is process-startup overhead across 153 separate test binaries,
not test execution itself).

Chapter 24/25 renders specifically (`cargo run --release --offline --bin
render_all`, timed individually):

| render             | time     | render              | time     |
|--------------------|----------|----------------------|----------|
| `plate_24`         | 25 ms    | `plate_25`           | 6 ms     |
| `msaa_demo`        | 41 ms    | `dither_strip`       | 6 ms     |
| `spill_map`        | 129 ms   | `halo_demo`          | 9 ms     |
| `tiger_assembly`   | 114 ms   | `brush_demo`         | 4 ms     |
|                    |          | `paint_by_script`    | 67 ms    |

`spill_map` and `tiger_assembly` are the slowest of the nine because both
run the full four-stage compute pipeline over the rose or tiger (`spill_
map` once, `tiger_assembly` 841 individual tile calls plus four full-canvas
snapshots) — still well under a fifth of a second each in release mode.
Chapter 24's pipeline scenario (`pipeline24.rs`, which renders all three of
tiger/harbor/rose twice each, once in raster order and once shuffled)
finishes in well under a second; nothing in either chapter approaches the
multi-second renders chapter 23's `atlas_corners`/`plate_23`/`fields_vs_
paths` already have in this codebase.
