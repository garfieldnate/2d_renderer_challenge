# Reader feedback — chapters 5 and 6, C11

Cold read, C11 (clang, `-std=c11 -Wall -Wextra -O2`, libm only, no other dependencies).
Chapters 1-4 were pre-existing in this scratch dir; I brought their tests up to date
with `features/` first (§0 below), then implemented chapter 5 end to end, rendered
and diffed it, then chapter 6 the same way.

## Catch-up (chapters 1-4 before starting chapter 5)

Diffing every `Scenario:`/`Scenario Outline:` title in `features/chapter0[1-4]*.feature`
against the scenario names already in `src/tests.c` turned up five scenarios that had
never been translated:

- `A union of nothing is inside nowhere` (chapter04-drawing.feature)
- `Invertibility is an exact test against zero` (chapter04-matrices.feature)
- `magnitude and dot look at x and y only` (chapter04-tuples.feature)
- `side_by_side puts the first canvas on the left` (chapter04-plate.feature)
- `The weights are applied in light, whatever the switch says` (chapter03-wu.feature)

I added all five. Four passed immediately against the existing code. The fifth —
`line_wu`'s weights ignoring the browser-mode switch — **failed on the existing
code**: `plot()` (chapter 3's one-pixel `paint_through`) called the three-argument
`mix(...)`, which reads the global `linear_blending` switch, instead of forcing linear
blending the way `paint_through` itself does. With `linear_blending` off, `pixel_at(c,
1, 0)` came back `(0.214041, 0.214041, 0.214041)` instead of the expected `(0.5, 0.5,
0.5)`. Fixed by changing `plot()` to call `mix4(pixel_at(c, x, y), col, weight, true)`
directly, matching `paint_through`'s existing comment ("the switch has no business
inside the rasterizer"). Re-ran the full suite (211 scenarios at that point): all
green, and the chapter 1-4 renders still diff at 0 against `reference/`.

## Result

    280 scenarios, 280 passed, 0 failed
    chapter 1: 62/62   chapter 2: 35/35   chapter 3: 38/38   chapter 4: 76/76
    chapter 5: 32/32   chapter 6: 37/37

Every scenario in `chapter05-paths.feature`, `chapter05-winding.feature`,
`chapter05-rules.feature`, `chapter05-plate.feature`, `chapter06-edges.feature`,
`chapter06-spans.feature`, `chapter06-sweep.feature` and `chapter06-plate.feature`
is translated, none skipped, none weakened. `max_channel_difference` against
`reference/`:

| render | size | max_channel_difference |
|---|---|---|
| `star-centers.ppm` | 320x160 | 0 |
| `star-coverage.ppm` | 320x160 | 0 |
| `plate-05.ppm` | 640x640 | 0 |
| `spiral.ppm` | 320x320 | 0 |
| `plate-06.ppm` | 640x640 | 0 |

All five are byte-identical to the reference, not just within the ± 1 the scenarios
allow.

## Ambiguities (guessed, not scenario-pinned)

- **Path value vs. reference semantics.** Gherkin's `move_to(p, point(...))` mutating
  `p` doesn't say whether `p` is a value or a reference — that's a language question.
  I made `Path` a heap-allocated, pointer-mutated type (`Path *path(void)`,
  `move_to(Path *p, ...)`), matching the existing `Canvas`/`CoverageBuffer` convention.
  A reader who instead made `Path` a value type would find `move_to` silently mutating
  a local copy and every scenario failing at the first assertion — safe, but only
  because it fails loudly.
- **`subpaths(p)` and `length(subpaths(p))`.** The book presents these as accessor
  calls. Since `Canvas` already exposes `width`/`height`/`pixels` as plain public
  fields rather than through getters, I did the same for `Path`:
  `p->subpaths[i].points[j]`, `p->subpaths[i].closed`, `p->n_subpaths`. `edges(p, &n)`
  and `bounds(p)` stayed real functions, since the prose is explicit that they're
  *derived* views, not part of the stored structure.
- **The `rule`/`method` parameter.** `filled(p, rule)`, `spans_from_crossings(xs,
  rule)`, `spans(p, rule, row)` and `star_panel(rule, method)` all take `const char *`
  and compare against the literal strings the scenarios use ("nonzero", "evenodd",
  "centers", "coverage"), stored internally as a 0/1 int rather than the book's string.
  Never pinned either way, but see "Concrete changes" below — this is a bit of a
  loaded gun.
- **`Bounds`, `EdgeEntry`, `Crossing`, `Span`.** None of these have book names beyond
  a tuple notation (`(min x, min y, max x, max y)`, `(x_top, slope, ...)`, `(x,
  direction)`, `(x0, x1)`). I invented struct names and field names for all four;
  any two C readers would invent different ones and the scenarios wouldn't notice,
  since Gherkin never names a field, only a position.
- **Ownership of heap arrays.** `edges()`, `edge_table()`, `crossings_on_row()`,
  `spans_from_crossings()` and `spans()` all return `malloc`'d arrays the caller frees
  (an out-parameter carries the count). The book's pseudocode treats these as ordinary
  lists in a memory-managed language; nothing pins who frees what, since no scenario
  can observe a leak. I freed everything in the test suite anyway, on the theory that
  Valgrind is one command away even if no scenario asks for it.

## Hard to translate

- **`polygon(p1, p2, ...)`.** A genuinely variadic constructor over `Tuple` values with
  no explicit count. C has no clean equivalent; I used a macro
  (`polygon(...) -> polygon_pts((Tuple[]){__VA_ARGS__}, sizeof(...)/sizeof(Tuple))`),
  the same trick the pre-existing harness already used for `EQ_PIXELS`. It only works
  when the whole argument list is visible at the call site as literal values — you
  can't build an array elsewhere and forward it through the macro. Every scenario
  happens to call `polygon(point(...), point(...), ...)` directly, so this never bit,
  but it's worth knowing the macro is the only reason it worked.
- **String-typed rule/method parameters** are an unusual shape for a C API: nothing
  stops a typo (`"envenodd"`) from silently parsing as `"nonzero"`. No scenario probes
  a misspelled rule, so this is invisible to the suite as written.
- **`close`** is also the POSIX file-descriptor function from `<unistd.h>`. Nothing in
  this project includes it, so `void close(Path *p)` is the only `close` in scope and
  the build is silent, but a C or C++ reader working in a project that also touches
  file descriptors would collide immediately and might not guess why.
- Nothing else was genuinely hard — chapter 6's floor/ceil arithmetic in `fill_span`
  and `rasterize_within` needed the usual explicit `(int)` casts C requires that a
  managed language wouldn't, but the prose ("columns from floor(min x) up to but not
  including ceil(max x)") was precise enough that this was mechanical, not ambiguous.

## Failures

None outstanding. The one real failure (chapter 3's `plot()`, described under
Catch-up) was diagnosed and fixed before starting chapter 5; every chapter 5 and
chapter 6 scenario passed on the first implementation attempt, with no reference
mismatches, no weakened tolerances, and no scenarios skipped or deleted.

## Prose problems

None found in chapters 5 or 6. Both chapters' scenarios were sufficient to pin a
correct implementation without consulting anything outside `chapters/` and
`features/` — every numeric probe I hit (the star's exact vertex coordinates, the
crossings/spans/winding numbers through its middle, the edge table's sort order,
the sweep-vs-chapter-5 equality) matched on the first attempt. The parenthetical in
§5.2 ("[the crossing count] has the same parity [as the winding number]") checks out
against every scenario I translated (e.g. `crossings(p, -1, 5) = 2` / `winding_at(p,
-1, 5) = 0`, both even; `crossings(p, 2, 5) = 1` / `winding_at(p, 2, 5) = 1`, both
odd) and is a nice thing to have stated in the open rather than left for the reader
to notice.

## Mutation results

Four mutations, applied one at a time to `src/renderer.c`, full suite re-run after
each, then reverted (confirmed identical to the pre-mutation source via `diff`
before moving on):

1. **Chapter 6 trap, played straight: keep horizontal edges in `edge_table` instead
   of dropping them** (slope 0, a synthetic one-row height, exactly the mistake the
   chapter's own trap box describes). Caught hard: 18 of chapter 6's 37 scenarios
   failed, across the edge table, spans, sweep and plate features (including the
   star's spiral, off by 204 in `max_channel_difference`). The trap is well-founded
   and thoroughly tested.

2. **Chapter 6: off-by-one in the sweep's active-edge-list eviction** — changed
   `active[i].y_bottom > y` to `>= y`, so an edge is dropped one row before it should
   be. Caught by exactly one scenario, the one built for precisely this corner ("An
   edge that starts on a sample height is active there, and one that ends there is
   not"). No collateral damage elsewhere, which is correct — this is a one-pixel-tall
   rectangle scenario and nothing else in the suite sits on that exact boundary.

3. **Chapter 5: flip `winding_at`'s sign convention** (swap the `w++`/`w--` in its two
   branches). Caught immediately by the ten scenarios that pin `winding_at`'s exact
   numeric value (the diamond, the polygon circle, both "inner loop" scenarios, the
   pentagram). Notably, it was **not** caught by any `inside_nonzero`/`inside_evenodd`
   or fill/coverage scenario — both rules are mathematically insensitive to a global
   sign flip (`w ≠ 0` is the same for `w` and `-w`; the parity of `w` and `-w` is
   identical). Not a suite gap, just confirmation that the exact-value `winding_at`
   scenarios are the only thing standing between a correct implementation and one
   with every loop wound backwards, and they do their job.

4. **Chapter 5: loosen `crossings`'s ray-cast comparison from strict `>` to `>=`**
   (count a crossing that lands exactly on the query point's x as "to the right").
   **Passed all 280 scenarios.** This is a genuine gap: `winding_at` has dedicated
   boundary scenarios (`The boundary belongs to the top and the left`, the two
   ray-through-a-vertex scenarios) that pin its half-open behavior exactly, but
   `crossings()` itself is never independently probed at a point that sits exactly on
   a crossing's x — every scenario that calls `crossings(...)` uses integer sample
   points against crossings at other, non-coincident x values. See "Concrete changes."

## Concrete changes I'd make

- Add a scenario for `crossings(p, x, y)` with `x` chosen to land exactly on a
  crossing (e.g. a square's crossings queried from `x = 0` or `x = 10` rather than
  `5`, `15`, `-1`), the same way `winding_at` already gets one. Mutation 4 above shows
  the current suite can't tell `>` from `>=` in `crossings` at all.
- Nothing else — chapters 5 and 6 were the smoothest of the four I've now touched in
  this project: every render matched the reference exactly (not just within
  tolerance), and no scenario needed a second reading to translate.

## Timing

`make test` (280 scenarios, from a clean build): well under a second; `TIMING=1`
breakdown for the two new chapters:

    feature_paths        0.1 ms      feature_edges       0.0 ms
    feature_winding      0.0 ms      feature_spans       0.0 ms
    feature_rules       52.3 ms      feature_sweep       1.0 ms
    feature_plate_05    68.2 ms      feature_plate_06   27.1 ms

`feature_rules` and `feature_plate_05` cost what they cost because they rasterize the
star at full 64-sample coverage (`rasterize(shape, 160, 160)` in "A filled path takes
the rule seriously") — chapter 6 makes the same picture in 27 ms via the sweep instead
of chapter 5's ~68 ms combined coverage cost, which is the chapter's whole point,
demonstrated by its own test suite rather than just asserted in prose.

`make render` (all six chapters' pictures, `./bin/render` alone, excluding
compilation): 0.78 s total. The chapter 6 spiral (24 stars, each a fresh
`fill_path_aliased` over a 320x320 buffer) is comfortably the single most expensive
picture and still negligible next to chapter 4's `plate_04`/`fan_both_orders`
supersampled renders (400 ms in the test binary alone, at 64 samples/pixel over
several unions of thick lines).
