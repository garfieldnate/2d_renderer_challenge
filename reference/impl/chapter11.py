"""
Chapter 11, Images and Resampling: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

An image stores premultiplied linear-light pixels, the chapter 9 representation,
because filtering with anything else muddies transparent edges. A PPM read back
in is decoded from sRGB to linear on the way, and the sampled colour is the paint.
"""

import math

from renderer import color, canvas, fill, pixel_at, write_pixel, decode, parse_ppm
from chapter02 import canvas_to_p6, magnify
from chapter04 import point, inverse, approx_scale
from chapter09 import Pixel, from_color, opaque, pixel_color, lerp_pixel
from chapter10 import Paint, PAINT_KINDS, paint_fill, solid
from chapter05 import polygon
from chapter07 import fill_path

CHAPTER = 11
FORMAT = "P6"


# --------------------------------------------------------------------------
# §11.1 an image is a grid of pixels
# --------------------------------------------------------------------------
class Image:
    __slots__ = ("width", "height", "pixels")

    def __init__(self, width, height, pixels):
        self.width, self.height = width, height
        self.pixels = pixels


def image(width, height, pixels):
    return Image(width, height, list(pixels))


def read_image(data):
    """a PPM (P3 or P6) read back into an image: each byte is decoded from
    sRGB to linear light and the pixel is opaque (alpha 1), premultiplied."""
    w, h, vals = parse_ppm(data)
    pixels = []
    for i in range(w * h):
        r, g, b = vals[3 * i] / 255, vals[3 * i + 1] / 255, vals[3 * i + 2] / 255
        pixels.append(opaque(color(decode(r), decode(g), decode(b))))
    return Image(w, h, pixels)


def _wrap(i, n, extend):
    """fold a texel index back into 0..n-1 by the extend mode"""
    if 0 <= i < n:
        return i
    if extend == "clamp":
        return 0 if i < 0 else n - 1
    if extend == "repeat":
        return i % n
    if extend == "reflect":
        p = 2 * n
        i = i % p
        if i < 0:
            i += p
        return i if i < n else p - 1 - i
    raise ValueError(extend)


def image_texel(img, ix, iy, extend="clamp"):
    """the pixel at integer texel (ix, iy), the index folded by the extend mode"""
    ix = _wrap(ix, img.width, extend)
    iy = _wrap(iy, img.height, extend)
    return img.pixels[iy * img.width + ix]


# --------------------------------------------------------------------------
# §11.2 sampling: the half-pixel offset
# --------------------------------------------------------------------------
# A texel's center is at (tx + 0.5, ty + 0.5), not (tx, ty). Sampling code
# works in "texel-center space", which is the source coordinate minus 0.5.
def sample_nearest(img, sx, sy, extend="clamp"):
    return image_texel(img, math.floor(sx), math.floor(sy), extend)


def sample_bilinear(img, sx, sy, extend="clamp"):
    gx, gy = sx - 0.5, sy - 0.5
    x0, y0 = math.floor(gx), math.floor(gy)
    fx, fy = gx - x0, gy - y0
    p00 = image_texel(img, x0, y0, extend)
    p10 = image_texel(img, x0 + 1, y0, extend)
    p01 = image_texel(img, x0, y0 + 1, extend)
    p11 = image_texel(img, x0 + 1, y0 + 1, extend)
    top = lerp_pixel(p00, p10, fx)
    bot = lerp_pixel(p01, p11, fx)
    return lerp_pixel(top, bot, fy)


def catmull(t):
    """the four Catmull-Rom weights for a fractional position t in [0, 1),
    for texels at offsets -1, 0, 1, 2"""
    t2, t3 = t * t, t * t * t
    return (
        -0.5 * t3 + t2 - 0.5 * t,
        1.5 * t3 - 2.5 * t2 + 1.0,
        -1.5 * t3 + 2.0 * t2 + 0.5 * t,
        0.5 * t3 - 0.5 * t2,
    )


def sample_bicubic(img, sx, sy, extend="clamp"):
    gx, gy = sx - 0.5, sy - 0.5
    x0, y0 = math.floor(gx), math.floor(gy)
    wx = catmull(gx - x0)
    wy = catmull(gy - y0)
    r = g = b = a = 0.0
    for j in range(4):
        for i in range(4):
            px = image_texel(img, x0 - 1 + i, y0 - 1 + j, extend)
            w = wx[i] * wy[j]
            r += w * px.r
            g += w * px.g
            b += w * px.b
            a += w * px.a
    return Pixel(r, g, b, a)


