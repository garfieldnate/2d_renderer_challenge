#!/usr/bin/env python3
"""
Turn a TrueType font into the book's glyphs.json.

    ./tools/ttf_to_json.py reference/fonts/Roboto-Regular.ttf reference/chapter-16/roboto.json
    ./tools/ttf_to_json.py --arabic reference/fonts/DejaVuSans.ttf reference/chapter-19/dejavu-arabic.json

Author-side only: readers get the JSON, never the .ttf (parsing sfnt is
Appendix B). Reads head, maxp, hhea, hmtx, cmap (formats 4 and 12), loca,
glyf (simple and composite outlines), and GPOS pair positioning for the kern
section. Keeps a subset: the glyphs the codepoints in KEEP reach, every glyph
they reference as a component, and the ligatures GSUB's liga feature builds
from them, plus .notdef.

The schema (chapter 16 prints it):

  units_per_em, ascender, descender, line_gap   numbers, in font units
  cmap      { "65": "A", ... }                  codepoint -> glyph name
  glyphs    { name: { advance, contours, components } }
            contours   [ [ [x, y, on], ... ], ... ]   font units, y up
            components [ { glyph, transform: [a, b, c, d, dx, dy] }, ... ]
  kern      [ [left, right, value], ... ]       optional, chapter 18
  ligatures [ [ [component names...], result ], ... ]   optional, chapter 19
  joining   { "1603": "dual" | "right" | "none" | "transparent" }   optional, chapter 19:
            Unicode's joining type (ArabicShaping.txt) for each codepoint in cmap
  forms     { name: { "init": name, "medi": name, "fina": name } }  optional, chapter 19:
            GSUB's init/medi/fina single substitutions
  marks     { name: [class, x, y] }              optional, chapter 19: a mark glyph's
            anchor class ("above" or "below") and its own anchor, font units
  anchors   { name: { class: [x, y] } }          optional, chapter 19: a base glyph's
            anchor per class; a mark lands with its anchor on the base's

The --arabic profile keeps the Arabic letters, tatweel, the eight harakat, space,
the Arabic comma and question mark and the ASCII punctuation a mixed line needs,
every positional form GSUB reaches from them, the lam-alef ligatures (rlig and liga), and the mark-to-base anchors.
"""

import json
import struct
import sys

# the codepoints the book's chapters use: printable ASCII, Latin-1 letters
# (most are composites), and a few typographic marks
KEEP = list(range(0x20, 0x7F)) + list(range(0xC0, 0x100)) + [0x2018, 0x2019, 0x201C, 0x201D, 0x2013, 0x2014, 0x2026]

