"""
Chapter 19, Shaping, A Field Guide: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Between a string and chapter 18's placements sits shaping: itemize the
string into runs of one script and direction; turn a run into a glyph
buffer, one entry per character with its cluster (the index of the
character it came from); substitute, ligate and attach through the font's
rule tables (GSUB's positional forms and ligatures, GPOS's mark anchors, as
JSON); then position the buffer, the pen walking right for ltr and left for
rtl, marks riding on their bases. A cluster is where the cursor may stand.
"""

import math

from renderer import color, canvas, fill, pixel_at, write_pixel
from chapter02 import paint_through, magnify
from chapter04 import point
from chapter05 import path, move_to, line_to, close, polygon
from chapter07 import fill_path
from chapter13 import stroke_to_path
from chapter16 import load_font, glyph_name, glyph_advance, glyph_bounds, roboto
from chapter17 import glyph_bitmap
from chapter18 import (Placement, placement, layout_run, run_advance, draw_run, kern,
                       round_half_up)

CHAPTER = 19
FORMAT = "P6"


# --------------------------------------------------------------------------
# §19.1 itemizing: runs of one script and one direction
# --------------------------------------------------------------------------
class Item:
    """a run of the text in one script and one direction: the characters
    text[start:end], their script, and "ltr" or "rtl" """
    __slots__ = ("start", "end", "text", "script", "direction")

    def __init__(self, start, end, text, script):
        self.start, self.end, self.text, self.script = start, end, text, script
        self.direction = "rtl" if script == "arabic" else "ltr"


def script_of(codepoint):
    """"arabic" for the Arabic block, "latin" for the Latin letters and
    their accented forms, "common" for everything else: spaces, digits,
    punctuation, which take the script of the run they sit in"""
    if 0x0600 <= codepoint <= 0x06FF:
        return "arabic"
    if 0x41 <= codepoint <= 0x5A or 0x61 <= codepoint <= 0x7A or 0xC0 <= codepoint <= 0x24F:
        return "latin"
    return "common"


def itemize(text):
    """split the text where the script changes. Common characters join the
    run before them; common characters at the very start join the first
    run; text of nothing but common characters is one latin run."""
    items = []
    start = 0
    script = None
    for i, ch in enumerate(text):
        s = script_of(ord(ch))
        if s == "common":
            continue
        if script is None:
            script = s
        elif s != script:
            items.append(Item(start, i, text[start:i], script))
            start, script = i, s
    if text:
        items.append(Item(start, len(text), text[start:], script or "latin"))
    return items


# --------------------------------------------------------------------------
# §19.2 the glyph buffer and its clusters
# --------------------------------------------------------------------------
class Shaped:
    """one glyph of a shaped run: its name, the cluster it belongs to (the
    index of the first character it came from), and for an attached mark
    its offset from its base's origin in font units"""
    __slots__ = ("glyph", "cluster", "dx", "dy")

    def __init__(self, glyph, cluster, dx=0, dy=0):
        self.glyph, self.cluster, self.dx, self.dy = glyph, cluster, dx, dy

    def __repr__(self):
        return "shaped(%r, %d)" % (self.glyph, self.cluster)


def shaped(glyph, cluster):
    return Shaped(glyph, cluster)


def glyph_buffer(font, text):
    """the starting point: one entry per character through the cmap, each
    its own cluster"""
    return [Shaped(glyph_name(font, ord(ch)), i) for i, ch in enumerate(text)]


def clusters(buffer):
    """the distinct clusters in the buffer, in logical order"""
    out = []
    for s in buffer:
        if s.cluster not in out:
            out.append(s.cluster)
    return sorted(out)


def is_mark(font, name):
    return name in font.marks


# --------------------------------------------------------------------------
# §19.3 ligatures: GSUB, the substitution kind
# --------------------------------------------------------------------------
def apply_ligatures(font, buffer):
    """walk the buffer left to right; at each position try the font's
    ligatures longest first, and when the next glyphs match a rule's parts
    replace them with its result, which takes the first part's cluster.
    Then move past the result; a ligature never feeds another."""
    rules = sorted(font.ligatures, key=lambda r: -len(r[0]))
    out = []
    i = 0
    while i < len(buffer):
        for parts, result in rules:
            n = len(parts)
            if tuple(s.glyph for s in buffer[i:i + n]) == parts:
                out.append(Shaped(result, buffer[i].cluster))
                i += n
                break
        else:
            out.append(buffer[i])
            i += 1
    return out


