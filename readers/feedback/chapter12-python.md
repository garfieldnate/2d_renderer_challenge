# Feedback: Chapters 11-12 (Python)

## Result

Full suite: 441 scenarios, 441 passed, 0 failed (chapters 1-12 combined).

- Chapter 11: 17 scenarios, 17 passed (image: 3, mip: 3, paint: 3, plate: 4, sampling: 4).
- Chapter 12: 13 scenarios, 13 passed (clip: 4, groups: 3, mask: 2, plate: 4).

Render diffs, `out/*.ppm` vs `reference/chapter-NN/*.ppm`, via `max_channel_difference`:

| Render | max_channel_difference |
|---|---|
| chapter-11/two-filters.ppm | 0 |
| chapter-11/plate-11.ppm | 0 |
| chapter-11/three-filters.ppm | 0 |
| chapter-12/opacity.ppm | 0 |
| chapter-12/plate-12.ppm | 0 |
| chapter-12/clip-demo.ppm | 0 |

All six renders are bit-exact against the reference, not just within the ≤ 1 budget the scenarios ask for.

## Catch-up

Ran chapters 1-10's existing suite before touching anything: all scenarios that were passing are still passing. Nothing was newly broken by adding chapters 11-12 (the two new chapters are additive; no chapter 1-10 function was touched except `paint_at`, which gained one more `isinstance` branch at the end, after the existing branches, so no rebinding of behavior for any pre-existing `Paint` kind).

## Ambiguities (what had to be guessed)

- **`clip_demo()` has no pseudocode or JS figure mirror anywhere in chapter 12.** Every other named render in chapters 11 and 12 (`sprite`/`two_filters`/`three_filters`, `per_child`/`group_opacity`/`opacity_plate`) is either given explicit pseudocode in the chapter text or has a JS reference implementation embedded in the chapter's own `<script>` block for the figures, which this Python implementation mirrored line for line (and which turned out to be bit-exact against the Python reference in every case). `clip_demo()` gets neither: the prose says only "clip_demo() clips a star to a circle and to a soft radial mask," with no radius, centre, or panel layout given. I reverse-engineered the parameters from `reference/chapter-12/clip-demo.ppm` by:
  1. Confirming the panel layout (300x150, two 150x150 panels side by side, same `PAPER`/orange-ink colours as the rest of the book) from the single pinned pixel and the background colour.
  2. Measuring the boundary's inner "waist" radius on the (unclipped, in its valleys) left panel and finding it matched the self-intersecting-pentagram invariant `0.381966` (`2 - φ`) exactly, confirming the star is `unit_star()` (the same shape chapter 6 already defines and reuses for the spiral plate), not a hand-rolled star.
  3. Fitting `(center, star radius, rotation, clip radius, mask radius)` by nonlinear least-squares (a from-scratch Nelder-Mead, since the sandbox has no numpy/scipy) against the full reference image, which converged cleanly to round numbers: center `(75, 75)`, star radius `60`, rotation `0`, clip circle radius `45`, soft mask radius `70`.
  4. Verifying bit-exactness (`max_channel_difference` = 0) once plugged back into the real renderer, which is strong evidence these are the actual reference parameters and not a coincidentally close fit.

  This worked out in the end, but it took real effort and there was no way to be sure it would land on the exact values (an approximate match would have failed the `≤ 1` budget and the exact pixel check, and there'd have been no way to know whether the discrepancy was mine or the chapter's). **Concrete change: give `clip_demo()` the same pseudocode treatment as `two_filters()`/`per_child()`/`group_opacity()`** — even three lines naming the star radius, clip radius, mask radius and center would remove all of this guesswork.
