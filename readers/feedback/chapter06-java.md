# Reader feedback — Java, chapters 5 and 6

Cold implementation from `chapter-05.html`/`chapter-06.html` and the `features/`
`.feature` files alone, on top of the existing chapters 1-4 Java code staged in
this directory. No access to the book's own repository or reference
implementation.

## Catch-up (done before starting chapter 5, covers chapters 1-4)

Diffed every `features/chapter0{1,2,3,4}-*.feature` scenario name against the
scenarios already registered in `Chapter01Tests.java`...`Chapter04Tests.java`.

New scenarios found missing from the existing code, and what happened when I
added them:

- **`Wu: the weights are applied in light, whatever the switch says`**
  (`chapter03-wu.feature`) was entirely absent from `Chapter03Tests.java`.
  Adding it and running it **failed**: `Lines.plot` called the unforced,
  three-argument `Mixer.mix(pixel, col, weight)`, which honors the global
  `Mixer.linearBlending` switch. §3.2 states plainly: "To light a pixel at a
  weight, you paint it: `mix(pixel_at(c, x, y), col, weight, true)` ... in
  light whatever the global switch says." **Real bug, fixed**: `Lines.plot`
  now calls the forced, four-argument overload.
- **`Paint: the arithmetic is on light, whatever the switch says`**
  (`chapter02-paint.feature`) *was* present in `Chapter02Tests.java` as
  `"Paint: the arithmetic is on light"`, but the test never actually set
  `Mixer.linearBlending = false`, so it silently tested nothing about the
  switch — it happened to pass because the switch's default is already
  linear. §2.5 states the identical rule for `paint_through`: "in between
  it's `mix(pixel, color, coverage)` with the switch forced to the light's
  way: `mix(pixel, color, coverage, true)`." Checking `Painter.paintThrough`
  found the same bug as `Lines.plot`: it called the unforced 3-arg `mix`.
  **Real bug, fixed**, and the test now actually toggles the switch off
  before calling `paintThrough`, so it can fail on the mistake it exists for.
- Four scenarios were missing outright from `Chapter04Tests.java` though
  present in the chapter 4 feature files: `Tuples: magnitude and dot look at
  x and y only`, `Matrices: Invertibility is an exact test against zero`,
  `Shapes: a union of nothing is inside nowhere`, `Plate 4: side_by_side puts
  the first canvas on the left`. None of these exposed a bug — the existing
  code already handled all four correctly (`Tuple.magnitude`/`dot` already
  ignore `w`; `Union` over an empty list already returns false via a loop
  that never iterates; `Matrix.inverse`/`isInvertible` are already an exact
  `!= 0` test; `Figures.sideBySide` was already correct). Added all four;
  all pass on the first try.
- Chapters 1 and 2 were otherwise fully translated already — no further gaps.

`./reference/impl/run_features.py` doesn't apply here (that's the Python
reference's runner); the equivalent check for this reader is "does every
feature scenario have a same-named Java scenario", which I did by hand with a
small script diffing scenario titles.

Both fixes are the same underlying mistake (a paint-primitive reading the
global blending switch instead of forcing it to linear), caught only because
the switch-off scenario actually toggles the switch. This is worth noting for
the book: a translated scenario that doesn't perform the `Given` step it's
named after (here, `Given linear blending is off`) is worse than no test,
because it reads as coverage that isn't there.

Chapters 1-6 all pass after these fixes (66+35+38+76+32+34 = 281 scenarios).

---

## Chapter 5 — Paths and Insideness

### Result

32/32 scenarios pass (`chapter05-paths.feature` 10, `chapter05-winding.feature`
9, `chapter05-rules.feature` 9, `chapter05-plate.feature` 4).

Renders, `max_channel_difference` against `reference/chapter-05/`:

| file | max_channel_difference |
|---|---|
| `star-centers.ppm` | 0 |
| `star-coverage.ppm` | 0 |
| `plate-05.ppm` | 0 |

Every byte matches the reference exactly, not just within the ±1 budget the
scenarios allow.

### Ambiguities

- The chapter's pseudo-code and scenarios pass the fill rule as a bare string,
  `"nonzero"` / `"evenodd"`. I mirrored that literally (`String rule` in
  `Paths.filled`, `FilledPath`, `Spans.spansFromCrossings`, etc.) rather than
  introducing a Java enum, so the tests stay a literal translation of the
  Gherkin. A real Java renderer would probably want an enum; I didn't add one
  because nothing in the scenarios asks for it and it isn't the reader's job
  to gold-plate the API.
