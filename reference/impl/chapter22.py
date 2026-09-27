"""
Chapter 22, Boolean Path Operations: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Every coordinate is snapped to a grid of 1/256 pixel and held as a whole
number of grid units, so every orientation test is exact. The pipeline:
segments from both paths, split until no two cross (crossings rounded to the
grid, repeated until a pass finds nothing), identical segments merged with
their windings summed, each segment classified by chapter 5's winding number
at its midpoint, the boundary segments kept and stitched into contours.

Three ways to find where segments meet, all producing the same splits: every
pair ("brute"), an active list swept down the canvas ("sweep"), and
Bentley-Ottmann with an ordered status and exact rational events
("bentley-ottmann").
"""

import heapq
import math
from fractions import Fraction

from renderer import canvas, color, fill, mix
from chapter02 import paint_through, magnify
from chapter04 import point, cross, translation, scaling, rotation, side_by_side
from chapter05 import path, move_to, line_to, close, edges, subpaths, polygon, star, circle_path
from chapter06 import transform_path
from chapter07 import fill_path, polygon_area
from chapter13 import stroke_to_path
from chapter16 import roboto, glyph_path, text_matrix, glyph_name

CHAPTER = 22
FORMAT = "P6"

GRID = 256
LIMIT = 1024          # coordinates must lie within +-LIMIT pixels


# --------------------------------------------------------------------------
# §22.1 a grid
# --------------------------------------------------------------------------
def grid(v):
    """a coordinate in pixels to a whole number of grid units, halves up"""
    return int(math.floor(v * GRID + 0.5))


def snap_point(p):
    return point(grid(p.x), grid(p.y))


def orient(a, b, c):
    """cross(b - a, c - a): positive when c is clockwise of a->b on screen.
    Exact for whole numbers: the products stay far below 2^53."""
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


def lex_less(p, q):
    """the sweep's order: top to bottom, and left to right along a row"""
    return p.y < q.y or (p.y == q.y and p.x < q.x)


def _o(ax, ay, bx, by, cx, cy):
    return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)


def _lt(p, q):
    return p[1] < q[1] or (p[1] == q[1] and p[0] < q[0])


# --------------------------------------------------------------------------
# §22.2 segments, and where two of them meet
# --------------------------------------------------------------------------
class Seg:
    """a segment between two grid points, lo before hi in the sweep's order,
    carrying how much it adds to the winding of path A and of path B: +1 for
    an edge that ran lo to hi, -1 for one that ran hi to lo"""
    __slots__ = ("l", "h", "wa", "wb")

    def __init__(self, l, h, wa, wb):
        if _lt(h, l):
            l, h, wa, wb = h, l, -wa, -wb
        self.l, self.h, self.wa, self.wb = l, h, wa, wb

    @property
    def lo(self):
        return point(self.l[0], self.l[1])

    @property
    def hi(self):
        return point(self.h[0], self.h[1])

    def __repr__(self):
        return "seg(%r, %r, %d, %d)" % (self.l, self.h, self.wa, self.wb)

    def approx(self, o, eps=None):
        return isinstance(o, Seg) and (self.l, self.h, self.wa, self.wb) == (o.l, o.h, o.wa, o.wb)


def _ip(p):
    x, y = p.x, p.y
    if x != math.floor(x) or y != math.floor(y):
        raise ValueError("not a grid point: %r" % (p,))
    return (int(x), int(y))


def seg(a, b, wa, wb):
    return Seg(_ip(a), _ip(b), wa, wb)


def path_segments(p, operand):
    """every edge of the path, snapped, as a segment of operand "a" or "b".
    Edges that snap to a single point are dropped."""
    out = []
    for a, b in edges(p):
        l, h = (grid(a.x), grid(a.y)), (grid(b.x), grid(b.y))
        if l == h:
            continue
        for q in (l, h):
            if abs(q[0]) > LIMIT * GRID or abs(q[1]) > LIMIT * GRID:
                raise ValueError("coordinate outside +-%d pixels" % LIMIT)
        out.append(Seg(l, h, 1, 0) if operand == "a" else Seg(l, h, 0, 1))
    return out


