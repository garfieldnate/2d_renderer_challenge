"""
Chapter 17, Rasterizing Type Well: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Filling a glyph gives legible text. This chapter is what makes it look good
at eleven pixels: a glyph bitmap positioned to a quarter of a pixel, a cache
keyed by (glyph, size, subpixel) and an atlas to keep the bitmaps in, the
named fudge (text blended in encoded space, and stems darkened by a fraction
of a pixel), and LCD rendering: coverage measured three times per pixel and
steered into the red, green and blue stripes through a three-tap filter.
"""

import math

from renderer import color, canvas, fill, pixel_at, write_pixel, mix, Color
from chapter02 import coverage_buffer, coverage_at, set_coverage, paint_through, magnify, ink
from chapter04 import point, translation, scaling, side_by_side
from chapter05 import path
from chapter07 import fill_path
from chapter13 import stroke_to_path
from chapter16 import (load_font, glyph_name, glyph_advance, glyph_bounds, glyph_path,
                       text_matrix, roboto)

CHAPTER = 17
FORMAT = "P6"

SUBPIXELS = 4
LCD_TAPS = (1 / 3, 1 / 3, 1 / 3)


# --------------------------------------------------------------------------
# §17.1 a glyph bitmap, positioned to a quarter pixel
# --------------------------------------------------------------------------
class Bitmap:
    """a glyph's coverage in a buffer of its own, plus where the buffer's
    top-left corner sits relative to the pen: left columns right of it and
    top rows below it (both integers, either may be negative)"""
    __slots__ = ("coverage", "left", "top")

    def __init__(self, coverage, left, top):
        self.coverage, self.left, self.top = coverage, left, top

    @property
    def width(self):
        return self.coverage.width

    @property
    def height(self):
        return self.coverage.height


def bitmap(coverage, left, top):
    return Bitmap(coverage, left, top)


def subpixel_of(x):
    """a fractional pen x as a whole pixel and one of four subpixel
    positions: the fraction rounded to the nearest quarter, carrying into
    the next pixel when it rounds to four quarters"""
    whole = math.floor(x)
    quarter = int(math.floor((x - whole) * SUBPIXELS + 0.5))
    if quarter == SUBPIXELS:
        return whole + 1, 0
    return whole, quarter


def glyph_bitmap(font, name, size, subpixel, tolerance=0.1):
    """the glyph rendered with its origin at x = subpixel / 4, y = 0, in a
    buffer just big enough: columns floor(xmin) to ceil(xmax) - 1 of its
    device bounds, rows likewise, so the same glyph at a different quarter
    is a different bitmap with the same ink"""
    s = size / font.units_per_em
    x0, y0, x1, y1 = glyph_bounds(font, name)
    if (x0, y0, x1, y1) == (0, 0, 0, 0):
        return Bitmap(coverage_buffer(0, 0), 0, 0)
    dx = subpixel / SUBPIXELS
    left = math.floor(x0 * s + dx)
    right = math.ceil(x1 * s + dx)
    top = math.floor(-y1 * s)
    bottom = math.ceil(-y0 * s)
    w, h = max(1, right - left), max(1, bottom - top)
    m = text_matrix(font, size, dx - left, -top)
    cov = fill_path(glyph_path(font, name, m, tolerance), "nonzero", w, h)
    return Bitmap(cov, left, top)


def paint_bitmap(c, bitmap, x, y, col, linear=True):
    """composite a bitmap with its pen at whole pixel (x, y): every covered
    pixel mixes toward col by its coverage, in linear light unless told
    otherwise"""
    for j in range(bitmap.height):
        for i in range(bitmap.width):
            k = coverage_at(bitmap.coverage, i, j)
            if k > 0:
                px, py = x + bitmap.left + i, y + bitmap.top + j
                if c.in_bounds(px, py):
                    write_pixel(c, px, py, mix(pixel_at(c, px, py), col, k, linear))


def draw_glyph_at(c, font, name, size, x, y, col, linear=True):
    """a glyph with its pen at a fractional x: pick the subpixel, look the
    bitmap up, paint it at the whole pixel"""
    whole, quarter = subpixel_of(x)
    paint_bitmap(c, glyph_bitmap(font, name, size, quarter), whole, int(y), col, linear)


