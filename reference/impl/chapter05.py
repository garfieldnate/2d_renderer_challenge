"""
Chapter 5, Paths and Insideness: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.
"""

import math

from renderer import canvas, color, fill, pixel_at, write_pixel
from chapter02 import (Shape, KINDS, inside, coverage_buffer, set_coverage, coverage,
                       center_inside, rasterize, rasterize_centers, paint_through, magnify)
from chapter04 import point, cross, side_by_side

CHAPTER = 5
FORMAT = "P6"


# --------------------------------------------------------------------------
# §5.1 a path is a list of instructions
# --------------------------------------------------------------------------
class Subpath:
    __slots__ = ("points", "closed")

    def __init__(self, start):
        self.points = [start]
        self.closed = False

    def __repr__(self):
        return "subpath(%d points, %s)" % (len(self.points), "closed" if self.closed else "open")


class Path:
    __slots__ = ("subpaths",)

    def __init__(self):
        self.subpaths = []

    def __repr__(self):
        return "path(%r)" % (self.subpaths,)


def path():
    return Path()


def subpaths(p):
    return p.subpaths


def move_to(p, pt):
    """starts a new subpath at pt"""
    p.subpaths.append(Subpath(pt))


def line_to(p, pt):
    """extends the current subpath to pt. with no current subpath it starts
    one, as move_to would. after a close, it starts a new subpath at the
    closed subpath's first point."""
    if not p.subpaths:
        move_to(p, pt)
        return
    cur = p.subpaths[-1]
    if cur.closed:
        move_to(p, cur.points[0])
        cur = p.subpaths[-1]
    cur.points.append(pt)


def close(p):
    """marks the current subpath closed. closing nothing, or closing twice,
    does nothing."""
    if p.subpaths:
        p.subpaths[-1].closed = True


def edges(p):
    """every edge of every subpath as (a, b) point pairs. every subpath is
    treated as closed for this purpose: the edge from its last point back to
    its first is included whether or not close was called. a subpath of one
    point has no edges."""
    out = []
    for sp in p.subpaths:
        pts = sp.points
        if len(pts) < 2:
            continue
        for i in range(len(pts)):
            out.append((pts[i], pts[(i + 1) % len(pts)]))
    return out


def bounds(p):
    """(min x, min y, max x, max y) over every point of every subpath.
    an empty path has bounds (0, 0, 0, 0)."""
    pts = [q for sp in p.subpaths for q in sp.points]
    if not pts:
        return (0.0, 0.0, 0.0, 0.0)
    return (min(q.x for q in pts), min(q.y for q in pts),
            max(q.x for q in pts), max(q.y for q in pts))


def circle_path(cx, cy, r, n):
    """an n-gon standing in for a circle: n points clockwise on screen,
    the first at angle 0, on the right"""
    p = path()
    for k in range(n):
        a = 2 * math.pi * k / n
        q = point(cx + r * math.cos(a), cy + r * math.sin(a))
        if k == 0:
            move_to(p, q)
        else:
            line_to(p, q)
    close(p)
    return p


def polygon(*pts):
    """a closed subpath through the points, a convenience for the tests"""
    p = path()
    move_to(p, pts[0])
    for q in pts[1:]:
        line_to(p, q)
    close(p)
    return p


# --------------------------------------------------------------------------
# §5.2 is this point inside?
# --------------------------------------------------------------------------
def crossings(p, x, y):
    """how many edges the ray from (x, y) toward +x crosses. an edge counts
    when the ray's height is in [min y, max y) of the edge, half-open, and
    the edge is to the right of the point at that height."""
    n = 0
    for a, b in edges(p):
        if a.y == b.y:
            continue
        if (a.y <= y) != (b.y <= y):
            t = (y - a.y) / (b.y - a.y)
            if a.x + t * (b.x - a.x) > x:
                n += 1
    return n


def winding_at(p, x, y):
    """the winding number of the path around (x, y). an edge that crosses
    the ray's height going down the canvas (increasing y) with the point on
    its left counts +1; going up with the point on its right counts -1.
    positive is clockwise on the screen, like chapter 4's cross product."""
    q = point(x, y)
    w = 0
    for a, b in edges(p):
        if a.y <= y:
            if b.y > y and cross(b - a, q - a) > 0:
                w += 1
        else:
            if b.y <= y and cross(b - a, q - a) < 0:
                w -= 1
    return w


# --------------------------------------------------------------------------
# §5.3 two rules
# --------------------------------------------------------------------------
def inside_nonzero(p, x, y):
    return winding_at(p, x, y) != 0


def inside_evenodd(p, x, y):
    return winding_at(p, x, y) % 2 == 1


def filled(p, rule):
    """the shape a path encloses under a fill rule, "nonzero" or "evenodd" """
    if rule not in ("nonzero", "evenodd"):
        raise ValueError(rule)
    return Shape("filled", path=p, rule=rule)


def _inside_filled(s, x, y):
    if s.rule == "nonzero":
        return inside_nonzero(s.path, x, y)
    return inside_evenodd(s.path, x, y)


KINDS["filled"] = _inside_filled


def rasterize_within(shape, box, w, h):
    """chapter 2's rasterize, visiting only the pixels the box touches:
    columns floor(min x) to ceil(max x) - 1, rows likewise, clipped to the
    buffer. everything else stays 0."""
    cov = coverage_buffer(w, h)
    x0, y0 = max(0, math.floor(box[0])), max(0, math.floor(box[1]))
    x1, y1 = min(w, math.ceil(box[2])), min(h, math.ceil(box[3]))
    for y in range(y0, y1):
        for x in range(x0, x1):
            set_coverage(cov, x, y, coverage(shape, x, y))
    return cov


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
INK = color(0.9, 0.55, 0.1)
PAPER = color(0.02, 0.02, 0.025)
SIZE = 160


def star():
    """a pentagram: five points on a circle of radius 70 about (80.5, 80.5),
    the first straight up, visited every second one, clockwise on screen"""
    p = path()
    for k in range(5):
        a = math.radians(-90 + 144 * k)
        q = point(80.5 + 70 * math.cos(a), 80.5 + 70 * math.sin(a))
        if k == 0:
            move_to(p, q)
        else:
            line_to(p, q)
    close(p)
    return p


def star_panel(rule, method):
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    s = filled(star(), rule)
    if method == "centers":
        cov = rasterize_centers(s, SIZE, SIZE)
    else:
        cov = rasterize_within(s, bounds(star()), SIZE, SIZE)
    paint_through(c, cov, INK)
    return c


def star_centers():
    """nonzero on the left, even-odd on the right, by the center question"""
    return side_by_side(star_panel("nonzero", "centers"), star_panel("evenodd", "centers"))


def star_coverage():
    """the same two, by coverage"""
    return side_by_side(star_panel("nonzero", "coverage"), star_panel("evenodd", "coverage"))


def plate_05():
    """centers on top, coverage below; nonzero left, even-odd right; x2"""
    top, bottom = star_centers(), star_coverage()
    both = canvas(top.width, top.height * 2)
    for y in range(top.height):
        for x in range(top.width):
            write_pixel(both, x, y, pixel_at(top, x, y))
            write_pixel(both, x, y + top.height, pixel_at(bottom, x, y))
    return magnify(both, 2)


RENDERS = {
    "star-centers": star_centers,
    "star-coverage": star_coverage,
    "plate-05": plate_05,
}
