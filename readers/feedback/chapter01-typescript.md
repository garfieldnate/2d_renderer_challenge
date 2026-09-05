# Chapter 1 feedback — TypeScript / Deno 2

60 scenarios (scenario outlines expanded), 60 passing, first run. All five renders are
byte-identical to the reference PPMs, not merely within the allowed ±1. The chapter is
accurate; almost every number in it is reproducible to the digit. What follows is the
criticism.

## Ambiguities

**The clamp-before-encode justification is wrong.** §1.5: *"Clamp before you encode, because
`encode` is only defined on 0..1 and will happily hand you a number over 1 or the square root
of something negative if you feed it garbage."* Neither hazard exists for the `encode` printed
two sections earlier. Its first branch is `l ≤ 0.0031308 ? l * 12.92`, so every negative input
takes the linear branch and never reaches `pow`; and `pow(l, 1/2.4)` for `l > 1` is perfectly
well defined. I verified this: clamping *after* encoding instead of before is mathematically
identical for this function and passes all 60 scenarios. The stated order is right, but the
reason given for it is not, and a reader who checks the reasoning will conclude the rule is
optional. Guessed: follow the stated order anyway.

**Where the browser mix clamps.** The printed formula is
`mix(a, b, t) = decode( encode(a) + (encode(b) - encode(a)) * t )` with no clamp in it. The
clamp appears only in prose, two paragraphs later: *"the browser's way clamps each end before
encoding it."* That sentence is unambiguous once you find it, but it is separated from the
formula it corrects by the whole "In the GUI" digression. I guessed correctly (clamp each end
before encoding), but see **Mistakes that stay green** — no scenario can tell my guess from the
wrong one.

**Function names for subtract, scale and multiply.** §1.1 promises *"If it doesn't [have
operator overloading], it's a function called `add`"* and warns *"don't rename them casually:
later chapters refer back to them."* Only `add` is named. TypeScript has no operator
overloading, so I invented `sub`, `scale` and `multiply` and will find out in chapter 4 whether
I guessed the book's names.

**`max_channel_difference` and the header.** *"returns the largest difference between any pair
of corresponding numbers"* — the header contains numbers too (`5 3 255`). I read "corresponding
numbers" as pixel data only, which is clearly the intent, but the sentence doesn't say so.
"Largest difference" also leaves signed-vs-absolute open; the `= 188` example forces absolute,
so it's self-correcting.

**The greedy-packing unit.** *"Emit values separated by single spaces; before adding a value…"*
— a "value" could plausibly be a pixel triple rather than a single channel. The 10×2 scenario
settles it (line 4 ends `… 255 231`, mid-pixel), but the settling is in the test, not the prose.

**`ramp_pair` leaves the switch on by accident.** The pseudo-code sets the switch off, then on,
inside the `x` loop, and never restores it; the plate scenario's final step
`And linear blending is on` passes only because the *last* assignment in the loop body happens
to be `on`. A reader who computes `light` before `naive` — a harmless reordering — fails that
step for a reason that has nothing to do with the picture. Nothing in the chapter warns of this.

**`≤` versus `<` on the default tolerance.** The feature narrative says `|a - b| ≤ 0.0001`; the
prose in §1.1 says *"within 0.0001 of each other"*. No scenario lands on the boundary, so it
doesn't matter, but I used `≤`.

**Trivial, but I checked twice:** the prose lists the black gaps as *"rows 40 to 44, 85 to 89,
130 to 134 and 175 to 179"*. The last one isn't a gap between bands, it's the bottom margin.
Consistent with the pseudo-code; just briefly confusing to describe them as one kind of thing.

## Hard to translate

Little of it. Deno's test runner is a plain `Deno.test(name, fn)`, so:

- **Scenario Outlines** become a `for` loop emitting one `Deno.test` per row. Deno requires
  unique test names, so I appended the row values to the name. Mechanical.
- **The global switch.** `Deno.test` is serial by default, so a module-level `let` works, but
  the chapter's warning applies to anyone who reaches for `--parallel`. I wrapped every mix
  scenario in a helper that sets the switch on before and after the body, which is the
  "reset before each scenario" discipline the chapter asks for.
- **`And ref ← read_file(...)` inside a `Then` block.** This is a Given-shaped step sitting in
  a Then run, in three scenarios. Harmless when hand-translating, ugly under a real Cucumber
  harness. Same for `When ppm ← canvas_to_ppm(c)` appearing *after* `Then` steps in
  "One pixel in four" and "Clamping changes the color".
