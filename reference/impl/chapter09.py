"""
Chapter 9, Compositing: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Everything here is in linear light, the space the canvas has stored since
chapter 1. Browsers composite and blend in the encoded space instead, so the
book's numbers differ from theirs on purpose; chapter 1 picked that lane loudly.
"""

import math

from renderer import Color, color, canvas, fill, pixel_at, write_pixel, clamp
from chapter02 import coverage_buffer, coverage_at, set_coverage, magnify
from chapter04 import point
from chapter05 import polygon, circle_path, path, move_to, line_to, close
from chapter07 import fill_path

CHAPTER = 9
FORMAT = "P6"


# --------------------------------------------------------------------------
# §9.1 premultiplied pixels
# --------------------------------------------------------------------------
class Pixel:
    """a premultiplied pixel in linear light: r, g, b are already multiplied
    by the alpha a, so r, g, b are each in [0, a] for a colour in range."""
    __slots__ = ("r", "g", "b", "a")

    def __init__(self, r, g, b, a):
        self.r, self.g, self.b, self.a = float(r), float(g), float(b), float(a)

    def approx(self, o, eps=1e-4):
        return (abs(self.r - o.r) <= eps and abs(self.g - o.g) <= eps
                and abs(self.b - o.b) <= eps and abs(self.a - o.a) <= eps)

    def __repr__(self):
        return "pixel(%.5g, %.5g, %.5g, %.5g)" % (self.r, self.g, self.b, self.a)


def pixel(r, g, b, a):
    return Pixel(r, g, b, a)


def from_color(c, a=1.0):
    """a straight colour and an alpha, premultiplied into a pixel"""
    return Pixel(c.red * a, c.green * a, c.blue * a, a)


def opaque(c):
    return from_color(c, 1.0)


CLEAR = Pixel(0.0, 0.0, 0.0, 0.0)


def pixel_alpha(px):
    return px.a


def pixel_color(px):
    """the straight (un-premultiplied) colour: divide the channels by alpha.
    A fully transparent pixel has no colour, so it reads back black."""
    if px.a == 0:
        return color(0, 0, 0)
    return color(px.r / px.a, px.g / px.a, px.b / px.a)


def lerp_pixel(a, b, t):
    """blend two pixels by t, straight down the premultiplied channels. This
    is the whole reason for premultiplying: you can average pixels, alpha and
    all, and a half-and-half of opaque red and nothing is red at half alpha,
    not a muddied grey. Filtering and gradients lean on this."""
    return Pixel(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                 a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)


# --------------------------------------------------------------------------
# §9.2 source-over
# --------------------------------------------------------------------------
def over(src, dst):
    """src composited over dst: src + (1 - src.a) * dst, premultiplied. This
    is what paint_through has been doing all along, with an opaque dst."""
    t = 1.0 - src.a
    return Pixel(src.r + t * dst.r, src.g + t * dst.g, src.b + t * dst.b,
                 src.a + t * dst.a)


# --------------------------------------------------------------------------
# §9.3 the twelve Porter-Duff operators, as one formula
# --------------------------------------------------------------------------
def _coeffs(op, a_s, a_d):
    """(Fa, Fb): the fraction of the source and of the destination that
    survive, for each operator. Every operator is these two numbers."""
    if op == "clear":     return 0.0, 0.0
    if op == "src":       return 1.0, 0.0
    if op == "dst":       return 0.0, 1.0
    if op == "src-over":  return 1.0, 1.0 - a_s
    if op == "dst-over":  return 1.0 - a_d, 1.0
    if op == "src-in":    return a_d, 0.0
    if op == "dst-in":    return 0.0, a_s
    if op == "src-out":   return 1.0 - a_d, 0.0
    if op == "dst-out":   return 0.0, 1.0 - a_s
    if op == "src-atop":  return a_d, 1.0 - a_s
    if op == "dst-atop":  return 1.0 - a_d, a_s
    if op == "xor":       return 1.0 - a_d, 1.0 - a_s
    raise ValueError(op)


def composite(op, src, dst):
    """one of the twelve Porter-Duff operators: Fa * src + Fb * dst, applied
    to every channel including alpha, with premultiplied pixels."""
    fa, fb = _coeffs(op, src.a, dst.a)
    return Pixel(fa * src.r + fb * dst.r, fa * src.g + fb * dst.g,
                 fa * src.b + fb * dst.b, fa * src.a + fb * dst.a)


PORTER_DUFF = ["clear", "src", "dst", "src-over", "dst-over", "src-in",
               "dst-in", "src-out", "dst-out", "src-atop", "dst-atop", "xor"]


# --------------------------------------------------------------------------
# §9.4 separable blend modes
# --------------------------------------------------------------------------
def _hardlight(cb, cs):
    if cs <= 0.5:
        return cb * 2 * cs
    return _screen(cb, 2 * cs - 1)


