"""
Chapter 8, Curves: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.
"""

import math

from renderer import canvas, color, fill, pixel_at, write_pixel
from chapter02 import coverage_buffer, paint_through, magnify, ink
from chapter04 import (point, vector, Tuple, translation, rotation, scaling, magnitude,
                       side_by_side)
from chapter05 import path, move_to, line_to, close, subpaths, bounds, circle_path
from chapter06 import transform_path
from chapter07 import fill_path

CHAPTER = 8
FORMAT = "P6"


# --------------------------------------------------------------------------
# §8.1 a curve is its control points
# --------------------------------------------------------------------------
class Curve:
    """a Bezier curve, held as its control points. three points is a
    quadratic, four is a cubic. the book never needs another degree."""
    __slots__ = ("points",)

    def __init__(self, points):
        self.points = list(points)

    @property
    def degree(self):
        return len(self.points) - 1

    def __repr__(self):
        return "curve(%s)" % ", ".join("(%.4g, %.4g)" % (p.x, p.y) for p in self.points)


def quadratic(p0, p1, p2):
    return Curve([p0, p1, p2])


def cubic(p0, p1, p2, p3):
    return Curve([p0, p1, p2, p3])


def _lerp_point(a, b, t):
    return point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)


def _decasteljau(points, t):
    """returns (point at t, the left control points, the right control points)
    by repeated linear interpolation. the left and right lists are what
    split_at hands back."""
    left = [points[0]]
    right = [points[-1]]
    pts = list(points)
    while len(pts) > 1:
        pts = [_lerp_point(pts[i], pts[i + 1], t) for i in range(len(pts) - 1)]
        left.append(pts[0])
        right.append(pts[-1])
    return pts[0], left, list(reversed(right))


def point_at(c, t):
    """the point on the curve at parameter t, by de Casteljau"""
    return _decasteljau(c.points, t)[0]


def split_at(c, t):
    """two curves that together retrace c: the piece from 0 to t and the
    piece from t to 1, each a curve of the same degree"""
    _, left, right = _decasteljau(c.points, t)
    return Curve(left), Curve(right)


def derivative(c, t):
    """the tangent vector at t: the derivative of the Bezier, which is a
    Bezier one degree lower on the differences of the control points, scaled
    by the degree"""
    n = c.degree
    diffs = [vector((c.points[i + 1].x - c.points[i].x) * n,
                    (c.points[i + 1].y - c.points[i].y) * n) for i in range(n)]
    # evaluate the lower-degree Bezier on the difference vectors
    while len(diffs) > 1:
        diffs = [Tuple(diffs[i].x + (diffs[i + 1].x - diffs[i].x) * t,
                       diffs[i].y + (diffs[i + 1].y - diffs[i].y) * t, 0)
                 for i in range(len(diffs) - 1)]
    return diffs[0]


def transform_curve(c, m):
    """a new curve with every control point taken through m"""
    return Curve([m * p for p in c.points])


# --------------------------------------------------------------------------
# §8.2 tight bounds
# --------------------------------------------------------------------------
def _roots_in_unit(a, b, cc):
    """real roots of a t^2 + b t + cc = 0 that lie strictly between 0 and 1"""
    out = []
    if abs(a) < 1e-12:
        if abs(b) > 1e-12:
            t = -cc / b
            if 0 < t < 1:
                out.append(t)
        return out
    disc = b * b - 4 * a * cc
    if disc < 0:
        return out
    s = math.sqrt(disc)
    for t in ((-b + s) / (2 * a), (-b - s) / (2 * a)):
        if 0 < t < 1:
            out.append(t)
    return out


def _extrema_ts(c):
    """the parameters where a component of the derivative is zero, plus the
    endpoints, which is where the tight bounds can be"""
    ts = [0.0, 1.0]
    pts = c.points
    if c.degree == 2:
        for get in (lambda p: p.x, lambda p: p.y):
            denom = get(pts[0]) - 2 * get(pts[1]) + get(pts[2])
            if abs(denom) > 1e-12:
                t = (get(pts[0]) - get(pts[1])) / denom
                if 0 < t < 1:
                    ts.append(t)
    else:  # cubic
        for get in (lambda p: p.x, lambda p: p.y):
            d0 = get(pts[1]) - get(pts[0])
            d1 = get(pts[2]) - get(pts[1])
            d2 = get(pts[3]) - get(pts[2])
            a = d0 - 2 * d1 + d2
            b = 2 * (d1 - d0)
            cc = d0
            ts += _roots_in_unit(a, b, cc)
    return ts


