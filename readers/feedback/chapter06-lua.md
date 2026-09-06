# Reader feedback — Lua 5.4, chapters 1-6

First reader in this language: there was no `readers/lua/` to catch up, no prior
code, nothing borrowed. Everything below comes from reading the six chapter HTML
files and the `features/chapterNN-*.feature` files, in that order, chapter by
chapter, and running each chapter's suite (and its renders, diffed against
`reference/chapter-0N/`) before moving to the next.

Headline: all 269 translated scenarios pass, and all 19 named renders match the
book's reference PPMs with `max_channel_difference = 0` (not just ≤ 1 — bit-exact).
No chapter needed a workaround or a "the reference must be wrong" moment.

## Chapter 1 — The Canvas and the Color

**Result:** 51/51 scenarios pass. Renders: `gray-match`, `quarter-match`, `ramp`,
`clamp-pair`, `plate-01` all `max_channel_difference = 0`.

**Catch-up:** n/a (first reader, nothing existed yet).

**Ambiguities:** None that mattered. The chapter is unusually explicit — it even
tells you the tie-break rule for `round` doesn't matter because "no test in this
book lands close enough to a half," and it's right; I used `floor(x + 0.5)`
without incident.

**Hard to translate:** Nothing hard. Lua's numeric `for x = a, b do` is inclusive
at both ends already, which matches the book's pseudo-code convention for free —
no off-by-one to hunt for at every loop the way a half-open-range language would
need.

**Failures:** None.

**Prose problems:** None found. §1.1's notation section is unusually
load-bearing and I used it verbatim as a spec for what my `T.assert_eq` etc. had
to do.

**Concrete changes:** None.

## Chapter 2 — Coverage

**Result:** 35/35 scenarios pass. Renders: `disc-centers`, `disc-coverage`,
`painted-twice`, `plate-02` all `max_channel_difference = 0`.

**Ambiguities:** `rectangle(x0, y0, x1, y1)` — "boundary included" is stated for
`inside`, but the coverage rasterizer's 8x8 sample grid means the boundary case
is rarely sampled directly; I implemented `inside` with `<=`/`>=` on all four
sides per the prose and it matched every reference value, including the "covered
exactly" scenario where the rectangle's edges land precisely on sample-cell
boundaries.

**Hard to translate:** None. Lua has no operator overloading conflict here since
shapes are plain closures (`{ inside = function(x,y) ... end }`), so `union`
(reserved in some languages) was a non-issue — I just named the function `union`
directly and it exported fine as a table field.

**Failures:** None.

**Prose problems:** None.

**Concrete changes:** None.

## Chapter 3 — Lines

**Result:** 38/38 scenarios pass. Renders: `fan-bresenham`, `fan-wu`,
`fan-coverage`, `plate-03` all `max_channel_difference = 0`.

**Ambiguities:** None — the chapter prints Bresenham's algorithm and
`thick_line`'s four half-planes in full precisely because the sign conventions
are easy to get backwards, and having the literal formulas meant there was
nothing to guess.

**Hard to translate:** The FMA trap in the "Except that the grid is blind along
the diagonal" trap box (§3.3) doesn't apply the same way in an interpreted
language — Lua's reference VM does all arithmetic through the `lua_Number`
double type without fusing multiply-adds across separate bytecode
`MUL`/`ADD` ops (no `#pragma STDC FP_CONTRACT` equivalent), so the scenario
passed without needing any compiler-flag consideration. Worth a one-line note in
the chapter that this trap is specific to ahead-of-time-compiled languages with
optimizing backends (C, C++, some Rust release builds), not interpreters.

**Failures:** None.

**Prose problems:** None.

**Concrete changes:** None.

## Chapter 4 — Points, Vectors, Transforms

**Result:** 76/76 scenarios pass (the largest chapter by scenario count).
Renders: `fan-both-orders`, `plate-04` both `max_channel_difference = 0`.