def _screen(cb, cs):
    return cb + cs - cb * cs


def _softlight(cb, cs):
    if cs <= 0.5:
        return cb - (1 - 2 * cs) * cb * (1 - cb)
    d = ((16 * cb - 12) * cb + 4) * cb if cb <= 0.25 else math.sqrt(cb)
    return cb + (2 * cs - 1) * (d - cb)


def _dodge(cb, cs):
    if cb == 0:
        return 0.0
    if cs == 1:
        return 1.0
    return min(1.0, cb / (1 - cs))


def _burn(cb, cs):
    if cb == 1:
        return 1.0
    if cs == 0:
        return 0.0
    return 1.0 - min(1.0, (1 - cb) / cs)


SEPARABLE = {
    "normal":     lambda cb, cs: cs,
    "multiply":   lambda cb, cs: cb * cs,
    "screen":     _screen,
    "overlay":    lambda cb, cs: _hardlight(cs, cb),
    "darken":     lambda cb, cs: min(cb, cs),
    "lighten":    lambda cb, cs: max(cb, cs),
    "color-dodge": _dodge,
    "color-burn": _burn,
    "hard-light": _hardlight,
    "soft-light": _softlight,
    "difference": lambda cb, cs: abs(cb - cs),
    "exclusion":  lambda cb, cs: cb + cs - 2 * cb * cs,
}


# --------------------------------------------------------------------------
# §9.5 non-separable blend modes
# --------------------------------------------------------------------------
def _lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def _clip_color(c):
    l = _lum(c)
    n = min(c)
    x = max(c)
    out = list(c)
    if n < 0:
        out = [l + (v - l) * l / (l - n) for v in out]
    if x > 1:
        out = [l + (v - l) * (1 - l) / (x - l) for v in out]
    return out


def _set_lum(c, l):
    d = l - _lum(c)
    return _clip_color([v + d for v in c])


def _sat(c):
    return max(c) - min(c)


def _set_sat(c, s):
    out = [0.0, 0.0, 0.0]
    idx = sorted(range(3), key=lambda i: c[i])
    lo, mid, hi = idx
    if c[hi] > c[lo]:
        out[mid] = (c[mid] - c[lo]) * s / (c[hi] - c[lo])
        out[hi] = s
    else:
        out[mid] = out[hi] = 0.0
    out[lo] = 0.0
    return out


def _nonseparable(mode, cb, cs):
    if mode == "hue":
        return _set_lum(_set_sat(cs, _sat(cb)), _lum(cb))
    if mode == "saturation":
        return _set_lum(_set_sat(cb, _sat(cs)), _lum(cb))
    if mode == "color":
        return _set_lum(cs, _lum(cb))
    if mode == "luminosity":
        return _set_lum(cb, _lum(cs))
    raise ValueError(mode)


NONSEPARABLE = ["hue", "saturation", "color", "luminosity"]
BLEND_MODES = list(SEPARABLE.keys()) + NONSEPARABLE


def blend_color(mode, cb, cs):
    """the blend function B(cb, cs) on two straight colours: the separable
    modes act channel by channel, the four non-separable ones on the whole
    colour at once. Returns a colour."""
    if mode in SEPARABLE:
        f = SEPARABLE[mode]
        return color(f(cb.red, cs.red), f(cb.green, cs.green), f(cb.blue, cs.blue))
    bb = (cb.red, cb.green, cb.blue)
    ss = (cs.red, cs.green, cs.blue)
    out = _nonseparable(mode, bb, ss)
    return color(out[0], out[1], out[2])


def blend(mode, src, dst):
    """source-over, but with the overlap blended by `mode` first. Reduces to
    over() exactly when mode is "normal". Premultiplied pixels in, out."""
    a_s, a_d = src.a, dst.a
    cs = pixel_color(src)
    cb = pixel_color(dst)
    b = blend_color(mode, cb, cs)
    # premultiplied output: as*(1-ad)*Cs + as*ad*B + (1-as)*dst
    def ch(csx, bx, srcx, dstx):
        return a_s * (1 - a_d) * csx + a_s * a_d * bx + (1 - a_s) * dstx
    return Pixel(ch(cs.red, b.red, src.r, dst.r),
                 ch(cs.green, b.green, src.g, dst.g),
                 ch(cs.blue, b.blue, src.b, dst.b),
                 a_s + a_d * (1 - a_s))


# --------------------------------------------------------------------------
# §9.6 layers: buffers of premultiplied pixels
# --------------------------------------------------------------------------
class Layer:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.pixels = [Pixel(0, 0, 0, 0) for _ in range(width * height)]


def layer(w, h):
    return Layer(w, h)


