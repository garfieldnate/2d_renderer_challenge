# Chapter 0 Feedback — Before You Start

## 1. Could you start?

Yes. After chapter 0, I understood:
- **What I'd build:** a 2D vector renderer that takes shapes and turns them into pixels
- **Language/tools needed:** any language with floating-point numbers and a test framework; Python, Rust, and Java have been validated
- **File structure:** `features/` holds Gherkin scenarios (one file per section); `reference/` holds reference images and data; paths in tests are relative to the project root
- **How tests work:** Gherkin format with Given/When/Then; the notation uses `←` for assignment, `=` for approximate equality (0.0001 tolerance), integers and pixel tuples compare exactly unless marked `± 1`

The one clarification I needed: § 0.5 mentions three kinds of tests and says "chapter 1 uses all three before it's done," but chapter 0 doesn't tell me where the feature files actually live on disk or how to invoke them. Chapter 1's note box under § 1.1 does answer this ("Copy [reference/] into the root of your project, run your tests from the root"), but that note comes after I've read through five pages of test philosophy. It might be useful to put that path instruction in chapter 0.

## 2. Contradictions

No outright contradictions between chapter 0 and 1. Chapter 0 says "the canvas stores light," and chapter 1 spends § 1.4 defending that claim with the concrete example of why 188, not 128, is half-light. The two chapters align well.

One implicit mismatch: Chapter 0 § 0.3 lists "No graphics libraries. No image library, no canvas API, no windowing" as a rule. But chapter 0 itself and every chapter in the book use HTML5 canvas to draw the figures and reference images. The intent is clear (don't use a graphics library in your *implementation*), but a first-time reader might wonder if they're forbidden from using any canvas API anywhere. A one-sentence clarification would help: "These restrictions apply to your implementation; the book's own figures are drawn with web canvas for display."

## 3. Unclear or wrong sentences

**§ 0.2**: "Coverage is a number between 0 and 1 for every pixel: how much of that pixel the shape covers."

This is clear, but it raises an immediate question for me: Is coverage the same as alpha blending? The section doesn't say. (I later learn it's not—coverage is what's underneath; alpha is the paint—but chapter 0 doesn't frame it that way.)

**§ 0.5, first paragraph under "Golden images"**: "No channel of any pixel may differ by more than 1."

This is precise, but the phrasing "no channel may differ by more than 1" is a bit abstract. Rephrase to: "Each of the R, G, B channels in each pixel may differ from the reference by at most 1 (0–255 scale)." The current wording made me re-read it twice.

**§ 0.6, "You also need the book's files"**: "Chapter 1 tells you where to put them so the paths in the scenarios resolve."

This is accurate, but since you're already describing what files you need in chapter 0, you could save a reader a few minutes by saying it plainly here: "Copy the `reference/` directory into your project root. Then run your tests from that root, and the paths in the scenarios (e.g., `read_file("reference/chapter-01/gray-match.ppm")`) will resolve correctly."

## 4. Promises that sound implausible or oversold

**Epilogue cover claim**: Chapter 0 shows a complex image (the tiger, gradients, text, crop marks, groups) and implies that after 21 chapters, "the finished cover is about ten lines of code that call them."

Ten lines of *user-facing* code—yes. But that's only because chapters 1–21 built all the machinery. The promise is misleading to someone who doesn't yet know that by chapter 21 they'll have full path fills, text rendering, SVG parsing, and groups. Maybe add: "...ten lines of high-level code that assembles the chapter's features you've built." Or just remove the phrase; the picture itself is inspiring.

**"880 scenarios"** (§ 0.5, end): The claim that the book has "over 880 scenarios" by the last chapter is impressive, but I have no reference point yet for whether that's dense or sparse. I'll trust it after I write code, but it's not a useful promise for motivation. (This is minor.)

**"Every number in every scenario came from running code, not arithmetic done by hand"** (§ 0.5, last sentence): True, but presented without saying what this *means* for me as a reader. Rephrase: "Every number was computed by the reference implementation, so if your code matches them, you know it's correct—not just plausible."

## 5. Tone issues

Overall tone is confident, clear, and funny. No smug, padded, or preachy moments that I caught. The voice is consistently casual and second-person ("you'll write," "you need," "you have").

One place that comes close: **§ 0.3, sixth bullet**: "Two things arrive ready-made. Chapter 20 lets you use your language's XML library to read SVG, because an XML parser teaches nothing about drawing..."

The explanation "because an XML parser teaches nothing about drawing" is slightly defensive. It's fine, but feels like the author is justifying a shortcut. I don't need justification; just state it plainly: "Two things arrive ready-made: an XML library for SVG (chapter 20) and JSON font files (chapter 16–19)." Readers trust you.

## 6. Duplication

**§ 0.4 vs. Chapter 1 test blocks**: § 0.4 says "Every chapter opens on a concrete problem...Then it goes round the same loop...you render something and look at it. Every render the book asks for is a named function with a reference image."

Chapter 1 then repeats this pattern explicitly: the checkerboard render (`gray_match()`), the ramp (`ramp()`), etc., with reference files. There's no wasted words here, but a reader might skim 0.4 and then re-learn it in practice in chapter 1. This is actually fine; repetition aids learning.

**Three kinds of tests (§ 0.5) vs. Chapter 1 § 1.1**: § 0.5 introduces "exact," "coverage with tolerance," and "golden images." Chapter 1 § 1.1 then re-introduces this in the context of scenarios: "Three tiers...exact scalars, scalars with tolerance, and golden image diffs."

Again, healthy repetition with slightly different framing. Not a problem.

## 7. Concrete changes

1. **Clarify the "no graphics libraries" rule**: Add one sentence to § 0.3 bullet 2: "This applies to your implementation; the book's figures use web canvas for display."

2. **Move file-structure instruction to chapter 0**: In § 0.6, replace "Chapter 1 tells you where to put them so the paths resolve" with explicit instruction: "Copy the `reference/` and `features/` directories into your project root, and run your tests from there."

3. **Reword the golden-image tolerance description** in § 0.5: Change "no channel of any pixel may differ by more than 1" to "Each R, G, B channel in each pixel must match the reference within ±1 (on the 0–255 scale)."

4. **Add a line to § 0.6 on math prerequisites**: After "You'll meet vectors, a 3×3 matrix..." add "Half of it you've used before; the other half is explained the first time you need it." (This lowers the anxiety bar slightly for readers who aren't math-confident.)

5. **Simplify the epilogue-cover claim**: Remove or rephrase "the finished cover is about ten lines of code that call them." Instead: "By chapter 21, the cover is a straightforward application of the features you've built." (Less grandiose, more honest.)

6. **Rephrase the "880 scenarios" sentence** at end of § 0.5: Change "Every number in every one of them came from running code, not from arithmetic done by hand, and the reference images were checked by looking at them as well as by diffing them" to "Every test value was computed by the reference implementation, so when your code passes, you know it's correct."

---

## Summary

Chapter 0 is a solid orientation. It explains the scope, the philosophy (coverage + paint), and how tests work. A first-time reader knows what to build, what tools to use, and roughly what a chapter looks like. The main gaps are:

- File-path setup should be in chapter 0, not deferred to chapter 1's note.
- "No graphics libraries" could confuse readers about what restriction applies.
- A few sentences are slightly defensive or abstract where they could be direct.

After chapter 0, I wanted to start chapter 1 immediately. That's success.
