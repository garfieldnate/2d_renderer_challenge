"""
Chapter 24, Doing It the GPU's Way: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

The algorithms a GPU runs, as ordinary code that obeys a GPU's rules: no
sorting, no unbounded per-pixel work, no shared mutable state between work
items, fixed-size tiles. Stencil-and-cover fills by adding signed triangles
into a winding buffer; Loop-Blinn draws quadratics with u^2 - v and no
flattening; multisampling counts samples instead of measuring area; and
chapter 21's tiler becomes four stages, flatten, bin, coarse and fine, whose
last stage can run its tiles in any order.
"""

import math

from renderer import canvas, color, fill, mix, clamp, write_pixel, pixel_at
from chapter02 import coverage_buffer, coverage_at, set_coverage, paint_through, magnify
from chapter04 import point, cross, translation, scaling, side_by_side
from chapter05 import path, move_to, line_to, close, edges, polygon, star, winding_at, subpaths
from chapter06 import transform_path, max_coverage_difference
from chapter07 import fill_path, apply_rule
from chapter08 import point_at
from chapter16 import roboto, glyph_outline, glyph_path, text_matrix, glyph_name
from chapter23 import glyph_curves

CHAPTER = 24
FORMAT = "P6"


# --------------------------------------------------------------------------
# §24.1 filling without sorting: stencil and cover
# --------------------------------------------------------------------------
class Stencil:
    """a whole number per pixel, and how many fragments were written"""
    __slots__ = ("width", "height", "values", "fragments")

    def __init__(self, w, h):
        self.width, self.height = w, h
        self.values = [0] * (w * h)
        self.fragments = 0


def stencil_at(s, x, y):
    return s.values[y * s.width + x]


def triangle_winding(a, b, c, x, y):
    """chapter 5's winding_at for the closed triangle a, b, c at (x, y):
    +1, -1 or 0"""
    w = 0
    q = point(x, y)
    for u, v in ((a, b), (b, c), (c, a)):
        if u.y <= y:
            if v.y > y and cross(v - u, q - u) > 0:
                w += 1
        else:
            if v.y <= y and cross(v - u, q - u) < 0:
                w -= 1
    return w


def stencil_triangle(s, a, b, c, ox=0.5, oy=0.5):
    """add the triangle's winding into every pixel whose sample point
    (x + ox, y + oy) it covers, visiting only its bounding box; a pixel it
    changes is a fragment"""
    x0 = max(0, math.floor(min(a.x, b.x, c.x) - ox))
    x1 = min(s.width - 1, math.ceil(max(a.x, b.x, c.x) - ox))
    y0 = max(0, math.floor(min(a.y, b.y, c.y) - oy))
    y1 = min(s.height - 1, math.ceil(max(a.y, b.y, c.y) - oy))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            w = triangle_winding(a, b, c, x + ox, y + oy)
            if w:
                s.values[y * s.width + x] += w
                s.fragments += 1


def fan_anchor(p):
    """the first point of the first subpath with one, or the origin"""
    for sp in p.subpaths:
        if sp.points:
            return sp.points[0]
    return point(0, 0)


def stencil_buffer(p, w, h, ox=0.5, oy=0.5):
    """one triangle per edge, anchor to the edge's ends, each added with its
    own sign: the buffer that falls out is chapter 5's winding number at
    every pixel's sample point"""
    s = Stencil(w, h)
    anchor = fan_anchor(p)
    for a, b in edges(p):
        stencil_triangle(s, anchor, a, b, ox, oy)
    return s


def cover(s, rule):
    """the cover pass: coverage 1 where the stencil fills under the rule"""
    cov = coverage_buffer(s.width, s.height)
    for i, v in enumerate(s.values):
        cov.values[i] = 1.0 if (v != 0 if rule == "nonzero" else v % 2 == 1) else 0.0
    return cov