def _round_div(n, d):
    """n / d rounded to the nearest whole number, halves up; d > 0"""
    return (2 * n + d) // (2 * d)


def _crossing_exact(s, t):
    """the crossing of two segments' lines as (X, Y, D), D > 0, point X/D, Y/D"""
    (ax, ay), (bx, by) = s.l, s.h
    (cx, cy), (dx, dy) = t.l, t.h
    beta = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx)
    alpha = (cx - ax) * (dy - cy) - (cy - ay) * (dx - cx)
    if beta < 0:
        alpha, beta = -alpha, -beta
    return (ax * beta + (bx - ax) * alpha, ay * beta + (by - ay) * alpha, beta)


def _crossing(s, t):
    X, Y, D = _crossing_exact(s, t)
    return (_round_div(X, D), _round_div(Y, D))


def crossing_point(s, t):
    """where two crossing segments cross, rounded to the nearest grid point"""
    x, y = _crossing(s, t)
    return point(x, y)


def _between(p, a, b):
    """p strictly between a and b in the sweep's order"""
    return _lt(a, p) and _lt(p, b)


def _meet(s, t):
    """(kind, splits of s, splits of t) with points as int pairs"""
    (ax, ay), (bx, by) = a, b = s.l, s.h
    (cx, cy), (dx, dy) = c, d = t.l, t.h
    if (max(ax, bx) < min(cx, dx) or max(cx, dx) < min(ax, bx)
            or by < cy or dy < ay):
        return "none", [], []
    o1 = _o(ax, ay, bx, by, cx, cy)
    o2 = _o(ax, ay, bx, by, dx, dy)
    o3 = _o(cx, cy, dx, dy, ax, ay)
    o4 = _o(cx, cy, dx, dy, bx, by)
    if o1 == 0 and o2 == 0:
        on_s = [q for q in (c, d) if _between(q, a, b)]
        on_t = [q for q in (a, b) if _between(q, c, d)]
        if on_s or on_t or (a == c and b == d):
            return "overlap", on_s, on_t
        if a == d or b == c:
            return "end", [], []
        return "none", [], []
    if ((o1 > 0 and o2 < 0) or (o1 < 0 and o2 > 0)) and ((o3 > 0 and o4 < 0) or (o3 < 0 and o4 > 0)):
        p = _crossing(s, t)
        return ("cross", [p] if p != a and p != b else [], [p] if p != c and p != d else [])
    on_s, on_t = [], []
    if o1 == 0 and _between(c, a, b):
        on_s.append(c)
    if o2 == 0 and _between(d, a, b):
        on_s.append(d)
    if o3 == 0 and _between(a, c, d):
        on_t.append(a)
    if o4 == 0 and _between(b, c, d):
        on_t.append(b)
    if on_s or on_t:
        return "touch", on_s, on_t
    if a == c or a == d or b == c or b == d:
        return "end", [], []
    return "none", [], []


class Meeting:
    __slots__ = ("kind", "on_s", "on_t")

    def __init__(self, kind, on_s, on_t):
        self.kind = kind
        self.on_s = [point(x, y) for x, y in on_s]
        self.on_t = [point(x, y) for x, y in on_t]

    def __repr__(self):
        return "meeting(%s, %r, %r)" % (self.kind, self.on_s, self.on_t)


def meet(s, t):
    """how two segments meet: "none", "end" (a shared endpoint and nothing
    more), "cross" (their insides cross at one point), "touch" (an endpoint
    of one lies inside the other) or "overlap" (collinear, sharing more
    than a point); and the points each must be split at"""
    return Meeting(*_meet(s, t))


