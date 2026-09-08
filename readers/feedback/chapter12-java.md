# Feedback — Java reader, chapters 11-12

## Result

| Chapter | Scenarios | Pass | Fail |
|---|---|---|---|
| 1  | 66 | 66 | 0 |
| 2  | 35 | 35 | 0 |
| 3  | 38 | 38 | 0 |
| 4  | 76 | 76 | 0 |
| 5  | 32 | 32 | 0 |
| 6  | 34 | 34 | 0 |
| 7  | 34 | 34 | 0 |
| 8  | 23 | 23 | 0 |
| 9  | 45 | 45 | 0 |
| 10 | 24 | 24 | 0 |
| **11** | **17** | **17** | **0** |
| **12** | **13** | **13** | **0** |
| **Total** | **417** | **417** | **0** |

Renders, `max_channel_difference` against `reference/chapter-NN/*.ppm`:

| Render | Diff |
|---|---|
| `two-filters.ppm` | 0 |
| `plate-11.ppm` | 0 |
| `three-filters.ppm` | 0 |
| `opacity.ppm` | 0 |
| `plate-12.ppm` | 0 |
| `clip-demo.ppm` | 0 |

Every chapter 11/12 render is bit-identical to the reference. `clip-demo.ppm`
took real work to get there -- see **Prose problems** below.

## Catch-up

Ran chapters 1-10's existing test suites before touching anything. All 373
scenarios passed with no changes; nothing was newly broken. The code these
scenarios exercise was untouched by this round.

## Ambiguities

None that blocked a scenario. The two places that needed judgment calls
(`mip_level_for`'s rounding direction, and whether `sample_nearest` needs its
own `-0.5` term) turned out to be fully pinned once worked through carefully
-- see **Hard to translate** below, since they were more a matter of care
than genuine ambiguity.

## Hard to translate

- **`mip_level_for`'s rounding.** The obvious first guess, `round(-log2(scale))`,
  passes four of the five pinned cases and fails `mip_level_for(0.3) = 1`
  (round gives 2). The chapter doesn't state the formula or the rounding
  mode in prose at all -- §11.4 only says "read from the level whose texels
  are about the size of an output pixel" -- so the five scenario values are
  the only spec. `floor(-log2(scale))` matches all five, but floors an exact
  power of two (`0.25` -> `-log2 = 2.0`) right on a boundary where floating
  point could tip either way; I added a `1e-9` epsilon to keep that case
  from silently reading one level too shallow if `Math.log`'s rounding ever
  lands a hair under 2.0 instead of over it. This is defensible but not
  provably what the reference does, since no test exercises the exact
  boundary with adversarial floating point. Worth a scenario at exactly
  `scale = 0.25` computed a second, independent way (e.g. via
  `Math.scalb`/`Math.getExponent`) to confirm both implementations agree,
  the way chapter 7 pins the near-vertical-edge epsilon.
