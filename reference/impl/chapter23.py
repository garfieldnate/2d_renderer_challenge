"""
Chapter 23, Distance Fields: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

A field stores, at every pixel center, the signed distance to the nearest
edge: negative inside, positive outside. Coverage is clamp(0.5 - d, 0, 1).
Offset, stroke and the boolean operations are one line each on a field;
the price is that they compose only approximately. The distance transform
turns any bitmap into a field; a small baked field magnified shows why
glyph atlases went multi-channel.
"""

import math

from renderer import canvas, color, fill, mix, clamp, write_pixel, pixel_at
from chapter02 import coverage_buffer, coverage_at, set_coverage, paint_through, ink, magnify
from chapter04 import point, vector, magnitude, dot, cross, translation, scaling, side_by_side
from chapter05 import path, move_to, line_to, close, edges, polygon, star, circle_path, winding_at
from chapter06 import transform_path, max_coverage_difference
from chapter07 import fill_path
from chapter08 import quadratic, cubic, point_at, derivative, split_at, transform_curve, flatten_into_path
from chapter13 import stroke_to_path
from chapter14 import distance_to_curve, second_derivative, stroke_curve_to_path
from chapter16 import roboto, glyph_outline, glyph_path, text_matrix, glyph_name, glyph_bounds
from chapter22 import combine, simplify, plate_glyph, plate_star

CHAPTER = 23
FORMAT = "P6"


# --------------------------------------------------------------------------
# §23.1 exact fields for primitives
# --------------------------------------------------------------------------
def sd_circle(p, c, r):
    return magnitude(p - c) - r


def distance_to_segment(p, a, b):
    """unsigned: a segment has no inside"""
    ab = b - a
    L = dot(ab, ab)
    t = 0.0 if L == 0 else clamp(dot(p - a, ab) / L)
    return magnitude(p - (a + ab * t))


def sd_box(p, c, hw, hh):
    """a box centered on c, hw and hh from the center to its sides"""
    qx, qy = abs(p.x - c.x) - hw, abs(p.y - c.y) - hh
    outside = math.sqrt(max(qx, 0.0) ** 2 + max(qy, 0.0) ** 2)
    return outside + min(max(qx, qy), 0.0)


def sd_rounded_box(p, c, hw, hh, r):
    return sd_box(p, c, hw - r, hh - r) - r


def inside_by(w, rule):
    return w != 0 if rule == "nonzero" else w % 2 == 1


def sd_polygon(p, pa, rule):
    """the distance to the nearest edge, negative where chapter 5 says the
    point is inside under the rule"""
    d = min(distance_to_segment(p, a, b) for a, b in edges(pa))
    return -d if inside_by(winding_at(pa, p.x, p.y), rule) else d


# --------------------------------------------------------------------------
# §23.2 fields for curves
# --------------------------------------------------------------------------
def solve_cubic(a, b, c, d):
    """the real roots of a t^3 + b t^2 + c t + d = 0, in increasing order;
    falls back to the quadratic, then the linear, when leading
    coefficients vanish"""
    if abs(a) < 1e-12:
        if abs(b) < 1e-12:
            if abs(c) < 1e-12:
                return []
            return [-d / c]
        disc = c * c - 4 * b * d
        if disc < 0:
            return []
        s = math.sqrt(disc)
        return sorted([(-c - s) / (2 * b), (-c + s) / (2 * b)])
    b, c, d = b / a, c / a, d / a
    p = c - b * b / 3
    q = 2 * b * b * b / 27 - b * c / 3 + d
    shift = -b / 3
    disc = q * q / 4 + p * p * p / 27
    if disc > 0:
        s = math.sqrt(disc)
        u = math.copysign(abs(-q / 2 + s) ** (1 / 3), -q / 2 + s)
        v = math.copysign(abs(-q / 2 - s) ** (1 / 3), -q / 2 - s)
        return [u + v + shift]
    if p == 0:
        return [shift]
    r = math.sqrt(-p / 3)
    arg = clamp(3 * q / (2 * p) / r, -1.0, 1.0)
    phi = math.acos(arg) / 3
    roots = [2 * r * math.cos(phi - 2 * math.pi * k / 3) + shift for k in range(3)]
    return sorted(roots)