- `circle_path`'s "first point at angle 0, ... going clockwise on the screen"
  doesn't by itself say whether the parameter angle should *increase* or
  *decrease* per step — both read as "clockwise" in different conventions
  depending on which way you already think of angle increasing. I used plain
  increasing angle with `cos`/`sin` (`a = 360*k/n` degrees) and checked the
  pinned second point, `point(13.5355, 13.5355)`, against it before writing
  anything else; it matched immediately, so there wasn't much genuine
  guessing left once I ran the numbers, but the prose alone doesn't pin the
  sign — only the scenario does.
- Otherwise this chapter was unusually thorough about edge cases (the pen
  state after `close()`, subpaths of zero and one edge, closing nothing) —
  every corner case I'd have had to guess was already narrated in prose *and*
  pinned by a scenario, exactly as the book's own rule demands.

### Hard to translate

Nothing significant. Java records (`Bounds`, `Edge`) map the Gherkin
structural comparisons (`bounds(p) = (1, 1, 9, 8)`) cleanly, except that a
record's generated `equals()` is exact, not tolerant — I wrote a small
`assertBoundsEq` helper using `Numbers.approxEqual` component-wise rather than
rely on `Bounds.equals`. Everything else (subpaths as a mutable `List<Tuple>`
plus a `closed` flag, `Paths.filled` returning a `Shape` that reuses chapter
2's `Rasterizer` verbatim) fell out directly from the existing chapter 1-4
code shape.

### Failures

None — 32/32 pass, including both plate renders and the pentagram scenario's
five pinned vertices.

### Prose problems

None found. One thing worth calling out as a *good* sign rather than a
problem: §5.1's claim that "a subpath of two points contributes two [edges],
there and back, and encloses nothing, which the winding number in the next
section will confirm without any special case" is literally true of the
implementation — `winding_at` needs no special-casing for a 2-point subpath,
which is a nice piece of evidence the two features were designed together
correctly.

### Concrete changes

None. This was the cleanest chapter of the six to translate cold.

---

## Chapter 6 — Filling a Polygon

### Result

34/34 scenarios pass (`chapter06-edges.feature` 6, `chapter06-spans.feature`
12, `chapter06-sweep.feature` 13, `chapter06-plate.feature` 3).

Renders, `max_channel_difference` against `reference/chapter-06/`:

| file | max_channel_difference |
|---|---|
| `spiral.ppm` | 0 |
| `plate-06.ppm` | 0 |

### Catch-up

None needed beyond chapter 5's — chapters 1-5 stayed green throughout chapter
6's implementation (re-ran the full suite after every source change).

### Ambiguities

- "Ties beyond [`y_top`, then `x_top`] are allowed to fall in any order" — I
  used a plain `List.sort` with a two-key `Comparator` and didn't add a third
  tie-break. Java's sort is stable, so ties keep `edges()`'s own iteration
  order; the one scenario that has four tied entries
  (`chapter06-edges.feature`, "the table is sorted by top, then by x at the
  top") only pins the `(y_top, x_top)` *pairs* in table order, not which
  physical edge occupies which slot, so this never mattered in practice —
  worth flagging for a reader in a language with an unstable sort, since the
  scenario would still pass with a different (still-valid) internal ordering.
- §6.3 explicitly says re-sorting the active list with insertion sort instead
  of a fresh sort each row is optional and "nothing in the scenarios can
  tell" — true, confirmed; I used the "honest simple version" (fresh sort
  every row) since the chapter says that's fine and it's simpler to get
  right.
- `transform_path` is introduced in §6.4 but is really a path operation with
  no dependency on the sweep; I put it in `Paths.java` next to chapter 5's
  path helpers rather than a chapter-6-specific file. Purely an organizational
  choice, not a behavior question.

### Hard to translate

One purely mechanical friction, not a translation problem with the book:
Java's `java.nio.file.Path` collides by name with the book's own `path()`
concept once you name the class `Path`, as chapter 5 does. I kept the book's
naming (`Path`, `Paths`, matching `path()`/free functions) and fully
qualified `java.nio.file.Path.of(...)` in the two test-runner files instead
of importing it, rather than renaming the book's own class to dodge the
collision. Worth a one-line note for Java readers in the book's Java-specific
notes, if it has any; not a chapter bug.

Otherwise the pseudo-code for `fill_path_aliased` and `spans_from_crossings`
translated close to line-for-line, since the `TableEdge`/`Crossing`/`Span`
types chapter 5 and chapter 6 both lean on already existed in the right
shape from chapter 2's `CoverageBuffer`.

### Failures

None — 34/34 pass, including the pixel-for-pixel match against chapter 5's
`rasterize_centers(filled(p, rule), w, h)` for a rectangle, a triangle drawn
both ways, a polygon circle at an awkward offset, and the star under both
rules (`max_coverage_difference` is exactly `0` in every one of those
scenarios, not just within tolerance).

### Prose problems

None found — and one claim I went out of my way to verify empirically rather
than take on faith, because it's exactly the kind of thing this book insists
on pinning: §6.1's trap says the star's edge table has **five** entries
rather than the four you'd expect on paper, because two of its vertices that
should share a height differ in their last bit (`58.86881039375369` vs
`58.86881039375366`), giving a fifth edge "with a slope of about
-4.7 × 10¹⁵ and a height of 3 × 10⁻¹⁴". I instrumented `EdgeTable.edgeTable(Figures.star())`
directly and got:

```
edge_table(star()).size() = 5
  ... height=2.842170943040401E-14 slope=-4.68472568855718E15
```

Height `2.84e-14` and slope `-4.68e15` — matches the book's own quoted figures
to the precision it gives them. The book is right that no scenario should
pin the table's length for the star, and none does.

### Concrete changes

None needed for this chapter either.

---

## Mutation results

Tried five plausible reader mistakes across both chapters, each undone
immediately after checking which scenario(s) caught it. All five were caught
— none slipped through the suite.

1. **`crossings`'s half-open rule replaced with closed-closed**
   (`(ay <= y && y <= by) || (by <= y && y <= ay)` instead of `<`) — the
   chapter's own named trap ("If you wrote ≤ at both ends you'll get 2 and
   4"). Caught by 2 scenarios: `Winding: a ray through a vertex counts it
   once` (expected 1, got 2) and `Winding: a diamond wound twice has winding
   number 2` (expected 2, got 4).
2. **`winding_at`'s down-heading branch changed from `b.y > y` to `b.y >= y`**
   (closed at the bottom instead of half-open) — caught by 4 chapter-5
   scenarios (vertex, boundary, diamond, polygon-circle) and 1 chapter-6
   scenario (the sample-height sweep/rasterize-centers agreement test),
   5 total.
3. **`Spans.fillSpan`'s right end changed from half-open to closed**
   (dropped the `- 1` from `last`) — the chapter's own named risk ("a ≤
   where a < belongs"). Caught by 11 of chapter 6's 34 scenarios: both direct
   `fill_span` unit scenarios, the off-buffer scenario, 5 of the `Sweep`
   scenarios, and both plate render diffs.
4. **Horizontal edges no longer dropped from the edge table** (the chapter's
   headline trap for §6.1 — "a hair sticking out of a corner") — caught by 6
   scenarios, all in `chapter06-edges.feature` and one in
   `chapter06-spans.feature` (`length(t)`/`length(edge_table(p))` mismatches,
   plus an `x_at` call landing on `-Infinity` from the division by zero the
   chapter warns about).
5. **`crossingsOnRow` no longer sorts its result by `x`**, relying on the
   table's own `(y_top, x_top)` order instead — caught by 3 scenarios, but
   notably *not* by the simplest one (`Spans: crossings on a row, sorted by
   x`, which uses an axis-aligned rectangle whose two edges happen to already
   come out in x-order from table order at that row). It took the star's
   asymmetric five-edge table (`Spans: the star's crossings through its
   middle` and `Spans: the star's spans through its middle`) to expose it.
   This is the one mutation where a *simpler* pinned example wouldn't have
   caught the bug — worth a mention in the book's own "probe a clamp
   somewhere the placement matters" spirit: the basic rectangle scenario for
   `crossings_on_row` doesn't actually exercise the sort, only the star's
   does.

No wrong implementation was found that passed every scenario in either
chapter.

## Timing

All timings are the harness's own `System.nanoTime()` totals for the whole
chapter run (register scenarios, run them, write renders), on this machine,
compiled (not interpreted):

| chapter | scenarios | time |
|---|---|---|
| 1 | 66 | 273 ms |
| 2 | 35 | 113 ms |
| 3 | 38 | 139 ms |
| 4 | 76 | 696 ms |
| 5 | 32 | 1170 ms |
| 6 | 34 | 217 ms |

Chapter 5 is the slowest of the six by a wide margin, as the chapter predicts:
its plate does two full 160×160 rasterizations at 64 samples/pixel (the
"reference renderer" method, `rasterize`/`rasterize_within`), each sample a
winding number over the star's five edges, for both the centers and coverage
panels under both rules. Chapter 6's `fillPathAliased` sweep, doing the exact
same pixel-for-pixel work through the active-edge-list algorithm instead, is
about 5-6x faster in wall time despite chapter 6 registering more scenarios,
which lines up with the book's own claim that the sweep only gets faster
relative to the naive method as the canvas and edge count grow (this is
Java, already compiled, so the ~70x Python figure the book quotes isn't the
right comparison — the *shape* of the win is the same).