# --------------------------------------------------------------------------
# §19.4 Arabic: joining, and the positional forms
# --------------------------------------------------------------------------
def joining_type(font, codepoint):
    """"dual", "right", "none" or "transparent", from the font file's copy
    of Unicode's table; "none" for a character it doesn't list"""
    return font.joining.get(codepoint, "none")


def form_of(types, i):
    """the positional form of letter i given every character's joining
    type: it joins backward when it is dual or right and the nearest
    non-transparent character before it is dual, forward when it is dual
    and the nearest non-transparent character after it is dual or right"""
    t = types[i]
    if t in ("none", "transparent"):
        return "isol"
    j = i - 1
    while j >= 0 and types[j] == "transparent":
        j -= 1
    back = t in ("dual", "right") and j >= 0 and types[j] == "dual"
    k = i + 1
    while k < len(types) and types[k] == "transparent":
        k += 1
    fwd = t == "dual" and k < len(types) and types[k] in ("dual", "right")
    if back and fwd:
        return "medi"
    if back:
        return "fina"
    if fwd:
        return "init"
    return "isol"


def arabic_forms(font, text):
    """the form of every character of the text, "isol" for one that isn't a
    joining letter"""
    types = [joining_type(font, ord(ch)) for ch in text]
    return [form_of(types, i) for i in range(len(text))]


def apply_forms(font, text, buffer):
    """substitute each glyph by its positional form when the font has one:
    forms[glyph][form]. A glyph with no entry for its form keeps its name."""
    forms = arabic_forms(font, text)
    out = []
    for s in buffer:
        table = font.forms.get(s.glyph, {})
        name = table.get(forms[s.cluster], s.glyph)
        out.append(Shaped(name, s.cluster, s.dx, s.dy))
    return out


# --------------------------------------------------------------------------
# §19.5 marks: GPOS, the positioning kind
# --------------------------------------------------------------------------
def attach_marks(font, buffer):
    """a mark rides on the nearest non-mark before it: its offset is the
    base's anchor of the mark's class minus the mark's own anchor, in font
    units, and it joins the base's cluster. A mark whose base has no anchor
    of its class, or with no base before it, sits at offset (0, 0) and
    keeps its cluster."""
    out = []
    base = None
    for s in buffer:
        if is_mark(font, s.glyph):
            cls, mx, my = font.marks[s.glyph]
            if base is not None and cls in font.anchors.get(base.glyph, {}):
                bx, by = font.anchors[base.glyph][cls]
                out.append(Shaped(s.glyph, base.cluster, bx - mx, by - my))
            else:
                out.append(Shaped(s.glyph, s.cluster, 0, 0))
        else:
            base = s
            out.append(Shaped(s.glyph, s.cluster, 0, 0))
    return out


def shape(font, text):
    """the whole pipeline for one run: cmap, then forms, then ligatures,
    then marks. A font without forms or anchors skips those steps, which
    is what shaping Latin in Roboto amounts to."""
    buffer = glyph_buffer(font, text)
    if font.forms:
        buffer = apply_forms(font, text, buffer)
    buffer = apply_ligatures(font, buffer)
    if font.marks:
        buffer = attach_marks(font, buffer)
    return buffer


# --------------------------------------------------------------------------
# §19.6 positioning, in either direction
# --------------------------------------------------------------------------
def buffer_advance(font, buffer, size, kerning):
    """how far the pen moves over the buffer: every non-mark's advance,
    plus the kern pair between consecutive non-marks with kerning on"""
    s = size / font.units_per_em
    total = 0.0
    prev = None
    for e in buffer:
        if is_mark(font, e.glyph):
            continue
        if kerning and prev is not None:
            total += kern(font, prev, e.glyph) * s
        total += glyph_advance(font, e.glyph) * s
        prev = e.glyph
    return total


def position(font, buffer, size, x, y, direction, kerning):
    """chapter 18's placements for a shaped buffer, one per entry in the
    buffer's own order. ltr: the pen starts at x and walks right. rtl: the
    pen starts at x plus the buffer's advance and walks left, so the first
    entry lands at the right end and the run still occupies x to x +
    advance. A mark never moves the pen: it is placed at its base's
    origin plus its offset, scaled, dy turned over."""
    s = size / font.units_per_em
    out = []
    pen = float(x) if direction == "ltr" else float(x) + buffer_advance(font, buffer, size, kerning)
    prev = None
    base_x = float(x)
    for e in buffer:
        if is_mark(font, e.glyph):
            out.append(Placement(e.glyph, base_x + e.dx * s, y - e.dy * s))
            continue
        adv = glyph_advance(font, e.glyph) * s
        k = kern(font, prev, e.glyph) * s if (kerning and prev is not None) else 0.0
        if direction == "ltr":
            pen += k
            base_x = pen
            pen += adv
        else:
            pen -= k
            pen -= adv
            base_x = pen
        out.append(Placement(e.glyph, base_x, y))
        prev = e.glyph
    return out