def distance_to_quadratic(p, c):
    """exact: the nearest point is where (B(t) - p) . B'(t) = 0, a cubic in
    t, or an end"""
    p0, p1, p2 = c.points
    a0 = p0 - p
    a1 = (p1 - p0) * 2
    a2 = p0 - p1 * 2 + p2
    ts = [0.0, 1.0] + [t for t in solve_cubic(2 * dot(a2, a2), 3 * dot(a1, a2),
                                              dot(a1, a1) + 2 * dot(a0, a2), dot(a0, a1))
                       if 0 < t < 1]
    return min(magnitude(point_at(c, t) - p) for t in ts)


def nearest_t_cubic(p, c):
    """Newton on f(t) = (B(t) - p) . B'(t) from nine seeds t = i / 8, eight
    steps each, clamped to [0, 1]; the t of the smallest distance among the
    two ends and the nine results"""
    best_t, best = 0.0, magnitude(point_at(c, 0.0) - p)
    d = magnitude(point_at(c, 1.0) - p)
    if d < best:
        best_t, best = 1.0, d
    for i in range(9):
        t = i / 8
        for _ in range(8):
            q = point_at(c, t) - p
            d1 = derivative(c, t)
            d2 = second_derivative(c, t)
            f = dot(q, d1)
            fp = dot(d1, d1) + dot(q, d2)
            if fp == 0:
                break
            t = clamp(t - f / fp)
        d = magnitude(point_at(c, t) - p)
        if d < best:
            best_t, best = t, d
    return best_t


def distance_to_cubic(p, c):
    return magnitude(point_at(c, nearest_t_cubic(p, c)) - p)


def weyl_points(n, x0, y0, w, h):
    """n points spread evenly over a box, the same in every language:
    point k is (x0 + w frac(k a), y0 + h frac(k b)) with a and b the
    plastic number's reciprocals, the R2 sequence"""
    a, b = 0.7548776662466927, 0.5698402909980532
    out = []
    for k in range(1, n + 1):
        u, v = k * a, k * b
        out.append(point(x0 + w * (u - math.floor(u)), y0 + h * (v - math.floor(v))))
    return out


def brute_distance(c, p):
    """the ground truth, by search: sample t = i / 128, and refine every
    sample that's no farther than its neighbours (an end counts as having
    one neighbour) by 40 rounds of ternary search between its
    neighbours; the smallest distance found"""
    n = 128
    ds = [magnitude(point_at(c, i / n) - p) for i in range(n + 1)]
    best = min(ds)
    for i in range(n + 1):
        if (i == 0 or ds[i] <= ds[i - 1]) and (i == n or ds[i] <= ds[i + 1]):
            lo, hi = max(0, i - 1) / n, min(n, i + 1) / n
            for _ in range(40):
                m1, m2 = lo + (hi - lo) / 3, hi - (hi - lo) / 3
                if magnitude(point_at(c, m1) - p) < magnitude(point_at(c, m2) - p):
                    hi = m2
                else:
                    lo = m1
            best = min(best, magnitude(point_at(c, (lo + hi) / 2) - p))
    return best


def max_curve_error(c, pts):
    """the largest difference between this chapter's distance and the
    brute-force search, over the points"""
    f = distance_to_quadratic if len(c.points) == 3 else distance_to_cubic
    return max(abs(f(q, c) - brute_distance(c, q)) for q in pts)


def glyph_curves(font, name, m):
    """every quadratic of the glyph through m, in device space"""
    return [transform_curve(c, m) for contour in glyph_outline(font, name) for c in contour]


def sd_curves(p, curves, sign_path, rule):
    """the distance to the nearest curve, negative where the flattened path
    winds around the point under the rule"""
    d = min(distance_to_quadratic(p, c) if len(c.points) == 3 else distance_to_cubic(p, c)
            for c in curves)
    return -d if inside_by(winding_at(sign_path, p.x, p.y), rule) else d


# --------------------------------------------------------------------------
# §23.3 render it
# --------------------------------------------------------------------------
class Field:
    __slots__ = ("width", "height", "values")

    def __init__(self, w, h, values=None):
        self.width, self.height = w, h
        self.values = values if values is not None else [0.0] * (w * h)


def field(w, h, fn):
    """a field sampled at every pixel center: fn(point(x + 0.5, y + 0.5))"""
    f = Field(w, h)
    for y in range(h):
        for x in range(w):
            f.values[y * w + x] = fn(point(x + 0.5, y + 0.5))
    return f


def field_of(w, h, values):
    """a field from a list of values, row by row"""
    return Field(w, h, [float(v) for v in values])


def field_at(f, x, y):
    return f.values[y * f.width + x]


