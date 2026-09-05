"""
Chapter 3, Lines: author-side reference implementation. See renderer.py.
"""

import math

from renderer import canvas, color, fill, mix, pixel_at, write_pixel
from chapter02 import (Shape, half_plane, rasterize, paint_through, ink,
                       coverage_buffer, set_coverage, coverage_at, magnify)

CHAPTER = 3
FORMAT = "P6"


# --------------------------------------------------------------------------
# §3.1 Bresenham
# --------------------------------------------------------------------------
def line_bresenham(c, x0, y0, x1, y1, col):
    """the classic: integer arithmetic only, one pixel per step along the
    longer axis, endpoints included. exactly the pseudo-code in the chapter."""
    steep = abs(y1 - y0) > abs(x1 - x0)
    if steep:
        x0, y0, x1, y1 = y0, x0, y1, x1
    if x0 > x1:
        x0, y0, x1, y1 = x1, y1, x0, y0
    dx = x1 - x0
    dy = abs(y1 - y0)
    ystep = 1 if y0 < y1 else -1
    err = dx // 2
    y = y0
    for x in range(x0, x1 + 1):
        if steep:
            write_pixel(c, y, x, col)
        else:
            write_pixel(c, x, y, col)
        err -= dy
        if err < 0:
            y += ystep
            err += dx


def lit_pixels(c):
    """every pixel that isn't black, in reading order"""
    black = color(0, 0, 0)
    out = []
    for y in range(c.height):
        for x in range(c.width):
            if not pixel_at(c, x, y).approx(black):
                out.append((x, y))
    return out


# --------------------------------------------------------------------------
# §3.2 Wu
# --------------------------------------------------------------------------
def plot(c, x, y, col, weight):
    if 0 <= x < c.width and 0 <= y < c.height and weight > 0:
        write_pixel(c, x, y, mix(pixel_at(c, x, y), col, weight))


def line_wu(c, x0, y0, x1, y1, col):
    """two pixels per step along the longer axis, weighted by how far the
    ideal line sits between them. integer endpoints only, for now."""
    steep = abs(y1 - y0) > abs(x1 - x0)
    if steep:
        x0, y0, x1, y1 = y0, x0, y1, x1
    if x0 > x1:
        x0, y0, x1, y1 = x1, y1, x0, y0
    dx = x1 - x0
    slope = (y1 - y0) / dx if dx else 0.0
    for x in range(x0, x1 + 1):
        y = y0 + (x - x0) * slope
        yi = math.floor(y)
        f = y - yi
        if steep:
            plot(c, yi, x, col, 1 - f)
            plot(c, yi + 1, x, col, f)
        else:
            plot(c, x, yi, col, 1 - f)
            plot(c, x, yi + 1, col, f)


def total_ink(c):
    """sum over every pixel of the pixel's red channel: with a white line on
    black, that's how much paint went down"""
    return sum(p.red for p in c.pixels)


# --------------------------------------------------------------------------
# §3.3 the reveal: a line is a thin rectangle
# --------------------------------------------------------------------------
def thick_line(x0, y0, x1, y1, width):
    """the rectangle of the given width centered on the segment from the
    center of pixel (x0, y0) to the center of pixel (x1, y1), square ends"""
    ax, ay, bx, by = x0 + 0.5, y0 + 0.5, x1 + 0.5, y1 + 0.5
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    if length == 0:
        dx, dy, length = 1.0, 0.0, 1.0   # a zero-length line is a width-by-width square
    dx, dy = dx / length, dy / length
    nx, ny = -dy, dx
    h = width / 2
    sides = [
        half_plane(ax, ay, dx, dy),
        half_plane(bx, by, -dx, -dy),
        half_plane(ax + nx * h, ay + ny * h, -nx, -ny),
        half_plane(ax - nx * h, ay - ny * h, nx, ny),
    ]
    return Shape("quad", sides=sides)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
INK = color(0.92, 0.92, 0.88)
PAPER = color(0.02, 0.02, 0.025)
RAYS = 12
SIZE = 160
CENTER = 80
RADIUS = 72


def ray_ends():
    """the twelve integer endpoints of the fan, every 30 degrees"""
    out = []
    for k in range(RAYS):
        a = math.radians(30 * k)
        out.append((round(CENTER + RADIUS * math.cos(a)), round(CENTER + RADIUS * math.sin(a))))
    return out


def fan_bresenham():
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    for (x, y) in ray_ends():
        line_bresenham(c, CENTER, CENTER, x, y, INK)
    return c


def fan_wu():
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    for (x, y) in ray_ends():
        line_wu(c, CENTER, CENTER, x, y, INK)
    return c


def fan_coverage():
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    for (x, y) in ray_ends():
        paint_through(c, rasterize(thick_line(CENTER, CENTER, x, y, 1), SIZE, SIZE), INK)
    return magnify(c, 2)


def plate_03():
    """bresenham's fan on the left, wu's on the right, x2"""
    both = canvas(SIZE * 2, SIZE)
    a, b = fan_bresenham(), fan_wu()
    for y in range(SIZE):
        for x in range(SIZE):
            write_pixel(both, x, y, pixel_at(a, x, y))
            write_pixel(both, x + SIZE, y, pixel_at(b, x, y))
    return magnify(both, 2)


RENDERS = {
    "fan-bresenham": fan_bresenham,
    "fan-wu": fan_wu,
    "fan-coverage": fan_coverage,
    "plate-03": plate_03,
}
