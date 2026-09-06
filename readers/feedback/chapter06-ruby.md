# Reader feedback: Chapters 5 and 6 (Ruby, cold implementation)

Implemented chapters 5 and 6 on top of the existing Ruby (2.6, minitest) code for
chapters 1-4, translating every scenario in `features/chapter05-*.feature` and
`features/chapter06-*.feature`, from the chapter prose and scenarios alone.

## Catch-up (chapters 1-4)

Compared scenario counts in every `features/chapter0[1-4]-*.feature` file against
existing `def test_` methods, then checked names by hand.

- Chapters 1, 2, 3: every scenario (including every `Scenario Outline` example)
  already had a matching test. No gaps.
- Chapter 4: 76 scenario instances in the feature files, only 74 `def test_`
  methods. Two scenarios were never translated:
  - "A union of nothing is inside nowhere" (`chapter04-drawing.feature`)
  - "side_by_side puts the first canvas on the left" (`chapter04-plate.feature`)

  Both scenarios pass immediately against the existing `renderer.rb` (no code
  changes needed) - `union([])` already returns a shape whose `inside?` is
  false via `Array#any?` on an empty array, and `side_by_side` was already
  correctly implemented. So these were pure test-suite gaps, not code bugs,
  but they're exactly the kind of gap that would let a broken `union([])` or
  `side_by_side` slip through a "green" reader submission. Added both tests to
  `test_chapter04.rb`; chapter 4 now runs 76/76.

## Chapter 5: Paths and Insideness

### Result
- `chapter05-paths.feature`: 10 scenarios, all pass
- `chapter05-winding.feature`: 9 scenarios, all pass
- `chapter05-rules.feature`: 9 scenarios, all pass
- `chapter05-plate.feature`: 4 scenarios, all pass
- Total: 32/32, 253 assertions
- Renders vs reference: `star-centers.ppm` diff 0, `star-coverage.ppm` diff 0,
  `plate-05.ppm` diff 0 (exact byte match on all three)

### Ambiguities
- None that caused a wrong first guess. The winding_at pseudocode in §5.2 is
  given explicitly enough (with the half-open rule spelled out in both the
  prose and the code block) that there was no guessing involved - a rare
  chapter where the "trap" callout and the pseudocode actually agree on every
  boundary.
- `bounds(p)` isn't given a named return type in prose (just "(min x, min y,
  max x, max y)"). I represented it as a 4-element array, which the
  `rasterize_within(shape, box, w, h)` signature then destructures. This
  worked cleanly but a reader in a typed language will want to know whether
  `box` is meant to be the same type `bounds()` returns or a separate tuple
  type - worth a sentence.

### Hard to translate
- Nothing chapter-specific was hard in minitest. `subpaths(p)[i].points[j]`
  chains translate directly to Ruby array/attr access.

### Failures
- None once implemented per the prose formulas.

### Prose problems
- None found. This was the cleanest chapter so far to translate: the
  pseudocode for `winding_at` matches the reference exactly (verified every
  scenario, including the pentagram and the vertex-ray cases, on the first
  implementation attempt with zero iteration).

## Chapter 6: Filling a Polygon

### Result
- `chapter06-edges.feature`: 6 scenarios, all pass
- `chapter06-spans.feature`: 15 scenario instances (12 scenarios + 3 extra
  `Scenario Outline` examples), all pass
- `chapter06-sweep.feature`: 12 scenarios, all pass
- `chapter06-plate.feature`: 2 scenarios, all pass
- Total: 37/37 (counted as 35 distinct scenarios by feature-file count, but
  minitest gives each outline example its own `def test_`, hence 37 runs),
  232 assertions
- Renders vs reference: `spiral.ppm` diff 0, `plate-06.ppm` diff 0 (exact
  byte match)
- Speed claim verified directly: chapter 5's `star_coverage()` (8x8
  supersampling within bounds) took 8.56s in this Ruby implementation;
  chapter 6's `spiral()` (24 stars, scanline sweep) took 0.53s for a canvas
  of the same order of magnitude. The chapter's claim that the sweep is
  dramatically faster holds up in this language too, even though Ruby's
  interpreter overhead dwarfs Python's for both.

