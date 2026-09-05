"""
Author-side reference implementation of chapter 1.

This is NOT printed in the book and readers never see it. It exists so that
every number in features/chapter01-*.feature was produced by running code,
and so reference/chapter-01/*.ppm can be regenerated after any edit.

Keep it boring. Mirror the book's API names exactly.
"""

import math

# --------------------------------------------------------------------------
# §1.1 colors
# --------------------------------------------------------------------------
EPSILON = 0.0001


def approx(a, b, eps=EPSILON):
    return abs(a - b) <= eps


class Color:
    __slots__ = ("red", "green", "blue")

    def __init__(self, r, g, b):
        self.red, self.green, self.blue = float(r), float(g), float(b)

    def __add__(self, o):
        return Color(self.red + o.red, self.green + o.green, self.blue + o.blue)

    def __sub__(self, o):
        return Color(self.red - o.red, self.green - o.green, self.blue - o.blue)

    def __mul__(self, o):
        if isinstance(o, Color):
            return Color(self.red * o.red, self.green * o.green, self.blue * o.blue)
        return Color(self.red * o, self.green * o, self.blue * o)

    __rmul__ = __mul__

    def approx(self, o, eps=EPSILON):
        return (approx(self.red, o.red, eps) and approx(self.green, o.green, eps)
                and approx(self.blue, o.blue, eps))

    def tuple(self):
        return (self.red, self.green, self.blue)

    def __repr__(self):
        return "color(%.6g, %.6g, %.6g)" % self.tuple()


def color(r, g, b):
    return Color(r, g, b)


# --------------------------------------------------------------------------
# §1.2 canvas
# --------------------------------------------------------------------------
class Canvas:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.pixels = [color(0, 0, 0) for _ in range(width * height)]

    def in_bounds(self, x, y):
        return 0 <= x < self.width and 0 <= y < self.height


def canvas(w, h):
    return Canvas(w, h)


def write_pixel(c, x, y, col):
    if c.in_bounds(x, y):
        c.pixels[y * c.width + x] = col


def pixel_at(c, x, y):
    return c.pixels[y * c.width + x]


def fill(c, col):
    for i in range(len(c.pixels)):
        c.pixels[i] = col


# --------------------------------------------------------------------------
# §1.3 sRGB transfer functions
# --------------------------------------------------------------------------
def decode(v):
    """file value (0..1) -> light (0..1)"""
    if v <= 0.04045:
        return v / 12.92
    return ((v + 0.055) / 1.055) ** 2.4


def encode(l):
    """light (0..1) -> file value (0..1)"""
    if l <= 0.0031308:
        return l * 12.92
    return 1.055 * l ** (1 / 2.4) - 0.055


# --------------------------------------------------------------------------
# §1.4 PPM
# --------------------------------------------------------------------------
def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def to_byte(light):
    """clamp, encode, scale to 0..255, round to nearest"""
    return int(math.floor(encode(clamp(light)) * 255 + 0.5))


def canvas_to_ppm(c):
    lines = ["P3", "%d %d" % (c.width, c.height), "255"]
    for y in range(c.height):
        words = []
        for x in range(c.width):
            p = pixel_at(c, x, y)
            words += [str(to_byte(p.red)), str(to_byte(p.green)), str(to_byte(p.blue))]
        line = ""
        for w in words:
            if line and len(line) + 1 + len(w) > 70:
                lines.append(line)
                line = w
            else:
                line = w if not line else line + " " + w
        lines.append(line)
    return "\n".join(lines) + "\n"


def ppm_values(ppm):
    """the numbers after the header, as ints"""
    toks = ppm.split()
    assert toks[0] == "P3", "not a P3 file"
    return [int(t) for t in toks[4:]]


def ppm_pixel(ppm, x, y):
    """the three numbers for pixel (x, y), read back out of the text"""
    toks = ppm.split()
    w = int(toks[1])
    v = ppm_values(ppm)
    i = (y * w + x) * 3
    return (v[i], v[i + 1], v[i + 2])