def curve_bounds(c):
    """(min x, min y, max x, max y) of the curve itself, tight: evaluated at
    the endpoints and at every parameter where the curve turns around in x or
    y. The control-point box is looser and this one is what flattening needs."""
    xs, ys = [], []
    for t in _extrema_ts(c):
        p = point_at(c, t)
        xs.append(p.x)
        ys.append(p.y)
    return (min(xs), min(ys), max(xs), max(ys))


# --------------------------------------------------------------------------
# §8.3 flattening
# --------------------------------------------------------------------------
def flatness(c):
    """how far the curve strays from the straight chord between its ends:
    the greatest distance of an interior control point from that chord"""
    a, b = c.points[0], c.points[-1]
    dx, dy = b.x - a.x, b.y - a.y
    length = math.hypot(dx, dy)
    worst = 0.0
    for p in c.points[1:-1]:
        if length == 0:
            d = math.hypot(p.x - a.x, p.y - a.y)
        else:
            d = abs((p.x - a.x) * dy - (p.y - a.y) * dx) / length
        worst = max(worst, d)
    return worst


def flatten(c, tolerance):
    """a polyline that stays within tolerance of the curve, as a list of
    points from the start to the end. Subdivide until each piece is flat
    enough, so points crowd where the curve bends and thin out where it's
    nearly straight."""
    out = [c.points[0]]
    _flatten_into(c, tolerance, out)
    return out


def _flatten_into(c, tolerance, out):
    if flatness(c) <= tolerance:
        out.append(c.points[-1])
    else:
        left, right = split_at(c, 0.5)
        _flatten_into(left, tolerance, out)
        _flatten_into(right, tolerance, out)


def polyline_length(pts):
    """the summed length of a list of points"""
    total = 0.0
    for i in range(len(pts) - 1):
        total += math.hypot(pts[i + 1].x - pts[i].x, pts[i + 1].y - pts[i].y)
    return total


def flatten_length(c, tolerance):
    return polyline_length(flatten(c, tolerance))


def flatten_into_path(p, c, tolerance):
    """append the flattened curve to a path with line_to, starting a subpath
    if there is none. the first flattened point coincides with the current
    point when there is one, so it is not repeated."""
    pts = flatten(c, tolerance)
    if not p.subpaths or p.subpaths[-1].closed:
        move_to(p, pts[0])
        pts = pts[1:]
    else:
        # if the pen is already at pts[0], skip it; otherwise line to it
        cur = p.subpaths[-1].points[-1]
        if cur.x == pts[0].x and cur.y == pts[0].y:
            pts = pts[1:]
    for q in pts:
        line_to(p, q)


# --------------------------------------------------------------------------
# §8.4 the SVG elliptical arc
# --------------------------------------------------------------------------
class Arc:
    """a center-parameterized elliptical arc: center, radii, the x-axis
    rotation phi (radians), the start angle theta1 and the swept angle
    delta. corrected is true when the radii were too small and were grown."""
    __slots__ = ("cx", "cy", "rx", "ry", "phi", "theta1", "delta", "corrected")

    def __init__(self, cx, cy, rx, ry, phi, theta1, delta, corrected):
        self.cx, self.cy, self.rx, self.ry = cx, cy, rx, ry
        self.phi, self.theta1, self.delta, self.corrected = phi, theta1, delta, corrected


def _angle(ux, uy, vx, vy):
    """the signed angle from vector u to vector v"""
    dot = ux * vx + uy * vy
    length = math.hypot(ux, uy) * math.hypot(vx, vy)
    a = math.acos(max(-1.0, min(1.0, dot / length)))
    return a if (ux * vy - uy * vx) >= 0 else -a


