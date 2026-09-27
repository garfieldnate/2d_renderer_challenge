# Reader feedback: chapters 22 and 23 (Python)

This reader implemented chapters 1 through 21 in an earlier round; this pass adds chapters 22
(Boolean Path Operations) and 23 (Distance Fields) cold, from the chapter text and the scenarios
alone, on top of the existing code.

## Chapter 22 — Boolean Path Operations

### Result

All 56 scenarios in `features/chapter22-*.feature` pass:

| Feature file | Scenarios |
|---|---|
| chapter22-grid.feature | 5 |
| chapter22-meet.feature | 8 |
| chapter22-split.feature | 5 |
| chapter22-inside.feature | 9 |
| chapter22-combine.feature | 10 |
| chapter22-sweep.feature | 3 |
| chapter22-bentley.feature | 6 |
| chapter22-robust.feature | 8 |
| chapter22-plate.feature | 2 |

Renders, against `reference/chapter-22/`:

| Render | max_channel_difference | Time |
|---|---|---|
| plate-22.ppm | 0 | 0.9 s |
| seal.ppm | 0 | 17.1 s |

Both are byte-exact, not just within the scenario's budget of 1.

### Catch-up

Ran the inherited chapters 1-21 test suite (727 scenarios, unchanged code) alongside chapters 22
and 23: all 727 still pass, and the whole suite (826 scenarios, chapters 1-23) passes together.
No scenario in an earlier chapter's `.feature` file failed on the code this reader last left in
place, so there was nothing to catch up — either nothing was added to those files since the last
round, or what was added was already covered.

### Ambiguities

