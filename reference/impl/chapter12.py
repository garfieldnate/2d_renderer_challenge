"""
Chapter 12, Clipping, Masks and Groups: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

The whole chapter is the dividend of coverage being a first-class value since
chapter 2: a clip is a coverage buffer, clipping is multiplying two of them, and
a group is an offscreen layer composited back with one opacity.
"""

import math

from renderer import color, canvas, fill, pixel_at, write_pixel
from chapter02 import (coverage_buffer, coverage_at, set_coverage, ink, magnify,
                       canvas_to_p6)
from chapter04 import point
from chapter05 import polygon, circle_path
from chapter07 import fill_path
from chapter09 import (Pixel, from_color, opaque, over, composite, layer, layer_pixel,
                       set_layer_pixel, paint_shape, composite_layers, flatten_layer, CLEAR)

CHAPTER = 12
FORMAT = "P6"


# --------------------------------------------------------------------------
# §12.1 a clip is a coverage buffer
# --------------------------------------------------------------------------
def multiply_coverage(a, b):
    """a new coverage buffer, each cell the product of the two. Clipping one
    coverage by another is this and nothing more; it commutes and it nests."""
    out = coverage_buffer(a.width, a.height)
    for i in range(a.width * a.height):
        out.values[i] = a.values[i] * b.values[i]
    return out


def full_clip(w, h):
    """the clip that clips nothing: coverage 1 everywhere. Multiplying by it
    changes nothing, so a clip to the whole canvas is a no-op."""
    cov = coverage_buffer(w, h)
    for i in range(w * h):
        cov.values[i] = 1.0
    return cov


def clip_rect(x0, y0, x1, y1, w, h):
    """a rectangular clip as a coverage buffer, antialiased at its edges the
    same way any fill is"""
    r = polygon(point(x0, y0), point(x1, y0), point(x1, y1), point(x0, y1))
    return fill_path(r, "nonzero", w, h)


def clip_path(p, rule, w, h):
    """an arbitrary clip: the coverage of a filled path. A clip was never
    anything but a shape's coverage."""
    return fill_path(p, rule, w, h)


# --------------------------------------------------------------------------
# §12.2 soft masks
# --------------------------------------------------------------------------
def soft_mask(cx, cy, r, w, h):
    """a soft clip: coverage 1 at the center fading smoothly to 0 at radius r,
    a radial falloff. Multiplied in exactly like a hard clip; the only
    difference is that its values are between 0 and 1."""
    cov = coverage_buffer(w, h)
    for y in range(h):
        for x in range(w):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
            v = 1.0 - d
            set_coverage(cov, x, y, v if v > 0 else 0.0)
    return cov


# --------------------------------------------------------------------------
# §12.3 groups
# --------------------------------------------------------------------------
def push_group(w, h):
    """start an offscreen group: a fresh transparent layer to draw into"""
    return layer(w, h)


def scale_opacity(l, opacity):
    """a copy of the layer with every premultiplied channel scaled by opacity,
    which lowers the whole group's alpha at once"""
    out = layer(l.width, l.height)
    for i in range(l.width * l.height):
        p = l.pixels[i]
        out.pixels[i] = Pixel(p.r * opacity, p.g * opacity, p.b * opacity, p.a * opacity)
    return out


def pop_group_with_opacity(group, base, opacity):
    """composite a finished group onto the base layer at one opacity: scale
    the whole group's alpha, then source-over. This is what makes group
    opacity differ from per-child opacity, because the group is flattened
    before the opacity is applied, so overlaps inside it are already resolved."""
    return composite_layers("src-over", scale_opacity(group, opacity), base)


def paint_into(l, cov, col, alpha=1.0):
    """draw a solid colour through a coverage buffer into a layer, source-over,
    at a given alpha. The chapter's small brush for the plate."""
    src = layer(l.width, l.height)
    for y in range(l.height):
        for x in range(l.width):
            k = coverage_at(cov, x, y) * alpha
            if k > 0:
                set_layer_pixel(src, x, y, from_color(col, k))
    return composite_layers("src-over", src, l)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
INKS = [color(0.95, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)]
SIZE = 150


def _three_circles():
    """three overlapping circles, as (path, colour) pairs, in a SIZE box"""
    centers = [(60, 62), (90, 62), (75, 92)]
    return [(circle_path(cx, cy, 34, 64), INKS[i]) for i, (cx, cy) in enumerate(centers)]


def per_child():
    """each circle painted onto the canvas at half opacity in turn: the
    overlaps composite twice and darken"""
    base = layer(SIZE, SIZE)
    for i in range(SIZE * SIZE):
        base.pixels[i] = opaque(PAPER)
    for path, col in _three_circles():
        base = paint_into(base, fill_path(path, "nonzero", SIZE, SIZE), col, 0.5)
    return base


def group_opacity():
    """the three circles drawn opaque into a group, then the whole group
    composited at half opacity: the overlaps match the rest"""
    base = layer(SIZE, SIZE)
    for i in range(SIZE * SIZE):
        base.pixels[i] = opaque(PAPER)
    group = push_group(SIZE, SIZE)
    for path, col in _three_circles():
        group = paint_into(group, fill_path(path, "nonzero", SIZE, SIZE), col, 1.0)
    return pop_group_with_opacity(group, base, 0.5)


def _layer_to_canvas(l):
    c = canvas(l.width, l.height)
    for y in range(l.height):
        for x in range(l.width):
            p = layer_pixel(l, x, y)
            write_pixel(c, x, y, color(p.r, p.g, p.b))
    return c


def opacity_plate():
    """per-child on the left, group on the right"""
    from chapter04 import side_by_side
    return side_by_side(_layer_to_canvas(per_child()), _layer_to_canvas(group_opacity()))


def plate_12():
    return magnify(opacity_plate(), 2)


def clip_demo():
    """a filled star clipped to a circle, beside the same star clipped by a
    soft radial mask"""
    star_pts = []
    for k in range(5):
        a = math.radians(-90 + 144 * k)
        star_pts.append(point(75 + 60 * math.cos(a), 75 + 60 * math.sin(a)))
    star = polygon(*star_pts)
    star_cov = fill_path(star, "nonzero", SIZE, SIZE)

    hard = multiply_coverage(star_cov, clip_path(circle_path(75, 75, 45, 64), "nonzero", SIZE, SIZE))
    soft = multiply_coverage(star_cov, soft_mask(75, 75, 70, SIZE, SIZE))

    def render(cov):
        c = canvas(SIZE, SIZE)
        fill(c, PAPER)
        from chapter02 import paint_through
        paint_through(c, cov, INKS[0])
        return c

    from chapter04 import side_by_side
    return side_by_side(render(hard), render(soft))


RENDERS = {
    "opacity": opacity_plate,
    "plate-12": plate_12,
    "clip-demo": clip_demo,
}
