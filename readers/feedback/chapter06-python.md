# Reader feedback: Python, chapters 5-6

Cold read of chapters 5 and 6 against the existing Python implementation of chapters 1-4.
Final state: 280/280 scenarios pass (211 from chapters 1-4, 32 from chapter 5, 37 from
chapter 6). All five renders (`star-centers.ppm`, `star-coverage.ppm`, `plate-05.ppm`,
`spiral.ppm`, `plate-06.ppm`) diff at `max_channel_difference = 0` against `reference/`.

---

## Catch-up (chapters 1-4)

Ran the existing 211 scenarios from chapters 1-4 before touching anything. All 211 passed
unmodified — nothing new has been added to those feature files since this code last ran, and
no fixes were needed. (The one change I made to shared infrastructure, the `compare_values`
fix described under chapter 6 below, doesn't change chapter 1-4 behavior; all 211 still pass
after it.)

---

## Chapter 5: Paths and Insideness

### Result

32/32 scenarios pass (`chapter05-paths.feature`: 10, `chapter05-rules.feature`: 9,
`chapter05-winding.feature`: 9, `chapter05-plate.feature`: 4).

Renders: `star-centers.ppm` diff 0, `star-coverage.ppm` diff 0, `plate-05.ppm` diff 0.
Timing: `star_centers()` 0.24s, `star_coverage()` 7.7s, `plate_05()` 8.5s (dominated by
`star_coverage`, since it rasterizes two 160x160 canvases at 64 samples/pixel over the
star's bounding box, twice for the two rules).

### Ambiguities

- **What does `line_to` do when the current subpath is open but has only the one point
  `move_to` left it with?** Section 5.1 only spells out the closed-then-`line_to` case
  ("starts a new subpath where the closed one began"). I inferred from "line_to(p, point)
  extends the current subpath" that an open subpath, regardless of point count, just gets
  the point appended — no scenario distinguishes a 1-point open subpath from a longer one,
  but the behavior falls out naturally from "append to the last subpath unless it's closed."
- **Does `close()` require the subpath to have at least 2 points?** Not stated. I let it
  close a 1-point subpath harmlessly (sets the flag, `edges()` still returns nothing for it
  since it has fewer than 2 points). The "closing nothing does nothing" scenario tests
  `close()` with *no* subpaths, not a 1-point one, so this corner is my guess, untested.
- **`inside_evenodd` and negative winding numbers.** The prose says "inside when it's odd,"
  and Python's `%` gives a non-negative remainder for a positive divisor even when the
  dividend is negative (`-1 % 2 == 1`), so `w % 2 != 0` is correct for negative `w` without
  extra care. Worth a scenario with a negative-winding path under even-odd, since a reader in
  a language where `%` can return a negative remainder (C, C++, or a naive Python `abs(w) %
  2` habit carried over from another language) could get this wrong silently. None of the
  even-odd scenarios use a clockwise-then-reversed pair that lands on a negative winding
  number at the probed point.

### Hard to translate

Nothing chapter-5-specific was hard to express in Python. The one general friction, shared
with chapter 6, is described below.

### Failures

None once the harness fix (below) was in.

### Prose problems

- Section 5.1: no issues found, the edge-case list (open triangle, line_to after close,
  degenerate subpaths) is thorough and each case has a scenario.
- Section 5.4, `star()` pseudocode: matches the pinned vertex coordinates in
  `chapter05-plate.feature` to 4 decimal places once run through `math.radians`/`math.cos`/
  `math.sin` — no discrepancy.

---

## Chapter 6: Filling a Polygon

### Result

37/37 scenarios pass (`chapter06-edges.feature`: 6, `chapter06-spans.feature`: 16,
`chapter06-sweep.feature`: 12, `chapter06-plate.feature`: 3).

Renders: `spiral.ppm` diff 0, `plate-06.ppm` diff 0. Timing: `spiral()` 0.49s, `plate_06()`
0.89s. The chapter's own claim ("about a millisecond" for the star's sweep vs "about
seventy" for the center test) is directionally right in this implementation too:
`fill_path_aliased` on the 160x160 star is fast enough that `spiral()` (24 stars, sweep-filled
into a 320x320 canvas) finishes in under half a second, while a single `star_coverage()`
render (which does 64-sample-per-pixel center/coverage sampling, not the sweep) takes ~8s.

### Ambiguities

- **Comparing whole lists of floats.** `chapter06-spans.feature`'s "The star's spans through
  its middle" scenario writes `spans(p, "nonzero", 80) = [(43.6988, 117.3012)]` — a *list*
  equality, not indexed element access like the sibling "star's crossings" scenario does
  (`xs[0] = (43.6988, -1)`). The book's own convention (`←` assigns; floats compare with
  0.0001 tolerance by default) doesn't say whether that convention reaches inside a list
  literal being compared as a whole. I read it as: yes, it should, since nothing in the
  prose suggests list-of-floats needs exact equality while every other float comparison in
  the book gets the default tolerance. See "Hard to translate" below — my test harness
  needed a fix to actually implement that reading.

