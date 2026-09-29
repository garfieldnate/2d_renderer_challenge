# Reader feedback: Chapter 0, "Before You Start"

Read: index.html (text only), chapter-00.html (full), chapter-01.html (full). Scripts ignored per
instructions.

## 1. Could I start?

Mostly yes, but with one real gap and one soft one.

- **What I'd build**: clear from §0.1 and reinforced by the contents page. I know it's a 2D vector
  renderer, no graphics libraries, output is PPM, canvas stores linear light.
- **Language/tools**: clear — "a language with floating point numbers and a test framework," any
  language, Gherkin scenarios I translate myself. Chapter 1 §1.1 delivers on this (JUnit/pytest/
  Rust `approx` all mentioned as acceptable).
- **How the tests work**: clear once I hit chapter 1 §1.1 — but chapter 0 alone doesn't tell me
  whether I need an actual Gherkin/Cucumber runner or just transcribe scenarios into my own test
  functions. That only becomes clear in chapter 1 ("You don't need Cucumber").
- **What files I need, and where they go — the real gap.** Chapter 0 §0.6 says: "You also need the
  book's files. The `features/` directory holds every scenario... The `reference/` directory holds
  the reference images... Chapter 1 tells you where to put them so the paths in the scenarios
  resolve." That's a promise about *both* directories. Chapter 1's actual placement instructions
  (the "Files the tests refer to" note in §1.1) only cover `reference/`: "Copy that directory into
  the root of your project, run your tests from the root, and the paths resolve." Nothing ever
  tells me where `features/` goes, or whether I need it on disk at all — every scenario I actually
  need is printed verbatim in the chapter text, and chapter 1 never has me open a `.feature` file
  directly. As a first-time reader I finished chapter 1 unsure whether skipping the `features/`
  download entirely would have cost me anything.
- **Project layout**: left entirely to the reader (no suggested skeleton, no "one file per feature"
  convention). That's probably deliberate given "any language," but it's worth knowing going in —
  chapter 0 could say so explicitly instead of leaving it to be inferred.

## 2. Contradictions

**A. Whether your OS's own image viewer opens PPM.**
Chapter 0: "GIMP opens PPM, so does **Preview on a Mac**, and so do most image editors. If yours
doesn't, a converter such as ImageMagick will turn the file into a PNG."
Chapter 1, §1.6, "Looking at a PPM": "Not every image viewer opens PPM, and **the one that ships
with your operating system may not**. GIMP, IrfanView, feh and most Linux viewers do."
Chapter 0 explicitly vouches for the Mac-native viewer; chapter 1's list of viewers that do open PPM
omits Mac entirely and hedges that your OS-shipped viewer might not work. A Mac reader hits chapter 1
and is now less sure than they were after chapter 0.

