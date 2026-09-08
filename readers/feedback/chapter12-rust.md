# Reader feedback — Rust, chapters 11-12

Cold implementation from `chapter-11.html`/`chapter-12.html` and their `features/*.feature`
files alone, on top of the existing chapters 1-10 Rust code. The book's own repository was not
consulted.

## Result

- Chapters 1-10: unchanged, all passing (see Catch-up).
- Chapter 11: 17 scenarios translated (`chapter11-image.feature` 3, `chapter11-sampling.feature`
  4, `chapter11-paint.feature` 3, `chapter11-mip.feature` 3, `chapter11-plate.feature` 4). All
  pass.
- Chapter 12: 13 scenarios translated (`chapter12-clip.feature` 4, `chapter12-mask.feature` 2,
  `chapter12-groups.feature` 3, `chapter12-plate.feature` 4). All pass.
- 30 new scenarios, 0 failing. Full suite: 68 test binaries, 403 `#[test]` functions, 0 failures.
- Renders, `max_channel_difference` against `reference/`:
  - `two-filters.ppm`: 0
  - `plate-11.ppm`: 0
  - `three-filters.ppm`: 0
  - `opacity.ppm`: 0
  - `plate-12.ppm`: 0
  - `clip-demo.ppm`: 0
  All six are byte-for-byte identical to the reference, not merely within the `≤ 1` tolerance the
  scenarios ask for.

## Catch-up

Ran `cargo test --release` for chapters 1-10 before touching anything new: all green, nothing
newly broken. No catch-up fixes were needed.

## Ambiguities

- `sample_nearest`/`sample_bilinear`/`sample_bicubic` are called in `chapter11-sampling.feature`
  as `sample_nearest(img, sx, sy)` — only three arguments, no extend mode — while §11.3's
  `image_paint(img, m, filter, extend)` takes filter and extend explicitly. The chapter never
  says what extend mode the bare three-argument samplers use. Every sample point in that feature
  file happens to need extension only for bicubic's 4x4 neighbourhood, and clamp, repeat and
  reflect all agree at those specific offsets from the 2x2 test image, so the ambiguity is
  invisible to the pinned numbers. I implemented the three public samplers with a fixed `"clamp"`
  extend and a separate `filter`+`extend`-taking pair of private helpers that `image_paint` calls
  directly — a reasonable reading, but the chapter should say so.
- `image_texel(img, 0, 0)` is called with only two integer arguments in one line of
  `chapter11-image.feature` ("A PPM reads back into the image it was written from"), while every
  other call in the same file passes a third `extend` argument. Since Rust has no default
  parameters, I passed `"clamp"` explicitly at that call site — harmless here (the coordinates
  are in-bounds) but worth being explicit about in the chapter text, the same way §11.2 already
  is explicit about the samplers.
- `clip_demo()` (§12.4) has no pseudocode and no JS figure source anywhere in the chapter — see
  Prose problems below.

## Hard to translate