**Ambiguities:** `M[r, c]` notation in the scenarios isn't valid Lua (you can't
subscript with two arguments), so I translated every such step to
`mat_get(M, r, c)`. The chapter itself anticipates this ("Rename them if your
language's conventions insist"), so this isn't a complaint, just a note on the
translation. Likewise Gherkin data tables (`Given the following matrix M:`)
became a small `table_matrix({{1,2,3},{4,5,6},{7,8,9}})` helper in the spec file
that flattens the rows into `matrix3(...)`.

**Hard to translate:** `union` as a shape combinator name collided with nothing
(Lua has no `union` keyword), so unlike C/Rust readers I didn't need
`union_of`. Matrix multiplication overloading (`*` on `Matrix * Matrix` vs.
`Matrix * Tuple`) is handled with a single `__mul` metamethod that dispatches on
the second operand's metatable — clean, no ambiguity.

**Failures:** None.

**Prose problems:** None. The three wrong-F figures in §4.6 (Figure 4.5) are
genuinely useful as a checklist while writing `letter_f`/`f_both_orders` — I
mentally checked my own implementation against each of the three named mistakes
(vector instead of point, transposed matrix storage, degrees-as-radians) before
running the tests, and none of them were present, which the tests then
confirmed.

**Concrete changes:** None.

## Chapter 5 — Paths and Insideness

**Result:** 32/32 scenarios pass. Renders: `star-centers`, `star-coverage`,
`plate-05` all `max_channel_difference = 0`.

**Ambiguities:** None. The half-open crossing rule
(`a.y <= y < b.y or b.y <= y < a.y`) is given as exact pseudo-code for
`winding_at`; I had to write `crossings(p, x, y)` myself since only prose
describes it ("look at each edge... if that x is to the right of your point,
count it"), but the half-open condition is stated in the surrounding prose
clearly enough that there was nothing to guess — I used the identical
half-open test as `winding_at` and it matched the vertex-through-ray scenarios
exactly.

**Hard to translate:** None.

**Failures:** None.

**Prose problems:** None.

**Concrete changes:** None. One observation, not a change request: `star()`
being defined in chapter 5 and then reused unmodified by chapters 6's
`unit_star()`/`spiral()` is a nice piece of continuity that a from-scratch
reader benefits from — the star's exact vertex coordinates (pinned to four
decimals) meant chapter 6 built directly on already-verified code with zero new
geometry to re-derive.

## Chapter 6 — Filling a Polygon

**Result:** 37/37 scenarios pass. Renders: `spiral`, `plate-06` both
`max_channel_difference = 0`.

**Ambiguities:** None. The chapter is exceptionally precise about the two
half-open rules (`y_top <= y < y_bottom` for both `crossings_on_row` and the
sweep's active-list membership, and `[x0, x1)` for `fill_span`), and gives
`fill_span`'s exact boundary formula (`ceil(x0 - 0.5)` / `ceil(x1 - 0.5) - 1`) in
pseudo-code, so there was nothing to invent.

**Hard to translate:** None. Lua's `math.ceil` on an already-integral float
(e.g. `math.ceil(2.5 - 0.5)` = `math.ceil(2.0)`) behaves as expected with no
platform quirks.

**Failures:** None.

**Prose problems:** None. The trap about `a.y = b.y` being an *exact* equality
test, and the star producing a fifth near-horizontal edge from floating-point
noise in its two "equal-height" vertices, is exactly right — I confirmed my own
`edge_table(star())` does produce 5 entries (not 4), matching the chapter's own
aside that the scenarios deliberately don't pin that count.

**Concrete changes:** None.

## Mutation testing

Five mutations were tried against the full 269-scenario suite (each applied,
run, then reverted before moving to the next — the suite is back to 269/269 and
every render still diffs at 0 after all of them):

| # | Mutation | Result |
|---|----------|--------|
| 1 | `to_byte`: truncate (`math.floor(e*255)`) instead of round (`math.floor(e*255+0.5)`) | **Caught** — 7 scenarios fail (chapter 1's ramp-line scenario, and five chapter-2 P6 byte-value scenarios, plus one paint-through scenario) |
| 2 | Canvas pixel index: `x * width + y + 1` instead of `y * width + x + 1` (a silent, self-consistent transposition of the backing array) | **Caught, but not by the scenario built for it.** Chapter 1's own "x is the column and y is the row" scenario does *not* fail — a write/read round-trip on the same coordinate pair is indistinguishable under a consistently-wrong-but-self-consistent index formula. It's caught downstream, 7 scenarios later, by non-square canvases whose width and height are far enough apart that the formula runs off the end of the backing array (`Plate 1` at 400×180, `Plate 2` at 480×240, `side_by_side` at 6×3, etc.) — those crash with "attempt to index a nil value" rather than producing a wrong picture. See "Concrete changes" below. |
| 3 | Bresenham tie rule: `if err <= 0` instead of `if err < 0` | **Caught** — exactly the 3 scenarios built for it ("A shallow line steps along x", "A line going up and to the right", "At an exact half the line stays on its row one step longer") |
| 4 | `spans(p, rule, row)`: sample at `y = row` instead of `y = row + 0.5` | **Caught** — 6 scenarios (the sample-height rectangle, all four rows of the triangle-narrows-by-one Scenario Outline, and the star's mid-row spans) |
| 5 | Browser-mode `mix`: clamp the *decoded result* instead of clamping *each end before encoding* | **Caught** — but only by the single scenario built for exactly this trap ("The browser's way clamps each end before encoding it"), which the project's own `plan.html`/prior-chapter notes call the most valuable kind of scenario to have. No other scenario in the whole suite happens to probe a color argument outside 0-1 through the browser-mode path, so this is a single point of failure worth knowing about, not a gap — it just means don't ever delete that one scenario. |
| 6 | Line "steep" test: `math.abs(y1-y0) >= math.abs(x1-x0)` instead of `>` (both `line_bresenham` and `line_wu`) | **Escaped detection — passes all 269 scenarios.** This is the headline finding; see below. |

### The escaping mutation

Changing the steep/shallow branch test from strict `>` to `>=` in both line
algorithms passes the entire suite. The reason: at `dx == dy` (a perfect 45°
line), the "steep" and "shallow" code paths are mirror-symmetric — swapping
`x`/`y` on a line whose slope is exactly 1 and then swapping the pixel-write
coordinates back on the way out produces exactly the same set of lit pixels
either way. Every diagonal scenario in the book (`line_bresenham(c,0,0,5,5,...)`,
`line_wu(c,0,0,5,5,...)`) has `dx == dy` by construction — it's *the* example of
a diagonal — so neither the Bresenham nor the Wu diagonal scenario can tell `>`
from `>=` apart. No other scenario puts a line exactly on the 45° boundary with
`dx == dy` in a context where the two branches would actually disagree (they only
disagree when the swap is applied to values that aren't symmetric under
exchange, e.g. non-square pixel-write coordinates plus one endpoint off the
diagonal — but no such case exists in the pinned scenarios). This mirrors the
book's own advice almost exactly ("when a scenario claims to test a branch, put
a value on each side where the branches actually disagree") — the diagonal
scenarios test *that a diagonal draws correctly*, not *which branch handled it*,
and for this particular boundary those are different questions. A concrete fix:
add a scenario with `dx == dy` but an asymmetric context, e.g. a diagonal that
starts off-canvas on one axis but not the other, or more directly, add an
assertion (in a debug build / via a side channel) that the `steep` flag itself
took the expected value for a `dx == dy` line — though that reaches past what a
black-box PPM/pixel-list scenario can observe. Simplest real fix: don't worry
about it, since `>` and `>=` produce the *same picture* at that boundary by
construction (that's exactly why it escaped) — it's a latent-but-harmless
ambiguity, not a bug with observable consequences. Still, per the book's stated
goal that every scenario should be able to fail on the mistake it exists for,
this boundary currently has no scenario watching it at all, harmless or not.

## Concrete changes I'd make

1. Add a scenario (chapter 1) that writes to two *different* non-square
   canvases and reads back a coordinate whose row/column indices are large
   enough that a transposed-but-internally-consistent backing-array formula
   would either collide with another pixel or run off the end of the array —
   i.e., make the existing "x is the column and y is the row" catch a wider
   class of indexing bugs than "did you swap the two arguments at the call
   site". As written, that scenario only catches call-site swaps, not
   storage-layout bugs; those are only caught coincidentally, several chapters
   later, by scenarios that happen to use asymmetric dimensions for other
   reasons.
2. (Very minor, no action needed) The FMA/`FP_CONTRACT` trap in §3.3 could
   note in one sentence that interpreted languages without a native
   multiply-add fusion pass (Lua, Python, Ruby, JS) don't need the
   `#pragma STDC FP_CONTRACT OFF` fix — it's specific to compiled languages
   with optimizing backends. Not blocking; a reader in an interpreted language
   might otherwise spend a minute looking for a setting that doesn't exist for
   them.

## Timing

All 269 scenarios: **~68 seconds** end to end (`lua run_tests.lua`), dominated by
the coverage-based (64-samples-per-pixel) render scenarios that call the actual
plate/render functions rather than tiny fixtures — `fan_coverage()` (160×160 at
64 spp) and the chapter 4/5 plates in particular. This number is inflated
because several scenarios call the *same* expensive render function
independently (e.g. `renders.star()` gets rebuilt from scratch by many chapter
5/6 scenarios that could share one fixture) — a reader optimizing this further
would memoize the named render functions per test run.

Regenerating every render fresh via `lua render_all.lua`: **~43 seconds** total,
per-render breakdown:

| Render | Time |
|---|---|
| gray-match, quarter-match, ramp, clamp-pair | <0.1s each |
| plate-01 | 0.13s |
| disc-centers, disc-coverage, painted-twice, plate-02 | ~0.1s each |
| fan-bresenham, fan-wu | <0.05s each |
| fan-coverage | 4.5s |
| plate-03 | 0.25s |
| fan-both-orders | 8.6-9.2s |
| plate-04 | 10.7-10.9s |
| star-centers | 0.24s |
| star-coverage | 6.6-7.0s |
| plate-05 | 7.2-7.6s |
| spiral | 0.3s |
| plate-06 | 0.6s |

The pattern matches the book's own claim almost exactly: "twenty million inside
tests... a quarter of a second or less in most compiled languages" (chapter 3)
— Lua 5.4's reference interpreter is roughly 20-40x that, landing in the
single-digit seconds for the 64-samples-per-pixel renders. Chapter 4's
`plate_04` (five 160×160 rasterizations at 64 samples/pixel, per the chapter's
own estimate) is the slowest single render at ~11 seconds; chapter 5's coverage
panels (two 160×160 rasterizations of the star, each sample a 5-edge winding
number) are the next slowest at ~7 seconds each. Nothing timed out or needed a
workaround; it's simply the cost of an unoptimized brute-force supersampler in
a bytecode interpreter, exactly as the book predicts and budgets for.
