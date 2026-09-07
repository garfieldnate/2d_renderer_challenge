"""
Chapter 7, Analytic Antialiasing: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.
"""

import math

from renderer import canvas, color, fill, pixel_at, write_pixel
from chapter02 import (coverage_buffer, set_coverage, coverage_at, paint_through, magnify,
                       rasterize, ink)
from chapter04 import point, translation, rotation, scaling, side_by_side
from chapter05 import path, move_to, line_to, close, edges, polygon, filled, star, circle_path
from chapter06 import transform_path, unit_star, fill_path_aliased, max_coverage_difference

CHAPTER = 7
FORMAT = "P6"


# --------------------------------------------------------------------------
# §7.1 two numbers per cell
# --------------------------------------------------------------------------
class Accumulator:
    """one area and one cover per cell. area is what the cell itself has
    accumulated; cover is what every cell to its right has."""
    __slots__ = ("width", "height", "area", "cover")

    def __init__(self, width, height):
        self.width, self.height = width, height
        self.area = [0.0] * (width * height)
        self.cover = [0.0] * (width * height)


def accumulator(w, h):
    return Accumulator(w, h)


def area_at(acc, x, y):
    return acc.area[y * acc.width + x]


def cover_at(acc, x, y):
    return acc.cover[y * acc.width + x]


def add_cell(acc, x, row, area, cover):
    """deposit into one cell. a cell left of the buffer is treated as if the
    piece ran down column 0's left side: column 0 is entirely to its right,
    so its area is the whole cover. a cell right of the buffer is dropped."""
    if x < 0:
        x, area = 0, cover
    if x >= acc.width:
        return
    i = row * acc.width + x
    acc.area[i] += area
    acc.cover[i] += cover


# --------------------------------------------------------------------------
# §7.2 a piece of an edge inside one row
# --------------------------------------------------------------------------
def accumulate_row(acc, row, x0, x1, height):
    """deposit the piece of an edge that lies in one row and runs from x0 to
    x1 across it, carrying a signed height. height is shared out among the
    cells the piece crosses in proportion to the width it has in each."""
    xa, xb = min(x0, x1), max(x0, x1)
    ca, cb = math.floor(xa), math.floor(xb)
    if ca == cb:
        xm = (xa + xb) / 2 - ca
        add_cell(acc, ca, row, height * (1 - xm), height)
        return
    dx = xb - xa
    for c in range(ca, cb + 1):
        lo, hi = max(xa, c), min(xb, c + 1)
        share = height * (hi - lo) / dx
        xm = (lo + hi) / 2 - c
        add_cell(acc, c, row, share * (1 - xm), share)


# --------------------------------------------------------------------------
# §7.3 walking the rows
# --------------------------------------------------------------------------
def accumulate(acc, a, b):
    """deposit the edge from a to b: clip it to each row it crosses and hand
    each piece to accumulate_row. heading up the canvas (decreasing y) adds,
    heading down subtracts, so that the running sum is chapter 5's winding
    number. a horizontal edge has no height and deposits nothing."""
    if a.y == b.y:
        return
    sign = 1 if a.y > b.y else -1
    top, bottom = (b, a) if a.y > b.y else (a, b)
    slope = (bottom.x - top.x) / (bottom.y - top.y)
    first = max(math.floor(top.y), 0)
    last = min(math.ceil(bottom.y) - 1, acc.height - 1)
    for row in range(first, last + 1):
        y0, y1 = max(top.y, row), min(bottom.y, row + 1)
        x0 = top.x + (y0 - top.y) * slope
        x1 = top.x + (y1 - top.y) * slope
        accumulate_row(acc, row, x0, x1, sign * (y1 - y0))


# --------------------------------------------------------------------------
# §7.4 the running sum
# --------------------------------------------------------------------------
def apply_rule(w, rule):
    """coverage from an accumulated winding number that may be fractional"""
    if rule == "nonzero":
        return min(1.0, abs(w))
    if rule == "evenodd":
        t = math.fmod(abs(w), 2.0)
        return t if t <= 1 else 2 - t
    raise ValueError(rule)


def resolve(acc, rule):
    """sweep each row left to right: a cell's winding is the cover of every
    cell to its left plus its own area"""
    cov = coverage_buffer(acc.width, acc.height)
    for row in range(acc.height):
        running = 0.0
        for x in range(acc.width):
            i = row * acc.width + x
            w = running + acc.area[i]
            running += acc.cover[i]
            set_coverage(cov, x, row, apply_rule(w, rule))
    return cov


