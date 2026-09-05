# Chapter 2 feedback — Lean 4 implementation

Read the chapter, wrote the code, translated all 28 scenarios, ran them, then
tried to break the suite. Everything passed and all four renders came out
byte-identical to `reference/chapter-02/`. What follows is the criticism.

## Ambiguities

**Byte numbering is never stated, and it isn't the same as pixel numbering.**

> "A 2-by-1 canvas is 11 bytes of header and 6 bytes of pixels."
> `Then p6 begins with "P6\n2 1\n255\n"` / `And length(p6) = 17` /
> `And byte 12 of p6 = 255`

The header is bytes 0–10 zero-based, so the first pixel byte is index 11, not
12. `byte 12 = 255` only works if bytes are counted from 1. I implemented
`eqByte` as `b[n-1]`. This sits four lines away from `ppm_pixel(p6, 1, 0)`,
which is zero-based, and one chapter away from `pixel_at(c, 0, 0)`. A reader
who assumes one convention throughout gets a red scenario for a green
implementation, and the failure message ("expected 255, got 0") points at the
writer rather than at the test. One sentence — "bytes are numbered from 1" —
fixes it, or renumber the scenario to 11/12/15.

**Does `paint_through` respect the linear-blending switch?**

> "in between it's `mix(pixel, color, coverage)`, the same mix as chapter 1, in
> light."

"the same mix as chapter 1" and "in light" pull in opposite directions: chapter
1's `mix` has a switch that can turn light off. I called `mix`, so
`paint_through` follows the switch, and since the switch defaults to on the
scenario "The arithmetic is on light" passes either way. Nothing in the book
distinguishes the two readings. If the intent is that coverage is *always*
composited in light (which I think it is, and which chapter 9 will presumably
depend on), say so and add a scenario that sets the switch off and still expects
`(188, 188, 188)`.

**`coverage_at` outside the buffer is undefined.** The chapter specifies only
the write side — "as with the canvas, writes outside the buffer are dropped" —
and `set_coverage`'s out-of-range scenario is the only one. I returned 0 for
out-of-range reads, by symmetry with `write_pixel`. It matters: the natural way
to write `plate_02` is to paint an 80×40 canvas through a 40×40 buffer and skip
the copying loop entirely, and that only works if reads outside return 0. A
reader who panics on out-of-range reads instead is equally compliant with the
text.

**`center_inside` appears only in the feature file.** The chapter's prose names
`coverage_buffer`, `coverage_at`, `set_coverage`, `ink`, `rasterize_centers`,
`coverage` and `rasterize`, but never `center_inside`; you learn it exists from
`chapter02-centers.feature`, where `center_inside(s, 2, 4) = 1` — a number, not
a boolean, unlike `inside`. I guessed it returns coverage (1.0/0.0) rather than
a bool, because `= 1` and `= 0` read as numbers and because `rasterize_centers`
wants a number.

**`disc_coverage()` gets prose where the other three renders get a listing.**
"which is `disc_centers` with `rasterize` in place of `rasterize_centers` and
nothing else changed" is unambiguous, but it's the only one of the four you have
to assemble yourself, and it's the one whose scenario has the tightest pixel
checks.

Minor: the "The center of pixel (x, y)" scenario puts a second `Given` after a
`Then`. Legal Gherkin, but it is the only scenario in either chapter that does
it, and a reader driving a real Gherkin runner may have to reorder it.

## Hard to translate

**Shapes as an interface — the easiest thing in the chapter, in Lean.** The book
says "A shape is a function from a point to yes or no. That's the whole
interface", and Lean takes that literally:

```lean
structure Shape where
  isInside : Float → Float → Bool
def circle (cx cy r : Float) : Shape :=
  ⟨fun x y => (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r⟩
```

