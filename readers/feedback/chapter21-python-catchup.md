# Catch-up pass feedback (chapters 8, 20, 21)

Scope: bring the reader up to date with scenarios added/changed in `features/` since the
chapter 20-21 pass, without touching `features/`, `reference/`, or the chapter HTML.

## Scenario count

721 -> 727 scenarios (six new, all in chapter 20). Before fixes: 723 passed, 4 failed.
After fixes: 727/727 pass.

## New/changed scenarios and what they found

1. **`chapter20-viewbox.feature` "One drawing, five ways to fit it"** — this scenario now
   fully specifies `aspect_demo()`'s source document (a `<polygon>` boat instead of two
   `<path>` triangles, `preserveAspectRatio` set as an attribute of the document itself
   rather than passed as a bare mode string, `xmlns` present). The old `aspect_demo()` was a
   pixel-measured reconstruction (no source was given last pass) and only agreed with the
   named `ppm_pixel` probes, not the whole-image budget (`max_channel_difference` 185).
   Rewrote it to build the exact document from the feature text (with `%s` substituted for
   each `preserveAspectRatio` value) and render each panel with plain `render_svg`, copied
   pixel for pixel — no more hand-built layer/matrix plumbing. Now byte-exact (diff 0).

2. **`chapter20-groups.feature` "A clip's shapes take their style from the clipPath"** — new
   scenario. `clip-rule='evenodd'` set as an attribute on the `<clipPath>` element itself,
   inherited by its child `<path>`. Old code computed each clip child's style against
   `initial_style()` directly (`computed_style(child, initial_style())`), skipping the
   clipPath element's own presentation attributes entirely, so an inherited property set on
   `<clipPath>` (rather than repeated on each child) was silently dropped and every clip
   child fell back to nonzero. Fixed in `clip_coverage` by computing
   `clip_style = computed_style(el, initial_style())` once and using that as the parent for
   every child's `computed_style` call. Failed before: `pixel_at(c, 5, 5)` came back red
   instead of white (the "hole" evenodd should have cut was filled in).

3. **`chapter20-paint.feature` "When there's nothing to paint with, and when there's one
   colour"** — extended with a case where a single-stop gradient (`url(#one)`) is looked up
   against a degenerate `objectBoundingBox` (`(0, 0, 10, 0)`, zero height) — same bbox that
   makes a real (2+-stop) gradient invalid. `paint_server` checked `bw == 0 or bh == 0` and
   returned `None` *before* the single-stop shortcut, so a solid-colour gradient failed
   exactly when it was pinned not to need geometry at all. Failed before: raised
   `unknown paint type: None` evaluating `paint_at` on the result. Fixed by moving the
   single-stop check ahead of the bounding-box computation in `paint_server`.

4. **`chapter20-transform.feature` "Nothing, or anything broken, is the identity"** — gained
   `translate(1 2 x)`. `number_list` (shared with path-data parsing, where "stop at the
   first thing that isn't a number" is correct) silently truncates trailing garbage, so
   `translate(1 2 x)` parsed as `translate(1, 2)` with the `x` dropped on the floor instead
   of invalidating the whole attribute. Failed before: returned `translation(1, 2)` instead
   of `identity()`. Fixed with a new `_number_list_consumed` helper (mirrors `number_list`'s
   walk, returns the index it stopped at) used only inside `parse_transform`, which now
   rejects the whole function (and so the whole attribute, per the all-or-nothing rule) when
   anything but whitespace/commas is left over inside the parens after the last number.

`chapter08-flatten.feature`'s two `flatten_into_path` "don't repeat the join point" scenarios
(mentioned as new in the task) were already green — this reader's `flatten_into_path` already
skipped the duplicate point at a join; no code change needed there.

## Ambiguity

None found this pass — all four fixes were clear-cut bugs the new/changed scenarios pinned
exactly (each failed with a concrete actual-vs-expected before the fix).

## Renders (chapters 20-21), max_channel_difference against reference/

- `aspect_demo.ppm`: 0 (was 185 last pass — the outstanding gap from missing prose/feature
  source is closed now that the feature gives the document)
- `harbor.ppm`: 0
- `rose.ppm`: 0
- `tiger.ppm`: 0
- `work_map.ppm`: 0

All five chapter 20/21 renders are now byte-exact.
