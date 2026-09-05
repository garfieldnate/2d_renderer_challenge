# Chapter 3 feedback

## Ambiguities

- **Pseudocode's range notation is inclusive on both ends, not Rust's half-open `..`.**
  `for x in x0..x1` in `line_bresenham` clearly means `x0..=x1` (a line from
  (0,0) to (5,5) needs both endpoints lit, and the scenarios confirm it). But
  the same convention shows up less obviously in `ray_ends`
  (`for k in 0..11` producing *twelve* points, not eleven) and in `plate_03`
  (`for y in 0..159` meaning all 160 rows). I only trusted this after
  cross-checking against `ray_ends()`'s expected output in
  chapter03-plate.feature — nothing in the prose flags that the book's
  pseudocode range syntax differs from Rust's. Worth a one-line footnote
  the first time a range appears in pseudocode, the way the chapter already
  footnotes "integer division" for `err ← dx / 2`.

- **`thick_line`'s `width` parameter's type.** Every call site in the
  features passes `1` (an integer literal in Gherkin), but the shape is
  built from real-valued half-plane offsets (`h = width / 2`), and a future
  chapter presumably wants fractional widths. I typed it `f64`. Never
  contradicted by a test, just unstated.

- **The double assertion in "Except that the grid is blind along the
  diagonal"**:
  ```
  Then  ink(cov) = 9.7188
  And   ink(cov) = 9.8995 ± 0.25
  ```
  These aren't two independent claims — 9.8995 is the *true* geometric
  length (7√2), and the second line is a loose sanity bound that the first,
  exact, discretized value already satisfies. Read in isolation it looks
  like a contradiction (or like the test author forgot to delete one line
  after tightening the other). I implemented both literally; both pass
  because they're consistent, but the scenario would be clearer as one
  assertion plus a comment explaining what the ±0.25 is checking.