### Ambiguities
- None on the algorithm itself - `edge_table`, `crossings_on_row`,
  `spans_from_crossings`, `fill_span`, and `fill_path_aliased` are all given
  as literal pseudocode with every boundary condition named (half-open at
  y_top/y_bottom, half-open at the span's right end). I translated the
  pseudocode close to verbatim and every scenario passed on the first
  attempt with the algorithm as literally written - except one bug described
  under Failures below, which was a translation bug, not a prose bug.

### Hard to translate
- Nothing structural. `Edge` became a small Ruby class with five
  `attr_accessor`s, matching the style of `Subpath`/`Path` from chapter 5.

### Failures (found and fixed during translation, not left in the suite)
- **Integer division in `edge_table`'s slope formula.** The pseudocode is
  `slope ← (b.x - a.x) / (b.y - a.y)`. Several scenarios build polygons from
  integer-literal points, e.g.
  `polygon(point(0, 0), point(10, 0), point(5, 10))`. In this codebase,
  `point(x, y)` stores whatever numeric type it's given, so `point(0, 0)` and
  `point(5, 10)` hold Ruby Integers, not Floats. `Integer#/` in Ruby is floor
  division: `(5 - 10) / (10 - 0)` evaluates to `-1`, not `-0.5`. My first
  implementation used the formula as written and got `t[0].slope = 0` where
  the scenario expected `0.5` (`(5-0)/(10-0)` floors from 0.5 to 0), caught
  immediately by
  `TestEdgeTable#test_a_triangles_edges_carry_their_slopes`,
  `test_an_edge_knows_where_it_crosses_a_height`,
  `TestSpans#test_a_triangles_spans_narrow_by_one_per_row_*`, and
  `TestSweep#test_a_triangle` (7 failures across both files, all from this
  one bug). Fixed with `.to_f` on the divisor in both branches of
  `edge_table`. This is a real trap for a reader in any language without
  automatic int-to-float promotion on division (Ruby, Python 2, C, Java,
  Kotlin without explicit casts...) and the chapter doesn't mention it -
  worth a callout, since chapter 5's `star()` (used pervasively as a test
  fixture from here on) is built from `Math.cos`/`Math.sin` and so is always
  float, which is probably why this trap wasn't caught by the reference
  implementation's own test suite (if it's in Python 3, `/` is always true
  division and this bug can't exist there at all).
- No other failures. Everything else matched on the first attempt because
  every formula in §6.1-6.3 is given as complete, unambiguous pseudocode.

### Prose problems
- §6.1's trap about the star's near-horizontal edge (the two vertices at
  `58.86881039375369` and `58.86881039375366`) is accurate and I could
  reproduce it: `edge_table(star())` really does return 5 entries, not 4,
  and the fifth edge really is harmless (see Mutation results below). No
  correction needed, just confirming the claim is correct in Ruby's
  `Math.cos`/`Math.sin` too.
- Nothing else. This was a tight, well-specified chapter.

## Mutation results

Tried five plausible reader mistakes against the finished chapter 5 and 6
suites, each applied to `renderer.rb`, tested, then reverted (confirmed via
diff against a pre-mutation backup and a full six-chapter re-run afterward,
285 runs / 1937 assertions / 0 failures).

