# Rust catch-up — chapters 16-17 (round: post chapter-17 collection)

This is a catch-up pass on an already-collected, already-green Rust implementation
of chapters 1-17. Two feature files had changed since collection:
`features/chapter17-cache.feature` (two new atlas scenarios) and
`features/chapter16-composites.feature` (two scenarios renamed/re-scoped, no new
assertions). Task: bring `tests/` back in line, make `cargo test --release` pass,
re-render chapters 16-17 and diff against `reference/`, update `README.md`, report
here.

## Result

- `cargo test --release`: **525 passed, 0 failed, 0 ignored** across 91 test
  binaries plus the lib/bin unit-test harnesses and doc-tests (0 each). Before this
  pass the suite compiled and passed at **523** (the two new atlas scenarios simply
  didn't exist yet in `tests/cache17.rs`), so nothing regressed — the delta is
  exactly the two new scenarios landing green under fixed code.
- `cargo run --release --bin render_all` regenerated all 61 renders to `out/`.
  `max_channel_difference` for every chapter 16-17 render against
  `reference/chapter-{16,17}/`:

  | render | max_channel_difference |
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

  All nine are byte-exact, matching what `tests/plate16.rs` and `tests/plate17.rs`
  already assert (`<= 1`, but the reference impl and this one agree exactly).

## Catch-up

**`features/chapter17-cache.feature`, "A taller bitmap that fits the width stays on
the shelf and raises it"** (new). `tests/cache17.rs` had no translation of this
scenario at all — it only covered the original four scenarios. Added
`a_taller_bitmap_that_fits_the_width_stays_on_the_shelf_and_raises_it`, translating
the four `atlas_add` calls verbatim. **Failed on the old code**: the previous
`atlas_add` required an incoming bitmap's height to be `<=` the shelf's *current*
height to stay on the shelf (`b.height <= a.shelf_height`), so a bitmap taller than
the shelf but still narrow enough to fit closed the shelf and started a new one
under it — landing the 12-tall bitmap at `(0, 8)` instead of `(10, 0)`. **Fix**:
rewrote `atlas_add` in `src/lib.rs` to follow `chapter-17.html` §17.2's pseudo-code
literally: a bitmap that fits the shelf's *width* stays on it regardless of height,
and the shelf's height grows to `max(shelf_height, bitmap.height)` (`shelf_top` only
moves on the next width-triggered shelf close). Confirmed by hand-tracing all four
`atlas_add` calls in the scenario against the new code before running it.

**`features/chapter17-cache.feature`, "A bitmap the atlas can never hold leaves the
shelf alone"** (new). Same situation: entirely missing from `tests/cache17.rs`.
Added `a_bitmap_the_atlas_can_never_hold_leaves_the_shelf_alone`. **Failed on the
old code** (by inspection — the loop-based implementation closed the current shelf
*before* checking whether the incoming bitmap could ever fit anywhere, so a
too-wide-for-the-whole-atlas bitmap arriving on a non-empty shelf would leave
`shelf_top` advanced and `cursor_x`/`shelf_height` reset to 0/0 even though it
returned `None` — the next bitmap would then land on a *new* shelf at `(0, new_y)`
instead of continuing the old one at `(10, 0)`). This exact divergence was already
flagged as a known, silent gap in the previous `README.md` ("Both give `None` and
happen to leave the same shelf position behind for the scenario's own numbers... —
nothing currently pins the shelf state after a failed `atlas_add`, so this
divergence is silent") — this new scenario is precisely what closes that gap.
**Fix**: same rewrite as above — `chapter-17.html`'s pseudo-code checks
`bitmap.width > atlas.width or bitmap.height > atlas.height` and returns `None`
*before* touching any shelf state, so a too-wide bitmap never mutates
`shelf_top`/`cursor_x`/`shelf_height`. Traced the scenario's three `atlas_add` calls
by hand against the new code: `(10,8)` → `(0,0)`, shelf becomes `cursor_x=10,
shelf_height=8`; `(40,5)` → `40 > 32` → `None`, shelf untouched; `(10,8)` → fits on
the still-open shelf → `(10,0)`. Matches the scenario exactly.

**`features/chapter16-composites.feature`, scenario rename** (no logic change).
The feature file's 4th scenario is now "Two more real glyphs' bounds" (checks `o`
and `H`) and its 5th is now "Bounds are tight, not the control box: a hand-written
bump stops where its curve does" (the hand-written JSON font with the quadratic
bump). The old test file had these swapped in name only: the `o`/`H` test was
called `bounds_are_tight_not_the_control_box` and the hand-written-bump test was
`a_font_can_be_written_by_hand_and_a_bumps_bounds_stop_where_the_curve_does`. The
actual assertions in each were already correct for what the *current* feature file
says — this never failed a test, it was purely a stale name that no longer matched
which scenario carries the "tight bounds" claim. **Fix**: renamed
`bounds_are_tight_not_the_control_box` → `two_more_real_glyphs_bounds`, and
`a_font_can_be_written_by_hand_and_a_bumps_bounds_stop_where_the_curve_does` →
`bounds_are_tight_not_the_control_box_a_hand_written_bump_stops_where_its_curve_does`.
Cosmetic only; ran `cargo test --test composites16` before and after to confirm
zero behavior change.

