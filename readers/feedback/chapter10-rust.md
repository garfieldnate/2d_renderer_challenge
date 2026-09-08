# Reader feedback: Rust, chapters 9-10

Cold implementation of chapter 9 (Compositing) and chapter 10 (Paint Servers and
Gradients) on top of the existing chapters 1-8 Rust code, from `chapter-09.html`,
`chapter-10.html` and their `.feature` files alone. I did not read or write the
book's own repository; everything here is from the scratch directory.

## Result

| Chapter | Test functions | Pass | Fail |
|---|---|---|---|
| 9 (pixels, over, porterduff, blend, plate_09) | 23 | 23 | 0 |
| 10 (stops, extend, gradients, dither, plate_10) | 19 | 19 | 0 |

(Counts are `#[test]` functions, not raw Gherkin scenarios: each `Scenario
Outline` is translated into one test that loops over its examples table,
matching the existing chapters' convention rather than one `#[test]` per row.
By that measure every `Scenario` and `Scenario Outline` in
`features/chapter09-*.feature` and `features/chapter10-*.feature` has exactly
one corresponding test function — nothing skipped, nothing merged across
scenarios.)

Full suite: `cargo test --release` → **373 passed, 0 failed** (331 of those
were already passing in chapters 1-8 before this session; the 42 new tests
above are chapters 9-10).

Renders, `out/*.ppm` vs `reference/chapter-0{9,10}/*.ppm`, via this crate's own
`max_channel_difference`:

| Render | max_channel_difference |
|---|---|
| `porter-duff.ppm` | 0 |
| `blend-modes.ppm` | 0 |
| `seam.ppm` | 0 |
| `plate-09.ppm` | 0 |
| `three-gradients.ppm` | 0 |
| `extend-modes.ppm` | 0 |
| `plate-10.ppm` | 0 |

All seven are exact, not merely within the pinned tolerance of 1. Chapter 9's
`chapter-09.html` and chapter 10's `chapter-10.html` both ship a full JS
reference implementation in their `<script>` source blocks (`function
porterDuff()`, `function threeGradients()`, etc.) — reproducing that
byte-for-byte (tile size 64, square painted at `(10,10)`-`(42,42)`, circle at
center `(38,38)` radius 20 via a 48-gon, the seam's two triangles' exact
coordinates, magnification factors) got every render to diff 0 on the first
render, no back-and-forth against tolerances needed.

## Catch-up

`cargo test --release` on the existing chapters 1-8 code, before touching
anything: all passing, nothing newly broken. No catch-up fixes were needed.

## Ambiguities

- **`radial_t`'s "largest root" vs. the reference's actual order.** §10.3's
  prose says `radial_t` should "return the largest root t with r0 + t·dr ≥ 0."
  The chapter's own JS reference does not sort the two roots by size — it
  checks `roots[0] = (-b+s)/(2a)` first, then `roots[1] = (-b-s)/(2a)`, and
  returns whichever is eligible first. For `a > 0` these two orderings agree
  (root 0 actually is the larger one), but for `a < 0` — which happens whenever
  `dr² > cd·cd`, i.e. the radii change faster than the centers move apart, a
  perfectly normal focal-gradient configuration — dividing by a negative `2a`
  flips the order, and "check `roots[0]` then `roots[1]`" and "return the
  larger eligible root" are no longer the same rule. I implemented the JS's
  actual check order (matches every scenario and both plate renders exactly);
  a reader who took the prose literally and sorted the roots first would
  diverge from the reference on some focal-gradient configurations, though no
  scenario in this chapter happens to hit that case. Worth either fixing the
  prose to describe the check-order rule, or adding a scenario with `a < 0`
  and the two orderings disagreeing, so a reader who trusts the English over
  the pseudocode gets caught.
- **`blend_color`'s parameter order isn't stated in prose.** The feature says
  "`blend_color(mode, backdrop, source)` is that function," which is precise,
  but the chapter's running prose (§9.4/9.5) never spells out which argument
  is which when describing the four non-separable modes ("colour is the
  source's hue and saturation at the backdrop's brightness" — you have to
  infer `backdrop`/`source` map to specific parameter positions from context).
  The one scenario that pins `blend_color` directly (`blend_color("color",
  color(0.2, 0.4, 0.8), color(0.9, 0.2, 0.2)) = color(0.874, 0.174, 0.174)`) is
  enough to nail it down by trial, but a reader who gets the order backwards on
  the first attempt has no prose to catch the mistake against, only the number.

## Hard to translate

- Nothing was hard to translate mechanically — the existing chapters 1-8 code
  already has `CoverageBuffer`, `fill_path`, `polygon`, `circle_path`, and
  `Color` arithmetic, so chapter 9's layers and chapter 10's gradients slot
  in as more of the same rather than new machinery. The one design decision
  worth flagging: `Layer`'s `pixels: Vec<Pixel>` field is `pub` rather than
  hidden behind an accessor (unlike `Canvas`, which has `pixel_at`/
  `write_pixel`), because nothing outside `src/lib.rs` needs to touch a layer
  directly — `paint_shape`/`composite_layers`/`blend_layers`/`flatten_layer`
  cover every scenario's and every render's needs. If a later chapter (11 or
  12, clipping/groups) needs layer pixel access from outside the module, that
  decision may need revisiting.