No class, no instance, no dispatch table; a new shape is a lambda. The only
friction was cosmetic: the field can't be called `inside` if I also want a free
function `inside s x y`, so the field is `isInside`. Readers coming from a
language where "interface" means a class hierarchy may over-build this; a
sentence noting that a closure is enough would help more languages than it hurts.

**The coverage buffer as a value.** Identical in shape to chapter 1's canvas, so
chapter 1 had already paid this tax: `set_coverage` returns a new buffer and the
book's mutation-flavoured scenarios become shadowing.

```
When  set_coverage(cov, 2, 1, 0.75)    →    let cov := setCoverage cov 2 1 0.75
Then  coverage_at(cov, 2, 1) = 0.75
```

`Array.set!` updates in place while the array is uniquely referenced, so the
`painted_twice` copying loops cost what the book's pseudo-code costs. This is a
non-problem, and I'd say so in the book's "for functional languages" aside if
there is one: coverage buffers never alias.

**Bytes vs strings — the one place the chapter's change genuinely hurt.**
Chapter 1's `ppm_pixel`, `distinct_values` and `max_channel_difference` took a
`String`. Chapter 2 needs the same three names to take either a P3 string or a
P6 `ByteArray`, and Lean has no subtyping to lean on. Options were (a) convert
everything to `ByteArray` and make chapter 1's tests write `.toUTF8` at 30 call
sites, or (b) a one-method class. I took (b):

```lean
class PpmBytes (α : Type) where ppmBytes : α → ByteArray
instance : PpmBytes ByteArray := ⟨id⟩
instance : PpmBytes String := ⟨String.toUTF8⟩
def maxChannelDifference [PpmBytes α] [PpmBytes β] (a : α) (b : β) : Nat := ...
```

