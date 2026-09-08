"""
Chapter 13, Stroking is Filling: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

The whole chapter is one function, stroke_to_path, that turns a stroked path
into a fillable outline: a rectangle per segment, a wedge per join, a shape per
cap. There is no new rasterizer; the renderer's only drawing operation is fill.
"""

import math

from renderer import color, canvas, fill, pixel_at, write_pixel
from chapter02 import paint_through, magnify
from chapter04 import point, vector, cross, dot, magnitude, normalize
from chapter05 import Path, Subpath, path, move_to, line_to, close, polygon, edges
from chapter07 import fill_path

CHAPTER = 13
FORMAT = "P6"


# --------------------------------------------------------------------------
# small vector helpers on chapter 4's tuples
# --------------------------------------------------------------------------
def _unit(a, b):
    """the unit direction from point a to point b"""
    return normalize(b - a)


def _perp(v):
    """the left-hand perpendicular of a direction: rotate a quarter turn"""
    return vector(-v.y, v.x)


def _add(p, v, s):
    return point(p.x + v.x * s, p.y + v.y * s)


def _line_intersect(p1, d1, p2, d2):
    """where the line through p1 along d1 meets the line through p2 along d2;
    None if they are parallel"""
    denom = cross(d1, d2)
    if abs(denom) < 1e-12:
        return None
    t = cross(p2 - p1, d2) / denom
    return _add(p1, d1, t)


def _arc(out_pts, center, a0, a1, r, steps):
    """append points of an arc of radius r about center, from angle a0 to a1"""
    for k in range(steps + 1):
        a = a0 + (a1 - a0) * k / steps
        out_pts.append(point(center.x + r * math.cos(a), center.y + r * math.sin(a)))


def _arc_steps(a0, a1):
    return max(2, int(math.ceil(abs(a1 - a0) / (math.pi / 16))))


# --------------------------------------------------------------------------
# §13.1 the pieces: segment rectangles, joins, caps
# --------------------------------------------------------------------------
def _segment_rect(a, b, h):
    """the rectangle of half-width h centered on the segment a..b, square ends"""
    d = _unit(a, b)
    n = _perp(d)
    return polygon(_add(a, n, h), _add(b, n, h), _add(b, n, -h), _add(a, n, -h))


def _join(v, d_in, d_out, h, join, miter_limit):
    """the wedge that fills the outer gap between two segments meeting at v.
    Returns a subpath, or None when the segments are collinear."""
    turn = cross(d_in, d_out)
    if abs(turn) < 1e-12:
        return None
    s = -1.0 if turn > 0 else 1.0        # the outer side of the turn
    n_in, n_out = _perp(d_in) * s, _perp(d_out) * s
    a = _add(v, n_in, h)
    b = _add(v, n_out, h)
    if join == "bevel":
        return polygon(v, a, b)
    if join == "round":
        a0 = math.atan2(a.y - v.y, a.x - v.x)
        a1 = math.atan2(b.y - v.y, b.x - v.x)
        if s > 0 and a1 < a0:
            a1 += 2 * math.pi
        if s < 0 and a1 > a0:
            a1 -= 2 * math.pi
        pts = [v]
        _arc(pts, v, a0, a1, h, _arc_steps(a0, a1))
        return polygon(*pts)
    if join == "miter":
        m = _line_intersect(a, d_in, b, d_out)
        if m is not None and magnitude(m - v) <= miter_limit * h:
            return polygon(v, a, m, b)
        return polygon(v, a, b)              # over the limit: bevel
    raise ValueError(join)


def miter_length(d_in, d_out, h):
    """the distance from the vertex to the miter tip, the closed form the join
    test checks: h / sin(theta / 2), where theta is the turn's interior angle"""
    v = point(0, 0)
    s = -1.0 if cross(d_in, d_out) > 0 else 1.0
    a = _add(v, _perp(d_in) * s, h)
    b = _add(v, _perp(d_out) * s, h)
    m = _line_intersect(a, d_in, b, d_out)
    return magnitude(m - v) if m is not None else float("inf")


def _cap(p, d_out, h, cap):
    """the shape that closes an open end at p, where d_out points out of the
    path. butt adds nothing; square extends a half-width; round is a semicircle."""
    n = _perp(d_out)
    if cap == "butt":
        return None
    if cap == "square":
        left = _add(p, n, h)
        right = _add(p, n, -h)
        return polygon(left, _add(left, d_out, h), _add(right, d_out, h), right)
    if cap == "round":
        a0 = math.atan2(n.y, n.x)
        # sweep the semicircle through the outward direction
        outward = math.atan2(d_out.y, d_out.x)
        a1 = a0 + (math.pi if _ang_between(a0, outward) > 0 else -math.pi)
        pts = []
        _arc(pts, p, a0, a1, h, _arc_steps(a0, a1))
        return polygon(*pts)
    raise ValueError(cap)