def field_range(f):
    """(least, greatest) value"""
    return (min(f.values), max(f.values))


def field_coverage(f):
    cov = coverage_buffer(f.width, f.height)
    for i, d in enumerate(f.values):
        cov.values[i] = clamp(0.5 - d)
    return cov


def circle_field(cx, cy, r, w, h):
    return field(w, h, lambda q: sd_circle(q, point(cx, cy), r))


def cubic_field(c, w, h):
    """the unsigned field of one cubic"""
    return field(w, h, lambda q: distance_to_cubic(q, c))


def polygon_field(pa, rule, w, h):
    return field(w, h, lambda q: sd_polygon(q, pa, rule))


def coverage_error(cov, exact):
    """per pixel, how far the field's coverage is from the exact one"""
    out = coverage_buffer(cov.width, cov.height)
    for i in range(len(cov.values)):
        out.values[i] = abs(cov.values[i] - exact.values[i])
    return out


# --------------------------------------------------------------------------
# §23.4 chapters 13, 14 and 22 for free
# --------------------------------------------------------------------------
def _map(f, fn):
    return Field(f.width, f.height, [fn(d) for d in f.values])


def _zip(a, b, fn):
    return Field(a.width, a.height, [fn(x, y) for x, y in zip(a.values, b.values)])


def field_offset(f, r):
    """grow the shape by r (shrink it when r < 0)"""
    return _map(f, lambda d: d - r)


def field_stroke(f, width):
    return _map(f, lambda d: abs(d) - width / 2)


def min_of(a, b):
    return min(a, b)


def field_union(a, b):
    return _zip(a, b, min)


def field_intersection(a, b):
    return _zip(a, b, max)


def field_difference(a, b):
    return _zip(a, b, lambda x, y: max(x, -y))


def field_xor(a, b):
    return _zip(a, b, lambda x, y: max(min(x, y), -max(x, y)))


FIELD_OPS = {"union": field_union, "intersection": field_intersection,
             "difference": field_difference, "xor": field_xor}


def field_combine(a, b, op):
    return FIELD_OPS[op](a, b)


# --------------------------------------------------------------------------
# §23.5 something paths can't do
# --------------------------------------------------------------------------
def smooth_min(a, b, k):
    """the polynomial smooth minimum: min(a, b) where they're more than k
    apart, rounded off by up to k / 4 where they're close"""
    if k <= 0:
        return min(a, b)
    h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k / 4


def field_smooth_union(a, b, k):
    return _zip(a, b, lambda x, y: smooth_min(x, y, k))


# --------------------------------------------------------------------------
# §23.6 the distance transform
# --------------------------------------------------------------------------
def edt_1d(f):
    """Felzenszwalb and Huttenlocher: d[q] = min over p of (q - p)^2 + f[p],
    by the lower envelope of the parabolas rooted at each p"""
    n = len(f)
    v = [0] * n                  # the parabolas on the envelope, left to right
    z = [0.0] * (n + 1)          # where each one takes over
    k = 0
    z[0], z[1] = -math.inf, math.inf

    def meet_at(q, p):
        return ((f[q] + q * q) - (f[p] + p * p)) / (2 * q - 2 * p)

    for q in range(1, n):
        s = meet_at(q, v[k])
        while s <= z[k]:
            k -= 1
            s = meet_at(q, v[k])
        k += 1
        v[k] = q
        z[k] = s
        z[k + 1] = math.inf
    d = [0.0] * n
    k = 0
    for q in range(n):
        while z[k + 1] < q:
            k += 1
        d[q] = (q - v[k]) * (q - v[k]) + f[v[k]]
    return d


def far_value(w, h):
    return w * w + h * h


def distance_transform(bits, w, h):
    """squared distance from every pixel center to the nearest pixel center
    that's on, columns first then rows; far_value(w, h) where nothing is
    on, which falls out: no answer can exceed the far value it started at"""
    big = far_value(w, h)
    g = [0.0 if b else big for b in bits]
    for x in range(w):
        col = edt_1d([g[y * w + x] for y in range(h)])
        for y in range(h):
            g[y * w + x] = col[y]
    out = []
    for y in range(h):
        out.extend(edt_1d(g[y * w:(y + 1) * w]))
    return out