AGL = {
    0x20: "space", 0x21: "exclam", 0x22: "quotedbl", 0x23: "numbersign", 0x24: "dollar",
    0x25: "percent", 0x26: "ampersand", 0x27: "quotesingle", 0x28: "parenleft",
    0x29: "parenright", 0x2A: "asterisk", 0x2B: "plus", 0x2C: "comma", 0x2D: "hyphen",
    0x2E: "period", 0x2F: "slash", 0x3A: "colon", 0x3B: "semicolon", 0x3C: "less",
    0x3D: "equal", 0x3E: "greater", 0x3F: "question", 0x40: "at", 0x5B: "bracketleft",
    0x5C: "backslash", 0x5D: "bracketright", 0x5E: "asciicircum", 0x5F: "underscore",
    0x60: "grave", 0x7B: "braceleft", 0x7C: "bar", 0x7D: "braceright", 0x7E: "asciitilde",
    0xC0: "Agrave", 0xC1: "Aacute", 0xC2: "Acircumflex", 0xC3: "Atilde", 0xC4: "Adieresis",
    0xC5: "Aring", 0xC6: "AE", 0xC7: "Ccedilla", 0xC8: "Egrave", 0xC9: "Eacute",
    0xCA: "Ecircumflex", 0xCB: "Edieresis", 0xCC: "Igrave", 0xCD: "Iacute",
    0xCE: "Icircumflex", 0xCF: "Idieresis", 0xD0: "Eth", 0xD1: "Ntilde", 0xD2: "Ograve",
    0xD3: "Oacute", 0xD4: "Ocircumflex", 0xD5: "Otilde", 0xD6: "Odieresis", 0xD7: "multiply",
    0xD8: "Oslash", 0xD9: "Ugrave", 0xDA: "Uacute", 0xDB: "Ucircumflex", 0xDC: "Udieresis",
    0xDD: "Yacute", 0xDE: "Thorn", 0xDF: "germandbls", 0xE0: "agrave", 0xE1: "aacute",
    0xE2: "acircumflex", 0xE3: "atilde", 0xE4: "adieresis", 0xE5: "aring", 0xE6: "ae",
    0xE7: "ccedilla", 0xE8: "egrave", 0xE9: "eacute", 0xEA: "ecircumflex", 0xEB: "edieresis",
    0xEC: "igrave", 0xED: "iacute", 0xEE: "icircumflex", 0xEF: "idieresis", 0xF0: "eth",
    0xF1: "ntilde", 0xF2: "ograve", 0xF3: "oacute", 0xF4: "ocircumflex", 0xF5: "otilde",
    0xF6: "odieresis", 0xF7: "divide", 0xF8: "oslash", 0xF9: "ugrave", 0xFA: "uacute",
    0xFB: "ucircumflex", 0xFC: "udieresis", 0xFD: "yacute", 0xFE: "thorn", 0xFF: "ydieresis",
    0x2018: "quoteleft", 0x2019: "quoteright", 0x201C: "quotedblleft", 0x201D: "quotedblright",
    0x2013: "endash", 0x2014: "emdash", 0x2026: "ellipsis",
    0xB4: "acute", 0xA8: "dieresis", 0xB8: "cedilla", 0x2C6: "circumflex", 0x2DC: "tilde",
    0x2DA: "ring", 0x2C7: "caron", 0x2D8: "breve", 0x2D9: "dotaccent", 0x2DD: "hungarumlaut",
    0x2DB: "ogonek", 0xAF: "macron", 0x301: "acutecomb", 0x300: "gravecomb", 0x303: "tildecomb",
    0x308: "dieresiscomb", 0x302: "circumflexcomb", 0x30A: "ringcomb", 0x327: "cedillacomb",
}


