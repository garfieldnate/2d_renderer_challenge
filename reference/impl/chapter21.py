"""
Chapter 21, Making It Fast: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Measure, then fix. Chapter 20's walker is re-run three ways, each counting its
work in a stats record: "whole" (chapter 20 as written: every fill resolves
every cell of the canvas), "bounded" (fills confined to the path's integer
window), and "tiled" (the canvas cut into 16 x 16 tiles, each classified
empty, partial or solid from where the edges deposited; only partial tiles
are resolved, solid tiles are painted as runs, and a solid opaque colour is
copied rather than blended). Every mode draws the same bytes; the coverage
may differ in the last bits, which is the chapter's trap.
"""

import math

from renderer import color, canvas, pixel_at, write_pixel, mix
from chapter02 import coverage_buffer, coverage_at, set_coverage
from chapter04 import point, inverse, is_invertible
from chapter05 import edges, bounds
from chapter06 import transform_path, max_coverage_difference
from chapter07 import fill_path, accumulator, accumulate, apply_rule, resolve
from chapter09 import Pixel, layer, over, flatten_layer, layer_pixel
from chapter10 import paint_at, solid
from chapter13 import stroke_to_path
from chapter15 import dash
import chapter20 as C20
from chapter20 import (parse_xml, computed_style, initial_style, parse_transform,
                       view_box_matrix, shape_commands, build_path, commands_bounds,
                       paint_server, clip_coverage, mask_layer, composite_group,
                       draw_coverage, render_svg, RENDERED, WHITE, TOLERANCE)

CHAPTER = 21
FORMAT = "P6"

TILE = 16


# --------------------------------------------------------------------------
# §21.1 counting the work
# --------------------------------------------------------------------------
class Stats:
    """how much work a render did: cells resolved by a running sum, pixels
    blended one at a time, and pixels copied without a blend"""
    __slots__ = ("cells", "blends", "copies")

    def __init__(self):
        self.cells = self.blends = self.copies = 0

    def __repr__(self):
        return "stats(cells=%d, blends=%d, copies=%d)" % (self.cells, self.blends, self.copies)


def stats():
    return Stats()


def fill_path_counted(p, rule, w, h, st):
    """chapter 7's fill, counting every cell it resolves: all of them"""
    st.cells += w * h
    return fill_path(p, rule, w, h)


def draw_coverage_counted(l, cov, paint, alpha, st):
    """chapter 20's draw_coverage, counting every pixel it blends"""
    for y in range(l.height):
        for x in range(l.width):
            k = coverage_at(cov, x, y) * alpha
            if k > 0:
                st.blends += 1
                c = paint_at(paint, x + 0.5, y + 0.5)
                i = y * l.width + x
                l.pixels[i] = over(Pixel(c.red * k, c.green * k, c.blue * k, k), l.pixels[i])


# --------------------------------------------------------------------------
# §21.2 bounds
# --------------------------------------------------------------------------
def fill_bounds(p, w, h):
    """the integer window of the canvas a path's fill can touch: from the
    floor of its least x and y to one past the floor of its greatest, cut to
    the canvas. (0, 0, 0, 0) for an empty path or an empty window."""
    if not p.subpaths:
        return (0, 0, 0, 0)
    b = bounds(p)
    x0, y0 = max(0, int(math.floor(b[0]))), max(0, int(math.floor(b[1])))
    x1, y1 = min(w, int(math.floor(b[2])) + 1), min(h, int(math.floor(b[3])) + 1)
    if x1 <= x0 or y1 <= y0:
        return (0, 0, 0, 0)
    return (x0, y0, x1, y1)


class Window:
    """a coverage buffer that covers part of the canvas, its top left at
    (x0, y0) in canvas pixels"""
    __slots__ = ("x0", "y0", "cov")

    def __init__(self, x0, y0, cov):
        self.x0, self.y0, self.cov = x0, y0, cov


def coverage_in(win, x, y):
    """a window's coverage at canvas pixel (x, y), 0 outside it"""
    if isinstance(win, Window):
        return coverage_at(win.cov, x - win.x0, y - win.y0)
    if isinstance(win, TiledCoverage):
        return win.at(x, y)
    return coverage_at(win, x, y)


