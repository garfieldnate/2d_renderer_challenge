"""
Chapter 20, Rendering SVG: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Nothing here draws a pixel a new way. The XML library hands over a tree;
the chapter hand-writes the four small languages hiding in its attributes
(path data, the transform list, style declarations and colours), turns
basic shapes into path commands, works out the viewBox matrix, and walks
the tree in document order: every shape is a path, flattened in device
space, filled through chapter 7, stroked through chapter 13 in its own
user space, painted with a chapter 10 paint (a gradient seen through a
matrix), clipped by multiplying coverage (chapter 12), and grouped into a
layer when it has an opacity (chapter 12 again). The result is flattened
over white paper.

The renders crop every fill to the path's device bounds, which is what
chapter 21 proves changes nothing; the book's walker fills the whole canvas.
"""

import math
import xml.etree.ElementTree as ET

from renderer import color, canvas, decode, pixel_at, write_pixel
from chapter02 import coverage_buffer, coverage_at, set_coverage, magnify
from chapter04 import point, matrix3, identity, translation, scaling, rotation, shearing, \
    inverse, determinant, is_invertible
from chapter05 import path, move_to, line_to, close, bounds
from chapter06 import transform_path
from chapter07 import fill_path, accumulator, accumulate, apply_rule
from chapter05 import edges
from chapter08 import cubic, quadratic, transform_curve, flatten_into_path, curve_bounds, arc
from chapter09 import Pixel, layer, over, flatten_layer
from chapter10 import (Paint, PAINT_KINDS, paint_at, solid, stop, linear_gradient,
                       radial_gradient)
from chapter12 import multiply_coverage
from chapter13 import stroke_to_path
from chapter15 import dash

CHAPTER = 20
FORMAT = "P6"

TOLERANCE = 0.1      # flattening tolerance in device pixels, as for type


# --------------------------------------------------------------------------
# §20.1 the document
# --------------------------------------------------------------------------
def _local(tag):
    return tag.rsplit("}", 1)[-1] if isinstance(tag, str) else ""


class Element:
    """a thin wrapper over the XML library's element: local name, attributes
    by name, children in document order"""
    __slots__ = ("name", "attributes", "children", "text")

    def __init__(self, e):
        self.name = _local(e.tag)
        self.attributes = {_local(k): v for k, v in e.attrib.items()}
        self.children = [Element(c) for c in e if isinstance(c.tag, str)]

    def __repr__(self):
        return "<%s %r>" % (self.name, self.attributes)


def parse_xml(text):
    """the document's root element"""
    if isinstance(text, bytes):
        text = text.decode("utf-8")
    return Element(ET.fromstring(text))


def attribute(el, name):
    return el.attributes.get(name)


def children(el):
    return el.children


def find_by_id(root, ident):
    """the element anywhere in the document whose id is ident, or none"""
    stack = [root]
    while stack:
        e = stack.pop(0)
        if e.attributes.get("id") == ident:
            return e
        stack[0:0] = e.children
    return None


# --------------------------------------------------------------------------
# §20.2 numbers
# --------------------------------------------------------------------------
WS = " \t\r\n"


def _skip(s, i):
    """skip whitespace, at most one comma, whitespace"""
    n = len(s)
    while i < n and s[i] in WS:
        i += 1
    if i < n and s[i] == ",":
        i += 1
        while i < n and s[i] in WS:
            i += 1
    return i


def read_number(s, i):
    """(value, next index) for the number starting at s[i], or (none, i) if
    there isn't one. sign, digits, a point, digits, an exponent: 1e2, -.5,
    +3., 1.5e-3. A second point ends the number: .5.5 is two numbers."""
    n, j = len(s), i
    if j < n and s[j] in "+-":
        j += 1
    digits = 0
    while j < n and s[j].isdigit():
        j += 1
        digits += 1
    if j < n and s[j] == ".":
        j += 1
        while j < n and s[j].isdigit():
            j += 1
            digits += 1
    if digits == 0:
        return None, i
    if j < n and s[j] in "eE":
        k = j + 1
        if k < n and s[k] in "+-":
            k += 1
        if k < n and s[k].isdigit():
            while k < n and s[k].isdigit():
                k += 1
            j = k
    return float(s[i:j]), j


def number_list(s):
    """every number in a list separated by whitespace and commas, stopping
    at the first thing that isn't one"""
    out, i = [], _skip(s, 0)
    while i < len(s):
        v, j = read_number(s, i)
        if v is None:
            break
        out.append(v)
        i = _skip(s, j)
    return tuple(out)


def read_flag(s, i):
    """an arc flag is one character, 0 or 1, and needs no separator"""
    if i < len(s) and s[i] in "01":
        return float(s[i]), i + 1
    return None, i


# --------------------------------------------------------------------------
# §20.3 path data
# --------------------------------------------------------------------------
class Command:
    """one absolute path command: op is M, L, C, Q, A or Z and args its
    numbers (A: rx, ry, angle in degrees, large flag, sweep flag, x, y)"""
    __slots__ = ("op", "args")

    def __init__(self, op, args):
        self.op, self.args = op, tuple(float(a) for a in args)

    def __repr__(self):
        return "%s%s" % (self.op, self.args)