### Hard to translate / harness fix (affects both chapters)

The existing `test_runner.py` (written for chapters 1-4) had a `compare_values` function
that special-cased `Color`, `Tuple`, `Matrix3`, plain numbers, and a *flat* tuple of numbers
(for pixel triples), each with the book's 0.0001 tolerance — but a `list` of tuples (or a
tuple of tuples) fell through to Python's exact `==`. That's invisible in chapters 1-4
because nothing there compares a whole list of floats at once. Chapter 6 does:
`spans(...)  = [(43.6988, 117.3012)]` and `spans(..., "evenodd", ...) = [(43.6988, 57.7556),
(103.2444, 117.3012)]` compare a computed list of float pairs against a 4-decimal literal.
The computed values (`43.698822151660636`, etc.) are correct to well within 0.0001 of the
literal, but exact list `==` failed.

Fixed by making the tuple-comparison branch handle `list` as well as `tuple`, and recurse
element-wise (so a list of tuples of floats gets tolerance at every level, not just one):

```python
elif isinstance(left_val, (tuple, list)) and isinstance(right_val, (tuple, list)):
    if len(left_val) != len(right_val):
        return False
    return all(compare_values(a, b, '=', tolerance) for a, b in zip(left_val, right_val))
```

This is a fix to the reader's own harness, not to the book or the reference, and it's a
change future chapters will likely need again (any scenario that compares a whole computed
list against a literal with non-trivial floats). Worth the book's author knowing that a
harness built straightforwardly from chapters 1-4's patterns alone won't handle this without
the fix — a hint in the book's own testing conventions section ("comparisons apply
recursively inside lists and tuples") would have saved the round-trip.

### Failures

None, after the harness fix above. Before the fix: 1 failure, "The star's spans through its
middle," actual `[(43.698822151660636, 117.30117784833935)]` vs expected
`[(43.6988, 117.3012)]`, which is not a bug in the chapter or the reference — it's the
harness's fault, as described above.

### Prose problems

- Section 6.1's trap (float-imprecision near-duplicate `y` values in the star, e.g.
  `58.86881039375369` vs `58.86881039375366`) reproduced exactly as described, confirming
  the reference and this Python implementation hit the same floating-point path (same libm
  behavior on this machine, or at least close enough that the same two points differ in the
  same low bit). Nothing to report there — it's exactly as advertised, and see Mutation
  results below for why this trap deserves a scenario it doesn't have.
- No other prose problems found in chapter 6. The pseudocode for `edge_table`,
  `crossings_on_row`, `spans_from_crossings`, `fill_span`, and `fill_path_aliased` translated
  line-for-line into Python with no adjustment needed, and every inequality (`<` vs `<=`)
  in the prose matched what the scenarios actually pin (confirmed via the mutation testing
  below).

---

## Mutation results

Four plausible reader mistakes, each applied to `renderer.py`, tested against the full
280-scenario suite, then reverted:

