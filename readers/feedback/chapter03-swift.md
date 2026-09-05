# Catch-up pass: Swift reader, chapters 1–3

## Missing scenarios found

Diffing every `Scenario`/`Scenario Outline` name in `features/*.feature` against
the `scenario(...)` calls in `Sources/Tests.swift` turned up gaps only in
chapter 1 (chapters 2 and 3 were already complete):

`features/chapter01-mix.feature`
- "The light's way never clamps"
- "The switch can be passed instead of set"
- "The browser's way clamps each end before encoding it"
- (the existing test named "The ends of a mix are its inputs either way" was
  renamed to match the feature file exactly: "…either way, when they're in
  range" — same assertions, name only.)

`features/chapter01-ppm.feature`
- "A line of exactly 70 characters is allowed"
- "Counting the distinct values in a file"
- "Files of different sizes are as different as it gets"
- "The same width with a different height is still a different size"

## What failed before the fix, and why

`mix()` only took three arguments and, in browser mode (`linearBlending =
false`), encoded `a` and `b` directly without clamping them first:
`encode(a)` / `encode(b)` on out-of-[0,1] colors. Adding "The browser's way
clamps each end before encoding it" (`mix(color(1.5, 0.5, -0.2), color(0,0,0),
0)` should equal `color(1, 0.5, 0)`) failed against the old code: `encode(1.5)`
evaluates the sRGB curve on an out-of-range input (≈1.194) instead of clamping
to 1 first, so `mix` returned something far from `(1, 0.5, 0)`. This is
exactly the trap called out in the book's writing notes — clamping the *ends*
before encoding, not the lerp result — and the old implementation had no
clamp at all on that path, so it would have gotten *both* wrong (a clamp-the-
result version would have coincidentally passed at t=0 and t=1, but not this
one, since it clamped nowhere).

Fixed by adding a `clamp01(Color)` helper and applying it to `a` and `b`
before encoding, and by adding the optional fourth `Bool?` parameter (default
`nil`, falling back to the global `linearBlending` switch) so `mix(a, b, t,
true/false)` can override the switch for one call without touching it — used
for "The switch can be passed instead of set", which also checks the global
switch is left on afterward.

The other new scenarios ("The light's way never clamps", the two
different-size `max_channel_difference` cases, "A line of exactly 70
characters", "Counting the distinct values in a file") all passed immediately
— `distinctValues` and `maxChannelDifference` were already implemented
correctly and just hadn't been exercised by a named test yet.

## Final counts

```
chapter 1:  scenarios: 66  passed: 66  failed: 0
chapter 2:  scenarios: 35  passed: 35  failed: 0
chapter 3:  scenarios: 37  passed: 37  failed: 0
scenarios: 138  passed: 138  failed: 0
```

All chapter 3 renders (`out/fan-bresenham.ppm`, `out/fan-wu.ppm`,
`out/fan-coverage.ppm`, `out/plate-03.ppm`) and all chapter 1/2 renders remain
byte-identical to `reference/`. `README.md` updated for the new scenario
count (131 → 138); no command changed.