- `roboto()` is used by `chapter22-sweep.feature`'s definition of `struck_line`/`struck_segments`
  ("`struck_segments(n)` is `merge_segments` of `path_segments(text, "a")` ...") and by
  `chapter23-atlas.feature` ("Given f ← roboto()"), but it is never itself defined anywhere in the
  chapter text or a `.feature` file. Guessed it's a one-line convenience wrapper,
  `load_font(read_file("reference/chapter-16/roboto.json"))`, matching the inline pattern every
  earlier chapter's render functions already use. Every numeric scenario that depends on it
  (`struck_segments(1)` having exactly 787 segments, `bake_sdf`'s exact texel values) matched, so
  the guess is almost certainly right, but the chapter should spell it out the way `plate_glyph()`/
  `plate_star()` are spelled out in `chapter22-plate.feature`'s prose.
- `combine`'s internal `find_splits` method is deliberately left open ("The finder doesn't change
  the answer; use any."). This implementation uses `"sweep"` for `combine`/`simplify` (and
  everything built on them — `plate_22`, `seal`, `plate_glyph`/`plate_star`'s use in chapter 23),
  not the newly-written `"bentley-ottmann"`, specifically so that a bug in the new
  Bentley-Ottmann code (the hardest, least-tested-by-construction part of the chapter) would only
  fail its own three direct scenarios, not every render in two chapters. That's a testing
  decision, not really an ambiguity, but the chapter never says which method the *reference*
  render was built with, which would matter to a reader trying to reproduce the reference's timing
  or benchmark their own `combine` against it.

### Hard to translate

- The chapter spells out, for languages with only fixed-width integers, keeping a crossing's
  numerator and denominator as separate whole numbers and comparing two events via
  cross-multiplication (`Y1 × D2` vs `Y2 × D1`) so a rounding error can never misorder the sweep.
  None of that bookkeeping is needed in Python: `orient` and `crossing_point` already work exactly
  on plain `int` (arbitrary precision), and Bentley-Ottmann's events are kept as
  `fractions.Fraction` pairs, which do the same gcd-reduce-and-compare-exactly job automatically
  and read much closer to the algebra in the prose (`lex_less`/`orient` work unmodified on a
  `Fraction` point, since Python's numeric tower lets `int` and `Fraction` compare and arithmetic
  together transparently). A reader in Java/Rust/C#/JS would need the chapter's literal recipe;
  a Python reader gets an easier ride the chapter doesn't call out.
- One genuine subtlety survived the switch to exact arithmetic and cost real debugging time: a
  segment that gets cut mid-sweep has to keep the *exact* (possibly fractional) crossing point as
  its continuation's new "lo" for the rest of that same Bentley-Ottmann pass — not the grid-rounded
  point. Rounding it immediately can, in small examples, push the rounded point past the
  segment's own original "hi" in the sweep's order (same row, tied on x the wrong way), which
  breaks the status list's ordering invariant partway through the sweep (a segment whose "lo" is
  later, in sweep order, than an event already queued ahead of it). The chapter's own multi-pass
  `split_segments` loop is exactly the mechanism that absorbs this same rounding wobble one level
  up (Figure 22.2's three-segments-needing-three-passes example), but the prose doesn't say the
  same wobble is a hazard *inside a single Bentley-Ottmann pass's own bookkeeping* if you round
  before the pass is over instead of only when recording the split for output. First draft rounded
  immediately and failed "A crossing between grid points is an exact event, split rounded" with a
  spurious extra split point recorded on the wrong segment; fixed by keeping the continuation's
  position exact throughout the sweep and rounding only the value written into the output split
  list.

### Failures

None outstanding — every scenario passes.

### Prose problems

- `roboto()` used without definition (see Ambiguities).
- No statement of which `find_splits` method backs the reference's own `combine`/plates.
- Everything else in §22.1-22.9 checked out exactly against the scenarios; no incorrect claims
  found.

### Mutation results

1. **Truncate instead of round halves-up in `crossing_point`** (`(2n+d)//(2d)` → `n//d`): caught
   immediately by the scenario written for exactly this, "A crossing between grid points rounds to
   one, halves up" (`(1, 0)` instead of `(2, 1)`), and cascades into 6 more failures including
   both plate renders (`max_channel_difference` rising to 2-3).
2. **`stitch`'s furthest-right-turn tie-break replaced by "take the first unused candidate arrow"**
   (drop the turn comparator entirely): caught by "The star's crossings become corners" (comes out
   with 4 subpaths under `"evenodd"` where 5 are expected) and by both plate renders (`Plate 22`'s
   `max_channel_difference` rises to 3, `The seal`'s to 21) — **but not** by the chapter's own
   direct unit scenario for this, "Turning furthest right keeps two squares that touch at a corner
   apart." That scenario's list of kept edges happens to put the *correct* choice first in this
   implementation's adjacency structure (built by one left-to-right scan over the input in order),
   so "just take whatever's first" passes it purely by coincidence of iteration order. This is the
   most useful single finding of the round: the direct unit test for this tie-break is not, by
   itself, strong evidence the tie-break is implemented — it needs a case constructed so that "take
   the first candidate found" and "take the furthest right turn" disagree *regardless of how a
   reader happens to order their own adjacency lookup* (for instance, two arrows at the shared
   vertex listed in the opposite order from this one, or a vertex shared by three or more regions).

### Concrete changes

- State `roboto()` explicitly, the same way the plate's helpers are spelled out.
- Note which `find_splits` method the reference implementation itself uses.
- Add a second stitch tie-break scenario, order-independent of how a reader's own adjacency
  structure happens to be built (see mutation 2 above) — ideally by permuting the same `kept` list
  from the existing scenario and asserting the identical result, so "coincidentally first" can't
  survive by luck of ordering.

### Timing

- Whole `chapter22-*.feature` suite: ~29 s.
- `plate-22.ppm`: 0.9 s. `seal.ppm`: 17.1 s (61 `combine()` calls, each a full
  split/classify/stitch pass over a growing segment set — by the end of the rosette the working
  set is several hundred segments).

---

## Chapter 23 — Distance Fields

### Result

All 43 scenarios in `features/chapter23-*.feature` pass:

| Feature file | Scenarios |
|---|---|
| chapter23-primitives.feature | 5 |
| chapter23-curves.feature | 6 |
| chapter23-render.feature | 4 |
| chapter23-free.feature | 4 |
| chapter23-smooth.feature | 2 |
| chapter23-transform.feature | 4 |
| chapter23-atlas.feature | 7 |
| chapter23-compose.feature | 1 |
| chapter23-plate.feature | 10 |

Renders, against `reference/chapter-23/` — every one is byte-exact (`max_channel_difference` 0,
not just within the scenario's budget of 1):

| Render | max_channel_difference | Time |
|---|---|---|
| primitive-fields.ppm | 0 | 0.7 s |
| error-map.ppm | 0 | 1.1 s |
| fillets.ppm | 0 | 0.5 s |
| transform-demo.ppm | 0 | 0.2 s |
| trap-shrink.ppm | 0 | 18.6 s |
| fields-vs-paths.ppm | 0 | 29.8 s |
| atlas-corners.ppm | 0 | 2.7 s |
| plate-23.ppm | 0 | 15.4 s |
| title.ppm | 0 | 4.8 s |

### Catch-up

Shared with chapter 22 above: the inherited chapters 1-21 suite (727 scenarios) still passes
unchanged, and the whole suite (826 scenarios) passes together. Nothing to catch up this round.

### Ambiguities

- `circle_field(cx, cy, r, w, h)` — the very first scenario of `chapter23-render.feature` ("A
  field is sampled at pixel centers") — is used but, like `roboto()`, never defined in the prose or
  any feature file. Guessed it's `field(w, h, lambda p: sd_circle(p, point(cx, cy), r))`; the
  scenario's exact numbers (`field_at(f, 8, 8) = -2.292893`, etc.) confirmed the guess.
- `bake_msdf`'s tie-break score `o`: §23.9's `msdf_texel` pseudocode says `o` is "`|dot(direction at
  t, unit(p − point_at(c, t)))|` if `t` is 0 or 1, **else 0**" — so an edge whose nearest point is
  strictly interior to it (not at either end) always gets the most favorable possible tie-break
  score, and only loses a near-tie to another interior candidate on distance alone. This is stated
  precisely enough to implement correctly by reading the pseudocode literally, but the prose
  paragraph above it only describes the *end* case ("the one whose end direction is more nearly at
  right angles...") and never says in words why an interior candidate is treated as automatically
  tied-for-best; a reader translating from the prose alone, without noticing the pseudocode's
  `else 0`, could plausibly guess `o` should be undefined/infinite for interior candidates instead
  (making them never win a near-tie), which is the opposite policy. Every scenario matched with `o
  = 0` for interior candidates, so that's confirmed correct, but it's easy to miss.

### Hard to translate

Nothing chapter-23-specific fought the language. Every formula in §23.1-23.5 and §23.9 is a direct
one-liner in Python, and there's none of chapter 22's fixed-width-integer concern (a `Field`'s
values are ordinary floats throughout, matching the chapter's own framing that fields, unlike the
grid, stay in floating point). The only real cost is performance, not translation: `plate_glyph_field`,
`plate_field`, and `bake_msdf`'s per-channel, per-texel loop over every colored edge are all
nested Python loops calling `distance_to_quadratic` (itself a closed-form cubic solve, not
iterative) tens of thousands of times per render — correct, but visibly the slowest code in the
book so far in an interpreted language (see Timing).

### Failures

None outstanding — every scenario passes, and every render is byte-exact.

### Prose problems

- `circle_field` used without definition (see Ambiguities).
- The `o`-for-interior-candidates policy in `bake_msdf`/`msdf_texel` is only fully specified in the
  pseudocode, not the surrounding prose (see Ambiguities) — worth a sentence.
- Everything else in §23.1-23.9 checked out exactly, including the two numbers the prose quotes
  from its own reference run (`distance_to_curve(c, p) ≥ 5.4` for the looping-cubic scenario, and
  the "a version without the ends says 59.7 where the answer is 50" claim for the end-omitted
  Newton mutation below) — both reproduced exactly against this implementation.

### Mutation results

1. **`sd_box` with the "inside" term dropped** (`min(max(qx,qy),0)` removed, keeping only the
   outside-distance term): caught immediately and directly by the chapter's own primitive scenario,
   "A box, beside a side, off a corner, and inside" — every point actually inside the box now reads
   distance 0 instead of negative (`0.0` vs `-4`, `0.0` vs `-1`) — and cascades to 3 failures total
   including a full render (`max_channel_difference` 189).
2. **`smooth_min`'s `h` clamp dropped** (`max(k - |a-b|, 0)` → plain `k - |a-b|`, unclamped):
   caught directly by "Far apart it's min; close together it's less" (`smooth_min(1, 5, 2)` comes
   out `0.5` instead of exactly `1` — once `|a-b| > k`, the unclamped `h` goes negative, and
   squaring it undoes the "far apart it's plain min" guarantee) and by "The fillet fills the
   crease" and a render scenario.
3. **`distance_to_cubic`'s two endpoints dropped from the candidate list, keeping only the nine
   Newton-refined seeds**: caught exactly by the scenario written for this,
   "The nearest point of a cubic can be an end that Newton walks away from." With the ends
   removed, the mutated code returns `59.70862011528161` for a query the true answer to is `50` —
   matching, to five decimals, the chapter's own quoted number for this exact mistake ("a version
   without the ends says 59.7 where the answer is 50"). This is a clean, exact reproduction of a
   number the author already knew about, which is about as strong a confirmation as a mutation test
   can give that both the scenario and this implementation are doing the right thing for the right
   reason.

No mutation tried this round passed every scenario undetected; every one of the five (two in
chapter 22, three in chapter 23) was caught by at least one scenario, and four of the five were
caught by the chapter's own scenario written specifically for that mistake.

### Concrete changes

- Define `circle_field` explicitly, the same as the chapter's other one-off render/test helpers.
- Add one sentence to §23.7/23.9 stating outright that an interior nearest-point candidate's
  tie-break score is 0 (favored over any end candidate whose direction isn't itself exactly
  perpendicular), since the prose paragraph only walks through the end case and the `else 0` only
  appears in the pseudocode.

### Timing

- Whole `chapter23-*.feature` suite (43 scenarios): 2 min 51 s. This is more than the sum of the
  nine renders' own times below (~74 s) because several renders are computed a second time inside
  `chapter23-plate.feature`'s "What the renders show" pixel-probe scenario (which calls
  `primitive_fields()`, `error_map()`, `fields_vs_paths()`, `fillets()`, `atlas_corners()` and
  `trap_shrink()` again, independently of their own "Each render matches its reference" scenario),
  plus `chapter23-curves.feature`'s `weyl_points(10000, ...)` ground-truth scenario, which calls
  `brute_distance` (129 samples plus up to 40 rounds of ternary search each) 10,000 times over two
  curves.
- Individually, the renders are dominated by `fields-vs-paths.ppm` (29.8 s) and `trap-shrink.ppm`
  (18.6 s) — both spend most of their time in `sd_polygon`'s `winding_at` call, computed once per
  pixel over a 200×160-ish canvas against a path with hundreds of edges (the flattened glyph/star
  paths chapter 22's `combine` and chapter 8's `flatten` produce at tight tolerances). `plate_23.ppm`
  (15.4 s) and `atlas_corners.ppm`/`title.ppm` (2.7 s/4.8 s) are the multi-channel baking and
  per-pixel Newton/cubic-solve work, small by comparison because the baked textures themselves are
  tiny (a few thousand texels total) even though the *math* per texel is the most involved in the
  chapter.
- Whole suite, chapters 1 through 23 (826 scenarios): 7 min 57 s on this machine. Chapters 22 and
  23 together added roughly 3 of those minutes to what chapters 1-21 alone took.

---

## Summary

826/826 scenarios pass (727 inherited + 56 for chapter 22 + 43 for chapter 23); every render from
chapter 2 through chapter 23 is byte-exact against `reference/` (`max_channel_difference` 0),
including all 11 new renders (`plate-22.ppm`, `seal.ppm`, and chapter 23's nine). Five deliberate
mutations were tried across the two chapters and every one was caught by at least one scenario;
one (chapter 22's stitch tie-break) exposed a real gap in test-order-independence in its own direct
unit scenario, only caught reliably by the render scenarios built on top of it. Two chapters, two
undefined convenience helpers (`roboto()`, `circle_field()`) had to be guessed from context and
confirmed by their numbers; both guesses turned out right, and both are the kind of gap a
copy-edit pass over the prose would catch (they're already implicit in the render descriptions'
own text, just never spelled out as functions the way every other one-off render helper is).