class Font:
    def __init__(self, data):
        self.d = data
        n = struct.unpack(">H", data[4:6])[0]
        self.tables = {}
        for i in range(n):
            tag, _, off, ln = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
            self.tables[tag.decode("latin-1")] = (off, ln)
        head = self.tables["head"][0]
        self.upem = struct.unpack(">H", data[head + 18:head + 20])[0]
        self.long_loca = struct.unpack(">h", data[head + 50:head + 52])[0] != 0
        maxp = self.tables["maxp"][0]
        self.num_glyphs = struct.unpack(">H", data[maxp + 4:maxp + 6])[0]
        hhea = self.tables["hhea"][0]
        self.ascender, self.descender, self.line_gap = struct.unpack(">hhh", data[hhea + 4:hhea + 10])
        self.num_hmetrics = struct.unpack(">H", data[hhea + 34:hhea + 36])[0]
        self.cmap = self.read_cmap()

    def u16(self, o):
        return struct.unpack(">H", self.d[o:o + 2])[0]

    def s16(self, o):
        return struct.unpack(">h", self.d[o:o + 2])[0]

    def u32(self, o):
        return struct.unpack(">I", self.d[o:o + 4])[0]

    # --- horizontal metrics
    def advance(self, gid):
        hmtx = self.tables["hmtx"][0]
        i = min(gid, self.num_hmetrics - 1)
        return self.u16(hmtx + 4 * i)

    # --- cmap: prefer a format 12 table, else format 4
    def read_cmap(self):
        base = self.tables["cmap"][0]
        n = self.u16(base + 2)
        subtables = []
        for i in range(n):
            pid, eid, off = struct.unpack(">HHI", self.d[base + 4 + 8 * i:base + 12 + 8 * i])
            subtables.append((pid, eid, base + off, self.u16(base + off)))
        best = None
        for st in subtables:
            if st[3] == 12:
                best = st
        if best is None:
            for st in subtables:
                if st[3] == 4 and st[0] == 3:
                    best = st
        if best is None:
            for st in subtables:
                if st[3] == 4:
                    best = st
        pid, eid, off, fmt = best
        m = {}
        if fmt == 12:
            ngroups = self.u32(off + 12)
            for g in range(ngroups):
                s, e, gid = struct.unpack(">III", self.d[off + 16 + 12 * g:off + 28 + 12 * g])
                for c in range(s, e + 1):
                    m[c] = gid + (c - s)
        else:
            segx2 = self.u16(off + 6)
            seg = segx2 // 2
            ends = off + 14
            starts = ends + segx2 + 2
            deltas = starts + segx2
            ranges = deltas + segx2
            for i in range(seg):
                end, start = self.u16(ends + 2 * i), self.u16(starts + 2 * i)
                delta, ro = self.s16(deltas + 2 * i), self.u16(ranges + 2 * i)
                for c in range(start, min(end, 0xFFFE) + 1):
                    if ro == 0:
                        gid = (c + delta) & 0xFFFF
                    else:
                        addr = ranges + 2 * i + ro + 2 * (c - start)
                        gid = self.u16(addr)
                        if gid:
                            gid = (gid + delta) & 0xFFFF
                    if gid:
                        m[c] = gid
        return m

    # --- glyf
    def glyph_offset(self, gid):
        loca = self.tables["loca"][0]
        if self.long_loca:
            return self.u32(loca + 4 * gid), self.u32(loca + 4 * gid + 4)
        return self.u16(loca + 2 * gid) * 2, self.u16(loca + 2 * gid + 2) * 2

    def outline(self, gid):
        """(contours, components): contours as lists of (x, y, on), in font
        units; components as (gid, [a, b, c, d, dx, dy])"""
        start, end = self.glyph_offset(gid)
        if end <= start:
            return [], []
        g = self.tables["glyf"][0] + start
        n = self.s16(g)
        if n >= 0:
            return self.simple(g, n), []
        return [], self.composite(g)

    def simple(self, g, n):
        ends = [self.u16(g + 10 + 2 * i) for i in range(n)]
        npts = ends[-1] + 1 if n else 0
        il = self.u16(g + 10 + 2 * n)
        p = g + 12 + 2 * n + il
        flags = []
        while len(flags) < npts:
            f = self.d[p]
            p += 1
            flags.append(f)
            if f & 8:
                rep = self.d[p]
                p += 1
                flags += [f] * rep
        xs, x = [], 0
        for f in flags:
            if f & 2:
                dx = self.d[p]
                p += 1
                x += dx if f & 16 else -dx
            elif not f & 16:
                x += self.s16(p)
                p += 2
            xs.append(x)
        ys, y = [], 0
        for f in flags:
            if f & 4:
                dy = self.d[p]
                p += 1
                y += dy if f & 32 else -dy
            elif not f & 32:
                y += self.s16(p)
                p += 2
            ys.append(y)
        contours, s = [], 0
        for e in ends:
            contours.append([[xs[i], ys[i], bool(flags[i] & 1)] for i in range(s, e + 1)])
            s = e + 1
        return contours

    def composite(self, g):
        p = g + 10
        out = []
        while True:
            flags, gid = self.u16(p), self.u16(p + 2)
            p += 4
            if flags & 1:                      # ARG_1_AND_2_ARE_WORDS
                a1, a2 = self.s16(p), self.s16(p + 2)
                p += 4
            else:
                a1, a2 = struct.unpack(">bb", self.d[p:p + 2])
                p += 2
            a = d = 1.0
            b = c = 0.0
            if flags & 8:                      # WE_HAVE_A_SCALE
                a = d = self.f2dot14(p)
                p += 2
            elif flags & 0x40:                 # WE_HAVE_AN_X_AND_Y_SCALE
                a, d = self.f2dot14(p), self.f2dot14(p + 2)
                p += 4
            elif flags & 0x80:                 # WE_HAVE_A_TWO_BY_TWO
                a, b, c, d = (self.f2dot14(p), self.f2dot14(p + 2),
                              self.f2dot14(p + 4), self.f2dot14(p + 6))
                p += 8
            if not flags & 2:                  # ARGS_ARE_XY_VALUES unset: point matching
                raise NotImplementedError("point-matched composite")
            out.append((gid, [a, b, c, d, float(a1), float(a2)]))
            if not flags & 0x20:               # MORE_COMPONENTS
                break
        return out

    def f2dot14(self, o):
        return self.s16(o) / 16384.0

    # --- GPOS pair positioning (the kern feature), lookup type 2
    def kern_pairs(self):
        if "GPOS" not in self.tables:
            return []
        base = self.tables["GPOS"][0]
        feat_list = base + self.u16(base + 6)
        lookup_list = base + self.u16(base + 8)
        wanted = set()
        nf = self.u16(feat_list)
        for i in range(nf):
            tag = self.d[feat_list + 2 + 6 * i:feat_list + 6 + 6 * i]
            off = self.u16(feat_list + 6 + 6 * i)
            if tag == b"kern":
                f = feat_list + off
                cnt = self.u16(f + 2)
                for k in range(cnt):
                    wanted.add(self.u16(f + 4 + 2 * k))
        pairs = {}
        for li in sorted(wanted):
            lk = lookup_list + self.u16(lookup_list + 2 + 2 * li)
            ltype, nsub = self.u16(lk), self.u16(lk + 4)
            for s in range(nsub):
                st = lk + self.u16(lk + 6 + 2 * s)
                t = ltype
                if t == 9:                     # extension
                    t = self.u16(st + 2)
                    st = st + self.u32(st + 4)
                if t == 2:
                    self.pair_subtable(st, pairs)
        return pairs

    def coverage(self, off):
        fmt = self.u16(off)
        out = []
        if fmt == 1:
            n = self.u16(off + 2)
            out = [self.u16(off + 4 + 2 * i) for i in range(n)]
        else:
            n = self.u16(off + 2)
            for i in range(n):
                s, e, si = struct.unpack(">HHH", self.d[off + 4 + 6 * i:off + 10 + 6 * i])
                out += list(range(s, e + 1))
        return out

    def class_def(self, off):
        fmt = self.u16(off)
        m = {}
        if fmt == 1:
            start, n = self.u16(off + 2), self.u16(off + 4)
            for i in range(n):
                m[start + i] = self.u16(off + 6 + 2 * i)
        else:
            n = self.u16(off + 2)
            for i in range(n):
                s, e, cl = struct.unpack(">HHH", self.d[off + 4 + 6 * i:off + 10 + 6 * i])
                for g in range(s, e + 1):
                    m[g] = cl
        return m

    @staticmethod
    def value_size(fmt):
        return bin(fmt).count("1") * 2

    def x_advance(self, off, fmt):
        """the XAdvance field of a value record, 0 if absent"""
        if not fmt & 4:
            return 0
        k = 0
        if fmt & 1:
            k += 2
        if fmt & 2:
            k += 2
        return self.s16(off + k)

    def pair_subtable(self, st, pairs):
        fmt = self.u16(st)
        cov = self.coverage(st + self.u16(st + 2))
        vf1, vf2 = self.u16(st + 4), self.u16(st + 6)
        sz = self.value_size(vf1) + self.value_size(vf2)
        if fmt == 1:
            n = self.u16(st + 8)
            for i in range(n):
                ps = st + self.u16(st + 10 + 2 * i)
                cnt = self.u16(ps)
                p = ps + 2
                for k in range(cnt):
                    second = self.u16(p)
                    v = self.x_advance(p + 2, vf1)
                    if v and (cov[i], second) not in pairs:
                        pairs[(cov[i], second)] = v
                    p += 2 + sz
        else:
            cd1 = self.class_def(st + self.u16(st + 8))
            cd2 = self.class_def(st + self.u16(st + 10))
            c1n, c2n = self.u16(st + 12), self.u16(st + 14)
            firsts = {}
            for g in cov:
                firsts.setdefault(cd1.get(g, 0), []).append(g)
            seconds = {}
            for g, cl in cd2.items():
                seconds.setdefault(cl, []).append(g)
            for a in range(c1n):
                for b in range(c2n):
                    rec = st + 16 + (a * c2n + b) * sz
                    v = self.x_advance(rec, vf1)
                    if v:
                        for g1 in firsts.get(a, []):
                            for g2 in seconds.get(b, []):
                                pairs.setdefault((g1, g2), v)

    # --- GSUB ligatures (the liga feature), lookup type 4
    def ligatures(self):
        if "GSUB" not in self.tables:
            return []
        base = self.tables["GSUB"][0]
        feat_list = base + self.u16(base + 6)
        lookup_list = base + self.u16(base + 8)
        wanted = set()
        nf = self.u16(feat_list)
        for i in range(nf):
            tag = self.d[feat_list + 2 + 6 * i:feat_list + 6 + 6 * i]
            off = self.u16(feat_list + 6 + 6 * i)
            if tag == b"liga":
                f = feat_list + off
                cnt = self.u16(f + 2)
                for k in range(cnt):
                    wanted.add(self.u16(f + 4 + 2 * k))
        out = []
        for li in sorted(wanted):
            lk = lookup_list + self.u16(lookup_list + 2 + 2 * li)
            ltype, nsub = self.u16(lk), self.u16(lk + 4)
            for s in range(nsub):
                st = lk + self.u16(lk + 6 + 2 * s)
                t = ltype
                if t == 7:
                    t = self.u16(st + 2)
                    st = st + self.u32(st + 4)
                if t != 4:
                    continue
                cov = self.coverage(st + self.u16(st + 2))
                n = self.u16(st + 4)
                for i in range(n):
                    ls = st + self.u16(st + 6 + 2 * i)
                    cnt = self.u16(ls)
                    for k in range(cnt):
                        lig = ls + self.u16(ls + 2 + 2 * k)
                        gid = self.u16(lig)
                        ncomp = self.u16(lig + 2)
                        rest = [self.u16(lig + 4 + 2 * j) for j in range(ncomp - 1)]
                        out.append(([cov[i]] + rest, gid))
        return out

    # --- generic: the lookups a feature tag references, by table and script
    def feature_lookups(self, table, tag, script=None):
        """(lookup type, subtable offset) pairs for every lookup the feature
        references; when a script is given, only the features that script's
        default language system lists. Extension lookups are unwrapped."""
        if table not in self.tables:
            return []
        base = self.tables[table][0]
        script_list = base + self.u16(base + 4)
        feat_list = base + self.u16(base + 6)
        lookup_list = base + self.u16(base + 8)
        ext = 7 if table == "GSUB" else 9
        allowed = None
        if script is not None:
            allowed = set()
            n = self.u16(script_list)
            for i in range(n):
                stag = self.d[script_list + 2 + 6 * i:script_list + 6 + 6 * i]
                if stag != script:
                    continue
                so = script_list + self.u16(script_list + 6 + 6 * i)
                dflt = self.u16(so)
                if dflt:
                    ls = so + dflt
                    cnt = self.u16(ls + 4)
                    allowed.update(self.u16(ls + 6 + 2 * k) for k in range(cnt))
        wanted = []
        nf = self.u16(feat_list)
        for i in range(nf):
            ftag = self.d[feat_list + 2 + 6 * i:feat_list + 6 + 6 * i]
            if ftag != tag or (allowed is not None and i not in allowed):
                continue
            f = feat_list + self.u16(feat_list + 6 + 6 * i)
            cnt = self.u16(f + 2)
            for k in range(cnt):
                li = self.u16(f + 4 + 2 * k)
                if li not in wanted:
                    wanted.append(li)
        out = []
        for li in wanted:
            lk = lookup_list + self.u16(lookup_list + 2 + 2 * li)
            ltype, nsub = self.u16(lk), self.u16(lk + 4)
            for s in range(nsub):
                st = lk + self.u16(lk + 6 + 2 * s)
                t = ltype
                if t == ext:
                    t = self.u16(st + 2)
                    st = st + self.u32(st + 4)
                out.append((t, st))
        return out

    # --- GSUB single substitution, lookup type 1 (init, medi, fina)
    def single_subst(self, tag, script):
        m = {}
        for t, st in self.feature_lookups("GSUB", tag, script):
            if t != 1:
                continue
            fmt = self.u16(st)
            cov = self.coverage(st + self.u16(st + 2))
            if fmt == 1:
                delta = self.s16(st + 4)
                for g in cov:
                    m.setdefault(g, (g + delta) & 0xFFFF)
            else:
                for i, g in enumerate(cov):
                    m.setdefault(g, self.u16(st + 6 + 2 * i))
        return m

    # --- GSUB ligature substitution, lookup type 4, for any feature tag
    def ligature_subst(self, tag, script):
        out = []
        for t, st in self.feature_lookups("GSUB", tag, script):
            if t != 4:
                continue
            cov = self.coverage(st + self.u16(st + 2))
            n = self.u16(st + 4)
            for i in range(n):
                ls = st + self.u16(st + 6 + 2 * i)
                cnt = self.u16(ls)
                for k in range(cnt):
                    lig = ls + self.u16(ls + 2 + 2 * k)
                    gid = self.u16(lig)
                    ncomp = self.u16(lig + 2)
                    rest = [self.u16(lig + 4 + 2 * j) for j in range(ncomp - 1)]
                    out.append(([cov[i]] + rest, gid))
        return out

    # --- GPOS mark-to-base, lookup type 4: one (marks, bases) pair per subtable
    def anchor(self, o):
        return (self.s16(o + 2), self.s16(o + 4))

    def mark_base(self, script):
        """[(marks {gid: (class index, (x, y))}, bases {gid: {class index: (x, y)}})]
        for every MarkBasePos subtable the mark feature references"""
        out = []
        for t, st in self.feature_lookups("GPOS", b"mark", script):
            if t != 4:
                continue
            mcov = self.coverage(st + self.u16(st + 2))
            bcov = self.coverage(st + self.u16(st + 4))
            classes = self.u16(st + 6)
            ma = st + self.u16(st + 8)
            ba = st + self.u16(st + 10)
            marks = {}
            for i in range(self.u16(ma)):
                cl, ao = self.u16(ma + 2 + 4 * i), self.u16(ma + 4 + 4 * i)
                marks[mcov[i]] = (cl, self.anchor(ma + ao))
            bases = {}
            for i in range(self.u16(ba)):
                rec = ba + 2 + i * 2 * classes
                anchors = {}
                for c in range(classes):
                    ao = self.u16(rec + 2 * c)
                    if ao:
                        anchors[c] = self.anchor(ba + ao)
                bases[bcov[i]] = anchors
            out.append((marks, bases))
        return out