ARITY = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7, "Z": 0}


def _read_args(s, i, op):
    """read one argument group for op, or (none, i) if it is incomplete"""
    vals = []
    for k in range(ARITY[op]):
        i = _skip(s, i)
        if op == "A" and k in (3, 4):
            v, i = read_flag(s, i)
        else:
            v, i = read_number(s, i)
        if v is None:
            return None, i
        vals.append(v)
    return vals, i


def path_commands(d):
    """the d attribute as a list of absolute commands in M L C Q A Z only.
    relative commands are made absolute, H and V become L, S and T become C
    and Q with the reflected control point, an argument group after the
    first repeats its command (after M, the repeats are L), and Z puts the
    current point back at the subpath's start. at the first thing that can't
    be read, the list so far is the answer."""
    out = []
    i, n = _skip(d, 0), len(d)
    cx = cy = sx = sy = 0.0
    prev_ctrl, prev_op = None, None
    cmd = None
    while i < n:
        ch = d[i]
        if ch.isalpha():
            if ch.upper() not in ARITY:
                break
            if cmd is None and ch.upper() != "M":
                break
            cmd = ch
            i = _skip(d, i + 1)
            if cmd.upper() == "Z":
                out.append(Command("Z", ()))
                cx, cy = sx, sy
                prev_op, prev_ctrl = "Z", None
                continue
        elif cmd is None or cmd.upper() == "Z":
            break
        op, rel = cmd.upper(), cmd.islower()
        vals, j = _read_args(d, i, op)
        if vals is None:
            break
        i = _skip(d, j)
        ox, oy = (cx, cy) if rel else (0.0, 0.0)
        if op == "M":
            cx, cy = vals[0] + ox, vals[1] + oy
            sx, sy = cx, cy
            out.append(Command("M", (cx, cy)))
            cmd = "l" if rel else "L"            # the repeats of M are L
            prev_ctrl = None
        elif op in "LHV":
            if op == "H":
                x, y = vals[0] + ox, cy
            elif op == "V":
                x, y = cx, vals[0] + oy
            else:
                x, y = vals[0] + ox, vals[1] + oy
            cx, cy = x, y
            out.append(Command("L", (x, y)))
            prev_ctrl = None
        elif op in "CS":
            if op == "C":
                x1, y1 = vals[0] + ox, vals[1] + oy
                x2, y2, x, y = vals[2] + ox, vals[3] + oy, vals[4] + ox, vals[5] + oy
            else:
                if prev_op in "CS" and prev_ctrl is not None:
                    x1, y1 = 2 * cx - prev_ctrl[0], 2 * cy - prev_ctrl[1]
                else:
                    x1, y1 = cx, cy
                x2, y2, x, y = vals[0] + ox, vals[1] + oy, vals[2] + ox, vals[3] + oy
            out.append(Command("C", (x1, y1, x2, y2, x, y)))
            prev_ctrl = (x2, y2)
            cx, cy = x, y
        elif op in "QT":
            if op == "Q":
                x1, y1, x, y = vals[0] + ox, vals[1] + oy, vals[2] + ox, vals[3] + oy
            else:
                if prev_op in "QT" and prev_ctrl is not None:
                    x1, y1 = 2 * cx - prev_ctrl[0], 2 * cy - prev_ctrl[1]
                else:
                    x1, y1 = cx, cy
                x, y = vals[0] + ox, vals[1] + oy
            out.append(Command("Q", (x1, y1, x, y)))
            prev_ctrl = (x1, y1)
            cx, cy = x, y
        elif op == "A":
            x, y = vals[5] + ox, vals[6] + oy
            out.append(Command("A", (abs(vals[0]), abs(vals[1]), vals[2], vals[3], vals[4], x, y)))
            cx, cy = x, y
            prev_ctrl = None
        prev_op = op
    return out


def arc_cubics(x1, y1, rx, ry, degrees, large, sweep, x2, y2):
    """an SVG arc as cubics, one per quarter turn or less: chapter 8's
    center conversion, then each piece's handles 4/3 tan(delta/4) of a
    radius long along the tangents. the first cubic starts exactly at
    (x1, y1) and the last ends exactly at (x2, y2). coincident endpoints
    have no arc and answer an empty list; a zero radius answers one straight
    cubic, since SVG draws a line there."""
    if x1 == x2 and y1 == y2:
        return []
    if rx == 0 or ry == 0:
        return [cubic(point(x1, y1), point(x1 + (x2 - x1) / 3, y1 + (y2 - y1) / 3),
                      point(x1 + 2 * (x2 - x1) / 3, y1 + 2 * (y2 - y1) / 3), point(x2, y2))]
    a = arc(x1, y1, rx, ry, math.radians(degrees), large != 0, sweep != 0, x2, y2)
    n = max(1, int(math.ceil(abs(a.delta) / (math.pi / 2) - 1e-6)))
    step = a.delta / n
    k = 4.0 / 3.0 * math.tan(step / 4)
    cphi, sphi = math.cos(a.phi), math.sin(a.phi)

    def on_ellipse(u, v):
        ex, ey = a.rx * u, a.ry * v
        return point(a.cx + cphi * ex - sphi * ey, a.cy + sphi * ex + cphi * ey)

    out = []
    for i in range(n):
        t0 = a.theta1 + step * i
        t1 = t0 + step
        c0, s0, c1, s1 = math.cos(t0), math.sin(t0), math.cos(t1), math.sin(t1)
        p0 = point(x1, y1) if i == 0 else on_ellipse(c0, s0)
        p3 = point(x2, y2) if i == n - 1 else on_ellipse(c1, s1)
        out.append(cubic(p0, on_ellipse(c0 - k * s0, s0 + k * c0),
                         on_ellipse(c1 + k * s1, s1 - k * c1), p3))
    return out