def distinct_values(ppm):
    return len(set(ppm_values(ppm)))


def max_channel_difference(ppm_a, ppm_b):
    """the largest difference between corresponding numbers; 255 if the
    two files don't have the same width and height"""
    ha, hb = ppm_a.split()[:4], ppm_b.split()[:4]
    if ha != hb:
        return 255
    a, b = ppm_values(ppm_a), ppm_values(ppm_b)
    if len(a) != len(b):
        return 255
    return max(abs(x - y) for x, y in zip(a, b)) if a else 0


# --------------------------------------------------------------------------
# §1.5 mixing
# --------------------------------------------------------------------------
LINEAR_BLENDING = True


def set_linear_blending(on):
    global LINEAR_BLENDING
    LINEAR_BLENDING = bool(on)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(a, b, t):
    if LINEAR_BLENDING:
        return Color(lerp(a.red, b.red, t), lerp(a.green, b.green, t), lerp(a.blue, b.blue, t))
    # the way browsers do it: blend the file values, then pretend the result is
    # light. encode is only defined on 0..1, so clamp on the way in.
    def naive(x, y):
        return decode(lerp(encode(clamp(x)), encode(clamp(y)), t))
    return Color(naive(a.red, b.red), naive(a.green, b.green), naive(a.blue, b.blue))


# --------------------------------------------------------------------------
# the renders: every one of these is pinned by a scenario and a reference PPM
# --------------------------------------------------------------------------
def checkerboard(c, x0, y0, w, h, period):
    """within the rectangle, one pixel in every `period` is white, the rest black.
    period 2 gives the classic checkerboard; period 4 gives one white in four."""
    white, black = color(1, 1, 1), color(0, 0, 0)
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            write_pixel(c, x, y, white if (x + y) % period == 0 else black)


def solid(c, x0, y0, w, h, col):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            write_pixel(c, x, y, col)


def gray_match():
    """Figure 1.1: a checkerboard beside solid 128 and solid 188."""
    c = canvas(300, 100)
    checkerboard(c, 0, 0, 100, 100, 2)
    g = decode(128 / 255)
    solid(c, 100, 0, 100, 100, color(g, g, g))
    solid(c, 200, 0, 100, 100, color(0.5, 0.5, 0.5))
    return c


def quarter_match():
    """one white pixel in four, beside solid 0.25 light"""
    c = canvas(200, 100)
    checkerboard(c, 0, 0, 100, 100, 4)
    solid(c, 100, 0, 100, 100, color(0.25, 0.25, 0.25))
    return c


def ramp():
    """256 columns of light x/255, 32 rows tall"""
    c = canvas(256, 32)
    for x in range(256):
        g = x / 255
        solid(c, x, 0, 1, 32, color(g, g, g))
    return c


def clamp_pair():
    """(2, 0.5, 0.5) on the left, (1, 0.25, 0.25) on the right"""
    c = canvas(200, 100)
    solid(c, 0, 0, 100, 100, color(2.0, 0.5, 0.5))
    solid(c, 100, 0, 100, 100, color(1.0, 0.25, 0.25))
    return c


PLATE_RAMPS = [
    (color(0, 0, 0), color(1, 1, 1)),
    (color(0.7, 0, 0), color(0, 0.3, 0.02)),
]


def plate_01():
    """two ramps, each mixed both ways. naive on top, linear beneath."""
    c = canvas(400, 180)
    for i, (a, b) in enumerate(PLATE_RAMPS):
        top = i * 90
        for x in range(400):
            t = x / 399
            set_linear_blending(False)
            naive = mix(a, b, t)
            set_linear_blending(True)
            linear = mix(a, b, t)
            for y in range(top, top + 40):
                write_pixel(c, x, y, naive)
            for y in range(top + 45, top + 85):
                write_pixel(c, x, y, linear)
    set_linear_blending(True)
    return c


RENDERS = {
    "gray-match": gray_match,
    "quarter-match": quarter_match,
    "ramp": ramp,
    "clamp-pair": clamp_pair,
    "plate-01": plate_01,
}
