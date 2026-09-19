"""
Chapter 14, Offsetting Curves: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

The offset of a Bezier is not a Bezier, so the chapter fits one: split the
curve where the offset stalls and reverses (the cusps), then subdivide each
piece until a cubic through its three offset points, with the curve's own end
tangents, is within tolerance. A stroked curve is then one closed outline: the
right offset forward, a cap, the left offset backward, a cap. Folds on the
inside of a tight bend stay in the outline and nonzero winding fills them.
"""

import math

from renderer import color, canvas, fill
from chapter02 import paint_through, magnify
from chapter03 import line_wu
from chapter04 import point, vector, cross, magnitude, normalize, side_by_side
from chapter05 import path, move_to, line_to, polygon, edges, circle_path
from chapter07 import fill_path
from chapter08 import cubic, point_at, split_at, derivative, flatten, flatten_into_path
from chapter13 import stroke_to_path, _cap, _dedupe, _px

CHAPTER = 14
FORMAT = "P6"

NUDGE = 1e-4


# --------------------------------------------------------------------------
# §14.1 the offset point
# --------------------------------------------------------------------------
def _live_t(c, t):
    """the parameter to take a direction at: t itself, unless the derivative
    vanishes there (a handle sitting on its anchor), in which case a hair
    further into the curve"""
    if magnitude(derivative(c, t)) < 1e-9:
        return t + NUDGE if t < 0.5 else t - NUDGE
    return t


def tangent_at(c, t):
    """the unit tangent at t"""
    return normalize(derivative(c, _live_t(c, t)))


def normal_at(c, t):
    """the unit normal at t: the tangent turned a quarter turn toward +y,
    which is the right-hand side of travel on the y-down canvas and chapter
    13's +h side"""
    tg = tangent_at(c, t)
    return vector(-tg.y, tg.x)


def offset_point(c, t, d):
    """the point at distance d along the normal from the curve at t;
    positive d is the right-hand side of travel on screen"""
    p = point_at(c, t)
    n = normal_at(c, t)
    return point(p.x + n.x * d, p.y + n.y * d)


# --------------------------------------------------------------------------
# §14.2 curvature, and where the offset stalls
# --------------------------------------------------------------------------
def second_derivative(c, t):
    """the second derivative: n(n-1) times the Bezier of second differences
    of the control points, one degree lower again"""
    p = c.points
    if c.degree == 2:
        return vector(2 * (p[0].x - 2 * p[1].x + p[2].x),
                      2 * (p[0].y - 2 * p[1].y + p[2].y))
    ax, ay = p[0].x - 2 * p[1].x + p[2].x, p[0].y - 2 * p[1].y + p[2].y
    bx, by = p[1].x - 2 * p[2].x + p[3].x, p[1].y - 2 * p[2].y + p[3].y
    return vector(6 * ((1 - t) * ax + t * bx), 6 * ((1 - t) * ay + t * by))


def curvature(c, t):
    """the signed curvature at t: cross(v, a) / |v|^3, positive where the
    curve turns toward +y (clockwise on screen, the same sign as cross).
    The radius of the circle that hugs the curve there is 1 / |curvature|."""
    t = _live_t(c, t)
    v = derivative(c, t)
    a = second_derivative(c, t)
    speed = magnitude(v)
    return cross(v, a) / (speed * speed * speed)


def cusps(c, d, samples=64, rounds=40):
    """the parameters where the offset at distance d stalls and reverses:
    the sign changes of 1 - curvature * d, found between 64 evenly spaced
    samples and bisected 40 times. Positive curvature and positive d are
    both the clockwise side, so on the inside of a turn the offset moves at
    (1 - curvature * d) times the curve's speed: it stalls where d is the
    radius, and runs backward beyond it."""
    def f(t):
        return 1 - curvature(c, t) * d
    out = []
    prev = f(0.0)
    for i in range(1, samples + 1):
        t = i / samples
        cur = f(t)
        if (prev < 0) != (cur < 0):
            lo, hi, flo = (i - 1) / samples, t, prev
            for _ in range(rounds):
                mid = (lo + hi) / 2
                fm = f(mid)
                if (fm < 0) == (flo < 0):
                    lo, flo = mid, fm
                else:
                    hi = mid
            out.append((lo + hi) / 2)
        prev = cur
    return out