def convert(ttf_path):
    f = Font(open(ttf_path, "rb").read())
    names = {0: ".notdef"}
    for cp, gid in sorted(f.cmap.items()):
        if gid in names:
            continue
        if cp in AGL:
            names[gid] = AGL[cp]
        elif 0x30 <= cp <= 0x39 or 0x41 <= cp <= 0x5A or 0x61 <= cp <= 0x7A:
            names[gid] = chr(cp)
        else:
            names[gid] = "uni%04X" % cp
    keep = set([0])
    for cp in KEEP:
        if cp in f.cmap:
            keep.add(f.cmap[cp])
    ligs = [(comps, gid) for comps, gid in f.ligatures() if all(c in keep for c in comps)]
    for comps, gid in ligs:
        keep.add(gid)
        names[gid] = "_".join(names[c] for c in comps)      # f_i, not uniFB01
    # components, transitively
    todo = list(keep)
    while todo:
        gid = todo.pop()
        _, comps = f.outline(gid)
        for cg, _ in comps:
            if cg not in keep:
                keep.add(cg)
                todo.append(cg)
    for gid in keep:
        if gid not in names:
            names[gid] = "g%d" % gid
    glyphs = {}
    for gid in sorted(keep):
        contours, comps = f.outline(gid)
        glyphs[names[gid]] = {
            "advance": f.advance(gid),
            "contours": contours,
            "components": [{"glyph": names[cg], "transform": t} for cg, t in comps],
        }
    kern = [[names[a], names[b], v] for (a, b), v in sorted(f.kern_pairs().items())
            if a in keep and b in keep]
    cmap = {str(cp): names[gid] for cp, gid in sorted(f.cmap.items()) if gid in keep}
    return {
        "family": "Roboto", "style": "Regular", "license": "Apache-2.0",
        "units_per_em": f.upem, "ascender": f.ascender, "descender": f.descender,
        "line_gap": f.line_gap,
        "cmap": cmap,
        "glyphs": glyphs,
        "kern": kern,
        "ligatures": [[[names[c] for c in comps], names[gid]] for comps, gid in ligs],
    }