# --------------------------------------------------------------------------
# §19.7 where the cursor may stand
# --------------------------------------------------------------------------
def caret_offsets(buffer, length):
    """the character offsets a cursor may stand at: every cluster start,
    then the end of the text"""
    return clusters(buffer) + [length]


def caret_positions(font, buffer, length, size, x, direction, kerning):
    """the x of the cursor at each of caret_offsets, in the same order: the
    pen where each cluster's first glyph is placed, then the pen after the
    last glyph. For ltr that runs left to right from x; for rtl it runs
    right to left from x plus the buffer's advance, and the last position
    is x."""
    run = position(font, buffer, size, x, 0, direction, kerning)
    s = size / font.units_per_em
    out = []
    for cl in clusters(buffer):
        for e, p in zip(buffer, run):
            if e.cluster == cl and not is_mark(font, e.glyph):
                out.append(p.x if direction == "ltr" else p.x + glyph_advance(font, e.glyph) * s)
                break
        else:                                        # a cluster of marks alone
            for e, p in zip(buffer, run):
                if e.cluster == cl:
                    out.append(p.x)
                    break
    total = buffer_advance(font, buffer, size, kerning)
    out.append(float(x) + total if direction == "ltr" else float(x))
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
_ARABIC = None


def dejavu():
    global _ARABIC
    if _ARABIC is None:
        from pathlib import Path
        p = Path(__file__).resolve().parents[1] / "chapter-19" / "dejavu-arabic.json"
        _ARABIC = load_font(p.read_text())
    return _ARABIC


KITAB = "كِتاب"        # kaf kasra teh alef beh: kitab, a book
SALAM = "سلام"              # seen lam alef meem: salam


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


def _box(c, x0, y0, x1, y1, col, width=1.0):
    _hairline(c, polygon(point(x0, y0), point(x1, y0), point(x1, y1), point(x0, y1)), col, width)


def _draw_shaped(c, font, buffer, size, x, y, direction, kerning, col, mark_col=None):
    """position, then draw; marks in their own ink when one is given"""
    run = position(font, buffer, size, x, y, direction, kerning)
    for e, p in zip(buffer, run):
        ink = mark_col if (mark_col is not None and is_mark(font, e.glyph)) else col
        draw_run(c, font, [p], size, ink)
    return run


def _carets(c, font, buffer, size, x, direction, kerning, length, y0, y1, col):
    for cx in caret_positions(font, buffer, length, size, x, direction, kerning):
        _vline(c, cx, y0, y1, col)


def ligature_demo():
    """office at a 64 pixel em in Roboto, shaped: the f_i in magenta, a
    cyan hairline at every caret, a dim baseline"""
    font = roboto()
    W, H = 260, 100
    c = canvas(W, H)
    fill(c, PAPER)
    size, x, y = 64, 20, 70
    text = "office"
    buffer = shape(font, text)
    run = position(font, buffer, size, x, y, "ltr", True)
    _hline(c, 4, W - 4, y, DIM)
    for e, p in zip(buffer, run):
        draw_run(c, font, [p], size, MAGENTA if e.glyph == "f_i" else GRAY)
    _carets(c, font, buffer, size, x, "ltr", True, len(text), y + 4, y + 16, CYAN)
    return c


def forms_demo():
    """beh's four forms at a 64 pixel em in DejaVu Sans, isolated, initial,
    medial and final, each on its own baseline segment with its name set
    in Roboto at 11 pixels below"""
    ar, lat = dejavu(), roboto()
    W, H = 320, 110
    c = canvas(W, H)
    fill(c, PAPER)
    size, y = 64, 60
    names = ["beh", "beh.init", "beh.medi", "beh.fina"]
    labels = ["isol", "init", "medi", "fina"]
    for k, (name, label) in enumerate(zip(names, labels)):
        x = 16 + k * 76
        _hline(c, x - 4, x + 68, y, DIM)
        draw_run(c, ar, [placement(name, x, y)], size, GRAY)
        draw_run(c, lat, layout_run(lat, label, 11, x, y + 30, True), 11, CYAN)
    return c