def brute_distance_transform(bits, w, h):
    big = far_value(w, h)
    ons = [(i % w, i // w) for i, b in enumerate(bits) if b]
    out = []
    for y in range(h):
        for x in range(w):
            out.append(min([(x - a) ** 2 + (y - b) ** 2 for a, b in ons] + [big]))
    return out


def coverage_of(w, h, values):
    """a coverage buffer from a list of values, row by row"""
    cov = coverage_buffer(w, h)
    cov.values = [float(v) for v in values]
    return cov


def bits_of(cov):
    """a pixel is on when its coverage is at least a half"""
    return [v >= 0.5 for v in cov.values]


def field_from_coverage(cov):
    """a field from any coverage buffer: outside, the distance to the
    nearest inside pixel center less a half; inside, minus the distance to
    the nearest outside one, less a half"""
    w, h = cov.width, cov.height
    on = bits_of(cov)
    to_in = distance_transform(on, w, h)
    to_out = distance_transform([not b for b in on], w, h)
    vals = []
    for i in range(w * h):
        if on[i]:
            vals.append(-(math.sqrt(to_out[i]) - 0.5))
        else:
            vals.append(math.sqrt(to_in[i]) - 0.5)
    return Field(w, h, vals)


# --------------------------------------------------------------------------
# §23.7 glyph atlases
# --------------------------------------------------------------------------
class Baked:
    """a small field (or three, one per channel) baked for one glyph, and
    where its top left texel sits relative to the glyph's origin"""
    __slots__ = ("channels", "left", "top", "width", "height")

    def __init__(self, channels, left, top):
        self.channels = channels
        self.left, self.top = left, top
        self.width, self.height = channels[0].width, channels[0].height


def bake_box(font, name, size, spread):
    """chapter 17's bitmap box at the quarter 0, grown by spread texels all
    round: (left, top, width, height) and the matrix that puts the glyph in
    it"""
    s = size / font.units_per_em
    x0, y0, x1, y1 = glyph_bounds(font, name)
    left = math.floor(x0 * s) - spread
    right = math.ceil(x1 * s) + spread
    top = math.floor(-y1 * s) - spread
    bottom = math.ceil(-y0 * s) + spread
    return left, top, right - left, bottom - top, text_matrix(font, size, -left, -top)


def bake_sdf(font, name, size, spread):
    """one channel: the glyph's signed distance at every texel center,
    clamped to +-spread"""
    left, top, w, h, m = bake_box(font, name, size, spread)
    curves = glyph_curves(font, name, m)
    sign_path = glyph_path(font, name, m, 0.01)
    f = field(w, h, lambda q: clamp(sd_curves(q, curves, sign_path, "nonzero"), -spread, spread))
    return Baked([f], left, top)


def sample_field(f, sx, sy):
    """bilinear in texel-center space, like chapter 11, clamped at the rim"""
    gx, gy = sx - 0.5, sy - 0.5
    x0, y0 = math.floor(gx), math.floor(gy)
    fx, fy = gx - x0, gy - y0

    def at(ix, iy):
        ix = 0 if ix < 0 else f.width - 1 if ix >= f.width else ix
        iy = 0 if iy < 0 else f.height - 1 if iy >= f.height else iy
        return f.values[iy * f.width + ix]
    top = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * fx
    bot = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * fx
    return top + (bot - top) * fy


def median3(a, b, c):
    return max(min(a, b), min(max(a, b), c))


def draw_baked(c, bk, scale, x, y, col):
    """draw a baked glyph with its origin at (x, y), every texel scale
    pixels wide: each canvas pixel center goes back to texel space, each
    channel is sampled bilinearly, the median of three (or the one) is the
    distance in texels, and scale times that is the distance in pixels"""
    x0 = math.floor(x + bk.left * scale)
    y0 = math.floor(y + bk.top * scale)
    x1 = math.ceil(x + (bk.left + bk.width) * scale)
    y1 = math.ceil(y + (bk.top + bk.height) * scale)
    for py in range(max(0, y0), min(c.height, y1)):
        for px in range(max(0, x0), min(c.width, x1)):
            u = (px + 0.5 - x) / scale - bk.left
            v = (py + 0.5 - y) / scale - bk.top
            ds = [sample_field(f, u, v) for f in bk.channels]
            d = ds[0] if len(ds) == 1 else median3(*ds)
            k = clamp(0.5 - d * scale)
            if k > 0:
                write_pixel(c, px, py, mix(pixel_at(c, px, py), col, k, True))


# ---- multi-channel -------------------------------------------------------
RED, GREEN, BLUE = 1, 2, 4
CYAN_EDGE, MAGENTA_EDGE, YELLOW_EDGE, WHITE_EDGE = GREEN | BLUE, RED | BLUE, RED | GREEN, 7
CORNER_SIN = math.sin(3.0)


def _dir(c, t):
    """the curve's direction at t, falling back to the chord where the
    derivative vanishes"""
    d = derivative(c, t)
    if magnitude(d) < 1e-12:
        d = c.points[-1] - c.points[0]
    return d * (1 / magnitude(d))


def line_curve(a, b):
    """a straight edge as a quadratic, its control point at the middle,
    the way chapter 16 turns TrueType's lines into curves"""
    return quadratic(a, (a + b) * 0.5, b)


def circle_curves(cx, cy, r):
    """a circle as eight quadratics, ends on the circle at angles 2 pi i / 8,
    controls where the ends' tangents meet"""
    k = r / math.cos(math.pi / 8)
    out = []
    for i in range(8):
        a0, a1, am = 2 * math.pi * i / 8, 2 * math.pi * (i + 1) / 8, 2 * math.pi * (i + 0.5) / 8
        out.append(quadratic(point(cx + r * math.cos(a0), cy + r * math.sin(a0)),
                             point(cx + k * math.cos(am), cy + k * math.sin(am)),
                             point(cx + r * math.cos(a1), cy + r * math.sin(a1))))
    return out


def is_corner(a, b):
    """two unit directions meet at a corner when they turn by more than
    pi - 3 radians, about 8 degrees"""
    return dot(a, b) <= 0 or abs(cross(a, b)) > CORNER_SIN


def color_edges(contour):
    """the colours of one closed contour's curves, as channel masks: no
    corner, all white; one corner, three runs from it, cyan, white,
    magenta; more, the runs between corners alternate cyan and magenta,
    and the last is yellow when there's an odd number of them. Answers
    (curves, masks), splitting curves in half first when a one-corner
    contour has fewer than three"""
    n = len(contour)
    corners = [i for i in range(n) if is_corner(_dir(contour[i - 1], 1.0), _dir(contour[i], 0.0))]
    if not corners:
        return list(contour), [WHITE_EDGE] * n
    start = corners[0]
    curves = contour[start:] + contour[:start]
    if len(corners) == 1:
        while len(curves) < 3:
            curves = [h for c in curves for h in split_at(c, 0.5)]
        m = len(curves)
        runs = [CYAN_EDGE, WHITE_EDGE, MAGENTA_EDGE]
        return curves, [runs[3 * j // m] for j in range(m)]
    rel = [(i - start) % n for i in corners]
    run_of, r = [], -1
    for j in range(n):
        if j in rel:
            r += 1
        run_of.append(r)
    count = len(corners)
    masks = []
    for j in range(n):
        k = run_of[j]
        if count % 2 == 1 and k == count - 1:
            masks.append(YELLOW_EDGE)
        else:
            masks.append(CYAN_EDGE if k % 2 == 0 else MAGENTA_EDGE)
    return curves, masks


def nearest_on_quadratic(p, c):
    """(distance, t) of the nearest point"""
    p0, p1, p2 = c.points
    a0, a1, a2 = p0 - p, (p1 - p0) * 2, p0 - p1 * 2 + p2
    ts = [0.0, 1.0] + [t for t in solve_cubic(2 * dot(a2, a2), 3 * dot(a1, a2),
                                              dot(a1, a1) + 2 * dot(a0, a2), dot(a0, a1))
                       if 0 < t < 1]
    return min((magnitude(point_at(c, t) - p), t) for t in ts)


def pseudo_distance(p, c, t, d):
    """the signed distance to the curve, except beyond an end, where it's
    the distance to the line the end's tangent runs along; negative on the
    curve's right, which is inside for a clockwise contour"""
    if t == 0.0 or t == 1.0:
        e = point_at(c, t)
        tan = _dir(c, t)
        along = dot(p - e, tan)
        if (t == 0.0 and along < 0) or (t == 1.0 and along > 0):
            side = cross(tan, p - e)
            return -abs(side) if side > 0 else abs(side)
    side = cross(_dir(c, t), p - point_at(c, t))
    return -d if side > 0 else d


def _orthogonality(p, c, t):
    e = point_at(c, t)
    v = p - e
    m = magnitude(v)
    return 0.0 if m == 0 else abs(dot(_dir(c, t), v * (1 / m)))


def msdf_texel(p, edges_, spread):
    out = []
    for ch in (RED, GREEN, BLUE):
        best = None
        for c, mask in edges_:
            if not mask & ch:
                continue
            d, t = nearest_on_quadratic(p, c)
            key = (d, _orthogonality(p, c, t) if t in (0.0, 1.0) else 0.0)
            if best is None or key[0] < best[0][0] - 1e-12 or (abs(key[0] - best[0][0]) <= 1e-12 and key[1] < best[0][1]):
                best = (key, c, t, d)
        v = pseudo_distance(p, best[1], best[2], best[3])
        out.append(clamp(v, -spread, spread))
    return out


def glyph_edges(font, name, m):
    """every contour's quadratics through m, coloured"""
    out = []
    for contour in glyph_outline(font, name):
        curves, masks = color_edges([transform_curve(c, m) for c in contour])
        out.extend(zip(curves, masks))
    return out


def bake_msdf(font, name, size, spread):
    """three channels, each the pseudo-distance to the nearest edge that
    carries it, clamped to +-spread"""
    left, top, w, h, m = bake_box(font, name, size, spread)
    es = glyph_edges(font, name, m)
    chans = [Field(w, h) for _ in range(3)]
    for y in range(h):
        for x in range(w):
            vals = msdf_texel(point(x + 0.5, y + 0.5), es, spread)
            for k in range(3):
                chans[k].values[y * w + x] = vals[k]
    return Baked(chans, left, top)


def bake_mtsdf(font, name, size, spread):
    """bake_msdf's three channels and a fourth, bake_sdf's true distance,
    for effects that reach away from the edge"""
    m = bake_msdf(font, name, size, spread)
    return Baked(m.channels + bake_sdf(font, name, size, spread).channels, m.left, m.top)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
INK = color(0.9, 0.55, 0.1)
CYAN = color(0.2, 0.75, 0.9)
MAGENTA = color(0.85, 0.2, 0.55)
PALE = color(0.92, 0.9, 0.82)
DIM = color(0.3, 0.3, 0.34)
BLACK = color(0, 0, 0)


def band_color(d):
    """paper tinted orange outside and cyan inside, in bands 6 pixels wide
    that alternate 0.12 and 0.3 of the tint, and a pale zero line where
    |d| < 1, mixed in by 1 - |d|"""
    tint = INK if d > 0 else CYAN
    col = mix(PAPER, tint, 0.12 if math.floor(abs(d) / 6) % 2 == 0 else 0.3, True)
    if abs(d) < 1:
        col = mix(col, PALE, 1 - abs(d), True)
    return col


def band_canvas(f):
    c = canvas(f.width, f.height)
    for i, d in enumerate(f.values):
        c.pixels[i] = band_color(d)
    return c


def paint_field(c, f, col):
    paint_through(c, field_coverage(f), col)


def paper(w, h):
    c = canvas(w, h)
    fill(c, PAPER)
    return c


def _row(*cs):
    out = cs[0]
    for c in cs[1:]:
        out = side_by_side(out, c)
    return out


def _stack(a, b):
    out = canvas(a.width, a.height + b.height)
    out.pixels = a.pixels + b.pixels
    return out


def primitive_fields():
    """the bands of four fields, 160 pixels square each: a circle, a box, a
    rounded box and chapter 5's star under even-odd"""
    c0 = point(80, 80)
    return _row(band_canvas(field(160, 160, lambda q: sd_circle(q, c0, 50))),
                band_canvas(field(160, 160, lambda q: sd_box(q, c0, 55, 35))),
                band_canvas(field(160, 160, lambda q: sd_rounded_box(q, c0, 55, 35, 20))),
                band_canvas(polygon_field(star(), "evenodd", 160, 160)))


def error_map():
    """chapter 5's star, nonzero, 160 square: the field of the star's own
    edges, filled; its error against chapter 7, magenta mixed into paper by
    4 times the error; and the error of the field of simplify(star), the
    outline chapter 22 makes of it"""
    exact = fill_path(star(), "nonzero", 160, 160)
    raw = polygon_field(star(), "nonzero", 160, 160)
    clean = polygon_field(simplify(star(), "nonzero"), "nonzero", 160, 160)
    left = paper(160, 160)
    paint_field(left, raw, INK)
    panels = [left]
    for f in (raw, clean):
        err = coverage_error(field_coverage(f), exact)
        c = paper(160, 160)
        for i, e in enumerate(err.values):
            c.pixels[i] = mix(PAPER, MAGENTA, min(1.0, 4 * e), True)
        panels.append(c)
    return _row(*panels)


def s_curve():
    return cubic(point(30, 150), point(40, 20), point(160, 180), point(170, 50))


def glyph_field(font, name, m, w, h):
    curves = glyph_curves(font, name, m)
    sign_path = glyph_path(font, name, m, 0.01)
    return field(w, h, lambda q: sd_curves(q, curves, sign_path, "nonzero"))


def plate_glyph_field():
    f = roboto()
    return glyph_field(f, glyph_name(f, ord("g")), text_matrix(f, 200, 40, 140), 200, 200)


def path_panels():
    """the top row of fields_vs_paths, drawn by chapters 13, 14 and 22"""
    a = paper(200, 200)
    paint_through(a, fill_path(stroke_to_path(transform_path(star(), translation(19.5, 19.5)), 10, "round", "round", 4.0),
                               "nonzero", 200, 200), INK)
    b = paper(200, 200)
    paint_through(b, fill_path(stroke_curve_to_path(s_curve(), 20, "round", 0.05), "nonzero", 200, 200), INK)
    c = paper(200, 200)
    paint_through(c, fill_path(combine(plate_glyph(), "nonzero", plate_star(), "evenodd", "xor"), "nonzero", 200, 200), INK)
    return a, b, c


def field_panels():
    """the bottom row: the same three as one line each on a field"""
    sp = transform_path(star(), translation(19.5, 19.5))
    fa = field_stroke(polygon_field(sp, "nonzero", 200, 200), 10)
    fb = field_stroke(cubic_field(s_curve(), 200, 200), 20)
    fc = field_xor(plate_glyph_field(), polygon_field(plate_star(), "evenodd", 200, 200))
    out = []
    for f in (fa, fb, fc):
        c = paper(200, 200)
        paint_field(c, f, INK)
        out.append(c)
    return out


def fields_vs_paths():
    top = _row(*path_panels())
    bottom = _row(*field_panels())
    return _stack(top, bottom)


def fillet_field(k):
    c0, c1 = point(60, 70), point(105, 95)
    return field(160, 160, lambda q: smooth_min(sd_circle(q, c0, 36), sd_rounded_box(q, c1, 40, 25, 4), k))


def fillets():
    """a circle and a rounded box, smooth-unioned with k = 0, 8, 16 and 32:
    filled orange, and a pale line where |d| < 1"""
    panels = []
    for k in (0, 8, 16, 32):
        f = fillet_field(k)
        c = paper(160, 160)
        paint_field(c, f, INK)
        paint_field(c, field_stroke(f, 1.5), PALE)
        panels.append(c)
    return _row(*panels)


def transform_bitmap():
    """chapter 16's g at 48 pixels to the em, origin (14, 44), filled by
    chapter 7 into a 64 by 64 coverage buffer"""
    f = roboto()
    return fill_path(glyph_path(f, glyph_name(f, ord("g")), text_matrix(f, 48, 14, 44), 0.1), "nonzero", 64, 64)


def transform_demo():
    """the bitmap, its field's bands, and its field offset by 0, 3 and 6
    stroked 1.5 wide, each 64 square and magnified 3 times"""
    cov = transform_bitmap()
    f = field_from_coverage(cov)
    a = paper(64, 64)
    paint_through(a, cov, INK)
    b = band_canvas(f)
    c = paper(64, 64)
    for r, col in ((6, MAGENTA), (3, CYAN), (0, INK)):
        paint_field(c, field_stroke(field_offset(f, r), 1.5), col)
    return magnify(_row(a, b, c), 3)


def _baked_panel(bk, scale):
    c = paper(300, 400)
    draw_baked(c, bk, scale, 10 - bk.left * scale, 10 - bk.top * scale, INK)
    return c


def atlas_corners():
    """E baked at 16 pixels, spread 3: one channel at 20x, then three; k
    baked at 16 at 20x, then at 32 at 10x; each in a 300 by 400 panel with
    the baked box's top left at (10, 10)"""
    f = roboto()
    e, k = glyph_name(f, ord("E")), glyph_name(f, ord("k"))
    return _row(_baked_panel(bake_sdf(f, e, 16, 3), 20), _baked_panel(bake_msdf(f, e, 16, 3), 20),
                _baked_panel(bake_msdf(f, k, 16, 3), 20), _baked_panel(bake_msdf(f, k, 32, 3), 10))


def plate_field():
    """Roboto's ampersand at 170 pixels to the em, origin (38, 164), in a
    200 by 200 field"""
    f = roboto()
    return glyph_field(f, glyph_name(f, ord("&")), text_matrix(f, 170, 38, 164), 200, 200)


def plate_23():
    """one field, four ways: its bands; filled; outlined, cyan through
    |d| - 2; and glowing, magenta mixed into paper by 0.8 exp(-d / 10)
    outside, then filled"""
    f = plate_field()
    bands = band_canvas(f)
    filled = paper(200, 200)
    paint_field(filled, f, INK)
    outline = paper(200, 200)
    paint_field(outline, field_stroke(f, 4), CYAN)
    glow = paper(200, 200)
    for i, d in enumerate(f.values):
        if d > 0:
            glow.pixels[i] = mix(PAPER, MAGENTA, 0.8 * math.exp(-d / 10), True)
    paint_field(glow, f, INK)
    return _row(bands, filled, outline, glow)


def peanut():
    """two circles, 96-gons of radius 40 about (60, 80) and (110, 80)"""
    return circle_path(60, 80, 40, 96), circle_path(110, 80, 40, 96)


def trap_shrink():
    """the peanut shrunk by 20, twice, on 170 by 160 panels: on the left
    the union of the circles' fields by min, on the right the field of
    chapter 22's union of the paths; each filled orange, with the unshrunk
    outline (the field's stroke 1.5 wide) in dim"""
    a, b = peanut()
    by_min = field_union(polygon_field(a, "nonzero", 170, 160), polygon_field(b, "nonzero", 170, 160))
    exact = polygon_field(combine(a, "nonzero", b, "nonzero", "union"), "nonzero", 170, 160)
    out = []
    for f in (by_min, exact):
        c = paper(170, 160)
        paint_field(c, field_offset(f, -20), INK)
        paint_field(c, field_stroke(f, 1.5), DIM)
        out.append(c)
    return _row(*out)


TITLE = "DISTANCE"


def title():
    """DISTANCE, every glyph an MTSDF baked at 32 pixels with spread 4 and
    drawn at scale 5, laid out by chapter 18 at 160 pixels from (78, 172)
    on 900 by 220 paper, in four passes over the run: a black shadow
    moved by (8, 8), a magenta glow, the orange fill, a pale outline"""
    from chapter18 import layout_run
    f = roboto()
    run = layout_run(f, TITLE, 160, 78, 172, True)
    baked = {}
    for pl in run:
        if pl.name not in baked:
            baked[pl.name] = bake_mtsdf(f, pl.name, 32, 4)
    c = paper(900, 220)
    passes = [
        (8, 8, BLACK, True, lambda d: 0.6 * clamp((10 - d) / 20)),
        (0, 0, MAGENTA, True, lambda d: 0.8 * (1 - clamp(d / 20)) ** 2),
        (0, 0, INK, False, lambda d: clamp(0.5 - d)),
        (0, 0, PALE, False, lambda d: clamp(0.5 - (abs(d) - 1.5))),
    ]
    for dx, dy, col, true, k_of in passes:
        for pl in run:
            draw_effect(c, baked[pl.name], 5, pl.x + dx, pl.y + dy, col, true, k_of)
    return c


def draw_effect(c, bk, scale, x, y, col, true, k_of):
    """draw_baked with the coverage replaced by k_of(distance in pixels),
    the distance the fourth channel's when true is set, the median's when
    it isn't"""
    x0 = math.floor(x + bk.left * scale)
    y0 = math.floor(y + bk.top * scale)
    x1 = math.ceil(x + (bk.left + bk.width) * scale)
    y1 = math.ceil(y + (bk.top + bk.height) * scale)
    for py in range(max(0, y0), min(c.height, y1)):
        for px in range(max(0, x0), min(c.width, x1)):
            u = (px + 0.5 - x) / scale - bk.left
            v = (py + 0.5 - y) / scale - bk.top
            if true:
                d = sample_field(bk.channels[3], u, v) * scale
            else:
                d = median3(*[sample_field(f, u, v) for f in bk.channels[:3]]) * scale
            k = k_of(d)
            if k > 0:
                write_pixel(c, px, py, mix(pixel_at(c, px, py), col, k, True))


RENDERS = {
    "primitive-fields": primitive_fields,
    "error-map": error_map,
    "fields-vs-paths": fields_vs_paths,
    "fillets": fillets,
    "transform-demo": transform_demo,
    "atlas-corners": atlas_corners,
    "trap-shrink": trap_shrink,
    "plate-23": plate_23,
    "title": title,
}
