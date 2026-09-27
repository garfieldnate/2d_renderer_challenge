#!/usr/bin/env python3
"""
Author-side generator for chapter 20's showcase documents. Writes
reference/chapter-20/harbor.svg and reference/chapter-20/rose.svg.

The files are the data; this script only saves typing the repetitive parts
(stars, ripples, the window's twelve bays). Everything in them is SVG the
chapter's walker reads: basic shapes, path data with arcs and shorthand,
the whole transform grammar, presentation attributes, style attributes,
inheritance, gradients by reference, clip paths, group opacity, dashes.
"""

import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "reference" / "chapter-20"


def f(v):
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for k in range(2 * n):
        r = r_out if k % 2 == 0 else r_in
        a = math.radians(rot + k * 180 / n)
        pts.append("%s,%s" % (f(cx + r * math.cos(a)), f(cy + r * math.sin(a))))
    return " ".join(pts)


def harbor():
    rnd = random.Random(20)
    L = []
    a = L.append
    a('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 320" preserveAspectRatio="xMidYMid slice">')
    a('  <defs>')
    a('    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">')
    a('      <stop offset="0" stop-color="#0b1026"/>')
    a('      <stop offset="0.45" stop-color="#3b1d5e"/>')
    a('      <stop offset="0.75" stop-color="#b8406a"/>')
    a('      <stop offset="1" stop-color="#ff9a52"/>')
    a('    </linearGradient>')
    a('    <radialGradient id="sun" cx="0.5" cy="0.5" r="0.5" fx="0.42" fy="0.38">')
    a('      <stop offset="0%" stop-color="#fffbe0"/>')
    a('      <stop offset="55%" stop-color="#ffd36b"/>')
    a('      <stop offset="100%" stop-color="#ff7a3d"/>')
    a('    </radialGradient>')
    a('    <linearGradient id="sea" gradientUnits="userSpaceOnUse" x1="0" y1="212" x2="0" y2="320">')
    a('      <stop offset="0" style="stop-color: #6b2f5c"/>')
    a('      <stop offset="1" style="stop-color: #0d1330"/>')
    a('    </linearGradient>')
    a('    <linearGradient id="far" gradientUnits="userSpaceOnUse" x1="0" y1="140" x2="0" y2="212">')
    a('      <stop offset="0" stop-color="#7a4a8c"/>')
    a('      <stop offset="1" stop-color="#c86a7a"/>')
    a('    </linearGradient>')
    a('    <linearGradient id="near" x1="0%" y1="0%" x2="0%" y2="100%">')
    a('      <stop offset="0" stop-color="#2b1840"/>')
    a('      <stop offset="1" stop-color="#150c24"/>')
    a('    </linearGradient>')
    a('    <linearGradient id="beam" x1="0" y1="0" x2="1" y2="0" gradientTransform="rotate(8)">')
    a('      <stop offset="0" stop-color="#fff6c8"/>')
    a('      <stop offset="1" stop-color="#8a3d6e"/>')
    a('    </linearGradient>')
    a('    <linearGradient id="stripes" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="9" spreadMethod="repeat">')
    a('      <stop offset="0.5" stop-color="#f4efe6"/>')
    a('      <stop offset="0.5" stop-color="#c8323c"/>')
    a('    </linearGradient>')
    a('    <radialGradient id="moonlight" cx="0.3" cy="0.4" r="0.7" gradientTransform="translate(0.3 0.4) rotate(-30) scale(1 0.6) translate(-0.3 -0.4)">')
    a('      <stop offset="0" stop-color="#fffdf0"/>')
    a('      <stop offset="1" stop-color="#d8cca0"/>')
    a('    </radialGradient>')
    a('    <clipPath id="glitter">')
    a('      <polygon points="240,212 196,320 284,320"/>')
    a('    </clipPath>')
    a('  </defs>')
    # sky
    a('  <rect width="480" height="320" fill="url(#sky)"/>')
    # stars: evenodd pentagrams, hollow centers
    a('  <g fill="#fff4d6" fill-rule="evenodd" opacity="0.85">')
    placed = 0
    while placed < 26:
        x, y = rnd.uniform(8, 470), rnd.uniform(6, 120)
        r = rnd.uniform(1.6, 4.2)
        rot = rnd.uniform(0, 72)
        if (x - 398) ** 2 + (y - 66) ** 2 < 60 ** 2:
            continue
        placed += 1
        a('    <polygon points="%s" transform="translate(%s %s) rotate(%s)"/>'
          % (_pentagram(r), f(x), f(y), f(rot)))
    a('  </g>')
    # the moon: a crescent of two arcs in a glowing gradient, a faint halo
    a('  <g fill="#f7f2dc">')
    for r in (52, 46, 41, 37):
        a('    <circle cx="398" cy="66" r="%d" opacity="0.05"/>' % r)
    a('  </g>')
    a('  <path d="M392 36a30 30 0 1 0 34 44 24 24 0 1 1-34-44z" fill="url(#moonlight)"/>')
    # sun and its halo
    a('  <g fill="#ffb86b">')
    for r in (92, 80, 70, 61, 53, 46):
        a('    <circle cx="240" cy="206" r="%d" opacity="0.07"/>' % r)
    a('  </g>')
    a('  <circle cx="240" cy="206" r="40" fill="url(#sun)"/>')
    # far hills, hazy
    a('  <g opacity="0.7">')
    a('    <path fill="url(#far)" d="M0 212V170q30-26 62-8t58 4 70-30 64 18c20 10 38 12 60-4s50-28 82-6 50 16 84 2V212z"/>')
    a('  </g>')
    # sea
    a('  <rect y="212" width="480" height="108" fill="url(#sea)"/>')
    # sun glitter: dashed ripples clipped to a wedge
    a('  <g clip-path="url(#glitter)" stroke="#ffd98a" stroke-linecap="round">')
    y = 216
    k = 0
    while y < 320:
        w = 0.8 + (y - 212) / 40
        dash1 = f(4 + (y - 212) / 6)
        a('    <line x1="150" y1="%s" x2="330" y2="%s" stroke-width="%s" stroke-dasharray="%s %s" stroke-dashoffset="%s"/>'
          % (f(y), f(y), f(w), dash1, f(3 + k % 3 * 2), f(k * 3.7)))
        y += 4 + (y - 212) / 12
        k += 1
    a('  </g>')
    # near headland with the lighthouse
    a('  <path fill="url(#near)" d="M300 320V236c18-6 30-18 52-20s36 6 54 2 40-22 74-18V320z"/>')
    a('  <g transform="translate(408 150)">')
    a('    <polygon points="4,0 22,0 26,68 0,68" fill="url(#stripes)" stroke="#1a0f2a" stroke-width="1" stroke-linejoin="round"/>')
    a('    <rect x="-2" y="-6" width="30" height="6" rx="2" fill="#1a0f2a"/>')
    a('    <path d="M3 -6 L6 -20 H20 L23 -6 Z" fill="#ffe9a8" stroke="#1a0f2a" stroke-width="1.2" stroke-linejoin="bevel"/>')
    a('    <path d="M13-20a8 8 0 0 1-8-2h16a8 8 0 0 1-8 2" fill="#1a0f2a"/>')
    a('    <path d="M13 -13 L-160 -34 L-160 2 Z" fill="url(#beam)" opacity="0.16"/>')
    a('  </g>')
    # sailboat: skewed sails, a hull, a mast
    a('  <g transform="translate(118 222) scale(0.9)">')
    a('    <path d="M-36 0h72l-10 12h-52z" fill="#1a0f2a"/>')
    a('    <line x1="0" y1="0" x2="0" y2="-70" stroke="#1a0f2a" stroke-width="2" stroke-linecap="square"/>')
    a('    <polygon points="2,-68 2,-4 34,-4" fill="#f6d9c4" transform="skewX(-6)"/>')
    a('    <polygon points="-2,-60 -2,-4 -28,-4" style="fill: #e9b8a8; stroke: #1a0f2a; stroke-width: 0.8"/>')
    a('    <polyline points="0,-70 10,-66 0,-62" fill="#c8323c"/>')
    a('  </g>')
    # the boat's reflection: the same drawing flipped, faded
    a('  <g transform="matrix(0.9 0 0 -0.45 118 236)" opacity="0.3">')
    a('    <polygon points="2,-68 2,-4 34,-4" fill="#f6d9c4" transform="skewX(-6)"/>')
    a('    <polygon points="-2,-60 -2,-4 -28,-4" fill="#e9b8a8"/>')
    a('  </g>')
    # gulls: two arcs each, round caps, rotated about their own centres
    a('  <g fill="none" stroke="#1a0f2a" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">')
    for (x, y, s, r) in [(170, 96, 1.0, -8), (196, 84, 0.8, 6), (214, 104, 0.65, -4), (300, 70, 0.9, 10), (322, 88, 0.6, -12)]:
        a('    <path d="M-10 0a7 5 0 0 1 10 0 7 5 0 0 1 10 0" transform="translate(%s %s) rotate(%s) scale(%s)"/>' % (f(x), f(y), f(r), f(1.7 * s)))
    a('  </g>')
    # buoys: ellipses, one skewed by skewY
    a('  <ellipse cx="200" cy="262" rx="6" ry="3" fill="#c8323c"/>')
    a('  <ellipse cx="268" cy="286" rx="8" ry="4" fill="#f4efe6" transform="skewY(4)"/>')
    # the frame: a rounded rectangle and a dashed rule inside it
    a('  <rect x="6" y="6" width="468" height="308" rx="14" fill="none" stroke="#f7f2dc" stroke-width="3"/>')
    a('  <rect x="13" y="13" width="454" height="294" rx="9" ry="9" fill="none" stroke="#f7f2dc" stroke-width="0.8" stroke-dasharray="1 5" stroke-linecap="round" opacity="0.8"/>')
    a('</svg>')
    return "\n".join(L) + "\n"


