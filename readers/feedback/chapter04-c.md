# Chapter 4 — reader feedback (C11, clang, on top of the chapters 1–3 code)

## Result

    chapter 1: 62 scenarios, 62 passed, 0 failed
    chapter 2: 35 scenarios, 35 passed, 0 failed
    chapter 3: 37 scenarios, 37 passed, 0 failed
    chapter 4: 72 scenarios, 72 passed, 0 failed

    206 scenarios, 206 passed, 0 failed

All 72 chapter-4 scenarios are translated, none skipped, none weakened. Counts
per feature file: tuples 11, matrices 17, transforms 16, scale 6, shapes 13,
plate 9.

Renders:

| file | max_channel_difference vs `reference/chapter-04/` |
|---|---|
| `out/fan-both-orders.ppm` | **0** (byte-identical, `cmp` agrees) |
| `out/plate-04.ppm` | **0** (byte-identical, `cmp` agrees) |

Chapters 2 and 3's renders are still byte-identical too, after the `thick_line`
refactor. Both new files came out right on the first run, which is unusual and
says the numbers in the chapter are trustworthy.

Also ran the suite under `-fsanitize=address,undefined`: clean.

## Ambiguities

Things the chapter left me to decide. None of them cost me a failing scenario,
but each is a place a reader can differ from you and never find out.

1. **`dot` and `magnitude` on tuples with `w ≠ 0`.** §4.1 defines
   `dot(a, b) = a.x·b.x + a.y·b.y` and `magnitude(v) = sqrt(x² + y²)`, i.e. the
   `w` component is dropped. Every scenario that touches either uses vectors,
   where `w = 0`, so a reader who copies *The Ray Tracer Challenge*'s habit and
   sums all three components passes the entire suite. I implemented the two-
   component version because the prose says so, but nothing enforces it. See
   Mutation results — this is one of only two things I could break without a
   scenario noticing.
2. **`is_invertible` — exact zero, or a tolerance?** The pseudo-code comment
   says "zero means there is no inverse". The book's default float comparison is
   `± 0.0001` everywhere else, so a reader may reasonably write
   `|determinant(m)| > 0.0001`. Both pass. Since `is_invertible` gates the
   collapsed-transform behaviour, and chapter 8 is said to check it before
   dividing, it's worth one sentence.
3. **What `union` does with an empty list**, and whether `outline` accepts fewer
   than two points. I made an empty union report `false` everywhere and never
   exercised either. Chapter 5 will hit this the moment a path is empty.
4. **`side_by_side` when the two canvases differ in size.** "copies `a` into the
   left half of a wider canvas and `b` into the right" doesn't say what the
   result's height is, or what fills the gap. Both callers pass 160×160 so it
   never bites; I used `a.height` and `a.width + b.width`.
5. **`transform_points` on vectors.** The name says points; `fan_points` and
   `letter_f` return points. Nothing says whether it must preserve `w` (my
   `m3_mul_tuple` does, so a vector in the list would stay a vector). Fine, but
   unstated.
