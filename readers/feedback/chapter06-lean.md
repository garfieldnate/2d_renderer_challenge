# Reader feedback — Lean 4, chapters 4-6

Candid notes from implementing chapters 4, 5 and 6 cold, from the chapter text
and `features/*.feature` alone, on top of the existing chapter 1-3 Lean code.
Overall: the chapters are tight. Every scenario in all three chapters passed
on the first implementation attempt except where noted below, both renders
per chapter came out byte-identical (`max_channel_difference` = 0, not just
≤ 1) to the reference PPMs, and the mutation round below caught six of seven
deliberate bugs — the seventh is the book's own named trap, working exactly
as advertised.

## Chapter 4 — Points, Vectors, Transforms

### Result

76 scenarios (chapter04-tuples 12, chapter04-matrices 18, chapter04-transforms
16, chapter04-scale 6, chapter04-drawing 14, chapter04-plate 10), all
passing. Both renders exact:

| render | max_channel_difference |
| --- | --- |
| `fan-both-orders.ppm` | 0 |
| `plate-04.ppm` | 0 |

### Catch-up

Before touching chapter 4, brought the existing chapter 1-3 code up to date
with the current `features/`. Ran `lake exe tests` cold first: 134/134
passed, matching the committed `README.md`'s counts, so at first glance
nothing looked new. Diffing every `Scenario:`/`Scenario Outline:` name in
`features/chapter0{1,2,3}-*.feature` against every `r.run "..."` string in
`Suite/Chapter0{1,2,3}.lean` (accounting for `s!"..."` interpolated names)
turned up exactly one scenario present in the feature file but absent from
the test code: **"The weights are applied in light, whatever the switch
says"** in `chapter03-wu.feature`. It sets linear blending off and checks
that `line_wu` still paints in light. Added the check — and it failed:
`plot` was calling `mix pixel col weight` with no `linear` argument, so it
deferred to the global switch instead of forcing linear the way
`paint_through` does. Fixed `plot` to pass `(some true)`, same as
`paintThrough`. Chapter 3 went from 37 to 38 scenarios, 134 → 135 total, all
green. (This matches the git history of the book's own repo — commit
`fd8c5a6` mentions exactly this fix "with a scenario", so this Lean
codebase's chapter 3 run had simply gone stale relative to a scenario the
author added after collecting a prior round of Lean feedback. Nothing in
chapter 4 depended on this fix directly, but `thickLine`'s refactor over
`segment` in this chapter touches the same rasterizer path, so it seemed
worth catching before building on top of it.)

### Ambiguities

- **`identity()`** is written as a nullary call in the book's Gherkin
  (`A * identity() = A`). Lean has no zero-argument function distinct from a
  value, so `identity` is a plain `Matrix3` constant, called without
  parentheses. Not really a guess — there's only one sane translation — but
  worth flagging since it's the one place the book's syntax doesn't map
  onto Lean syntax token-for-token.
- Nothing else needed guessing. The pseudo-code for `minor`/`cofactor`/
  `determinant`/`inverse` is precise enough to transliterate directly,
  including the transpose-by-writing-into-`[c, r]` trick.

### Hard to translate

- **`Matrix3.at` collides with Lean 4's tactic-mode keyword `at`** (as in
  `simp at h`). `at` cannot be a plain identifier — not even a namespaced
  field-projection name like `Matrix3.at` — so `M[r, c]` became `m.get r c`
  instead. First build attempt failed with `unexpected token 'at'`; renamed
  and moved on. Any language where "at" is reserved (few) will hit this; it
  cost about two minutes once the error message was read.
