# Catch-up pass: chapters 22-23 (Java)

## Scenarios diffed

Compared every `Scenario:` title (case-insensitively, ignoring the `Section: `
prefix this suite adds) in `features/chapter22-*.feature` and
`features/chapter23-*.feature` against `src/Chapter22Tests.java` /
`src/Chapter23Tests.java`.

**New:**
- `Robust: At a shared corner the furthest right turn is not the first edge in
  the list` (`chapter22-robust.feature`). Added: `a = polygon((1,0),(3,2),(2,4))`,
  `b = polygon((3,2),(4,3),(4,4))`, asserts the union's two contours. Passed
  immediately on the existing `Stitching`/`BoolCombine` code (see below).

**Renamed only (content unchanged):**
- `Render: at the star's points it's a long way off, and inside it's wrong
  until simplified` → `...until the path is simplified`. Renamed to match;
  no assertions changed.

- The scenario-outline-driven `Render: each render matches its reference`
  already expands to per-render scenarios (`atlas_corners`, `error_map`,
  `fields_vs_paths`, `fillets`, `primitive_fields`, `title`,
  `transform_demo`, `trap_shrink`) in this suite's style, and `Bentley:
  Bentley-Ottmann finds what every pair finds...` is just this suite's
  existing `Bentley: finds what every pair finds...` without the repeated
  feature name. Neither is a real gap.

## Failures found and fixed

Two chapter-22 scenarios failed **before** any scenario was added, both in
`BentleyOttmann.findSplits`:

- `Bentley: finds what every pair finds, testing neighbours only` — point 2 of
  segment 168 was `(81005, 36986)`, expected `(81005, 36985)`.
- `Bentley: the whole split, three ways, one answer` — `a` (brute) didn't
  equal `c` (bentley-ottmann) at all.

Cause: the implementation cut each `Piece`'s `lo` down to the rounded crossing
point as the sweep progressed (`cutRemainders`, building a new `Piece(newLo,
pc.hi, ...)`). The rounded cut point can sit up to half a grid unit off the
segment's true line, so every later orientation test, crossing test, and
crossing-point computation against that piece used a perturbed line instead
of the segment's real one — exactly the bug the feature's clarified prose
calls out: *"Nothing is cut during the sweep: every segment keeps the ends it
had when find_splits was called, and every test and every crossing uses
those ends. The cuts happen afterwards, in split_segments."*

Fix: `BentleyOttmann.java` no longer builds a rounded remainder `Piece`. The
block's C-pieces (those whose `hi` isn't the event) are still recorded as
split points but are now carried forward into the new status block as the
exact same, unmutated `Piece` (original `lo`/`hi`), so every `orientSign`,
`meet`, and `crossingEvent` call for the rest of the sweep uses the segment's
true endpoints. Both failing scenarios pass now, byte-for-byte against the
feature's numbers (`st.tests = 1659`, `st.events = 879`, `length(c) = 1559`,
`brute.tests = 2012677`, `sweep.tests = 278841`, `bo.tests = 5224`,
`bo.events = 2823`, `bo.passes = 2`).

## Other flagged rules, checked and already correct

- **Stitching's furthest-right turn as a formula**: `Stitching.halfOf`/
  `turnsFurtherRight` already implement the exact half/cross/dot formula in
  the feature's prose (not an `atan2` approximation), and match
  `Tuple.cross`'s convention directly. Confirmed by adding the new corner
  scenario above, which passed unmodified.
- **`is_corner`'s `sin(3)` in radians**: `Msdf.isCorner` uses `Math.sin(3)`,
  and Java's `Math.sin` always takes radians, so this was already right
  (nothing to change) — reader implementations in languages where `sin`
  takes degrees would have needed a fix here, Java didn't.
- **MSDF tie-break's `o`**: `Msdf.msdfChannel`'s tie-break (`o = 0` unless
  `t == 0 || t == 1`, else `|dot(dir, unit(p - end))|`) already matches the
  feature prose exactly.
- **The title's four passes**: `Chapter23Figures.title()` already runs four
  separate `for (Placement pl : run)` loops, one per effect, each drawing the
  whole run before the next starts. Nothing to change.

## Final state

- `Chapter22Tests`: 54/54 passing (53 existing + 1 new).
- `Chapter23Tests`: 43/43 passing (unchanged count; one scenario renamed).
- Full suite, chapters 1-23: all 23 test classes green (819 scenarios total
  across the suite, 0 failures).
- All eleven chapter-22/23 renders (`plate-22`, `seal`, `atlas-corners`,
  `error-map`, `fields-vs-paths`, `fillets`, `plate-23`, `primitive-fields`,
  `title`, `transform-demo`, `trap-shrink`) are byte-exact against
  `reference/chapter-22/` and `reference/chapter-23/` after the fix.

## Files touched

- `src/BentleyOttmann.java` — removed mid-sweep cutting; carries pieces
  forward unmutated.
- `src/Chapter22Tests.java` — added the missing corner scenario.
- `src/Chapter23Tests.java` — renamed one scenario to match current wording.
