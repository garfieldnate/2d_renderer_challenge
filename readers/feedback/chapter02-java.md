# Chapter 2 feedback

## Ambiguities

- **"Scenario: Sizes still have to match"** (`chapter02-p6.feature`): `max_channel_difference(p6a, p6b) = 255` for a 2×1 canvas against a 1×2 canvas, both default black. There is no prose anywhere explaining what should happen when the two images don't have the same dimensions — the scenario title is the only hint of intent. I guessed: check width/height first, and if they differ, report the maximum possible difference (255) rather than comparing whatever bytes happen to overlap. That guess is unverifiable from the text alone; a reader could just as reasonably decide to throw an exception, or compare only the overlapping region and return 0 (since both canvases are black).

- **`center_inside(s, 2, 4) = 1`** (`chapter02-centers.feature`): every other boolean shape predicate in the book (`inside(s, x, y) = true`) is spelled as a boolean. `center_inside` and `coverage` are spelled as numeric equalities (`= 1`, `= 0`, `= 0.5`). I read this as deliberate — `center_inside` returns the same 0/1 coverage value that ends up in the buffer, not a `boolean` — but the chapter never says so; it falls out only by comparing the scenario's assertion style to the ones for `inside`.

- **Mixed-type comparisons** (`max_channel_difference(p3, p6)`, `ppm_pixel(p6, ...)`): the chapter says the readers should "accept both" formats, but never says how a statically-typed language should represent "either a P3 file or a P6 file" as one parameter type. I used `Object` with an `instanceof` dispatch in `Ppm`, which is the least invasive option (existing chapter-1 call sites, which always pass a P3 `String`, keep compiling unchanged) but it's not something I'd call clean Java, and the chapter's "share that code" instruction is really only true in a language where strings and byte arrays are close cousins.

## Hard to translate

- `disc_centers()`, `disc_coverage()`, `painted_twice()`, and `plate_02()` are pseudocode blocks embedded in the chapter prose, not scenarios in a `.feature` file. They're only reachable, spec-wise, through a `Given c ← disc_centers()` clause inside a `paint`/`coverage`/`twice`/`plate` scenario. Translating the nested loops (`once`/`twice`/`both` coverage-buffer copies in `painted_twice`/`plate_02`) was mechanical, but there is no scenario that checks those intermediate buffers directly — only a handful of spot-checked final pixels plus one whole-image `max_channel_difference ≤ 1` against the reference PPM. A transcription slip in the loop bounds (e.g. copying `cov` into the wrong half) would be caught only by that final diff, never by a small, quick, diagnostic assertion.

- The chapter's instruction that "`read_file` now returns bytes rather than text... nothing changes for chapter 1's tests" doesn't map onto this codebase, because chapter 1 never had a `Ppm.readFile` — the test runner just called `Files.readString` inline. So there was nothing to "change" in the sense the chapter means; I left chapter 1's reference-reading as `readString` (a `String`, still accepted by the now-`Object`-typed `Ppm` methods) and added a separate `Files.readAllBytes` call for chapter 2's `byte[]` references, rather than inventing a unifying `Ppm.readFile` the book never asked me to name.

## Failures

None. Every scenario passed on the first run once the four new coverage/rasterizer/painter classes and the P6 reader were written, and all four renders came out byte-identical to `reference/chapter-02/*.ppm` (`cmp` reports no difference). The closest thing to a "failure" was self-inflicted and caught before it mattered: my first compile used `javac -d out`, which would have left `.class` files sitting in `out/` next to the four required `.ppm` renders. Fixed by compiling to `classes/` instead; no scenario would ever have caught that, since nothing checks what else is in `out/`.

## Mistakes that stay green

