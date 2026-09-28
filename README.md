# The 2D Renderer Challenge

A test-driven book that builds a complete 2D vector renderer from nothing — lines, curves,
fills, strokes, gradients, clips and type — in whatever language you like, writing every
pixel yourself.

It is shamelessly modeled on Jamis Buck's *The Ray Tracer Challenge*: language-agnostic
Cucumber scenarios, no library dependencies, no printed implementation, and a picture at the
end of every chapter. Where that book renders a sphere, this one renders the Ghostscript
tiger.

**Status:** outline complete, chapters 1 to 25 written (24 chapters plus the bonus raster-editor chapter); 1 to 6 reader-tested in twelve languages, 7 to 23 in three so far. 24 chapters across 6 parts,
plus two bonus tracks. Start at [`plan.html`](plan.html).

---

## The through-line

> Rasterization computes coverage. Painting composites paint through coverage.

Once the reader holds a coverage buffer, a stroke is a fill of a different outline, a clip is
a multiplication of two coverage buffers, and a glyph is a path somebody else authored.
Three-quarters of the book is teaching them to see that.

## Layout

| Path | What's in it |
| --- | --- |
| `plan.html` | The full outline — 24 chapters, every plate rendered live, plus the writing guide (chapter rhythm, aside rules, voice). Read this first. |
| `chapters/` | The book. One HTML document per chapter, zero-padded (`chapter-01.html`) so they sort in reading order. |
| `assets/book.css` | Shared chapter styling — palette, type, reading column. |
| `assets/book.js` | The figure scaffold. `Plate.add(id, aspect, draw)` plus theme handling and the source panels. |
| `features/` | Cucumber scenarios, one file per chapter section, exactly as printed in the text. |
| `reference/chapter-NN/` | The reference PPMs that golden-image scenarios diff against. Shipped with the book. |
| `reference/impl/` | Author-side reference implementation and the runner that executes every `.feature` against it. Not printed, never shown to readers. |
| `reference/fonts/` | Roboto Regular (Apache 2.0) and DejaVu Sans (Bitstream Vera licence), with their licenses: the sources of `reference/chapter-16/roboto.json` and `reference/chapter-19/dejavu-arabic.json`; `tools/ttf_to_json.py` makes both. |
| `tools/sync_features.py` | Copies each feature file into the chapter that prints it, so the text can't drift from the tests. |
| `build.py` | Inlines CSS and JS into a single self-contained file in `dist/`. |
| `CLAUDE.md` | The rules for writing a chapter: every step pinned by Gherkin, no exercises left to the reader, how to test a chapter with reader agents. |

## Reading it

Open `plan.html` or any file in `chapters/` directly in a browser. There is no build step, no
server, no toolchain. Figures are drawn with the canvas API and follow your system light/dark
setting.

Every figure carries a **canvas source** toggle underneath it. That panel is generated from
the live function via `Function.prototype.toString()`, so the code you read is provably the
code that drew the picture above it — it cannot drift out of date.

To produce a single-file version for publishing:

```sh
./build.py                          # all chapters → dist/
./build.py chapters/chapter-01.html   # just one
./build.py --fragment chapters/chapter-01.html   # for the Artifact publisher
```

## The rules of the book

These are set out properly in `plan.html`; the short version:

- **Output is PPM.** Plain-text P3 in chapter 1 so you can `cat` it, binary P6 from chapter 2.
  No image libraries, no canvas API, no windowing. If a pixel is on the screen, you put it there.
- **The canvas stores linear light.** Only the PPM writer knows about sRGB. Blending happens on
  light, with a one-line switch to do it the browser's way when you need to compare.
- **Every step has a test.** Including the small "render this and look" pictures, which come with
  reference images to diff against. Nothing is left as an exercise.
- **An XML library is allowed** for chapter 20's SVG renderer. It's ubiquitous and
  pedagogically empty. You still hand-write the path-data parser, which is the part that
  teaches something.
- **Font data arrives as JSON.** Binary `sfnt` parsing isn't evenly available across languages
  and byte-level table reading is a detour. Each type chapter ships a `glyphs.json`;
  parsing real `.ttf` files is an optional appendix.
- **The math is hand-rolled.** Matrices, curve subdivision, root finding, arc length. All
  small, all worth writing once.
- **No interactivity** — but recurring *In the GUI* asides connect each algorithm to the
  toolbar control it hides behind in Illustrator, Figma, Inkscape or Photoshop.

## Writing a chapter

`plan.html` has a section called *The rhythm of a chapter* that specifies the format: the
five-step concept → test → implement → look loop, what an *In the GUI* aside may and may not
contain, what qualifies as a chapter's payoff plate, and the voice. It includes a worked
example of a good aside and a bad one. Read it before drafting. `CLAUDE.md` holds the
mechanical rules: where the numbers come from, how the test blocks stay in sync, and how a
chapter is tested by having agents implement it cold in several languages.

```sh
./reference/impl/run_features.py     # every scenario passes against the reference
./reference/impl/render.py           # regenerate reference/chapter-NN/*.ppm
./tools/sync_features.py --check     # the chapter prints exactly what features/ contains
```

The short version of the voice: casual, funny, second person, contractions. Never *simply*,
*just*, *obviously* or *trivially* — each one tells a stuck reader that the problem is them.
Admit when something is genuinely horrible, because that's what makes "this next part is
easy" believable.

## License

MIT, for the prose and the code alike. See [`LICENSE`](LICENSE). Use any of it for anything,
including teaching from it or writing your own version.

The Ghostscript tiger in `plan.html` is the traditional public-domain test file distributed
with Ghostscript.
