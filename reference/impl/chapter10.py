"""
Chapter 10, Paint Servers and Gradients: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Stop colours are interpolated in linear light, the canvas space, as everything
else in the book has been. Browsers interpolate gradients in the encoded space
(or premultiplied), so the book's ramp is subtly different on purpose.
"""

import math

from renderer import color, canvas, fill, pixel_at, write_pixel, clamp, encode, mix
from chapter02 import coverage_buffer, coverage_at, magnify, canvas_to_p6
from chapter04 import point
from chapter05 import polygon, circle_path
from chapter07 import fill_path

CHAPTER = 10
FORMAT = "P6"


# --------------------------------------------------------------------------
# §10.1 paint is a function of position
# --------------------------------------------------------------------------
class Paint:
    """a function from a device point to a colour. Solid ignores the point;
    the gradients turn the point into a scalar and look it up in a stop table."""
    __slots__ = ("kind", "data")

    def __init__(self, kind, **data):
        self.kind = kind
        self.data = data


def solid(c):
    return Paint("solid", color=c)


def paint_at(p, x, y):
    """the colour this paint puts at device point (x, y)"""
    if p.kind == "solid":
        return p.data["color"]
    if p.kind == "linear":
        return sample_stops(p.data["stops"], extend(linear_t(p, x, y), p.data["extend"]))
    if p.kind == "radial":
        t = radial_t(p, x, y)
        if t is None:
            return sample_stops(p.data["stops"], 1.0)
        return sample_stops(p.data["stops"], extend(t, p.data["extend"]))
    if p.kind == "conic":
        return sample_stops(p.data["stops"], extend(conic_t(p, x, y), p.data["extend"]))
    raise ValueError(p.kind)


# --------------------------------------------------------------------------
# §10.2 the stop table
# --------------------------------------------------------------------------
def stop(offset, c):
    return (float(offset), c)


def sample_stops(stops, t):
    """the colour at parameter t in [0, 1], interpolated in linear light.
    Below the first stop is the first colour, above the last is the last;
    between two stops it is a straight blend. A binary search finds the pair."""
    if t <= stops[0][0]:
        return stops[0][1]
    if t >= stops[-1][0]:
        return stops[-1][1]
    lo, hi = 0, len(stops) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if stops[mid][0] <= t:
            lo = mid
        else:
            hi = mid
    o0, c0 = stops[lo]
    o1, c1 = stops[hi]
    f = (t - o0) / (o1 - o0)
    return mix(c0, c1, f, linear=True)


# --------------------------------------------------------------------------
# §10.3 extend modes
# --------------------------------------------------------------------------
def extend(t, mode):
    """fold a parameter outside [0, 1] back in. pad clamps, repeat wraps,
    reflect bounces."""
    if mode == "pad":
        return 0.0 if t < 0 else 1.0 if t > 1 else t
    if mode == "repeat":
        return t - math.floor(t)
    if mode == "reflect":
        u = abs(t) % 2.0
        return u if u <= 1.0 else 2.0 - u
    raise ValueError(mode)


# --------------------------------------------------------------------------
# §10.4 the three gradients
# --------------------------------------------------------------------------
def linear_gradient(p0, p1, stops, extend="pad"):
    return Paint("linear", p0=p0, p1=p1, stops=stops, extend=extend)


def linear_t(p, x, y):
    """the parameter of (x, y): its distance along the axis from p0 to p1,
    as a fraction of the axis length. On the axis, t is the parameter itself."""
    p0, p1 = p.data["p0"], p.data["p1"]
    dx, dy = p1.x - p0.x, p1.y - p0.y
    denom = dx * dx + dy * dy
    return ((x - p0.x) * dx + (y - p0.y) * dy) / denom


def radial_gradient(c0, r0, c1, r1, stops, extend="pad"):
    """the two-circle form: a start circle (c0, r0) at t = 0 and an end circle
    (c1, r1) at t = 1. SVG's focal gradient is the special case r0 = 0."""
    return Paint("radial", c0=c0, r0=r0, c1=c1, r1=r1, stops=stops, extend=extend)


def radial_t(p, x, y):
    """the largest t for which (x, y) lies on the circle interpolated between
    the two, solved from a quadratic. None when the point is in no circle,
    the cone of undefined region a focal gradient can have."""
    c0, c1 = p.data["c0"], p.data["c1"]
    r0, r1 = p.data["r0"], p.data["r1"]
    cdx, cdy = c1.x - c0.x, c1.y - c0.y
    dr = r1 - r0
    pdx, pdy = x - c0.x, y - c0.y
    a = cdx * cdx + cdy * cdy - dr * dr
    b = -2.0 * (pdx * cdx + pdy * cdy + r0 * dr)
    c = pdx * pdx + pdy * pdy - r0 * r0
    if abs(a) < 1e-9:
        if abs(b) < 1e-12:
            return None
        t = -c / b
        return t if r0 + t * dr >= 0 else None
    disc = b * b - 4 * a * c
    if disc < 0:
        return None
    s = math.sqrt(disc)
    # the largest t whose interpolated radius is not negative, per the spec.
    # picking a root by sign of the discriminant is a trap: which root is
    # larger depends on the sign of a, and the radius filter hides the mistake
    # whenever only one root is valid.
    best = None
    for t in ((-b + s) / (2 * a), (-b - s) / (2 * a)):
        if r0 + t * dr >= 0 and (best is None or t > best):
            best = t
    return best