- **The real translation problem was structural, not lexical.** Chapter 4,
  §4.5, redefines chapter 3's `thick_line` as `segment(point(x0+0.5,
  y0+0.5), point(x1+0.5, y1+0.5), w)`. That's fine in a language that
  resolves names at call time or supports forward declarations. Lean
  resolves top-level `def`s strictly in file order with no forward
  declaration for plain functions, and chapter 3's own `fan_coverage` render
  calls `thick_line` *before* chapter 4's `Tuple`/`Matrix3`/`segment` would
  otherwise be defined later in the same file. The fix was to physically
  relocate chapter 4's §§4.1-4.5 (points, vectors, matrices, the four
  transforms, `approx_scale`, `segment`, `union`, `transformed`, `outline`)
  up into the chapter 3 section of `Renderer.lean`, directly before "The
  renders", replacing the old `thick_line` body with the new one-liner over
  `segment`. Chapter 4's actual new material — §4.6, `fan_points`,
  `letter_f`, the two chapter-4 renders — stays where you'd expect, after
  chapter 3's renders. A comment at both splice points explains the jump.
  This is purely a Lean (and any strict single-pass, top-to-bottom language)
  problem; nothing in the book's prose is at fault, and a reader in Python,
  Ruby, or anything with mutual recursion or forward declarations across a
  module would never notice.
- Adding a second "carries no arithmetic meaning on its own" numeric type
  (`Tuple`, alongside `Color`) meant duplicating `Add`/`Sub`/`Neg`/`HMul`/
  `HDiv` instances and an `approxEq`. Mechanical, but four instances per
  numeric type is a lot of boilerplate for two types; a language with
  operator overloading via a shared numeric protocol (or just duck typing)
  would have less of this.

### Failures

None. All 76 scenarios passed, including after the chapter 3 catch-up fix
above (which chapter 4 doesn't directly touch, but is upstream of the same
rasterizer).

### Prose problems

None found. §4.4's three-candidates-for-`approx_scale` discussion is
unusually thorough for a "just trust me, use the third one" section, and the
worked numbers (2 for `scaling(4,1)`, 1.618 for `shearing(1,0)`'s true
stretch) are exactly reproducible by hand, which made it easy to sanity
check `approxScale` before running a single test.

### Concrete changes

None for this chapter — no gaps to close.

## Chapter 5 — Paths and Insideness

### Result

32 scenarios (chapter05-paths 10, chapter05-winding 9, chapter05-rules 9,
chapter05-plate 4), all passing on the first attempt. Both renders exact:

| render | max_channel_difference |
| --- | --- |
| `star-centers.ppm` | 0 |
| `star-coverage.ppm` | 0 |
| `plate-05.ppm` | 0 |

### Catch-up

No prior chapter 5 code existed (this is the first pass at chapter 5), so
nothing to catch up — this row is here only for symmetry with the other two
sections. Chapters 1-4 were already brought current in the chapter 4
section above, and chapter 5 didn't add anything to their feature files.

### Ambiguities

- **Even-odd's parity rule for a negative winding number is never pinned by
  a scenario.** The prose says "even-odd: a point is inside when its winding
  number is odd," and every `inside_evenodd`/`filled(..., "evenodd")`
  scenario in `chapter05-rules.feature` only ever produces winding numbers
  0, 1 or 2 — never a negative one, which only arises from a loop wound
  counter-clockwise (`winding_at(p, 5, 5) = -1` is pinned in
  `chapter05-winding.feature`'s "the other way round" scenario, but that
  scenario doesn't call `inside_evenodd` or `inside_nonzero`). Mathematically
  -1 is odd, and `insideEvenOdd` here computes `(windingAt p x y).natAbs % 2
  == 1`, which gets that right. But a reader in a language with C-style
  truncating integer modulo (`-1 % 2 == -1`, not `1`) who writes the natural-
  looking `w % 2 == 1` would silently get "-1 is not odd" and mark a
  counter-clockwise single loop as a **hole** under even-odd, which is wrong
  and demonstrably different from every vector tool's behavior. This is
  exactly the kind of half-of-a-compound-rule the project's own writing
  guide says to probe separately (CLAUDE.md: "Probe each half of a compound
  rule separately"), and right now nothing does. See Concrete changes.
- Nothing else needed guessing. `close()` on an empty path, `line_to` with
  nothing to extend, `line_to` after `close`, and the half-open crossing
  rule are all pinned exactly and unambiguously.

### Hard to translate

- **Winding numbers are signed**, so the harness needed a new `eqI` (Int
  equality) helper alongside `eqN` (Nat). Trivial once noticed, but every
  prior chapter's counts, lengths and pixel values were all naturally
  non-negative, so this was the first scenario set to need a genuinely
  signed integer comparison.
- Representing a path as `{ subpaths : Array Subpath }` with `Subpath =
  { points : Array Tuple, closed : Bool }` and threading `moveTo`/`lineTo`/
  `close` through immutable updates (`p.subpaths.set! i {...}`) is the same
  pattern chapter 1's `Canvas` already established, so this one was easy —
  worth noting only because it confirms the pattern generalizes past a flat
  pixel buffer to a tree-shaped-ish value.
- `bounds(p)` needing `(0, 0, 0, 0)` for an empty path (rather than some
  sentinel like `±infinity`) is a deliberate, stated choice, and matches
  Lean's lack of a natural "empty min/max" idiom — no translation difficulty
  once the book states the convention outright, which it does.

### Failures

None. All 32 scenarios passed, including the pentagram scenarios that probe
exactly the boundary the crossing-count/winding-number split is built to
demonstrate.

### Prose problems

The "even-odd parity of a negative winding number" gap above is really a
scenario gap, not a prose error — the prose sentence ("inside when its
winding number is odd") is correct as written and I doubt any working
implementation gets it wrong by accident, since the natural implementation
in most languages (Python's `%`, Ruby's `%`) already floors toward negative
infinity and gets the right answer for free. It only bites C, C++, Java,
JavaScript, C# and Lean/Rust-style truncating-toward-zero languages, which is
a real fraction of the book's audience. Flagging as a prose/scenario problem
because the fix is one scenario, not a code change.

### Concrete changes

- Add a scenario to `chapter05-rules.feature`, something like: given a
  single square wound counter-clockwise (`winding_at = -1`), assert
  `inside_evenodd(p, 5, 5) = true` and `inside_nonzero(p, 5, 5) = true`. That
  pins the negative-winding parity convention the way the positive-winding
  cases already are, and it's exactly the kind of scenario CLAUDE.md asks
  for: it can fail on the specific mistake (`w % 2 == 1` under truncating
  modulo) that every scenario currently in the file cannot.

## Chapter 6 — Filling a Polygon

### Result

37 scenarios (chapter06-edges 6, chapter06-spans 16 [12 named + a 4-row
outline], chapter06-sweep 12, chapter06-plate 3), all passing on the
first attempt, including the byte-for-byte cross-check against chapter 5's
`rasterize_centers` that seven of the sweep scenarios perform directly.
Both renders exact:

| render | max_channel_difference |
| --- | --- |
| `spiral.ppm` | 0 |
| `plate-06.ppm` | 0 |

### Catch-up

No prior chapter 6 code existed and chapter 6 doesn't add scenarios to
earlier chapters' feature files, so there was nothing to catch up here
either. (Chapters 1-4 were brought current once, in the chapter 4 section
above; nothing since has gone stale, confirmed by the full 280/280 pass
after every mutation-testing revert below.)

### Ambiguities

None. This chapter's pseudo-code (`spans_from_crossings`, `fill_path_
aliased`) is given almost line-for-line, and every half-open comparison the
book calls out (`y_top ≤ y < y_bottom` three times, in `crossings`/
`winding_at` from chapter 5, in `crossings_on_row`, and in the sweep's active-
list filter; `x0 ≤ center < x1` in `fill_span`) is stated explicitly enough
that no judgment call was needed anywhere.

### Hard to translate

Nothing new. Everything here reuses patterns already established: `Edge` is
a plain structure, `edgeTable`/`crossingsOnRow` sort a small `Array` with
`Array.qsort` (safe here — see README, these arrays are edges-per-path or
crossings-per-row, never pixels), and `fillPathAliased`'s active-edge sweep
is a `let mut active := #[]` threaded through a `for row in [0:h] do` with a
`while` loop for the "join" half and an `Array.filter` for the "leave" half,
the same imperative-loop-inside-`Id.run do` idiom every render since chapter
1 has used.

