# Chapter 1 feedback — implemented in Lean 4.29.1, core only

## Ambiguities

**"The ends of a mix are its inputs either way" is not true.** With the switch off,
`mix(a, b, 0) = decode(encode(clamp(a)))`, which is `clamp(a)`, not `a`. The very next
scenario in the same file proves it: given `a ← color(1.5, 0.5, -0.2)`, `mix(a, b, 0) =
color(1, 0.5, 0)`. The two scenarios only coexist because the first one's inputs happen
to be in range. The title claims something the chapter has just disproved. Guessed: the
title means "when the ends are in range".

**`mix` with linear blending ON is never clamped, and the chapter never says so.**
The correct formula is given as `a + (b - a) * t` with no clamps at all, while the
browser formula gets an explicit `a' ← clamp(a)` line and a scenario. Since § 1.2 makes
a point of colors legitimately leaving 0..1, a reader can reasonably wonder whether the
light-space mix clamps too. No scenario pins it. Guessed: no clamping, exactly as
written.

**Two notations for quoting file lines, only one defined.** § 1.1 defines
`lines 4-5 of ppm are` followed by a docstring block. The PPM feature also uses
`line 4 of ppm is "255 0 0 0 188 0 0 0 128"` (singular, inline string) and
`ppm ends with a newline character`, neither of which appears in the notation list.
Guessed: same comparison, one line, and `String.endsWith "\n"`.

**`≤` is never defined.** Every reference-image scenario ends
`max_channel_difference(ppm, ref) ≤ 1`, and `distinct_values(ppm) = 183` is an exact
integer `=`. § 1.1 defines `=` for floats (tolerance) and for integer triples (exact),
but not `≤`, and not `=` on a bare integer. Guessed: exact integer comparison
throughout, no tolerance.

**"exactly N pixels of c are some color" — tolerance on the match, exactness on the
count.** § 1.1 says these "are loops over the whole canvas comparing with the usual
tolerance. The count is exact." That is clear once parsed, but the sentence reads as if
"exact" might apply to the comparison. Guessed: `approxEq` per pixel, `==` on the count.

**`distinct_values` counts numbers, not colors.** "returns how many different numbers
appear in the pixel data" is unambiguous in isolation, but the word *values* invites
"distinct pixels". The `= 4` scenario only disambiguates if you work the arithmetic
({0, 128, 188, 255}) rather than counting the 3 distinct pixels. A one-word change to
"distinct channel numbers" would settle it in the feature file itself.

**The 70-character rule and the separating space.** "before adding one, if the line
would end up longer than 70 characters, start a new line instead" — the "would end up"
length has to include the space you are about to insert. The exactly-70 scenario does
pin it, but only after you have already guessed right; getting it wrong shifts by one
token and the scenario reads as a mystery. Guessed: `len(line) + 1 + len(token) > 70`.

**Empty rows.** A canvas of width 0 produces an empty pixel-data line per row under
"Each row of pixels starts on a fresh line regardless." Untested, undefined. I emit a
blank line.

**Line numbering assumes exactly three header lines.** `line 4 of ppm` is only
well-defined because your own writer emits no comments. Fine for a writer, worth a word
for the reader helpers, which are told to tokenise rather than count lines.

## Hard to translate

**The global switch.** This was the only genuinely awkward requirement. Lean has no
mutable globals in pure code; the closest thing is `initialize r : IO.Ref Bool ← IO.mkRef
true`, which works but drags `mix` into `IO`:

```lean
initialize linearBlendingRef : IO.Ref Bool ← IO.mkRef true
def mix (a b : Color) (t : Float) : IO Color := do
  return mixWith (← linearBlendingIsOn) a b t
```

