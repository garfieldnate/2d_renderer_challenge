"""
Chapter 18, Setting a Line of Text: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Layout is separate from rendering. layout_run turns a string into a list of
placements, (glyph name, x, y) with the pen stepping by each advance and
shrinking by each kern pair; break_lines is greedy at spaces; layout_line
aligns a line four ways inside a measure; layout_paragraph stacks lines by
line_height. draw_run hands the placements to chapter 17's bitmaps, each at
its nearest quarter pixel. Nothing here draws a pixel a new way.
"""

import math

from renderer import color, canvas, fill, pixel_at, write_pixel
from chapter02 import paint_through, magnify
from chapter04 import point
from chapter05 import path, move_to, line_to, polygon
from chapter07 import fill_path
from chapter13 import stroke_to_path
from chapter16 import load_font, glyph_name, glyph_advance, roboto
from chapter17 import subpixel_of, glyph_bitmap, paint_bitmap, pen_advance

CHAPTER = 18
FORMAT = "P6"


def round_half_up(v):
    return int(math.floor(v + 0.5))


# --------------------------------------------------------------------------
# §18.1 advances, the pen, and the vertical metrics
# --------------------------------------------------------------------------
class Placement:
    """one glyph of a laid-out run: its name and where its origin sits on
    the baseline, in fractional pixels"""
    __slots__ = ("name", "x", "y")

    def __init__(self, name, x, y):
        self.name, self.x, self.y = name, float(x), float(y)

    def __repr__(self):
        return "placement(%r, %g, %g)" % (self.name, self.x, self.y)


def placement(name, x, y):
    return Placement(name, x, y)


def ascent(font, size):
    """how far the font reaches above the baseline, in pixels"""
    return font.ascender * size / font.units_per_em


def descent(font, size):
    """how far below the baseline, as a positive number of pixels"""
    return -font.descender * size / font.units_per_em


def line_height(font, size):
    """baseline to baseline: ascent + descent + the line gap"""
    return (font.ascender - font.descender + font.line_gap) * size / font.units_per_em


# --------------------------------------------------------------------------
# §18.2 kerning
# --------------------------------------------------------------------------
def kern(font, left, right):
    """the pair adjustment in font units, 0 when the font has no pair"""
    return font.kern.get((left, right), 0)


def layout_run(font, text, size, x, y, kerning=True):
    """one placement per character, the pen starting at x on the baseline
    y and stepping by each glyph's advance; with kerning on, the pen also
    moves by the kern pair between each glyph and the one before it"""
    s = size / font.units_per_em
    out = []
    pen = float(x)
    prev = None
    for ch in text:
        name = glyph_name(font, ord(ch))
        if kerning and prev is not None:
            pen += kern(font, prev, name) * s
        out.append(Placement(name, pen, y))
        pen += glyph_advance(font, name) * s
        prev = name
    return out


def run_advance(font, text, size, kerning=True):
    """how far the pen moves over the whole run"""
    s = size / font.units_per_em
    total = 0.0
    prev = None
    for ch in text:
        name = glyph_name(font, ord(ch))
        if kerning and prev is not None:
            total += kern(font, prev, name) * s
        total += glyph_advance(font, name) * s
        prev = name
    return total


# --------------------------------------------------------------------------
# §18.3 breaking lines
# --------------------------------------------------------------------------
def break_lines(font, text, size, measure, kerning=True):
    """greedy: words are runs of non-space characters; a word joins the
    current line when the line with it, one space between, is no wider than
    the measure, and starts a new line otherwise. A word wider than the
    measure sits alone on its line and overflows."""
    words = [w for w in text.split(" ") if w]
    lines = []
    current = ""
    for word in words:
        candidate = word if not current else current + " " + word
        if current and run_advance(font, candidate, size, kerning) > measure:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


# --------------------------------------------------------------------------
# §18.4 aligning
# --------------------------------------------------------------------------
ALIGNMENTS = ("left", "right", "center", "justify")


def layout_line(font, text, size, x, y, measure, align, kerning=True):
    """a run laid out inside a measure starting at x: left leaves the
    slack on the right, right on the left, center splits it; justify
    spreads it across the line's spaces, and a line with no space is laid
    out left"""
    width = run_advance(font, text, size, kerning)
    slack = measure - width
    run = layout_run(font, text, size, x, y, kerning)
    if align == "right":
        shift = slack
    elif align == "center":
        shift = slack / 2
    else:
        shift = 0.0
    if align == "justify":
        gaps = text.count(" ")
        if gaps:
            extra = slack / gaps
            seen = 0
            for ch, p in zip(text, run):
                p.x += seen * extra
                if ch == " ":
                    seen += 1
            return run
    for p in run:
        p.x += shift
    return run


def layout_paragraph(font, text, size, x, y, measure, align, kerning=True):
    """break_lines, then every line laid out with its baseline line_height
    below the one before, the first on y. Justify never stretches the last
    line: it is laid out left."""
    out = []
    lines = break_lines(font, text, size, measure, kerning)
    for i, line in enumerate(lines):
        mode = align
        if align == "justify" and i == len(lines) - 1:
            mode = "left"
        out += layout_line(font, line, size, x, y + i * line_height(font, size), measure, mode, kerning)
    return out


# --------------------------------------------------------------------------
# §18.5 the seam: rendering a run
# --------------------------------------------------------------------------
def draw_run(c, font, run, size, col, linear=True):
    """every placement through chapter 17: the pen's x split into a whole
    pixel and a quarter, the bitmap for that quarter painted there, the
    baseline rounded to the nearest pixel row (halves up)"""
    for p in run:
        whole, quarter = subpixel_of(p.x)
        paint_bitmap(c, glyph_bitmap(font, p.name, size, quarter), whole, round_half_up(p.y), col, linear)