### Failures

None. All 37 scenarios passed, including "The star, both rules, matches
chapter 5 pixel for pixel" and "A transformed star fills where the transform
put it," which are the two scenarios most likely to expose a half-open
mistake or a sign error carried over from chapters 4-5, and didn't.

### Prose problems

None. The trap box about `a.y = b.y` needing to be *exact* (not "close"),
illustrated with the star's own two 58.868810393753...-and-a-bit vertices,
is the single best piece of "here is a bug you will ship and not notice"
writing in these three chapters — it names the actual floating-point values
involved, explains why the resulting sliver edge is harmless, and preempts
the natural but wrong impulse to give horizontal-ish edges an epsilon
tolerance. Nothing to fix.

### Concrete changes

None for this chapter.

## Mutation results

Picked plausible mistakes and checked at least one scenario fails for each,
per language/chapter-agnostic instructions. Seven mutations tried across
chapters 4-6; six caught, one did not — and that one is the book's own named
trap, working exactly as the prose predicts.

| # | Chapter | Mutation | Caught? | By |
| --- | --- | --- | --- | --- |
| 1 | 4 | `transformed`: skip the `is_invertible` check, always take the inverse (dividing by a zero determinant gives `inf`/`NaN`, which compares `false` to everything) | **No** — all 211 scenarios (chapters 1-4) still passed | — |
| 2 | 4 | `rotation(r)`: swap the sign of sine (`matrix3(cos r, sin r, 0, -sin r, cos r, 0, 0, 0, 1)`) | Yes | 13 scenarios across chapter04-transforms and chapter04-plate, including both plate renders (`max_channel_difference` 207) |
| 3 | 4 | `inverse`: skip the transpose, write `cofactor(m, r, c) / d` into `[r, c]` instead of `[c, r]` | Yes | 6 scenarios: "Calculating the inverse of a matrix", "Multiplying a product by its inverse", "The inverse of a transform is a transform", "The inverse of a translation moves the other way", "The inverse of a rotation turns the other way", "The transform is applied in the order the matrix says" |
| 4 | 5 | `crossings`/`winding_at`: use a closed interval (`a.y ≤ y ≤ b.y`) instead of half-open | Yes | 2 scenarios ("A ray through a vertex counts it once" and the pentagram winding scenario, both double-counting the vertex exactly as the book predicts) |
| 5 | 5 | `line_to`: ignore the `closed` flag, always append to the last subpath | Yes | 1 scenario ("line_to after a close starts a new subpath where the closed one began") — the only scenario written specifically to catch this, and it did, cleanly |
| 6 | 6 | Sweep's active-edge filter: `e.y_bottom > y` → `e.y_bottom >= y` (an edge active one row too long) | Yes | 1 scenario ("An edge that starts on a sample height is active there, and one that ends there is not"), off by exactly one row (`ink` 12 vs 9) |
| 7 | 6 | `fill_span`: drop the `- 1` from `last := ceil(x1 - 0.5) - 1` (one column too many on the right) | Yes | 11 of 37 chapter 6 scenarios, plus both chapter 6 renders (`max_channel_difference` 204) |