# --------------------------------------------------------------------------
# §14.3 fitting a cubic to the offset, and measuring the miss
# --------------------------------------------------------------------------
def fit_offset(c, d):
    """one cubic that starts and ends at the curve's offset points with the
    curve's own end tangents, its two handle lengths chosen so it passes
    through the offset point at t = 0.5 when its own t is 0.5"""
    p0, p3 = offset_point(c, 0.0, d), offset_point(c, 1.0, d)
    t0, t1 = tangent_at(c, 0.0), tangent_at(c, 1.0)
    m = offset_point(c, 0.5, d)
    # B(0.5) = (p0 + 3 p1 + 3 p2 + p3) / 8 with p1 = p0 + a t0, p2 = p3 - b t1
    # gives a t0 - b t1 = (8 m - 4 p0 - 4 p3) / 3
    r = vector((8 * m.x - 4 * p0.x - 4 * p3.x) / 3, (8 * m.y - 4 * p0.y - 4 * p3.y) / 3)
    den = cross(t0, t1)
    if abs(den) < 1e-9:
        a = b = magnitude(p3 - p0) / 3
    else:
        a = cross(r, t1) / den
        b = cross(r, t0) / den
    return cubic(p0, point(p0.x + a * t0.x, p0.y + a * t0.y),
                 point(p3.x - b * t1.x, p3.y - b * t1.y), p3)


def offset_error(c, d, fitted, samples=16):
    """how far the fitted curve is from the true offset, measured at 17
    matched parameters t = i / 16: the largest |fitted(t) - offset_point(t)|"""
    worst = 0.0
    for i in range(samples + 1):
        t = i / samples
        worst = max(worst, magnitude(point_at(fitted, t) - offset_point(c, t, d)))
    return worst


def distance_to_curve(c, p, samples=64, rounds=32):
    """the distance from a point to the nearest point of the curve: the best
    of 65 samples at t = i / 64, refined by 32 rounds of ternary search
    between that sample's neighbours"""
    def dist(t):
        return magnitude(point_at(c, t) - p)
    best_i, best = 0, float("inf")
    for i in range(samples + 1):
        d = dist(i / samples)
        if d < best:
            best_i, best = i, d
    lo = max(0.0, (best_i - 1) / samples)
    hi = min(1.0, (best_i + 1) / samples)
    for _ in range(rounds):
        m1 = lo + (hi - lo) / 3
        m2 = hi - (hi - lo) / 3
        if dist(m1) < dist(m2):
            hi = m2
        else:
            lo = m1
    return min(best, dist((lo + hi) / 2))


# --------------------------------------------------------------------------
# §14.4 the offset curve
# --------------------------------------------------------------------------
def sub_curve(c, t0, t1):
    """the piece of c between parameters t0 and t1, by splitting twice"""
    right = split_at(c, t0)[1] if t0 > 0 else c
    if t1 < 1:
        return split_at(right, (t1 - t0) / (1 - t0))[0]
    return right


def offset_curve(c, d, tolerance):
    """the offset of c at distance d as a list of cubics, in order: the curve
    is split at its cusps, and each piece is fitted, halved and fitted again
    until the fit is within tolerance (or sixteen halvings deep)"""
    ts = [0.0]
    for t in cusps(c, d):
        if t - ts[-1] > 1e-9 and 1 - t > 1e-9:
            ts.append(t)
    ts.append(1.0)
    pieces = []
    for i in range(len(ts) - 1):
        _offset_into(sub_curve(c, ts[i], ts[i + 1]), d, tolerance, pieces, 0)
    return pieces


def _offset_into(c, d, tolerance, out, depth):
    fitted = fit_offset(c, d)
    if offset_error(c, d, fitted) <= tolerance or depth >= 16:
        out.append(fitted)
        return
    left, right = split_at(c, 0.5)
    _offset_into(left, d, tolerance, out, depth + 1)
    _offset_into(right, d, tolerance, out, depth + 1)


def offset_path(c, d, tolerance):
    """the offset curve flattened into one open subpath, for drawing"""
    p = path()
    for piece in offset_curve(c, d, tolerance):
        flatten_into_path(p, piece, tolerance)
    return p


def offset_distance_error(c, d, tolerance, samples=100):
    """the honest measure: how far the offset's points stray from distance
    |d| to the curve, over 100 points spread along the result"""
    pieces = offset_curve(c, d, tolerance)
    worst = 0.0
    for i in range(samples):
        u = i / (samples - 1) * len(pieces)
        k = min(len(pieces) - 1, int(u))
        q = point_at(pieces[k], u - k)
        worst = max(worst, abs(distance_to_curve(c, q) - abs(d)))
    return worst


# --------------------------------------------------------------------------
# §14.5 stroking a curve: one outline
# --------------------------------------------------------------------------
def stroke_curve_to_path(c, width, cap, tolerance):
    """the stroke of one curve as one closed outline: the right offset
    forward, the end cap, the left offset backward, the start cap. Fill it
    nonzero; a fold on the inside of a tight bend is a loop the rule fills."""
    h = width / 2.0
    pts = []
    for piece in offset_curve(c, h, tolerance):
        pts += flatten(piece, tolerance)
    pts += _cap_points(point_at(c, 1.0), tangent_at(c, 1.0), h, cap)
    for piece in reversed(offset_curve(c, -h, tolerance)):
        pts += list(reversed(flatten(piece, tolerance)))
    pts += _cap_points(point_at(c, 0.0), tangent_at(c, 0.0) * -1, h, cap)
    pts = _dedupe(pts)
    if len(pts) > 1 and magnitude(pts[-1] - pts[0]) < 1e-9:
        pts.pop()
    return polygon(*pts)