# --------------------------------------------------------------------------
# the Arabic subset, for chapter 19
# --------------------------------------------------------------------------
ARABIC_NAMES = {
    0x0621: "hamza", 0x0622: "alefmadda", 0x0623: "alefhamzaabove", 0x0624: "wawhamza",
    0x0625: "alefhamzabelow", 0x0626: "yehhamza", 0x0627: "alef", 0x0628: "beh",
    0x0629: "tehmarbuta", 0x062A: "teh", 0x062B: "theh", 0x062C: "jeem", 0x062D: "hah",
    0x062E: "khah", 0x062F: "dal", 0x0630: "thal", 0x0631: "reh", 0x0632: "zain",
    0x0633: "seen", 0x0634: "sheen", 0x0635: "sad", 0x0636: "dad", 0x0637: "tah",
    0x0638: "zah", 0x0639: "ain", 0x063A: "ghain", 0x0640: "tatweel", 0x0641: "feh",
    0x0642: "qaf", 0x0643: "kaf", 0x0644: "lam", 0x0645: "meem", 0x0646: "noon",
    0x0647: "heh", 0x0648: "waw", 0x0649: "alefmaksura", 0x064A: "yeh",
    0x064B: "fathatan", 0x064C: "dammatan", 0x064D: "kasratan", 0x064E: "fatha",
    0x064F: "damma", 0x0650: "kasra", 0x0651: "shadda", 0x0652: "sukun",
    0x060C: "arabiccomma", 0x061F: "arabicquestion", 0x0020: "space",
    0x002C: "comma", 0x002E: "period", 0x003A: "colon", 0x003B: "semicolon",
    0x0021: "exclam", 0x003F: "question", 0x0028: "parenleft", 0x0029: "parenright",
    0x002D: "hyphen",
}

