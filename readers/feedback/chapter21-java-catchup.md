# Catch-up pass: Java, chapters 1-21

Compared every `.feature` scenario against the existing Java tests. Found new/changed
scenarios in three files, translated them, ran the suite, fixed what failed. Final: 722
scenarios, all green. All five chapter 20/21 renders byte-identical to reference.

## New/changed scenarios

**`chapter08-flatten.feature`** -- two brand-new scenarios, neither previously translated:

- "Appending curves to a path joins them without repeating a point"
- "A curve that starts away from the pen is joined with a line, and after a close it
  starts a new subpath"

Both **failed on the existing code**. `Curves.flattenIntoPath` was the naive
`for (pt : flatten(c, tol)) p.lineTo(pt)`, which:

1. Never dropped a duplicate point when the curve's first flattened point landed exactly
   on the pen (consecutive curves sharing an endpoint got a zero-length edge at the join).
   `expected 25 but got 26`.
2. After a `close()`, relied on `Path.lineTo`'s own "start a new subpath at the closed
   one's first point" rule -- which restarts at the *previous* subpath's start, not the
   *new curve's* first point. `expected (50, 0) but got (0, 0)`.

This bug had been sitting in `Curves.flattenIntoPath` for twelve chapters, invisible
because nothing pinned it (see README's note that chapter 20's own point counts are what
first surfaced it in a different reader). `SvgBuilder.java` had already grown a private
`flattenIntoPathNoDup` to work around it locally for SVG path-building. Fixed
`Curves.flattenIntoPath` itself to the chapter's now-stated rule, and deleted
`SvgBuilder`'s duplicate -- it now calls `Curves.flattenIntoPath` directly. Verified no
regression: chapters 8, 15 (which flattens curves into open paths, incl. the golden
spiral's six curve-to-curve joins), and 20/21 (heavy `SvgBuilder` users) all still green,
and all five chapter 20/21 renders still diff 0.

**`chapter20-style.feature`** -- new scenario "Opacities are clamped, a miter limit below 1
is ignored, and so is anything that doesn't parse". **Passed on the existing code, no bug
found.** `SvgStyle.parseProperty` already clamps opacity/fill-opacity/stroke-opacity to
[0,1] and rejects `stroke-miterlimit < 1` or an unparseable `stroke-width`/`fill-rule` as
`INVALID` (silently ignored, keeping the inherited/initial value).

**`chapter20-groups.feature`** -- new scenario "A clip's shapes take their style from the
clipPath" (`clip-rule` set on the `<clipPath>` element itself, not on its child).
**Passed, no bug found.** `SvgClip.clipCoverage` already computes the clipPath's own style
from `initial_style()` and passes it as the parent for each child's `computedStyle`, and
`clip-rule` is in the inherited-properties set, so this was already correct -- just
untested directly.

**`chapter20-walker.feature`** -- new scenario "The dash offset moves the pattern along the
path" (`stroke-dashoffset` on a plain, untransformed stroke). **Passed, no bug found.**
`SvgWalker` already threads `st.strokeDashoffset` into `Dash.dash`.

**`chapter21-spans.feature`** -- new scenario "A solid tile cut short by the canvas copies
only the pixels on the canvas" (a 40x40 canvas, polygon covering the whole thing, so the
last tile column/row is only 8px instead of 16). **Passed, no bug found.**
`Tiles.drawTiled` already clips both tile dimensions with
`Math.min(t0 + TILE, width/height)` before iterating pixels, so a cut-short solid tile was
never over-counted here (this is the bug the git history says a *different* reader's Rust
port had -- counting every solid tile as a full 256 copies regardless of canvas edges).

**`chapter21-tiles.feature`** -- existing scenario "A horizontal edge makes a tile
partial, and an edge off the canvas deposits nothing" (renamed from "...off canvas...")
gained two `coverage_in` assertions at the end (`coverage_in(tiled, 50, 20) = 1`,
`coverage_in(tiled, 20, 50) = 0`). Added both to the existing Java test. Passed
immediately -- these just exercise `Tiles.fillPathTiled` + `Coverage.coverageIn` on a
shape already covered by the scenario's `classify_tiles` assertions.

## Ambiguity

None worth flagging. The three chapter 20 additions and the chapter 21 addition read as
"pin what the reference implementation already specifies", not new behavior -- they
exist to catch implementations that got style inheritance, clamping, dash offset, or tile
clipping wrong, and this one already had them right. The chapter 8 pair is the one that
actually earns its place: it caught a real, long-lived bug.

## Final counts

| Chapter | Scenarios | Before this pass |
|---|---|---|
| 8  | 25 | 23 |
| 20 | 86 | 83 |
| 21 | 22 | 21 |
| all others | unchanged | unchanged |
| **Total** | **722** | 716 |

All 722 green. `./out/aspect_demo.ppm`, `harbor.ppm`, `rose.ppm`, `tiger.ppm`,
`work_map.ppm` all diff 0 (`max_channel_difference`) against
`reference/chapter-20/` and `reference/chapter-21/`.

README updated: chapter 8's `flattenIntoPath` description, and the chapter 20/21 scenario
counts and notes.
