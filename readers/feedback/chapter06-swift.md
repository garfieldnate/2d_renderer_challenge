# Reader feedback — Swift, chapters 5–6

Staged from `readers/swift/`, built on top of an existing chapters 1–4 implementation
(210 scenarios passing). Implemented chapters 5 and 6 cold, from the chapter HTML and
`features/chapter05-*.feature` / `features/chapter06-*.feature` alone. Did not read or
write anything outside this directory.

## Chapter 5 — Paths and Insideness

### Result

32 scenarios, all passing:

| Feature file | Scenarios |
|---|---|
| chapter05-paths.feature | 10 |
| chapter05-winding.feature | 9 |
| chapter05-rules.feature | 9 |
| chapter05-plate.feature | 4 |

Renders: `star-centers.ppm`, `star-coverage.ppm`, `plate-05.ppm`, all diffed against
`reference/chapter-05/` with `max_channel_difference` — **0** for all three (byte-identical,
confirmed both via the in-scenario check and `cmp -s`).

### Catch-up

Before starting chapter 5, re-read every `features/chapter0[1-4]-*.feature` against the
existing `Tests.swift` and found five scenarios that existed in the feature files but had
never been translated:

- `The weights are applied in light, whatever the switch says` (chapter03-wu.feature)
- `magnitude and dot look at x and y only` (chapter04-tuples.feature)
- `Invertibility is an exact test against zero` (chapter04-matrices.feature)
- `A union of nothing is inside nowhere` (chapter04-drawing.feature)
- `side_by_side puts the first canvas on the left` (chapter04-plate.feature)