That infects `ramp_pair` and `plate_01` — both are `IO Canvas` — which in turn means the
plate can't be a plain `def` alongside `ramp` and `clamp_pair`. I kept a pure
`mixWith (linear : Bool) a b t` underneath so the actual arithmetic stays testable
without IO. The aside says "If your language objects to a mutable global on principle,
as Swift 6 does, give `mix` an optional last argument whose default is the switch" —
Lean objects, but that escape hatch doesn't work either, because a Lean default argument
is a pure expression and can't read a ref. The thing that *forces* a real global is one
step: `And linear blending is on` at the end of the plate scenario. Without it, threading
a `Bool` parameter satisfies every other scenario, `plate_01` stays pure, and the chapter
loses nothing.

**Operator overloading: `c * 2` does not compile.** Lean's arithmetic elaborator
(`binop%`) unifies the operand types of `*` before instance resolution, so with
`HMul Color Float Color` in scope, `c * 2` still reports

```
failed to synthesize instance of type class OfNat Color 2
```

and `c * 0.5` reports `OfScientific Color`. The fix is an annotation at every call site,
`c * (2.0 : Float)`, which makes the scenario read worse than the book's. `c1 + c2`,
`c1 - c2` and `c1 * c2` (Hadamard) all overload cleanly. This is not exotic — the same
bites any language that unifies numeric literals with the operand type — and the
operators bullet in § 1.1 would be a good place for one sentence about it.

**Mutable canvases.** A `Canvas` is a value; `writePixel c x y col` returns a new one.
Because Lean's `Array.set!` mutates in place when the array is uniquely referenced, the
book's pseudo-code transliterates with identical cost, but the *shape* changes: every
statement `write_pixel(c, x, y, col)` becomes an assignment `c := writePixel c x y col`
inside `Id.run do ... let mut c := ...`. `fill(c, color)` has the same problem. The book
consistently writes these as statements with no return value, which quietly assumes
reference semantics. One line saying "in a language without mutable objects, have
`write_pixel` return the new canvas" would cover it, and it costs the imperative reader
nothing.

**Signed coordinates against unsigned indices.** The chapter is right that you need a
signed type, and Lean makes this mildly annoying: `x y : Int` for the API,
`Int.toNat` inside, `Nat` loop variables coerced at the call site. It works, and the
out-of-bounds scenario is what forced it, so the warning earned its place.

**File IO** was a non-event: `IO.FS.readFile` / `IO.FS.writeFile`, plus
`IO.FS.createDirAll "out"` because Lean won't create the directory for you.

**Splitting on whitespace.** In Lean 4.29 `String.split` returns `Std.Iter String.Slice`,
not a list of strings, and there is no whitespace-splitting helper. The book's "split the
text on whitespace" cost me a build error and a rewrite as
`replace "\r"/"\n"/"\t"` then `splitOn " "`. Not the book's fault, but the instruction
does assume a stdlib primitive that isn't universal.

**No test framework.** Written by hand: ~85 lines of
`ReaderT (IO.Ref (Array String)) IO`, one `r.run "name" do ...` per scenario, PASS/FAIL
per line, non-zero exit on any failure. The runner resets the switch to on before every
scenario, per § 1.7's rule. Lean has no parallel test runner, so the thread-local
warning didn't apply.

## Failures

None. 60 of 60 scenarios pass. All five renders came out **byte-identical** to
`reference/chapter-01/` (`cmp` clean on all five), so the `± 1` and `≤ 1` slack was never
needed — Lean's `Float.pow` agrees with whatever produced the references to the last
rounding.

## Prose

