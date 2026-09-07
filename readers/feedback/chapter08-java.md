# Reader feedback — Java, chapters 7 and 8

Cold read of chapter 7 (Analytic Antialiasing) and chapter 8 (Curves) from
the chapter HTML and the `.feature` files alone, on top of the existing
chapters 1-6 Java code. No access to `reference/impl/` or the book's
repository.

## Result

| Chapter | Scenarios | Pass | Fail |
|---|---|---|---|
| 1-6 (catch-up) | 66+35+38+76+32+34 = 281 | 281 | 0 |
| 7 | 34 | 32 | 2 |
| 8 | 21 | 18 | 3 |

Render `max_channel_difference` against `reference/chapter-0N/*.ppm`:

| Render | Diff | Notes |
|---|---|---|
| `needles.ppm` | 204 | geometry unspecified by the chapter, see Ambiguities |
| `soft-square.ppm` | 0 | |
| `star-exact.ppm` | 0 | |
| `spiral-smooth.ppm` | 0 | |
| `plate-07.ppm` | 204 | same root cause as needles (shares `rays()`) |
| `drops.ppm` | 198 | teardrop shape unspecified, see Ambiguities |
| `flower.ppm` | 204 | petal/layout unspecified, see Ambiguities |
| `plate-08.ppm` | 204 | same root cause as flower |

Every failing scenario fails only on its final `max_channel_difference`
(or, for `needles`, one extra `ppm_pixel`) assertion; every dimension check
and every *other* pinned `ppm_pixel` probe in those same scenarios passes,
including all six of `flower`'s pixel probes and four of `plate-07`'s five.
That is the strongest evidence I have that the fill/curve/arc engines
themselves are correct and the mismatch is specifically in figure geometry
the chapter never wrote down.

## Catch-up

Chapters 1-6 unchanged and still 281/281 before touching anything. Nothing
newly broken.

## Ambiguities