Added all five. Four passed immediately with no code change. The first one caught a real
bug: `plot(c, x, y, col, weight)` (§3.2, Wu's line) was calling the switchable `mix(a, b,
t)` instead of `mix(a, b, t, true)`. The chapter's prose is explicit that plotting a
Wu-line pixel happens "in light whatever the global switch says," matching `paint_through`
— but the existing code passed the plain 3-argument `mix`, so with `linearBlending` set
false the antialiasing weights were gamma-blended instead of linear. Actual vs expected
before the fix:

```
pixel_at(c, 1, 0): (0.21404114048223244, 0.21404114048223244, 0.21404114048223244) != (0.5, 0.5, 0.5)
```

This never showed up in any existing render or scenario because `linearBlending` defaults
to `true` and no render ever flips it off before drawing a Wu line — the bug was invisible
until a scenario specifically toggled the switch first. One-line fix: pass `true` as the
fourth argument to `mix` inside `plot`. Re-ran the full suite after the fix; all chapters
1–4 still green (210 → 214 with the four new no-op scenarios plus this one).

### Ambiguities

- `circle_path(cx, cy, r, n)`'s "first point at angle 0, on the right, going clockwise on
  the screen" is stated but the exact formula isn't spelled out the way `star()`'s
  pseudocode is. Guessed the obvious `point(cx + r·cos(2πi/n), cy + r·sin(2πi/n))` for
  `i` in `0..<n` — increasing `i` sweeps toward positive y first, which is clockwise on a
  canvas whose y points down, matching chapter 4's rotation convention. The scenario
  (`circle_path(10, 10, 5, 8)` → `points[1] = point(13.5355, 13.5355)`) confirmed the guess
  on the first try, so this is a minor gap rather than a real ambiguity, but a reader in a
  language without a handy `cos`/`sin` convention check could get the direction backwards
  and not know until they hit that one assertion.
- `bounds(p)` on an empty path is pinned to exactly `(0, 0, 0, 0)`, which I implemented as
  "track min/max lazily, defaulting all four to 0 before the first point is seen." Works,
  but it means `bounds` of a path with one subpath of one point at `(-5, -5)` is
  `(-5, -5, -5, -5)`, not something involving the "phantom" `(0,0)` default — worth double
  checking the scenario coverage here isn't accidentally testing the lazy-init path instead
  of a real reduce; it is (the "subpath of one point" scenario uses positive coordinates on
  both points, `(1,1)` and `(2,2)`, so a bug that left the `(0,0)` default mixed in would
  have been caught — good scenario design, no gap).

### Hard to translate

Nothing hard. `Path` as a reference type (`final class`) with mutating free functions
(`moveTo`, `lineTo`, `close`) matches the existing `Canvas`/`CoverageBuffer` convention
in this codebase exactly, so path mutation reads the same way `write_pixel(c, ...)` does
elsewhere. `Subpath` as a value-type struct nested in `path.subpaths: [Subpath]` was the
only design choice, and it made `edges(p)` and `bounds(p)` straightforward `for` loops.

### Failures

None — every chapter 5 scenario passed once implemented against the prose and pseudocode
as written.

### Prose problems

None found in chapter 5 itself. (See the plot() bug above — that's a chapter 3 prose
claim the existing code silently violated, not a chapter 5 problem, but it's the reason
chapter 5 couldn't start clean.)

## Chapter 6 — Filling a Polygon

### Result

37 scenario() calls (34 `Scenario:`/`Scenario Outline:` lines in the feature files; the
"A triangle's spans narrow by one per row" outline expands to 4), all passing:

| Feature file | Scenarios (as written) |
|---|---|
| chapter06-edges.feature | 6 |
| chapter06-spans.feature | 16 (13 raw `Scenario:`/`Scenario Outline:` lines, the outline expanding to 4 rows, net +3) |
| chapter06-sweep.feature | 12 |
| chapter06-plate.feature | 3 |

Renders: `spiral.ppm`, `plate-06.ppm`, both diffed against `reference/chapter-06/` —
**0** (byte-identical).

### Catch-up

None specific to chapter 6 — the catch-up pass happened once, before chapter 5, and
covered chapters 1–4 (see above). No chapter 5 or 6 scenarios existed before this session.

### Ambiguities

- `x_at(edge, y) = x_top + (y - y_top) * slope` is given explicitly, but which endpoint of
  the original `(a, b)` pair becomes `x_top`/`y_top` when `a.y > b.y` (i.e. the edge heads
  up) isn't spelled out as a formula, only implied by "which of its two ends is higher on
  the canvas." Implemented as: if `a.y < b.y`, top is `a`, `slope = (b.x-a.x)/(b.y-a.y)`,
  `direction = +1`; else top is `b`, `slope = (a.x-b.x)/(a.y-b.y)`, `direction = -1`. The
  "same whichever way drawn" scenario is exactly the check that this convention is
  self-consistent (same `x_top`, same `|slope|`, opposite `direction`), and it passed on
  the first attempt, so the guess was right, but the formula itself isn't printed anywhere
  the way `x_at` is.
- The active-edge-list sweep's pseudocode filters `active` with `e.y_bottom > y` after
  advancing `next`, but doesn't say explicitly what happens to an edge whose `y_top`
  equals the *previous* row's sample height plus a full step — i.e., whether an edge can
  be added and removed in between two consecutive integer rows without ever being sampled.
  It can't, in practice (edges span at least one row of height 1 or they'd be horizontal
  in this book's grid), so this never came up, but it's a case the pseudocode doesn't rule
  out by construction the way the half-open row-sampling case does.

### Hard to translate

`Edge` as a small value-type `struct` with five stored `Double`/`Int` fields translated
directly — no friction. The one place Swift's ergonomics mattered was
`table.sort { $0.yTop != $1.yTop ? $0.yTop < $1.yTop : $0.xTop < $1.xTop }`: Swift's
`Array.sort` is guaranteed stable since Swift 5, which the prose relies on implicitly
("ties beyond that are allowed to fall in any order") — a language whose sort isn't
stable would need to say so explicitly, or the "sorted by y_top, then by x_top" scenarios
with four-way ties (`t[0]` through `t[3]` all sharing `y_top = 1`) would be
under-specified for that reader.

### Failures

None — every chapter 6 scenario passed once implemented against the pseudocode as
written, including the pixel-for-pixel comparison against chapter 5's
`rasterize_centers(filled(p, rule), w, h)` for a rectangle, a triangle (both windings), a
polygon circle, and the star under both rules.

### Prose problems

None. The chapter's own named trap (horizontal edges dropped, not clamped) and its
worked half-open-rule explanation for the active edge list matched the implementation
needed to pass the scenarios exactly; no guessing required.

## Mutation results

Five one-line mutations to `Renderer.swift`, applied and reverted one at a time, full
suite (`./run`) rerun after each:

1. **`windingAt`'s half-open rule broken** (`b.y > y` → `b.y >= y` in the "heading down"
   branch, reproducing the exact vertex-double-counting bug the chapter's own trap
   describes for `crossings`). **Caught** — 5 scenarios failed: "A ray through a vertex
   counts it once," "The boundary belongs to the top and the left," "A diamond wound
   twice has winding number 2," "The polygon circle," and (in chapter 6) "An edge that
   starts on a sample height is active there, and one that ends there is not."
2. **Sweep active-edge-list off-by-one** (`active.filter { $0.yBottom > y }` →
   `{ $0.yBottom >= y }`, keeping an edge active one row too long at its bottom).
   **Caught, but only just** — exactly 1 scenario failed ("An edge that starts on a
   sample height is active there, and one that ends there is not"). Notably, the star
   pixel-for-pixel comparison ("The star, both rules, matches chapter 5 pixel for pixel")
   did **not** catch it, because none of the star's five vertices happen to land on an
   integer-plus-0.5 sample height. This is a real fragility: the suite's only defense
   against this exact off-by-one is one hand-built rectangle scenario. If that scenario
   were ever deleted or weakened, this bug would ship silently on every render that
   doesn't happen to have geometry aligned to a sample row.
3. **Horizontal edges kept in the edge table** (removed the `guard a.y != b.y else {
   continue }` in `edgeTable`, matching the chapter's own named mistake). **Caught** — 6
   scenarios failed, including "A flat top is not a span of its own," the scenario
   written for exactly this trap.
4. **`fillSpan`'s right end made inclusive** (`Int(ceil(x1 - 0.5)) - 1` →
   `Int(floor(x1 - 0.5))`, agreeing with the correct formula only when `x1` isn't exactly
   on a sample center). **Caught** — 6 scenarios failed, including both render diffs
   (`spiral.ppm`, `plate-06.ppm`), so this one would have been caught by the plate alone
   even without the unit-level span scenarios.
5. **`crossings(p, x, y)`'s strict "to the right" test loosened** (`if xc > x` → `if xc >=
   x`). **Not caught — passed all 284 scenarios and produced byte-identical renders.**
   This is the most valuable finding. `crossings` is a diagnostic function used only by
   test scenarios in this book (every render goes through `windingAt`/`filled`, never
   `crossings` directly), and every scenario that calls `crossings` happens to query a
   point whose x is strictly to the left of every relevant edge crossing — none puts the
   query point exactly on a crossing's x. The chapter is explicit that "if that x is to
   the right of your point, you'll walk through it: count it," which is a strict
   inequality, but no scenario forces the boundary case (`xc == x`) to disagree from the
   `>=` version. A scenario with a vertical edge at the same x as the query point (e.g. a
   square with a corner exactly at the query x) would catch this in one line.
6. **Sweep activation off-by-one, the other direction** (`table[next].yTop <= y` →
   `< y`, delaying activation of an edge whose top lands exactly on a sample height).
   **Caught** — 3 scenarios failed, including both chapter 6 render diffs.

All mutations were reverted; `diff` against the pre-mutation `Renderer.swift` confirmed
a clean revert before moving on, and the full suite (284/284) plus all sixteen render
diffs (0 in every case) were re-verified at the end.

## Concrete changes I'd make

- Fix the missing `mix(..., true)` in `plot()` (done, see Chapter 5 catch-up above) — this
  should be checked against every chapter that has a "the arithmetic ignores the switch"
  claim, since it's exactly the kind of thing a reader copies from an earlier working
  function and doesn't re-derive.
- Add a `crossings()` scenario with the query point exactly on a crossing (e.g.
  `crossings(polygon(point(0,0), point(10,0), point(10,10), point(0,10)), 10, 5)`, which
  should be `0` under the strict "to the right" rule but `1` under a `>=` mistake) — see
  mutation 5 above. This is the one place in six chapters where a plausible off-by-one
  slipped through every scenario and every render diff.
- Consider a second scenario for the sweep's active-edge-list bottom boundary that isn't
  a plain axis-aligned rectangle, so a bug there doesn't rely on exactly one hand-built
  test (see mutation 2). The star-based comparison scenario is a good general safety net
  but structurally cannot catch this class of bug, because the star's vertices are
  irrational multiples of 0.5 by construction.
- `x_at`'s "which end is `y_top`" convention (§6.1) could use one more sentence spelling
  out the assignment the way the formula for `x_at` itself is spelled out, for a reader
  translating into a language where "the smaller-y endpoint" isn't as immediate a
  one-liner as it is in Swift/Python.

## Timing

All times on this machine, `swiftc -O`, chapters 1–6 combined (`./run` — 284 scenarios):
4.2–4.3s total test-suite time across several runs. Slowest individual scenarios
throughout were the chapter 5 coverage-based renders re-run inside scenarios
("A filled path takes the rule seriously" ~850ms, "Rasterizing within the bounds gives
the same coverage" ~720ms, "Plate 5" ~650ms, "The star by coverage" ~590ms) — these are
chapter 5's explicitly-acknowledged stopgap reference renderer (64 samples/pixel, a
winding number over five edges, per sample), not chapter 6's sweep.

`./run render` (writes all sixteen P6/P3 files):

- `star_coverage()` + `plate_05()` (four 64-samples/pixel panels, since `plate_05()`
  re-runs `star_centers()` and `star_coverage()` itself, matching the book's own
  `plate_05` pseudocode): **1.17–1.67s** across runs.
- `spiral()` + `plate_06()` (forty-eight scanline fills of a 320×320 canvas — twenty-four
  stars nonzero-filled, drawn once for `spiral()` and reused via `magnify` for
  `plate_06()`, so really twenty-four fills, not forty-eight): **0.029–0.031s** across
  runs.

That's roughly a 40–55x speedup from the scanline sweep over the supersampled reference
renderer on this machine — smaller than the book's "seventy times faster in Python"
claim, which makes sense: the gap the chapter describes is inherent to the *algorithm*
(edges × pixels-that-don't-touch-them) and grows with canvas size and edge count, and a
compiled language's constant-factor advantage on the slow path (branch-heavy per-sample
winding-number tests) is larger than its advantage on the fast path (mostly array
indexing and arithmetic), so the ratio compresses compared to an interpreted language —
consistent with the chapter's own aside that "in a compiled language the sweep is too
fast to time with a stopwatch," relatively speaking.
