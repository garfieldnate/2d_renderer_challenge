# The 2D Renderer Challenge

A test-driven book that builds a complete 2D vector renderer from nothing — lines, curves,
fills, strokes, gradients, clips and type — in whatever language you like, writing every
pixel yourself.

It is shamelessly modeled on Jamis Buck's *The Ray Tracer Challenge*: language-agnostic
Cucumber scenarios, no library dependencies, no printed implementation, and a picture at the
end of every chapter. Where that book renders a sphere, this one renders the Ghostscript
tiger.

**Status:** outline complete, chapter 1 drafted. 24 chapters across 6 parts, plus two bonus
tracks. Start at [`plan.html`](plan.html).

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
| `build.py` | Inlines CSS and JS into a single self-contained file in `dist/`. |

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
example of a good aside and a bad one. Read it before drafting.

The short version of the voice: casual, funny, second person, contractions. Never *simply*,
*just*, *obviously* or *trivially* — each one tells a stuck reader that the problem is them.
Admit when something is genuinely horrible, because that's what makes "this next part is
easy" believable.

## License

MIT, for the prose and the code alike. See [`LICENSE`](LICENSE). Use any of it for anything,
including teaching from it or writing your own version.

The Ghostscript tiger in `plan.html` is the traditional public-domain test file distributed
with Ghostscript.
