"""
Chapter 15, Dashes: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Dashing is a path-to-path transform that runs before the stroker: walk each
subpath by arc length, switching between on and off as the pattern says, and
emit every on-stretch as its own open subpath. Curves are walked by arc length
too, through a table of chord lengths, since a Bezier's parameter is nothing
like its length.
"""

import math

from renderer import color, canvas, fill
from chapter02 import paint_through, magnify
from chapter04 import point, vector, magnitude
from chapter05 import Path, Subpath, path, move_to, line_to, close, subpaths, circle_path
from chapter07 import fill_path
from chapter08 import cubic, point_at, split_at, flatten_into_path
from chapter13 import stroke_to_path

CHAPTER = 15
FORMAT = "P6"

EPS = 1e-9


# --------------------------------------------------------------------------
# §15.1 length along a path, and along a curve
# --------------------------------------------------------------------------
def path_length(p):
    """the summed length of every subpath's polyline; a closed subpath
    includes the segment from its last point back to its first"""
    total = 0.0
    for sp in p.subpaths:
        pts = sp.points
        n = len(pts)
        for i in range(n - 1):
            total += magnitude(pts[i + 1] - pts[i])
        if sp.closed and n > 1:
            total += magnitude(pts[0] - pts[-1])
    return total


def arc_length_table(c, n):
    """n + 1 running lengths along the curve, the length of the polyline
    through point_at(c, i / n) up to each i: table[0] is 0, table[n] is the
    whole length, slightly under the true arc length because chords cut
    corners"""
    table = [0.0]
    prev = point_at(c, 0.0)
    for i in range(1, n + 1):
        q = point_at(c, i / n)
        table.append(table[-1] + magnitude(q - prev))
        prev = q
    return table


def arc_length(c, n):
    return arc_length_table(c, n)[n]


def t_at_length(table, s):
    """the parameter at which the running length reaches s, by linear
    interpolation within the table's segment that spans it; 0 before the
    start, 1 past the end"""
    n = len(table) - 1
    if s <= 0:
        return 0.0
    if s >= table[n]:
        return 1.0
    lo, hi = 0, n
    while hi - lo > 1:                    # table[lo] <= s < table[hi]
        mid = (lo + hi) // 2
        if table[mid] <= s:
            lo = mid
        else:
            hi = mid
    span = table[lo + 1] - table[lo]
    frac = (s - table[lo]) / span if span > 0 else 0.0
    return (lo + frac) / n


def point_at_length(c, s, n):
    return point_at(c, t_at_length(arc_length_table(c, n), s))


def split_at_length(c, s, n):
    """the two curves that meet where the running length reaches s"""
    return split_at(c, t_at_length(arc_length_table(c, n), s))


# --------------------------------------------------------------------------
# §15.2 the pattern
# --------------------------------------------------------------------------
def normalize_pattern(pattern):
    """the pattern the walk will use: an odd number of entries is repeated
    so on and off alternate the same way every cycle; a pattern with a
    negative entry, or one whose entries sum to zero, is no pattern at all
    and comes back empty, which means draw the path solid"""
    if any(v < 0 for v in pattern) or sum(pattern) <= 0:
        return []
    if len(pattern) % 2 == 1:
        return list(pattern) + list(pattern)
    return list(pattern)


def _lerp(a, b, t):
    return point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)


def _copy_path(p):
    out = Path()
    for sp in p.subpaths:
        q = Subpath(sp.points[0])
        q.points = list(sp.points)
        q.closed = sp.closed
        out.subpaths.append(q)
    return out


# --------------------------------------------------------------------------
# §15.3 the walk
# --------------------------------------------------------------------------
def dash(p, pattern, phase):
    """cut a path into dashes: every subpath is walked from its start by
    arc length, on for pattern[0], off for pattern[1], and so on around the
    pattern, and every on-stretch becomes an open subpath of the result.
    The walk continues straight through a subpath's vertices (a dash that
    turns a corner keeps its corner) and starts over at each subpath. phase
    is how far into the pattern the walk begins, taken modulo the pattern's
    sum. A closed subpath is walked around its closing segment, and if its
    last dash runs into its first the two are joined into one dash."""
    pat = normalize_pattern(pattern)
    if not pat:
        return _copy_path(p)
    n = len(pat)
    total = sum(pat)
    out = Path()
    for sp in p.subpaths:
        pts = list(sp.points)
        if sp.closed and len(pts) > 1:
            pts.append(pts[0])
        # walk the phase into the pattern
        i, remaining, on = 0, pat[0], True
        ph = phase % total
        while ph > 0:
            if ph >= remaining:
                ph -= remaining
                i = (i + 1) % n
                remaining, on = pat[i], not on
            else:
                remaining -= ph
                ph = 0
        first = len(out.subpaths)
        cur = None
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            seg = magnitude(b - a)
            if seg < EPS:
                continue
            pos = 0.0
            while pos < seg:
                step = min(remaining, seg - pos)
                if on:
                    if cur is None:
                        move_to(out, _lerp(a, b, pos / seg))
                        cur = out.subpaths[-1]
                    if step > 0:
                        line_to(out, _lerp(a, b, (pos + step) / seg))
                pos += step
                remaining -= step
                if remaining <= EPS:
                    i = (i + 1) % n
                    remaining, on = pat[i], not on
                    cur = None
        # a closed subpath whose last dash reaches its start joins the first
        dashes = out.subpaths[first:]
        if sp.closed and len(dashes) >= 1:
            head, tail = dashes[0], dashes[-1]
            if (magnitude(head.points[0] - pts[0]) < EPS
                    and magnitude(tail.points[-1] - pts[0]) < EPS):
                if head is tail:
                    tail.points.pop()
                    tail.closed = True
                else:
                    tail.points += head.points[1:]
                    out.subpaths.pop(first)
    return out