# --------------------------------------------------------------------------
# §7.5 the fill
# --------------------------------------------------------------------------
def fill_path(p, rule, w, h):
    """the analytic fill: every edge into the accumulator, then resolve"""
    acc = accumulator(w, h)
    for a, b in edges(p):
        accumulate(acc, a, b)
    return resolve(acc, rule)


def polygon_area(p):
    """the shoelace formula over every subpath, positive when clockwise on
    screen, for checking that ink(fill_path(p)) is the area of p"""
    total = 0.0
    for a, b in edges(p):
        total += (a.x * b.y - b.x * a.y)
    return total / 2


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
INK = color(0.9, 0.55, 0.1)
INKS = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
PALE = color(0.92, 0.9, 0.82)


def needle_path():
    """twelve thin triangles from the center of a 60 by 60 canvas to its
    rim, in one path"""
    p = path()
    for k in range(12):
        a = math.radians(30 * k + 7)
        half = math.radians(1.6)
        move_to(p, point(30.5, 30.5))
        line_to(p, point(30.5 + 29 * math.cos(a - half), 30.5 + 29 * math.sin(a - half)))
        line_to(p, point(30.5 + 29 * math.cos(a + half), 30.5 + 29 * math.sin(a + half)))
        close(p)
    return p


def needles():
    """chapter 6's fill on the left, this chapter's on the right, x4"""
    left, right = canvas(60, 60), canvas(60, 60)
    fill(left, PAPER)
    fill(right, PAPER)
    p = needle_path()
    paint_through(left, fill_path_aliased(p, "nonzero", 60, 60), INK)
    paint_through(right, fill_path(p, "nonzero", 60, 60), INK)
    return magnify(side_by_side(left, right), 4)


def soft_square():
    """a square whose edges sit on pixel centers, x24"""
    c = canvas(8, 8)
    fill(c, PAPER)
    p = polygon(point(1.5, 1.5), point(5.5, 1.5), point(5.5, 5.5), point(1.5, 5.5))
    paint_through(c, fill_path(p, "nonzero", 8, 8), INK)
    return magnify(c, 24)


def star_exact():
    """chapter 5's star, nonzero on the left and even-odd on the right,
    filled analytically"""
    panels = []
    for rule in ("nonzero", "evenodd"):
        c = canvas(160, 160)
        fill(c, PAPER)
        paint_through(c, fill_path(star(), rule, 160, 160), INK)
        panels.append(c)
    return side_by_side(*panels)


def spiral_smooth():
    """chapter 6's spiral of stars, filled analytically"""
    c = canvas(320, 320)
    fill(c, PAPER)
    for k in range(24):
        a = math.radians(25 * k)
        r = 20 + 5 * k
        m = (translation(160.5 + r * math.cos(a), 160.5 + r * math.sin(a))
             * rotation(a) * scaling(6 + 1.25 * k, 6 + 1.25 * k))
        cov = fill_path(transform_path(unit_star(), m), "nonzero", 320, 320)
        paint_through(c, cov, INKS[k % 3])
    return c


SIZE = 480
CENTER = 240.0


def rays(ink_index):
    """the rays of the sunburst that wear one ink: every third of 72, each
    a thin triangle from the center to the rim"""
    p = path()
    for k in range(ink_index, 72, 3):
        a = math.radians(5 * k)
        half = math.radians(1.4)
        move_to(p, point(CENTER, CENTER))
        line_to(p, point(CENTER + 232 * math.cos(a - half), CENTER + 232 * math.sin(a - half)))
        line_to(p, point(CENTER + 232 * math.cos(a + half), CENTER + 232 * math.sin(a + half)))
        close(p)
    return p


def sunburst():
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    for i in range(3):
        paint_through(c, fill_path(rays(i), "nonzero", SIZE, SIZE), INKS[i])
    disc = circle_path(CENTER, CENTER, 78, 180)
    paint_through(c, fill_path(disc, "nonzero", SIZE, SIZE), PAPER)
    m = translation(CENTER, CENTER) * scaling(64, 64)
    paint_through(c, fill_path(transform_path(unit_star(), m), "evenodd", SIZE, SIZE), PALE)
    return c


def plate_07():
    return sunburst()


RENDERS = {
    "needles": needles,
    "soft-square": soft_square,
    "star-exact": star_exact,
    "spiral-smooth": spiral_smooth,
    "plate-07": plate_07,
}