- **`plot`'s "skips a weight of zero."** I read this as "skip if `weight <=
  0.0`", covering the (never-exercised) negative case defensively as well
  as the documented zero case. Doesn't change any test outcome since Wu
  weights here are always in `[0, 1]`.

## Hard to translate

- **Extending `Shape` without breaking `Copy`.** The chapter says "your
  `inside` from chapter 2 grows one case," which invites adding a variant
  that holds a list of sub-shapes to AND together. But `Shape` currently
  derives `Copy`, and existing code depends on that: `inside(s: Shape, ...)`
  takes `Shape` by value and every existing test/figure (e.g.
  `tests/shapes.rs`, `plate_02()`) calls it on the same shape more than
  once without cloning. A `Vec<Shape>` or `Box<Shape>` field would force
  removing `Copy`, which would silently break all of that existing,
  already-passing code. A recursive `[Shape; 4]` field isn't legal Rust
  either (unboxed self-reference, infinite size). I settled for storing the
  four half-planes as raw `(px, py, nx, ny)` tuples in a fixed
  `[(f64,f64,f64,f64); 4]` array — `Shape` stays `Copy`, and the actual
  point-in-half-plane math is still shared via one `half_plane_inside`
  helper used by both the `HalfPlane` and `Intersection` arms. This is a
  Rust-specific translation problem the book's language-agnostic pseudocode
  doesn't have to think about.

- **Pseudocode inclusive ranges** (see Ambiguities) made every `for` loop a
  small trap: translating `x0..x1` to Rust's `x0..x1` instead of `x0..=x1`
  would silently drop the last column/row/ray and every scenario would be
  off by exactly one element at the end — an easy, quiet mistake to ship.

## Failures

None. Every chapter 3 scenario passed on the first implementation attempt.
Both `fan_coverage()` and `plate_03()` matched their reference PPMs
byte-for-byte (`cmp` reports them identical, not merely within the ±1
tolerance the scenarios themselves allow). Nothing to attribute to the book
or to this implementation here — I looked hard for a discrepancy given the
task's instructions and didn't find one.

## Mistakes that stay green

I hand-injected the seven bugs the task asked about, one at a time, and ran
the suite:

| Mistake | Caught? | Detail |
|---|---|---|
| Bresenham `err ← 0` instead of `dx / 2` | **Yes, hard** | 4/9 bresenham scenarios fail (shallow, steep, up-right, exact-half). |
| Steep swap forgotten (Bresenham) | **Barely** | Only 1/9 direct scenarios fails (the dedicated steep-line one). `bresenhams_fan`'s five spot-checked pixels all happen to avoid the corrupted region and **passes**. Only `plate_3`'s full-image reference comparison catches it in the fan/plate tests. If that scenario or the reference-image check didn't exist, this ships. |
| Wu weights swapped (`f` / `1-f` reversed) | **Yes, hard** | 5/10 wu scenarios + `wus_fan` + `plate_3` all fail. |
| Wu `round` instead of `floor` | **Yes, hard** | Same shape as above: 5/10 wu scenarios + `wus_fan` + `plate_3` fail. |
| `thick_line` half-planes facing outward | **Yes, total** | All 7 quad scenarios fail (the "rectangle" becomes everywhere-but-itself). |
| `thick_line` built from pixel corners, not centers | **Partially — a real gap** | Only 2/7 quad scenarios fail (`inside_a_thick_line`, and the horizontal-line half-pixel-ends scenario). The angle-invariance outline (4 rows, "ink = 10 whatever the angle") and the diagonal-blindness scenario **all stay green**, because translating both endpoints by the same half-pixel offset preserves segment length, and those scenarios only check aggregate `ink`, never a specific coverage value at an angle. A reader who only ran (or only trusted) the outline scenarios would ship a rectangle sitting half a pixel off from every line it's supposed to trace, and not know it — only the fan/plate full-image comparisons catch it. |
| `lit_pixels` in column-major order | **Barely — a real gap** | Exactly 1/9 bresenham scenarios fails (`a_line_going_up_and_to_the_right`, the only one where x increases while y *decreases*, so row-major and column-major orderings diverge). All 9 other bresenham scenarios and both Wu scenarios that call `lit_pixels` (diagonal, and single-row horizontal) are blind to it, because in each of those x and y move together or one is constant, so the two orderings coincide by accident. The reference-image comparisons don't help either — they check color per pixel, not order. This is the thinnest needle in the set: one incidental scenario is the entire safety net. |

The two "real gap" rows are worth the author's attention: they're not
hypothetical — I verified each in this exact codebase, with this exact
test suite, by literally introducing the bug and watching a large majority
of the chapter's own scenarios pass anyway.

## Prose

- The chapter's three-act structure (Bresenham: fast but flickers → Wu:
  smooth but loses up to 18% of the paint on a slant → thick_line: correct
  ink, but slow) is genuinely well-built pedagogy, better than most
  textbook treatments of the same material, and "the way out isn't a
  faster line algorithm" lands well as the chapter's actual thesis.
- "It's beautiful, and you should write it once" (about Bresenham) is a
  nice, honest aside — it tells the reader not to expect to reuse this
  code past this chapter, which chapter 4's "and by then you won't be
  using this function" for Wu later confirms.
- The double-assertion oddity in chapter03-quad.feature (see Ambiguities)
  is the one spot where I had to stop and re-read twice.
- `lit_pixels(c)`'s claim that "it's three lines" underplays it a little in
  Rust (mine is a nested loop plus a filter and a push — more like eight),
  but that's a language artifact, not a prose problem.
- The "It's slow… twenty seconds for one picture" aside about
  `fan_coverage` is a nice concrete number, and it's satisfying that the
  compiled Rust version of the exact same brute-force algorithm runs the
  whole chapter's test suite in well under a second — a real, measured
  demonstration of the chapter's own point about interpreted vs. compiled,
  and special-purpose vs. general.

## Would change

- Split the double `ink(cov) = ...` assertion in "Except that the grid is
  blind along the diagonal" into one exact assertion, with a prose comment
  explaining what the true geometric length is, rather than two assertions
  that read as contradictory until worked out by hand.
- Add a scenario that pins `lit_pixels`' ordering directly (write a
  handful of pixels out of raster order, assert the returned list is
  sorted top-to-bottom/left-to-right) rather than leaving that contract to
  fall out of one line-drawing scenario incidentally. Right now a
  column-major implementation of `lit_pixels` survives 8 of 9 Bresenham
  scenarios and both Wu scenarios that touch it.
- Add one `thick_line` scenario that checks a specific `coverage_at(...)`
  value on a diagonal case (the way the horizontal case already does),
  instead of only checking aggregate `ink`. As shown above, a systematic
  half-pixel translation of the whole rectangle currently survives every
  outline row and the diagonal-blindness scenario.
- State explicitly, even in one clause, that the book's pseudocode ranges
  are inclusive on both ends — it's consistent throughout the chapter, but
  it's the kind of thing a reader coming from Rust/Python/JS will get
  wrong on the first read of `line_bresenham` and only notice via a failing
  test.

## Results

- **Chapter 1:** 59 tests, 59 passed, 0 failed.
- **Chapter 2:** 28 tests, 28 passed, 0 failed.
- **Chapter 3 (new this session):** 31 tests, 31 passed, 0 failed.
  - `tests/bresenham.rs`: 9
  - `tests/wu.rs`: 10 (6 scenarios + a 4-row outline)
  - `tests/quad.rs`: 7 (3 scenarios + a 4-row outline)
  - `tests/plate_03.rs`: 5
- **Total: 118 tests, 118 passed, 0 failed.**
- `cargo test --release`: ~0.2s for the full suite (chapters 1-3).
- `cargo run --release --bin render_all`: ~0.2s, writes 13 files to `out/`
  (9 from chapters 1-2, plus `fan-bresenham.ppm`, `fan-wu.ppm`,
  `fan-coverage.ppm`, `plate-03.ppm`). `fan-coverage.ppm` and
  `plate-03.ppm` are byte-identical to `reference/chapter-03/*.ppm`.
- No time hotspot worth naming — even `fan_coverage()`'s twelve
  160×160-canvas, 64-samples-per-pixel rasterizations (the chapter's own
  called-out slow path) are invisible in release-mode wall clock time at
  this canvas size.
