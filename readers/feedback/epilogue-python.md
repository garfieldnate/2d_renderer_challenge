# Reader feedback: the epilogue (Python)

This reader implemented chapter 0 (prose only, nothing to do) and the epilogue
("One Last Picture") cold, from `epilogue.html`, `chapter-00.html` and the four
`features/epilogue-*.feature` files alone, on top of the chapter 1-25 Python
implementation already in this directory. It did not read the book's own
repository or any other reader's code.

## Result

`python3 test_runner.py` from this directory: **891 scenarios, 891 passed, 0
failed.** That's up from 879 at the last chapter 24-25 catch-up: +1 in
`chapter23-atlas.feature` (a new scenario, not a new chapter) and +11 across
the four new `epilogue-*.feature` files. Per-file epilogue breakdown:

- `epilogue-cover.feature`: 2/2 ("The cover"; "Chapter 21's tiled walker draws
  the cover's document byte for byte")
- `epilogue-document.feature`: 3/3
- `epilogue-type.feature`: 3/3
- `epilogue-glow.feature`: 3/3

All three epilogue renders are byte-exact against `reference/epilogue/`
(`max_channel_difference` of 0, not just inside the ±1 budget):

| Render | Produced by | `max_channel_difference` |
|---|---|---|
| `cover-art.ppm` | `render_svg(read_file(".../cover.svg"), 480, 680)` | 0 |
| `cover.ppm` | `book_cover()` | 0 |
| `cover-glow.ppm` | `book_cover_glow()` | 0 |

Chapter 21's tiled walker on the cover document also matched exactly: `stats().cells
= 881792`, `stats().copies = 205568`, both pinned values hit on the nose, and its
canvas is byte-identical to both `render_svg`'s own output and the reference.

No code from chapters 1-25 needed to change. Every function the epilogue's
pseudocode names — `render_svg`, `load_font`, `layout_paragraph`, `layout_run`,
`draw_run`, `bake_mtsdf`, `draw_effect` — already existed with exactly the
signature the epilogue's program uses. The whole epilogue implementation is
two new top-level functions (`book_cover`, `book_cover_glow`) and one four-line
helper (`glow_of`) appended to the end of `renderer.py`, plus three namespace
entries in `test_runner.py`.

## Catch-up

Ran the untouched chapter 1-25 code against the current `features/` (which
already carried this session's one new scenario) before writing anything new,
as instructed. Every one of the 880 chapters 1-25 scenarios that existed
before this session (879 minus nothing removed) passed unchanged — genuinely
no catch-up fixes were needed for the existing chapters.

The only new item outside the epilogue itself was
`chapter23-atlas.feature`'s "A space has no edges, so every texel is as far
out as the clamp allows" scenario (`bake_mtsdf(f, "space", 16, 3)`, every
channel exactly `3` — the field's spread, since a space glyph has no outline
to be near). Checked this against the existing code by hand before running
the full suite: `bake_sdf`'s field function already special-cases an empty
`quads` list to `d = spread`, and `bake_msdf`'s per-channel `fn` already
returns `spread` when no coloured edge carries that channel's bit (an empty
`edges_list` for a glyph with no contours). Both were already correct — the
scenario passed on the first run, no fix needed. This is worth recording
precisely because it's the useful negative result: the scenario is a real
test (it would catch a`bake_msdf`/`bake_sdf` that returned 0, or +inf, or
crashed on an empty glyph), it just happened to already hold.

## Ambiguities

Very few — this chapter is unusually well pinned, probably because it's
assembled entirely from named, already-tested functions rather than
introducing new algorithm. Two small judgment calls:

1. **Where to put the glyph-baking cache in `book_cover_glow`.** The prose
   says "every distinct glyph of the title baked once by `bake_mtsdf`... then,
   for every placement of the title in order, `draw_effect(...)`" — it
   doesn't spell out *how* "baked once" is achieved (a pre-pass over the set
   of distinct names, vs. a memoizing cache keyed by glyph name consulted
   inside the placement loop). Went with a local `dict` cache consulted
   inside the loop over placements, in the same style `title()` (chapter 23's
   plate, in this same `renderer.py`) already uses for its own baked-glyph
   cache. Byte-exact result either way, since baking is a pure function of
   `(font, name, size, spread)` and doesn't depend on which placement
   triggered it.
2. **Whether `book_cover()`'s local variable name `title` shadows the
   module-level `title()` function** (chapter 23's plate render, already
   named `title` in this codebase before the epilogue). It does, but only
   inside `book_cover`'s own local scope, and `book_cover` never calls
   `renderer.title()`, so there's no actual collision — unlike the
   `plate_star`/`centred_star` and `flatten`/`flatten_layer` naming clashes
   CLAUDE.md-equivalent notes call out elsewhere in this book. Left it named
   `title`, matching the epilogue's own printed pseudocode variable name,
   since a faithful translation should use the book's own names where they
   don't actually collide.

Nothing in `chapter-00.html` needed a decision: it has no `data-feature`
blocks and states so itself ("no tests and no code").

## Hard to translate

Nothing was hard here. The four feature files use step shapes the runner
already understood end to end: `Given font ← load_font(read_file(...))`,
`When title ← layout_paragraph(...)`, indexed/attribute access
(`title[14].name`, `title[14].x`), `Given st ← stats()`, and
`ppm_pixel`/`max_channel_difference` against a `read_file`'d reference. No new
step pattern, no new mutation-style step, nothing that needed
`test_runner.py`'s parser touched beyond adding the three new names to the
`evaluate_expression` namespace dict.

## Failures

None. Every scenario passed on the first attempt once `book_cover`,
`book_cover_glow` and `glow_of` were written and wired into the namespace.

## Prose problems

Nothing wrong found. Two places worth a note, not a fix:

- **§E.5's trap is exactly as sharp as advertised, and worth flagging as a
  place a reader could genuinely get burned**, because it's the one part of
  the epilogue that isn't just "call an existing function": choosing
  `spread` for `bake_mtsdf` is a judgment call the epilogue makes explicit
  reasoning for ("the spread times the scale must reach at least as far as
  the effect"), and it's easy to imagine a reader copying chapter 23's
  `title()` render (spread 4) out of habit. Mutation-tested this directly
  (below) — it's not a hypothetical, it visibly breaks the glow into a grid
  of dim rectangles exactly as §E.5 describes, and the golden-image scenario
  catches it by a wide margin (`max_channel_difference` 80 against the ≤1
  budget).
- **Chapter 0's retrospective table in §0.1/§0.2 and the "what everything
  turned out to be" table in the epilogue's §E.1 both describe this
  implementation accurately.** Checked each entry in the epilogue's table
  against what this reader actually built: "A fill / a running sum of signed
  areas" (chapter 7's `accumulator`/`resolve`, exact) — matches; "Transparency
  / premultiplied light and `src + (1 − src.a)·dst`" (chapter 9's `over`) —
  matches; "The GPU's way / the same sums, in a different order" (chapter
  24's `stencil_buffer` proven equal to `winding_at`, and `run_pipeline`
  proven byte-identical to `render_svg` and shuffle-order-independent) —
  matches. No misdescription found in either chapter's look-back at earlier
  chapters' own implementation choices.

## Mutation results

Picked four plausible reader mistakes for this chapter specifically (glow_of
and the glow-baking step, since that's the only place with any actual
judgment in it — the rest of the epilogue is straight-line composition of
existing functions). All four were caught; three by the golden-image
assertion and/or a specific pinned pixel, one only by the aggregate
`max_channel_difference` check and not by any of the scenario's five named
pixel probes (worth flagging on its own):

1. **Dropped the square in `glow_of`** (`0.45 * (1 - clamp(d/10, 0, 1))`
   instead of `** 2`). Caught immediately and directly by the unit scenario:
   `glow_of(5)` came out `0.225` against the pinned `0.1125` — doesn't even
   need a render.
2. **Used chapter 23's `spread=4` instead of the epilogue's `spread=8`** in
   the `bake_mtsdf` call (the exact mistake §E.5's trap box warns against).
   Caught by the golden-image scenario: `max_channel_difference` against
   `cover-glow.ppm` came out `80` (budget is `≤ 1`), and the scenario's own
   `ppm_pixel(p6, 35, 499)` probe came out `(97, 56, 55)` against the pinned
   `(93, 54, 55) ± 1` — a miss of 4.
3. **Drew the glow after the crisp `draw_run` letters instead of before**
   (glow painted on top of the glyphs rather than underneath them). Caught
   hard: `max_channel_difference` came out `56`, and the scenario's very
   first pinned pixel, `ppm_pixel(p6, 44, 499)`, came out `(249, 207, 183)`
   against the pinned `(243, 239, 230) ± 1` — that pixel sits on a letter,
   and drawing the glow over it visibly washes the letter out.
4. **Passed `use_true_channel=False` to `draw_effect`** (reading the msdf's
   three-channel median instead of the mtsdf's fourth, true-distance,
   channel — a plausible slip, since `draw_baked` elsewhere in chapter 23
   *does* read the median). This is the interesting one: **all five of the
   scenario's own pinned `ppm_pixel` probes passed exactly**, because none of
   them happens to sit where the median-of-three and the true-distance field
   disagree by more than a shade. Only the scenario's final assertion,
   `max_channel_difference(p6, ref) ≤ 1`, catches it — the real value came
   out `45`. If this chapter's scenario had only pinned those five points
   (as the type-heavy chapters sometimes do for layout numbers) and skipped
   the whole-image diff, this bug would have shipped clean. It's a concrete
   argument for CLAUDE.md's own rule about pairing point probes with a full
   golden-image diff, and this chapter is a clean example of why: the point
   probes test *placement*, the full diff tests *which field got sampled*.

All four mutations were reverted and the full suite re-confirmed at 891/891
after undoing them (verified via direct re-run of `renderer.book_cover_glow()`
against `reference/epilogue/cover-glow.ppm`, `max_channel_difference` 0; no
mutation was left in `renderer.py` or `test_runner.py` — all four were tried
as standalone throwaway functions in a scratch `python3 -c` session, never
written into the tracked files).

Did not find a wrong implementation that slips past every scenario. Came
closest with #4 above, which slips past every *point* probe but not the
diff.

## Concrete changes you'd make

Nothing needed changing in the epilogue's prose, scenarios, or the existing
chapters' code. If pressed for a nitpick: the epilogue's own program listing
prints `layout_paragraph(font, "...", 44, 40, 530, 400, "left", true)` and
`layout_run(font, "...", 15, 40, 640, true)` without naming which argument is
`kerning` at the call site (relying on the reader having chapter 18's
signature memorized) — every other recently-written chapter in this book
(18, 19) is explicit that the kerning flag is "always passed explicitly in
scenarios," and the epilogue's own feature files do pass it as a bare
`true`/`false` positional the same way, so this is consistent with the book's
established style, not a real problem — just the one spot a reader unfamiliar
with chapter 18's exact parameter order has to flip back to check.

## Timing

- `book_cover()`: ~41 s (dominated by `render_svg` of the tiger-containing
  document; the type layout and two `draw_run` calls are negligible next to
  it).
- `book_cover_glow()`: ~54 s (the extra ~13 s over `book_cover()` is baking
  and drawing the MTSDF glow for every distinct glyph in the title —
  roughly 15-20 distinct glyphs at 32 px with spread 8).
- `render_svg` of `cover.svg` alone (`cover-art.ppm`): ~41 s, same as
  `book_cover()` minus the negligible type step, confirming the whole cost is
  the document, not the title.
- `render_svg_with(..., "tiled", ...)` of the same document: ~9 s — a ~4.5x
  speedup on this one document, in the same family as chapter 21's own
  reported tiger numbers, consistent with the cover being smaller and
  simpler than the full tiger scene.
- Full suite (`python3 test_runner.py`, all 891 scenarios, chapters 1-25 plus
  the epilogue): **13m55s** wall clock on this machine (00:07 to 00:21),
  in the same ~15-minute range the chapter 24-25 catch-up reported for 879
  scenarios — the epilogue's four scenarios and one document render add
  well under two minutes to a run already dominated by chapters 20-23's SVG
  rendering and distance-field baking, exactly as the existing README
  predicted for any addition this small.