def word_demo():
    """kitab with a kasra at a 64 pixel em, shaped and positioned rtl from
    x = 20: the letters gray, the mark magenta, a cyan hairline at every
    caret, a dim baseline"""
    font = dejavu()
    W, H = 260, 100
    c = canvas(W, H)
    fill(c, PAPER)
    size, x, y = 64, 20, 64
    buffer = shape(font, KITAB)
    _hline(c, 4, W - 4, y, DIM)
    _draw_shaped(c, font, buffer, size, x, y, "rtl", False, GRAY, MAGENTA)
    _carets(c, font, buffer, size, x, "rtl", False, len(KITAB), y + 4, y + 16, CYAN)
    return c


def mixed_demo():
    """one line in two scripts: "Book: kitab, again." itemized, each run
    shaped in its own font and drawn at a 28 pixel em from the pen the run
    before it left, the Arabic run right to left; a cyan hairline where
    each run begins. The comma after kitab joins the Arabic run and comes
    out on its left: the bidi trap, on purpose."""
    lat, ar = roboto(), dejavu()
    W, H = 300, 60
    c = canvas(W, H)
    fill(c, PAPER)
    size, y = 28, 40
    text = "Book: " + KITAB + ", again."
    pen = 12.0
    _hline(c, 4, W - 4, y, DIM)
    for item in itemize(text):
        font = ar if item.script == "arabic" else lat
        buffer = shape(font, item.text)
        _vline(c, pen, y + 3, y + 10, CYAN)
        _draw_shaped(c, font, buffer, size, pen, y, item.direction, True, GRAY, MAGENTA)
        pen += buffer_advance(font, buffer, size, True)
    return c


def cluster_plate():
    """characters in, glyphs out. Two bands side by side: office in Roboto
    on the left, kitab with its kasra in DejaVu Sans on the right. In each
    band the characters sit in dim boxes on the top row, one per character
    through the cmap alone, and the shaped glyphs sit in cyan boxes on the
    bottom row, one box per cluster, positioned as the run is; glyphs that
    changed, and the mark, are magenta, and magenta hairlines join each
    character's box to the box of the cluster it ended up in."""
    lat, ar = roboto(), dejavu()
    W, H = 540, 210
    c = canvas(W, H)
    fill(c, PAPER)
    size = 52
    bands = [(lat, "office", "ltr", 20, 80, 180),
             (ar, KITAB, "rtl", 290, 80, 180)]
    for font, text, direction, x, y_top, y_bot in bands:
        s = size / font.units_per_em
        # top row: the characters, each in a box as wide as its own advance,
        # spaced 14 apart, left to right in logical order
        raw = glyph_buffer(font, text)
        centers = []
        pen = float(x)
        for e in raw:
            w = max(glyph_advance(font, e.glyph) * s, 12)
            _box(c, pen, y_top - 46, pen + w, y_top + 12, DIM)
            draw_run(c, font, [placement(e.glyph, pen + (w - glyph_advance(font, e.glyph) * s) / 2, y_top)], size, GRAY)
            centers.append(pen + w / 2)
            pen += w + 14
        # bottom row: the shaped run, one box per cluster spanning its glyphs
        buffer = shape(font, text)
        run = position(font, buffer, size, x, y_bot, direction, True)
        boxes = {}
        for e, p in zip(buffer, run):
            if is_mark(font, e.glyph):
                continue
            adv = glyph_advance(font, e.glyph) * s
            lo, hi = boxes.get(e.cluster, (p.x, p.x + adv))
            boxes[e.cluster] = (min(lo, p.x), max(hi, p.x + adv))
        for e, p in zip(buffer, run):
            ink = MAGENTA if (is_mark(font, e.glyph) or e.glyph not in [r.glyph for r in raw]) else GRAY
            draw_run(c, font, [p], size, ink)
        for cl, (lo, hi) in boxes.items():
            _box(c, lo, y_bot - 46, hi, y_bot + 12, CYAN)
        # the joins: each character to the box of the cluster it belongs to
        for i in range(len(text)):
            lo, hi = boxes[_cluster_of_char(buffer, i)]
            p = path()
            move_to(p, point(centers[i], y_top + 12))
            line_to(p, point((lo + hi) / 2, y_bot - 46))
            _hairline(c, p, MAGENTA, 0.75)
    return c


def _cluster_of_char(buffer, i):
    """the cluster a character offset belongs to: the largest cluster
    start that is not past it"""
    best = None
    for b in buffer:
        if b.cluster <= i and (best is None or b.cluster > best):
            best = b.cluster
    return best


def plate_19():
    return cluster_plate()


RENDERS = {
    "ligature": ligature_demo,
    "forms": forms_demo,
    "word": word_demo,
    "mixed": mixed_demo,
    "plate-19": plate_19,
}
