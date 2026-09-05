"""
Chapter 2, Coverage: author-side reference implementation. See renderer.py.
"""

import math

from renderer import (Color, Canvas, canvas, color, mix, pixel_at, write_pixel,
                      clamp, to_byte, set_linear_blending)

CHAPTER = 2
FORMAT = "P6"
SAMPLES = 8  # per side: 8 x 8 = 64 samples per pixel


# --------------------------------------------------------------------------
# §2.1 shapes are questions
# --------------------------------------------------------------------------
class Shape:
    def __init__(self, kind, **kw):
        self.kind = kind
        self.__dict__.update(kw)


def circle(cx, cy, r):
    return Shape("circle", cx=cx, cy=cy, r=r)


def rectangle(x0, y0, x1, y1):
    return Shape("rectangle", x0=x0, y0=y0, x1=x1, y1=y1)


def half_plane(px, py, nx, ny):
    """the points on the side of (px, py) that the normal (nx, ny) points to"""
    return Shape("half_plane", px=px, py=py, nx=nx, ny=ny)


def inside(shape, x, y):
    k = shape.kind
    if k == "circle":
        dx, dy = x - shape.cx, y - shape.cy
        return dx * dx + dy * dy <= shape.r * shape.r
    if k == "rectangle":
        return shape.x0 <= x <= shape.x1 and shape.y0 <= y <= shape.y1
    if k == "half_plane":
        return (x - shape.px) * shape.nx + (y - shape.py) * shape.ny >= 0
    if k == "quad":
        return all(inside(h, x, y) for h in shape.sides)
    raise ValueError(k)


# --------------------------------------------------------------------------
# §2.2 the coverage buffer, and the binary question
# --------------------------------------------------------------------------
class Coverage:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.values = [0.0] * (width * height)


def coverage_buffer(w, h):
    return Coverage(w, h)


def coverage_at(cov, x, y):
    """0 outside the buffer, so a small buffer can paint a big canvas"""
    if 0 <= x < cov.width and 0 <= y < cov.height:
        return cov.values[y * cov.width + x]
    return 0.0


def set_coverage(cov, x, y, v):
    if 0 <= x < cov.width and 0 <= y < cov.height:
        cov.values[y * cov.width + x] = v


def center_inside(shape, px, py):
    return 1.0 if inside(shape, px + 0.5, py + 0.5) else 0.0


def rasterize_centers(shape, w, h):
    cov = coverage_buffer(w, h)
    for y in range(h):
        for x in range(w):
            set_coverage(cov, x, y, center_inside(shape, x, y))
    return cov


# --------------------------------------------------------------------------
# §2.3 the better question
# --------------------------------------------------------------------------
def coverage(shape, px, py):
    """fraction of an 8 x 8 grid of sample points inside the shape"""
    n = 0
    for j in range(SAMPLES):
        for i in range(SAMPLES):
            if inside(shape, px + (i + 0.5) / SAMPLES, py + (j + 0.5) / SAMPLES):
                n += 1
    return n / (SAMPLES * SAMPLES)


def rasterize(shape, w, h):
    cov = coverage_buffer(w, h)
    for y in range(h):
        for x in range(w):
            set_coverage(cov, x, y, coverage(shape, x, y))
    return cov


def ink(cov):
    return sum(cov.values)


# --------------------------------------------------------------------------
# §2.4 paint through coverage
# --------------------------------------------------------------------------
def paint_through(c, cov, col):
    for y in range(c.height):
        for x in range(c.width):
            k = coverage_at(cov, x, y)
            if k > 0:
                write_pixel(c, x, y, mix(pixel_at(c, x, y), col, k, True))


# --------------------------------------------------------------------------
# §2.5 binary PPM
# --------------------------------------------------------------------------
def canvas_to_p6(c):
    out = bytearray(("P6\n%d %d\n255\n" % (c.width, c.height)).encode("ascii"))
    for p in c.pixels:
        out += bytes([to_byte(p.red), to_byte(p.green), to_byte(p.blue)])
    return bytes(out)


# --------------------------------------------------------------------------
# §2.6 magnify
# --------------------------------------------------------------------------
def magnify(c, k):
    big = canvas(c.width * k, c.height * k)
    for y in range(c.height):
        for x in range(c.width):
            p = pixel_at(c, x, y)
            for j in range(k):
                for i in range(k):
                    write_pixel(big, x * k + i, y * k + j, p)
    return big


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
INK = color(0.9, 0.55, 0.1)
PAPER = color(0.02, 0.02, 0.025)


def disc_centers():
    """a disc drawn by asking each pixel whether its center is inside, x8"""
    c = canvas(40, 40)
    from renderer import fill
    fill(c, PAPER)
    paint_through(c, rasterize_centers(circle(20, 20, 16), 40, 40), INK)
    return magnify(c, 8)


def disc_coverage():
    c = canvas(40, 40)
    from renderer import fill
    fill(c, PAPER)
    paint_through(c, rasterize(circle(20, 20, 16), 40, 40), INK)
    return magnify(c, 8)


def painted_twice():
    """left: the disc painted once. right: the same disc painted twice through
    the same coverage. the edge thickens, because coverage isn't opacity."""
    c = canvas(80, 40)
    from renderer import fill
    fill(c, PAPER)
    cov = rasterize(circle(20, 20, 16), 40, 40)
    once = coverage_buffer(80, 40)
    for y in range(40):
        for x in range(40):
            set_coverage(once, x, y, coverage_at(cov, x, y))
            set_coverage(once, x + 40, y, coverage_at(cov, x, y))
    paint_through(c, once, INK)
    twice = coverage_buffer(80, 40)
    for y in range(40):
        for x in range(40):
            set_coverage(twice, x + 40, y, coverage_at(cov, x, y))
    paint_through(c, twice, INK)
    return magnify(c, 6)


def plate_02():
    """same circle, same grid: centers on the left, coverage on the right, x6"""
    c = canvas(80, 40)
    from renderer import fill
    fill(c, PAPER)
    shape = circle(20, 20, 16)
    left = rasterize_centers(shape, 40, 40)
    right = rasterize(shape, 40, 40)
    both = coverage_buffer(80, 40)
    for y in range(40):
        for x in range(40):
            set_coverage(both, x, y, coverage_at(left, x, y))
            set_coverage(both, x + 40, y, coverage_at(right, x, y))
    paint_through(c, both, INK)
    return magnify(c, 6)


RENDERS = {
    "disc-centers": disc_centers,
    "disc-coverage": disc_coverage,
    "painted-twice": painted_twice,
    "plate-02": plate_02,
}