# --------------------------------------------------------------------------
# §17.2 the cache and the atlas
# --------------------------------------------------------------------------
class GlyphCache:
    def __init__(self):
        self.bitmaps = {}


def glyph_cache():
    return GlyphCache()


def cached_bitmap(cache, font, name, size, subpixel):
    """the bitmap for (glyph, size, subpixel), rendered the first time and
    the same object every time after"""
    key = (name, size, subpixel)
    if key not in cache.bitmaps:
        cache.bitmaps[key] = glyph_bitmap(font, name, size, subpixel)
    return cache.bitmaps[key]


def cache_size(cache):
    return len(cache.bitmaps)


class Atlas:
    """shelf packing: bitmaps go left to right along a shelf whose height
    is its first bitmap's; when one doesn't fit, a new shelf opens below"""
    __slots__ = ("width", "height", "shelf_y", "shelf_h", "shelf_x", "coverage")

    def __init__(self, width, height):
        self.width, self.height = width, height
        self.shelf_y = self.shelf_h = self.shelf_x = 0
        self.coverage = coverage_buffer(width, height)


def atlas(width, height):
    return Atlas(width, height)


def atlas_add(a, bitmap):
    """place a bitmap and answer (x, y) of its top-left corner in the
    atlas, or none when there is no room"""
    w, h = bitmap.width, bitmap.height
    if w > a.width or h > a.height:
        return None
    if a.shelf_x + w > a.width:                       # open a new shelf
        a.shelf_y += a.shelf_h
        a.shelf_x, a.shelf_h = 0, 0
    if a.shelf_y + max(h, a.shelf_h) > a.height:
        return None
    x, y = a.shelf_x, a.shelf_y
    for j in range(h):
        for i in range(w):
            set_coverage(a.coverage, x + i, y + j, coverage_at(bitmap.coverage, i, j))
    a.shelf_x += w
    a.shelf_h = max(a.shelf_h, h)
    return (x, y)


# --------------------------------------------------------------------------
# §17.3 the fudge, named: encoded-space blending and stem darkening
# --------------------------------------------------------------------------
def embolden(font, name, size, amount, tolerance=0.1):
    """the glyph's coverage with its outline pushed out by amount / 2 on
    each side: the fill plus the outline stroked amount wide, added and
    clamped. A bitmap like glyph_bitmap's, grown a pixel all round."""
    s = size / font.units_per_em
    x0, y0, x1, y1 = glyph_bounds(font, name)
    left, top = math.floor(x0 * s) - 1, math.floor(-y1 * s) - 1
    w = math.ceil(x1 * s) + 1 - left
    h = math.ceil(-y0 * s) + 1 - top
    m = text_matrix(font, size, -left, -top)
    p = glyph_path(font, name, m, tolerance)
    fillcov = fill_path(p, "nonzero", w, h)
    edge = fill_path(stroke_to_path(p, amount, "butt", "round", 4.0), "nonzero", w, h)
    out = coverage_buffer(w, h)
    for i in range(w * h):
        out.values[i] = min(1.0, fillcov.values[i] + edge.values[i])
    return Bitmap(out, left, top)


# --------------------------------------------------------------------------
# §17.4 LCD: three coverages per pixel
# --------------------------------------------------------------------------
def lcd_filter(values):
    """each entry replaced by the average of itself and its two
    neighbours, with zeros beyond the ends: the three-tap filter whose taps
    sum to one, so ink is spread but not lost"""
    n = len(values)
    out = []
    for i in range(n):
        a = values[i - 1] if i > 0 else 0.0
        b = values[i]
        c = values[i + 1] if i + 1 < n else 0.0
        out.append(LCD_TAPS[0] * a + LCD_TAPS[1] * b + LCD_TAPS[2] * c)
    return out


def lcd_coverage(font, name, size, x, y, w, h, tolerance=0.1):
    """the glyph rasterized three times wider, one coverage per subpixel
    stripe, each row filtered: a buffer 3 w wide and h tall"""
    m = scaling(3, 1) * text_matrix(font, size, x, y)
    raw = fill_path(glyph_path(font, name, m, tolerance), "nonzero", 3 * w, h)
    out = coverage_buffer(3 * w, h)
    for row in range(h):
        vals = raw.values[row * 3 * w:(row + 1) * 3 * w]
        out.values[row * 3 * w:(row + 1) * 3 * w] = lcd_filter(vals)
    return out