def conic_gradient(center, angle0, stops, extend="pad"):
    """an angular sweep around a center, t going 0..1 once around from
    angle0. angle0 is in radians, measured the way the canvas turns."""
    return Paint("conic", center=center, angle0=angle0, stops=stops, extend=extend)


def conic_t(p, x, y):
    center, angle0 = p.data["center"], p.data["angle0"]
    a = math.atan2(y - center.y, x - center.x) - angle0
    t = a / (2 * math.pi)
    return t - math.floor(t)


# --------------------------------------------------------------------------
# §10.5 painting with a paint
# --------------------------------------------------------------------------
def paint_fill(c, cov, paint):
    """fill a coverage buffer with a paint: sample the paint at each covered
    pixel's center and blend it in through the coverage, in linear light. A
    solid paint makes this exactly chapter 2's paint_through."""
    for y in range(c.height):
        for x in range(c.width):
            k = coverage_at(cov, x, y)
            if k > 0:
                col = paint_at(paint, x + 0.5, y + 0.5)
                write_pixel(c, x, y, mix(pixel_at(c, x, y), col, k, linear=True))


# --------------------------------------------------------------------------
# §10.6 ordered dithering
# --------------------------------------------------------------------------
BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def dither_threshold(x, y):
    """the ordered-dither offset for a pixel, in [0, 1): the 4x4 Bayer value
    over 16"""
    return BAYER4[y % 4][x % 4] / 16.0


def to_byte_dithered(light, x, y):
    """encode to a byte, but nudge by the pixel's Bayer offset before rounding
    down, so a slow ramp crosses byte boundaries in a fine pattern instead of
    a hard band"""
    v = encode(clamp(light)) * 255 + dither_threshold(x, y)
    return int(math.floor(v))


def canvas_to_p6_dithered(c):
    out = bytearray(("P6\n%d %d\n255\n" % (c.width, c.height)).encode("ascii"))
    for y in range(c.height):
        for x in range(c.width):
            px = pixel_at(c, x, y)
            out += bytes([to_byte_dithered(px.red, x, y),
                          to_byte_dithered(px.green, x, y),
                          to_byte_dithered(px.blue, x, y)])
    return bytes(out)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
SUNSET = [
    stop(0.0, color(0.05, 0.02, 0.15)),
    stop(0.35, color(0.75, 0.15, 0.25)),
    stop(0.7, color(0.98, 0.6, 0.15)),
    stop(1.0, color(1.0, 0.95, 0.75)),
]
PANEL = 150


def _panel(paint):
    c = canvas(PANEL, PANEL)
    box = polygon(point(0, 0), point(PANEL, 0), point(PANEL, PANEL), point(0, PANEL))
    paint_fill(c, fill_path(box, "nonzero", PANEL, PANEL), paint)
    return c


def three_gradients():
    """linear, radial with an offset focus, and conic, the same stops each"""
    lin = linear_gradient(point(10, 10), point(140, 140), SUNSET, "pad")
    rad = radial_gradient(point(55, 55), 0, point(75, 75), 85, SUNSET, "pad")
    con = conic_gradient(point(75, 75), -math.pi / 2, SUNSET, "pad")
    panels = [_panel(lin), _panel(rad), _panel(con)]
    c = canvas(PANEL * 3 + 8, PANEL)
    fill(c, PAPER)
    for i, panel in enumerate(panels):
        ox = i * (PANEL + 4)
        for y in range(PANEL):
            for x in range(PANEL):
                write_pixel(c, ox + x, y, pixel_at(panel, x, y))
    return c


def plate_10():
    return three_gradients()


def extend_strip():
    """one two-stop gradient shown under the three extend modes, its axis only
    a third of the way across so the modes have room to act"""
    stops = [stop(0.0, color(0.1, 0.15, 0.5)), stop(1.0, color(1.0, 0.7, 0.1))]
    c = canvas(180, 90)
    for i, mode in enumerate(("pad", "repeat", "reflect")):
        g = linear_gradient(point(60, 0), point(100, 0), stops, mode)
        box = polygon(point(0, i * 30), point(180, i * 30), point(180, i * 30 + 30), point(0, i * 30 + 30))
        paint_fill(c, fill_path(box, "nonzero", 180, 90), g)
    return magnify(c, 2)



RENDERS = {
    "three-gradients": three_gradients,
    "plate-10": plate_10,
    "extend-modes": extend_strip,
}