- **Default `extend` mode for `image_texel`/samplers.** The scenarios call `image_texel(img, 0, 0)` with no extend argument in the round-trip scenario (§11.1), where it doesn't matter (the index is in range). No scenario pins what the default *should* be for an out-of-range call. I defaulted to `"clamp"` for all of `image_texel`/`sample_nearest`/`sample_bilinear`/`sample_bicubic`, since that's the least surprising choice for a photo (repeat/reflect assume a tileable image) and it's what `image_paint`'s scenarios always pass explicitly. Worth stating in prose if the default matters to the book.
- **Whether `clip_rect`/`full_clip`'s bounds argument is `(w, h)` of the whole canvas or something narrower.** The scenarios always pass the same `w, h` as the shape being clipped, so I couldn't tell from the scenarios alone whether `clip_rect`/`clip_path`/`full_clip` are meant to allocate a coverage buffer the size of the *clip's own bounding box* (as the chapter's own trap warns about for *groups*, §12.3) rather than the full canvas. I implemented all three at full canvas size, matching every scenario, but the chapter's trap about wasteful full-canvas group buffers arguably applies equally to clips and isn't mentioned there — see Prose problems below.

## Hard to translate

- Nothing was hard to translate mechanically — every scenario maps onto a single function call or a short, obvious sequence, consistent with earlier chapters. The generic `test_runner.py` comparison and assignment machinery (from chapters 1-10) needed zero changes: `img.width`, `chain[0].width`, `catmull(0.5) = [...]`, and `mip_level_for(0.3) = 1` all fall through the existing generic "assignment" and "comparison" step handlers once the new functions are registered in the namespace dict, without any new step-pattern code in `test_runner.py`.

## Failures

None outstanding. (See Ambiguities above for the one scenario, `clip_demo`, that took real effort to make pass rather than being pinned tightly enough to derive directly — it does pass, bit-exact, but only because I reverse-engineered undocumented parameters, not because the chapter specified them.)

## Prose problems