6. **`outline`'s `width` is in device space** — the feature file's header says so
   ("every edge a segment of that width in device space") but §4.5's prose
   sentence ("takes the points through `m` and returns the union of the segments
   between consecutive points") doesn't. Given the trap two paragraphs later is
   entirely about which space the pen lives in, the prose sentence should say it
   too. I got it right from the feature header, not the chapter body.
7. **`plate_04`'s ghost.** The pseudo-code is explicit, so no guessing needed —
   but the prose sentence before it ("Draw the ghost once, copy it into two
   canvases") reads as though `side_by_side` might do the copying. The
   pseudo-code settles it. Keep the pseudo-code.

## Hard to translate

C-specific, and all of it my problem rather than yours — but two of the book's
names are actively hostile to C, so they're worth knowing about.

* **`union` is a C keyword.** The shape had to become `union_of`. Any reader in
  C, C++, Rust (`union` is reserved), or Go-ish languages hits this. A one-line
  aside ("if `union` is a keyword in your language, call it `union_of`") would
  save everyone the same five seconds of annoyance and, more usefully, keep the
  name consistent between readers when you diff their code.
* **`minor` is a macro.** `<sys/types.h>` defines `minor(x)` (and `major`)
  outside strict-ANSI mode; anything that includes it poisons the name.
  `-std=c11` happens to suppress it on this machine, but `-std=gnu11` does not,
  and glibc has the same macro. I `#undef` it in the header. Same class of
  problem as `union` — worth an aside next to the cofactor pseudo-code.
* **`A * B` versus `A * p`.** No operator overloading, so both are `mul(a, b)`,
  a `_Generic` macro that dispatches on the type of the second argument. Reads
  fine; `translation(104.5, 76.5) * rotation(π / 6)` becomes
  `mul(translation(104.5, 76.5), rotation(PI / 6))`. Left-associativity of the
  three-factor chains had to be reproduced by hand as `mul(mul(C, B), A)` —
  matrix multiplication is associative so it doesn't matter, but I checked.
* **Data tables.** `Given the following matrix M:` became a `matrix3(...)` call
  laid out over three source lines so the shape survives. `X is the following
  matrix:` became `EQM(X, matrix3(...))`, entry by entry at `± 0.0001`.
* **Lists.** `[point(...), ...]` and `length(pts) = 13` don't exist in C. Every
  list-taking function grew an `int n` the book doesn't mention
  (`outline(pts, n, m, width)`, `union_of(parts, n)`), and `fan_points` /
  `letter_f` fill a caller-supplied array and return the count. That's the count
  the `length(...)` steps check.
* **Composite shapes need heap ownership.** A `struct Shape` can't contain
  itself, and the codebase passes `Shape` by value everywhere, so `union_of`,
  `transformed` and `outline` copy their children onto the heap and there is a
  `shape_free`. This is the one place chapter 4 forced a structural change on
  chapters 1–3's design; the chapter can't help that, but it's the biggest
  single cost of the chapter in a language without a garbage collector, and it
  is worth a sentence in the "In the GUI"-style aside slot: *a shape that
  contains shapes is the first time this book needs a tree.*
* **Performance.** `inside` taking `Shape` by value became a thin wrapper over a
  pointer-taking `inside_p`, because a union of twelve segments at 64 samples a
  pixel over 160×160 would otherwise copy a ~350-byte struct about twenty
  million times. Chapter 3 already had a comment worrying about exactly this;
  chapter 4 makes it real. Renders take ~0.35 s total, so it's not a crisis, but
  a reader who doesn't notice will see a 5–10× slowdown.

## Failures

None. Nothing in chapter 4 failed, and nothing in chapters 1–3 regressed after
`thick_line` was rewritten as `segment(point(x0 + 0.5, y0 + 0.5), ...)`.

## Prose problems

Genuinely few. What I have:

* **§4.5, the `segment` scenario doesn't quite do what the prose claims.** The
  text says "the first scenario below checks that with chapter 3's own numbers".
  It checks three of chapter 3's five probes — `coverage_at(cov, 11, 5)` and
  `coverage_at(cov, 2, 1)` are dropped. Not wrong, but if the point is "this is
  the same test", make it the same test. Cheap, and `(11, 5)` is the far end cap,
  which is where an endpoint that lost its `+ 0.5` would show first.
* **§4.5, "in device space" missing from the `outline` sentence.** See
  Ambiguities 6. The word "device" appears in the feature-file header and in the
  trap, but not in the sentence that introduces `outline`, which is the one a
  reader implements from.
* **§4.4, "It's one line: `sqrt(|m[0,0]·m[1,1] - m[0,1]·m[1,0]|)`."** That is the
  determinant of the *upper-left 2 by 2*, which is what the feature header says.
  §4.2 has just spent a page defining `determinant(M)` as the 3-by-3 cofactor
  expansion. For every matrix in the book the two agree (bottom row `0 0 1`), so
  a reader who writes `sqrt(|determinant(m)|)` passes every scenario — I checked.
  One clause ("the 3-by-3 determinant would do as well, since the bottom row is
  always `0 0 1`") would stop readers wondering whether they've misunderstood.
* **§4.6, "Five rasterizations of a 160-by-160 canvas".** Correct only if you
  count `fan_both_orders`'s two and `f_both_orders`'s three together; the
  sentence sits directly under `plate_04`'s pseudo-code, where the answer is
  three. Say "five across the two renders".
* **§4.6, "each against a union of ten or twelve segments"** — the F outline is
  ten *points*, hence ten segments, which is right; but "ten or twelve" invites
  the reader to think the F has ten edges *because* it has ten corners with one
  edge left open. Given that "an outline that doesn't close" is a mistake a
  reader will make (I broke it deliberately; see below), spelling out "ten
  corners, ten edges, because the last one closes back to the first" would earn
  its place. The feature file's header says "last back to first"; the chapter
  body says it once, in §4.5.
* Everything else checked out numerically: 1.618 for the shear's largest
  singular value, columns of length 1 and 1.414, 30 radians = 278.9° past four
  turns, the fan landing at (52.25, 118.50), the 0.75 corner notch, and the trap's
  "a vertical stroke twice as wide as it should be and a horizontal one half as
  wide" (the scenario shows exactly 2 px and 0.5 px). The §4.3 derivation of the
  rotation matrix from where the unit vectors land is the clearest version of
  that argument I've read.

## Mutation results

Thirty-four deliberately wrong implementations, each rebuilt from a clean copy of
the source and run against the whole suite. **Twenty-nine were caught.** The
catches:

| Wrong implementation | ch4 scenarios failed | first to catch it |
|---|---|---|
| matrix stored/multiplied transposed | 21 | Matrices / A matrix multiplied by a point |
| `A * B` computes `B * A` | 12 | Matrices / Multiplying two matrices |
| sine negated in `rotation` | 13 | The transforms / A positive rotation turns x toward y |
| `point()` builds with `w = 0` | 16 | Points and vectors / A point has w = 1 |
| `rotation` takes degrees | 13 | The transforms / A positive rotation turns x toward y |
| `transformed` stores `m`, not `inverse(m)` | 5 | shapes / A circle seen through a scale is an ellipse |
| `approx_scale` = longest column | 4 | scale / A non-uniform scale is reported as the geometric mean |
| `approx_scale` without the absolute value | 1 | scale / A reflection is not a negative scale |
| `inverse` without the transpose | 6 | Matrices / Calculating the inverse of a matrix |
| cofactor sign never applied | 9 | Matrices / The determinant of a 3 by 3 matrix |
| `minor`'s 2×2 taken in the wrong order | 3 | Matrices / The determinant of a 3 by 3 matrix |
| `cross` terms swapped | 2 | tuples / The cross product of two vectors is a number |
| `shearing` transposed | 2 | The transforms / Shearing moves x in proportion to y |
| `segment` keeps chapter 3's `+ 0.5` | 17 (6 in ch3) | ch3 / Inside a thick line |
| union = intersection | 5 | shapes / A union is inside when any of its parts is |
| union looks only at its first part | 5 | shapes / A union is inside when any of its parts is |
| **outline doesn't close** | 3 | shapes / An outline is one shape, so its corners are painted once |
| outline builds segments in shape space | 1 | shapes / An outline takes its points through the matrix first |
| outline divides width by `approx_scale(m)` | 1 | shapes / An outline takes its points through the matrix first |
| `transformed` asks with `w = 0` | 1 | shapes / The transform is applied in the order the matrix says |
| `letter_f` listed counterclockwise | 4 | Plate 4 / The letter F |
| `fan_points` reversed / radius 72 / cos↔sin swapped | 2–4 | Plate 4 / The fan as points |
| `side_by_side` puts b on the left | 2 | Plate 4 / The fan, both orders |
| ghost drawn with `move` instead of `home` | 1 | Plate 4 / Plate 4 |
| `plate_04` magnifies by 1 | 1 | Plate 4 / Plate 4 |
| `scaling` factors in the last column | 21 | Matrices / The determinant of a transform is the area factor |
| `normalize` sets `w` to 1 | 1 | tuples / Normalizing a vector |

The `w = 0` corners and the transposed-matrix mistakes from Figure 4.5 are both
caught loudly, and `rotation(30)` in degrees is caught by a scalar scenario
before it ever reaches a PPM byte, exactly as §4.6 promises. Good.

**Five passed every scenario.** Two of them are real holes, one is a prose
over-claim, and two are defensible:

1. **`dot` summing all three components.** `dot(a, b) = a.x·b.x + a.y·b.y + a.w·b.w`
   passes 206/206. Every `dot` scenario uses vectors. Fix: add
   `dot(point(1, 2), point(2, 3)) = 8` to "The dot product of two vectors", where
   the two-component answer is 8 and the three-component answer is 9. That one
   line closes it. This matters because chapter 2's half-plane test is a dot
   product (§4.1 says so) and chapter 5 is about to take dot products of things
   built from points.
2. **`magnitude` including `w`.** Same story: `sqrt(x² + y² + w²)` passes 206/206.
   `magnitude(point(3, 4)) = 5` would close it. Lower stakes than `dot`, but
   free.
3. **`transformed` with no `is_invertible` guard at all.** §4.5 explicitly sells
   the guard: "the scenario says so rather than leaving you to find out from a
   division by zero". In C it doesn't work — dividing by a zero determinant gives
   `inf`/`nan`, the transformed query point is `nan`, and every `inside` test
   comes back false, so "A shape seen through a collapsed transform is empty"
   passes *without* the guard. It will do the same in any IEEE-float language
   that doesn't raise (C, C++, Rust, Java, JavaScript, Go, Swift); it will only
   catch readers in Python and Ruby, where the division raises. So the sentence
   is over-claiming for most of your readers. Either say so, or pin something the
   `nan` path can't fake — e.g. `is_invertible(scaling(0, 1)) = false` is already
   in the matrices feature, so the honest fix is just to soften the prose to
   "…so that you get an empty shape rather than an exception or a canvas full of
   `NaN`".
4. **`approx_scale` as `sqrt(|determinant(m)|)`** (full 3×3). Passes 206/206, and
   is genuinely equivalent for every matrix the book builds. Not a bug — but see
   the §4.4 prose note; a reader can't tell from the chapter whether it's meant to
   be equivalent.

5. **`is_invertible` with a `0.0001` tolerance** rather than an exact `!= 0`.
   Passes 206/206, and I don't think it's wrong — but see Ambiguities 2; the
   chapter should pick one.

One more that passes and isn't a bug: `letter_f` listed in the reverse
order *if* you also updated the pinned indices — the closed outline is the same
shape either way, which is fine; the four index scenarios catch the version where
you only reverse the list.

## Concrete changes I'd make

In rough order of value:

1. Add `dot(point(1, 2), point(2, 3)) = 8` (and `magnitude(point(3, 4)) = 5`) to
   `chapter04-tuples.feature`. Two lines; closes the only real hole in the suite.
2. Soften §4.5's claim about the collapsed-transform scenario saving readers from
   a division by zero — in most languages it doesn't, because the `NaN`s answer
   "false" for you. Or add an assertion the `NaN` path can't satisfy.
3. Put "in device space" into §4.5's sentence introducing `outline`, matching the
   feature file's own header.
4. Say in §4.4 that `sqrt(|determinant(m)|)` is the same thing for every matrix
   in the book, so readers who write the 3×3 version know they haven't erred.
5. Restore the two dropped probes to "A segment between pixel centers is a thick
   line" so it really is chapter 3's scenario with real endpoints.
6. One aside on names that collide: `union` (keyword in C, C++, Rust) and `minor`
   (macro in `<sys/types.h>`). Suggest `union_of` so readers' code agrees.
7. Say "ten corners, ten edges, because the last closes back to the first" where
   the F is introduced in §4.6.
8. §4.6: "five rasterizations across the two renders", not five under `plate_04`.
9. Optional, and I'd want it: a scenario for `union_of([])` and for `outline` with
   one or two points. Chapter 5 will meet both.

## Timing

Machine: Apple silicon, clang `-O2`.

* `make render` (all fifteen pictures, chapters 1–4): **0.50 s** wall, repeatable.
* `fan_both_orders()` alone: **156 ms**. `plate_04()` alone: **192 ms**.
* Whole suite (`./bin/tests`, 206 scenarios): **~0.85 s**, of which
  `feature_plate_04` is **370 ms** (it renders both pictures again) and
  `feature_plate_03` is 93 ms. Every non-plate chapter-4 feature is under 1 ms.

The chapter's estimate — "about the same work as chapter 3's fan, so … well under
a second compiled" — is right: chapter 4's two renders together cost about 3.7×
chapter 3's plate, which is what five 160×160 rasterizations against a dozen
segments should cost, and it's still a third of a second.
