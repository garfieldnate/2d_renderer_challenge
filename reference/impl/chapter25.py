"""
Chapter 25, The Raster Editor Detour: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

A raster editor's tools are the same coverage machinery with the geometry
supplied by a hand instead of a path: a brush is a coverage kernel stamped
along the pointer's path, a bucket is a coverage mask grown from a seed, a
selection is a coverage mask kept for later, and indexed colour is a
palette plus the error you owe when a pixel doesn't match it.
"""

import math
import struct

from renderer import canvas, color, fill, mix, clamp, write_pixel, pixel_at, decode, encode, to_byte
from chapter02 import coverage_buffer, coverage_at, set_coverage, paint_through, magnify, canvas_to_p6
from chapter04 import point, magnitude, side_by_side
from chapter05 import circle_path
from chapter07 import fill_path
from chapter09 import Pixel, layer, over, layer_pixel, flatten_layer
from chapter10 import BAYER4, dither_threshold, linear_gradient, stop, paint_at
from chapter12 import multiply_coverage, clip_rect
from chapter13 import stroke_to_path

CHAPTER = 25
FORMAT = "P6"


# --------------------------------------------------------------------------
# §25.1 brushes
# --------------------------------------------------------------------------
class Brush:
    __slots__ = ("radius", "hardness", "spacing", "flow", "opacity")

    def __init__(self, radius, hardness, spacing, flow, opacity):
        self.radius, self.hardness, self.spacing = radius, hardness, spacing
        self.flow, self.opacity = flow, opacity


def brush(radius, hardness, spacing, flow, opacity):
    return Brush(radius, hardness, spacing, flow, opacity)


def dab_coverage(b, d):
    """the brush's coverage at distance d from its center: 1 inside
    hardness x radius, 0 outside the radius, a straight ramp between"""
    inner = b.hardness * b.radius
    if d <= inner:
        return 1.0
    if d >= b.radius:
        return 0.0
    return (b.radius - d) / (b.radius - inner)


def stamp_positions(events, b):
    """dab centers along the pointer's path: the first event, then every
    spacing x 2 x radius of arc length along the polyline through the
    events, carrying the leftover distance from segment to segment"""
    if not events:
        return []
    step = b.spacing * 2 * b.radius
    out = [events[0]]
    need = step
    for a, c in zip(events, events[1:]):
        seg = magnitude(c - a)
        pos = 0.0
        while seg - pos >= need:
            pos += need
            t = pos / seg
            out.append(point(a.x + (c.x - a.x) * t, a.y + (c.y - a.y) * t))
            need = step
        need -= seg - pos
    return out


def stroke_mask(w, h, centers, b):
    """one stroke's coverage: every dab builds up at flow, 1 - (1 - m)(1 -
    flow x k), sampled at pixel centers over the dab's box"""
    m = coverage_buffer(w, h)
    for q in centers:
        x0, x1 = max(0, math.floor(q.x - b.radius)), min(w - 1, math.ceil(q.x + b.radius))
        y0, y1 = max(0, math.floor(q.y - b.radius)), min(h - 1, math.ceil(q.y + b.radius))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                dx, dy = x + 0.5 - q.x, y + 0.5 - q.y
                k = dab_coverage(b, math.sqrt(dx * dx + dy * dy))
                if k > 0:
                    i = y * w + x
                    m.values[i] = 1 - (1 - m.values[i]) * (1 - b.flow * k)
    return m


def paint_stroke(c, events, b, col, by_distance=True):
    """a stroke onto the canvas: its mask, capped at the brush's opacity,
    painted through; by_distance false stamps one dab per event, the way
    a brush that trusts the mouse does"""
    centers = stamp_positions(events, b) if by_distance else list(events)
    m = stroke_mask(c.width, c.height, centers, b)
    for i in range(len(m.values)):
        m.values[i] *= b.opacity
    paint_through(c, m, col)
    return m


