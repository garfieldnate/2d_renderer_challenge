"""
Chapter 6, Filling a Polygon: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.
"""

import math

from renderer import canvas, color, fill, pixel_at, write_pixel
from chapter02 import coverage_buffer, set_coverage, coverage_at, paint_through, magnify
from chapter04 import point, translation, rotation, scaling
from chapter05 import Path, Subpath, path, edges, star

CHAPTER = 6
FORMAT = "P6"


# --------------------------------------------------------------------------
# §6.1 the edge table
# --------------------------------------------------------------------------
class Edge:
    """an edge ready for the sweep: its top and bottom heights, where it
    crosses its top, how far it moves in x per unit of y, and which way the
    path was heading: +1 down the canvas (increasing y), -1 up."""
    __slots__ = ("y_top", "y_bottom", "x_top", "slope", "direction")

    def __init__(self, a, b):
        if a.y < b.y:
            top, bottom, self.direction = a, b, 1
        else:
            top, bottom, self.direction = b, a, -1
        self.y_top, self.y_bottom = top.y, bottom.y
        self.x_top = top.x
        self.slope = (bottom.x - top.x) / (bottom.y - top.y)

    def x_at(self, y):
        return self.x_top + (y - self.y_top) * self.slope

    def __repr__(self):
        return "edge(y %.4g..%.4g, x_top %.4g, slope %.4g, dir %+d)" % (
            self.y_top, self.y_bottom, self.x_top, self.slope, self.direction)


def edge_table(p):
    """every non-horizontal edge of the path, sorted by top height, then by
    x at the top. horizontal edges are dropped: they have no height to
    cross and their slope would be a division by zero."""
    out = [Edge(a, b) for a, b in edges(p) if a.y != b.y]
    out.sort(key=lambda e: (e.y_top, e.x_top))
    return out


# --------------------------------------------------------------------------
# §6.2 crossings on a row, and spans
# --------------------------------------------------------------------------
def crossings_on_row(table, y):
    """(x, direction) for every edge of the table that spans height y under
    the half-open rule, sorted by x. the slow version: every edge, every row."""
    out = [(e.x_at(y), e.direction) for e in table if e.y_top <= y < e.y_bottom]
    out.sort(key=lambda c: c[0])
    return out


def spans_from_crossings(xs, rule):
    """walk the sorted crossings left to right, accumulating the winding
    number, and emit the maximal intervals where the rule says inside"""
    out = []
    w = 0
    start = None
    for x, d in xs:
        w += d
        inside = (w != 0) if rule == "nonzero" else (w % 2 == 1)
        if inside and start is None:
            start = x
        elif not inside and start is not None:
            out.append((start, x))
            start = None
    return out


def spans(p, rule, row):
    """the spans of the path on pixel row `row`, sampled at height row + 0.5,
    as (x_start, x_end) pairs of real numbers"""
    return spans_from_crossings(crossings_on_row(edge_table(p), row + 0.5), rule)


def fill_span(cov, row, x0, x1):
    """set every pixel of the row whose center lies in [x0, x1) to 1"""
    first = math.ceil(x0 - 0.5)
    last = math.ceil(x1 - 0.5) - 1
    for x in range(max(first, 0), min(last, cov.width - 1) + 1):
        set_coverage(cov, x, row, 1.0)


# --------------------------------------------------------------------------
# §6.3 the sweep
# --------------------------------------------------------------------------
def fill_path_aliased(p, rule, w, h):
    """the scanline fill: sweep the rows top to bottom, keeping the list of
    edges that span the current row's sample height. the same buffer
    rasterize_centers(filled(p, rule), w, h) produces, far faster."""
    cov = coverage_buffer(w, h)
    table = edge_table(p)
    active = []
    nxt = 0
    for row in range(h):
        y = row + 0.5
        while nxt < len(table) and table[nxt].y_top <= y:
            active.append(table[nxt])
            nxt += 1
        active = [e for e in active if e.y_bottom > y]
        xs = sorted(((e.x_at(y), e.direction) for e in active), key=lambda c: c[0])
        for x0, x1 in spans_from_crossings(xs, rule):
            fill_span(cov, row, x0, x1)
    return cov


def max_coverage_difference(a, b):
    """the largest difference between corresponding entries of two coverage
    buffers; 1 when they differ in size, because then they can't be the
    same picture"""
    if a.width != b.width or a.height != b.height:
        return 1.0
    return max((abs(x - y) for x, y in zip(a.values, b.values)), default=0.0)


# --------------------------------------------------------------------------
# §6.4 paths through matrices
# --------------------------------------------------------------------------
def transform_path(p, m):
    """a new path with every point of every subpath taken through m; the
    closed flags come along"""
    out = Path()
    for sp in p.subpaths:
        q = Subpath(m * sp.points[0])
        q.points = [m * pt for pt in sp.points]
        q.closed = sp.closed
        out.subpaths.append(q)
    return out


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
INKS = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
SIZE = 320


def unit_star():
    """the chapter 5 star, moved to the origin and shrunk to radius 1"""
    return transform_path(star(), scaling(1 / 70, 1 / 70) * translation(-80.5, -80.5))


def spiral():
    """twenty-four stars along a spiral: the k-th is at angle 25k degrees and
    radius 20 + 5k from the canvas center, radius 6 + 1.25k, turned by 25k
    degrees, and colored INKS[k mod 3]. filled nonzero, aliased."""
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    for k in range(24):
        a = math.radians(25 * k)
        r = 20 + 5 * k
        m = (translation(160.5 + r * math.cos(a), 160.5 + r * math.sin(a))
             * rotation(a) * scaling(6 + 1.25 * k, 6 + 1.25 * k))
        cov = fill_path_aliased(transform_path(unit_star(), m), "nonzero", SIZE, SIZE)
        paint_through(c, cov, INKS[k % 3])
    return c


def plate_06():
    return magnify(spiral(), 2)


RENDERS = {
    "spiral": spiral,
    "plate-06": plate_06,
}


def x_at(e, y):
    """where an edge of the table crosses height y"""
    return e.x_at(y)