def layer_pixel(l, x, y):
    if 0 <= x < l.width and 0 <= y < l.height:
        return l.pixels[y * l.width + x]
    return CLEAR


def set_layer_pixel(l, x, y, px):
    if 0 <= x < l.width and 0 <= y < l.height:
        l.pixels[y * l.width + x] = px


def paint_shape(l, cov, col):
    """paint a solid colour through a coverage buffer into a fresh layer:
    each pixel becomes that colour at alpha = its coverage, premultiplied"""
    for y in range(l.height):
        for x in range(l.width):
            k = coverage_at(cov, x, y)
            if k > 0:
                set_layer_pixel(l, x, y, from_color(col, k))


def composite_layers(op, src, dst):
    """composite two layers pixel by pixel with a Porter-Duff operator"""
    out = layer(dst.width, dst.height)
    for i in range(dst.width * dst.height):
        out.pixels[i] = composite(op, src.pixels[i], dst.pixels[i])
    return out


def flatten_layer(l, bg):
    """composite a layer over an opaque background colour, giving an opaque
    canvas: exactly the canvas the earlier chapters drew on."""
    c = canvas(l.width, l.height)
    base = opaque(bg)
    for y in range(l.height):
        for x in range(l.width):
            px = over(layer_pixel(l, x, y), base)
            write_pixel(c, x, y, color(px.r, px.g, px.b))
    return c


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
DST_COLOR = color(0.2, 0.5, 0.85)     # the square: blue
SRC_COLOR = color(0.95, 0.55, 0.1)    # the circle: orange
TILE = 64


def _dst_layer():
    l = layer(TILE, TILE)
    sq = polygon(point(10, 10), point(42, 10), point(42, 42), point(10, 42))
    paint_shape(l, fill_path(sq, "nonzero", TILE, TILE), DST_COLOR)
    return l


def _src_layer():
    l = layer(TILE, TILE)
    circ = circle_path(38, 38, 20, 48)
    paint_shape(l, fill_path(circ, "nonzero", TILE, TILE), SRC_COLOR)
    return l


def porter_duff_table():
    """the twelve operators in a 4-by-3 grid: square is destination, circle
    is source, each tile flattened over paper"""
    cols, rows = 4, 3
    c = canvas(cols * TILE, rows * TILE)
    fill(c, PAPER)
    src, dst = _src_layer(), _dst_layer()
    for i, op in enumerate(PORTER_DUFF):
        tile = flatten_layer(composite_layers(op, src, dst), PAPER)
        ox, oy = (i % cols) * TILE, (i // cols) * TILE
        for y in range(TILE):
            for x in range(TILE):
                write_pixel(c, ox + x, oy + y, pixel_at(tile, x, y))
    return c


def plate_09():
    return magnify(porter_duff_table(), 2)


def blend_strip():
    """the sixteen blend modes: an orange source disc over a blue backdrop
    square, one tile each, four across and four down, opaque both"""
    modes = BLEND_MODES
    cols, rows = 4, 4
    c = canvas(cols * TILE, rows * TILE)
    fill(c, PAPER)
    src, dst = _src_layer(), _dst_layer()
    for i, mode in enumerate(modes):
        out = layer(TILE, TILE)
        for j in range(TILE * TILE):
            out.pixels[j] = blend(mode, src.pixels[j], dst.pixels[j])
        tile = flatten_layer(out, PAPER)
        ox, oy = (i % cols) * TILE, (i // cols) * TILE
        for y in range(TILE):
            for x in range(TILE):
                write_pixel(c, ox + x, oy + y, pixel_at(tile, x, y))
    return c


def seam():
    """the conflation trap: two opaque triangles that share the diagonal,
    each antialiased and composited src-over onto paper. Along the shared
    edge each covers about half the pixel, and src-over of two half-covered
    opaque pixels is 0.75, not 1.0, so a quarter of the paper shows through
    as a seam down a shape that should have been solid."""
    c = canvas(80, 80)
    ink = color(0.95, 0.55, 0.1)
    left = polygon(point(4, 4), point(76, 76), point(4, 76))
    right = polygon(point(4, 4), point(76, 4), point(76, 76))
    base = layer(80, 80)
    for i in range(80 * 80):
        base.pixels[i] = opaque(PAPER)
    for tri in (left, right):
        src = layer(80, 80)
        paint_shape(src, fill_path(tri, "nonzero", 80, 80), ink)   # opaque, alpha = coverage
        base = composite_layers("src-over", src, base)
    for y in range(80):
        for x in range(80):
            px = base.pixels[y * 80 + x]
            write_pixel(c, x, y, color(px.r, px.g, px.b))
    return magnify(c, 4)


RENDERS = {
    "porter-duff": porter_duff_table,
    "plate-09": plate_09,
    "blend-modes": blend_strip,
    "seam": seam,
}
