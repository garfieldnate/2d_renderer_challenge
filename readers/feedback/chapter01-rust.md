# Feedback on Chapter 1 — Rust reader

## Ambiguities

- **`write_pixel`/`pixel_at` coordinate type.** The canvas scenario "Writing outside the
  canvas is ignored" calls `write_pixel(c, -1, 5, ...)`. Rust's natural index type
  (`usize`) can't hold -1, so the prose forced a decision the book never states: what
  type are x/y? I made them signed 64-bit integers everywhere, including `pixel_at`,
  for symmetry, even though no scenario ever calls `pixel_at` with a negative or
  out-of-range coordinate. A one-line note ("coordinates may be negative; readers in
  languages with unsigned array indices will need a signed parameter type") would have
  saved a moment of "wait, how do I even call this."
- **Ranges are described as inclusive, but the pseudocode index style looks
  half-open.** "Ranges in these programs are inclusive at both ends: `0..99` is a
  hundred values" is clear once you hit it in §1.6, but by then I'd already read the
  `gray_match()` pseudocode (`for x in 0..99`) and the `plate_01()` pseudocode (`for y
  in top .. top + 39`) and silently assumed half-open, C-style ranges, because that's
  the overwhelmingly common convention. I had to re-read plate_01's row math once I
  reached the inclusive-range note and re-derive that `top..=(top+39)` was intended,
  not `top..(top+39)`. Stating the range convention *before* the first pseudocode block
  that uses it (i.e., in §1.3 or earlier) would remove the need to backtrack.
- **`round(x)` isn't given a language-neutral definition beyond "rounds to the nearest
  whole number,"** with a note that ties never occur in this chapter's tests. That's
  fine and I used `f64::round` (round-half-away-from-zero), but it's worth being
  explicit that any tie-breaking rule is acceptable, since round-half-to-even and
  round-half-away-from-zero are both common library defaults and would silently diverge
  on `.5` inputs the tests don't happen to exercise.
- **The linear-blending switch is described as "global state."** For a single-threaded
  reference implementation in most languages that's unambiguous, but the chapter's own
  rule ("reset it before each scenario, or turn it back on at the end of any scenario
  that turns it off") assumes serial test execution. Rust's built-in test harness runs
  every `#[test]` on its own OS thread by default, so naive global mutable state (a
  plain `static AtomicBool`) would make `mix`'s behavior nondeterministic under `cargo
  test`'s default parallelism — a scenario that turns blending off could leak into a
  concurrently-running scenario that expects it on. I resolved this myself with a
  thread-local flag defaulting to "on" (each test thread gets a fresh copy, which
  happens to implement the "reset before each scenario" rule for free), but a book
  covering multiple languages might want to flag this: "if your test runner
  parallelizes by default, make sure the switch doesn't leak across tests."

## Hard to translate

- **The `± 1` file-value tolerance vs. the default `± 0.0001` color tolerance** are two
  different comparison functions operating on two different domains (integer triples
  from a parsed PPM vs. float triples in memory), and the scenarios mix both kinds
  freely (e.g. `chapter01-plate.feature`'s `ppm_pixel(...) = (128, 128, 128) ± 1`
  alongside `ppm_pixel(...) = (0, 0, 0)` with no tolerance on the same scenario). Not
  hard exactly, just something I had to write two small equality helpers for
  (`colors_eq` at 0.0001, and a manual per-component `abs() <= 1` check for PPM pixel
  triples) rather than one generic "approx" function, since Rust has no operator
  overloading for a custom "plus-or-minus" comparison the way the prose's `± 1` notation
  implies.
- **Scenario Outlines** (`chapter01-srgb.feature`) don't map to a single Rust test
  function with a data table the way they would in a framework with native
  parameterized tests (e.g., `#[rstest]` — a crate, so off-limits here). Stdlib
  `#[test]` has no built-in table-driven test support, so I used a small `macro_rules!`
  to expand each Examples row into its own named `#[test]` function. It works and each
  row gets its own pass/fail line, but it's boilerplate that a language with native
  parameterized tests wouldn't need, and I could see a less experienced reader looping
  over the table in one `#[test]` and asserting in a loop instead, which would collapse
  8-10 scenarios into one pass/fail signal and hide which specific example failed. The
  book's "every scenario is a separate test" spirit deserves a one-line callout that
  languages without table-driven tests may need this kind of workaround.

## Failures

None. All 59 translated scenarios pass, and all five rendered files
(`out/gray-match.ppm`, `out/quarter-match.ppm`, `out/ramp.ppm`, `out/clamp-pair.ppm`,
`out/plate-01.ppm`) are byte-for-byte identical to the book's reference files, not just
within the `± 1` tolerance the scenarios ask for. That includes the 70-character
line-wrap scenario, which is the kind of thing that's easy to get subtly wrong (fencepost
error in the greedy packing) and didn't need a second attempt.

## Prose

- Clear and well-paced overall for a "one evening" chapter. The 128-vs-188 hook in the
  opening section earns its place — it's the reason to keep reading the sRGB section
  instead of skimming it.
- The two places I had to stop and re-read are both listed under Ambiguities above
  (range inclusivity introduced after it's used; coordinate signedness never stated).
  Neither cost more than a minute, but both were "wait, go back" moments rather than a
  smooth read.
- §1.5's four-step conversion order (clamp, encode, multiply, round) is stated crisply
  and I didn't need to consult the scenario to get it right on the first try — worth
  noting as an example of the prose doing exactly enough work.
- The "204 pixels of c are color(...)" step phrasing ("N pixels of c are color(...)")
  in `chapter01-gray-match.feature` doesn't appear anywhere in the prose narration of
  §1.6 — the prose describes the checkerboard/gray/gray layout but never mentions that
  the tests will also assert a pixel *count*. Not a real problem (the count is a trivial
  consequence of the layout), but it's the one place a scenario introduces a new kind of
  assertion ("count of pixels matching a color") without the prose ever setting it up.

## Would change

- State the inclusive-range convention once, early (e.g., in §1.3 when `canvas(width,
  height)` and pixel indexing are first introduced), rather than in §1.6 after two
  pseudocode blocks have already used ranges.
- Add one sentence about coordinate signedness for `write_pixel`/`pixel_at` — even just
  "x and y may be negative; use a signed integer type for them" — since the
  out-of-bounds scenario forces every reader in a language with unsigned array indices
  (Rust, Go's common style, etc.) to make the same silent call.
- A short callout that the linear-blending switch is a classic parallel-test-runner
  trap would help readers in languages (Rust, Go, Java with JUnit5 parallel execution)
  where "just use a global" is not automatically safe.
- Mention scenario outlines' relationship to table-driven testing (or its absence) in
  §1.1, alongside the other notation notes, since it's the first and only place in this
  chapter that needs it.

## Results

- **Total scenarios translated:** 59 (7 features; `chapter01-srgb.feature`'s two
  Scenario Outlines expand to 10 + 8 = 18 individual cases, all others are 1:1).
- **Passed:** 59. **Failed:** 0.
- **Renders:** all 5 output files are byte-identical to the shipped reference PPMs.
- **Time hotspots:** none really — this was a genuinely one-evening chapter. The only
  place I spent more than a few minutes was double-checking the `plate_01` row math
  (inclusive ranges, `top`/`top+39`/`top+45`/`top+84` banding) against the pixel
  assertions in `chapter01-plate.feature`, because that's the one function whose
  pseudocode is dense enough that a fencepost error wouldn't have been obvious from
  reading it alone — only from running the scenario. Runtime cost was negligible: the
  full suite (59 tests including two reference-image diffs against a 10,543-line PPM)
  runs in well under half a second.