def winding_mismatches(s, p):
    """pixels where the stencil and chapter 5's winding_at disagree"""
    n = 0
    for y in range(s.height):
        for x in range(s.width):
            if s.values[y * s.width + x] != winding_at(p, x + 0.5, y + 0.5):
                n += 1
    return n


# --------------------------------------------------------------------------
# §24.2 curves without flattening: Loop-Blinn
# --------------------------------------------------------------------------
def loop_blinn_uv(c, q):
    """(u, v) at q, interpolated from (0, 0), (1/2, 0), (1, 1) at the
    quadratic's three control points; none when the triangle is flat"""
    p0, p1, p2 = c.points
    det = cross(p1 - p0, p2 - p0)
    if det == 0:
        return None
    s = cross(q - p0, p2 - p0) / det
    t = cross(p1 - p0, q - p0) / det
    return (s / 2 + t, t, s)


def inside_curve(c, q):
    """q is between the quadratic and its chord: s > 0 and u^2 - v < 0"""
    uv = loop_blinn_uv(c, q)
    if uv is None:
        return False
    u, v, s = uv
    return s > 0 and u * u - v < 0


def curve_sign(c):
    p0, p1, p2 = c.points
    return 1 if cross(p1 - p0, p2 - p0) > 0 else -1


def loop_blinn_stencil(curves, anchor, w, h, ox=0.5, oy=0.5):
    """a stencil of closed quadratic contours with no flattening: the fan of
    chords from the anchor, plus, for each curve, its sign in every pixel
    whose sample point lies between the curve and its chord"""
    s = Stencil(w, h)
    for c in curves:
        stencil_triangle(s, anchor, c.points[0], c.points[2], ox, oy)
    for c in curves:
        p0, p1, p2 = c.points
        if cross(p1 - p0, p2 - p0) == 0:
            continue
        sg = curve_sign(c)
        x0 = max(0, math.floor(min(p0.x, p1.x, p2.x) - ox))
        x1 = min(w - 1, math.ceil(max(p0.x, p1.x, p2.x) - ox))
        y0 = max(0, math.floor(min(p0.y, p1.y, p2.y) - oy))
        y1 = min(h - 1, math.ceil(max(p0.y, p1.y, p2.y) - oy))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if inside_curve(c, point(x + ox, y + oy)):
                    s.values[y * w + x] += sg
                    s.fragments += 1
    return s


def glyph_stencil(font, name, m, w, h):
    """Loop-Blinn for a glyph: its quadratics through m, anchored at the
    first curve's start"""
    curves = glyph_curves(font, name, m)
    return loop_blinn_stencil(curves, curves[0].points[0], w, h)


# --------------------------------------------------------------------------
# §24.3 sampling instead of area
# --------------------------------------------------------------------------
PATTERNS = {
    1: [(0.5, 0.5)],
    4: [(0.375, 0.125), (0.875, 0.375), (0.125, 0.625), (0.625, 0.875)],
    16: [((k + 0.5) / 16, (((5 * k + 3) % 16) + 0.5) / 16) for k in range(16)],
    64: [((i + 0.5) / 8, (j + 0.5) / 8) for j in range(8) for i in range(8)],
}


def sample_pattern(n):
    return [point(x, y) for x, y in PATTERNS[n]]


def msaa_coverage(p, rule, w, h, n):
    """the fraction of the pattern's n samples in each pixel that the path
    fills, each sample one stencil"""
    cov = coverage_buffer(w, h)
    for ox, oy in PATTERNS[n]:
        s = stencil_buffer(p, w, h, ox, oy)
        on = cover(s, rule)
        for i in range(w * h):
            cov.values[i] += on.values[i]
    for i in range(w * h):
        cov.values[i] /= n
    return cov


def sliver():
    """a long thin wedge whose top edge climbs one pixel in forty"""
    return polygon(point(2, 10.3), point(78, 12.2), point(78, 30), point(2, 30))