# Unicode's joining types (ArabicShaping.txt) for the letters above. R joins
# only to the letter before it; D joins both ways; U never joins; T is
# transparent, invisible to the letters either side of it. Tatweel is
# Unicode's C, join-causing, which for shaping behaves as D with one form.
JOINING = {}
for _cp in (0x0622, 0x0623, 0x0624, 0x0625, 0x0627, 0x0629, 0x062F, 0x0630, 0x0631, 0x0632,
            0x0648, 0x0649):
    JOINING[_cp] = "right"
for _cp in (0x0626, 0x0628, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x0633, 0x0634, 0x0635,
            0x0636, 0x0637, 0x0638, 0x0639, 0x063A, 0x0640, 0x0641, 0x0642, 0x0643, 0x0644,
            0x0645, 0x0646, 0x0647, 0x064A):
    JOINING[_cp] = "dual"
for _cp in range(0x064B, 0x0653):
    JOINING[_cp] = "transparent"
for _cp in (0x0621, 0x060C, 0x061F, 0x0020, 0x002C, 0x002E, 0x003A, 0x003B, 0x0021, 0x003F,
            0x0028, 0x0029, 0x002D):
    JOINING[_cp] = "none"

ANCHOR_CLASSES = {(512, 0): "below", (512, 1200): "above"}


