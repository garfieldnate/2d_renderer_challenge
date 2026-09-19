"""
Chapter 16, What a Glyph Is: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

A font arrives as JSON (tools/ttf_to_json.py makes it from a TrueType file).
A glyph is contours of quadratic Beziers with TrueType's implied on-curve
midpoints, in font units with y up, or a composite of other glyphs through a
transform. text_matrix is the one place the y flip lives; glyph_path takes a
glyph through it and flattens in device space, and chapter 7 fills it.
"""

import json
import math

from renderer import color, canvas, fill, pixel_at, write_pixel
from chapter02 import paint_through, magnify, coverage_at
from chapter04 import point, matrix3, translation, scaling, identity, side_by_side
from chapter05 import path, move_to, line_to, close, polygon, circle_path, edges
from chapter07 import fill_path, polygon_area
from chapter08 import quadratic, transform_curve, flatten_into_path, curve_bounds, point_at
from chapter13 import stroke_to_path

CHAPTER = 16
FORMAT = "P6"


# --------------------------------------------------------------------------
# §16.1 the font file
# --------------------------------------------------------------------------
class Glyph:
    __slots__ = ("advance", "contours", "components")

    def __init__(self, advance, contours, components):
        self.advance = advance
        self.contours = contours          # lists of (x, y, on) triples
        self.components = components      # (name, [a, b, c, d, dx, dy])


class Font:
    __slots__ = ("units_per_em", "ascender", "descender", "line_gap", "glyphs", "cmap",
                 "kern", "ligatures")

    def __init__(self, data):
        self.units_per_em = data["units_per_em"]
        self.ascender = data["ascender"]
        self.descender = data["descender"]
        self.line_gap = data["line_gap"]
        self.glyphs = {}
        for name, g in data["glyphs"].items():
            contours = [[(px, py, bool(on)) for px, py, on in c] for c in g["contours"]]
            comps = [(c["glyph"], list(c["transform"])) for c in g.get("components", [])]
            self.glyphs[name] = Glyph(g["advance"], contours, comps)
        self.cmap = {int(k): v for k, v in data["cmap"].items()}
        self.kern = {(a, b): v for a, b, v in data.get("kern", [])}
        self.ligatures = [(tuple(parts), name) for parts, name in data.get("ligatures", [])]


def load_font(text):
    if isinstance(text, bytes):
        text = text.decode("utf-8")
    return Font(json.loads(text))


def glyph_name(font, codepoint):
    """the glyph a character maps to; .notdef when the font has none"""
    return font.cmap.get(codepoint, ".notdef")


def glyph_advance(font, name):
    return font.glyphs[name].advance


def glyph_count(font):
    return len(font.glyphs)


# --------------------------------------------------------------------------
# §16.2 contours: implied points, then quadratics
# --------------------------------------------------------------------------
def implied_points(contour):
    """the contour with TrueType's implied on-curve points made explicit:
    between two consecutive off-curve points there is an on-curve point at
    their midpoint (the contour wraps, so the last and first count as
    consecutive). The result is rotated to start on an on-curve point."""
    pts = [(x, y, on) for x, y, on in contour]
    out = []
    n = len(pts)
    for i in range(n):
        cur = pts[i]
        nxt = pts[(i + 1) % n]
        out.append(cur)
        if not cur[2] and not nxt[2]:
            out.append(((cur[0] + nxt[0]) / 2, (cur[1] + nxt[1]) / 2, True))
    for i, p in enumerate(out):
        if p[2]:
            return out[i:] + out[:i]
    return out