**B. "Chapter 1 tells you where to put them" (the book's files).**
Covered above in §1 — chapter 0 promises placement instructions for both `features/` and
`reference/`; chapter 1 only gives them for `reference/`.

## 3. Unclear or wrong sentences in chapter 0

- "the SVG renderer in Part VI never draws text and **borrows nothing from Part V but a paper
  colour**." I could not figure out what "a paper colour" refers to — it isn't defined anywhere in
  chapter 0, and nothing in Part V (glyphs/type, per the contents page) obviously produces a
  "paper colour." Reads like a dangling reference to something cut from an earlier draft.
- "You also need the book's files... Chapter 1 tells you where to put **them**." As above — the
  plural promise isn't fully kept, so on a first read this sentence sets an expectation chapter 1
  doesn't satisfy.
- "A language with floating point numbers and a test framework. That's close to the whole list." —
  minor, but "close to the whole list" is vague filler; either it's the whole list or it isn't (the
  very next paragraphs add "the book's files" and basic math, so it isn't).

## 4. Promises that feel oversold or vague

- **"more geometry than all of Part II"** (§0.7, Part IV's blurb: "Lines with width, joins, caps,
  offset curves and dashes. No new rasterizer, and more geometry than all of Part II.") Part II
  covers matrices, paths, insideness, a scanline fill, analytic antialiasing *and* Bézier/arc
  curves. Claiming three stroke chapters out-geometry all five of those chapters combined reads as
  an unverifiable boast rather than useful information for deciding whether to keep going.
- **"Test readers have worked through the first six chapters in twelve languages, from Python and
  JavaScript to Rust, C, Swift and Lean, and the whole book in Python, Java and Rust."** Only six of
  the claimed twelve languages are named. As a reader this doesn't help me decide anything about my
  own language choice — it reads as a credibility stat rather than guidance, and the gap between
  "twelve" and the six actually listed makes it feel padded.
- **"By the last chapter the book has over 880 scenarios."** Not wrong, just not actionable for
  someone deciding whether to start chapter 1 — a scope/credibility flourish rather than a promise
  I can check against anything I'm about to do.

## 5. Tone

Overall the voice holds up well — casual, confident, no exclamation marks, admits the mistakes are
its own ("Most traps are there because the book's own author made the mistake first"). Two spots
tipped toward smug for me:

- Chapter 0's closing line: "The tests will tell you when you've got it right, every time, **which
  is more than most graphics programming ever does**." A swipe at "most graphics programming" that
  isn't earned by anything shown yet — reads as a dig rather than a fact.
- Chapter 1, §1.4: "It's a compression scheme for human eyeballs, and it's been so successful that
  **most programmers never learn it's there**." Mild, but implies the reader is now part of an
  enlightened minority — a little superior for an opening chapter that's otherwise good at admitting
  when the reader (and the author) got something wrong.

## 6. Duplication

- **PPM viewers.** Chapter 0: "GIMP opens PPM, so does Preview on a Mac, and so do most image
  editors. If yours doesn't, a converter such as ImageMagick will turn the file into a PNG."
  Chapter 1's "Looking at a PPM" note repeats essentially the same advice (GIMP + ImageMagick) with a
  different, non-overlapping list of viewers (IrfanView, feh, "most Linux viewers," no Mac). One of
  these should be cut, or they should at least agree with each other (see contradiction A above) —
  right now a reader gets the same tip twice with different details each time.
- **The 0.0001 tolerance rule.** Chapter 0 §0.5 already states the exact-vs-tolerance-vs-golden-image
  framing in some detail ("Numbers compare within 0.0001... a test... within a stated margin... no
  channel of any pixel may differ by more than 1"). Chapter 1 §1.1 then restates the 0.0001 rule
  practically verbatim before giving the operational detail (the `±ε` override, the comparison
  helper). This one is more forgivable — chapter 0 is previewing and chapter 1 is operationalizing —
  but chapter 0's version could be shortened to a pointer ("chapter 1 spells out exactly how") rather
  than restating the number itself.

## 7. Concrete changes I'd make

1. Fix the Mac-Preview/PPM claim so chapter 0 and chapter 1 agree — either both vouch for the
   OS-native viewer or both hedge on it.
2. Either tell the reader explicitly where `features/` goes (if it's needed at all), or drop it from
   chapter 0's "you also need the book's files" list and say plainly that only `reference/` needs to
   land in the project — the scenarios themselves are meant to be read off the page, not parsed from
   disk.
3. Cut or explain "borrows nothing from Part V but a paper colour" — as written it's a dangling
   reference with no antecedent.
4. Either name all twelve languages in the reader-testing claim, or soften it to something like
   "several languages" that doesn't invite counting.
5. Soften "more geometry than all of Part II" to something checkable, or drop the comparison — it
   reads as marketing rather than as a planning aid for someone deciding where to stop.
6. Cut the closing dig ("which is more than most graphics programming ever does") — the chapter's
   case for itself is strong enough without taking a shot at the rest of the field.
7. Trim chapter 0's PPM-viewer sentence and chapter 1's "Looking at a PPM" note down to one canonical
   version instead of two overlapping, slightly conflicting ones.
8. Consider shortening chapter 0 §0.5's restatement of the 0.0001 tolerance to a forward pointer,
   since chapter 1 §1.1 delivers the operational version anyway.