def full_coverage(c, w, h):
    """any of the chapter's coverages as a canvas-sized coverage buffer"""
    out = coverage_buffer(w, h)
    for y in range(h):
        for x in range(w):
            out.values[y * w + x] = coverage_in(c, x, y)
    return out


def fill_path_bounded(p, rule, w, h, st):
    """chapter 7's fill confined to the path's window: the path moved by
    (-x0, -y0) into an accumulator the window's size, resolved there"""
    x0, y0, x1, y1 = fill_bounds(p, w, h)
    cw, ch = x1 - x0, y1 - y0
    acc = accumulator(cw, ch)
    for a, b in edges(p):
        accumulate(acc, point(a.x - x0, a.y - y0), point(b.x - x0, b.y - y0))
    st.cells += cw * ch
    return Window(x0, y0, resolve(acc, rule))


def draw_window(l, win, paint, alpha, st):
    """draw_coverage over the window only"""
    cov = win.cov
    for j in range(cov.height):
        for i in range(cov.width):
            k = cov.values[j * cov.width + i] * alpha
            if k > 0:
                st.blends += 1
                x, y = win.x0 + i, win.y0 + j
                c = paint_at(paint, x + 0.5, y + 0.5)
                idx = y * l.width + x
                l.pixels[idx] = over(Pixel(c.red * k, c.green * k, c.blue * k, k), l.pixels[idx])


# --------------------------------------------------------------------------
# §21.3 tiles
# --------------------------------------------------------------------------
class SparseAccumulator:
    """chapter 7's accumulator, keeping only the cells that were deposited
    into: cell (x, row) -> [area, cover]. add_cell's rules stand: left of the
    canvas folds onto column 0 as pure cover, right of it is dropped."""
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.cells = {}

    def add(self, x, row, area, cover):
        if x < 0:
            x, area = 0, cover
        if x >= self.width:
            return
        c = self.cells.get((x, row))
        if c is None:
            self.cells[(x, row)] = [area, cover]
        else:
            c[0] += area
            c[1] += cover


def _accumulate_sparse(acc, a, b):
    """chapter 7's accumulate and accumulate_row, into a sparse accumulator"""
    if a.y == b.y:
        return
    sign = 1 if a.y > b.y else -1
    top, bottom = (b, a) if a.y > b.y else (a, b)
    slope = (bottom.x - top.x) / (bottom.y - top.y)
    first = max(math.floor(top.y), 0)
    last = min(math.ceil(bottom.y) - 1, acc.height - 1)
    for row in range(first, last + 1):
        y0, y1 = max(top.y, row), min(bottom.y, row + 1)
        x0 = top.x + (y0 - top.y) * slope
        x1 = top.x + (y1 - top.y) * slope
        height = sign * (y1 - y0)
        xa, xb = min(x0, x1), max(x0, x1)
        ca, cb = math.floor(xa), math.floor(xb)
        if ca == cb:
            xm = (xa + xb) / 2 - ca
            acc.add(ca, row, height * (1 - xm), height)
            continue
        dx = xb - xa
        for c in range(ca, cb + 1):
            lo, hi = max(xa, c), min(xb, c + 1)
            share = height * (hi - lo) / dx
            xm = (lo + hi) / 2 - c
            acc.add(c, row, share * (1 - xm), share)


def sparse_accumulate(p, w, h):
    acc = SparseAccumulator(w, h)
    for a, b in edges(p):
        _accumulate_sparse(acc, a, b)
    return acc