def contour_curves(contour):
    """the contour as a closed run of quadratics: an on-curve point, an
    off-curve control point, the next on-curve point. A straight edge
    between two on-curve points is a quadratic too, with its control point
    at the midpoint, so every piece is the same shape."""
    pts = implied_points(contour)
    if not pts:
        return []
    curves = []
    n = len(pts)
    i = 0
    while i < n:
        a = pts[i]
        b = pts[(i + 1) % n]
        if b[2]:
            mid = point((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            curves.append(quadratic(point(a[0], a[1]), mid, point(b[0], b[1])))
            i += 1
        else:
            c = pts[(i + 2) % n]
            curves.append(quadratic(point(a[0], a[1]), point(b[0], b[1]), point(c[0], c[1])))
            i += 2
    return curves


# --------------------------------------------------------------------------
# §16.3 composites
# --------------------------------------------------------------------------
def component_matrix(t):
    """the matrix for a component's [a, b, c, d, dx, dy]: TrueType applies
    x' = a x + c y + dx, y' = b x + d y + dy"""
    a, b, c, d, dx, dy = t
    return matrix3(a, c, dx,
                   b, d, dy,
                   0, 0, 1)


def glyph_outline(font, name):
    """every contour of the glyph as a list of quadratics in font units, y
    up; a composite is its components' outlines, each through its matrix"""
    g = font.glyphs[name]
    out = [contour_curves(c) for c in g.contours]
    for comp_name, t in g.components:
        m = component_matrix(t)
        for contour in glyph_outline(font, comp_name):
            out.append([transform_curve(c, m) for c in contour])
    return out


def glyph_bounds(font, name):
    """(xmin, ymin, xmax, ymax) of the outline in font units, tight, from
    chapter 8's curve_bounds; an empty glyph is (0, 0, 0, 0)"""
    boxes = [curve_bounds(c) for contour in glyph_outline(font, name) for c in contour]
    if not boxes:
        return (0, 0, 0, 0)
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


# --------------------------------------------------------------------------
# §16.4 the flip, in one place, and the path
# --------------------------------------------------------------------------
def text_matrix(font, size, x, y):
    """font units to device pixels for a glyph whose origin sits on the
    baseline at (x, y): scale by size / units_per_em and turn y over"""
    s = size / font.units_per_em
    return translation(x, y) * scaling(s, -s)


def contour_path(font, name, i, m, tolerance):
    """one contour of the glyph through m, flattened, as a closed subpath"""
    p = path()
    for c in glyph_outline(font, name)[i]:
        flatten_into_path(p, transform_curve(c, m), tolerance)
    close(p)
    return p


def glyph_path(font, name, m, tolerance):
    """the whole glyph as a path: every contour through m, flattened in
    device space, closed. Fill it nonzero."""
    p = path()
    for contour in glyph_outline(font, name):
        for c in contour:
            flatten_into_path(p, transform_curve(c, m), tolerance)
        close(p)
    return p


def draw_glyph(c, font, name, size, x, y, col, tolerance=0.1):
    p = glyph_path(font, name, text_matrix(font, size, x, y), tolerance)
    paint_through(c, fill_path(p, "nonzero", c.width, c.height), col)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
GRAY = color(0.62, 0.62, 0.66)
DIM = color(0.3, 0.3, 0.34)
MAGENTA = color(0.85, 0.2, 0.55)
CYAN = color(0.2, 0.75, 0.9)
INKS = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
_FONT = None


def roboto():
    global _FONT
    if _FONT is None:
        from pathlib import Path
        p = Path(__file__).resolve().parents[1] / "chapter-16" / "roboto.json"
        _FONT = load_font(p.read_text())
    return _FONT


def _square(c, q, h, col):
    paint_through(c, fill_path(polygon(point(q.x - h, q.y - h), point(q.x + h, q.y - h),
                                       point(q.x + h, q.y + h), point(q.x - h, q.y + h)),
                               "nonzero", c.width, c.height), col)


def _ring(c, q, r, col):
    o = stroke_to_path(circle_path(q.x, q.y, r, 24), 1.5, "butt", "round", 4.0)
    paint_through(c, fill_path(o, "nonzero", c.width, c.height), col)


def _hairline(c, p, col, width=1.0):
    o = stroke_to_path(p, width, "butt", "round", 4.0)
    paint_through(c, fill_path(o, "nonzero", c.width, c.height), col)


def glyph_plate():
    """Roboto's a at a 300 pixel em, filled, with its control polygon drawn
    over it: on-curve points as filled squares, off-curve points as hollow
    circles, and the implied on-curve midpoints as smaller squares"""
    font = roboto()
    W, H = 320, 320
    c = canvas(W, H)
    fill(c, PAPER)
    m = text_matrix(font, 300, 40, 250)
    draw_glyph(c, font, "a", 300, 40, 250, GRAY)
    g = font.glyphs["a"]
    for contour in g.contours:
        poly = path()
        for k, (x, y, on) in enumerate(contour):
            q = m * point(x, y)
            (move_to if k == 0 else line_to)(poly, q)
        close(poly)
        _hairline(c, poly, DIM)
    for contour in g.contours:
        explicit = set((x, y) for x, y, on in contour)
        for x, y, on in implied_points(contour):
            q = m * point(x, y)
            if not on:
                _ring(c, q, 4.0, MAGENTA)
            elif (x, y) in explicit:
                _square(c, q, 3.0, CYAN)
            else:
                _square(c, q, 2.0, CYAN)
    return c


def plate_16():
    return magnify(glyph_plate(), 2)


def composite_demo():
    """eacute at a 240 pixel em, its two components in two inks, and the
    glyph's bounding box as a hairline"""
    font = roboto()
    W, H = 240, 240
    c = canvas(W, H)
    fill(c, PAPER)
    size, x, y = 240, 50, 190
    m = text_matrix(font, size, x, y)
    for k, (comp, t) in enumerate(font.glyphs["eacute"].components):
        p = glyph_path(font, comp, m * component_matrix(t), 0.1)
        paint_through(c, fill_path(p, "nonzero", W, H), INKS[k % 3])
    x0, y0, x1, y1 = glyph_bounds(font, "eacute")
    a, b = m * point(x0, y0), m * point(x1, y1)
    box = polygon(point(a.x, a.y), point(b.x, a.y), point(b.x, b.y), point(a.x, b.y))
    _hairline(c, box, MAGENTA)
    return c


def sizes():
    """g at 12, 24, 48 and 96 pixels on one baseline, each flattened at the
    same device tolerance"""
    font = roboto()
    W, H = 240, 120
    c = canvas(W, H)
    fill(c, PAPER)
    x = 8
    for size in (12, 24, 48, 96):
        draw_glyph(c, font, "g", size, x, 80, GRAY)
        x += glyph_advance(font, "g") * size / font.units_per_em + 8
    return c


def flip_trap():
    """the same glyph through text_matrix on the left and through a scale
    that forgot to turn y over on the right"""
    font = roboto()
    W, H = 120, 120
    right = canvas(W, H)
    fill(right, PAPER)
    left = canvas(W, H)
    fill(left, PAPER)
    s = 60 / font.units_per_em
    draw_glyph(left, font, "R", 60, 35, 60, GRAY)
    p = glyph_path(font, "R", translation(35, 60) * scaling(s, s), 0.1)
    paint_through(right, fill_path(p, "nonzero", W, H), MAGENTA)
    for cv in (left, right):
        base = path()
        move_to(base, point(0, 60))
        line_to(base, point(W, 60))
        _hairline(cv, base, DIM)
    return side_by_side(left, right)


RENDERS = {
    "glyph": glyph_plate,
    "plate-16": plate_16,
    "composite": composite_demo,
    "sizes": sizes,
    "flip": flip_trap,
}
