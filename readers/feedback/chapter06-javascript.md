# Reader feedback — JavaScript, Chapters 5 and 6

Implemented cold, from the built chapter HTML and the `.feature` files alone, on top of the
existing chapters 1–4 JavaScript in this directory. Node 22, built-in modules only, `node test.js`
as the harness (`node:test`).

## Chapter 5: Paths and Insideness

### Result

32 scenarios translated, all 32 pass, plus 1 output-writing test (33 total in the chapter-5
section). Full suite after chapter 5: 246/246 passing.

| Feature file | Scenarios | Pass |
|---|---|---|
| chapter05-paths.feature | 10 | 10 |
| chapter05-winding.feature | 9 | 9 |
| chapter05-rules.feature | 9 | 9 |
| chapter05-plate.feature | 4 | 4 |

`max_channel_difference` against `reference/chapter-05/`:
- `star-centers.ppm`: **0**
- `star-coverage.ppm`: **0**
- `plate-05.ppm`: **0**

All three bit-exact, not just within the ≤1 budget.

### Catch-up

Step 0 of the task: before touching chapter 5, brought the existing chapter 1–4 suite up to
`features/` as it stands today. Cross-referencing every `Scenario:`/`Scenario Outline:` name in
`features/chapter0[1-4]-*.feature` against the test names in `test.js` turned up **5 scenarios
that had never been translated**:

1. *"A union of nothing is inside nowhere"* (chapter04-drawing.feature) — translated, passed
   immediately on the existing code.
2. *"Invertibility is an exact test against zero"* (chapter04-matrices.feature) — translated,
   passed immediately.
3. *"side_by_side puts the first canvas on the left"* (chapter04-plate.feature) — translated,
   passed immediately (the function existed and was used by the plates, just never had its own
   scenario).
4. *"The weights are applied in light, whatever the switch says"* (chapter03-wu.feature) —
   **failed**. `line_wu`'s `plot()` helper called `mix(current, color, weight)` with no third
   argument, so it inherited the *global* linear-blending switch instead of always blending in
   light the way `paint_through` already did (that function explicitly passes `mix(..., true)`
   with a comment saying so). With `linear blending off`, expected `color(0.5, 0.5, 0.5)`, got
   `color(0.214041..., ...)` (the browser-mode encode/lerp/decode value). One-line fix: pass
   `true` explicitly in `plot()`, matching the existing `paint_through` pattern.
5. *"magnitude and dot look at x and y only"* (chapter04-tuples.feature) — **failed**. Both
   `Tuple.magnitude()` and the standalone `dot()` included the tuple's `w` component in their
   arithmetic (`sqrt(x*x + y*y + w*w)`, `a.x*b.x + a.y*b.y + a.w*b.w`). Invisible for vectors
   (`w = 0`), but the missing scenario calls both on *points* (`w = 1`):
   `magnitude(point(3, 4))` returned `sqrt(9+16+1) ≈ 5.099`, not `5`; `dot(point(1,2), point(2,3))`
   returned `1*2+2*3+1*1 = 9`, not `8`. Fixed both to look at `x`/`y` only.

