# Chapter 4 reader feedback — Swift

Implemented cold, from `chapter-04.html` and `features/chapter04-*.feature`
alone, on top of the existing chapters 1–3 Swift code. Language: Swift 6
toolchain, Swift 5 language mode, plain `swiftc` (no SwiftPM).

## Result

All scenarios pass, chapters 1–4, no weakened tolerances, nothing skipped.

| Feature file | Scenarios | Pass | Fail |
|---|---|---|---|
| chapter04-tuples.feature | 11 | 11 | 0 |
| chapter04-matrices.feature | 17 | 17 | 0 |
| chapter04-transforms.feature | 16 | 16 | 0 |
| chapter04-scale.feature | 6 | 6 | 0 |
| chapter04-shapes.feature | 13 | 13 | 0 |
| chapter04-plate.feature | 9 | 9 | 0 |
| **Chapter 4 total** | **72** | **72** | **0** |

Whole-suite total: chapter 1 = 66, chapter 2 = 35, chapter 3 = 37, chapter 4
= 72 → **210 scenarios, 210 passed, 0 failed**. Chapters 1–3 were re-run
after the `thick_line`/`segment` refactor and are unaffected: all ten
pre-existing renders (`out/*.ppm` for chapters 1–3) stay byte-identical to
`reference/`.

Renders, diffed against `reference/chapter-04/` with `max_channel_difference`:

- `out/fan-both-orders.ppm` vs `reference/chapter-04/fan-both-orders.ppm`:
  **byte-identical, max_channel_difference = 0**.
- `out/plate-04.ppm` vs `reference/chapter-04/plate-04.ppm`:
  **byte-identical, max_channel_difference = 0**.

No discrepancy to investigate — both renders matched exactly on the first
correct implementation, which is a good sign for the chapter's pseudocode:
it was precise enough that "read it, translate it literally" produced
pixel-for-pixel identical output, no fudging.

## Ambiguities