def _curves_of(cmds):
    """walk the commands keeping the current point: yield ("move", p),
    ("line", p), ("curve", c) and ("close", None) in user space"""
    cx = cy = sx = sy = 0.0
    for c in cmds:
        a = c.args
        if c.op == "M":
            cx, cy = sx, sy = a[0], a[1]
            yield "move", point(cx, cy)
        elif c.op == "L":
            cx, cy = a[0], a[1]
            yield "line", point(cx, cy)
        elif c.op == "C":
            yield "curve", cubic(point(cx, cy), point(a[0], a[1]), point(a[2], a[3]), point(a[4], a[5]))
            cx, cy = a[4], a[5]
        elif c.op == "Q":
            yield "curve", quadratic(point(cx, cy), point(a[0], a[1]), point(a[2], a[3]))
            cx, cy = a[2], a[3]
        elif c.op == "A":
            for k in arc_cubics(cx, cy, a[0], a[1], a[2], a[3], a[4], a[5], a[6]):
                yield "curve", k
            cx, cy = a[5], a[6]
        elif c.op == "Z":
            cx, cy = sx, sy
            yield "close", None


def build_path(cmds, m, tolerance):
    """a chapter 5 path in device space: every point through m, every curve
    through m and then flattened (chapter 8's order). a subpath that is
    only its moveto is dropped."""
    p = path()

    def drop_lone():
        if p.subpaths and len(p.subpaths[-1].points) == 1 and not p.subpaths[-1].closed:
            p.subpaths.pop()

    for kind, v in _curves_of(cmds):
        if kind == "move":
            drop_lone()
            move_to(p, m * v)
        elif kind == "line":
            line_to(p, m * v)
        elif kind == "curve":
            flatten_into_path(p, transform_curve(v, m), tolerance)
        else:
            close(p)
    drop_lone()
    return p


def commands_bounds(cmds):
    """the tight bounds of the geometry in user space: endpoints, and chapter
    8's curve_bounds of every curve. (0, 0, 0, 0) when there is none."""
    xs, ys = [], []
    for kind, v in _curves_of(cmds):
        if kind in ("move", "line"):
            xs.append(v.x)
            ys.append(v.y)
        elif kind == "curve":
            b = curve_bounds(v)
            xs += [b[0], b[2]]
            ys += [b[1], b[3]]
    if not xs:
        return (0.0, 0.0, 0.0, 0.0)
    return (min(xs), min(ys), max(xs), max(ys))


# --------------------------------------------------------------------------
# §20.4 the transform attribute
# --------------------------------------------------------------------------
def parse_transform(s):
    """a transform list as one matrix: each function's matrix multiplied in
    left to right, so the rightmost applies to a point first. angles are in
    degrees. an attribute that doesn't parse is the identity."""
    if s is None:
        return identity()
    m = identity()
    i, n = _skip(s, 0), len(s)
    while i < n:
        j = i
        while j < n and s[j].isalpha():
            j += 1
        name = s[i:j]
        while j < n and s[j] in WS:
            j += 1
        if not name or j >= n or s[j] != "(":
            return identity()
        k = s.find(")", j)
        if k < 0:
            return identity()
        inner = s[j + 1:k]
        args = number_list(inner)
        if not _all_numbers(inner, len(args)):
            return identity()
        t = _transform_function(name, args)
        if t is None:
            return identity()
        m = m * t
        i = _skip(s, k + 1)
    return m


def _all_numbers(inner, count):
    """true when inner holds exactly count numbers and nothing else"""
    i, got = _skip(inner, 0), 0
    while i < len(inner):
        v, j = read_number(inner, i)
        if v is None:
            return False
        got += 1
        i = _skip(inner, j)
    return got == count


def _transform_function(name, a):
    if name == "matrix" and len(a) == 6:
        return matrix3(a[0], a[2], a[4], a[1], a[3], a[5], 0, 0, 1)
    if name == "translate" and len(a) in (1, 2):
        return translation(a[0], a[1] if len(a) == 2 else 0.0)
    if name == "scale" and len(a) in (1, 2):
        return scaling(a[0], a[1] if len(a) == 2 else a[0])
    if name == "rotate" and len(a) == 1:
        return rotation(math.radians(a[0]))
    if name == "rotate" and len(a) == 3:
        return translation(a[1], a[2]) * rotation(math.radians(a[0])) * translation(-a[1], -a[2])
    if name == "skewX" and len(a) == 1:
        return shearing(math.tan(math.radians(a[0])), 0)
    if name == "skewY" and len(a) == 1:
        return shearing(0, math.tan(math.radians(a[0])))
    return None