# --------------------------------------------------------------------------
# §22.3 splitting until nothing crosses
# --------------------------------------------------------------------------
class SweepStats:
    """pair tests made, events handled, and passes of the finder"""
    __slots__ = ("tests", "events", "passes")

    def __init__(self):
        self.tests = self.events = self.passes = 0

    def __repr__(self):
        return "sweep_stats(tests=%d, events=%d, passes=%d)" % (self.tests, self.events, self.passes)


def sweep_stats():
    return SweepStats()


def _add_splits(splits, i, pts):
    if pts:
        splits.setdefault(i, set()).update(pts)


def _brute(segs, st):
    splits = {}
    n = len(segs)
    for i in range(n):
        s = segs[i]
        for j in range(i + 1, n):
            st.tests += 1
            _, on_s, on_t = _meet(s, segs[j])
            _add_splits(splits, i, on_s)
            _add_splits(splits, j, on_t)
    return splits


def _sweep(segs, st):
    """the active list: segments in order of their top, each tested against
    the ones still active when it arrives"""
    order = sorted(range(len(segs)), key=lambda i: (segs[i].l[1], segs[i].l[0], segs[i].h[1], segs[i].h[0]))
    splits, active = {}, []
    for i in order:
        s = segs[i]
        active = [j for j in active if _lt(s.l, segs[j].h)]
        for j in active:
            st.tests += 1
            _, on_s, on_t = _meet(s, segs[j])
            _add_splits(splits, i, on_s)
            _add_splits(splits, j, on_t)
        active.append(i)
    return splits


# ---- Bentley-Ottmann ------------------------------------------------------
def _key(X, Y, D):
    return (Fraction(Y, D), Fraction(X, D))


def _orient_at(s, P):
    """orient(s.lo, s.hi, P) for a point P = (X, Y, D), in sign"""
    X, Y, D = P
    (lx, ly), (hx, hy) = s.l, s.h
    return (hx - lx) * (Y - D * ly) - (hy - ly) * (X - D * lx)


def _left_below(s, t):
    """s is left of t just below a point both pass through"""
    return (t.h[0] - t.l[0]) * (s.h[1] - s.l[1]) - (t.h[1] - t.l[1]) * (s.h[0] - s.l[0]) > 0


def _proper(s, t):
    (ax, ay), (bx, by) = s.l, s.h
    (cx, cy), (dx, dy) = t.l, t.h
    o1 = _o(ax, ay, bx, by, cx, cy)
    o2 = _o(ax, ay, bx, by, dx, dy)
    o3 = _o(cx, cy, dx, dy, ax, ay)
    o4 = _o(cx, cy, dx, dy, bx, by)
    return ((o1 > 0 and o2 < 0) or (o1 < 0 and o2 > 0)) and ((o3 > 0 and o4 < 0) or (o3 < 0 and o4 > 0))


