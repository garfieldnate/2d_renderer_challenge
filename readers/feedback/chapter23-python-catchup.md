# Chapter 22-23 catch-up pass

Diffed every scenario in `features/chapter22-*.feature` and
`features/chapter23-*.feature` against the existing Python implementation,
and re-read the clarified rules named in the catch-up task:

1. Bentley-Ottmann records its splits and cuts nothing during the sweep.
2. Stitching's furthest-right turn is now a formula (half by
   `cross(r, v)`/`dot(r, v)`, ties by `cross(u, v)`).
3. `is_corner`'s `sin(3)` is radians.
4. The MSDF tie-break's `o`.
5. The title's four effects are passes, each drawing the whole run before
   the next starts.

## What was already right

Items 1, 3, 4 and 5 were already implemented exactly as the clarified
prose now states:

- `_find_splits_bentley_ottmann` never mutates a segment's true `lo`/`hi`;
  it tracks a status item's *continuation* at the exact (unrounded) event
  point and records the rounded grid point as a split separately, exactly
  as "nothing is cut during the sweep" requires.
- `is_corner` uses `math.sin(3)` directly (Python's `sin` takes radians),
  matching "the sine of 3 radians."
- `bake_msdf`'s per-channel winner search already compares `d < best.d -
  1e-12` for a strict win and, within `1e-12`, prefers the smaller `o`
  (0 inside the curve, `|dot(direction, unit(p - end))|` at an end) —
  exactly the tie-break the atlas feature now states in prose.
- `title()` already loops `for effect in effects: for placement in
  placements: draw_effect(...)`, i.e. one pass per effect over the whole
  run, not per glyph — the bug the Rust reader's feedback described
  (off by 6, drawing per glyph) was never present here.

## What was wrong and is now fixed

`_turn_half(r, v)` (used by `stitch`'s furthest-right tie-break) encoded
the two halves the formula describes as *four* ordinal values instead of
two: `cross(r,v) < 0` -> 0, `cross(r,v) > 0` -> 2, and the `cross(r,v) ==
0` case split into 3 (`dot(r,v) > 0`) or 1 (`dot(r,v) < 0`). The book's
rule groups `cross(r,v) < 0` and `cross(r,v) == 0 and dot(r,v) > 0`
into the *same* lower half (0), with everything else in half 1. Because
`_turn_cmp` compares halves by plain `<`, the old encoding put the
`cross == 0, dot > 0` case (an outgoing edge that runs exactly back along
the incoming direction — a dead-end doubling back) in the highest ordinal
slot (3), so it would lose a half-comparison against a `cross(r,v) > 0`
candidate (encoded 2) even though the spec puts it in the winning lower
half. Rewrote `_turn_half` to return exactly 0 or 1 per the literal
formula:

```python
def _turn_half(r, v):
    c = cross(r, v)
    if c < 0:
        return 0
    if c == 0 and dot(r, v) > 0:
        return 0
    return 1
```

No pinned scenario currently puts a live "doubles straight back" candidate
in contention with another candidate at the same junction (the one
scenario that comes closest, "A spike that goes out and comes back adds
nothing," has its antiparallel duplicate edges cancelled by `keep_edges`
before `stitch` ever sees them), so this didn't fail any existing test —
it's a latent bug against the specification, fixed proactively since the
formula is now stated exactly enough to catch it.

## Scenario diff

No missing scenarios and no step shapes the runner didn't already handle.
Every scenario in both chapters' `.feature` files already had a
matching implementation and passed both before and after the
`_turn_half` fix (the fix's own trigger condition isn't exercised by the
current suite, so it changed no scenario's outcome — see above).

## Result

`python3 test_runner.py`: **827 of 827 green**, both before this pass's
one code change and after. All chapter 22/23 renders (`plate-22.ppm`,
`seal.ppm`, and chapter 23's nine: `primitive-fields.ppm`,
`error-map.ppm`, `fields-vs-paths.ppm`, `fillets.ppm`,
`transform-demo.ppm`, `atlas-corners.ppm`, `trap-shrink.ppm`,
`plate-23.ppm`, `title.ppm`) remain byte-exact against `reference/`.
