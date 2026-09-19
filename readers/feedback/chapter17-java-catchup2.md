# Java catch-up: chapters 16-17

Catch-up pass bringing this Java implementation's tests up to date with the
current `features/`. Language: Java (JDK, javac/java only, no build tool, no
JUnit). Scope: chapters 16-17 only, per the task.

## Result

Whole suite (chapters 1-17), run from this directory:

```
javac -d classes src/*.java
java -cp classes Chapter01Tests   # ... through Chapter17Tests
```

All 17 chapters green. Total 559 scenarios, 559 passed, 0 failed. Chapter
16: 23/23. Chapter 17: 22/22 (up from 20 before this pass -- two new atlas
scenarios added).

`max_channel_difference` of every chapter 16/17 render against
`reference/chapter-16` and `reference/chapter-17` (computed with `Ppm.
maxChannelDifference`, the same helper the tests use, over the freshly
re-rendered `out/*.ppm`):

| render | diff |
|---|---|
| glyph.ppm | 0 |
| plate-16.ppm | 0 |
| composite.ppm | 0 |
| sizes.ppm | 0 |
| flip.ppm | 0 |
| subpixels.ppm | 0 |
| smoothing.ppm | 0 |
| lcd.ppm | 0 |
| plate-17.ppm | 0 |

Every render is byte-exact.

## Catch-up

Two feature-file changes were called out for this round; both were checked
against the current code, and neither needed a code fix.

1. **`chapter17-cache.feature`: "A taller bitmap that fits the width stays
   on the shelf and raises it"** (new). `Atlas.add` already grows the shelf
   in place for a bitmap that's narrow enough to stay but taller than
   everything on the shelf so far (`shelfHeight = max(shelfHeight,
   bm.height)`, no shelf bump). Traced by hand against the scenario's four
   `atlas_add` calls before writing the test -- all four match the existing
   code's output. Added the scenario to `Chapter17Tests.registerCache()`;
   it passed on the very first run. No code change.

2. **`chapter17-cache.feature`: "A bitmap the atlas can never hold leaves
   the shelf alone"** (new). `Atlas.add` rejects a bitmap wider (or taller)
   than the whole atlas with an immediate `return null`, before touching
   `shelfY`, `currentX`, or `shelfHeight` -- so a too-wide request can never
   corrupt the current shelf's state, and the following bitmap lands where
   it would have anyway. Traced by hand, matches. Added to
   `Chapter17Tests.registerCache()`; passed on the first run. No code
   change.

3. **`chapter16-composites.feature`: two scenarios renamed.** "Bounds are
   tight, not the control box" (the `o`/`H` bounds check) is now "Two more
   real glyphs' bounds," and the tight-bounds claim moved onto the
   hand-written `bump`/`twice` scenario, now named "Bounds are tight, not
   the control box: a hand-written bump stops where its curve does." Both
   scenario bodies in the feature file are byte-identical to what
   `Chapter16Tests.java` already ran -- only the two `scenario(...)` name
   strings were updated to match. No behavior changed, no code change.

This round found no bug: the previous round's `Atlas.add` implementation
(from the chapter-17 catch-up that fixed the width/height-rejection-order
issue) already generalizes correctly to both new cases. That is itself
worth stating plainly, since the instructions call out "a new scenario that
fails previously-green code is the strongest evidence a scenario earns its
place" -- these two did not fail, so on their own they add regression
coverage rather than catching a live bug. They are still worth keeping:
between them they pin both halves of the "does a rejected/oversize bitmap
disturb shelf state" question, which the original "shelf packing" scenario
never isolated (its own rejections -- the 40x5 and 30x20 bitmaps -- happen
after a shelf that's about to be abandoned anyway on the next successful
add, so a bug that only shows up when the *very next* add must land on the
undisturbed old shelf could have slipped through).

## Ambiguities

None found this round. Both feature changes were unambiguous: exact
`atlas_add` call sequences with exact expected results, and a pure rename
with identical scenario bodies.

## Failures

None. Every scenario in every chapter's feature files is now translated
into `Chapter16Tests.java` / `Chapter17Tests.java` and passes; verified by
listing every `Scenario:` line in `features/chapter16-*.feature` and
`features/chapter17-*.feature` (23 and 22 respectively) and confirming a
1:1 count against each test file's own total.

## Prose problems

None specific to this round's changes. (Prior rounds' prose issues --
`clip_demo()`'s missing geometry in chapter 12, the `lopsided()` control
points that only exist in figure JS in chapter 15 -- are unchanged and
already logged in earlier feedback/commits; not re-litigated here since
this pass touched only chapters 16-17.)

## Concrete changes

- `src/Chapter17Tests.java`: added two scenarios to `registerCache()` --
  "Cache: a taller bitmap that fits the width stays on the shelf and raises
  it" and "Cache: a bitmap the atlas can never hold leaves the shelf
  alone" -- transcribed directly from `features/chapter17-cache.feature`.
  No production code (`Atlas.java`) changed.
- `src/Chapter16Tests.java`: renamed two scenario strings to match
  `features/chapter16-composites.feature`'s current names ("Composites: two
  more real glyphs' bounds" and "Composites: bounds are tight, not the
  control box: a hand-written bump stops where its curve does"). No test
  body or production code changed.
- `README.md`: added a short catch-up note under Chapter 17 documenting
  both changes and why neither needed a fix.