**Mutation 1 is the finding worth repeating.** The book's own prose in §4.5
says almost word for word what happened: "Skip the check and your language
decides: some raise on the division by zero in `inverse`, others hand back a
matrix full of `NaN` that happens to answer `false` to every comparison,
which passes the scenario by accident and will not pass the next thing you
build on it." Lean's `Float` division by zero returns `inf`/`NaN` rather than
raising, `NaN` compares `false` to every `<=`/`>=` comparison in `circle`'s
`inside` test, and so `transformed(circle(...), scaling(0, 1))` silently
becomes "always outside," which is the *correct answer* for that one
scenario and would be the *wrong* answer the moment something built on this
shape needed to distinguish "definitely outside" from "this shape is
degenerate, don't trust any answer about it" — exactly chapter 8's problem
with flattening tolerance, which the book flags as the reason `approx_scale`
exists in the first place. No scenario in chapters 1-4 can tell these two
implementations apart, and I don't see an easy one to add without asking the
shape a second, unrelated question (e.g. `approx_scale` of the same matrix,
already 0, so a combined "if approx_scale is 0, treat as empty regardless of
`is_invertible`" scenario would work, but that couples two independently-
justified functions for the sake of one test). Reporting as the most
valuable finding rather than proposing a scenario fix, per the instructions.

## Timing

Machine: this one, `lake build`'s default (release-ish) settings, Lean
4.29.1. All renders produced via `lake exe render`; per-render times are
printed by `Render.lean` itself.

| render (chapter) | time |
| --- | --- |
| `fan_coverage` (3) | ~25.3 s |
| `fan_both_orders` (4) | ~5.6 s |
| `plate_04` (4) | ~8.6 s |
| `star_centers` (5) | ~38 ms |
| `star_coverage` (5) | ~4.0 s |
| `plate_05` (5) | ~4.1 s |
| `spiral` (6) | ~175 ms |
| `plate_06` (6) | ~183 ms |

`lake exe tests` (all 280 scenarios, chapters 1-6, including every render
above since several scenarios call the render functions directly): **~59 s
wall clock**, almost entirely `fan_coverage` (25 s), `star_coverage` +
`plate_05` (8 s together, since `plate05` recomputes both star panels again
via `starCenters`/`starCoverage` rather than reusing chapter 5's own
already-computed canvases), and `fan_both_orders` + `plate_04` (14 s
together, same double-computation pattern). Chapter 6's sweep-based renders
cost under half a second combined and don't move the needle. This matches
the book's own claim almost exactly: coverage-based filling is "a few
seconds," and the sweep is "too fast to time with a stopwatch" in a compiled
language — true here down to the millisecond count. The gap between chapter
5's coverage renders (~8s combined) and chapter 6's sweep renders of a
structurally similar picture (24 stars vs. 2 stars, and still 175ms) is the
whole chapter's argument made in wall-clock time.
