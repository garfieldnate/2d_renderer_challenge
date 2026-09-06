"""
Chapter 4, Points, Vectors, Transforms: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.
"""

import math

from renderer import EPSILON, approx, canvas, color, fill, pixel_at, write_pixel
from chapter02 import (Shape, KINDS, half_plane, inside, rasterize, paint_through,
                       magnify)

CHAPTER = 4
FORMAT = "P6"


# --------------------------------------------------------------------------
# §4.1 points and vectors
# --------------------------------------------------------------------------
class Tuple:
    """x, y and w. w = 1 is a point, w = 0 is a vector."""
    __slots__ = ("x", "y", "w")

    def __init__(self, x, y, w):
        self.x, self.y, self.w = float(x), float(y), float(w)

    def __add__(self, o):
        return Tuple(self.x + o.x, self.y + o.y, self.w + o.w)

    def __sub__(self, o):
        return Tuple(self.x - o.x, self.y - o.y, self.w - o.w)

    def __neg__(self):
        return Tuple(-self.x, -self.y, -self.w)

    def __mul__(self, s):
        return Tuple(self.x * s, self.y * s, self.w * s)

    __rmul__ = __mul__

    def __truediv__(self, s):
        return Tuple(self.x / s, self.y / s, self.w / s)

    def approx(self, o, eps=EPSILON):
        return (isinstance(o, Tuple) and approx(self.x, o.x, eps)
                and approx(self.y, o.y, eps) and approx(self.w, o.w, eps))

    def __repr__(self):
        return "tuple(%.6g, %.6g, %.6g)" % (self.x, self.y, self.w)


def point(x, y):
    return Tuple(x, y, 1)


def vector(x, y):
    return Tuple(x, y, 0)


def magnitude(v):
    return math.sqrt(v.x * v.x + v.y * v.y)


def normalize(v):
    m = magnitude(v)
    return Tuple(v.x / m, v.y / m, 0)


def dot(a, b):
    return a.x * b.x + a.y * b.y


def cross(a, b):
    """the 2D cross product is a number: positive when b is a turn toward
    +y from a, which on a y-down canvas is a clockwise turn on screen"""
    return a.x * b.y - a.y * b.x


# --------------------------------------------------------------------------
# §4.2 matrices
# --------------------------------------------------------------------------
class Matrix3:
    """3 x 3, stored row by row"""
    __slots__ = ("m",)

    def __init__(self, values):
        self.m = [float(v) for v in values]
        assert len(self.m) == 9

    def __getitem__(self, rc):
        r, c = rc
        return self.m[r * 3 + c]

    def __mul__(self, o):
        if isinstance(o, Matrix3):
            out = []
            for r in range(3):
                for c in range(3):
                    out.append(sum(self[r, k] * o[k, c] for k in range(3)))
            return Matrix3(out)
        if isinstance(o, Tuple):
            t = (o.x, o.y, o.w)
            return Tuple(*[sum(self[r, k] * t[k] for k in range(3)) for r in range(3)])
        raise TypeError(o)

    def approx(self, o, eps=EPSILON):
        return isinstance(o, Matrix3) and all(approx(a, b, eps) for a, b in zip(self.m, o.m))

    def __repr__(self):
        return "matrix3(%s)" % ", ".join("%.6g" % v for v in self.m)


def matrix3(*values):
    """nine numbers, row by row"""
    return Matrix3(values)


def identity():
    return matrix3(1, 0, 0,
                   0, 1, 0,
                   0, 0, 1)


def transpose(m):
    return matrix3(m[0, 0], m[1, 0], m[2, 0],
                   m[0, 1], m[1, 1], m[2, 1],
                   m[0, 2], m[1, 2], m[2, 2])


def determinant(m):
    """cofactor expansion along the first row"""
    return (m[0, 0] * (m[1, 1] * m[2, 2] - m[1, 2] * m[2, 1])
            - m[0, 1] * (m[1, 0] * m[2, 2] - m[1, 2] * m[2, 0])
            + m[0, 2] * (m[1, 0] * m[2, 1] - m[1, 1] * m[2, 0]))


def minor(m, r, c):
    rows = [i for i in range(3) if i != r]
    cols = [j for j in range(3) if j != c]
    return m[rows[0], cols[0]] * m[rows[1], cols[1]] - m[rows[0], cols[1]] * m[rows[1], cols[0]]


def cofactor(m, r, c):
    k = minor(m, r, c)
    return -k if (r + c) % 2 else k


def is_invertible(m):
    return determinant(m) != 0


def inverse(m):
    """the transposed matrix of cofactors, divided by the determinant"""
    d = determinant(m)
    if d == 0:
        raise ZeroDivisionError("matrix is not invertible")
    out = [0.0] * 9
    for r in range(3):
        for c in range(3):
            out[c * 3 + r] = cofactor(m, r, c) / d      # transposed on the way in
    return Matrix3(out)


# --------------------------------------------------------------------------
# §4.3 the transforms
# --------------------------------------------------------------------------
def translation(x, y):
    return matrix3(1, 0, x,
                   0, 1, y,
                   0, 0, 1)


def scaling(x, y):
    return matrix3(x, 0, 0,
                   0, y, 0,
                   0, 0, 1)


def rotation(r):
    """radians. positive turns x toward y, which on a y-down canvas is
    clockwise on the screen"""
    c, s = math.cos(r), math.sin(r)
    return matrix3(c, -s, 0,
                   s, c, 0,
                   0, 0, 1)


def shearing(xy, yx):
    """x moves in proportion to y, y moves in proportion to x"""
    return matrix3(1, xy, 0,
                   yx, 1, 0,
                   0, 0, 1)