def _cap_points(p, d_out, h, cap):
    shape = _cap(p, d_out, h, cap)
    return list(shape.subpaths[0].points) if shape is not None else []


def flatten_then_stroke(c, width, cap, tolerance):
    """chapter 13's way: flatten the curve, stroke the polyline with round
    joins"""
    p = path()
    flatten_into_path(p, c, tolerance)
    return stroke_to_path(p, width, cap, "round", 4.0)


def point_count(p):
    return sum(len(sp.points) for sp in p.subpaths)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
GRAY = color(0.62, 0.62, 0.66)
MAGENTA = color(0.85, 0.2, 0.55)
WHITE = color(0.9, 0.9, 0.92)
WARM = [color(0.95, 0.75, 0.2), color(0.95, 0.55, 0.15), color(0.9, 0.35, 0.15), color(0.8, 0.2, 0.2)]
COOL = [color(0.35, 0.8, 0.9), color(0.25, 0.6, 0.9), color(0.3, 0.4, 0.85), color(0.45, 0.3, 0.8)]
SIZE = 160


def hairpin():
    """a cubic that bends back on itself: its tightest radius is about 8,
    well under the thirty-pixel half-width the demos stroke it with"""
    return cubic(point(35, 140), point(65, -30), point(95, -30), point(125, 140))


def arch():
    """the plate's curve: an arch in a 320 by 270 canvas, its tightest radius
    about 26, so the offsets at 30, 45 and 60 fold on the inside"""
    return cubic(point(60, 250), point(130, 5), point(190, 5), point(260, 250))


def _hairline(c, p, col, width=1.5):
    outline = stroke_to_path(p, width, "butt", "round", 4.0)
    paint_through(c, fill_path(outline, "nonzero", c.width, c.height), col)


def _outline_over(c, outline, col):
    for a, b in edges(outline):
        line_wu(c, _px(a.x), _px(a.y), _px(b.x), _px(b.y), col)


def two_strokes():
    """left: the hairpin flattened and stroked with chapter 13's stroker,
    round joins, its many-piece outline in magenta. right: one outline from
    the offset curves. the gray is the same; the outline is not."""
    def panel(outline):
        c = canvas(SIZE, SIZE)
        fill(c, PAPER)
        paint_through(c, fill_path(outline, "nonzero", SIZE, SIZE), GRAY)
        _outline_over(c, outline, MAGENTA)
        return c
    return side_by_side(panel(flatten_then_stroke(hairpin(), 60, "butt", 0.25)),
                        panel(stroke_curve_to_path(hairpin(), 60, "butt", 0.25)))


def fold_demo():
    """the hairpin's one outline, filled nonzero on the left and even-odd on
    the right. the inner offset folds into a loop; even-odd leaves a hole."""
    outline = stroke_curve_to_path(hairpin(), 60, "butt", 0.25)

    def panel(rule):
        c = canvas(SIZE, SIZE)
        fill(c, PAPER)
        paint_through(c, fill_path(outline, rule, SIZE, SIZE), GRAY)
        _outline_over(c, outline, MAGENTA)
        return c
    return side_by_side(panel("nonzero"), panel("evenodd"))


def offsets_plate():
    """the arch with its offsets at 15, 30, 45 and 60 on both sides, warm on
    the inside of the bend where they fold, cool outside. cusps are dots."""
    W, H = 320, 270
    c = canvas(W, H)
    fill(c, PAPER)
    curve = arch()
    for k, d in enumerate((15, 30, 45, 60)):
        _hairline(c, offset_path(curve, -d, 0.1), COOL[k])
    for k, d in enumerate((15, 30, 45, 60)):
        _hairline(c, offset_path(curve, d, 0.1), WARM[k])
    spine = path()
    flatten_into_path(spine, curve, 0.1)
    _hairline(c, spine, WHITE, 2.0)
    for d in (15, 30, 45, 60):
        for t in cusps(curve, d):
            q = offset_point(curve, t, d)
            dot = circle_path(q.x, q.y, 2.5, 24)
            paint_through(c, fill_path(dot, "nonzero", W, H), MAGENTA)
    return c


def plate_14():
    return magnify(offsets_plate(), 2)


RENDERS = {
    "two-strokes": two_strokes,
    "fold": fold_demo,
    "offsets": offsets_plate,
    "plate-14": plate_14,
}