# --------------------------------------------------------------------------
# §20.5 colours and the style cascade
# --------------------------------------------------------------------------
NAMED_COLORS = {
    "black": (0, 0, 0), "silver": (192, 192, 192), "gray": (128, 128, 128),
    "white": (255, 255, 255), "maroon": (128, 0, 0), "red": (255, 0, 0),
    "purple": (128, 0, 128), "fuchsia": (255, 0, 255), "green": (0, 128, 0),
    "lime": (0, 255, 0), "olive": (128, 128, 0), "yellow": (255, 255, 0),
    "navy": (0, 0, 128), "blue": (0, 0, 255), "teal": (0, 128, 128),
    "aqua": (0, 255, 255), "orange": (255, 165, 0),
}


def _byte_color(r, g, b):
    return color(decode(r / 255), decode(g / 255), decode(b / 255))


def parse_color(s):
    """a colour value as linear light: #rgb, #rrggbb, rgb(r, g, b) with
    integers or percentages, or one of the seventeen names. the file's
    numbers are sRGB, so each is decoded. anything else is none."""
    s = s.strip()
    low = s.lower()
    if low in NAMED_COLORS:
        return _byte_color(*NAMED_COLORS[low])
    if low.startswith("#"):
        h = low[1:]
        if not all(c in "0123456789abcdef" for c in h):
            return None
        if len(h) == 3:
            return _byte_color(*(int(c * 2, 16) for c in h))
        if len(h) == 6:
            return _byte_color(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
        return None
    if low.startswith("rgb(") and low.endswith(")"):
        parts = [p.strip() for p in low[4:-1].split(",")]
        if len(parts) != 3:
            return None
        vals = []
        for p in parts:
            pct = p.endswith("%")
            v, j = read_number(p[:-1] if pct else p, 0)
            if v is None or j != len(p) - (1 if pct else 0):
                return None
            v = v * 255 / 100 if pct else v
            vals.append(min(255.0, max(0.0, v)))
        return _byte_color(*vals)
    return None


# name -> (initial value, inherited)
PROPERTIES = {
    "fill": (color(0, 0, 0), True),
    "fill-opacity": (1.0, True),
    "fill-rule": ("nonzero", True),
    "stroke": (None, True),
    "stroke-width": (1.0, True),
    "stroke-opacity": (1.0, True),
    "stroke-linecap": ("butt", True),
    "stroke-linejoin": ("miter", True),
    "stroke-miterlimit": (4.0, True),
    "stroke-dasharray": (None, True),
    "stroke-dashoffset": (0.0, True),
    "clip-rule": ("nonzero", True),
    "opacity": (1.0, False),
    "clip-path": (None, False),
    "stop-color": (color(0, 0, 0), False),
}


class Style:
    """the computed value of every property, reachable with - as _"""
    def __init__(self, values):
        self.values = dict(values)

    def __getattr__(self, name):
        try:
            return self.__dict__["values"][name.replace("_", "-")]
        except KeyError:
            raise AttributeError(name)

    def __repr__(self):
        return "style(%r)" % (self.values,)


def initial_style():
    return Style({k: v for k, (v, _) in PROPERTIES.items()})


def _number_value(s):
    s = s.strip()
    if s.endswith("px"):
        s = s[:-2]
    v, j = read_number(s, 0)
    if v is None or j != len(s):
        return None
    return v


def _url(s):
    s = s.strip()
    if s.startswith("url(") and ")" in s:
        return s[:s.index(")") + 1].replace(" ", "")
    return None


def parse_property(name, value):
    """a declared value as a computed one, or the marker INVALID when the
    declaration should be ignored"""
    v = value.strip()
    if name in ("fill", "stroke"):
        if v == "none":
            return None
        if v.startswith("url("):
            u = _url(v)
            return u if u else INVALID
        c = parse_color(v)
        return c if c is not None else INVALID
    if name == "stop-color":
        c = parse_color(v)
        return c if c is not None else INVALID
    if name in ("fill-opacity", "stroke-opacity", "opacity"):
        n = _number_value(v)
        return INVALID if n is None else min(1.0, max(0.0, n))
    if name == "stroke-width":
        n = _number_value(v)
        return INVALID if n is None or n < 0 else n
    if name == "stroke-miterlimit":
        n = _number_value(v)
        return INVALID if n is None or n < 1 else n
    if name == "stroke-dashoffset":
        n = _number_value(v)
        return INVALID if n is None else n
    if name == "stroke-dasharray":
        if v == "none":
            return None
        parts = [p for p in v.replace(",", " ").split()]
        nums = [_number_value(p) for p in parts]
        if not nums or any(x is None for x in nums):
            return INVALID
        return tuple(nums)
    if name in ("fill-rule", "clip-rule"):
        return v if v in ("nonzero", "evenodd") else INVALID
    if name == "stroke-linecap":
        return v if v in ("butt", "round", "square") else INVALID
    if name == "stroke-linejoin":
        return v if v in ("miter", "round", "bevel") else INVALID
    if name == "clip-path":
        if v == "none":
            return None
        u = _url(v)
        return u if u else INVALID
    return INVALID


INVALID = object()


def declarations(style_attr):
    """the name: value pairs of a style attribute, in order"""
    out = []
    for part in style_attr.split(";"):
        if ":" in part:
            k, v = part.split(":", 1)
            out.append((k.strip(), v.strip()))
    return out


def computed_style(el, parent):
    """the element's style: inherited properties start at the parent's value
    and the rest at their initial value; presentation attributes override
    that, and the style attribute's declarations override those. inherit
    takes the parent's value; a value that doesn't parse is ignored."""
    vals = {}
    for k, (init, inherited) in PROPERTIES.items():
        vals[k] = parent.values[k] if inherited else init
    decls = [(k, v) for k, v in el.attributes.items() if k in PROPERTIES]
    if "style" in el.attributes:
        decls += [(k, v) for k, v in declarations(el.attributes["style"]) if k in PROPERTIES]
    for k, v in decls:
        if v.strip() == "inherit":
            vals[k] = parent.values[k]
            continue
        pv = parse_property(k, v)
        if pv is not INVALID:
            vals[k] = pv
    return Style(vals)


# --------------------------------------------------------------------------
# §20.6 basic shapes
# --------------------------------------------------------------------------
def _num_attr(el, name, default=0.0):
    v = el.attributes.get(name)
    if v is None:
        return default
    n = _number_value(v)
    return default if n is None else n


def shape_commands(el):
    """the commands a basic shape stands for, per the SVG spec's equivalent
    paths. a shape that doesn't render (a zero or negative size) has none.
    path answers its d attribute."""
    name = el.name
    C = Command
    if name == "path":
        return path_commands(el.attributes.get("d", ""))
    if name == "rect":
        x, y = _num_attr(el, "x"), _num_attr(el, "y")
        w, h = _num_attr(el, "width"), _num_attr(el, "height")
        if w <= 0 or h <= 0:
            return []
        rx = el.attributes.get("rx")
        ry = el.attributes.get("ry")
        rx = _number_value(rx) if rx is not None else None
        ry = _number_value(ry) if ry is not None else None
        if rx is not None and rx < 0:
            rx = None
        if ry is not None and ry < 0:
            ry = None
        if rx is None and ry is None:
            rx = ry = 0.0
        elif rx is None:
            rx = ry
        elif ry is None:
            ry = rx
        rx, ry = min(rx, w / 2), min(ry, h / 2)
        if rx == 0 or ry == 0:
            return [C("M", (x, y)), C("L", (x + w, y)), C("L", (x + w, y + h)),
                    C("L", (x, y + h)), C("Z", ())]
        return [C("M", (x + rx, y)), C("L", (x + w - rx, y)),
                C("A", (rx, ry, 0, 0, 1, x + w, y + ry)), C("L", (x + w, y + h - ry)),
                C("A", (rx, ry, 0, 0, 1, x + w - rx, y + h)), C("L", (x + rx, y + h)),
                C("A", (rx, ry, 0, 0, 1, x, y + h - ry)), C("L", (x, y + ry)),
                C("A", (rx, ry, 0, 0, 1, x + rx, y)), C("Z", ())]
    if name in ("circle", "ellipse"):
        cx, cy = _num_attr(el, "cx"), _num_attr(el, "cy")
        if name == "circle":
            rx = ry = _num_attr(el, "r")
        else:
            rx, ry = _num_attr(el, "rx"), _num_attr(el, "ry")
        if rx <= 0 or ry <= 0:
            return []
        return [C("M", (cx + rx, cy)), C("A", (rx, ry, 0, 0, 1, cx, cy + ry)),
                C("A", (rx, ry, 0, 0, 1, cx - rx, cy)), C("A", (rx, ry, 0, 0, 1, cx, cy - ry)),
                C("A", (rx, ry, 0, 0, 1, cx + rx, cy)), C("Z", ())]
    if name == "line":
        return [C("M", (_num_attr(el, "x1"), _num_attr(el, "y1"))),
                C("L", (_num_attr(el, "x2"), _num_attr(el, "y2")))]
    if name in ("polyline", "polygon"):
        nums = number_list(el.attributes.get("points", ""))
        pairs = [(nums[i], nums[i + 1]) for i in range(0, len(nums) - 1, 2)]
        if not pairs:
            return []
        out = [C("M", pairs[0])] + [C("L", p) for p in pairs[1:]]
        if name == "polygon":
            out.append(C("Z", ()))
        return out
    return []


SHAPES = ("path", "rect", "circle", "ellipse", "line", "polyline", "polygon")


# --------------------------------------------------------------------------
# §20.7 viewBox and preserveAspectRatio
# --------------------------------------------------------------------------
def view_box_matrix(view_box, aspect, width, height):
    """the matrix from the viewBox's user space onto a width by height
    viewport. "none" stretches each axis on its own; otherwise one scale,
    the smaller of the two for meet and the larger for slice, and the box
    aligned by the xMin/xMid/xMax and YMin/YMid/YMax parts. no viewBox, or
    one that doesn't parse, is the identity."""
    if view_box is None:
        return identity()
    vb = number_list(view_box)
    if len(vb) != 4 or vb[2] <= 0 or vb[3] <= 0:
        return identity()
    mx, my, vw, vh = vb
    sx, sy = width / vw, height / vh
    words = (aspect or "xMidYMid meet").split()
    align = words[0] if words else "xMidYMid"
    if align == "none":
        return scaling(sx, sy) * translation(-mx, -my)
    slice_ = len(words) > 1 and words[1] == "slice"
    s = max(sx, sy) if slice_ else min(sx, sy)
    fx = {"xMin": 0.0, "xMid": 0.5, "xMax": 1.0}.get(align[0:4], 0.5)
    fy = {"YMin": 0.0, "YMid": 0.5, "YMax": 1.0}.get(align[4:8], 0.5)
    ox = (width - vw * s) * fx
    oy = (height - vh * s) * fy
    return translation(ox, oy) * scaling(s, s) * translation(-mx, -my)


# --------------------------------------------------------------------------
# §20.8 paint servers
# --------------------------------------------------------------------------
def transformed_paint(p, m):
    """a paint seen through a matrix: sampled at inverse(m) of the device
    point, so the gradient's own coordinates can be anything"""
    return Paint("transformed", paint=p, inverse=inverse(m))


def _sample_transformed(p, x, y):
    q = p.data["inverse"] * point(x, y)
    return paint_at(p.data["paint"], q.x, q.y)


PAINT_KINDS["transformed"] = _sample_transformed


def _length(el, name, default):
    """a gradient coordinate: a number, or a percentage as a fraction"""
    v = el.attributes.get(name)
    if v is None:
        return default
    v = v.strip()
    if v.endswith("%"):
        n, j = read_number(v[:-1], 0)
        return default if n is None or j != len(v) - 1 else n / 100
    n = _number_value(v)
    return default if n is None else n


def gradient_stops(el):
    """the stops of a gradient element: offsets as fractions clamped to
    [0, 1] and never less than the one before, colours from stop-color"""
    out, last = [], 0.0
    for s in el.children:
        if s.name != "stop":
            continue
        o = _length(s, "offset", 0.0)
        o = max(last, min(1.0, max(0.0, o)))
        last = o
        out.append(stop(o, computed_style(s, initial_style()).stop_color))
    return out


EXTENDS = {"pad": "pad", "reflect": "reflect", "repeat": "repeat"}


def paint_server(root, ref, bbox, ctm):
    """the chapter 10 paint a url(#id) names, in device space, or none when
    it names nothing paintable. objectBoundingBox (the default) puts the
    gradient's coordinates in the unit square of the shape's user-space
    bounds; userSpaceOnUse leaves them in user space. either way
    gradientTransform comes last, and the whole matrix is the element's
    transform times that."""
    ident = ref[len("url(#"):-1]
    el = find_by_id(root, ident)
    if el is None or el.name not in ("linearGradient", "radialGradient"):
        return None
    stops = gradient_stops(el)
    if not stops:
        return None
    if len(stops) == 1:
        return solid(stops[0][1])
    units = el.attributes.get("gradientUnits", "objectBoundingBox")
    m = ctm
    if units != "userSpaceOnUse":
        x0, y0, x1, y1 = bbox
        if x1 - x0 <= 0 or y1 - y0 <= 0:
            return None
        m = m * translation(x0, y0) * scaling(x1 - x0, y1 - y0)
    m = m * parse_transform(el.attributes.get("gradientTransform"))
    if not is_invertible(m):
        return None
    ext = EXTENDS.get(el.attributes.get("spreadMethod", "pad"), "pad")
    if el.name == "linearGradient":
        x1_, y1_ = _length(el, "x1", 0.0), _length(el, "y1", 0.0)
        x2_, y2_ = _length(el, "x2", 1.0), _length(el, "y2", 0.0)
        if x1_ == x2_ and y1_ == y2_:
            return solid(stops[-1][1])
        g = linear_gradient(point(x1_, y1_), point(x2_, y2_), stops, ext)
    else:
        cx, cy, r = _length(el, "cx", 0.5), _length(el, "cy", 0.5), _length(el, "r", 0.5)
        fx, fy = _length(el, "fx", cx), _length(el, "fy", cy)
        fr = _length(el, "fr", 0.0)
        if r <= 0:
            return solid(stops[-1][1])
        g = radial_gradient(point(fx, fy), fr, point(cx, cy), r, stops, ext)
    return transformed_paint(g, m)


# --------------------------------------------------------------------------
# §20.9 clips and groups
# --------------------------------------------------------------------------
def union_coverage(a, b):
    """two silhouettes together: 1 - (1 - a)(1 - b), the alpha of one over
    the other"""
    out = coverage_buffer(a.width, a.height)
    av, bv = a.values, b.values
    for i in range(a.width * a.height):
        out.values[i] = 1 - (1 - av[i]) * (1 - bv[i])
    return out


def clip_coverage(root, ref, ctm, w, h):
    """the coverage of a clipPath: the union of its shapes' fills, each with
    its own clip-rule, in the user space of the element that uses it (its
    ctm) times the clipPath's transform and the shape's. a reference to
    nothing clips nothing, which is none."""
    ident = ref[len("url(#"):-1]
    el = find_by_id(root, ident)
    if el is None or el.name != "clipPath":
        return None
    m = ctm * parse_transform(el.attributes.get("transform"))
    base = computed_style(el, initial_style())
    cov = coverage_buffer(w, h)
    for child in el.children:
        if child.name not in SHAPES:
            continue
        st = computed_style(child, base)
        cm = m * parse_transform(child.attributes.get("transform"))
        p = build_path(shape_commands(child), cm, TOLERANCE)
        cov = union_coverage(cov, _fill(p, st.clip_rule, w, h))
    return cov


def mask_layer(l, cov):
    """every premultiplied pixel scaled by the coverage under it: a layer
    clipped"""
    out = layer(l.width, l.height)
    for i in range(l.width * l.height):
        k = cov.values[i]
        p = l.pixels[i]
        out.pixels[i] = Pixel(p.r * k, p.g * k, p.b * k, p.a * k)
    return out


def composite_group(group, base, opacity):
    """source-over of a finished group onto the layer below, every pixel
    scaled by opacity first: chapter 12's pop_group_with_opacity, done in
    place, and byte-identical to it"""
    for i in range(base.width * base.height):
        g = group.pixels[i]
        if g.a > 0:
            src = Pixel(g.r * opacity, g.g * opacity, g.b * opacity, g.a * opacity)
            base.pixels[i] = over(src, base.pixels[i])


def draw_coverage(l, cov, paint, alpha):
    """paint through coverage into a layer: at each pixel with coverage the
    paint's colour at the pixel center, at alpha coverage times alpha,
    source-over what is there"""
    for y in range(l.height):
        for x in range(l.width):
            k = coverage_at(cov, x, y) * alpha
            if k > 0:
                c = paint_at(paint, x + 0.5, y + 0.5)
                i = y * l.width + x
                l.pixels[i] = over(Pixel(c.red * k, c.green * k, c.blue * k, k), l.pixels[i])


# --------------------------------------------------------------------------
# §20.10 the walker
# --------------------------------------------------------------------------
class Context:
    """what the walk carries: the document (for references), the canvas
    size, and the layer being drawn into"""
    def __init__(self, root, w, h):
        self.root, self.w, self.h = root, w, h


def _fill(p, rule, w, h):
    """chapter 7's fill, cropped to the path's device bounds. identical to
    fill_path(p, rule, w, h), which chapter 21 proves; the book's walker
    uses fill_path."""
    return fill_path_cropped(p, rule, w, h)


class CroppedCoverage:
    """a coverage buffer that only stores a rectangle of the canvas and
    reads 0 elsewhere, with coverage_at-compatible values access"""
    __slots__ = ("width", "height", "x0", "y0", "cw", "ch", "vals")

    def __init__(self, w, h, x0, y0, cw, ch):
        self.width, self.height, self.x0, self.y0, self.cw, self.ch = w, h, x0, y0, cw, ch
        self.vals = [0.0] * (cw * ch)

    @property
    def values(self):
        out = [0.0] * (self.width * self.height)
        for j in range(self.ch):
            row = (self.y0 + j) * self.width + self.x0
            out[row:row + self.cw] = self.vals[j * self.cw:(j + 1) * self.cw]
        return out


def fill_path_cropped(p, rule, w, h):
    b = bounds(p)
    x0 = max(0, int(math.floor(b[0])))
    y0 = max(0, int(math.floor(b[1])))
    x1 = min(w, int(math.floor(b[2])) + 1)
    y1 = min(h, int(math.floor(b[3])) + 1)
    if not p.subpaths or x1 <= x0 or y1 <= y0:
        return CroppedCoverage(w, h, 0, 0, 0, 0)
    cw, ch = x1 - x0, y1 - y0
    acc = accumulator(w, ch)          # full width so deposits land in the same cells
    for a, b2 in edges(p):
        accumulate(acc, point(a.x, a.y - y0), point(b2.x, b2.y - y0))
    cov = CroppedCoverage(w, h, x0, y0, cw, ch)
    for row in range(ch):
        running = 0.0
        base = row * w
        for x in range(x0, x1):
            i = base + x
            wv = running + acc.area[i]
            running += acc.cover[i]
            if x >= x0:
                cov.vals[row * cw + x - x0] = apply_rule(wv, rule)
    return cov


def _cov_mul(a, b):
    """multiply a (possibly cropped) coverage by a full clip buffer"""
    if b is None:
        return a
    out = coverage_buffer(a.width, a.height)
    av = a.values
    for i in range(a.width * a.height):
        out.values[i] = av[i] * b.values[i]
    return out


def _draw(l, cov, paint, alpha):
    if isinstance(cov, CroppedCoverage):
        for j in range(cov.ch):
            y = cov.y0 + j
            for i in range(cov.cw):
                k = cov.vals[j * cov.cw + i] * alpha
                if k > 0:
                    x = cov.x0 + i
                    c = paint_at(paint, x + 0.5, y + 0.5)
                    idx = y * l.width + x
                    l.pixels[idx] = over(Pixel(c.red * k, c.green * k, c.blue * k, k), l.pixels[idx])
    else:
        draw_coverage(l, cov, paint, alpha)


def _paint_for(ctx, value, cmds, ctm):
    if value is None:
        return None
    if isinstance(value, str):
        return paint_server(ctx.root, value, commands_bounds(cmds), ctm)
    return solid(value)


def draw_shape(ctx, l, el, style, ctm, clip):
    """fill, then stroke. the fill is the device path through chapter 7; the
    stroke is built in user space (the device path taken back through the
    inverse of the ctm, dashed there, stroked there by chapter 13) and the
    outline brought forward through the ctm, so a squashed transform squashes
    the pen too"""
    cmds = shape_commands(el)
    if not cmds or not is_invertible(ctm):
        return
    dev = build_path(cmds, ctm, TOLERANCE)
    fill_paint = _paint_for(ctx, style.fill, cmds, ctm)
    if fill_paint is not None and style.fill_opacity > 0:
        cov = _cov_mul(_fill(dev, style.fill_rule, ctx.w, ctx.h), clip)
        _draw(l, cov, fill_paint, style.fill_opacity)
    stroke_paint = _paint_for(ctx, style.stroke, cmds, ctm)
    if stroke_paint is not None and style.stroke_width > 0 and style.stroke_opacity > 0:
        user = transform_path(dev, inverse(ctm))
        if style.stroke_dasharray is not None:
            user = dash(user, list(style.stroke_dasharray), style.stroke_dashoffset)
        outline = stroke_to_path(user, style.stroke_width, style.stroke_linecap,
                                 style.stroke_linejoin, style.stroke_miterlimit)
        cov = _cov_mul(_fill(transform_path(outline, ctm), "nonzero", ctx.w, ctx.h), clip)
        _draw(l, cov, stroke_paint, style.stroke_opacity)


RENDERED = ("svg", "g") + SHAPES


def render_element(ctx, l, el, parent_style, ctm):
    """draw one element and everything under it into layer l, in document
    order. an element with an opacity below 1, or a group with a clip-path,
    draws into a fresh layer that is clipped, faded and composited back."""
    if el.name not in RENDERED:
        return
    style = computed_style(el, parent_style)
    ctm = ctm * parse_transform(el.attributes.get("transform"))
    clip = None
    if style.clip_path is not None:
        clip = clip_coverage(ctx.root, style.clip_path, ctm, ctx.w, ctx.h)
    grouped = style.opacity < 1 or (clip is not None and el.name in ("svg", "g"))
    target = layer(ctx.w, ctx.h) if grouped else l
    if el.name in ("svg", "g"):
        for child in el.children:
            render_element(ctx, target, child, style, ctm)
    else:
        draw_shape(ctx, target, el, style, ctm, None if grouped else clip)
    if grouped:
        if clip is not None:
            target = mask_layer(target, clip)
        composite_group(target, l, style.opacity)


WHITE = color(1, 1, 1)


def render_svg(text, width, height):
    """an SVG document drawn onto a width by height canvas of white paper:
    the root's viewBox mapped onto the canvas, then every element in
    document order"""
    root = parse_xml(text)
    ctx = Context(root, width, height)
    l = layer(width, height)
    m = view_box_matrix(root.attributes.get("viewBox"), root.attributes.get("preserveAspectRatio"),
                        width, height)
    render_element(ctx, l, root, initial_style(), m)
    return flatten_layer(l, WHITE)


# --------------------------------------------------------------------------
# the renders
# --------------------------------------------------------------------------
def _svg(name):
    from pathlib import Path
    return (Path(__file__).resolve().parents[1] / "chapter-20" / name).read_text()


PAPER = color(0.02, 0.02, 0.025)
ASPECT_SVG = ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 80' preserveAspectRatio='%s'>"
              "<rect width='60' height='80' fill='#f4d8a8'/>"
              "<circle cx='30' cy='26' r='14' fill='#e8553a'/>"
              "<polygon points='0,80 22,44 36,62 44,52 60,80' fill='#3b5b7a'/>"
              "<rect x='1' y='1' width='58' height='78' fill='none' stroke='#1a1a1a' stroke-width='2'/>"
              "</svg>")
ASPECTS = ["none", "xMinYMid meet", "xMidYMid meet", "xMaxYMid meet", "xMidYMid slice"]


def aspect_demo():
    """one portrait drawing in five landscape viewports, one per
    preserveAspectRatio, side by side on dark paper"""
    c = canvas(660, 110)
    for y in range(110):
        for x in range(660):
            write_pixel(c, x, y, PAPER)
    for k, aspect in enumerate(ASPECTS):
        panel = render_svg(ASPECT_SVG % aspect, 120, 90)
        ox = 10 + k * 130
        for y in range(90):
            for x in range(120):
                write_pixel(c, ox + x, 10 + y, pixel_at(panel, x, y))
    return c


def harbor():
    return render_svg(_svg("harbor.svg"), 480, 320)


def rose():
    return render_svg(_svg("rose.svg"), 400, 400)


def tiger():
    return render_svg(_svg("tiger.svg"), 450, 450)


def plate_20():
    return tiger()


RENDERS = {
    "aspect_demo": aspect_demo,
    "harbor": harbor,
    "rose": rose,
    "tiger": tiger,
}
