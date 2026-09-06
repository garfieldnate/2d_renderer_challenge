# Reader feedback: chapters 5 and 6, C# (.NET 8)

Cold read, translating every scenario from `features/*.feature` into the existing
hand-rolled test suite (no NuGet). Chapters 1-4 were already implemented; I brought
that code up to date with `features/` first (step 0), then did chapter 5, then
chapter 6, each fully green and rendered before moving on.

## Catch-up (chapters 1-4, before touching chapter 5)

Four scenarios existed in `features/` that weren't yet translated into `Program.cs`:

- `chapter04-tuples`: "magnitude and dot look at x and y only"
- `chapter04-matrices`: "Invertibility is an exact test against zero"
- `chapter04-shapes`: "A union of nothing is inside nowhere"
- `chapter04-plate`: "side_by_side puts the first canvas on the left" (this one also
  required making `Renders.SideBySide` `public` - it had been `private`, used only
  internally by chapter 4's own renders, with no direct test)

All four passed immediately once written - none exposed a latent bug in the existing
code. I looked hard for a reason `SideBySide` might misbehave once exposed (e.g. an
implicit assumption that both inputs were the same height) and didn't find one; the
implementation already handles unequal heights correctly (`Math.Max(a.Height,
b.Height)`), which the new scenario doesn't even probe (both canvases are height 3).
That's arguably a scenario gap, not a code gap - see Concrete changes.

## Chapter 5: Paths and Insideness

### Result

| Feature | Scenarios |
|---|---|
| chapter05-paths | 10/10 |
| chapter05-winding | 9/9 |
| chapter05-rules | 9/9 |
| chapter05-plate | 4/4 |

`out/star-centers.ppm`, `out/star-coverage.ppm`, `out/plate-05.ppm` all match
`reference/chapter-05/*.ppm` byte for byte (`max_channel_difference` = 0 on all
three).

### Ambiguities

- None the prose or scenarios left genuinely open. The one place I expected to have
  to guess - what `line_to` after `close` does to the *new* subpath's starting point
  - is pinned by its own scenario ("line_to after a close starts a new subpath where
  the closed one began"), so there was nothing to guess.
- `bounds()` of an empty path is stated explicitly as `(0, 0, 0, 0)` in prose and
  pinned by a scenario - good, since C#'s `Enumerable.Min`/`Max` throw on an empty
  sequence and a reader who reached for LINQ here would have hit that immediately.

### Hard to translate

- **`Path` collides with `System.IO.Path`.** This project has `ImplicitUsings`
  enabled, which brings `System.IO` (among others) into scope project-wide as a
  global using. The book's `path()` maps naturally to a class named `Path`, and
  the moment I did that, every `new Path()` and `Path.Polygon(...)` in `Program.cs`
  became `error CS0104: 'Path' is an ambiguous reference between 'Chapter01.Path'
  and 'System.IO.Path'`. Inside the class library itself there's no conflict
  (nothing there references `System.IO`), so this only bites in the test file that
  has both `using Chapter01;` and the implicit `System.IO`. I fixed it by
  fully qualifying every call site as `Chapter01.Path` rather than renaming the
  type, since the book's name is the one worth keeping faithful. A C# reader
  translating this chapter cold, who doesn't happen to compile early and often,
  could easily not notice this until dozens of call sites need the same fix. Worth
  a one-line callout in the chapter for C#/Go readers (Go's standard library has
  the same `path` package name collision risk) - something like "if your language
  has a standard library module literally called `path`, expect a name clash and
  qualify or alias it."
- Nothing else was hard. The winding number pseudocode in §5.2 is close enough to
  literal code that translating it was closer to transcription than translation.

### Failures

None. Every scenario passed on the first implementation that matched my reading of
the prose.

### Prose problems

- None found. I did re-read §5.2's half-open rule three times before trusting my
  translation, not because it was unclear, but because getting a sign or direction
  backwards here is exactly the kind of mistake that silently produces a plausible-
  looking but wrong picture - and the prose already anticipates this ("if you wrote
  `≤` at both ends you'll get 2 and 4"), which is exactly the right kind of warning.

## Chapter 6: Filling a Polygon

### Result

| Feature | Scenarios |
|---|---|
| chapter06-edges | 6/6 |
| chapter06-spans | 16/16 |
| chapter06-sweep | 12/12 |
| chapter06-plate | 3/3 |

`out/spiral.ppm` and `out/plate-06.ppm` both match `reference/chapter-06/*.ppm`
byte for byte (`max_channel_difference` = 0). Every `fill_path_aliased` scenario
also independently checks `max_coverage_difference(sweep_result,
rasterize_centers(filled(...))) = 0` - the fast sweep and chapter 5's slow reference
agree pixel for pixel on every shape the scenarios throw at it (rectangle, triangle,
both windings of that triangle, an off-center polygon circle, the star under both
rules, a rectangle whose edges sit exactly on sample heights, a polygon bigger than
the buffer, an empty path, and a scaled/translated star).

### Ambiguities

- None. This chapter is unusually well-specified for an algorithm with this many
  off-by-one opportunities - every half-open boundary in `fill_span`,
  `crossings_on_row`, and the active-edge-list join/leave rule has a scenario that
  specifically probes it (see Mutation results below - three separate ways to get a
  boundary backwards, three separate scenarios that catch it).

### Hard to translate

- The pseudocode for `fill_path_aliased` translates almost line for line into a
  `List<Edge>` with a `next` index into the (pre-sorted) table and a `List<Edge>
  active` that gets filtered each row. The one place I made an implementation
  choice not fully dictated by the pseudocode: I used `active.RemoveAll(e =>
  e.YBottom <= y)` and rebuilt the sorted crossing list from scratch every row with
  LINQ's `OrderBy`, rather than the "keep it sorted, insertion-sort it back into
  order" optimization the prose mentions as optional ("nothing in the scenarios can
  tell"). Confirmed true - the suite doesn't distinguish the two approaches, and
  the prose says as much.
- `transform_path` needed a decision about what happens to a subpath with zero
  points (never actually possible in the current `Path` API, since `MoveTo` always
  seeds one, but I guarded it anyway with `if (sp.Points.Count == 0) continue;` for
  defensiveness). No scenario exercises this, since it can't currently arise.

### Failures

None on the first implementation.

### Prose problems

- None. The trap in §6.1 (the star's two nearly-but-not-quite equal y-values from
  two different trig calls, producing a fifth degenerate edge) is exactly right and
  is exactly why the scenarios don't pin `length(edge_table(star()))` - I checked,
  and they don't; only the rectangle/triangle/complex-path scenarios pin table
  length, all of which have honestly-equal y-values by construction (integer or
  clean-decimal inputs, not two independent `cos`/`sin` calls).

## Mutation results (both chapters, three mutations each)

I mutated the working code, ran the suite, recorded what failed, then reverted and
re-ran to confirm 279/279 before moving on.

**Chapter 5:**

1. **Inclusive-both-ends half-open rule** (`a.Y <= y && y <= b.Y` instead of
   `y < b.Y`, in both `Crossings` and `WindingAt`) - caught: 2 scenarios failed
   ("A ray through a vertex counts it once", "A diamond wound twice has winding
   number 2").
2. **Swapped nonzero/evenodd** in `Filled.Inside` - caught: 4 scenarios failed (1 in
   chapter05-rules, 3 in chapter05-plate, including the byte-exact Plate 5 render).
3. **`line_to` after `close()` starts a bare new subpath** (just `[p]`, dropping the
   "starts where the closed one began" rule) - caught: exactly 1 scenario failed,
   the one written for precisely this ("line_to after a close starts a new subpath
   where the closed one began"). No other scenario noticed, which says this rule
   is thinly tested - if that one scenario were ever deleted, nothing else would
   catch a regression here. (Recommend: also exercise this path through a rendered
   plate somewhere, so the render diff would catch it too. Currently no plate uses
   an open-then-closed-then-continued path.)

**Chapter 6:**

1. **Active edge removed one row late** (`e.YBottom < y` instead of `<= y`) - caught:
   exactly 1 scenario, the one purpose-built for it ("An edge that starts on a
   sample height is active there, and one that ends there is not").
2. **`fill_span` inclusive at the right end** (`last = ceil(x1 - 0.5)` instead of
   `- 1`) - caught hard: 11 of 279 scenarios failed, including both byte-exact
   chapter 6 renders. This is the most over-determined check in the whole
   suite - as it should be, since it's the single most consequential half-open
   boundary in the sweep.
3. **Tolerance instead of exact equality for "is this edge horizontal"**
   (`Math.Abs(a.Y - b.Y) < 0.0001` instead of `a.Y == b.Y`) - **not caught. All
   279 scenarios still passed.** This is the most valuable finding from this
   round. The chapter's own trap section explicitly discusses the star's
   genuinely-near-horizontal edge pair (differing by ~3e-14) and says the
   scenarios deliberately don't pin the star's edge table length "for exactly
   this reason." That's correct and good - but it also means no scenario in
   `features/` currently distinguishes "drop only exact horizontals" from "drop
   anything within 0.0001 of horizontal," because nothing in the suite has an
   edge with a y-difference in the gap between "genuinely degenerate" (~1e-14) and
   "clearly a real edge" (the smallest real slope difference in any test polygon
   is much larger than 0.0001). A reader who "fixes" the exact-equality check
   into a tolerance check - a very natural instinct in floating point code,
   and one this book's own conventions elsewhere (colors, tuples, matrices)
   actively encourage - introduces a real bug (a shallow, real edge gets
   silently dropped and its span disappears or shifts) that nothing here would
   catch. **Concrete fix:** add a polygon with one edge whose two endpoints
   differ in y by something like 0.01 - clearly not the same point, clearly
   meant to be a real (very shallow) edge - and check it still produces a span/
   contributes to the edge table. That would fail under the tolerance mutation
   while still passing under exact equality, closing the gap.

All three chapter 5 mutations and two of three chapter 6 mutations were reverted
and the suite reconfirmed at 279/279 after each one; the tolerance mutation was
also reverted and reconfirmed (it never made the suite fail, so "reverting" was
just restoring the original file, then re-running to be sure nothing else had
drifted).

## Concrete changes I'd make

1. Add a scenario for `side_by_side` with unequal-height inputs (e.g. 2x3 and 4x5),
   the way the canvas feature's asymmetric scenario catches a transposed writer -
   right now the only scenario for it uses two equal-height canvases, so a reader
   who hardcodes one canvas's height for both halves would still pass.
2. Close the horizontal-edge tolerance gap described above with one added polygon
   scenario (a shallow real edge, y-difference ~0.01, not exactly the star's
   near-degenerate case).
3. Exercise `line_to`-after-`close` (chapter 5) through at least one rendered
   plate, not only through the direct `Path` scenario, so a render diff would also
   catch a regression there.
4. A one-line note for C#/Go/similar readers about the `Path` vs. `System.IO.Path`
   (or equivalent) name collision, since it's a compile error a cold reader will
   definitely hit and might spend a confused minute on.

## Timing

Full `dotnet run` (build + all 279 scenarios across 6 chapters + all 19 renders
written to `out/`): consistently 14-19 seconds wall clock on this machine (mostly
JIT/build startup - the actual test run and renders are a small fraction of that;
nothing in chapters 5 or 6 was slow enough to notice by eye, including the star's
64-sample-per-pixel coverage rasterization at 160x160 and the 24-star spiral sweep
at 320x320).