def _bentley_ottmann(segs, st):
    queue, tops, seen = [], {}, set()

    def push(X, Y, D, top=None):
        k = _key(X, Y, D)
        if top is not None:
            tops.setdefault(k, []).append(top)
        if k not in seen:
            seen.add(k)
            heapq.heappush(queue, (k, (X, Y, D)))

    for i, s in enumerate(segs):
        push(s.l[0], s.l[1], 1, i)
        push(s.h[0], s.h[1], 1)

    status, splits = [], {}

    def test(i, j, k):
        st.tests += 1
        s, t = segs[i], segs[j]
        if _proper(s, t):
            X, Y, D = _crossing_exact(s, t)
            if _key(X, Y, D) > k:
                push(X, Y, D)

    def by_direction(ids):
        # insertion sort with the exact comparison; ties (collinear) by index
        out = []
        for i in sorted(ids):
            pos = len(out)
            while pos > 0 and _left_below(segs[i], segs[out[pos - 1]]):
                pos -= 1
            out.insert(pos, i)
        return out

    while queue:
        k, P = heapq.heappop(queue)
        st.events += 1
        X, Y, D = P
        # the block of the status that contains P
        lo, hi = 0, len(status)
        while lo < hi:
            mid = (lo + hi) // 2
            if _orient_at(segs[status[mid]], P) < 0:
                lo = mid + 1
            else:
                hi = mid
        end = lo
        while end < len(status) and _orient_at(segs[status[end]], P) == 0:
            end += 1
        block = status[lo:end]
        U = tops.get(k, [])
        L = [i for i in block if segs[i].h[0] * D == X and segs[i].h[1] * D == Y]
        C = [i for i in block if i not in L]
        if len(U) + len(L) + len(C) > 1 and C:
            q = (_round_div(X, D), _round_div(Y, D))
            for i in C:
                _add_splits(splits, i, [q])
        new = by_direction(U + C)
        status[lo:end] = new
        if not new:
            if 0 < lo < len(status):
                test(status[lo - 1], status[lo], k)
        else:
            if lo > 0:
                test(status[lo - 1], status[lo], k)
            r = lo + len(new) - 1
            if r + 1 < len(status):
                test(status[r], status[r + 1], k)
    return splits


FINDERS = {"brute": _brute, "sweep": _sweep, "bentley-ottmann": _bentley_ottmann}


def _find(segs, method, st):
    """split points per segment index, excluding each segment's own ends"""
    raw = FINDERS[method](segs, st)
    out = {}
    for i, pts in raw.items():
        s = segs[i]
        pts = [q for q in pts if q != s.l and q != s.h]
        if pts:
            out[i] = pts
    return out


def find_splits(segs, method, st):
    """for every segment, the points it must be split at, in order along it"""
    raw = _find(segs, method, st)
    return [[point(x, y) for x, y in _along(segs[i], raw.get(i, []))] for i in range(len(segs))]


def _along(s, pts):
    (lx, ly), (hx, hy) = s.l, s.h
    return sorted(set(pts), key=lambda q: ((q[0] - lx) * (hx - lx) + (q[1] - ly) * (hy - ly), q[1], q[0]))


def _cut(segs, splits):
    out = []
    for i, s in enumerate(segs):
        pts = splits.get(i)
        if not pts:
            out.append(s)
            continue
        chain = [s.l] + _along(s, pts) + [s.h]
        for u, v in zip(chain, chain[1:]):
            if u != v:
                out.append(Seg(u, v, s.wa, s.wb))
    return out


def merge_segments(segs):
    """identical segments become one, their windings summed; a segment
    whose windings sum to 0 for both paths is dropped. Sorted by lo, then
    hi, in the sweep's order."""
    acc = {}
    for s in segs:
        k = (s.l[1], s.l[0], s.h[1], s.h[0])
        if k in acc:
            acc[k] = (acc[k][0] + s.wa, acc[k][1] + s.wb)
        else:
            acc[k] = (s.wa, s.wb)
    out = []
    for k in sorted(acc):
        wa, wb = acc[k]
        if wa or wb:
            out.append(Seg((k[1], k[0]), (k[3], k[2]), wa, wb))
    return out


def split_segments(segs, method, st):
    """merge, find, cut, and again, until a pass finds nothing to split"""
    segs = merge_segments(segs)
    while True:
        st.passes += 1
        splits = _find(segs, method, st)
        if not splits:
            return segs
        segs = merge_segments(_cut(segs, splits))


# --------------------------------------------------------------------------
# §22.4 which side is inside
# --------------------------------------------------------------------------
def _beside(segs, i, candidates=None):
    e = segs[i]
    mx, my = e.l[0] + e.h[0], e.l[1] + e.h[1]       # the midpoint, doubled
    wa = wb = 0
    for j in (range(len(segs)) if candidates is None else candidates):
        if j == i:
            continue
        f = segs[j]
        lx, ly, hx, hy = 2 * f.l[0], 2 * f.l[1], 2 * f.h[0], 2 * f.h[1]
        if (ly < my or (ly == my and lx <= mx)) and (my < hy or (my == hy and mx < hx)):
            o = _o(lx, ly, hx, hy, mx, my)
            if o == 0:
                raise AssertionError("a segment passes through another's midpoint")
            if o > 0:
                wa += f.wa
                wb += f.wb
    return (wa, wb), (wa + e.wa, wb + e.wb)