This is the chapter's one real gap, and it's the same gap in both
chapters: **the "one-off fun" renders don't get pseudocode.** Every render
in chapters 1-6 is a named function with either literal pseudocode or
numbers explicit enough to reconstruct exactly (`rayEnds()`'s "72 pixels
from (80,80), one every 30 degrees", `star()`'s "radius 70 about (80.5,
80.5)", `spiral()`'s literal formula for radius and rotation per step).
Chapters 7 and 8 stop doing that for exactly the renders whose whole point
is bespoke geometry:

- **Chapter 7, §7.6:** `needle_path()`, `needles()`, and the sunburst's
  `rays(i)` (ray count is given -- seventy-two -- but not their angular
  width, their inner/outer radius, or the twelve needles' geometry beyond
  "thin"). `sunburst()`/`plate_07()` *do* get real pseudocode; `rays(i)`,
  the one function that pseudocode calls, doesn't.
- **Chapter 8, §8.5:** `flower_at`/`flower`/`plate_08` get real pseudocode,
  but the `petal()` function they call (two cubics, their control points)
  is never specified beyond "about one unit tall," and neither are the
  three flowers' `(cx, cy, s, n, rot)` spots. `drops()` isn't given
  pseudocode at all, and its scenario doesn't even pin a `ppm_pixel` --
  only the canvas dimensions and the full-image diff.

**What I guessed**, so the author can compare: for chapter 7 I built
`needlePath()` as twelve wedges (apex shared at the canvas center, base at
a fixed outer radius) and tuned the two free parameters until
`ink(fill_path_aliased(needle_path(), ...))` hit exactly 268.0 (there's a
wide plateau of `(R, half_width)` pairs that do; I used `R = 16.5`,
`half_width = 1.4`). For the sunburst I *did* manage to reverse-engineer
the exact ray formula from the three colored `ppm_pixel` probes at radius
~200 (angle `-90 + 5k` degrees, `k`'s ink is `SPIRAL_INKS[k % 3]`) --
those three probes plus the disc and star (which *are* fully specified)
were enough to pin everything except the ray's angular width and outer
radius, which I set to 2 degrees and 225px. For chapter 8, `petal()` is two
cubics from `(0,0)` to `(0,-1)` bulging ±0.55 in x; I placed the three
flowers by solving backward from the six `ppm_pixel` probes (which pin
each flower's ink color and roughly its center) but the probes
underdetermine size, petal count, and rotation, so I picked plausible
values. Every specified probe passes; the full images don't match.

**This is worth fixing** even though it doesn't block a reader from
finishing the chapter (the fill and curve engines are the graded content,
and both are fully pinned). But it does mean two of chapter 7's five plate
scenarios and all three of chapter 8's can never be made to pass by a cold
reader, no matter how correct their renderer is -- which quietly breaks the
book's own iron rule ("every suggested implementation is specified... each
render is a named function... so scenarios can call it").

## Hard to translate

Nothing else was hard. The Gherkin here translates extremely cleanly
because almost every scenario is either a bare scalar/tuple equality or a
`ppm_pixel` probe, both of which chapters 1-6 already gave me idioms for.
The one new step shape was `a.corrected`/`a.rx`/`a.ry` field access on an
arc result and `arc(...) = none`, both trivial in Java (a record-like class
with public fields, and `null` for "none").

## Failures

Listed above under Result; both are the geometry-ambiguity renders, not
bugs in the specified algorithms. Full detail:

- `Plate 7: the needles, aliased against exact` -- fails on
  `ppm_pixel(p6, 360, 120)`: expected `(94, 78, 51)`, got `(148, 119, 62)`
  ± 1, and on the final `max_channel_difference` (204). Whose fault: mine,
  for not having the author's `needle_path()`/`needles()` parameters --
  see Ambiguities.
- `Plate 7: plate 7` -- fails only on `max_channel_difference` (204); all
  six `ppm_pixel` probes (which happen to sit exactly on ray centerlines
  and known reused colors) pass. Whose fault: mine, same root cause
  (`rays()`).
- `Plate 8: the teardrop, coarse against fine` -- fails only on
  `max_channel_difference` (198); there's no `ppm_pixel` probe to pass or
  fail. Whose fault: the chapter gives no shape for the teardrop at all.
- `Plate 8: the flowers` -- fails only on `max_channel_difference` (204);
  all six `ppm_pixel` probes pass. Whose fault: mine (`petal()`/spots).
- `Plate 8: plate 8` -- same as above, scaled by 2; all four probes pass,
  only the full-image diff fails.

## Prose problems

- §7.6 and §8.5 (see Ambiguities): the renders' own geometry helper
  functions (`needle_path()`, `rays(i)`, `petal()`, the flower spots, the
  teardrop) aren't specified, unlike every prior chapter's renders.
- Everything else I could check against a running implementation checked
  out. In particular the two "tricky" corners of chapter 7 --the fold at
  column 0 and the drop past the right edge in `add_cell`, and the
  midpoint-weighted area formula in `accumulate_row`-- are both pinned
  precisely enough (including the negative-height and multi-cell-share
  scenarios) that I built them correctly on the first pass and they've
  stayed correct since.
- One implementation trap the chapter doesn't mention, discovered by
  running chapter 6's spiral back through the new fill (see Mutation
  results/Concrete changes): a rotated shape's "vertical" edges aren't
  bit-identical in x at both ends (`cos(pi/2)` isn't exactly 0 in floating
  point), so treating `x0 == x1` by exact equality routes them through the
  general multi-cell branch of `accumulate_row`, where `height * segWidth
  / dx` divides by a `dx` of a few `1e-14` and the resulting area is off by
  a dozen orders of magnitude. This isn't a scenario gap so much as a
  missing sentence: none of the row/walk scenarios use a curve or a
  transform, so nothing in `chapter07-*.feature` could have caught it --
  only re-running chapter 6's own spiral through the new fill did. I'd add
  one line to §7.3 warning that `x0 == x1` should be a tolerance check, not
  exact equality, and a scenario built from a 90-degree-rotated square.

## Mutation results

Six plausible reader mistakes, three per chapter:

| # | Mutation | Caught? | By |
|---|---|---|---|
| 1 | Flip the winding sign in `accumulate` (`dir = y0>y1 ? -1 : 1`) | Yes | 6 of the 7 `chapter07-walk.feature` scenarios fail directly |
| 2 | Drop the clamp in `apply_rule`'s nonzero case (`return w` instead of `min(1,w)`) | Yes | `apply_rule(1.5,"nonzero")`, the doubled-square and star fill scenarios |
| 3 | Even-odd fold without reflecting back down (`return w % 2.0`, no `2 - folded` branch) | Yes | `apply_rule(1.25/1.5/2/3.25/-1.5, "evenodd")`, star `ink(eo)` |
| 4 | Area weighted from the wrong side (`mid` instead of `1 - mid`) | Yes | the "slanted piece leans left" row scenario, most of `chapter07-fill.feature`'s ink/coverage checks |
| 5 | **Missing acos domain clamp in `Arc.angleBetween`** | **No** | every `chapter08-arc.feature` scenario still passes |
| 6 | **Flatten before transform in `flowerAt`** (flatten each petal curve in its own unit space, then transform the resulting polyline points, instead of transforming the curve first) | **No** | every `chapter08-*.feature` scenario still passes (the three plate scenarios were already failing for the unrelated geometry-ambiguity reason, so this mutation adds nothing new) |

Mutations 1-4 in Fill.java were caught broadly and immediately -- chapter
7's scenarios are genuinely tight. **Mutations 5 and 6 are the valuable
finding.** Both are real, foreseeable reader mistakes that the prose itself
calls out (§8.4's trap section for the acos clamp implicitly, §8.3's "the
mistake everyone makes once" for flatten order explicitly) and neither has
a scenario that can catch it:

- The acos clamp: `dot(u,v)/(|u||v|)` is mathematically in `[-1,1]` but a
  `cos` that lands at `1.0000000000000002` due to floating point sends
  `Math.acos` to `NaN` in Java (other languages may throw or silently
  return a domain error). None of the four `arc()` scenarios happen to hit
  a case where the two vectors are close enough to parallel/antiparallel
  for the float error to cross the boundary -- I did not construct one
  either, in the time available, but I'm confident one exists (nearly
  back-to-back start/end angles, or a very eccentric ellipse near its
  vertex, are the classic ways this bites in every other Bezier/arc
  library that's ever shipped this bug).
- Flatten-before-transform: this is *mathematically invisible* to any
  scenario that flattens a curve directly, because for an affine map,
  transforming a curve then flattening it produces the exact same points
  as flattening it then transforming the points -- the *only* observable
  difference is how many segments get produced at a given tolerance
  *number*, which only matters once the same curve is reused at different
  final scales. `chapter08-flatten.feature` never transforms a curve
  before flattening it, so it can't see this. The only place in the
  feature files that could have caught it is exactly `flower()`'s "the big
  flower gets more segments than the small one and all three come out
  equally smooth" -- but that's asserted only by eye/full-image diff in
  the prose, never by a `length(flatten(...))` scenario at two different
  scales, and my own copy of that scenario is already failing for the
  unrelated petal-shape ambiguity, so it couldn't demonstrate the catch
  either.

I reverted both mutations; the suite is back to 32/34 and 18/21.

## Concrete changes you'd make

1. Give `needle_path()`/`needles()`/`rays(i)` (chapter 7) and `petal()`/the
   three flower spots/the teardrop shape (chapter 8) the same treatment as
   every other render: literal control points or an explicit formula, the
   way `star()` and `spiral()` get one. This is the only thing keeping a
   correct implementation from reaching 5/5 and 3/3 on the plate features.
2. Add a scenario to `chapter07-walk.feature` (or a new one) built from an
   edge that is mathematically vertical but not bit-identical in x at both
   ends -- e.g. take `unit_star()` (or any path) through
   `rotation(pi/2)` and check that `accumulate`/`fill_path`'s ink still
   equals the untransformed shape's ink. This is precisely the bug chapter
   6's spiral surfaced for me, and it's invisible to every scenario
   currently in the file because they all construct edges with literal,
   exactly-equal x-coordinates.
3. Add a scenario to `chapter08-curves.feature` (or `-arc.feature`) that
   pins `angleBetween`/`arc()` at a near-degenerate angle (start and end
   nearly coincident in direction, or a very eccentric radius ratio) to
   force the acos-domain question into the open.
4. Add a scenario -- even a small unit one, not a full render -- that
   flattens the *same* curve through two different scale transforms at the
   *same* tolerance and asserts the two segment counts scale sensibly
   (e.g. `length(flatten(transform_curve(c, scaling(50,50)), 0.25))` should
   be noticeably larger than `length(flatten(c, 0.25))` for a curve near
   unit size). Right now "flatten after the transform, not before" is
   prose you can silently get backward.

## Timing

Roughly 2 hours end to end: about 50 minutes on chapter 7 (reading,
building the accumulator/fill engine, chasing the vertical-edge bug down
via the spiral re-render, then the needle/sunburst reconstruction), about
50 minutes on chapter 8 (curves/bounds/flatten/arc all went in cleanly on
the first pass; the rest of the time was the flower/petal reconstruction),
and the remainder on mutation testing, README, and this file.

---

## Catch-up (author-run, after the geometry fixes)

The five render scenarios above failed only because chapters 7 and 8 hadn't printed the
bespoke render geometry. After that pseudocode was added to the chapters, a catch-up pass
reconciled this reader's renders using the printed definitions alone: all eight renders now
diff 0 against the reference, and the two scenarios this reader was missing (the half-circle
arc and the flatten-after-transform point count) were translated and pass. The printed
geometry was sufficient; two minor residual notes: `rays(i)` has no angular offset (ray 0
points east, not up, unlike the spiral's convention), and `needle_path`/`rays` share one
wedge shape printed as two blocks rather than a named helper.