# --------------------------------------------------------------------------
# §4.4 how big is a matrix
# --------------------------------------------------------------------------
def approx_scale(m):
    """the square root of the absolute determinant of the 2 x 2 linear part:
    the factor by which lengths grow, on average"""
    return math.sqrt(abs(m[0, 0] * m[1, 1] - m[0, 1] * m[1, 0]))


def max_stretch(m):
    """the largest singular value of the linear part: the most any length
    grows. only here so the chapter's comparison numbers come from code."""
    a, b, c, d = m[0, 0], m[0, 1], m[1, 0], m[1, 1]
    s1 = a * a + b * b + c * c + d * d
    s2 = math.sqrt(max((a * a + b * b - c * c - d * d) ** 2 + 4 * (a * c + b * d) ** 2, 0.0))
    return math.sqrt((s1 + s2) / 2)


def max_column(m):
    """the longer of the two column vectors of the linear part"""
    return max(math.hypot(m[0, 0], m[1, 0]), math.hypot(m[0, 1], m[1, 1]))


# --------------------------------------------------------------------------
# §4.5 transforming what you draw
# --------------------------------------------------------------------------
def segment(a, b, width):
    """chapter 3's thick_line with real endpoints: the rectangle of the given
    width centered on the segment from point a to point b, square ends"""
    ax, ay, bx, by = a.x, a.y, b.x, b.y
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    h = width / 2
    if length == 0:
        dx, dy, length = 1.0, 0.0, 1.0
        ax, bx = ax - h, bx + h
    dx, dy = dx / length, dy / length
    nx, ny = -dy, dx
    return Shape("quad", sides=[
        half_plane(ax, ay, dx, dy),
        half_plane(bx, by, -dx, -dy),
        half_plane(ax + nx * h, ay + ny * h, -nx, -ny),
        half_plane(ax - nx * h, ay - ny * h, nx, ny),
    ])


def transformed(shape, m):
    """the shape seen through m: a device point is inside when its image
    under the inverse is inside the original. a singular m has no inverse
    and the shape collapses to nothing."""
    inv = inverse(m) if is_invertible(m) else None
    return Shape("transformed", shape=shape, inv=inv)


def _inside_transformed(s, x, y):
    if s.inv is None:
        return False
    p = s.inv * point(x, y)
    return inside(s.shape, p.x, p.y)


KINDS["transformed"] = _inside_transformed


def union(shapes):
    """inside any of them"""
    return Shape("union", shapes=list(shapes))


KINDS["union"] = lambda s, x, y: any(inside(k, x, y) for k in s.shapes)


def transform_points(points, m):
    return [m * p for p in points]


def outline(points, m, width=1):
    """the closed polygon through the points after they go through m, each
    edge a segment of the given width in device space, as one shape"""
    pts = transform_points(points, m)
    return union(segment(pts[i], pts[(i + 1) % len(pts)], width) for i in range(len(pts)))


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
INK = color(0.92, 0.92, 0.88)
GHOST = color(0.16, 0.16, 0.17)
PAPER = color(0.02, 0.02, 0.025)
SIZE = 160
RAYS = 12
RADIUS = 36

# the two matrices of the chapter, and where the untransformed shape is drawn
TURN = rotation(math.radians(30))
MOVE = translation(104.5, 76.5)
HOME = translation(44.5, 44.5)


def fan_points():
    """chapter 3's fan as points around the origin: the center first, then
    the twelve ends, at real coordinates this time, no rounding"""
    out = [point(0, 0)]
    for k in range(RAYS):
        a = math.radians(30 * k)
        out.append(point(RADIUS * math.cos(a), RADIUS * math.sin(a)))
    return out


def fan_transformed(m):
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    pts = transform_points(fan_points(), m)
    rays = union(segment(pts[0], e, 1) for e in pts[1:])
    paint_through(c, rasterize(rays, SIZE, SIZE), INK)
    return c


def side_by_side(a, b):
    both = canvas(a.width + b.width, a.height)
    for y in range(a.height):
        for x in range(a.width):
            write_pixel(both, x, y, pixel_at(a, x, y))
        for x in range(b.width):
            write_pixel(both, x + a.width, y, pixel_at(b, x, y))
    return both


def fan_both_orders():
    """left: rotate, then translate. right: translate, then rotate. the
    fan moves, but it can't tell you whether it turned."""
    return side_by_side(fan_transformed(MOVE * TURN), fan_transformed(TURN * MOVE))


def letter_f():
    """ten corners of an F, clockwise on screen from the top left, in a
    box 40 wide and 60 tall centered on the origin"""
    return [point(-20, -30), point(20, -30), point(20, -20), point(-10, -20), point(-10, -5),
            point(12, -5), point(12, 5), point(-10, 5), point(-10, 30), point(-20, 30)]


def f_ghost():
    c = canvas(SIZE, SIZE)
    fill(c, PAPER)
    paint_through(c, rasterize(outline(letter_f(), HOME), SIZE, SIZE), GHOST)
    return c


def f_both_orders():
    """left: rotate, then translate. right: translate, then rotate. same
    two matrices, and the F knows the difference. the dim F is where it
    started."""
    ghost = f_ghost()
    a = canvas(SIZE, SIZE)
    b = canvas(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            write_pixel(a, x, y, pixel_at(ghost, x, y))
            write_pixel(b, x, y, pixel_at(ghost, x, y))
    paint_through(a, rasterize(outline(letter_f(), MOVE * TURN), SIZE, SIZE), INK)
    paint_through(b, rasterize(outline(letter_f(), TURN * MOVE), SIZE, SIZE), INK)
    return side_by_side(a, b)


def plate_04():
    return magnify(f_both_orders(), 2)


RENDERS = {
    "fan-both-orders": fan_both_orders,
    "plate-04": plate_04,
}