- Chapter 12's pseudocode for `pop_group_with_opacity` writes `composite(src-over, faded, base)`
  as if `composite` (chapter 9's single-pixel Porter-Duff function) operated on whole layers.
  The book already has a layer-wide sibling, `composite_layers`, from chapter 9 — I used that
  directly. A reader who translates the pseudocode literally, pixel by pixel through `composite`,
  gets the identical answer either way, so this isn't a bug, just an imprecision in how the
  pseudocode names things.
- `clip_demo()`: translating this took real effort disproportionate to its two lines of prose.
  With no pseudocode, no JS, and only one pinned pixel plus the overall `≤ 1` diff budget, pinning
  the star's placement and the two clip radii meant reverse-engineering five free numbers
  (star centre, star radius, circle centre, circle radius, mask radius) from the reference PPM
  itself. What worked: dumping the star's own antialiased coverage from the existing `fill_path`
  machinery, sub-pixel edge-detecting the reference image's boundaries in Python, algebraically
  solving for the star's apex from its two edge slopes (which matched chapter 5's `star()` angles
  exactly once I noticed a first attempt was polluted by a header-parsing bug — see below — and
  then a small joint numerical optimization in Rust, coordinate-descent over the remaining
  parameters, converged to exact round numbers: star centred on the panel at radius 60, circle
  radius 45, mask radius 70, all sharing the panel's own centre. `max_channel_difference` hit
  exactly 0 once those numbers were found, which is the only reason I trust them rather than a
  merely-close approximation. Chapter 7's `soft_square`/`star_exact` set the precedent that this
  kind of reverse-engineering is in scope for a reader, but it is genuinely the most time-consuming
  part of this round — see Timing.
- Self-inflicted detour: my first few attempts at fitting `clip_demo()`'s parameters compared raw
  `canvas_to_p6` output directly by byte index, forgetting that `canvas_to_p6` prepends a
  `"P6\n{w} {h}\n255\n"` text header before the pixel bytes. That shifted every comparison by 15
  bytes (5 pixels) and produced a large, confusing, but *fittable* residual error (an optimizer
  will happily shift a circle's centre by 5 pixels to paper over an indexing bug), which cost real
  time to notice. Once I switched to the existing `ppm_pixel` helper (which already accounts for
  the header) for both sides of every comparison, the fit converged to exact integers immediately.
  Not a chapter problem — a reminder that a reader's own tooling can be the bug — but worth stating
  since it's exactly the kind of self-inflicted wound the book's "probe a clamp somewhere the
  placement matters" philosophy is meant to catch on the *renderer's* side too.

## Failures

None. Every translated scenario passes; every render diffs 0 against the reference.

## Prose problems

- §12.4: `clip_demo()` is the only named render across chapters 11 and 12 (indeed, seemingly the
  only one in the book since chapter 7) that ships with neither pseudocode nor a JS figure source
  a reader can read the actual numbers from. `two_filters`/`three_filters`/`plate_11` (§11.5) and
  `per_child`/`group_opacity`/`opacity_plate`/`plate_12` (§12.4 itself, just above `clip_demo`) all
  have explicit pseudocode or literal JS. `clip_demo` gets one sentence ("clips a star to a circle
  and to a soft radial mask") and one pinned pixel. Per this project's own rule that "numbers
  quoted in prose... come from the reference, never from memory or a calculator," and the
  precedent set by chapter 7's similarly-unspecified renders, I'd recommend either (a) printing
  the same kind of short pseudocode the other three renders in this pair of chapters get — it's
  three lines: place `unit_star()` at the panel centre with `scaling(60, 60)`, clip the left half
  with a circle of radius 45, mask the right half with `soft_mask` of radius 70 — or (b) at
  minimum, pin one more pixel on the *left* (hard-clip) half; right now every pinned pixel for
  this render is in the right (soft-mask) half, so a reader whose hard clip is subtly wrong (a
  different radius, a different `n` in `circle_path`) could still pass every scenario and only be
  caught by the aggregate `≤ 1` diff budget over the whole 300x150 image, which is a much blunter
  instrument than an explicit pixel.
- §11.2: as noted in Ambiguities, the chapter should say what extend mode `sample_nearest`/
  `sample_bilinear`/`sample_bicubic` use when called without one, since every other extend-taking
  function in this chapter and chapter 10 takes it explicitly and this one silently doesn't.
- §11.4 ("Why premultiplied, again"): the prose explicitly says the difference between straight
  and premultiplied averaging "makes no visible difference" for this chapter's opaque photos and
  matters "the first time you resample a cut-out with a soft edge" — but no scenario in
  `chapter11-mip.feature` or anywhere else in chapters 11-12 ever constructs an image with
  partial alpha. See Mutation results: the exact bug the prose warns about survives every test in
  the chapter.

## Mutation results

Six deliberate bugs, one at a time, tested, then reverted:

1. **Dropped the half-pixel offset** in `bilinear_at` (used `sx, sy` directly instead of
   `sx - 0.5, sy - 0.5`). Caught immediately by "The identity transform is bit-exact under every
   filter" (`chapter11-paint.feature`) — bilinear through the identity no longer reproduces the
   source exactly.
2. **Sampled through `m` instead of `inverse(m)`** in `image_paint`. Caught by both "The transform
   places the image, and the inverse finds the texel" and "A doubled image samples the same texel
   across two device pixels" (`chapter11-paint.feature`).
3. **Wrong Catmull-Rom weights** (dropped the two linear `-0.5t`/`+0.5t` terms, keeping the cubic
   and quadratic ones). Caught directly by "The Catmull-Rom weights sum to one and pass through
   the samples" (`chapter11-sampling.feature`) and, independently, by "Three filters, adding
   bicubic" (`chapter11-plate.feature`) against its reference image.
4. **`multiply_coverage` using `max` instead of a product.** Caught immediately and hard: 3 of the
   4 scenarios in `chapter12-clip.feature` failed (multiplying 0.5 and 0.25 no longer gives 0.25;
   clipping to the whole canvas is still a no-op by coincidence, since `max(x, 1) = 1`, but every
   other scenario broke).
5. **A hard 0/1 step in `soft_mask`** instead of the linear falloff (`if d < r { 1.0 } else
   { 0.0 }`). Caught by both scenarios in `chapter12-mask.feature` — the pinned fractional values
   (0.8586, 0.0945) are no longer 1 or 0 under the correct implementation, so a step function
   fails immediately.
6. **Group opacity applied per child instead of once at pop time**, mutating the render function
   `group_opacity()` itself to call `paint_into(..., 0.5)` for each circle and
   `pop_group_with_opacity(..., 1.0)` at the end, rather than the reverse. This was **not** caught
   by `groups.rs` (`chapter12-groups.feature`), because that file exercises `paint_into`/
   `push_group`/`pop_group_with_opacity` directly against hand-built shapes and never calls
   `group_opacity()` — the primitives themselves were untouched by this mutation. It **was**
   caught hard by every scenario in `plate_12.rs` (`chapter12-plate.feature`): the render becomes
   visually identical to `per_child()` at the overlaps, which is exactly the picture the plate
   exists to show is *wrong*, so all three pixel/reference checks failed.

One mutation **survived every test in the suite** (chapters 1-12, 403 assertions, 0 failures):

7. **Unpremultiplying before averaging in `downsample`** — divide each texel's premultiplied
   colour by its own alpha, average the four straight colours and the four alphas separately, then
   remultiply the averaged colour by the averaged alpha, instead of averaging the premultiplied
   channels directly. This is precisely the bug chapter 9 spends a paragraph warning about and
   chapter 11's "Why premultiplied, again" callout repeats. It has no effect whatsoever here
   because every `Image` in every scenario — the 2x2 fixture, the 8x8 sprite — is fully opaque
   (alpha exactly 1 at every texel), and dividing/multiplying by 1 is the identity. See Prose
   problems and Concrete changes.

## Concrete changes

1. **Add a partially-transparent image scenario to `chapter11-mip.feature`.** A 2x2 image with at
   least one texel at, say, alpha 0.5 (or 0), downsampled, with the resulting texel pinned. This
   is exactly the kind of test this project's own conventions call for ("a scenario must be able
   to fail on the mistake it exists for") — right now the premultiplied-averaging mistake the
   chapter explicitly names has no scenario that can catch it.
2. **Give `clip_demo()` explicit pseudocode** in §12.4, matching the standard `two_filters`/
   `three_filters`/`per_child`/`group_opacity` already hold themselves to in the same two
   chapters. Three lines would do it (see Prose problems).
3. **State the default extend mode** for `sample_nearest`/`sample_bilinear`/`sample_bicubic` in
   §11.2 prose, or add an explicit fourth argument to those scenario calls if the intent is that
   readers always pass one.
4. **Pin at least one pixel on the hard-clip half** of `clip_demo()` (currently all three pinned
   pixels for that render sit in the soft-mask half), so a wrong circle radius or a wrong
   `circle_path` segment count has a scenario narrower than the whole-image `≤ 1` budget to fail
   on.

## Timing

Roughly two and a half focused hours. Chapters 11's API and renders (images, samplers, mip chain,
`two_filters`/`three_filters`/`plate_11`) came together quickly and matched the reference exactly
on the first real attempt, maybe forty minutes including test-writing. Chapter 12's clip/mask/group
primitives were similarly fast, another thirty minutes. Essentially all of the remaining time — well
over half the round — went into reverse-engineering `clip_demo()`'s five geometric parameters from
the reference PPM alone, including the detour caused by my own PPM-header indexing bug (see Hard to
translate). Mutation testing for both chapters took about twenty minutes total.