def arc(x1, y1, rx, ry, phi, large_arc, sweep, x2, y2):
    """the SVG endpoint parameterization turned into a center one, per the
    spec's F.6.5 and F.6.6. rx and ry are grown if they are too small to
    reach; a zero radius or coincident endpoints has no arc and returns
    None. phi is the x-axis rotation in radians (SVG's attribute is in
    degrees)."""
    if (x1 == x2 and y1 == y2) or rx == 0 or ry == 0:
        return None
    rx, ry = abs(rx), abs(ry)
    cphi, sphi = math.cos(phi), math.sin(phi)
    # F.6.5.1 the endpoints in the ellipse's own frame
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cphi * dx + sphi * dy
    y1p = -sphi * dx + cphi * dy
    # F.6.6 radius correction
    corrected = False
    lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lam > 1:
        s = math.sqrt(lam)
        rx, ry, corrected = rx * s, ry * s, True
    # F.6.5.2 the center in that frame
    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    co = math.sqrt(max(0.0, num / den))
    if large_arc == sweep:
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx
    # F.6.5.3 back to user space
    cx = cphi * cxp - sphi * cyp + (x1 + x2) / 2
    cy = sphi * cxp + cphi * cyp + (y1 + y2) / 2
    # F.6.5.5 and F.6.5.6 the angles
    theta1 = _angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    delta = _angle((x1p - cxp) / rx, (y1p - cyp) / ry,
                   (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and delta > 0:
        delta -= 2 * math.pi
    elif sweep and delta < 0:
        delta += 2 * math.pi
    return Arc(cx, cy, rx, ry, phi, theta1, delta, corrected)


def arc_point(a, t):
    """the point at parameter t in 0..1 along the arc, t = 0 at its start
    and t = 1 at its end"""
    theta = a.theta1 + a.delta * t
    cphi, sphi = math.cos(a.phi), math.sin(a.phi)
    ex, ey = a.rx * math.cos(theta), a.ry * math.sin(theta)
    return point(a.cx + cphi * ex - sphi * ey, a.cy + sphi * ex + cphi * ey)


def flatten_arc(a, n):
    """the arc as n equal-angle segments, as a list of n + 1 points"""
    return [arc_point(a, i / n) for i in range(n + 1)]


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
INKS = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
TOL = 0.2


def teardrop():
    """a single closed curve: two cubics meeting at a sharp bottom point and
    a round top, in a 60 by 60 box. drawn coarse on the left and fine on the
    right to show flattening."""
    top = point(30.5, 12)
    tip = point(30.5, 52)
    right = cubic(top, point(58, 16), point(46, 52), tip)
    left = cubic(tip, point(15, 52), point(3, 16), top)
    return right, left


def drops():
    left, right = canvas(60, 60), canvas(60, 60)
    fill(left, PAPER)
    fill(right, PAPER)
    a, b = teardrop()
    coarse = path()
    flatten_into_path(coarse, a, 4.0)
    flatten_into_path(coarse, b, 4.0)
    close(coarse)
    fine = path()
    flatten_into_path(fine, a, 0.1)
    flatten_into_path(fine, b, 0.1)
    close(fine)
    paint_through(left, fill_path(coarse, "nonzero", 60, 60), INKS[2])
    paint_through(right, fill_path(fine, "nonzero", 60, 60), INKS[2])
    return magnify(side_by_side(left, right), 4)


def petal():
    """one petal pointing up, its tip at the origin and its base a little
    below, made of two cubics that bulge out to the sides. about a unit tall."""
    tip = point(0, -1)
    base = point(0, 0)
    right = cubic(base, point(0.55, -0.35), point(0.4, -0.92), tip)
    left = cubic(tip, point(-0.4, -0.92), point(-0.55, -0.35), base)
    return right, left


def flower_at(p, m, n, tolerance):
    """add n petals around the origin, each transformed by m and flattened in
    that device space, as n closed subpaths of the path p"""
    r, l = petal()
    for k in range(n):
        spin = m * rotation(2 * math.pi * k / n)
        flatten_into_path(p, transform_curve(r, spin), tolerance)
        flatten_into_path(p, transform_curve(l, spin), tolerance)
        close(p)


def flower():
    """three flowers of curved petals, each a different size, every petal
    flattened in device space at the same tolerance so the big flower is as
    smooth as the small one. a disc is punched out of each center by painting
    the paper back through a filled circle."""
    c = canvas(360, 360)
    fill(c, PAPER)
    spots = [(108, 250, 44, 8, 0.0), (200, 145, 74, 8, 0.39), (286, 252, 54, 7, 0.8)]
    for i, (cx, cy, s, n, rot) in enumerate(spots):
        m = translation(cx, cy) * scaling(s, s) * rotation(rot)
        petals = path()
        flower_at(petals, m, n, TOL)
        paint_through(c, fill_path(petals, "nonzero", 360, 360), INKS[i % 3])
        disc = circle_path(cx, cy, s * 0.3, 64)
        paint_through(c, fill_path(disc, "nonzero", 360, 360), PAPER)
    return c


def plate_08():
    return magnify(flower(), 2)


RENDERS = {
    "drops": drops,
    "flower": flower,
    "plate-08": plate_08,
}