- **`ppm ends with a newline character`** plus **`every line of ppm is at most 70 characters`**
  needed a `lines_of()` helper, because splitting a newline-terminated string on `\n` yields a
  trailing empty element that is not a line. Obvious in hindsight, five minutes lost.
- **Docstring blocks** are indented in the `.feature` files; each expected line needs trimming
  before comparison. Worth one sentence in §1.1's notation list, since the notation list covers
  everything else.

## Failures

None. All 60 scenarios pass, and all five files are byte-identical to the references — the ±1
slack was never needed. TypeScript's `Math.pow` agrees with whatever the author used.

## Mistakes that stay green

I applied 40 mutations to the source and re-ran the suite. Three survived; two are real gaps.

| Mutation | Result |
|---|---|
| **`max_channel_difference` compares widths only, not heights** | **STAYS GREEN** — real gap |
| **Browser-mode `mix` clamps the *result* instead of each end before encoding** | **STAYS GREEN** — real gap |
| `to_byte` clamps after encoding instead of before | stays green, but it is not a bug (see Ambiguities) |
| `Math.floor` instead of `Math.round` in `to_byte` | caught |
| `Math.ceil` instead of `Math.round` | caught (by the exact `line 4` scenarios, not by the ±1 file comparisons) |
| No clamp at all in `to_byte` | caught |
| `>= 70` instead of `> 70` in the line wrap | caught |
| `> 71` (allowing a 71-char line) | caught |
| Line length measured without the separator space | caught |
| Line buffer not reset per row (rows not on fresh lines) | caught |
| Greedy packing treats a pixel triple, not a value, as the unit | caught |
| Canvas stored transposed (`x * height + y` in both write and read) | caught |
| `canvas(w, h)` treated as `(rows, cols)` | caught |
| `ppm_pixel` indexes `(x * height + y) * 3` | caught |
| `write_pixel` bounds use `>` instead of `>=` | caught |
| `write_pixel` skips the negative bounds check | caught |
| `encode` branches swapped | caught |
| `decode` branches swapped | caught |
| `decode` uses encode's threshold (0.0031308) | caught |
| `encode` uses decode's threshold (0.04045) | caught |
| `encode` with no linear segment (pure power) | caught |
| `decode` with no linear segment (pure power) | caught |
| `encode` exponent `1/2.2` instead of `1/2.4` | caught |
| `max_channel_difference` drops the size rule entirely | caught |
| `max_channel_difference` without `abs` | caught |
| `distinct_values` counts header tokens too | caught |
| `distinct_values` counts distinct pixels instead of values | caught |
| PPM data parsed from token 3 instead of token 4 | caught |
| PPM width/height read from tokens 2 and 3 | caught |
| Trailing newline omitted | caught |
| Header maxval `256` | caught |
| `mix` linear/browser branches swapped | caught |
| Browser-mode `mix` does not clamp at all | caught |
| Plate: light band starts at `top + 44` | caught |
| Plate: naive band 41 rows | caught |
| Plate: light band 41 rows | caught |
| Plate: naive and light bands swapped | caught |
| Plate: `t = x / 400` | caught |
| Plate: second pair at `top = 89` | caught |
| `gray_match` checkerboard inverted | caught |
| `gray_match` gray patch uses `128/255` without decoding | caught |
| `quarter_match` uses `(x+y) mod 4 == 1` | caught |
| `ramp` uses `x / 256` | caught |
| `clamp_pair` halves swapped | caught |
| `scale` multiplies only the red channel | caught |

Details on the two real gaps:

1. **Heights are never compared.** The only scenario exercising the size rule is
   `canvas(5, 3)` vs `canvas(3, 5)`, whose *widths* already differ. An implementation that
   checks width and forgets height passes everything here and then silently reports a small
   difference (or zero) when a later chapter compares a 400×180 render against a 400×200
   reference. The chapter's own motivation for the rule — *"a transposed render compares as a
   perfect match"* — is exactly the case a width-only check happens to cover, which is probably
   why it wasn't noticed.

2. **The browser mix's clamp is only probed at `t = 0`.** "The browser's way can't see past 1"
   uses `mix(color(1.5, 0.5, -0.2), color(0,0,0), 0)`. At `t = 0` the interpolation is the
   identity, so clamping the ends and clamping the output give the same answer:
   `clamp(decode(encode(1.5))) = clamp(1.4998) = 1`. My mutant that encodes unclamped and clamps
   the decoded result passes all 60 scenarios. At `t = 0.5` the two disagree loudly —
   `0.2140` correct versus `0.3137` for the mutant — but nothing tests that. Worse, this bug is
   *silent* in TypeScript specifically: the chapter's warning imagines a `pow` domain error, and
   `encode`'s linear branch means no such error ever fires.