# --------------------------------------------------------------------------
# §24.4 paint as a shader
# --------------------------------------------------------------------------
def shade_tile(paint, tx, ty, seed):
    """a paint evaluated at every pixel center of a 16 by 16 tile, the
    pixels visited in lcg_shuffle(256, seed) order (raster order when seed
    is none), answered in raster order"""
    from chapter10 import paint_at as _pa
    keys = [(tx * 16 + i % 16, ty * 16 + i // 16) for i in range(256)]
    visit = range(256) if seed is None else lcg_shuffle(256, seed)
    out = [None] * 256
    for i in visit:
        x, y = keys[i]
        out[i] = _pa(paint, x + 0.5, y + 0.5)
    return out


# --------------------------------------------------------------------------
# §24.5 the compute pipeline
# --------------------------------------------------------------------------
from chapter09 import Pixel, layer, over, flatten_layer
from chapter10 import paint_at
from chapter20 import (parse_xml, computed_style, initial_style, parse_transform, view_box_matrix,
                       shape_commands, build_path, commands_bounds, paint_server, find_by_id,
                       RENDERED, SHAPES, WHITE, TOLERANCE, render_svg)
from chapter10 import solid
from chapter04 import inverse, is_invertible
from chapter13 import stroke_to_path
from chapter15 import dash
from chapter21 import fill_bounds, _accumulate_sparse, SparseAccumulator, TILE

STACK_DEPTH = 2


class Fill:
    """one filled path of the scene, in device space"""
    __slots__ = ("path", "rule", "paint", "alpha", "clip")

    def __init__(self, path, rule, paint, alpha, clip):
        self.path, self.rule, self.paint, self.alpha, self.clip = path, rule, paint, alpha, clip


class Push:
    __slots__ = ("opacity", "clip")

    def __init__(self, opacity, clip):
        self.opacity, self.clip = opacity, clip


class Pop:
    __slots__ = ()


def _clip_parts(root, ref, ctm):
    """chapter 20's clip_coverage as a list of (device path, clip rule)"""
    el = find_by_id(root, ref[len("url(#"):-1])
    if el is None or el.name != "clipPath":
        return None
    m = ctm * parse_transform(el.attributes.get("transform"))
    base = computed_style(el, initial_style())
    parts = []
    for child in el.children:
        if child.name not in SHAPES:
            continue
        st = computed_style(child, base)
        cm = m * parse_transform(child.attributes.get("transform"))
        parts.append((build_path(shape_commands(child), cm, TOLERANCE), st.clip_rule))
    return parts


def _paint_for(root, value, cmds, ctm):
    if value is None:
        return None
    if isinstance(value, str):
        return paint_server(root, value, commands_bounds(cmds), ctm)
    return solid(value)


def _encode(root, out, el, parent, ctm):
    if el.name not in RENDERED:
        return
    style = computed_style(el, parent)
    ctm = ctm * parse_transform(el.attributes.get("transform"))
    clip = _clip_parts(root, style.clip_path, ctm) if style.clip_path is not None else None
    grouped = style.opacity < 1 or (clip is not None and el.name in ("svg", "g"))
    if grouped:
        out.append(Push(style.opacity, clip))
    inner = None if grouped else clip
    if el.name in ("svg", "g"):
        for child in el.children:
            _encode(root, out, child, style, ctm)
    else:
        cmds = shape_commands(el)
        if cmds and is_invertible(ctm):
            dev = build_path(cmds, ctm, TOLERANCE)
            fp = _paint_for(root, style.fill, cmds, ctm)
            if fp is not None and style.fill_opacity > 0:
                out.append(Fill(dev, style.fill_rule, fp, style.fill_opacity, inner))
            sp = _paint_for(root, style.stroke, cmds, ctm)
            if sp is not None and style.stroke_width > 0 and style.stroke_opacity > 0:
                user = transform_path(dev, inverse(ctm))
                if style.stroke_dasharray is not None:
                    user = dash(user, list(style.stroke_dasharray), style.stroke_dashoffset)
                outline = stroke_to_path(user, style.stroke_width, style.stroke_linecap,
                                         style.stroke_linejoin, style.stroke_miterlimit)
                out.append(Fill(transform_path(outline, ctm), "nonzero", sp, style.stroke_opacity, inner))
    if grouped:
        out.append(Pop())


def encode_svg(text, w, h):
    """chapter 20's walker, drawing nothing: the scene as a flat list of
    Fill, Push and Pop in document order"""
    root = parse_xml(text)
    m = view_box_matrix(root.attributes.get("viewBox"), root.attributes.get("preserveAspectRatio"), w, h)
    out = []
    _encode(root, out, root, initial_style(), m)
    return out


class Scene:
    """the scene's paths in one list, clips included, each a draw"""
    def __init__(self, commands, w, h):
        self.commands, self.width, self.height = commands, w, h
        self.cols, self.rows = -(-w // TILE), -(-h // TILE)
        self.draws = []                     # (path, rule)

        def draw_id(p, rule):
            self.draws.append((p, rule))
            return len(self.draws) - 1
        self.ops = []
        for c in commands:
            if isinstance(c, Fill):
                clip = [draw_id(p, r) for p, r in c.clip] if c.clip else None
                self.ops.append(("fill", draw_id(c.path, c.rule), c.paint, c.alpha, clip))
            elif isinstance(c, Push):
                clip = [draw_id(p, r) for p, r in c.clip] if c.clip else None
                self.ops.append(("push", c.opacity, clip))
            else:
                self.ops.append(("pop",))


def flatten_stage(scene):
    """stage 1: every draw's edges as segments (draw, a, b)"""
    return [(d, a, b) for d, (p, _) in enumerate(scene.draws) for a, b in edges(p)]


def bin_stage(scene, segments):
    """stage 2: every segment's chapter 7 deposits, each filed under the tile
    of its cell, in segment order: bins[(tx, ty)] is a list of (draw, x,
    row, area, cover)"""
    bins = {}
    for d, a, b in segments:
        acc = SparseAccumulator(scene.width, scene.height)
        acc.cells = _Recorder()
        _accumulate_sparse(acc, a, b)
        for (x, row), (area, cov) in acc.cells.log:
            bins.setdefault((x // TILE, row // TILE), []).append((d, x, row, area, cov))
    return bins


class _Recorder(dict):
    """a stand-in for the sparse accumulator's cells that records every
    deposit in order instead of summing"""
    def __init__(self):
        super().__init__()
        self.log = []

    def get(self, key, default=None):
        return None

    def __setitem__(self, key, value):
        self.log.append((key, tuple(value)))


class TileDraw:
    """what the coarse stage tells the fine stage about one draw in one
    tile: its class, and for a partial tile the running sum arriving on
    each row and the tile's cells"""
    __slots__ = ("kind", "arriving", "cells")

    def __init__(self, kind, arriving=None, cells=None):
        self.kind, self.arriving, self.cells = kind, arriving, cells


def coarse_stage(scene, bins):
    """stage 3: for every tile, the command list. A fill becomes ("fill",
    TileDraw, paint, alpha, [clip TileDraws]) unless its tile is empty;
    push and pop are copied to every tile. Reads the bins of the tiles to
    a tile's left, writes only its own list."""
    w, h = scene.width, scene.height
    # the sparse accumulator's cells for each draw, from the bins, summed in
    # segment order (bins list deposits in segment order within each tile)
    totals = [dict() for _ in scene.draws]
    # deposits of one draw into one cell come from that draw's segments in
    # order; bins preserve that order per tile, and a cell is in one tile
    for key, deps in bins.items():
        for d, x, row, area, cov in deps:
            c = totals[d].get((x, row))
            if c is None:
                totals[d][(x, row)] = [area, cov]
            else:
                c[0] += area
                c[1] += cov
    windows = [fill_bounds(p, w, h) for p, _ in scene.draws]
    classified = {}

    def tile_draw(d, tx, ty):
        key = (d, tx, ty)
        if key in classified:
            return classified[key]
        x0, y0, x1, y1 = windows[d]
        if x1 == 0 or not (x0 // TILE <= tx <= (x1 - 1) // TILE and y0 // TILE <= ty <= (y1 - 1) // TILE):
            classified[key] = TileDraw("empty")
            return classified[key]
        rule = scene.draws[d][1]
        cells = totals[d]
        rows = range(ty * TILE, min(h, (ty + 1) * TILE))
        arriving = []
        for row in rows:
            xs = sorted(x for (x, r) in cells if r == row and x < tx * TILE)
            running = 0.0
            for x in xs:
                running += cells[(x, row)][1]
            arriving.append(running)
        mine = {(x, r): v for (x, r), v in cells.items()
                if tx * TILE <= x < (tx + 1) * TILE and ty * TILE <= r < (ty + 1) * TILE}
        if any(v[0] != 0 or v[1] != 0 for v in mine.values()):
            td = TileDraw("partial", arriving, mine)
        else:
            n = round(arriving[0])
            if any(abs(a - n) > 0.000001 for a in arriving):
                td = TileDraw("partial", arriving, mine)
            else:
                td = TileDraw("solid" if apply_rule(n, rule) == 1 else "empty")
        classified[key] = td
        return td

    lists = {}
    for ty in range(scene.rows):
        for tx in range(scene.cols):
            cmds = []
            for op in scene.ops:
                if op[0] == "fill":
                    td = tile_draw(op[1], tx, ty)
                    if td.kind == "empty":
                        continue
                    clip = [(tile_draw(c, tx, ty), scene.draws[c][1]) for c in op[4]] if op[4] else None
                    cmds.append(("fill", td, scene.draws[op[1]][1], op[2], op[3], clip))
                elif op[0] == "push":
                    clip = [(tile_draw(c, tx, ty), scene.draws[c][1]) for c in op[2]] if op[2] else None
                    cmds.append(("push", op[1], clip))
                else:
                    cmds.append(("pop",))
            lists[(tx, ty)] = cull_groups(cmds)
    return lists


def cull_groups(cmds):
    """drop every push and its pop that have no fill between them in this
    tile, innermost first: an empty group composites nothing"""
    out = []
    marks = []                       # for each open push: (index in out, fills seen)
    for c in cmds:
        if c[0] == "push":
            marks.append([len(out), 0])
            out.append(c)
        elif c[0] == "pop":
            start, n = marks.pop()
            if n == 0:
                del out[start:]
            else:
                out.append(c)
                if marks:
                    marks[-1][1] += n
        else:
            out.append(c)
            if marks:
                marks[-1][1] += 1
    return out


def _resolve(td, rule, tx, ty, w, h):
    """a tile's coverage for one draw, row by row as chapter 21 resolves it"""
    x0, y0 = tx * TILE, ty * TILE
    x1, y1 = min(w, x0 + TILE), min(h, y0 + TILE)
    out = {}
    if td.kind == "solid":
        for y in range(y0, y1):
            for x in range(x0, x1):
                out[(x, y)] = 1.0
        return out
    if td.kind == "empty":
        for y in range(y0, y1):
            for x in range(x0, x1):
                out[(x, y)] = 0.0
        return out
    for j, y in enumerate(range(y0, y1)):
        running = td.arriving[j]
        for x in range(x0, x1):
            c = td.cells.get((x, y))
            area, cov = (c[0], c[1]) if c else (0.0, 0.0)
            out[(x, y)] = apply_rule(running + area, rule)
            running += cov
    return out


def _clip_values(parts, tx, ty, w, h):
    """the union of a clip's parts, 1 - (1 - a)(1 - b), in order from 0"""
    x0, y0 = tx * TILE, ty * TILE
    vals = {(x, y): 0.0 for y in range(y0, min(h, y0 + TILE)) for x in range(x0, min(w, x0 + TILE))}
    for td, rule in parts:
        cv = _resolve(td, rule, tx, ty, w, h)
        for k in vals:
            a, b = vals[k], cv[k]
            vals[k] = 1 - (1 - a) * (1 - b)
    return vals


class FineStats:
    __slots__ = ("tiles", "spills")

    def __init__(self):
        self.tiles = self.spills = 0


def fine_tile(scene, cmds, tx, ty, fs):
    """stage 4: one tile's commands into its own 16 by 16 block, a stack of
    blocks for groups; answers the block. Reads nothing but its list."""
    w, h = scene.width, scene.height
    x0, y0 = tx * TILE, ty * TILE
    keys = [(x, y) for y in range(y0, min(h, y0 + TILE)) for x in range(x0, min(w, x0 + TILE))]
    stack = [{k: Pixel(0, 0, 0, 0) for k in keys}]
    pushes = []
    for c in cmds:
        if c[0] == "fill":
            _, td, rule, paint, alpha, clip = c
            cov = _resolve(td, rule, tx, ty, w, h)
            cv = _clip_values(clip, tx, ty, w, h) if clip else None
            top = stack[-1]
            opaque = paint.kind == "solid" and alpha == 1 and cv is None
            col = paint.data["color"] if paint.kind == "solid" else None
            for k in keys:
                if td.kind == "solid" and opaque:
                    top[k] = Pixel(col.red, col.green, col.blue, 1.0)
                    continue
                v = cov[k]
                if cv is not None:
                    v = v * cv[k]
                kk = v * alpha
                if kk > 0:
                    cc = col if col is not None else paint_at(paint, k[0] + 0.5, k[1] + 0.5)
                    top[k] = over(Pixel(cc.red * kk, cc.green * kk, cc.blue * kk, kk), top[k])
        elif c[0] == "push":
            if len(stack) >= STACK_DEPTH:
                fs.spills += 1
            stack.append({k: Pixel(0, 0, 0, 0) for k in keys})
            pushes.append(c)
        else:
            _, opacity, clip = pushes.pop()
            g = stack.pop()
            if clip:
                cv = _clip_values(clip, tx, ty, w, h)
                g = {k: Pixel(p.r * cv[k], p.g * cv[k], p.b * cv[k], p.a * cv[k]) for k, p in g.items()}
            base = stack[-1]
            for k in keys:
                p = g[k]
                if p.a > 0:
                    base[k] = over(Pixel(p.r * opacity, p.g * opacity, p.b * opacity, p.a * opacity), base[k])
    fs.tiles += 1
    return stack[0]


def deposit_count(bins):
    return sum(len(v) for v in bins.values())


def command_count(lists):
    return sum(len(v) for v in lists.values())


def max_group_depth(commands):
    d = m = 0
    for c in commands:
        if isinstance(c, Push):
            d += 1
            m = max(m, d)
        elif isinstance(c, Pop):
            d -= 1
    return m


def lcg_shuffle(n, seed):
    """a permutation of 0..n-1, the same in every language: Fisher-Yates
    from the end, j = x mod (i + 1) with x <- (1103515245 x + 12345) mod
    2^31 drawn before each swap"""
    order = list(range(n))
    x = seed
    for i in range(n - 1, 0, -1):
        x = (1103515245 * x + 12345) % 2147483648
        j = x % (i + 1)
        order[i], order[j] = order[j], order[i]
    return order


def run_pipeline(scene, order_seed=None, fs=None):
    """all four stages; the fine stage visits tiles in raster order, or in
    lcg_shuffle(tile count, seed) order; answers the canvas over white"""
    fs = fs if fs is not None else FineStats()
    segs = flatten_stage(scene)
    bins = bin_stage(scene, segs)
    lists = coarse_stage(scene, bins)
    tiles = [(tx, ty) for ty in range(scene.rows) for tx in range(scene.cols)]
    if order_seed is not None:
        tiles = [tiles[i] for i in lcg_shuffle(len(tiles), order_seed)]
    l = layer(scene.width, scene.height)
    for tx, ty in tiles:
        block = fine_tile(scene, lists[(tx, ty)], tx, ty, fs)
        for (x, y), p in block.items():
            l.pixels[y * scene.width + x] = p
    return flatten_layer(l, WHITE)


def render_svg_gpu(text, w, h, seed=None):
    return run_pipeline(Scene(encode_svg(text, w, h), w, h), seed)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
PAPER = color(0.02, 0.02, 0.025)
INK = color(0.9, 0.55, 0.1)
CYAN = color(0.2, 0.75, 0.9)
MAGENTA = color(0.85, 0.2, 0.55)
PALE = color(0.92, 0.9, 0.82)


def winding_color(w):
    """paper for 0; orange mixed in by 0.45 for +1 and 0.9 for +2 or more;
    cyan by 0.6 for any negative winding"""
    if w == 0:
        return PAPER
    if w < 0:
        return mix(PAPER, CYAN, 0.6, True)
    return mix(PAPER, INK, 0.45 if w == 1 else 0.9, True)


def stencil_canvas(s):
    c = canvas(s.width, s.height)
    for i, v in enumerate(s.values):
        c.pixels[i] = winding_color(v)
    return c


def plate_star():
    """chapter 5's star moved by (19.5, 19.5) to the middle of 200 by 200"""
    return transform_path(star(), translation(19.5, 19.5))


def curve_terms(curves, w, h):
    """per pixel, the sum of the curve terms alone"""
    s = Stencil(w, h)
    for c in curves:
        p0, p1, p2 = c.points
        if cross(p1 - p0, p2 - p0) == 0:
            continue
        sg = curve_sign(c)
        for y in range(max(0, math.floor(min(p0.y, p1.y, p2.y) - 0.5)), min(h - 1, math.ceil(max(p0.y, p1.y, p2.y) - 0.5)) + 1):
            for x in range(max(0, math.floor(min(p0.x, p1.x, p2.x) - 0.5)), min(w - 1, math.ceil(max(p0.x, p1.x, p2.x) - 0.5)) + 1):
                if inside_curve(c, point(x + 0.5, y + 0.5)):
                    s.values[y * w + x] += sg
    return s


def plate_24():
    """left, the star's stencil in winding colours; right, Loop-Blinn's g,
    Roboto at 700 to the em from (-120, 420), so the panel holds its bowl:
    cyan mixed into paper by 0.55 where the curve terms add, magenta where
    they subtract, and then, where the winding is nonzero, orange mixed in
    by 0.6"""
    left = stencil_canvas(stencil_buffer(plate_star(), 200, 200))
    f = roboto()
    m = text_matrix(f, 700, -120, 420)
    curves = glyph_curves(f, glyph_name(f, ord("g")), m)
    s = loop_blinn_stencil(curves, curves[0].points[0], 200, 200)
    terms = curve_terms(curves, 200, 200)
    right = canvas(200, 200)
    for i in range(200 * 200):
        col = PAPER
        if terms.values[i] > 0:
            col = mix(col, CYAN, 0.55, True)
        elif terms.values[i] < 0:
            col = mix(col, MAGENTA, 0.55, True)
        if s.values[i] != 0:
            col = mix(col, INK, 0.6, True)
        right.pixels[i] = col
    return side_by_side(left, right)


def msaa_demo():
    """the sliver's corner, 24 by 12 pixels from (30, 4), five ways
    magnified 8 times, each 192 by 96, stacked: 1, 4, 16 and 64 samples,
    then chapter 7"""
    rows = []
    covs = [msaa_coverage(sliver(), "nonzero", 80, 40, n) for n in (1, 4, 16, 64)]
    covs.append(fill_path(sliver(), "nonzero", 80, 40))
    for cov in covs:
        c = canvas(24, 12)
        fill(c, PAPER)
        for y in range(12):
            for x in range(24):
                k = coverage_at(cov, x + 30, y + 4)
                if k > 0:
                    write_pixel(c, x, y, mix(PAPER, INK, k, True))
        rows.append(magnify(c, 8))
    out = canvas(192, 96 * len(rows))
    for i, r in enumerate(rows):
        out.pixels[i * 192 * 96:(i + 1) * 192 * 96] = r.pixels
    return out


def _tiger_scene():
    from pathlib import Path
    text = (Path(__file__).resolve().parents[1] / "chapter-20" / "tiger.svg").read_text()
    return Scene(encode_svg(text, 450, 450), 450, 450)


def tiger_assembly():
    """the tiger through the pipeline with its fine stage in
    lcg_shuffle(841, 2024) order, stopped after a quarter, a half, three
    quarters and all of its 841 tiles (210, 420, 630, 841), unfinished
    tiles left as paper; 2 by 2, 900 by 900"""
    sc = _tiger_scene()
    segs = flatten_stage(sc)
    bins = bin_stage(sc, segs)
    lists = coarse_stage(sc, bins)
    tiles = [(tx, ty) for ty in range(sc.rows) for tx in range(sc.cols)]
    order = [tiles[i] for i in lcg_shuffle(len(tiles), 2024)]
    fs = FineStats()
    blocks = {}
    out = canvas(900, 900)
    fill(out, PAPER)
    stops = [210, 420, 630, 841]
    done = 0
    for panel, stop in enumerate(stops):
        while done < stop:
            tx, ty = order[done]
            blocks[(tx, ty)] = fine_tile(sc, lists[(tx, ty)], tx, ty, fs)
            done += 1
        l = layer(450, 450)
        for blk in blocks.values():
            for (x, y), p in blk.items():
                l.pixels[y * 450 + x] = p
        c = flatten_layer(l, WHITE)
        ox, oy = (panel % 2) * 450, (panel // 2) * 450
        for y in range(450):
            for x in range(450):
                if (x // TILE, y // TILE) in blocks:
                    out.pixels[(y + oy) * 900 + x + ox] = c.pixels[y * 450 + x]
    return out


def spill_map():
    """the rose through the pipeline, beside one square per tile, magenta
    mixed into paper by 0.2 + 0.8 x spills / the most spills of any tile
    when the tile spilled, paper otherwise, each tile's 16 pixels inset by
    one as chapter 21's work map does; 810 by 400"""
    from pathlib import Path
    text = (Path(__file__).resolve().parents[1] / "chapter-20" / "rose.svg").read_text()
    sc = Scene(encode_svg(text, 400, 400), 400, 400)
    segs = flatten_stage(sc)
    lists = coarse_stage(sc, bin_stage(sc, segs))
    l = layer(400, 400)
    spills = {}
    for ty in range(sc.rows):
        for tx in range(sc.cols):
            fs = FineStats()
            blk = fine_tile(sc, lists[(tx, ty)], tx, ty, fs)
            spills[(tx, ty)] = fs.spills
            for (x, y), p in blk.items():
                l.pixels[y * 400 + x] = p
    rose = flatten_layer(l, WHITE)
    most = max(spills.values())
    out = canvas(810, 400)
    fill(out, PAPER)
    for y in range(400):
        for x in range(400):
            out.pixels[y * 810 + x] = rose.pixels[y * 400 + x]
            u, v = x % TILE, y % TILE
            n = spills[(x // TILE, y // TILE)]
            if u in (0, TILE - 1) or v in (0, TILE - 1) or n == 0:
                continue
            out.pixels[y * 810 + 410 + x] = mix(PAPER, MAGENTA, 0.2 + 0.8 * n / most, True)
    return out


RENDERS = {
    "plate-24": plate_24,
    "msaa-demo": msaa_demo,
    "spill-map": spill_map,
    "tiger-assembly": tiger_assembly,
}