- **`out/` isn't asserted to be clean.** No scenario (chapter 1's or chapter 2's) checks that `out/` contains only the expected files. Compiling classes into it, or leaving a stale render from an old shape in there, changes nothing about pass/fail.
- **`distinct_values(p6) = 5`** in "The disc by centers" is a coincidence of the two chosen colors (background `(0.02, 0.02, 0.025)` and ink `(0.9, 0.55, 0.1)`), not a targeted check of anything. A renderer that swapped which channel got which of the ink color's three components could still land on 5 distinct byte values in a from-centers (no partial coverage) render and pass that clause alone — it's only the accompanying `ppm_pixel` and `max_channel_difference` assertions in the same scenario that would actually catch a channel swap.
- **`CoverageBuffer.coverageAt` has no bounds check**, deliberately mirroring `Canvas.pixelAt` (which also has none). The chapter only specifies the drop-on-write rule ("as with the canvas, writes outside the buffer are dropped"); reads are never mentioned, and no scenario ever reads a coverage buffer out of bounds. A future rasterizer that samples one row or column past the edge of a buffer smaller than the canvas it's paired with would throw `ArrayIndexOutOfBoundsException` at best, or silently read garbage from a neighboring row at worst (since the backing store is a flat array) — the test suite would tell you *something* broke, but not *why*.
- **Only one blind diagonal is tested.** "Except when the grid conspires" checks the well-known 45° case (`half_plane(2.5, 4.5, 1, 1)` → 0.5625) but no other angle. A sampling bug that only misbehaved at, say, a different rational-slope angle wouldn't be caught by this suite at all.

## Prose

Chapter 2 is the strongest writing so far. §2.7 ("Coverage is not opacity") is the standout: it names a bug every 2D renderer has and nobody talks about, explains it in three sentences, and backs it with a scenario simple enough to run in your head first (`0.5 → 0.75`, not `1.0`). The worked arithmetic in §2.4/§2.6 (disc area 78.5 vs. the sampled 78.5398 vs. the exact 78.5398...) is an unusually honest touch — it lets the reader sanity-check the renderer without the book hand-waving "trust me."

One friction point: §2.2's phrasing ("read_file now returns bytes rather than text... nothing changes for chapter 1's tests") is written from inside a dynamically-typed reference implementation where strings and byte sequences are practically interchangeable. In Java that sentence is simply false without deliberate API design (`Object`-typed readers, or a byte-string bridge) — it's not wrong to say, but a Java reader following the book literally would wonder why their code didn't compile.

## Would change

- State the "sizes still have to match" rule as one sentence of prose (even just: "an image of the wrong shape isn't a pixel comparison at all, so it's reported as maximally different") instead of leaving the reader to reverse-engineer a magic 255 from a scenario title.
- Give `center_inside` the same explicit type note the shapes get ("inside... boundary included") — a one-line "returns 1 or 0, not true or false, because it feeds the same buffer coverage does" would have saved a guess.
- A short callout that the four named pseudocode functions (`disc_centers`, etc.) are real, testable functions — reachable only via `Given c ← disc_centers()` in a `.feature` file — would help; right now that convention has to be inferred by cross-referencing prose and features.

## Results

- Chapter 1: 59/59 passed, unchanged, ~256 ms.
- Chapter 2: 28/28 passed (all scenarios in all 8 `chapter02-*.feature` files; no scenario outlines to expand), ~105 ms.
- All four required renders (`out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`, `out/plate-02.ppm`) are byte-identical to `reference/chapter-02/*.ppm`.
- Time hotspot: none worth mentioning. JVM startup (~90-100 ms) dwarfs the actual rendering work — even the slowest render (`rasterize`, 64 shape queries per pixel over a 40×40 grid) finishes in low single-digit milliseconds. Total wall time for both suites combined is under half a second.
- Mutation check: 6 plausible reader mistakes were introduced one at a time (corner-sampled coverage grid, pixel-corner instead of pixel-center testing, an extra whitespace byte in the P6 header, a transposed `magnify`, `paint_through` ignoring the existing pixel, coverage divided by 63) and reverted afterward. All 6 were caught, each by 4-8 failing scenarios.