- **The Gherkin data-table steps aren't machine-parsed by this runner.**
  `run_features.py`-style scenarios ("Given the following matrix M: | 1 | 2
  | 3 | ...") were translated by hand into `matrix3(1, 2, 3, ...)` calls, per
  the chapter's own note ("each table is a call to `matrix3`"). This is
  explicitly sanctioned by the prose, so not really an ambiguity, but it's
  worth the author double-checking that every translated table matches its
  source row order — a transcription slip here would be invisible to any
  syntax check.
- **`is_invertible`'s tolerance.** The chapter's pseudocode says "zero means
  there is no inverse" with no epsilon mentioned. I implemented
  `isInvertible(m) = determinant(m) != 0` (exact equality), not
  `!equal(determinant(m), 0)`. For every scenario in this chapter the inputs
  are small integers or well-conditioned transforms, so it never mattered,
  but a reader building `is_invertible` for use elsewhere (e.g. after a
  chain of floating-point transform multiplications) will eventually hit a
  determinant that's `1e-15` instead of exactly `0` and get a different
  answer depending on which rule they picked. Chapter 8's `approx_scale`
  divide-by-zero guard (mentioned in §4.4's closing line) is exactly the
  place this will bite; worth the chapter saying explicitly "zero means
  exactly zero, not epsilon-zero" so two readers don't diverge.
- **`copyCanvas` / "a copy of ghost".** The pseudocode for `f_both_orders()`
  says `a ← a copy of ghost` without defining what a canvas copy is. I
  implemented a plain pixel-for-pixel copy (new canvas, same dimensions,
  `writePixel` from the source at every coordinate) since nothing else makes
  sense for a "canvas of colors," but this is a place where the chapter
  leans on the reader's judgment for a helper that has no scenario of its
  own. Not a real ambiguity in practice (there's only one sane reading) but
  it's the one function in this chapter with no test pinning it directly —
  it's only exercised indirectly through the two Plate 4 scenarios.

## Hard to translate

Nothing was hard to translate. The tuple/matrix arithmetic mapped onto
Swift operator overloads (`+`, `-`, prefix `-`, `*`, `/`) exactly the way
chapters 1's `Color` arithmetic already had, so there was an existing
pattern to follow. The one new piece of Swift machinery was a custom
`subscript(_ r: Int, _ c: Int)` on `Matrix3` to get `M[r, c]` reading
exactly like the book's notation — trivial, but worth flagging that a
language without operator/subscript overloading (nothing in this book's
language list lacks it, but hypothetically) would need `matrixAt(M, r, c)`
instead, same as `pixelAt`/`coverageAt` elsewhere in this codebase.

## Failures

None. Every scenario passed on the first implementation that matched the
chapter's stated formulas literally (cofactor-expansion determinant/inverse,
the four transform matrices exactly as printed, `approx_scale` as
`sqrt(|det|)` of the upper-left 2×2).

## Prose problems

- §4.4, "The largest stretch" paragraph: minor, but the closed-form
  largest-singular-value formula is described as "six lines... the square
  root of the larger eigenvalue of `m` times its own transpose" without
  giving the actual six lines, unlike every other candidate in that section
  which gets a one-line formula. Since the book explicitly doesn't ask the
  reader to implement it, this is fine as scoped, but a reader who wants to
  swap it in later (as the chapter invites, "swap the body of
  `approx_scale`... and nothing else in the book changes") has nothing to
  copy from and has to derive it themselves. A one-line closed form in a
  footnote or `.trap` aside would close that gap without adding a scenario
  for a formula the book doesn't use.
- §4.3, "Rotation" — this is well done, not a problem, but worth confirming
  it lands: the chapter says the convention twice (once at "positive angle
  turns x toward y," once in the trap-adjacent callout about "if your F
  leans the other way"), and the plate scenario's numeric checks (`f[0] =
  point(102.1795, 40.5192)` etc.) genuinely do fail if the sine is negated,
  as the mutation testing below confirms. No note needed — this is the
  chapter doing exactly what CLAUDE.md's "iron rule" asks for.
- §4.2 pseudocode for `inverse(M)`: the comment "note [c, r]: the transpose
  happens here" is exactly the kind of detail that saves a reader an hour,
  and it's the one line I re-read twice while implementing to make sure my
  `cells[c * 3 + r] = cofactor(m, r, c) / d` matched the transpose direction.
  It matched. No change needed, just noting it worked as intended.
- Everywhere: no instance of "simply," "just," "obviously," "trivially," "of
  course," "clearly," or "we" (meaning "you") found by scanning the rendered
  text of chapter-04.html. Voice guideline held.

## Mutation results

Six plausible reader mistakes were introduced one at a time as one-line
edits to `Sources/Renderer.swift`, built, tested, and reverted (confirmed
byte-identical to the pre-mutation file via `diff` after each revert):

| # | Mutation | Scenarios failed |
|---|---|---|
| 1 | Matrix stored/read transposed (matrix×tuple reads columns instead of rows) | 21 (matrix, transform, and Plate 4 scenarios) |
| 2 | Sine negated in `rotation` | 13 (rotation, chained-transform, and Plate 4 scenarios) |
| 3 | `approx_scale` defined as the longest column length instead of `sqrt(\|det\|)` | 4, including the shapes-feature "Under a non-uniform scale the compromise shows" scenario — confirms that scenario pins the *actual compromise value*, not just unit-tests the formula in isolation |
| 4 | `transformed` applies `m` instead of `inverse(m)` | 5 (all the "seen through a transform" inside/ellipse/pen scenarios) |
| 5 | `outline` doesn't close (drops the last-point-back-to-first edge) | 3, including the Plate 4 render itself |
| 6 | `letter_f` built from `vector(...)` instead of `point(...)` (w = 0) | 5, including the Plate 4 render itself |

A seventh, more marginal case: rewriting `rotation(Double.pi / 6)` as
`rotation(30)` (degrees read as radians) **inside `fan_both_orders()` and
`f_both_orders()` specifically** (not in the standalone transform tests,
which build their own matrices) was caught by only 2 scenarios — "The fan,
both orders" and "Plate 4" — both of which are the two slowest scenarios in
the suite (~300–390 ms each). Every other numeric transform scenario builds
`rotation(Double.pi / 6)` inline and so doesn't exercise this particular
call site. This isn't a gap — the mistake is caught, correctly, with actual
vs. expected values (the numeric `pts[...]`/`f[...]` checks aren't present
for this specific call site, only the final pixel checks) — but it means a
reader who makes this exact mistake only inside the render helper gets
their answer from the two most expensive scenarios in the suite rather
than a cheap unit one. Not worth a new scenario on its own (the mistake
*is* caught), just noting it for completeness since the task asked
specifically about degrees-for-radians.

No wrong implementation was found that passed every scenario — every
mutation tried failed at least one, several failed a dozen or more. This
chapter's scenario set is thorough.

## Concrete changes you'd make

1. (Optional, low priority) Add one line to §4.4 stating explicitly that
   `is_invertible` compares the determinant to exactly zero, not within a
   tolerance, so two readers building on it later (chapter 8's flattening
   guard) don't diverge on ill-conditioned matrices. See "Ambiguities" above.
2. (Optional, very low priority) Give the six-line closed form for the
   largest singular value in §4.4, even though the book doesn't use it,
   since the chapter explicitly invites swapping it in later and currently
   gives a reader nothing to copy.
3. No changes to any scenario — the six deliberate mutations above were all
   caught, several by more than one scenario, and the render scenarios
   matched the reference exactly on the first correct implementation.

## Timing

- Full suite (`./run`, chapters 1–4, 210 scenarios): **1.306s** wall,
  built with `-O`.
- Slowest individual scenarios: Plate 4 (`plate_04()`, 640×320 after 2x
  magnify) at 387.6 ms, chapter 1's Plate 1 at 298.9 ms, "The fan, both
  orders" (`fan_both_orders()`, 320×160) at 294.6 ms.
- `./run render` (writes all `out/*.ppm` for chapters 1–4): **~0.83s**
  wall total.
  - `fan_coverage()` (chapter 3, twelve 160×160 rasterizations at 64
    samples/pixel): 0.087s standalone.
  - `fan_both_orders() + plate_04()` (chapter 4, five 160×160
    rasterizations at 64 samples/pixel between them — two for the fan,
    three for the F): 0.652s standalone, timed together as one block in
    `main.swift` the same way chapter 3 times `fan_coverage()` alone.
  - `plate_04()` is the more expensive of the two (it's `f_both_orders()`
    magnified 2x, i.e. three 160×160 rasterizations plus the upscale to
    640×320), consistent with it being the single slowest scenario in the
    suite.