1. **Horizontal-edge check with a tolerance instead of exact equality**
   (`edge_table`: `if abs(a.y - b.y) < 0.0001: continue` instead of `if a.y == b.y: continue`).
   **Passed all 280 scenarios.** This is the most valuable finding: section 6.1's trap
   explicitly warns "The rule is `a.y = b.y`, exactly," and explains that the star has a
   near-duplicate pair (`58.86881039375369` vs `58.86881039375366`, differing by about
   3e-14) whose spurious edge is "harmless: no sample height will ever fall inside a span
   that thin." That's exactly why a *tolerant* horizontal check also passes every scenario:
   it drops that spurious edge too, and since it was harmless anyway, dropping it doesn't
   change any pinned output. No scenario exists that would fail if a reader used
   `abs(a.y - b.y) < epsilon` for *some* epsilon instead of exact equality — which is a
   completely reasonable thing for a reader coming from a language/background where "always
   use an epsilon for float comparison" is a reflex. The chapter's own prose argues this is
   wrong in principle (a horizontal edge with a real, larger difference should never be
   dropped, and an epsilon threshold is an arbitrary choice that could accidentally swallow
   a real, nearly-horizontal edge in some other polygon), but nothing in the *scenarios*
   forces that. A scenario with two edges whose `y` values differ by something between
   "clearly the same" and "clearly different" — say 0.01, enough to matter for a real edge
   but small enough to tempt a sloppy epsilon — would catch a reader who reaches for
   tolerance out of habit.
2. **Crossings using a closed interval on both ends** (`crossings`: `(a.y <= y <= b.y) or
   (b.y <= y <= a.y)` instead of the half-open rule). **Caught**: "A ray through a vertex
   counts it once" and "A diamond wound twice has winding number 2" both failed (vertices
   counted twice).
3. **`fill_span` inclusive at the right end** (dropping the `- 1` from `last`). **Caught
   broadly**: 11 scenarios failed, including the whole-picture ones (`spiral.ppm`,
   `plate-06.ppm`) and the dedicated "half-open at its right end" scenario. This one's very
   well covered.
4. **Non-strict cross-product comparison in `winding_at`** (`>= 0` / `<= 0` instead of `> 0`
   / `< 0`). **Caught**: "The boundary belongs to the top and the left," "The polygon
   circle," and "An edge that starts on a sample height is active there, and one that ends
   there is not" all failed (vertices/edges on the ray double-counted or dropped).

All mutations were reverted; the suite is back to 280/280 clean.

---

## Concrete changes I'd make

1. Add a scenario to `chapter06-edges.feature` with two edges whose `y` values differ by a
   small-but-real amount (not the star's ~3e-14 accident) to catch a tolerance-based
   horizontal check — see Mutation 1 above.
2. Add a sentence to the book's testing conventions (`plan.html` → Testing, or the
   per-chapter note) saying explicitly that float tolerance applies recursively inside lists
   and tuples being compared as a whole, not just to bare scalars and flat pixel triples.
   Chapters 1-4 never exercise this, so a harness built strictly to their scenarios doesn't
   handle it, and chapter 6 is the first to need it.
3. (Very minor, not a bug) `inside_evenodd`'s correctness for negative winding numbers relies
   on Python's `%` always returning a non-negative result for a positive divisor. A reader in
   a language where `%` can return a negative remainder (C, C++, Rust with rem vs
   rem_euclid) needs to know to normalize before checking oddness. A scenario with a
   clockwise-then-reversed pair landing on a negative winding number at the probed point
   would pin this explicitly instead of leaving it to be discovered.

## Timing

- `star_centers()`: 0.24s
- `star_coverage()`: 7.7s (two 160x160 canvases, 64-sample coverage, bounded to the star's bbox)
- `plate_05()`: 8.5s (both of the above, composited)
- `spiral()`: 0.49s (24 stars, sweep-filled via `fill_path_aliased` into 320x320)
- `plate_06()`: 0.89s (`spiral()` + 2x magnify)
- Full 280-scenario suite: a few seconds total, dominated by the chapter 5 coverage renders
  inside the plate/coverage scenarios (which call `star_coverage`/`star_panel` directly).