def _ang_between(a, b):
    d = (b - a) % (2 * math.pi)
    if d > math.pi:
        d -= 2 * math.pi
    return d


def _disc(center, r):
    pts = []
    _arc(pts, center, 0.0, 2 * math.pi, r, 48)
    return polygon(*pts)


def _dedupe(pts):
    out = [pts[0]]
    for p in pts[1:]:
        if magnitude(p - out[-1]) > 1e-9:
            out.append(p)
    return out


# --------------------------------------------------------------------------
# §13.2 the stroker
# --------------------------------------------------------------------------
def stroke_to_path(p, width, cap="butt", join="miter", miter_limit=4.0):
    """turn a stroked path into a fillable outline: a rectangle per segment, a
    join wedge per interior vertex, a cap shape per open end, all as subpaths
    of one path to be filled nonzero. No rasterizer, only geometry."""
    h = width / 2.0
    out = Path()

    def emit(sub):
        if sub is not None:
            out.subpaths.append(sub.subpaths[0])

    for sp in p.subpaths:
        pts = _dedupe(sp.points)
        if len(pts) < 2:
            # a single point: a round cap is a dot, a square cap a square
            if cap == "round":
                emit(_disc(pts[0], h))
            elif cap == "square":
                c = pts[0]
                emit(polygon(point(c.x - h, c.y - h), point(c.x + h, c.y - h),
                             point(c.x + h, c.y + h), point(c.x - h, c.y + h)))
            continue

        closed = sp.closed
        segs = [(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
        if closed:
            segs.append((pts[-1], pts[0]))

        for a, b in segs:
            emit(_segment_rect(a, b, h))

        dirs = [_unit(a, b) for a, b in segs]
        # joins at every shared vertex
        joins = len(segs) - 1 if not closed else len(segs)
        for i in range(joins):
            v = segs[(i + 1) % len(segs)][0]
            emit(_join(v, dirs[i], dirs[(i + 1) % len(segs)], h, join, miter_limit))

        if not closed:
            emit(_cap(pts[0], dirs[0] * -1, h, cap))     # start: outward is backward
            emit(_cap(pts[-1], dirs[-1], h, cap))        # end: outward is forward

    return out


def stroke(canvas_, p, width, col, cap="butt", join="miter", miter_limit=4.0):
    """stroke a path onto a canvas: build the outline and fill it"""
    outline = stroke_to_path(p, width, cap, join, miter_limit)
    paint_through(canvas_, fill_path(outline, "nonzero", canvas_.width, canvas_.height), col)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
GRAY = color(0.62, 0.62, 0.66)
MAGENTA = color(0.85, 0.2, 0.55)
SIZE = 160


def chevron():
    """a wide V, one join, to show off the three joins"""
    p = path()
    move_to(p, point(30, 40))
    line_to(p, point(80, 120))
    line_to(p, point(130, 40))
    return p


def _stroke_panel(join):
    from chapter03 import line_wu
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    outline = stroke_to_path(chevron(), 26, "butt", join, 4.0)
    paint_through(c, fill_path(outline, "nonzero", SIZE, SIZE), GRAY)
    for a, b in edges(outline):
        line_wu(c, int(round(a.x)), int(round(a.y)), int(round(b.x)), int(round(b.y)), MAGENTA)
    return c


def joins_plate():
    """miter, round, bevel side by side, each the outline in magenta over the
    gray fill"""
    from chapter04 import side_by_side
    return side_by_side(side_by_side(_stroke_panel("miter"), _stroke_panel("round")),
                        _stroke_panel("bevel"))


def plate_13():
    return magnify(joins_plate(), 2)


def caps_demo():
    """one horizontal segment, the three caps, magnified"""
    from chapter03 import line_wu
    from chapter04 import side_by_side
    def panel(cap):
        c = canvas(SIZE, 80)
        fill(c, PAPER)
        seg = path()
        move_to(seg, point(45, 40))
        line_to(seg, point(115, 40))
        outline = stroke_to_path(seg, 30, cap, "miter", 4.0)
        paint_through(c, fill_path(outline, "nonzero", SIZE, 80), GRAY)
        for a, b in edges(outline):
            line_wu(c, int(round(a.x)), int(round(a.y)), int(round(b.x)), int(round(b.y)), MAGENTA)
        return c
    return side_by_side(side_by_side(panel("butt"), panel("round")), panel("square"))


RENDERS = {
    "joins": joins_plate,
    "plate-13": plate_13,
    "caps": caps_demo,
}