def dash_count(p, pattern, phase):
    return len(dash(p, pattern, phase).subpaths)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
GRAY = color(0.62, 0.62, 0.66)
DIM = color(0.25, 0.25, 0.28)
MAGENTA = color(0.85, 0.2, 0.55)
INKS = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
PHI = (1 + math.sqrt(5)) / 2
KAPPA = 0.5522847498


def _stroke(c, p, width, col, cap="butt", join="round"):
    outline = stroke_to_path(p, width, cap, join, 4.0)
    paint_through(c, fill_path(outline, "nonzero", c.width, c.height), col)


def _dot(c, q, r, col):
    paint_through(c, fill_path(circle_path(q.x, q.y, r, 24), "nonzero", c.width, c.height), col)


def lopsided():
    """the marks demo's curve: one short handle, one long, so its parameter
    crawls at the start and races at the end; marks at equal steps of t are
    four times as far apart at the end as at the start"""
    return cubic(point(15, 100), point(25, 85), point(100, 5), point(185, 95))


def even_marks():
    """the lopsided curve twice: eleven marks at equal steps of the
    parameter on the left, at equal steps of arc length on the right"""
    W, H = 200, 120
    c = lopsided()
    left, right = canvas(W, H), canvas(W, H)
    for cv in (left, right):
        fill(cv, PAPER)
        spine = path()
        flatten_into_path(spine, c, 0.1)
        _stroke(cv, spine, 1.5, DIM)
    L = arc_length(c, 256)
    for i in range(11):
        _dot(left, point_at(c, i / 10), 3.0, INKS[0])
        _dot(right, point_at_length(c, L * i / 10, 256), 3.0, INKS[1])
    from chapter04 import side_by_side
    return side_by_side(left, right)


def wave():
    """a gentle S, flattened into one open subpath, for the strip"""
    p = path()
    flatten_into_path(p, cubic(point(20, 20), point(120, -20), point(200, 60), point(300, 20)), 0.1)
    return p


def dash_strip():
    """the same wave four times: solid; dashed 12 on 6 off; the same
    pattern at phase 9; dots, a zero-length dash every 9 with round caps"""
    W, H = 320, 160
    c = canvas(W, H)
    fill(c, PAPER)
    rows = [([], 0, "butt", GRAY), ([12, 6], 0, "butt", INKS[0]),
            ([12, 6], 9, "butt", INKS[1]), ([0, 9], 0, "round", INKS[2])]
    from chapter04 import translation
    from chapter06 import transform_path
    for k, (pattern, phase, cap, col) in enumerate(rows):
        p = transform_path(wave(), translation(0, 40 * k))
        _stroke(c, dash(p, pattern, phase), 5, col, cap)
    return c


def golden_spiral():
    """seven quarter circles, each phi times the radius of the last and
    tangent to it, flattened into one open subpath: a golden spiral"""
    p = path()
    r = 6.0
    cx, cy = 148.0, 130.0
    theta = math.pi
    for _ in range(7):
        a0, a1 = theta, theta + math.pi / 2
        d0 = vector(math.cos(a0), math.sin(a0))
        d1 = vector(math.cos(a1), math.sin(a1))
        p0 = point(cx + r * d0.x, cy + r * d0.y)
        p3 = point(cx + r * d1.x, cy + r * d1.y)
        p1 = point(p0.x + KAPPA * r * d1.x, p0.y + KAPPA * r * d1.y)
        p2 = point(p3.x + KAPPA * r * d0.x, p3.y + KAPPA * r * d0.y)
        flatten_into_path(p, cubic(p0, p1, p2, p3), 0.05)
        nr = r * PHI
        cx, cy = p3.x - nr * d1.x, p3.y - nr * d1.y
        r, theta = nr, a1
    return p


def spiral_dashes():
    """the golden spiral dashed 16 on 10 off, every dash stroked 7 wide
    with round caps in the next of three inks; the spiral itself faint
    underneath"""
    W, H = 340, 340
    c = canvas(W, H)
    fill(c, PAPER)
    sp = golden_spiral()
    _stroke(c, sp, 1.0, DIM)
    for k, d in enumerate(dash(sp, [16, 10], 0).subpaths):
        one = Path()
        one.subpaths.append(d)
        _stroke(c, one, 7, INKS[k % 3], "round")
    return c


def plate_15():
    return magnify(spiral_dashes(), 2)


RENDERS = {
    "even-marks": even_marks,
    "dash-strip": dash_strip,
    "spiral-dashes": spiral_dashes,
    "plate-15": plate_15,
}