def _pentagram(r):
    """the five points of a star joined every second one: its middle winds
    twice, so evenodd leaves it hollow"""
    pts = []
    for k in range(5):
        a = math.radians(-90 + k * 144)
        pts.append("%s,%s" % (f(r * math.cos(a)), f(r * math.sin(a))))
    return " ".join(pts)


def rose():
    L = []
    a = L.append
    C = 200
    a('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">')
    a('  <defs>')
    a('    <radialGradient id="stone" gradientUnits="userSpaceOnUse" cx="200" cy="200" r="200" fx="150" fy="140">')
    a('      <stop offset="0" stop-color="#8d8577"/>')
    a('      <stop offset="0.8" stop-color="#4a443c"/>')
    a('      <stop offset="1" stop-color="#2a2622"/>')
    a('    </radialGradient>')
    a('    <radialGradient id="heart" cx="0.5" cy="0.5" r="0.5" fx="0.4" fy="0.35">')
    a('      <stop offset="0" stop-color="#fff2b0"/>')
    a('      <stop offset="0.6" stop-color="#f0a818"/>')
    a('      <stop offset="1" stop-color="#9a4a08"/>')
    a('    </radialGradient>')
    a('    <radialGradient id="blue" cx="0.5" cy="0.9" r="0.9">')
    a('      <stop offset="0" stop-color="#7fc8ff"/>')
    a('      <stop offset="0.5" stop-color="#1f5fbf"/>')
    a('      <stop offset="1" stop-color="#0a1f5c"/>')
    a('    </radialGradient>')
    a('    <radialGradient id="ruby" cx="0.5" cy="0.2" r="0.8">')
    a('      <stop offset="0" stop-color="#ff9aa8"/>')
    a('      <stop offset="0.55" stop-color="#c4122e"/>')
    a('      <stop offset="1" stop-color="#4a0414"/>')
    a('    </radialGradient>')
    a('    <linearGradient id="emerald" x1="0" y1="0" x2="1" y2="1">')
    a('      <stop offset="0" stop-color="#b6f5a0"/>')
    a('      <stop offset="0.5" stop-color="#1e9a4a"/>')
    a('      <stop offset="1" stop-color="#06401e"/>')
    a('    </linearGradient>')
    a('    <radialGradient id="rings" gradientUnits="userSpaceOnUse" cx="200" cy="200" r="14" spreadMethod="reflect">')
    a('      <stop offset="0" stop-color="#5a2a8a"/>')
    a('      <stop offset="1" stop-color="#b070e0"/>')
    a('    </radialGradient>')
    a('    <clipPath id="window">')
    a('      <circle cx="200" cy="200" r="176"/>')
    a('    </clipPath>')
    a('  </defs>')
    a('  <rect width="400" height="400" fill="url(#stone)"/>')
    # the glass, clipped to the window
    a('  <g clip-path="url(#window)" stroke="#141210" stroke-linejoin="round">')
    a('    <circle cx="200" cy="200" r="176" fill="url(#rings)" stroke="none"/>')
    a('    <g transform="translate(200 200)">')
    for k in range(12):
        ang = k * 30
        a('      <g transform="rotate(%d)">' % ang)
        # outer bay: a pointed lancet made of two arcs
        a('        <path d="M0-60 C22-80 30-120 26-150 A40 40 0 0 0 0-176 A40 40 0 0 0-26-150 C-30-120-22-80 0-60Z" fill="url(#%s)" stroke-width="4"/>'
          % ("blue" if k % 2 == 0 else "ruby"))
        a('        <path d="M0-78 C12-94 16-118 14-138 A22 22 0 0 0 0-156 A22 22 0 0 0-14-138 C-16-118-12-94 0-78Z" fill="url(#emerald)" stroke-width="2.5" opacity="0.85"/>')
        a('        <circle cy="-104" r="6" fill="url(#heart)" stroke-width="2"/>')
        a('        <g transform="rotate(15)">')
        a('          <circle cy="-150" r="13" fill="#f0a818" stroke-width="3"/>')
        a('          <circle cy="-150" r="5" fill="#fff2b0" stroke-width="1.5"/>')
        a('        </g>')
        a('      </g>')
    # the rose's middle: twelve petals, the heart, tracery rings
    for k in range(12):
        a('      <ellipse rx="11" ry="30" cy="-34" fill="url(#%s)" stroke-width="2.5" transform="rotate(%d)"/>'
          % ("ruby" if k % 2 == 0 else "blue", k * 30 + 15))
    a('      <circle r="22" fill="url(#heart)" stroke-width="3"/>')
    a('      <path d="M0-12L3.5-3.5 12 0 3.5 3.5 0 12-3.5 3.5-12 0-3.5-3.5z" fill="#fff8d8" stroke-width="1.5"/>')
    a('    </g>')
    a('  </g>')
    # leading: concentric rings, one an evenodd annulus, one dashed
    a('  <g fill="none" stroke="#141210">')
    a('    <circle cx="200" cy="200" r="176" stroke-width="7"/>')
    a('    <circle cx="200" cy="200" r="64" stroke-width="4"/>')
    a('    <circle cx="200" cy="200" r="186" stroke="#2a2622" stroke-width="10" stroke-dasharray="9.74 4" />')
    a('  </g>')
    a('  <path fill="#6d665a" fill-rule="evenodd" d="M200 8a192 192 0 1 1 0 384a192 192 0 1 1 0-384zM200 18a182 182 0 1 0 0 364a182 182 0 1 0 0-364z"/>')
    # carved stone corners: matrix-placed quarter rosettes
    for (mx, my, ma, mb, mc, md) in [(0, 0, 1, 0, 0, 1), (400, 0, -1, 0, 0, 1), (0, 400, 1, 0, 0, -1), (400, 400, -1, 0, 0, -1)]:
        a('  <g transform="matrix(%d %d %d %d %d %d)" fill="#3a352e" stroke="#8d8577" stroke-width="1.2">' % (ma, mb, mc, md, mx, my))
        a('    <path d="M0 0H44A44 44 0 0 1 0 44Z"/>')
        a('    <path d="M6 6H30A24 24 0 0 1 6 30Z" fill="#5a2a8a" style="stroke-dasharray: 2 2"/>')
        a('    <circle cx="14" cy="14" r="4" fill="#f0a818" stroke="none"/>')
        a('  </g>')
    a('</svg>')
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    (OUT / "harbor.svg").write_text(harbor())
    (OUT / "rose.svg").write_text(rose())
    print("wrote harbor.svg, rose.svg")