def wobbly_events():
    """a pointer's events along a wave, bunched where the hand slowed: x =
    20 + 360 u² (u = i / 24), y = 60 + 30 sin(2 pi u), 25 events"""
    out = []
    for i in range(25):
        u = i / 24
        out.append(point(20 + 360 * u * u, 60 + 30 * math.sin(2 * math.pi * u)))
    return out


def min_along(m, events, samples):
    """the least mask value at pixel centers along the event polyline,
    sampled at n points per segment"""
    best = 1.0
    for a, c in zip(events, events[1:]):
        for k in range(samples):
            t = k / samples
            x, y = a.x + (c.x - a.x) * t, a.y + (c.y - a.y) * t
            best = min(best, coverage_at(m, int(math.floor(x)), int(math.floor(y))))
    return best


# --------------------------------------------------------------------------
# §25.2 flood fill
# --------------------------------------------------------------------------
def bytes_at(c, x, y):
    p = pixel_at(c, x, y)
    return (to_byte(p.red), to_byte(p.green), to_byte(p.blue))


def matches(c, x, y, seed, tolerance):
    """within tolerance of the seed: every channel's byte no more than
    tolerance from the seed's"""
    b = bytes_at(c, x, y)
    return all(abs(b[k] - seed[k]) <= tolerance for k in range(3))


class FillStats:
    __slots__ = ("pushes", "deepest")

    def __init__(self):
        self.pushes = self.deepest = 0


def fill_stats():
    return FillStats()


def bytes_of(data, i, j):
    return list(data[i:j])


def flood_mask(c, x, y, tolerance, connectivity, fs=None):
    """the scanline flood fill as a mask: from the seed, grow along the row
    to both ends of the matching run, mark it, and push the matching runs
    of the rows above and below it (for 8-connectivity, reaching one pixel
    further each way); a stack of spans, never recursion"""
    fs = fs if fs is not None else FillStats()
    w, h = c.width, c.height
    m = coverage_buffer(w, h)
    seed = bytes_at(c, x, y)
    stack = [(x, y)]
    fs.pushes += 1
    while stack:
        fs.deepest = max(fs.deepest, len(stack))
        px, py = stack.pop()
        if m.values[py * w + px] or not matches(c, px, py, seed, tolerance):
            continue
        lx = px
        while lx > 0 and not m.values[py * w + lx - 1] and matches(c, lx - 1, py, seed, tolerance):
            lx -= 1
        rx = px
        while rx < w - 1 and not m.values[py * w + rx + 1] and matches(c, rx + 1, py, seed, tolerance):
            rx += 1
        for k in range(lx, rx + 1):
            m.values[py * w + k] = 1.0
        reach = 1 if connectivity == 8 else 0
        for ny in (py - 1, py + 1):
            if not 0 <= ny < h:
                continue
            inrun = False
            for k in range(max(0, lx - reach), min(w - 1, rx + reach) + 1):
                ok = not m.values[ny * w + k] and matches(c, k, ny, seed, tolerance)
                if ok and not inrun:
                    stack.append((k, ny))
                    fs.pushes += 1
                inrun = ok
    return m


def select_color(c, x, y, tolerance):
    """contiguous off: every pixel of the canvas within tolerance of the
    seed"""
    seed = bytes_at(c, x, y)
    m = coverage_buffer(c.width, c.height)
    for yy in range(c.height):
        for xx in range(c.width):
            if matches(c, xx, yy, seed, tolerance):
                m.values[yy * c.width + xx] = 1.0
    return m


def anti_alias_mask(m):
    """the bucket's anti-alias box: a pixel outside the mask with a
    4-neighbour inside gets 0.5"""
    w, h = m.width, m.height
    out = coverage_buffer(w, h)
    out.values = list(m.values)
    for y in range(h):
        for x in range(w):
            if m.values[y * w + x]:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and m.values[ny * w + nx]:
                    out.values[y * w + x] = 0.5
                    break
    return out