## Failures

None. Every scenario passed on the first implementation attempt; no chapter,
reference, or agent bug was found requiring a fix.

## Prose problems

- §10.3 (the radial gradient's `radial_t` pseudocode): see the ambiguity above
  — "return the largest root" doesn't match the reference's actual
  check-first-eligible-root behavior once `a < 0`. Not currently exercised by
  a scenario, so it's a latent trap rather than a failure, but the wording
  should either match the algorithm or a scenario should be added that
  distinguishes "largest root" from "first eligible root in a fixed order."

## Mutation results

Eight deliberate bugs, one at a time, each tested and reverted:

| # | Ch | Mutation | Caught by |
|---|---|---|---|
| 1 | 9 | `src-over` coefficient reads `dst`'s alpha instead of `src`'s (`(1, 1-a_d)` instead of `(1, 1-a_s)`) | `porterduff::each_operator_is_its_two_coefficients`, `porterduff::src_over_is_over_and_dst_over_is_over_swapped`, `plate_09::the_conflation_seam_is_0_75_not_1_0`, `plate_09::the_seam_shows_in_the_render`, `plate_09::plate_9` |
| 2 | 9 | Blend modes computed in encoded (sRGB) space instead of linear light | `blend::the_separable_modes_opaque_source_over_opaque_backdrop`, `blend::the_four_non_separable_modes_mix_a_saturated_red_with_a_blue` |
| 3 | 9 | `lum(c)` changed from `0.3R+0.59G+0.11B` to `(R+G+B)/3` | `blend::blend_color_is_the_blend_function_on_two_straight_colours`, `blend::the_four_non_separable_modes_mix_a_saturated_red_with_a_blue` |
| 4 | 9 | `seam()` "fixed" to merge both triangles' coverage (max) before painting, instead of two independent src-over composites | `plate_09::the_seam_shows_in_the_render` (the conflation-seam coefficient scenario itself is a pure `composite()` unit test and doesn't touch `seam()`, so it did *not* catch this one — only the render scenario did) |
| 5 | 10 | `radial_t` returns the first quadratic root unconditionally, without checking `r0 + t·dr ≥ 0` | `gradients::a_focal_gradient_runs_from_the_focal_point_to_the_end_circle`, `gradients::a_concentric_radial_gradients_parameter_is_distance_over_radius` |
| 6 | 10 | `extend(t, "reflect")` implemented as `t - t.floor()` (i.e. as `"repeat"`) | `extend::the_three_modes_fold_a_parameter_back_in`, `plate_10::the_extend_strip` |
| 7 | 10 | `to_byte_dithered` ignores `dither_threshold` entirely (equivalent to plain `to_byte`) | `dither::one_light_value_dithers_to_the_two_bytes_around_it`, `dither::a_flat_patch_is_one_byte_plain_but_two_dithered` |
| 8 | 10 | Focal gradient's unreachable cone (`radial_t` returns `None`) painted black instead of the last stop | `plate_10::an_unreachable_focal_pixel_takes_the_last_stop_not_black` |

No mutation survived. Mutation 4 is the most interesting result: the pinned
"conflation seam is 0.75" unit scenario (a direct `composite()` test) is
useless against a `seam()`-level "fix," because merging coverage before
painting never calls `composite()` with two independent translucent layers in
the first place — only the render-level scenario against
`reference/chapter-09/seam.ppm` catches it. That's a point in favor of the
book's insistence on pinning renders, not just unit-level formulas: a reader
who "improves" `seam()` to avoid the artifact the chapter is explicitly about
would pass every unit test in `chapter09-porterduff.feature` and still fail
the render.

## Concrete changes

1. §10.3: fix `radial_t`'s prose ("return the largest root") to match the
   reference's actual behavior (check a fixed root order, return the first
   eligible one), or add a scenario with `a < 0` where the two rules diverge.
2. Consider one more line of prose in §9.4/9.5 stating `blend_color`'s
   parameter order in the running text, not just the feature file, since a
   reader translating from the chapter body alone (before checking the
   scenario) has nothing else to go on.

## Timing

Roughly 90 minutes end to end: reading both chapters and all ten feature
files, cross-checking the chapters' embedded JS reference against the
pseudocode and scenarios, implementing chapter 9 (~420 lines) and chapter 10
(~230 lines) in `src/lib.rs`, writing 10 new test files (`tests/pixels.rs`,
`over.rs`, `porterduff.rs`, `blend.rs`, `plate_09.rs`, `stops.rs`, `extend.rs`,
`gradients.rs`, `dither.rs`, `plate_10.rs`), wiring `render_all.rs`, and
running eight mutation-testing rounds. Every render matched the reference
exactly on the first `cargo run --release --bin render_all`; no iteration was
needed once the geometry was copied faithfully from the chapters' own
reference JS.