class TiledCoverage:
    """a fill as tiles: classes[ty][tx] is "empty", "partial" or "solid";
    partial tiles keep their resolved cells, solid ones read 1, empty 0"""
    def __init__(self, w, h):
        self.width, self.height = w, h
        self.cols, self.rows = -(-w // TILE), -(-h // TILE)
        self.classes = [["empty"] * self.cols for _ in range(self.rows)]
        self.values = {}                       # (x, y) -> coverage, partial tiles only

    def at(self, x, y):
        if not (0 <= x < self.width and 0 <= y < self.height):
            return 0.0
        k = self.classes[y // TILE][x // TILE]
        if k == "solid":
            return 1.0
        if k == "empty":
            return 0.0
        return self.values[(x, y)]


def _tiled(p, rule, w, h, st):
    t = TiledCoverage(w, h)
    x0, y0, x1, y1 = fill_bounds(p, w, h)
    if x1 == 0:
        return t
    acc = sparse_accumulate(p, w, h)
    tx0, tx1 = x0 // TILE, (x1 - 1) // TILE
    ty0, ty1 = y0 // TILE, (y1 - 1) // TILE
    touched = set()
    by_row = {}
    for (x, row), (area, cover) in acc.cells.items():
        if area != 0 or cover != 0:
            touched.add((x // TILE, row // TILE))
        by_row.setdefault(row, []).append(x)
    # the running sum arriving at each tile's left edge, row by row: the
    # covers of every deposited cell to its left, added left to right
    arriving = {}
    for row in range(ty0 * TILE, min(h, (ty1 + 1) * TILE)):
        xs = sorted(by_row.get(row, []))
        running, k = 0.0, 0
        for tx in range(tx0, tx1 + 1):
            while k < len(xs) and xs[k] < tx * TILE:
                running += acc.cells[(xs[k], row)][1]
                k += 1
            arriving[(tx, row)] = running
    for ty in range(ty0, ty1 + 1):
        rows = range(ty * TILE, min(h, (ty + 1) * TILE))
        for tx in range(tx0, tx1 + 1):
            if (tx, ty) in touched:
                t.classes[ty][tx] = "partial"
                continue
            n = round(arriving[(tx, rows[0])])
            if any(abs(arriving[(tx, r)] - n) > 0.000001 for r in rows):
                t.classes[ty][tx] = "partial"
            else:
                t.classes[ty][tx] = "solid" if apply_rule(n, rule) == 1 else "empty"
    for ty in range(ty0, ty1 + 1):
        for row in range(ty * TILE, min(h, (ty + 1) * TILE)):
            for tx in range(tx0, tx1 + 1):
                if t.classes[ty][tx] != "partial":
                    continue
                running = arriving[(tx, row)]
                for x in range(tx * TILE, min(w, (tx + 1) * TILE)):
                    c = acc.cells.get((x, row))
                    area, cover = (c[0], c[1]) if c else (0.0, 0.0)
                    t.values[(x, row)] = apply_rule(running + area, rule)
                    running += cover
                    st.cells += 1
    return t


def classify_tiles(p, rule, w, h):
    """every tile of the canvas classified. a tile outside the path's window
    is empty. inside it, a tile is partial when a cell in it got a deposit
    with a nonzero area or cover, or when the running sums arriving at its
    left edge (the covers of every cell to its left in that row) are not all
    within 0.000001 of one whole number n on every row of the tile;
    otherwise it is solid when n fills
    under the rule and empty when it doesn't"""
    return _tiled(p, rule, w, h, Stats()).classes


def fill_path_tiled(p, rule, w, h, st):
    """the fill as tiles, resolving only the partial ones"""
    return _tiled(p, rule, w, h, st)


def tile_count(classes, kind):
    return sum(row.count(kind) for row in classes)


def _solid_opaque(paint, alpha):
    return paint.kind == "solid" and alpha == 1


def draw_tiled(l, t, paint, alpha, st):
    """paint a tiled fill: partial tiles pixel by pixel; solid tiles as runs,
    each pixel written as the paint's colour, opaque, when the paint is a
    solid colour at alpha 1, and blended at alpha otherwise; empty tiles not
    at all"""
    col = paint.data["color"] if paint.kind == "solid" else None
    for ty in range(t.rows):
        for tx in range(t.cols):
            kind = t.classes[ty][tx]
            if kind == "empty":
                continue
            for y in range(ty * TILE, min(t.height, (ty + 1) * TILE)):
                for x in range(tx * TILE, min(t.width, (tx + 1) * TILE)):
                    idx = y * l.width + x
                    if kind == "solid" and _solid_opaque(paint, alpha):
                        st.copies += 1
                        l.pixels[idx] = Pixel(col.red, col.green, col.blue, 1.0)
                        continue
                    k = (1.0 if kind == "solid" else t.values[(x, y)]) * alpha
                    if k > 0:
                        st.blends += 1
                        c = col if col is not None else paint_at(paint, x + 0.5, y + 0.5)
                        l.pixels[idx] = over(Pixel(c.red * k, c.green * k, c.blue * k, k), l.pixels[idx])


# --------------------------------------------------------------------------
# the walker, three ways
# --------------------------------------------------------------------------
def _clipped(cov_fn, clip, w, h):
    out = coverage_buffer(w, h)
    for y in range(h):
        for x in range(w):
            out.values[y * w + x] = cov_fn(x, y) * clip.values[y * w + x]
    return out


class _Ctx:
    def __init__(self, root, w, h, mode, st):
        self.root, self.w, self.h, self.mode, self.st = root, w, h, mode, st


def _fill_and_draw(ctx, l, p, rule, paint, alpha, clip):
    w, h, st = ctx.w, ctx.h, ctx.st
    if ctx.mode == "whole":
        cov = fill_path_counted(p, rule, w, h, st)
        if clip is not None:
            cov = _clipped(lambda x, y: coverage_at(cov, x, y), clip, w, h)
        draw_coverage_counted(l, cov, paint, alpha, st)
    elif ctx.mode == "bounded":
        win = fill_path_bounded(p, rule, w, h, st)
        if clip is not None:
            draw_coverage_counted(l, _clipped(lambda x, y: coverage_in(win, x, y), clip, w, h),
                                  paint, alpha, st)
        else:
            draw_window(l, win, paint, alpha, st)
    else:
        t = fill_path_tiled(p, rule, w, h, st)
        if clip is not None:
            draw_coverage_counted(l, _clipped(t.at, clip, w, h), paint, alpha, st)
        else:
            draw_tiled(l, t, paint, alpha, st)


def _paint_for(ctx, value, cmds, ctm):
    if value is None:
        return None
    if isinstance(value, str):
        return paint_server(ctx.root, value, commands_bounds(cmds), ctm)
    return solid(value)


def _draw_shape(ctx, l, el, style, ctm, clip):
    cmds = shape_commands(el)
    if not cmds or not is_invertible(ctm):
        return
    dev = build_path(cmds, ctm, TOLERANCE)
    fp = _paint_for(ctx, style.fill, cmds, ctm)
    if fp is not None and style.fill_opacity > 0:
        _fill_and_draw(ctx, l, dev, style.fill_rule, fp, style.fill_opacity, clip)
    sp = _paint_for(ctx, style.stroke, cmds, ctm)
    if sp is not None and style.stroke_width > 0 and style.stroke_opacity > 0:
        user = transform_path(dev, inverse(ctm))
        if style.stroke_dasharray is not None:
            user = dash(user, list(style.stroke_dasharray), style.stroke_dashoffset)
        outline = stroke_to_path(user, style.stroke_width, style.stroke_linecap,
                                 style.stroke_linejoin, style.stroke_miterlimit)
        _fill_and_draw(ctx, l, transform_path(outline, ctm), "nonzero", sp,
                       style.stroke_opacity, clip)


def _render_element(ctx, l, el, parent, ctm):
    if el.name not in RENDERED:
        return
    style = computed_style(el, parent)
    ctm = ctm * parse_transform(el.attributes.get("transform"))
    clip = None
    if style.clip_path is not None:
        clip = clip_coverage(ctx.root, style.clip_path, ctm, ctx.w, ctx.h)
    grouped = style.opacity < 1 or (clip is not None and el.name in ("svg", "g"))
    target = layer(ctx.w, ctx.h) if grouped else l
    if el.name in ("svg", "g"):
        for child in el.children:
            _render_element(ctx, target, child, style, ctm)
    else:
        _draw_shape(ctx, target, el, style, ctm, None if grouped else clip)
    if grouped:
        if clip is not None:
            target = mask_layer(target, clip)
        composite_group(target, l, style.opacity)


def render_svg_with(text, width, height, mode, st):
    """chapter 20's render_svg with its fills done one of three ways, "whole",
    "bounded" or "tiled", counting the work into st"""
    root = parse_xml(text)
    ctx = _Ctx(root, width, height, mode, st)
    l = layer(width, height)
    m = view_box_matrix(root.attributes.get("viewBox"), root.attributes.get("preserveAspectRatio"),
                        width, height)
    _render_element(ctx, l, root, initial_style(), m)
    return flatten_layer(l, WHITE)


# --------------------------------------------------------------------------
# §21.5 four pixels at a time
# --------------------------------------------------------------------------
def composite_span(l, y, x, ks, col):
    """composite one colour into a row of a layer through a run of coverages,
    one pixel at a time: pixel x + i gets the colour at alpha ks[i]"""
    for i, k in enumerate(ks):
        idx = y * l.width + x + i
        d = l.pixels[idx]
        t = 1 - k
        l.pixels[idx] = Pixel(col.red * k + t * d.r, col.green * k + t * d.g,
                              col.blue * k + t * d.b, k + t * d.a)


def composite_span4(l, y, x, ks, col):
    """the same, four pixels to a step and no branch: each lane does exactly
    the scalar arithmetic, and a coverage of 0 is an exact no-op
    (c * 0 + 1 * d = d), so the result is identical. the last n mod 4 pixels
    go one at a time."""
    n = len(ks)
    i = 0
    while i + 4 <= n:
        lanes = range(i, i + 4)
        k4 = [ks[j] for j in lanes]
        t4 = [1 - k for k in k4]
        d4 = [l.pixels[y * l.width + x + j] for j in lanes]
        r4 = [col.red * k4[q] + t4[q] * d4[q].r for q in range(4)]
        g4 = [col.green * k4[q] + t4[q] * d4[q].g for q in range(4)]
        b4 = [col.blue * k4[q] + t4[q] * d4[q].b for q in range(4)]
        a4 = [k4[q] + t4[q] * d4[q].a for q in range(4)]
        for q in range(4):
            l.pixels[y * l.width + x + i + q] = Pixel(r4[q], g4[q], b4[q], a4[q])
        i += 4
    composite_span(l, y, x + i, ks[i:], col)


def layers_equal(a, b):
    """true when every channel of every pixel is the same number"""
    return all(p.r == q.r and p.g == q.g and p.b == q.b and p.a == q.a
               for p, q in zip(a.pixels, b.pixels)) and a.width == b.width and a.height == b.height


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
def _svg(name):
    return C20._svg(name)


def tile_work(text, width, height):
    """for every tile of the canvas, how many of the render's fills found it
    partial and how many found it solid: a list of rows of (partial, solid)"""
    root = parse_xml(text)
    counts = [[[0, 0] for _ in range(-(-width // TILE))] for _ in range(-(-height // TILE))]
    orig = globals()["_fill_and_draw"]

    def spy(ctx, l, p, rule, paint, alpha, clip):
        for ty, row in enumerate(classify_tiles(p, rule, width, height)):
            for tx, k in enumerate(row):
                if k == "partial":
                    counts[ty][tx][0] += 1
                elif k == "solid":
                    counts[ty][tx][1] += 1
        orig(ctx, l, p, rule, paint, alpha, clip)

    globals()["_fill_and_draw"] = spy
    try:
        render_svg_with(text, width, height, "tiled", Stats())
    finally:
        globals()["_fill_and_draw"] = orig
    return [[tuple(c) for c in row] for row in counts]


MAGENTA = color(0.85, 0.2, 0.55)
CYAN = color(0.2, 0.75, 0.9)


PAPER = color(0.02, 0.02, 0.025)


def work_map():
    """910 by 450 dark paper: on the left the tiger as the tiled walker draws
    it; on the right, from x = 460, one square per tile, magenta at 0.15 plus
    0.85 times its partial count over the busiest tile's, cyan at 0.6
    where fills found it solid and none partial, and paper where no fill
    touched it, each square inset one pixel from its tile's edges"""
    text = _svg("tiger.svg")
    tiger = render_svg_with(text, 450, 450, "tiled", Stats())
    work = tile_work(text, 450, 450)
    most = max(p for row in work for p, s in row)
    c = canvas(910, 450)
    for y in range(450):
        for x in range(910):
            write_pixel(c, x, y, PAPER)
    for y in range(450):
        for x in range(450):
            write_pixel(c, x, y, pixel_at(tiger, x, y))
            p, s = work[y // TILE][x // TILE]
            inset = x % TILE == 0 or y % TILE == 0 or x % TILE == TILE - 1 or y % TILE == TILE - 1
            if inset:
                continue
            if p > 0:
                col = mix(PAPER, MAGENTA, 0.15 + 0.85 * p / most, True)
            elif s > 0:
                col = mix(PAPER, CYAN, 0.6, True)
            else:
                continue
            write_pixel(c, 460 + x, y, col)
    return c


def tiger_tiled():
    return render_svg_with(_svg("tiger.svg"), 450, 450, "tiled", Stats())


def plate_21():
    return work_map()


RENDERS = {
    "work_map": work_map,
}