def convert_arabic(ttf_path):
    f = Font(open(ttf_path, "rb").read())
    script = b"arab"
    names = {0: ".notdef"}
    keep = set([0])
    for cp, name in ARABIC_NAMES.items():
        if cp in f.cmap:
            names[f.cmap[cp]] = name
            keep.add(f.cmap[cp])
    # positional forms: the init/medi/fina single substitutions
    forms = {}
    for form in ("init", "medi", "fina"):
        m = f.single_subst(form.encode("ascii"), script)
        for src, dst in m.items():
            if src in keep and src in names:
                forms.setdefault(names[src], {})[form] = names[src] + "." + form
                names[dst] = names[src] + "." + form
    form_gids = set()
    for form in ("init", "medi", "fina"):
        for src, dst in f.single_subst(form.encode("ascii"), script).items():
            if src in keep:
                form_gids.add(dst)
    keep |= form_gids
    # ligatures whose parts are all letters or forms we keep: rlig, then liga
    ligs = []
    seen = set()
    for tag in (b"rlig", b"liga"):
        for comps, gid in f.ligature_subst(tag, script):
            if all(c in keep and c in names for c in comps) and gid not in seen:
                if any(names[c].split(".")[0] in ("space",) or names[c] in JOINING_MARK_NAMES for c in comps):
                    continue
                seen.add(gid)
                base = "_".join(names[c].split(".")[0] for c in comps)
                first = names[comps[0]].split(".")[1:]
                if first == ["medi"] or first == ["fina"]:          # lam.medi + alef.fina -> lam_alef.fina
                    base += ".fina"
                names[gid] = base
                keep.add(gid)
                ligs.append((comps, gid))
    # mark attachment: class names from the marks' own anchors
    marks, anchors = {}, {}
    for mtable, btable in f.mark_base(script):
        class_names = {}
        for gid, (cl, anchor) in mtable.items():
            if gid in keep and anchor in ANCHOR_CLASSES:
                class_names[cl] = ANCHOR_CLASSES[anchor]
        if not class_names:
            continue
        for gid, (cl, anchor) in mtable.items():
            if gid in keep and cl in class_names:
                marks[names[gid]] = [class_names[cl], anchor[0], anchor[1]]
        for gid, table in btable.items():
            if gid in keep:
                for cl, anchor in table.items():
                    if cl in class_names:
                        anchors.setdefault(names[gid], {})[class_names[cl]] = [anchor[0], anchor[1]]
    # components, transitively
    todo = list(keep)
    while todo:
        gid = todo.pop()
        _, comps = f.outline(gid)
        for cg, _ in comps:
            if cg not in keep:
                keep.add(cg)
                todo.append(cg)
    for gid in keep:
        if gid not in names:
            names[gid] = "g%d" % gid
    glyphs = {}
    for gid in sorted(keep):
        contours, comps = f.outline(gid)
        glyphs[names[gid]] = {
            "advance": f.advance(gid),
            "contours": contours,
            "components": [{"glyph": names[cg], "transform": t} for cg, t in comps],
        }
    cmap = {str(cp): names[f.cmap[cp]] for cp in sorted(ARABIC_NAMES) if cp in f.cmap}
    joining = {str(cp): JOINING[cp] for cp in sorted(ARABIC_NAMES) if cp in f.cmap}
    return {
        "family": "DejaVu Sans", "style": "Book", "license": "Bitstream Vera / public domain",
        "units_per_em": f.upem, "ascender": f.ascender, "descender": f.descender,
        "line_gap": f.line_gap,
        "cmap": cmap,
        "glyphs": glyphs,
        "kern": [],
        "ligatures": [[[names[c] for c in comps], names[gid]] for comps, gid in ligs],
        "joining": joining,
        "forms": {k: forms[k] for k in sorted(forms)},
        "marks": {k: marks[k] for k in sorted(marks)},
        "anchors": {k: {c: anchors[k][c] for c in sorted(anchors[k])} for k in sorted(anchors)},
    }


JOINING_MARK_NAMES = set(ARABIC_NAMES[cp] for cp in range(0x064B, 0x0653))


def main(argv):
    arabic = "--arabic" in argv
    src, dst = [a for a in argv if not a.startswith("--")]
    data = convert_arabic(src) if arabic else convert(src)
    text = json.dumps(data, separators=(",", ":"))
    open(dst, "w").write(text + "\n")
    print("%s: %d glyphs, %d kern pairs, %d ligatures, %d forms, %d marks, %d anchored bases, %.0f KB" % (
        dst, len(data["glyphs"]), len(data["kern"]), len(data["ligatures"]),
        len(data.get("forms", {})), len(data.get("marks", {})), len(data.get("anchors", {})),
        len(text) / 1024))


if __name__ == "__main__":
    main(sys.argv[1:])