def layout_run_rounded(font, text, size, x, y):
    """the trap: the pen rounded to a whole pixel after every glyph. Each
    rounding is at most half a pixel; over a line they don't cancel."""
    s = size / font.units_per_em
    out = []
    pen = float(x)
    for ch in text:
        name = glyph_name(font, ord(ch))
        out.append(Placement(name, pen, y))
        pen = round_half_up(pen + glyph_advance(font, name) * s)
    return out


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
WHITE = color(1, 1, 1)
BLACK = color(0, 0, 0)
GRAY = color(0.62, 0.62, 0.66)
DIM = color(0.3, 0.3, 0.34)
MAGENTA = color(0.85, 0.2, 0.55)
CYAN = color(0.2, 0.75, 0.9)

THROUGH_LINE = ("Rasterization computes coverage. Painting composites paint through "
                "coverage. Once you hold a coverage buffer, a stroke is a fill of a "
                "different outline, a clip is a multiplication of two buffers, and a "
                "glyph is a path somebody else drew.")


def _hairline(c, p, col, width=1.0):
    o = stroke_to_path(p, width, "butt", "round", 4.0)
    paint_through(c, fill_path(o, "nonzero", c.width, c.height), col)


def _vline(c, x, y0, y1, col, width=1.0):
    p = path()
    move_to(p, point(x, y0))
    line_to(p, point(x, y1))
    _hairline(c, p, col, width)


def _hline(c, x0, x1, y, col, width=1.0):
    p = path()
    move_to(p, point(x0, y))
    line_to(p, point(x1, y))
    _hairline(c, p, col, width)


def kern_demo():
    """the word TAVERN at a 64 pixel em, twice: kerned on top, advances
    alone below, with a tick at every pen position and a bracket at the end
    for the difference"""
    font = roboto()
    W, H = 320, 190
    c = canvas(W, H)
    fill(c, PAPER)
    size, x = 64, 12
    for row, (y, kerning) in enumerate(((70, True), (160, False))):
        run = layout_run(font, "TAVERN", size, x, y, kerning)
        draw_run(c, font, run, size, GRAY)
        _hline(c, 4, W - 4, y, DIM)
        end = x + run_advance(font, "TAVERN", size, kerning)
        for p in run + [Placement("", end, y)]:
            _vline(c, p.x, y + 3, y + 12, CYAN if kerning else DIM)
    kerned = x + run_advance(font, "TAVERN", size, True)
    plain = x + run_advance(font, "TAVERN", size, False)
    _vline(c, kerned, 84, 180, MAGENTA)
    _vline(c, plain, 84, 180, MAGENTA)
    _hline(c, kerned, plain, 180, MAGENTA)
    return c


def break_demo():
    """the through-line broken greedily into a 300 pixel measure at 16
    pixels, left aligned, the measure drawn as two cyan rules"""
    font = roboto()
    W, H = 340, 150
    c = canvas(W, H)
    fill(c, PAPER)
    x, y, measure, size = 20, 30, 300, 16
    run = layout_paragraph(font, THROUGH_LINE, size, x, y, measure, "left")
    draw_run(c, font, run, size, GRAY)
    _vline(c, x, 10, H - 10, CYAN)
    _vline(c, x + measure, 10, H - 10, CYAN)
    return c


def drift_demo():
    """the trap: one line at 11 pixels, the pen fractional on top and
    rounded to a whole pixel after every glyph below, a tick at each line's
    end and a magenta bracket for the drift; magnified three times"""
    font = roboto()
    text = "little illicit lilies fill the hill until it is still"
    W, H = 260, 44
    c = canvas(W, H)
    fill(c, WHITE)
    size, x = 11, 6
    exact = layout_run(font, text, size, x, 14, False)
    rounded = layout_run_rounded(font, text, size, x, 34)
    draw_run(c, font, exact, size, BLACK)
    draw_run(c, font, rounded, size, BLACK)
    end_exact = x + run_advance(font, text, size, False)
    end_rounded = rounded[-1].x + pen_advance(font, rounded[-1].name, size)
    _vline(c, end_exact, 3, 18, CYAN, 2.0)
    _vline(c, end_exact, 23, 38, CYAN, 2.0)
    _vline(c, end_rounded, 23, 38, MAGENTA, 2.0)
    _hline(c, end_exact, end_rounded, 40, MAGENTA, 2.0)
    return magnify(c, 3)


def alignment_plate():
    """the through-line set four ways at 14 pixels in a 300 pixel measure:
    left and right on the top row, centered and justified below, with a
    dim rule on every baseline and the measure's edges in cyan"""
    font = roboto()
    W, H = 660, 236
    c = canvas(W, H)
    fill(c, PAPER)
    size, measure = 14, 300
    for k, align in enumerate(ALIGNMENTS):
        col, row = k % 2, k // 2
        x = 20 + col * (measure + 20)
        y = 24 + row * 108
        run = layout_paragraph(font, THROUGH_LINE, size, x, y, measure, align)
        n = len(break_lines(font, THROUGH_LINE, size, measure))
        for i in range(n):
            _hline(c, x, x + measure, y + i * line_height(font, size), DIM, 0.5)
        _vline(c, x, y - 14, y + (n - 1) * line_height(font, size) + 5, CYAN, 0.5)
        _vline(c, x + measure, y - 14, y + (n - 1) * line_height(font, size) + 5, CYAN, 0.5)
        draw_run(c, font, run, size, GRAY)
    return c


def plate_18():
    return alignment_plate()


RENDERS = {
    "kerning": kern_demo,
    "breaking": break_demo,
    "drift": drift_demo,
    "plate-18": plate_18,
}