def winding_beside(segs, i):
    """the winding numbers of A and B on the two sides of segment i: first
    the side where it doesn't count, then the side where it does (its left,
    or below it when it's horizontal)"""
    return _beside(segs, i)


def inside_rule(w, rule):
    if rule == "nonzero":
        return w != 0
    if rule == "evenodd":
        return w % 2 == 1
    raise ValueError(rule)


def op_inside(op, in_a, in_b):
    if op == "union":
        return in_a or in_b
    if op == "intersection":
        return in_a and in_b
    if op == "difference":
        return in_a and not in_b
    if op == "xor":
        return in_a != in_b
    raise ValueError(op)


def _candidates(segs):
    """for each segment, the others whose range contains its midpoint: a
    sweep over the midpoints, so the classification isn't every pair"""
    events = []
    for i, s in enumerate(segs):
        events.append(((2 * s.l[1], 2 * s.l[0]), 0, i))
        events.append(((2 * s.h[1], 2 * s.h[0]), 2, i))
        events.append(((s.l[1] + s.h[1], s.l[0] + s.h[0]), 1, i))
    events.sort()
    active, out = set(), {}
    for _, kind, i in events:
        if kind == 0:
            active.add(i)
        elif kind == 2:
            active.discard(i)
        else:
            out[i] = list(active)
    return out


def keep_edges(segs, rule_a, rule_b, op):
    return [(point(u[0], u[1]), point(v[0], v[1])) for u, v in _keep(segs, rule_a, rule_b, op)]


def _keep(segs, rule_a, rule_b, op):
    """the segments with the result inside on one side and outside on the
    other, each as a (from, to) pair of grid points directed so the inside
    is on its right as you travel it"""
    cands = _candidates(segs)
    kept = []
    for i, e in enumerate(segs):
        (a0, b0), (a1, b1) = _beside(segs, i, cands[i])
        without = op_inside(op, inside_rule(a0, rule_a), inside_rule(b0, rule_b))
        with_ = op_inside(op, inside_rule(a1, rule_a), inside_rule(b1, rule_b))
        if without != with_:
            kept.append((e.l, e.h) if with_ else (e.h, e.l))
    return kept


# --------------------------------------------------------------------------
# §22.5 stitching
# --------------------------------------------------------------------------
def _turn_key(r, v):
    """counterclockwise angle from r to v as a sortable key, exactly"""
    cr = r[0] * v[1] - r[1] * v[0]
    dt = r[0] * v[0] + r[1] * v[1]
    half = 0 if (cr < 0 or (cr == 0 and dt > 0)) else 1
    return half


def _sharpest_right(r, cands, dirs):
    best = None
    for k in cands:
        v = dirs[k]
        if best is None:
            best = k
            continue
        b = dirs[best]
        hv, hb = _turn_key(r, v), _turn_key(r, b)
        if hv < hb or (hv == hb and b[0] * v[1] - b[1] * v[0] > 0):
            best = k
    return best


def _canonical(contour):
    pts = list(contour)
    changed = True
    while changed and len(pts) >= 3:
        changed = False
        for k in range(len(pts)):
            u, v, w = pts[k - 1], pts[k], pts[(k + 1) % len(pts)]
            if (v[0] - u[0]) * (w[1] - v[1]) - (v[1] - u[1]) * (w[0] - v[0]) == 0:
                del pts[k]
                changed = True
                break
    first = min(range(len(pts)), key=lambda k: (pts[k][1], pts[k][0]))
    return pts[first:] + pts[:first]