def paint_lcd(c, cov3, col):
    """composite a three-per-pixel coverage: red through the first stripe,
    green the second, blue the third, each channel mixed on its own"""
    for y in range(c.height):
        for x in range(c.width):
            kr = coverage_at(cov3, 3 * x, y)
            kg = coverage_at(cov3, 3 * x + 1, y)
            kb = coverage_at(cov3, 3 * x + 2, y)
            if kr > 0 or kg > 0 or kb > 0:
                d = pixel_at(c, x, y)
                write_pixel(c, x, y, Color(d.red + (col.red - d.red) * kr,
                                           d.green + (col.green - d.green) * kg,
                                           d.blue + (col.blue - d.blue) * kb))


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
WHITE = color(1, 1, 1)
BLACK = color(0, 0, 0)
GRAY = color(0.62, 0.62, 0.66)


def pen_advance(font, name, size):
    return glyph_advance(font, name) * size / font.units_per_em


def draw_text(c, font, text, size, x, y, col, linear=True, cache=None):
    """glyph after glyph, the pen advancing by each advance in fractional
    pixels, each glyph placed at its nearest quarter pixel. Chapter 18 does
    this properly; this is enough to look at."""
    pen = x
    for ch in text:
        name = glyph_name(font, ord(ch))
        whole, quarter = subpixel_of(pen)
        bm = cached_bitmap(cache, font, name, size, quarter) if cache else glyph_bitmap(font, name, size, quarter)
        paint_bitmap(c, bm, whole, int(y), col, linear)
        pen += pen_advance(font, name, size)
    return pen


def subpixel_strip():
    """the letter l at 11 pixels, its pen at x = 4, 4.25, 4.5 and 4.75 in
    four panels, magnified eight times"""
    font = roboto()
    panels = []
    for k in range(4):
        c = canvas(10, 14)
        fill(c, WHITE)
        draw_glyph_at(c, font, "l", 11, 4 + k / 4, 11, BLACK)
        panels.append(c)
    row = side_by_side(side_by_side(panels[0], panels[1]), side_by_side(panels[2], panels[3]))
    return magnify(row, 8)


def smoothing_demo():
    """Hamburg at 11 pixels, black on white, three ways: blended in linear
    light; blended in encoded space, which is what every text stack does;
    and linear again with the stems darkened by a third of a pixel"""
    font = roboto()
    W, H = 72, 42
    c = canvas(W, H)
    fill(c, WHITE)
    draw_text(c, font, "Hamburg", 11, 2, 11, BLACK, True)
    draw_text(c, font, "Hamburg", 11, 2, 25, BLACK, False)
    pen = 2.0
    for ch in "Hamburg":
        name = glyph_name(font, ord(ch))
        whole, quarter = subpixel_of(pen)
        bm = embolden(font, name, 11, 1 / 3)
        paint_bitmap(c, bm, whole, 39, BLACK, True)
        pen += pen_advance(font, name, 11)
    return magnify(c, 4)


def lcd_plate():
    """the letters 'ea' at 13 pixels, black on white: grayscale coverage on
    top, LCD coverage below, magnified six times so the stripes show"""
    font = roboto()
    W, H = 24, 16
    top = canvas(W, H)
    fill(top, WHITE)
    bottom = canvas(W, H)
    fill(bottom, WHITE)
    pen = 2.0
    for ch in "ea":
        name = glyph_name(font, ord(ch))
        m = text_matrix(font, 13, pen, 12)
        paint_through(top, fill_path(glyph_path(font, name, m, 0.1), "nonzero", W, H), BLACK)
        paint_lcd(bottom, lcd_coverage(font, name, 13, pen, 12, W, H), BLACK)
        pen += pen_advance(font, name, 13)
    both = canvas(W, 2 * H)
    for y in range(H):
        for x in range(W):
            write_pixel(both, x, y, pixel_at(top, x, y))
            write_pixel(both, x, y + H, pixel_at(bottom, x, y))
    return magnify(both, 6)


def plate_17():
    return magnify(lcd_plate(), 2)


RENDERS = {
    "subpixels": subpixel_strip,
    "smoothing": smoothing_demo,
    "lcd": lcd_plate,
    "plate-17": plate_17,
}