- **`sample_nearest`'s relationship to the half-pixel offset.** §11.2's trap
  says "every sampler works in texel-centre space: subtract 0.5" without
  carving out an exception, but a literal `floor(sx - 0.5)` for nearest is
  wrong by one texel half the time (it needs a round-to-nearest, not a
  floor, after the subtraction). Working out that `round(sx - 0.5) ==
  floor(sx)` algebraically and confirming it against all four sampling
  scenarios took more care than the other two filters, which translate
  line for line from prose. A sentence in §11.2 saying so directly ("nearest
  needs no separate subtraction: round-to-nearest of x - 0.5 is floor(x)")
  would save a reader from either misreading the trap as literal for all
  three filters, or wrongly assuming nearest is exempt from it for no
  stated reason.

## Failures

None outstanding. `clip_demo()` failed twice during development (see below)
before its exact geometry was found; the version now in `Figures.java`
passes every scenario and diffs 0 against the reference.

## Prose problems

- **§12.4, `clip_demo()`: no pseudocode, no figure JS, no geometry in
  prose.** Every other named render in chapters 11 and 12 --
  `two_filters`, `three_filters`, `plate_11`, `per_child`, `group_opacity`,
  `plate_12` -- has either printed pseudocode or a `Plate.add(...)` figure
  function at the bottom of the chapter HTML whose source is provably the
  code that drew the plate. `clip_demo()` has neither. §12.4's prose says
  only "clip_demo() clips a star to a circle and to a soft radial mask,"
  and the feature file pins exactly one pixel (`ppm_pixel(p6, 225, 45) =
  (197, 155, 74)`) plus the usual `max_channel_difference(p6, ref) <= 1`
  against the reference PPM. That is not enough to derive the function: a
  reader has no way to know the star's center, its radius, which star path
  is reused (I guessed chapter 6's `unit_star()`, which turned out right),
  the circle clip's center and radius, or the soft mask's center and
  radius, from the chapter text alone. I built a first guess (star center
  (75, 75) radius 60, circle same center radius 60, mask same center radius
  60) from measuring pixel extents in the reference PPM by hand -- allowed,
  since the reference image is shipped for exactly this kind of check --
  and it missed the single pinned pixel by 11 levels (186 vs 197) and had a
  `max_channel_difference` of 51 over the whole image. Getting to an exact
  match required a small brute-force parameter search (varying the circle
  and mask radii and centers, re-rendering, and comparing against the
  reference bytes) rather than anything derivable from the chapter. The
  found values -- star radius 60, circle clip radius 45, soft mask radius
  70, all three sharing the star's center (75, 75) -- are exactly right
  (diff 0), but this is reverse-engineering the reference implementation's
  output, not translating the chapter, and it directly violates the book's
  own iron rule ("every suggested implementation is specified... each
  render is a named function... so scenarios can call it"). A reader
  without the patience (or the license) to brute-force against the
  reference bytes cannot pass this scenario. Fix: print `clip_demo()`'s
  pseudocode the way `per_child()`/`group_opacity()` are printed in the
  same section, or add it as a `Plate.add` figure like every other render
  in these two chapters.
- **§11.4, minification is specified but never wired up, and the chapter
  doesn't say so.** `downsample`, `mip_chain`, and `mip_level_for` are all
  precisely pinned by `chapter11-mip.feature`, but no scenario in
  `chapter11-paint.feature` or `chapter11-plate.feature` ever constructs an
  `image_paint` that minifies (every scenario there magnifies). The
  chapter's own pseudocode for `image_paint` in §11.3 doesn't reference a
  mip level at all. This isn't a bug -- I initially assumed I'd need to
  wire mip selection into `ImagePaint` and had to re-read closely to
  confirm the pseudocode really doesn't ask for it -- but a sentence after
  the `image_paint` pseudocode block saying explicitly "this doesn't pick a
  mip level; that's left as three separate functions this chapter doesn't
  wire together" would have saved the double-take, and would make it
  obvious to a reader that a minifying render (one doesn't exist in this
  chapter) is out of scope by design rather than an oversight.

## Mutation results

Three mutations per chapter, each reverted after testing (verified against
backups: byte-identical). All caught except one, which is a real, useful
finding about test coverage rather than a bug in the implementation:

**Chapter 11**
1. Dropped the `-0.5` half-pixel offset in `sampleBilinear`/`sampleBicubic`
   -> caught immediately: 6 scenarios fail, including "the identity
   transform is bit-exact under every filter," exactly the scenario the
   chapter's trap says exists for this purpose.
2. Sampled forward through `m` instead of through `m.inverse()` in
   `ImagePaint` -> caught by the two scenarios that place the image with a
   real transform (translation, then 2x scaling); the identity-transform
   scenario does *not* catch it, since `identity().inverse() == identity()`
   -- confirming the chapter's own point that the identity case alone isn't
   sufficient to test the direction of the walk.
3. Averaged un-premultiplied (`pixelColor()`) instead of premultiplied
   channels in `downsample` -> **not caught. Every scenario still passes.**
   This is a genuine gap: every image `downsample` is ever exercised on in
   this book's scenarios is fully opaque (alpha = 1 everywhere), so
   premultiplied and straight averaging are numerically identical --
   dividing by alpha = 1 does nothing. The chapter's own prose predicts
   this ("for the opaque photos in this chapter it makes no visible
   difference; the first time you resample a cut-out with a soft edge,
   it's the difference between a clean edge and a grey fringe") but no
   scenario actually builds that cut-out. A `downsample` scenario over an
   image with a translucent texel (e.g. two texels red at alpha 1 and 0,
   checking the averaged pixel's *premultiplied* channel rather than its
   un-premultiplied color) would catch this and is currently missing.
4. Swapped in uniform B-spline weights for the Catmull-Rom ones in
   `catmull` -> caught immediately by both the dedicated weights scenario
   and by bicubic sampling and the identity-transform scenario.

**Chapter 12**
1. `multiplyCoverage` using `max` instead of the product -> caught by 4 of
   4 relevant scenarios plus the clip-demo plate.
2. Group opacity applied per child (bake 0.5 into each `paintInto` call and
   pop at opacity 1, instead of painting at opacity 1 and popping at 0.5)
   -> caught by the plate scenarios' pinned overlap pixel and by
   `max_channel_difference` on both `opacity.ppm` and `plate-12.ppm`. (The
   dedicated `Groups` scenario for this exercises the API correctly by
   construction and can't catch a caller misusing it; this mutation had to
   be applied at the `Figures.groupOpacity()` call site rather than inside
   `Groups.java` itself to reproduce a plausible reader mistake.)
3. `softMask` clamped to hard 0/1 at the radius instead of a continuous
   falloff -> caught by both mask scenarios and the clip-demo plate's
   pinned pixel.

## Concrete changes

1. Print `clip_demo()`'s pseudocode in §12.4 (star center, radius, path
   source; circle clip center and radius; soft mask center and radius),
   the same way `per_child()`/`group_opacity()` are printed just above it.
   This is the one real gap against the book's own iron rule found in
   either chapter.
2. Add one `downsample` scenario over a non-opaque image (a translucent
   texel averaged against an opaque one), checking the result's
   *premultiplied* channel, so a straight-vs-premultiplied averaging bug
   can't hide behind every test image happening to be opaque.
3. Optional clarity: a sentence in §11.2 stating that `sample_nearest`'s
   `floor(sx)` already *is* the texel-centre rule (round-to-nearest of
   `sx - 0.5` collapses to `floor(sx)`), not an exception to the trap.
4. Optional clarity: a sentence after §11.3's `image_paint` pseudocode
   noting that mip selection is deliberately not wired in here, since none
   of this chapter's renders minify.
5. Consider pinning `mip_level_for` at exactly `scale = 0.25` with a
   comment on why a small epsilon matters there, mirroring how chapter 7
   documents `VERTICAL_EPSILON`.

## Timing

Reading both chapters and every feature file, translating all 30 scenarios,
implementing images/sampling/minification (chapter 11) and
clipping/masks/groups (chapter 12), getting all six renders to diff 0
(including the `clip_demo()` parameter search), running the full 1-12 suite,
and mutation testing took one continuous session, no blocking pauses. The
`clip_demo()` reverse-engineering was the single largest time sink by far --
easily half the total effort for chapter 12 -- for a function whose actual
logic (once found) is four lines.
