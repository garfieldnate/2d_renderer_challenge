# Feedback: Java, catch-up + chapters 16-17

This round: (0) a catch-up fix to chapter 13 for one new scenario, then
(1) chapter 16 ("What a Glyph Is") and (2) chapter 17 ("Rasterizing Type
Well"), implemented cold from `chapter-16.html`/`chapter-17.html`'s prose
and pseudocode and every scenario in `features/chapter16-*.feature` and
`features/chapter17-*.feature`. No JUnit, no library, hand-rolled JSON
reader for the font file, exactly as asked.

## Result

Full suite, run from this directory after `javac -d classes src/*.java`:

| Chapter | Scenarios | Pass | Fail |
|---|---|---|---|
| 1 | 66 | 66 | 0 |
| 2 | 35 | 35 | 0 |
| 3 | 38 | 38 | 0 |
| 4 | 76 | 76 | 0 |
| 5 | 32 | 32 | 0 |
| 6 | 34 | 34 | 0 |
| 7 | 34 | 34 | 0 |
| 8 | 23 | 23 | 0 |
| 9 | 45 | 45 | 0 |
| 10 | 24 | 24 | 0 |
| 11 | 17 | 17 | 0 |
| 12 | 13 | 13 | 0 |
| 13 | 22 | 22 | 0 |
| 14 | 27 | 27 | 0 |
| 15 | 28 | 28 | 0 |
| 16 | 23 | 23 | 0 |
| 17 | 19 | 19 | 0 |
| **Total** | **596** | **596** | **0** |

`max_channel_difference` of every chapter 16-17 render, freshly written to
`out/` and compared against `reference/`:

| Render | Diff |
|---|---|
| `glyph.ppm` | 0 |
| `plate-16.ppm` | 0 |
| `composite.ppm` | 0 |
| `sizes.ppm` | 0 |
| `flip.ppm` | 0 |
| `subpixels.ppm` | 0 |
| `smoothing.ppm` | 0 |
| `lcd.ppm` | 0 |
| `plate-17.ppm` | 0 |

Every render is byte-exact against the reference, not just within budget.
Every point-value scenario (implied points, control-point coordinates,
bounds, matrix products, bitmap coverage, atlas placement) also matched
the reference numbers on the first implementation that compiled, without
any tolerance-tuning -- see **Ambiguities** for the one place that
required outside information to get there.

## Catch-up (chapter 13, one new scenario)

`features/chapter13-degenerate.feature` gained "A closed subpath that ends
where it began has no zero-length closing segment": a path that draws a
10x10 square with an explicit `line_to` back to its own start point and
*then* calls `close`, rather than relying on `close` alone to supply the
last edge. The scenario pins `length(subpaths(o)) = 8` and
`polygon_area(o) = -84` for the stroke of that path.

This is new, and it failed on the existing code before the fix: `Stroke`
deduped only *consecutive* identical points, so the redundant final point
(same coordinates as the first, but not adjacent to it in the point list)
survived into `strokeSubpath`. For a closed subpath, `strokeSubpath` then
appends its own synthetic closing segment from the last point back to the
first -- which, with the redundant point already sitting on top of the
first, is a segment from a point to itself. `unitDir` normalizes a
zero-length vector and produces `NaN`, which cascaded into a
`length(subpaths(o))` of the wrong count and a `polygon_area` of `NaN`
instead of `-84`.

Fix: in `Stroke.strokeToPath`, after deduping consecutive points, a closed
subpath whose *last* point sits within the same epsilon of its *first*
point has that last point dropped before segment-building starts. One line
(`src/Stroke.java`). All 22 chapter 13 scenarios are green, and chapters
1-15's own suites are unaffected (all still pass; chapter 14's stroker
reuse of `Stroke.capShapePublic`/`dedupePublic` doesn't touch the changed
path).

## Ambiguities