## Prose

Clear throughout; I re-read only three places.

- The formula/clamp split in §1.7, above. Fix that and §1.7 is airtight.
- §1.5's *"square root of something negative"*. It sent me back to §1.4 to check whether I had
  copied `encode` wrong. I hadn't; the sentence is just untrue of the function as printed.
- §1.5 introduces `ppm_pixel`, `distinct_values` and `max_channel_difference` in one dense
  paragraph, 800 words before any of them is used. By the time I reached §1.6 I had to scroll
  back for the "everything after the fourth token" sentence. A four-line signature block, or
  moving the paragraph to the head of §1.6, would fix it.

Things that are unusually good and should not change: the "0 counts as a multiple" parenthetical
in `quarter_match`; *"Exactly 70 is fine"* as its own sentence with its own scenario; naming the
exact ranges 0..99 as inclusive in §1.1 before any pseudo-code uses them; and stating up front
that *"a marginal failure is a real one"* in the sRGB tables, which saved me from wondering
whether `0.0999` versus my `0.099853` was drift or a bug.

## Would change

1. **Add `max_channel_difference(canvas_to_ppm(canvas(5,3)), canvas_to_ppm(canvas(5,4))) = 255`**
   to the PPM feature. One line, closes the height gap.
2. **Add a browser-mix scenario at `t ≠ 0` with an out-of-range end**, e.g.
   `Given linear blending is off / a ← color(1.5, 0, 0) / b ← color(0, 0, 0) / Then mix(a, b, 0.5) = color(0.2140, 0, 0)`.
   One line, closes the clamp-placement gap and is the only way to catch it in a language whose
   `pow` doesn't complain.
3. **Put the clamp in the printed browser-mix formula**:
   `mix(a, b, t) = decode( encode(clamp(a)) + (encode(clamp(b)) - encode(clamp(a))) * t )`.
4. **Rewrite the clamp-before-encode justification.** The honest version is short: "encode's
   linear branch keeps negatives from reaching `pow`, so in most languages you'll get away with
   clamping late — but the definition clamps first, and in a language whose `pow` rejects
   negative bases you won't get away with it."
5. **Name `sub`, `scale` and `multiply`** alongside `add` in §1.1, given the explicit warning
   that later chapters refer back to these names.
6. **Make `ramp_pair` restore the switch explicitly**, or note that the plate's last step
   depends on the loop body's statement order.
7. **Reorder the `When`/`Then` steps** in "One pixel in four", "Clamping changes the color" and
   the two `read_file` scenarios so Givens and Whens precede Thens. Purely cosmetic for a
   hand-translator; not cosmetic for anyone actually running Cucumber.
8. **Mention docstring indentation** in the §1.1 notation list.
9. Consider dropping **"Linear blending is on by default"**, which the chapter already concedes
   tests the harness under any reasonable setup.

## Results

- **Scenarios:** 60 (7 Scenario Outline rows for encode, 7 for decode... precisely: 9 encode
  rows + 7 decode rows + 44 plain scenarios).
- **Passed:** 60. **Failed:** 0.
- **Wall clock:** 654 ms for the whole suite, including `deno` startup and type-checking.
- **Renders:** all five in `out/`, all byte-identical to `reference/chapter-01/`.

Time hotspots, all in the reference-comparison scenarios:

| Test | Time |
|---|---|
| The plate | 242 ms |
| The gray match, as a file | 68 ms |
| Clamping changes the color | 27 ms |
| Encoding stretches the dark end | 24 ms |
| One pixel in four | 20 ms |
| everything else | ≤ 13 ms |

The plate's 242 ms is not rendering — `plate_01()` takes 5 ms and `canvas_to_ppm` 22 ms. It is
the twelve `ppm_pixel` calls, each of which re-tokenizes the full 721 KB string, at ~15 ms
apiece. That is a consequence of the book's API shape: `ppm_pixel(ppm, x, y)` takes the *text*,
so the obvious implementation re-parses per call. Worth a one-line note in §1.5 telling readers
to memoize the parse if a later chapter's plate gets big, or the suite will get slow for a
reason that has nothing to do with the renderer.