Verified scope: enumerated every chapter 16/17 `.feature` file (10 total:
`chapter16-{font,plate,path,composites,contours}.feature`,
`chapter17-{bitmap,fudge,lcd,plate,cache}.feature`) and compared its
`^  Scenario:` count against its test file's `#[test]` count. Every file matches
exactly except the two above, which are now fixed. No other drift found.

## Ambiguities

- The old `README.md` already flagged the exact ambiguity this catch-up closes:
  whether a too-wide-for-the-atlas bitmap arriving mid-shelf should disturb the
  current shelf on its way to returning `None`. `chapter-17.html`'s pseudo-code
  settles it (check "can never fit" first, before any shelf mutation), and the new
  scenario now pins that answer instead of leaving it "silent." Nothing else new to
  flag here — the two atlas scenarios only reinforce what the pseudo-code already
  states, hand-tracing them left no remaining gap.
- Minor: the `atlas_add` pseudo-code's first line — `if bitmap.width > atlas.width
  or bitmap.height > atlas.height: return none` — is *stricter* than "can this ever
  fit," in one sense: it also rejects a bitmap whose height alone exceeds the
  atlas's height even if some future, differently-packed shelf arrangement could
  theoretically still place it (it can't, actually, since the atlas height is fixed
  and shelves only stack downward, so this is just the correct early-out, not a
  looser approximation — noting it only because it's worth double-checking if a
  future scenario ever adds atlas resizing).

## Failures

None. All 525 scenarios pass; all nine chapter 16/17 renders diff `0` against
`reference/`.

## Prose problems

None found in this pass — this was a narrow catch-up on two feature files, not a
full cold read of chapters 16-17's prose. (See the original reader's `FEEDBACK.md`
notes already folded into `README.md`'s "Chapter 16 notes" / "Chapter 17 notes" /
"Mutation testing" sections for prose issues found during the original cold read
and prior catch-up rounds — e.g. the `flip_trap` closed-vs-open-subpath trap, the
`lcd_filter` zero-vs-edge-padding ambiguity.)

## Concrete changes

1. `src/lib.rs` — rewrote `atlas_add` to match `chapter-17.html` §17.2's
   pseudo-code order exactly: early-return `None` for a bitmap too wide or tall for
   the atlas *before* touching shelf state; only then close the shelf on a
   width-only failure; only then check height against the (possibly reset) shelf;
   grow `shelf_height` to `max(shelf_height, bitmap.height)` on placement instead of
   only ever setting it once per shelf. Replaced the old `loop { ... }` retry
   structure (which could close a shelf on a bitmap that could never fit anywhere)
   with a straight-line translation of the four-step pseudo-code.
2. `tests/cache17.rs` — added
   `a_taller_bitmap_that_fits_the_width_stays_on_the_shelf_and_raises_it` and
   `a_bitmap_the_atlas_can_never_hold_leaves_the_shelf_alone`, translating the two
   new Gherkin scenarios directly (now 6 `#[test]` fns, matching the feature file's
   6 scenarios).
3. `tests/composites16.rs` — renamed two test functions to match the feature
   file's current scenario titles/scope (no assertion changes):
   `bounds_are_tight_not_the_control_box` → `two_more_real_glyphs_bounds`;
   `a_font_can_be_written_by_hand_and_a_bumps_bounds_stop_where_the_curve_does` →
   `bounds_are_tight_not_the_control_box_a_hand_written_bump_stops_where_its_curve_does`.
4. `README.md` — rewrote the `Atlas` paragraph in "Chapter 17 notes" to describe
   the new pseudo-code-exact implementation and drop the now-resolved "divergence is
   silent" caveat, replacing it with a pointer to the new scenario that pins the
   behavior and a short history of why the old retry-loop version failed it.