Both real bugs (#4, #5) had been sitting in code that every existing chapter-3/4 test exercised
and passed, because every prior scenario happened to call `line_wu` with linear blending in its
default (on) state, and every prior scenario happened to call `magnitude`/`dot` on vectors
(`w = 0`), never on points. This is a strong argument for the book's own rule that a scenario
needs a value where the bug actually shows: neither bug could have been caught by "more of the
same" tests, only by a scenario that specifically probes points/switch-off.

### Ambiguities

- `bounds(p)` return shape: the prose says "(min x, min y, max x, max y)" without saying whether
  that's a tuple, a struct, or an array. Guessed a plain 4-element JS array `[minx, miny, maxx,
  maxy]`, consistent with how `edges(p)` already returns `[a, b]` pairs as plain arrays elsewhere
  in this codebase's conventions, and how chapter 6's `rasterize_within(shape, box, w, h)` takes
  `box` as the same 4-tuple. Worked cleanly; a struct with named fields would have worked equally
  well and the scenarios don't distinguish.
- `circle_path`'s "going clockwise on the screen" and its first-point-at-angle-0 convention:
  the prose states this explicitly and a scenario pins it (`circle_path(10, 10, 5, 8)` point 1 at
  `(13.5355, 13.5355)`, i.e. `+45°` with standard `cos`/`sin`, which is clockwise once you
  remember y points down) — no real ambiguity, just double-checked against the scenario before
  committing to `angle = i * 2π / n` with plain `cos`/`sin`.
- `filled(p, rule)`'s `rule` argument: stored as the literal strings `"nonzero"` / `"evenodd"`
  since that's exactly what the scenarios pass and compare against; no enum needed.

### Hard to translate

Nothing forced an awkward shape onto the JavaScript. A path is `{ subpaths: [{ points: [...],
closed }, ...] }`; `edges()` returns arrays of `[a, b]` point pairs; everything else is plain
functions over that structure, consistent with how chapters 1–4 already represent shapes as
plain classes/objects queried by free functions rather than methods.

### Failures

None outstanding — every chapter 5 scenario passes.

### Prose problems

None that blocked anything. Two small notes, not blockers:

- §5.4's `star()` vertex order (first point straight up at `-90°`, then `+144°` per step) took a
  second read to convince myself it really does go clockwise on the screen for a five-pointed
  star with points visited "every second one" — but the chapter says this explicitly and the
  scenario pins all five vertex coordinates to four decimals, so there's no room to get it wrong
  and have it go unnoticed.
- The chapter says the star's near-duplicate vertex heights (58.86881039375369 vs ...366) produce
  a 5-entry edge table "and neither should you [pin the count]". In this implementation, on
  Node 22 / V8, `star()`'s points 2 and 3 (angles 198° and 342°) come out **bit-identical**
  (`58.86881039375366` for both), so `edge_table(star())` has exactly 4 non-horizontal entries,
  not 5. Confirmed with a standalone script (not in the test suite, since the chapter correctly
  says not to pin this). Harmless either way — it's exactly the point the trap is making, just a
  different libm giving a different answer in the last bit. Worth a note in the prose that the
  count is genuinely toolchain-dependent, if it isn't already framed that way (it's close).

### Concrete changes I'd make

- None to the chapter itself — it's precise enough that translation was mechanical. See the
  Mutation results section below for the one real scenario gap this reading turned up (in
  chapter 5's even-odd rule).

## Chapter 6: Filling a Polygon

### Result

37 scenarios translated (including the 4-row `Scenario Outline` in chapter06-spans.feature
counted as 4 tests), all 37 pass, plus 1 output-writing test (38 total in the chapter-6 section).
Full suite after chapter 6: **284/284 passing**.

| Feature file | Scenarios | Pass |
|---|---|---|
| chapter06-edges.feature | 6 | 6 |
| chapter06-spans.feature | 16 (incl. 4-row outline) | 16 |
| chapter06-sweep.feature | 12 | 12 |
| chapter06-plate.feature | 3 | 3 |

`max_channel_difference` against `reference/chapter-06/`:
- `spiral.ppm`: **0**
- `plate-06.ppm`: **0**

Both bit-exact. Also independently confirmed the chapter's central claim in code, not just by
scenario: `fill_path_aliased(p, rule, w, h)` and `rasterize_centers(filled(p, rule), w, h)`
produce `max_coverage_difference == 0` for every shape in the suite, including the star under
both rules at 160×160.

### Catch-up

None needed here beyond chapter 5's catch-up (above) — chapters 5 and 6's own feature files are
new this session, so there was nothing prior to reconcile against.

### Ambiguities

- `edge_table` entry shape: fields named exactly as the prose says (`y_top`, `y_bottom`, `x_top`,
  `slope`, `direction`), as plain objects, since the scenarios reach into them by those names
  (`t[0].y_top`, etc.) — no ambiguity, just a direct transcription.
- Tie-breaking beyond `(y_top, x_top)` in `edge_table`'s sort: the prose explicitly says "allowed
  to fall in any order," and JS's `Array.prototype.sort` is stable since ES2019/V8 7.0, so ties
  keep edge-array order (`edges(p)` order, which follows subpath and winding order). No scenario
  distinguishes further, so this was a non-decision.
- `spans_from_crossings`/`spans`/`fill_path_aliased` all take crossings as `[x, direction]` pairs
  (plain 2-arrays) rather than objects — matches how chapter 5 already represents edges as
  `[a, b]` arrays, kept the convention consistent.

### Hard to translate

Nothing. The sweep, the active-edge list, and the edge table all map onto plain arrays and
objects with no impedance mismatch. `transform_path` is a two-line function once `path()`'s
internal shape is known from chapter 5.

### Failures

None outstanding.

### Prose problems

None found. The two "trap"-style warnings in this chapter (horizontal edges must be dropped by
exact `a.y === b.y`, and the half-open rule appears three separate times — in `crossings()`, in
`fill_span()`, and in the sweep's active-edge join/exit) are each backed by a scenario that
genuinely fails if you get the comparison direction wrong (verified directly — see Mutation
results). The chapter's own claim that this is "seventy times faster in Python" is not something
this JS implementation can confirm on its own terms (V8's JIT closes most of the gap a naive
interpreter would show), but the *relative* order-of-magnitude did show up clearly — see Timing.

### Concrete changes I'd make

- None. This was the smoothest chapter to translate of the two; the pseudo-code in §6.2/§6.3 is
  close enough to be nearly copy-paste, deliberately so, and it worked first try.

## Mutation results

Per the task, tried plausible reader mistakes against the finished chapter 5 + 6 code, one
mutation at a time, ran the full suite, then reverted. All mutations below were applied directly
to `test.js`, tested, and reverted; the repository is back to its pre-mutation state (verified
with `diff` against a saved copy after every revert).

| # | Mutation | Where | Caught? | By |
|---|---|---|---|---|
| 1 | `crossings()`'s half-open span test made inclusive at both ends (`a.y<=y<=b.y` or reverse) | Ch.5 `crossings` | Yes | "A ray through a vertex counts it once", "A diamond wound twice has winding number 2" |
| 2 | Same, made exclusive at both ends (`a.y<y<b.y`) | Ch.5 `crossings` | Yes | same two scenarios |
| 3 | `winding_at()`'s branch split changed from `a.y<=y`/`b.y>y` to `a.y<y`/`b.y>=y` | Ch.5 `winding_at` | Yes | "The boundary belongs to the top and the left", "An edge that starts on a sample height is active there, and one that ends there is not" (ch.6, since it cross-checks against `rasterize_centers(filled(...))`) |
| 4 | `inside_evenodd` changed from `Math.abs(w) % 2 === 1` to `w % 2 === 1` (drops the `abs`) | Ch.5 `inside_evenodd` | **No — passed all 284 tests** | — see below |
| 5 | Same drop-the-`abs` mutation in `spans_from_crossings`'s even-odd branch | Ch.6 `spans_from_crossings` | Yes | "A ring is two spans...", "The star's spans through its middle", "The star, both rules, matches chapter 5...", "A transformed star fills where the transform put it" |
| 6 | `fill_span`'s pixel-center math replaced with naive `Math.round(x0)` / `Math.round(x1)-1` instead of `ceil(x-0.5)` | Ch.6 `fill_span` | Yes | "The span is half-open at its right end", "A span may run off either side of the buffer", ch.6 sample-height scenario |
| 7 | Sweep's active-edge exit changed from `e.y_bottom > y` to `e.y_bottom >= y` | Ch.6 `fill_path_aliased` | Yes | "An edge that starts on a sample height is active there, and one that ends there is not" |
| 8 | Sweep's active-edge join changed from `table[next].y_top <= y` to `< y` | Ch.6 `fill_path_aliased` | Yes | same scenario |

**Mutation #4 is the real finding.** In JavaScript, `-1 % 2` is `-1`, not `1` — the language's `%`
keeps the sign of the dividend, unlike a true mathematical modulo. `inside_evenodd`'s correct
implementation must take `Math.abs(winding_at(...))` before checking oddness (which this
implementation does); a reader who writes `winding_at(p, x, y) % 2 === 1` directly gets a function
that is wrong for any point with a *negative odd* winding number, e.g. a solitary
counterclockwise-wound loop's interior (`winding_at = -1`) would be reported as **not** inside
under even-odd, when even-odd only cares about parity and should say inside. **No scenario in
chapter05-rules.feature or chapter05-winding.feature exercises `inside_evenodd` (or `winding_at`
combined with an even-odd check) at a point whose winding number is negative and odd** — every
even-odd scenario in the chapter only ever lands on windings of 0, 1, or 2. The equivalent bug in
chapter 6's `spans_from_crossings` *is* caught (mutation #5), because the star's own crossings
include both `+1` and `-1` directions and the accumulated `w` does go negative-odd partway through
a row — chapter 6 exercises the case chapter 5 never sets up. Concrete fix: add a scenario to
chapter05-rules.feature (or winding.feature) with a single counterclockwise loop — e.g.
`polygon(point(0,0), point(0,10), point(10,10), point(10,0))` (the existing "other way round"
square, which chapter05-winding.feature already shows has `winding_at(p, 5, 5) = -1`) — asserting
`inside_evenodd(p, 5, 5) = true`. That one scenario would have caught this.

## Timing

Measured with `node test.js` (Node 22.14.0) on the runner used for this session; wall-clock
`duration_ms` as reported by `node:test`'s TAP output for the render-heavy tests. Not a rigorous
benchmark, but the *relative* sizes are the point:

- Full suite (all 284 tests, chapters 1–6): **~9.9–10.3s** across a few runs.
- Chapter 5's two brute-force 64-sample rasterizations of the 160×160 star
  ("A filled path takes the rule seriously", nonzero + evenodd): **~517ms** combined
  (~250ms each).
- Chapter 5's "Plate 5" (four star panels, two of them 64-sample coverage rasterizations,
  plus magnify): **~690ms**.
- Chapter 6's "The star, both rules, matches chapter 5 pixel for pixel" (two
  `fill_path_aliased` sweeps of the same 160×160 star *plus* two `rasterize_centers` calls for
  comparison): **~12.2ms** combined.
- Chapter 6's "The spiral" (24 stars, each swept into a 320×320 canvas): **~62.5ms**.
- Chapter 6's "Plate 6" (spiral + 2× magnify): **~160ms**.

Rough read: one 160×160 coverage rasterization of the star costs on the order of 250ms in this
JS implementation; the equivalent sweep (which the "both rules" test above pairs with its own
`rasterize_centers` comparison, so the ~12ms figure includes *both* a sweep and a center-question
pass for both rules) is comfortably two orders of magnitude faster. The book's Python figures
("about a millisecond" for the sweep, "about seventy" for the center test, ratio ~70×) don't carry
over literally to V8 — the JIT makes the naive per-pixel-per-edge center/coverage loop much
faster than CPython's interpreter, so the *absolute* numbers here are all smaller than the book's
Python ones — but the *shape* of the result (sweep dramatically cheaper than brute force,
worsening with more edges/pixels) reproduced cleanly.