**§ 1.7 is the densest paragraph in the chapter and carries the most load.** The
clamp-placement argument ("They have to be on the ends, before encoding, not on the
result: clamping the result gives a different, wrong midpoint") is correct and important
and gets one sentence, wedged between the browser digression and the trap box. The
`decode` at the end of the naive formula gets an explanation ("The decode at the end
isn't a typo"), which is the right instinct; the clamp placement deserves the same.

**`ramp_pair`'s pseudo-code flips the global switch 800 times.** Inside the `x` loop, per
column, twice. It works, and the "leave it as you found it" line at the end of
`plate_01` is a nice touch, but hoisting the two mixes into two separate loops would read
better and would model the switch as what it is — a mode, not a per-pixel parameter.
In a monadic language the in-loop version is also what forces the whole render into IO.

**Nothing was out of order.** § 1.4 before § 1.5 before § 1.7 is exactly right, and
putting the notation contract (§ 1.1) before any code is worth the page.

**Missing:** a debugging aid for the plate. Twelve `ppm_pixel` assertions plus a 721 KB
diff is all you get; when the plate is wrong there is nothing intermediate to check. One
printed number — the exact `t` at `x = 200` is `200/399 = 0.501253…`, which is why the
gray midpoints land on 128 and 188 rather than 127/187 — would save a reader an hour.

## Would change

1. **Drop or reword `And linear blending is on` in the plate scenario.** It is the single
   step that makes a real mutable global mandatory. Everything else in the chapter is
   satisfiable by `mix(a, b, t, linear)` with a defaulted parameter, which is what a pure
   language wants and which the imperative reader can still implement as a global.
   Alternatively keep the step but phrase the requirement as "the switch is back in its
   default state", which a parameter-threading implementation satisfies vacuously.
2. **Present `mix(a, b, t, linear = LINEAR_BLENDING)` as the primary signature** in § 1.7,
   with "most languages let you leave the last argument off" as the note, rather than the
   reverse. The imperative pseudo-code is unchanged; the functional reader gets a legal
   route in the main text instead of in a Swift-specific aside.
3. **Add one sentence to the operators bullet in § 1.1**: in statically typed languages
   that unify numeric literals with the operand type, `c * 2` may need an explicit
   `c * 2.0f` / `c * (2.0 : Float)`, or a named `scale`. Lean, and I'd expect Scala and
   some C++ setups, all hit this.
4. **Say once that `write_pixel` and `fill` may return a new canvas.** Two clauses in
   § 1.3 next to "put a color at a position". Nothing else in the chapter changes.
5. **Rename the mix scenario** "The ends of a mix are its inputs either way" →
   "…when the ends are in range", and add a scenario for `mix` with linear blending **on**
   and an out-of-range end, pinning that it does *not* clamp. That asymmetry is a real
   design decision and currently only exists in prose.
6. **Promote "parse once and keep the numbers" from a parenthetical to a recommendation,
   or ship `parse_ppm` as a fourth helper.** In my run the naive re-split already accounts
   for 1.6 s of a 2.5 s suite at chapter 1, on a 400×180 image. It won't survive
   chapter 6.
7. **Change "how many different numbers" to "how many different channel numbers"** in the
   `distinct_values` description.
8. **State the 70-column rule as an inequality**: "start a new line when
   `len(line) + 1 + len(token) > 70`". The prose version is correct but requires the
   reader to notice that the separating space counts.

## Results

- **60 scenarios, 60 passed, 0 failed.** (equality 3, colors 6, canvas 6, sRGB 20 —
  4 scenarios plus 16 Examples rows — PPM 11, gray-match 3, mix 7, limits 3, plate 1.)
- **Renders:** `out/gray-match.ppm`, `out/quarter-match.ppm`, `out/ramp.ppm`,
  `out/clamp-pair.ppm`, `out/plate-01.ppm` — all five byte-identical to the references.
- **Time hotspots:**
  - Clean `lake build` (library + both executables, no cache): **2.5 s** wall. Incremental
    rebuild after editing `Tests.lean` alone: ~2.3 s. Lean compile time is not a problem
    at this size, but `Tests.lean` is a single 430-line `main`, and Lean elaborates a
    `do` block of that length as one unit — splitting the suite per feature file would
    keep incremental edits cheap in later chapters.
  - `lake exe tests`: **2.8 s** wall, of which roughly **1.6 s** is the plate scenario
    alone: 13 `ppm_pixel` calls, each re-tokenising the 721 KB PPM (~120 ms per parse) as
    the book's "the obvious implementation re-splits it on every call" describes. Most
    of the remaining ~1.2 s is the other four reference comparisons re-parsing their PPMs
    the same way; every scenario that doesn't touch a file is under 10 ms.
  - `lake exe render`: under 0.2 s for all five images. Rendering is free; parsing text
    is the whole cost of this chapter.