1. **Chapter 5, `crossings`: `xi > x` weakened to `xi >= x`.** This is the
   boundary comparison for "the ray will pass through this crossing point."
   **Passed every scenario in `chapter05-*.feature` undetected.** No
   scenario queries a point whose x-coordinate exactly equals an edge's
   crossing x at the query height, so the `>` vs `>=` distinction is never
   exercised. This is the most valuable finding: it's the same class of bug
   the chapter's own trap warns about for `winding_at`'s vertex handling
   (§5.2), but `crossings()` itself has no equivalent scenario. Worth a
   scenario like "a ray whose start point sits exactly on a crossing" to pin
   which side the boundary falls on (though note `winding_at`, the function
   actually used for `inside_nonzero`/`inside_evenodd`/`filled`, does NOT
   have this weakness - it uses the cross-product sign test, not an x-value
   comparison, so this gap is contained to the diagnostic `crossings()`
   function and doesn't affect any rendered output).
2. **Chapter 5, `winding_at`: `a.y <= y` weakened to `a.y < y`.** This breaks
   the half-open rule at the edge's top endpoint. Caught immediately - 7 of
   32 scenarios failed, including the vertex-ray scenario, the boundary
   scenario, and both plate renders (`max_channel_difference` of 204). The
   suite is very solid on this particular boundary.
3. **Chapter 6, `edge_table`: exact equality (`a.y == b.y`) for the
   horizontal-edge check weakened to a tolerance (`(a.y - b.y).abs <
   0.0001`).** **Passed every scenario in `chapter06-*.feature` undetected**,
   but this is consistent with the chapter's own explanation, not a gap in
   it: the star's near-horizontal edge is called out in the trap as
   "harmless: no sample height will ever fall inside a span that thin, so it
   crosses nothing," and the chapter deliberately doesn't pin the star's
   edge-table length for exactly this reason. A tolerance-based drop and an
   exact-equality keep produce the same rendered output for every scenario
   in this book, so this "mutation" isn't actually a behavioral bug given
   the scenarios as specified - it would only matter for a hypothetical
   future scenario that pins an edge count, which the author has explicitly
   and correctly chosen not to write. Reporting this as confirmation of the
   prose's own claim, not as a chapter bug.
4. **Chapter 6, `fill_span`: dropped the `- 0.5` pixel-center offset**
   (`first = x0.ceil`, `last = x1.ceil - 1`, instead of
   `(x0 - 0.5).ceil`/`(x1 - 0.5).ceil - 1`). Caught immediately and hard -
   10 of 37 scenarios failed, across `TestSpans`, `TestSweep`, and both
   plate renders (`max_channel_difference` of 204). This is the single most
   heavily-guarded boundary in the chapter.
5. **Chapter 6, `fill_path_aliased`: active-edge exclusion `e.y_bottom > y`
   weakened to `e.y_bottom >= y`.** Caught by exactly one scenario -
   `"An edge that starts on a sample height is active there, and one that
   ends there is not"` - and no others. This is precisely the scenario the
   chapter says it wrote for this purpose (§6.3: "the scenario for it fills
   rows 2, 3 and 4 and not row 5; get either comparison wrong and it fills
   four rows or two"), and it does its job with no redundancy and no gaps
   that this mutation could find.

Net: 3 of 5 mutations caught (two hard, one by exactly the intended
scenario), one confirmed-harmless-by-design, and one real gap in
`crossings()`'s boundary handling that a future scenario could close.

## Concrete changes I'd make

1. Add a scenario to `chapter05-winding.feature` that puts a query point's x
   exactly on a crossing's x at the query height, to pin `crossings()`'s
   `>` vs `>=` choice (see Mutation #1). `winding_at` doesn't need this
   (it's cross-product based) but `crossings()` currently has no scenario
   that could fail on it.
2. A one-line note in §6.1 (or wherever `edge_table`'s slope formula first
   appears) that the division must be a real-number division, for readers
   in languages where `int / int` isn't automatically promoted to a float
   (Ruby, C, Java, Kotlin, Python 2). This is exactly the kind of "nothing
   left implicit" trap the book's own writing rules call for elsewhere
   (e.g. the P6 clamp order, the rounding mode) and it bit me on the very
   first run of chapter 6.
3. Consider naming the return shape of `bounds(p)` explicitly in prose (a
   tuple/array of 4 numbers in a fixed order) since it's later passed
   directly as the `box` argument to `rasterize_within` - implicit but
   consistent, worth stating once.

## Timing

- Chapter 5 renders: `star_centers()` 0.23s, `star_coverage()` 8.56s,
  `plate_05()` 10.58s (includes both panels plus the 320x320 composite plus
  2x magnify)
- Chapter 6 renders: `spiral()` 0.53s, `plate_06()` 0.69s (includes the
  spiral plus 2x magnify)
- Test suite wall-clock (this machine, Ruby 2.6.10, minitest, six chapters
  run sequentially): chapter 1 ~0.9s, chapter 2 ~9-12s, chapter 3 ~42-46s,
  chapter 4 ~72-77s, chapter 5 ~80-84s, chapter 6 ~41-46s. Chapters 4 and 5
  are the slowest because their test suites call full-canvas renders
  (`fan_both_orders`, `f_both_orders`, `star_centers`, `star_coverage`,
  `plate_05`) inside ordinary scenario tests, not just the dedicated
  render/diff scripts - chapter 6's sweep-based renders bring the
  corresponding chapter's suite time back down substantially despite having
  more scenarios (37 vs 32).