- **§12.4 (`clip_demo`)**: no pseudocode is given for `clip_demo()`, unlike every other named render in chapters 11-12. See Ambiguities.
- **§12.3, the group-buffer trap**: the trap box explains why a *group's* offscreen layer should be sized to its bounding box, not the whole canvas, but doesn't mention that the exact same waste applies to `clip_rect`/`clip_path`'s coverage buffer (a coverage buffer is exactly as much memory as a layer, per pixel). Not a bug — the book explicitly keeps its own groups canvas-sized "because its canvases are small and the code stays readable" — but readers who take the trap at face value may assume clips are exempt when they aren't; one sentence noting that clips have the identical bounding-box opportunity (and that this implementation, like the book's own groups, skips it) would close the gap.
- **§11.2 nearest vs. the half-pixel offset**: worth double-checking this is intentional rather than an oversight — `sample_nearest` does *not* subtract 0.5 (it floors the raw source coordinate directly), while `sample_bilinear`/`sample_bicubic` do. The trap box's wording ("every sampler works in texel-centre space... subtract 0.5") reads as if it applies uniformly to all three, but it doesn't apply to nearest's *implementation* (nearest still *returns* the right texel because flooring an un-shifted coordinate already finds the containing cell — the trap is really about the two *interpolating* samplers). I got this right only by checking against the two mixed-parity scenarios (`sample_nearest(img, 1.1, 0.1) = green`, which fails if you shift by -0.5 first: `floor(0.6) = 0` gives red, not green) — a reader translating from the prose alone, without running the scenario, would plausibly subtract 0.5 in `sample_nearest` too and only discover the bug from that one scenario. The chapter would be stronger if it said explicitly that nearest doesn't need the offset and why (there's no interpolation to center).

## Mutation results

Six mutations tried across the two chapters, one plausible mistake per remaining slot beyond the three suggested:

| Mutation | Caught? | Scenario(s) |
|---|---|---|
| Ch 11: drop the half-pixel `-0.5` offset in `sample_bilinear` | Yes | "The identity transform is bit-exact...", "Two filters...", "Every sampler returns the texel exactly at its center", "Bilinear blends toward its neighbours" (4 failures) |
| Ch 11: `image_paint` samples through `m` directly instead of `inverse(m)` | Yes | "The transform places the image...", "A doubled image samples...", all three plate renders |
| Ch 11: wrong Catmull-Rom weights (swapped for linear-interpolation weights) | Yes | "The Catmull-Rom weights sum to one...", "Three filters, adding bicubic" |
| Ch 11: **`downsample` averages straight colour instead of premultiplied channels** | **No — survives every scenario** | none |
| Ch 12: `multiply_coverage` uses `max` instead of product | Yes | "Multiplying two coverage buffers...", "Clipping to the whole canvas...", "A clip zeroes the coverage...", "A shape multiplied by a soft mask...", "The clip demo" |
| Ch 12: `soft_mask` clamps to a hard 0/1 threshold instead of a linear falloff | Yes | both mask scenarios, "The clip demo" |
| Ch 12: group opacity applied per-child (`paint_into(..., 0.5)` inside the group loop) instead of once via `pop_group_with_opacity` | Yes | "A single circle looks the same...", "The opacity plate", "Plate 12" |

**The `downsample` mutation is the one that matters.** Every scenario that exercises `downsample`/`mip_chain` (chapter11-mip.feature, and `sprite()`'s round trip in chapter11-plate.feature) uses only fully-opaque images (`opaque(color(...))` in the mip scenarios; the sprite is opaque pixel art). Averaging "premultiplied" channels and averaging "straight, then re-premultiplying by the averaged alpha" are numerically *identical* whenever every input pixel has alpha = 1, since un-premultiplying by 1 is a no-op. So a `downsample` that quietly does the wrong thing — unpremultiply each texel, average the straight colours, average the alphas, then re-premultiply — passes all 441 scenarios. I confirmed this is a real bug, not an equivalent mutant, by hand-averaging a translucent red texel next to a fully transparent one: the correct (premultiplied) average keeps the surviving colour a saturated red at reduced alpha (`Color(1, 0, 0)` at alpha 0.25), while the mutated (straight) average washes it out to `Color(0.5, 0, 0)` at the same alpha — precisely the "grey fringe" the chapter's own "Why premultiplied, again" box warns about, on the one operation (`downsample`) that box explicitly names. **Concrete change: add a scenario to chapter11-mip.feature (or -image.feature) with a translucent-over-transparent 2x2 image, pinning `downsample`'s result pixel exactly**, the same way chapter 9 pinned `lerp_pixel` on premultiplied inputs. I did not add this scenario myself since I was told not to modify `features/`, and left the (passing) suite as-is; the gap is reported here per the "mutation that survives" instruction.

## Concrete changes

1. Add pseudocode for `clip_demo()` in §12.4 (star radius, clip radius, mask radius, centers) — see Ambiguities and Prose problems.
2. Add a translucent-over-transparent scenario for `downsample` — see Mutation results.
3. State explicitly in §11.2 that `sample_nearest` doesn't need (and shouldn't apply) the half-pixel offset, and why.
4. Optional: a sentence in §12.3's trap noting clips have the same bounding-box opportunity groups do.

## Timing

Reading both chapters and every `.feature` file: ~15 minutes. Implementing chapters 11-12 (images/sampling/mip machinery, then clip/mask/group machinery) and getting all scenarios green on the first pass except `clip_demo`: ~40 minutes. Reverse-engineering `clip_demo()`'s undocumented parameters (boundary detection, circle/pentagram fitting, then a from-scratch Nelder-Mead search against the reference PPM since no numpy/scipy is available): ~35 minutes — by far the longest single piece of this round, and the only reason the whole task took as long as it did. Mutation testing (six mutations, one surviving): ~10 minutes. Full suite run: ~104 seconds serially (441 scenarios across 12 chapters; nothing in this round was slow to render, at 150x150-320x160 canvas sizes).