- **`composite_demo()`, `sizes()`, and `flip_trap()` have no printed
  pseudocode.** Chapter 16 prints `glyph_plate()`/`plate_16()` in full in
  §16.5, but the other three renders `chapter16-plate.feature` names are
  described only in one sentence each ("draws eacute with its two
  components in two inks and its bounds as a hairline box", etc.), with no
  Gherkin table pinning canvas sizes, pen positions, colors, or the
  bounding box's stroke width. This is the identical situation `README.md`
  already flagged for chapter 12's `clip_demo()`. I found the exact
  geometry the same way that round apparently did: the chapter's own
  `<script>` block ships the literal JS source these figures are drawn
  from (`chapter-16.html`'s `compositeDemo`/`sizes`/`flipTrap` functions,
  and `chapter-17.html`'s `subpixelStrip`/`smoothingDemo`/`lcdPlate`),
  which a real cold reader has to notice is there and choose to read as
  ground truth rather than prose. It is legitimate ground truth (it's what
  produced the reference PPMs), but it means the *chapter itself* doesn't
  pin these renders anywhere a reader would look first (the printed
  pseudocode blocks). I'd promote these three (and chapter 17's three) to
  printed pseudocode, the same treatment `glyph_plate()` already gets.
- **`draw_text` is named in prose but never called out as its own
  scenario.** §17.5's feature text says "`draw_text` steps the pen by
  [`pen_advance`], each glyph at its nearest quarter," but no scenario
  pins `draw_text`'s signature or return value directly -- only
  `pen_advance` gets a scenario. I wrote a private `drawText` helper in
  `Figures.java` matching the description (and the figure JS's own
  `drawText`), but there's no scenario that would catch a reader's
  differently-shaped `draw_text` (e.g., one that returns nothing instead
  of the pen's new position, or doesn't floor `y`). Not a blocker since no
  reference render depends on `draw_text` having a specific public
  signature, but it's the one named function in these two chapters with
  zero direct scenario coverage.
- **Whether `paint_bitmap`'s `linear` flag is a parameter or should read
  chapter 1's global switch.** The scenarios always pass it explicitly
  (`paint_bitmap(c, bitmap, x, y, color, true/false)`), so I implemented it
  as an explicit parameter, ignoring `Mixer.linearBlending` entirely for
  this call. The chapter text ("`paint_bitmap` takes a `linear` flag")
  supports this reading, but it's worth being explicit that the two
  switches are now independent: resetting `Mixer.linearBlending` between
  scenarios (as chapter 1 says to do) has no effect on `paint_bitmap`'s
  behavior.

## Hard to translate

Nothing in these two chapters resisted Java specifically. The one recurring
translation choice: the book's contour points are triples `[x, y, on]`
with a boolean flag; I made this a `record ContourPoint(double x, double y,
boolean on)` rather than reusing `Tuple` (whose third field, `w`, means
something else entirely in chapter 4's algebra and would have been a false
friend). Component transforms `[a, b, c, d, dx, dy]` stayed as a plain
`double[6]` rather than a named record, since the scenarios always
construct and compare them as flat six-element lists.

`glyph_path`'s "one closed subpath per contour" was straightforward given
chapter 8's `Curves.flatten`/`transformCurve` and chapter 5's `Path`
already existed; the only design decision was whether to deduplicate the
point that repeats at each curve-to-curve boundary within a contour (curve
*k*'s last point equals curve *k+1*'s first, since they share a vertex). I
did not dedupe -- a repeated point becomes a zero-length edge, which both
`Fill.accumulate` (via its `y0 == y1` horizontal-edge check) and
`Winding.windingAt`/`Winding.crossings` already treat as a no-op. Confirmed
by every pinned area and ink value matching the reference exactly with the
duplicates left in.

## Failures

None. Every scenario in both chapters passed once written; there was no
case where the chapter, the reference, or my translation disagreed and had
to be adjudicated.

## Prose problems

- §17.4 (LCD) says paint_lcd's row filter has "taps that sum to one," and
  the scenario checks this only indirectly (`lcd_filter([1,1,1]) =
  [0.666667, 1, 0.666667]`, which sums to `2.333`, not `1` -- the *taps*
  sum to one, not the filtered output of a uniform input, which is a
  subtlety a reader could trip over if they check the wrong sum). The
  prose is correct once you know which sum it means, but the direct
  scenario for it (`LCD_TAPS = (0.333333, 0.333333, 0.333333)`) is a
  separate assertion from the filter-behavior ones, and nothing calls out
  the distinction explicitly. Minor, but a sentence like "the three
  *coefficients* sum to one; a uniform row of coverage 1 comes back as a
  uniform row of coverage 1" would close the gap.
- Otherwise both chapters read cleanly and matched the reference on the
  first pass; no wrong claims found, no place I got stuck.

## Mutation results

Six deliberate mistakes, one per plausible spot per chapter, plus one
extra probe:

| # | Mutation | Caught by |
|---|---|---|
| 1 | `implied_points`: skip the wrap-around pair (last, first) when checking for an implied off-off midpoint | `Contours: a loop of off-curve points implies a midpoint between each pair` (length 8 → 7) |
| 2 | `component_matrix`: build the matrix in TrueType's own `[a,b,c,d,dx,dy]` reading order instead of the transposed order the format actually needs | `Composites: a component transform is a matrix` and the hand-written-font bounds scenario |
| 3 | `text_matrix`: forget the flip (`scaling(s, s)` instead of `scaling(s, -s)`) | 8 of chapter 16's 23 scenarios and 13 of chapter 17's 19 -- everything downstream of a glyph's device-space shape, including every plate |
| 4 | `glyph_bitmap`: left edge ignores the quarter pixel (`dx` dropped from the `left` computation only, kept in `right` and in the fill matrix) | `Bitmap: a quarter to the right moves the ink, not the amount of it` and `Cache: a different quarter or size is a different entry` (`b.left` wrong) |
| 5 | `lcd_filter`: pad with the edge value (replicate) instead of zero beyond the ends | `LCD: the filter's taps sum to one and spread a spike over three stripes` (`lcd_filter([1,1,1])[0]` wrong; the single-element `[6] → [2]` case would also have failed, but the scenario throws on its first bad assertion so it's masked in the same run) |
| 6 | `Atlas.add`: never opens a new shelf, just returns `none` once the current one is full | `Cache: shelf packing places bitmaps left to right, then opens a new shelf` (third placement, expected `(0, 8)`, wrong immediately) |
| 7 (extra) | `contour_curves`: put a straight edge's control point at the *start* point instead of the edge's midpoint -- still exactly collinear with the endpoints, so the quadratic traces the identical line | **Only** the two point-value scenarios in `chapter16-contours.feature` that check `curves[i].points[1]` directly. It passes every single scenario in `chapter16-path.feature`, `chapter16-plate.feature`, and all of chapter 17 -- every fill, every bound, every rendered pixel, because `flatness()` measures perpendicular distance from the chord and a collinear control point (anywhere on the line through the endpoints) gives flatness zero regardless of where on that line it sits. |

Mutation 7 is the interesting one and matches the pattern CLAUDE.md's rule
("a scenario must be able to fail on the mistake it exists for") is
guarding against: a control point's *position along the chord* has zero
observable effect on any rendered output, ever, for any glyph, at any
size. If `chapter16-contours.feature`'s two point-value assertions
(`curves[0].points[1] = point(5, 0)`, etc.) didn't exist and the chapter
relied only on rendering scenarios to validate `contour_curves`, this
exact bug -- and any bug that moves a straight edge's control point
anywhere else on the same line, including all the way to one of the
endpoints -- would ship silently. No render, no plate, no `ink()` or
`coverage_at()` check would ever catch it. This is a good argument for
keeping (and not cutting) direct unit-level assertions on intermediate
data structures like `contour_curves`, even in a book that leans hard on
image-diff scenarios for everything downstream.

No mutation passed every scenario outright; mutation 7 is the closest to
that outcome and is the one worth the author's attention.

## Concrete changes I'd make

1. Print `composite_demo()`, `sizes()`, and `flip_trap()` as pseudocode in
   chapter 16 §16.5 the same way `glyph_plate()`/`plate_16()` already are,
   and the equivalent three in chapter 17 §17.5. Right now they're only
   fully specified in the chapter's own `<script>` source, which a cold
   reader has no principled reason to treat as more authoritative than the
   prose paragraph next to it.
2. Add one scenario that pins `draw_text`'s return value (the pen position
   after stepping through a short string), since it's the one named
   function in these chapters that a scenario never calls.
3. A one-line clarification in §17.4 that the "taps sum to one" claim is
   about the three coefficients, distinct from what a uniform input comes
   back as after filtering (which is itself a decent implicit check, but
   reads at first like it should sum to something related to 1 as well).

## Timing

All numbers are wall-clock, JVM included, on this machine, `javac -d
classes src/*.java` done once beforehand:

- `java -cp classes Chapter16Tests` (23 scenarios + 5 renders,
  `glyph.ppm`/`plate-16.ppm`/`composite.ppm`/`sizes.ppm`/`flip.ppm`,
  `plate-16.ppm` at 640x640 being the largest): **~0.29s** reported by the
  runner's own internal timer, **~0.54s** wall including JVM startup.
- `java -cp classes Chapter17Tests` (19 scenarios + 4 renders, largest
  `plate-17.ppm` at 288x384): **~0.09-0.16s** reported internally,
  **~0.18s** wall including JVM startup.
- Font loading (`Fonts.loadFont` on the full 177-glyph `roboto.json`,
  ~150KB of JSON through the hand-written parser) is not separately
  measurable at this scale -- it disappears into JVM startup noise. The
  full 1-17 suite (17 separate JVM invocations, no warm sharing) runs in
  about 4.5 seconds total on this machine.