def bucket(c, x, y, col, tolerance, contiguous, anti_alias, connectivity=4):
    """the paint bucket: a flood mask (or select_color when not
    contiguous), anti-aliased if asked, painted through"""
    m = flood_mask(c, x, y, tolerance, connectivity) if contiguous else select_color(c, x, y, tolerance)
    if anti_alias:
        m = anti_alias_mask(m)
    paint_through(c, m, col)
    return m


def naive_depth(w, h):
    """how deep the four-way recursive fill goes filling an empty w by h
    canvas from its top left: the length of its longest chain of calls,
    found without recursing (it visits right, left, down, up)"""
    seen = bytearray(w * h)
    # the recursion is a depth-first walk; simulate it with an explicit
    # stack of (x, y, next direction)
    deepest = 0
    stack = [(0, 0, 0)]
    seen[0] = 1
    dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
    while stack:
        deepest = max(deepest, len(stack))
        x, y, k = stack[-1]
        if k == 4:
            stack.pop()
            continue
        stack[-1] = (x, y, k + 1)
        nx, ny = x + dirs[k][0], y + dirs[k][1]
        if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
            seen[ny * w + nx] = 1
            stack.append((nx, ny, 0))
    return deepest


def ring_canvas():
    """a disc's outline on paper, the ground a bucket gets poured on: a
    160 by 160 canvas of pale paper with chapter 13's stroke of a 96-gon
    circle of radius 60 about (80, 80), 4 wide, round joins, filled by
    chapter 7 and painted through in ink"""
    c = canvas(160, 160)
    fill(c, PALE)
    o = stroke_to_path(circle_path(80, 80, 60, 96), 4, "butt", "round", 4.0)
    paint_through(c, fill_path(o, "nonzero", 160, 160), INK_DARK)
    return c