def _stitch(kept):
    order = sorted(range(len(kept)), key=lambda k: (kept[k][0][1], kept[k][0][0], kept[k][1][1], kept[k][1][0]))
    out_of = {}
    for k in order:
        out_of.setdefault(kept[k][0], []).append(k)
    dirs = [(v[0] - u[0], v[1] - u[1]) for u, v in kept]
    used = [False] * len(kept)
    contours = []
    for k0 in order:
        if used[k0]:
            continue
        start = kept[k0][0]
        pts, k = [], k0
        while True:
            used[k] = True
            u, v = kept[k]
            pts.append(u)
            if v == start:
                break
            cands = [j for j in out_of.get(v, []) if not used[j]]
            d = dirs[k]
            k = _sharpest_right((-d[0], -d[1]), cands, dirs)
        contours.append(_canonical(pts))
    contours.sort(key=lambda c: [(q[1], q[0]) for q in c])
    return contours


def stitch(kept):
    """link directed edges into closed contours: from each vertex take the
    unused edge that turns furthest right; drop vertices where the contour
    runs straight; start each contour at its topmost-then-leftmost vertex;
    order contours by their points"""
    return [[point(x, y) for x, y in c] for c in _stitch([(_ip(u), _ip(v)) for u, v in kept])]


def contours_to_path(contours):
    p = path()
    for c in contours:
        move_to(p, point(c[0][0] / GRID, c[0][1] / GRID))
        for x, y in c[1:]:
            line_to(p, point(x / GRID, y / GRID))
        close(p)
    return p


def combine_with(a, rule_a, b, rule_b, op, method, st):
    segs = path_segments(a, "a") + path_segments(b, "b")
    segs = split_segments(segs, method, st)
    return contours_to_path(_stitch(_keep(segs, rule_a, rule_b, op)))


def combine(a, rule_a, b, rule_b, op):
    """a boolean operation on two paths: "union", "intersection",
    "difference" (a minus b) or "xor". The result's contours wind clockwise
    around what's inside and counterclockwise around holes, so either fill
    rule fills it the same"""
    return combine_with(a, rule_a, b, rule_b, op, "bentley-ottmann", sweep_stats())


def simplify(p, rule):
    """one path's outline under its fill rule, with every crossing resolved"""
    return combine(p, rule, path(), "nonzero", "union")


def float_crossing(a, b, c, d):
    """the trap: the crossing of a-b with c-d in pixels, in floating point"""
    t = cross(c - a, d - c) / cross(b - a, d - c)
    return point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)


def point_lists(p):
    return [list(sp.points) for sp in subpaths(p)]


def segment_count(p):
    return len(path_segments(p, "a"))


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
INK = color(0.9, 0.55, 0.1)
DIM = color(0.3, 0.3, 0.34)
MAGENTA = color(0.85, 0.2, 0.55)
CYAN = color(0.2, 0.75, 0.9)


def _hairline(c, p, col, width=1.0):
    o = stroke_to_path(p, width, "butt", "round", 4.0)
    paint_through(c, fill_path(o, "nonzero", c.width, c.height), col)


OP_PANEL = 200
OPS = ("union", "intersection", "difference", "xor")


def plate_glyph():
    """Roboto's g, 200 pixels to the em, its origin at (40, 140): the
    plate's path A, filled nonzero"""
    f = roboto()
    return glyph_path(f, glyph_name(f, ord("g")), text_matrix(f, 200, 40, 140), 0.1)


def plate_star():
    """chapter 5's star scaled by 0.85 about (80.5, 80.5) and moved to
    (130, 104): path B, filled even-odd"""
    m = translation(130 - 80.5, 104 - 80.5) * translation(80.5, 80.5) * scaling(0.85, 0.85) * translation(-80.5, -80.5)
    return transform_path(star(), m)