SAMPLERS = {"nearest": sample_nearest, "bilinear": sample_bilinear, "bicubic": sample_bicubic}


# --------------------------------------------------------------------------
# §11.3 the image as a paint
# --------------------------------------------------------------------------
def image_paint(img, m, filter="bilinear", extend="clamp"):
    """a paint that samples an image, placed on the canvas by matrix m. m maps
    image space to device space, so a device point is taken back through the
    inverse to find where in the image to look."""
    return Paint("image", image=img, inverse=inverse(m), filter=filter, extend=extend)


def _sample_image_paint(p, x, y):
    src = p.data["inverse"] * point(x, y)
    px = SAMPLERS[p.data["filter"]](p.data["image"], src.x, src.y, p.data["extend"])
    return pixel_color(px)


PAINT_KINDS["image"] = _sample_image_paint


# --------------------------------------------------------------------------
# §11.4 minification and mip pyramids
# --------------------------------------------------------------------------
def downsample(img):
    """halve an image by averaging each 2x2 block in premultiplied light.
    Odd sizes drop the last row or column."""
    w, h = img.width // 2, img.height // 2
    out = []
    for y in range(h):
        for x in range(w):
            acc = [0.0, 0.0, 0.0, 0.0]
            for dy in range(2):
                for dx in range(2):
                    px = img.pixels[(2 * y + dy) * img.width + (2 * x + dx)]
                    acc[0] += px.r; acc[1] += px.g; acc[2] += px.b; acc[3] += px.a
            out.append(Pixel(acc[0] / 4, acc[1] / 4, acc[2] / 4, acc[3] / 4))
    return Image(w, h, out)


def mip_chain(img):
    """the image and every halving of it down to 1x1"""
    levels = [img]
    while levels[-1].width > 1 and levels[-1].height > 1:
        levels.append(downsample(levels[-1]))
    return levels


def mip_level_for(scale):
    """the mip level a minification by `scale` (device length per image length)
    wants: 0 at 1:1 or larger, one level up per halving. scale < 1 is
    minification."""
    if scale >= 1:
        return 0
    return max(0, int(math.floor(-math.log2(scale))))


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)


def sprite():
    """a small, deliberately asymmetric 8x8 image, so a flip or transpose
    shows. Built as a canvas, written to a PPM and read back, to exercise the
    round trip."""
    c = canvas(8, 8)
    O = color(0.95, 0.55, 0.1)
    B = color(0.15, 0.45, 0.85)
    W = color(0.95, 0.93, 0.85)
    K = color(0.06, 0.06, 0.08)
    grid = [
        K, K, B, B, B, B, K, K,
        K, B, B, B, B, B, B, K,
        B, B, W, B, B, W, B, B,
        B, B, W, B, B, W, B, B,
        B, B, B, B, B, B, B, B,
        O, B, B, O, O, B, B, O,
        K, O, O, B, B, O, O, K,
        K, K, O, O, O, O, K, K,
    ]
    for i, col in enumerate(grid):
        write_pixel(c, i % 8, i // 8, col)
    return read_image(canvas_to_p6(c))


def _magnified(img, filter, k):
    """the image painted k times bigger by one filter, as a canvas"""
    from chapter04 import scaling
    w, h = img.width * k, img.height * k
    c = canvas(w, h)
    fill(c, PAPER)
    box = polygon(point(0, 0), point(w, 0), point(w, h), point(0, h))
    paint_fill(c, fill_path(box, "nonzero", w, h), image_paint(img, scaling(k, k), filter, "clamp"))
    return c


def two_filters():
    """the 8x8 sprite magnified 20x, nearest on the left and bilinear on the
    right, the plate's comparison"""
    from chapter04 import side_by_side
    s = sprite()
    return side_by_side(_magnified(s, "nearest", 20), _magnified(s, "bilinear", 20))


def plate_11():
    return two_filters()


def three_filters():
    """nearest, bilinear and bicubic on the sprite, magnified 16x"""
    from chapter04 import side_by_side
    s = sprite()
    row = side_by_side(_magnified(s, "nearest", 16), _magnified(s, "bilinear", 16))
    return side_by_side(row, _magnified(s, "bicubic", 16))


RENDERS = {
    "two-filters": two_filters,
    "plate-11": plate_11,
    "three-filters": three_filters,
}