# --------------------------------------------------------------------------
# §25.3 quantization
# --------------------------------------------------------------------------
def canvas_bytes(c):
    return [bytes_at(c, i % c.width, i // c.width) for i in range(c.width * c.height)]


def median_cut(colors, n):
    """a palette of at most n byte colours: count every distinct colour and
    start with one box of them all; while there are fewer than n boxes,
    take the box whose widest channel is widest (the earliest box on a
    tie) among boxes with at least two colours; sort its colours stably by
    that channel (red before green before blue when widths tie), and cut
    it after the first colour at which the running count of pixels reaches
    half the box's pixels, but never after its last; the palette is each
    box's mean colour weighted by count, rounded halves up"""
    counts = {}
    for col in colors:
        counts[col] = counts.get(col, 0) + 1
    boxes = [sorted(counts)]

    def rng(box, k):
        return max(col[k] for col in box) - min(col[k] for col in box)

    while len(boxes) < n:
        cands = [(i, max(rng(b, k) for k in range(3))) for i, b in enumerate(boxes) if len(b) >= 2]
        if not cands:
            break
        i = max(cands, key=lambda iw: (iw[1], -iw[0]))[0]
        box = boxes[i]
        ch = max(range(3), key=lambda k: (rng(box, k), -k))
        box = sorted(box, key=lambda col: col[ch])
        total = sum(counts[col] for col in box)
        run, cut = 0, 1
        for j, col in enumerate(box):
            run += counts[col]
            if 2 * run >= total:
                cut = j + 1
                break
        cut = min(max(cut, 1), len(box) - 1)
        boxes[i:i + 1] = [box[:cut], box[cut:]]
    out = []
    for b in boxes:
        t = sum(counts[col] for col in b)
        out.append(tuple(int(math.floor(sum(col[k] * counts[col] for col in b) / t + 0.5)) for k in range(3)))
    return out


def nearest_index(palette, col):
    """the palette entry nearest a byte colour by squared distance, the
    lowest index on a tie"""
    best, bi = None, 0
    for i, p in enumerate(palette):
        d = (p[0] - col[0]) ** 2 + (p[1] - col[1]) ** 2 + (p[2] - col[2]) ** 2
        if best is None or d < best:
            best, bi = d, i
    return bi


def remap(c, palette):
    """every pixel to its nearest palette index"""
    return [nearest_index(palette, b) for b in canvas_bytes(c)]


def _lin(palette):
    return [(decode(p[0] / 255), decode(p[1] / 255), decode(p[2] / 255)) for p in palette]


def nearest_linear(lp, v):
    best, bi = None, 0
    for i, p in enumerate(lp):
        d = (p[0] - v[0]) ** 2 + (p[1] - v[1]) ** 2 + (p[2] - v[2]) ** 2
        if best is None or d < best:
            best, bi = d, i
    return bi


def error_diffuse(c, palette):
    """Floyd and Steinberg in linear light: rows top to bottom, each left
    to right; a pixel's light plus the error it has been handed goes to
    the nearest palette entry in light, and what's left over goes 7/16 to
    the right, 3/16 below left, 5/16 below, 1/16 below right, the shares
    that fall off the canvas dropped"""
    w, h = c.width, c.height
    lp = _lin(palette)
    err = [[0.0, 0.0, 0.0] for _ in range(w * h)]
    out = [0] * (w * h)
    for y in range(h):
        for x in range(w):
            p = pixel_at(c, x, y)
            e = err[y * w + x]
            v = (p.red + e[0], p.green + e[1], p.blue + e[2])
            i = nearest_linear(lp, v)
            out[y * w + x] = i
            q = lp[i]
            d = (v[0] - q[0], v[1] - q[1], v[2] - q[2])
            for dx, dy, share in ((1, 0, 7), (-1, 1, 3), (0, 1, 5), (1, 1, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and ny < h:
                    t = err[ny * w + nx]
                    for k in range(3):
                        t[k] += d[k] * share / 16
    return out


def ordered_dither(c, palette):
    """chapter 10's Bayer threshold for a two-entry palette: a pixel takes
    the second entry when its light is above dither_threshold(x, y)
    between the two entries' light (measured on green), the first
    otherwise"""
    lp = _lin(palette)
    lo, hi = lp[0][1], lp[1][1]
    out = []
    for y in range(c.height):
        for x in range(c.width):
            v = pixel_at(c, x, y).green
            t = lo + (hi - lo) * dither_threshold(x, y)
            out.append(1 if v > t else 0)
    return out


def threshold(c, palette):
    """the nearest entry in light, no dither"""
    lp = _lin(palette)
    return [nearest_linear(lp, (p.red, p.green, p.blue)) for p in c.pixels]


def indexed_canvas(indices, palette, w, h):
    c = canvas(w, h)
    for i, k in enumerate(indices):
        p = palette[k]
        c.pixels[i] = color(decode(p[0] / 255), decode(p[1] / 255), decode(p[2] / 255))
    return c


def canvas_to_bmp8(indices, palette, w, h):
    """an 8-bit indexed BMP: the 14-byte file header ("BM", file size,
    0, pixel offset), the 40-byte info header (40, w, h, 1 plane, 8 bits,
    no compression, image size, 2835 by 2835 pixels a metre, colours
    used, 0), 256 palette entries of blue, green, red, 0 (unused entries
    black), then the rows bottom to top, each padded with zeros to a
    multiple of 4 bytes; every number little-endian"""
    stride = (w + 3) // 4 * 4
    offset = 14 + 40 + 256 * 4
    size = offset + stride * h
    out = bytearray(b"BM")
    out += struct.pack("<IHHI", size, 0, 0, offset)
    out += struct.pack("<IiiHHIIiiII", 40, w, h, 1, 8, 0, stride * h, 2835, 2835, len(palette), 0)
    for i in range(256):
        r, g, b = palette[i] if i < len(palette) else (0, 0, 0)
        out += bytes((b, g, r, 0))
    for y in range(h - 1, -1, -1):
        row = bytes(indices[y * w:(y + 1) * w])
        out += row + bytes(stride - w)
    return bytes(out)


def read_bmp8(data):
    """(width, height, palette, indices) back out of canvas_to_bmp8"""
    offset = struct.unpack_from("<I", data, 10)[0]
    w, h = struct.unpack_from("<ii", data, 18)
    used = struct.unpack_from("<I", data, 46)[0]
    pal = []
    for i in range(used or 256):
        b, g, r, _ = data[54 + 4 * i:58 + 4 * i]
        pal.append((r, g, b))
    stride = (w + 3) // 4 * 4
    idx = [0] * (w * h)
    for row in range(h):
        y = h - 1 - row
        base = offset + row * stride
        idx[y * w:(y + 1) * w] = list(data[base:base + w])
    return w, h, pal, idx


def ramp_canvas(w, h):
    """light rising left to right, x / (w - 1), every row the same"""
    c = canvas(w, h)
    for y in range(h):
        for x in range(w):
            g = x / (w - 1)
            c.pixels[y * w + x] = color(g, g, g)
    return c


def mean_light(c):
    return sum(p.green for p in c.pixels) / len(c.pixels)


# --------------------------------------------------------------------------
# §25.4 selection and undo
# --------------------------------------------------------------------------
def marquee(x0, y0, x1, y1, w, h):
    """a rectangle selection, chapter 12's clip_rect"""
    return clip_rect(x0, y0, x1, y1, w, h)


def add_selection(a, b):
    out = coverage_buffer(a.width, a.height)
    out.values = [1 - (1 - x) * (1 - y) for x, y in zip(a.values, b.values)]
    return out


def subtract_selection(a, b):
    out = coverage_buffer(a.width, a.height)
    out.values = [x * (1 - y) for x, y in zip(a.values, b.values)]
    return out


def intersect_selection(a, b):
    return multiply_coverage(a, b)


def feather(m, r):
    """a box blur of radius r, run along rows then down columns, each
    pixel the mean of the 2r + 1 values centred on it, those off the
    buffer counted as 0"""
    w, h = m.width, m.height
    tmp = [0.0] * (w * h)
    for y in range(h):
        for x in range(w):
            s = 0.0
            for k in range(x - r, x + r + 1):
                if 0 <= k < w:
                    s += m.values[y * w + k]
            tmp[y * w + x] = s / (2 * r + 1)
    out = coverage_buffer(w, h)
    for y in range(h):
        for x in range(w):
            s = 0.0
            for k in range(y - r, y + r + 1):
                if 0 <= k < h:
                    s += tmp[k * w + x]
            out.values[y * w + x] = s / (2 * r + 1)
    return out


class Floating:
    """pixels lifted out of the canvas through a selection, and where they
    sit now"""
    __slots__ = ("layer", "dx", "dy")

    def __init__(self, l, dx, dy):
        self.layer, self.dx, self.dy = l, dx, dy


def float_selection(c, sel, backfill):
    """cut: the selection's pixels into a premultiplied layer, at the
    selection's coverage, and the canvas under them mixed toward the
    backfill colour by the same coverage"""
    l = layer(c.width, c.height)
    for i, k in enumerate(sel.values):
        if k > 0:
            p = c.pixels[i]
            l.pixels[i] = Pixel(p.red * k, p.green * k, p.blue * k, k)
            c.pixels[i] = mix(p, backfill, k, True)
    return Floating(l, 0, 0)


def move_floating(f, dx, dy):
    f.dx += dx
    f.dy += dy


def drop_floating(c, f):
    """paste: the layer, moved, source-over the canvas; pixels moved off
    the canvas are lost"""
    w, h = c.width, c.height
    for y in range(h):
        for x in range(w):
            p = f.layer.pixels[y * w + x]
            if p.a <= 0:
                continue
            nx, ny = x + f.dx, y + f.dy
            if 0 <= nx < w and 0 <= ny < h:
                d = c.pixels[ny * w + nx]
                t = 1 - p.a
                c.pixels[ny * w + nx] = color(p.r + t * d.red, p.g + t * d.green, p.b + t * d.blue)


class History:
    """a command stack: every edit saves the pixels of the rectangle it
    will change before it runs; undo puts them back and keeps what it
    replaced for redo; a new edit after an undo throws redo away"""
    def __init__(self, c):
        self.canvas = c
        self.undo_stack, self.redo_stack = [], []

    def _snap(self, rect):
        x0, y0, x1, y1 = rect
        w = self.canvas.width
        return [self.canvas.pixels[y * w + x] for y in range(y0, y1) for x in range(x0, x1)]

    def _put(self, rect, pixels):
        x0, y0, x1, y1 = rect
        w = self.canvas.width
        i = 0
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.canvas.pixels[y * w + x] = pixels[i]
                i += 1

    def do(self, rect, edit):
        """rect is (x0, y0, x1, y1), end exclusive, cut to the canvas"""
        c = self.canvas
        rect = (max(0, rect[0]), max(0, rect[1]), min(c.width, rect[2]), min(c.height, rect[3]))
        before = self._snap(rect)
        edit(c)
        self.undo_stack.append((rect, before))
        self.redo_stack = []

    def undo(self):
        if not self.undo_stack:
            return False
        rect, before = self.undo_stack.pop()
        after = self._snap(rect)
        self._put(rect, before)
        self.redo_stack.append((rect, after))
        return True

    def redo(self):
        if not self.redo_stack:
            return False
        rect, after = self.redo_stack.pop()
        before = self._snap(rect)
        self._put(rect, after)
        self.undo_stack.append((rect, before))
        return True


def history(c):
    return History(c)


def stored_pixels(h):
    """how many pixels the history holds, on both stacks"""
    return sum(len(px) for _, px in h.undo_stack + h.redo_stack)


def history_fill(h, x0, y0, x1, y1, col):
    """an edit through the history: the rectangle x0..x1-1, y0..y1-1 set to
    col"""
    def edit(c):
        for y in range(max(0, y0), min(c.height, y1)):
            for x in range(max(0, x0), min(c.width, x1)):
                c.pixels[y * c.width + x] = col
    h.do((x0, y0, x1, y1), edit)


def undo(h):
    return h.undo()


def redo(h):
    return h.redo()


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
PALE = color(0.92, 0.9, 0.82)
INK = color(0.9, 0.55, 0.1)
INK_DARK = color(0.05, 0.05, 0.08)
CYAN = color(0.2, 0.75, 0.9)
MAGENTA = color(0.85, 0.2, 0.55)
BLACK_WHITE = [(0, 0, 0), (255, 255, 255)]


def plate_25():
    """left: the ring's inside bucketed cyan at tolerance 32, contiguous,
    no anti-alias, from (80, 80); its pixels 100 to 159 across and 50 to
    109 down, magnified 4 times. Right: a 240 by 240 ramp error-diffused
    to black and white. 480 by 240"""
    c = ring_canvas()
    bucket(c, 80, 80, CYAN, 32, True, False)
    crop = canvas(60, 60)
    for y in range(60):
        for x in range(60):
            crop.pixels[y * 60 + x] = pixel_at(c, 100 + x, 50 + y)
    r = ramp_canvas(240, 240)
    right = indexed_canvas(error_diffuse(r, BLACK_WHITE), BLACK_WHITE, 240, 240)
    return side_by_side(magnify(crop, 4), right)


def dither_strip():
    """a 256 by 32 ramp three ways, stacked: threshold, ordered, error
    diffusion, each to black and white; 256 by 96"""
    r = ramp_canvas(256, 32)
    out = canvas(256, 96)
    for k, f in enumerate((threshold, ordered_dither, error_diffuse)):
        cc = indexed_canvas(f(r, BLACK_WHITE), BLACK_WHITE, 256, 32)
        out.pixels[k * 256 * 32:(k + 1) * 256 * 32] = cc.pixels
    return out


def halo_demo():
    """the ring bucketed four ways from (80, 80) in cyan, side by side:
    tolerance 0; 32; 32 with anti-alias; 160; each 160 square"""
    panels = []
    for tol, aa in ((0, False), (32, False), (32, True), (160, False)):
        c = ring_canvas()
        bucket(c, 80, 80, CYAN, tol, True, aa)
        panels.append(c)
    out = panels[0]
    for p in panels[1:]:
        out = side_by_side(out, p)
    return out


def brush_demo():
    """wobbly_events() stroked twice on 400 by 240 pale paper with brush(8,
    0.5, 0.25, 0.6, 1): by event on top (y as given), by distance below (y
    + 110), in ink"""
    c = canvas(400, 240)
    fill(c, PALE)
    ev = wobbly_events()
    paint_stroke(c, ev, brush(8, 0.5, 0.25, 0.6, 1.0), INK_DARK, False)
    paint_stroke(c, [point(q.x, q.y + 110) for q in ev], brush(8, 0.5, 0.25, 0.6, 1.0), INK_DARK, True)
    return c


SKY_TOP, SKY_LOW = color(0.05, 0.12, 0.35), color(0.95, 0.45, 0.2)
SEA = color(0.02, 0.1, 0.2)
HILL = color(0.04, 0.12, 0.06)
SUN = color(1.0, 0.8, 0.3)


def paint_by_script():
    """a dusk scene made only with this chapter's tools, then reduced to
    16 colours and read back from its BMP: 480 by 320"""
    w, h = 480, 320
    c = canvas(w, h)
    hist = history(c)
    sky = marquee(0, 0, w, 210, w, h)
    g = linear_gradient(point(0, 0), point(0, 210), [stop(0, SKY_TOP), stop(1, SKY_LOW)])

    def paint_sky(cv):
        from chapter10 import paint_fill
        paint_fill(cv, sky, g)
    hist.do((0, 0, w, 210), paint_sky)
    hist.do((0, 210, w, h), lambda cv: paint_through(cv, marquee(0, 210, w, h, w, h), SEA))
    sun = brush(46, 0.55, 0.25, 1.0, 1.0)
    hist.do((320, 60, 420, 160), lambda cv: paint_stroke(cv, [point(370, 110)], sun, SUN))
    hills = [point(-20 + 26 * i, 205 - 30 * math.sin(i / 3.1) - 12 * math.sin(i * 1.7)) for i in range(21)]
    hist.do((0, 120, w, 260), lambda cv: paint_stroke(cv, hills, brush(34, 0.7, 0.2, 0.8, 1.0), HILL))
    hist.do((0, 0, w, h), lambda cv: paint_stroke(cv, [point(40, 40), point(460, 300)], brush(30, 0.5, 0.2, 1.0, 1.0), MAGENTA))
    hist.undo()
    for k in range(6):
        y = 232 + 14 * k
        wave = [point(60 + 60 * k + 8 * j, y + 2 * math.sin(j)) for j in range(12)]
        hist.do((0, 200, w, h), lambda cv, wave=wave: paint_stroke(cv, wave, brush(1.6, 0.2, 0.3, 0.7, 0.8), SUN))
    boat = marquee(150, 262, 210, 272, w, h)
    hist.do((140, 250, 220, 280), lambda cv: paint_through(cv, boat, INK_DARK))
    f = float_selection(c, boat, SEA)
    move_floating(f, 40, -6)
    drop_floating(c, f)
    pal = median_cut(canvas_bytes(c), 16)
    idx = error_diffuse(c, pal)
    w2, h2, pal2, idx2 = read_bmp8(canvas_to_bmp8(idx, pal, w, h))
    return indexed_canvas(idx2, pal2, w2, h2)


RENDERS = {
    "plate-25": plate_25,
    "dither-strip": dither_strip,
    "halo-demo": halo_demo,
    "brush-demo": brush_demo,
    "paint-by-script": paint_by_script,
}