def op_panel(op):
    c = canvas(OP_PANEL, OP_PANEL)
    fill(c, PAPER)
    a, b = plate_glyph(), plate_star()
    r = combine(a, "nonzero", b, "evenodd", op)
    paint_through(c, fill_path(r, "nonzero", OP_PANEL, OP_PANEL), INK)
    _hairline(c, a, DIM)
    _hairline(c, b, DIM)
    _hairline(c, r, MAGENTA)
    return c


def plate_22():
    out = op_panel(OPS[0])
    for op in OPS[1:]:
        out = side_by_side(out, op_panel(op))
    return out




# ---- the benchmark: a line of text struck through ------------------------
def struck_line(n):
    """the word Pathfinder n times, a space between, at 120 / n pixels to
    the em from (20, 160); and 14n bars slanting down to the left through
    it. Answers (text, bars)."""
    text = text_path(roboto(), " ".join(["Pathfinder"] * n), 120 / n, 20, 160)
    bars = path()
    for k in range(14 * n):
        x = -40 + 48 * k / n
        move_to(bars, point(x, 100))
        line_to(bars, point(x + 22 / n, 100))
        line_to(bars, point(x - 40 / n, 200))
        line_to(bars, point(x - 62 / n, 200))
        close(bars)
    return text, bars


def struck_segments(n):
    text, bars = struck_line(n)
    return merge_segments(path_segments(text, "a") + path_segments(bars, "b"))


# ---- the demo: a seal built from nothing but combine ---------------------
def text_path(font, text, size, x, y):
    """a run of text as one path: every glyph of layout_run with kerning,
    flattened to 0.1 pixel"""
    from chapter18 import layout_run
    p = path()
    for pl in layout_run(font, text, size, x, y, True):
        for sp in subpaths(glyph_path(font, pl.name, text_matrix(font, size, pl.x, pl.y), 0.1)):
            p.subpaths.append(sp)
    return p


def _union_all(paths):
    out = paths[0]
    for q in paths[1:]:
        out = combine(out, "nonzero", q, "nonzero", "union")
    return out


SEAL = 480


def seal_parts():
    """the pieces the seal is combined from"""
    cx = cy = SEAL / 2
    rim = _union_all([circle_path(cx, cy, 200, 120)] +
                     [circle_path(cx + 200 * math.cos(2 * math.pi * k / 40),
                                  cy + 200 * math.sin(2 * math.pi * k / 40), 16, 24) for k in range(40)])
    ring = combine(rim, "nonzero", circle_path(cx, cy, 168, 120), "nonzero", "difference")
    band = polygon(point(20, 196), point(460, 196), point(460, 284), point(20, 284))
    words = text_path(roboto(), "BOOLEAN", 84, 52, 270)
    return rim, ring, band, words


def rosette(cx, cy, n, r, d):
    """n circles of radius r, their centers on a circle of radius d about
    (cx, cy), combined one at a time by xor"""
    out = path()
    for k in range(n):
        a = 2 * math.pi * k / n
        out = combine(out, "nonzero", circle_path(cx + d * math.cos(a), cy + d * math.sin(a), r, 72),
                      "nonzero", "xor")
    return out


def seal():
    rim, ring, band, words = seal_parts()
    s = combine(ring, "nonzero", band, "nonzero", "union")
    s = combine(s, "nonzero", words, "nonzero", "xor")
    s = combine(s, "nonzero", transform_path(star(), translation(SEAL / 2 - 80.5, 104 - 80.5)), "evenodd", "xor")
    s = combine(s, "nonzero", rosette(SEAL / 2, 352, 16, 44, 36), "nonzero", "xor")
    c = canvas(SEAL, SEAL)
    fill(c, PAPER)
    paint_through(c, fill_path(s, "nonzero", SEAL, SEAL), INK)
    _hairline(c, s, MAGENTA, 0.75)
    return c


RENDERS = {
    "plate-22": plate_22,
    "seal": seal,
}