Ten lines, and every chapter-1 call site compiled unchanged — including
`max_channel_difference(p3, p6)`, which needs two *different* instances. Worth
noting in the book that this scenario exists, because it rules out the obvious
"just make it a byte function and convert at the boundary" design in a typed
language. `readFile` became `IO.FS.readBinFile`, and the P3 branch of the parser
does `String.fromUTF8!` and reuses chapter 1's tokenizer, exactly as the chapter
promises ("a P3 file is text that happens to be stored in bytes, so nothing
changes for chapter 1's tests" — true, all 62 stayed green).

**Performance of the supersampler: a non-issue, and the chapter aims the warning
at the wrong function.** "It's slow. Sixty-four shape queries per pixel" — 40×40
pixels × 64 samples is 102,400 closure calls, and `lake exe render` produces all
nine images (four of them supersampled, then magnified to 320×320 and 480×240,
then encoded) in **0.26 s** total. The supersampler never showed up in a profile.

What did cost 61 seconds in a single scenario was `distinct_values(p6) = 5` in
"The disc by centers". My chapter-1 implementation sorted the channel values and
counted runs; `Array.qsort` on 307,200 values of which only *five* are distinct
goes quadratic. Chapter 1 never noticed because its biggest image has 183
distinct values in 90,000. Chapter 2 hands you a 307,200-byte file and then asks
for its distinct count, which is exactly the adversarial input. Rewriting
`distinct_values` as a bucket count took the whole suite from 63 s to 2.8 s. This
is worth half a sentence in §2.2, because the trap is created by the chapter:
bigger files plus a `distinct_values` assertion on a nearly-uniform image.

## Failures

None. 90/90 on the first run of the chapter-2 suite, and

```
disc-centers: byte-identical      painted-twice: byte-identical
disc-coverage: byte-identical     plate-02: byte-identical
```

against `reference/chapter-02/`. The `± 1` tolerances were never needed.

The chapter-1 revisions were small: `mix` grew an optional fourth argument
(`def mix (a b : Color) (t : Float) (linear : Option Bool := none) : IO Color`,
and `mix a b 0.5 true` elaborates via the `Bool → Option Bool` coercion), the two
new mix scenarios passed as written, and I deleted the switch assertion from
Plate 1. 62/62.

## Mistakes that stay green

Each mistake was applied to the working implementation, rebuilt, and the whole
90-scenario suite run.

| mistake | caught? |
| --- | --- |
| sample points at cell corners, `i/8` not `(i+0.5)/8` | yes — 7 scenarios |
| `center_inside` tests the pixel corner `(x, y)` | yes — 4, incl. the scenario written for it |
| P6 header off by a byte (extra newline after `255`) | yes — 6 |
| P6 header ends with a space instead of a newline | **only 1** — see below |
| P6 reader skips two header bytes instead of one | yes — 5 |
| P6 reader assumes an 11-byte header | yes — 4 (all four reference-image scenarios) |
| `magnify` transposed (k·h by k·w, blocks swapped) | yes — 4 |
| `paint_through` ignores the existing pixel | yes — 7 |
| coverage divided by 63 | yes — 8 |
| `half_plane` with the normal's sign flipped | yes — 4 |
| `rectangle` with an exclusive boundary | **only 1** |
| `circle` with an exclusive boundary | **only 1** |
| `set_coverage` without the bounds check | **only 1** — the scenario written for it |
| `paint_through` reads `coverage_at(cov, y, x)` | yes — 3 |
| `paint_through` mixes paint→pixel (arguments swapped) | yes — 6 |
| `magnify` reads the source as `x*height + y` | yes — 2 (only the 80×40 plates) |

**Stays green — `rasterize` and `rasterize_centers` with width and height
swapped.** Building an `h`-by-`w` buffer instead of `w`-by-`h` passes all 90
scenarios. Every rasterization in the chapter is square: 16×16, 8×8, 40×40, and
the two `cov.width = 16` / `cov.height = 16` assertions can't tell the two apart.
The bug then lies dormant until chapter 3 rasterizes something wide. One
scenario fixes it — `rasterize(rectangle(0, 0, 2, 1), 4, 2)` with
`cov.width = 4`, `cov.height = 2`, `ink(cov) = 2` — and it is cheap insurance for
a mistake that is very easy to make in the `for y / for x` loop.

**Stays green — `coverage_at` outside the buffer returning 1 instead of 0.** No
scenario ever reads outside a buffer. This is the ambiguity above showing up as a
gap: the behaviour is unspecified, so a mutation of it can't be caught, but a
reader who *relies* on the 0 (to paint an 80×40 canvas through a 40×40 buffer,
which is the natural way to write `plate_02`) is relying on something the suite
never checks.

**Nearly green — the P6 header ending in a space.** Only "The header, then the
bytes" catches it, via `p6 begins with "P6\n2 1\n255\n"`. Every reader in the
book — mine, and any reader following the chapter's own instruction to "skip the
single whitespace byte after the last one" — round-trips a space-terminated
header perfectly, so all four reference-image comparisons stay green. That is
arguably correct behaviour (netpbm allows any single whitespace byte), but the
chapter says "followed by exactly one newline", and exactly one assertion in the
suite enforces it.

**Nearly green — boundary inclusiveness.** `rectangle` and `circle` made
exclusive are each caught by exactly one scenario, the `inside` one. The
rasterization scenarios can't help: sample points sit at `(i+0.5)/8`, which never
lands on `1.25`, `4.75` or a circle's edge, so open and closed shapes rasterize
identically. Fine as it stands, but it means the boundary rule is load-bearing on
a single line of a single scenario, and chapter 3's half-planes will care about
it a lot.

## Prose

Very good overall. §2.7 is the best thing in either chapter so far — the
coverage/opacity distinction is usually left implicit, and stating it as "two
different quantities that look identical" plus "every 2D renderer on earth has
that seam and nobody mentions it" earns the figure. The framing sentence
"Everything after this chapter is a faster way to compute the same number" is
worth the price of admission.

Ordering is sound. §2.2 (P6) and §2.3 (magnify) are announced as detours and
read like detours, which is the right call — they're needed by §2.5's render and
would be worse as a surprise in the middle of it.

**A numeric claim that doesn't hold.**

> "It's also correct to within 1/64 for anything with a straight edge"

It isn't; the bound is 1/16, four times bigger. For an axis-aligned edge at
`x = 2.5626`, the true coverage of pixel 2 is 0.4374 and the sampler returns
0.375 — an error of 0.0624, or 4/64. (Verified against my implementation; the
worst case is an edge sitting just past a column of sample centers, which loses a
whole column, i.e. half of 1/8.) The chapter half-contradicts itself two
paragraphs later: "The rectangle scenario below is exact, not approximate: its
edges at 1.25 and 4.75 land on sample boundaries" — which is exactly the
condition under which 1/64 holds. I'd rewrite as "its answer is always a multiple
of 1/64, and for a straight edge it's within 1/16 of the true area — exact when
the edge lands on a sample boundary."

**The other numeric claims check out.** 11-byte header and 17-byte file for 2×1;
`round(encode(0.9)·255) = 243`; centers give ink 80 against 25π ≈ 78.5398, and
the sampler gives 78.5 exactly (5024/64, and the sum is exact in binary floating
point because every term is a multiple of 1/64 — nice); 36/64 = 0.5625 for the
45° half-plane; 24 of 64 in figure 2.2.

**"The file is a quarter the size of the P3 version"** is the best case, not the
typical one. It holds when every channel is three digits plus a separator. For
Plate 1, the P3 file is 721,295 bytes and the P6 would be 216,015 — a third, not
a quarter. "Three to four times smaller" would be honest.

**Missing:** what `magnify(c, 0)` does (nothing in the chapter or the scenarios
constrains it, and 0 is a plausible off-by-one landing spot); whether
`rasterize`'s `w`/`h` are the buffer's or the shape's (obvious, but the green
mutation above shows it's untested); and, in §2.5, that `paint_through` must
tolerate a coverage buffer of a different size than the canvas, which is the
shortest route to `plate_02`.

## Would change

1. State the byte-numbering base in §2.2, or renumber the `byte N` assertions to
   be zero-based like `ppm_pixel`.
2. Add one non-square rasterization scenario. It is the only mutation on my list
   that survives the whole suite.
3. Specify `coverage_at` outside the buffer, and add the assertion. Then say in
   §2.5 that `paint_through` may be handed a smaller buffer, and `plate_02` gets
   shorter.
4. Fix the 1/64 claim to 1/16.
5. Add a `paint_through` scenario with the linear-blending switch off, to settle
   whether coverage compositing is always in light.
6. Half a sentence in §2.2: images are now big enough that an O(n log n)
   `distinct_values` matters, and an image is the worst possible input to a naive
   quicksort.
7. Give `disc_coverage()` its three-line listing like the other three renders.

## Results

- **90 scenarios, 90 passed, 0 failed** — chapter 1: 62/62, chapter 2: 28/28.
  Scenario counts by feature: shapes 4, p6 3, magnify 2, centers 5, paint 5,
  coverage 6, twice 2, plate 1.
- All four chapter-2 renders **byte-identical** to `reference/chapter-02/`.
- Clean `lake build` (deleting `.lake/build`): **3.0 s** wall, 5.3 s CPU, 15 jobs.
- `lake exe tests`: **3.1 s** wall (2.8 s CPU). Slowest scenarios: Plate 1 1.8 s,
  gray-match-as-a-file 0.35 s, "The disc by coverage" 0.15 s. Before the
  `distinct_values` fix the suite took **63 s**, 61 of them in one scenario.
- `lake exe render`: **0.53 s** wall (0.26 s CPU) for all nine images.
- 11 seeded mistakes from the brief, plus 5 of my own: 14 caught, 2 green.
- Lean 4.29.1, core only, no network. `Renderer.lean` is 515 lines,
  `Suite/Chapter02.lean` 272.
