"""
Epilogue, the cover: author-side reference implementation.
See renderer.py. Mirrors the book's API names exactly; never printed.

Nothing new. The cover is one SVG document drawn by chapter 20's walker
(gradients, a clip, the tiger, a stroke, a dash, a group at half opacity)
with the title set on top by chapter 18 and painted by chapter 17. The
bonus variant puts chapter 23's glow under the title first.
"""

from pathlib import Path

from renderer import color
from chapter16 import roboto
from chapter18 import layout_paragraph, layout_run, draw_run
from chapter20 import render_svg
from chapter23 import bake_mtsdf, draw_effect, clamp

CHAPTER = "epilogue"
FORMAT = "P6"

_REF = Path(__file__).resolve().parents[1] / "epilogue"

_TITLE = "The 2D Renderer Challenge"
_SUBTITLE = "A test-driven guide to drawing every pixel yourself"
_CREAM = color(0.9, 0.86, 0.79)
_ORANGE = color(1.0, 0.33, 0.085)


def cover_svg():
    return (_REF / "cover.svg").read_text()


def cover_title(font):
    """the title in two lines at 44 pixels, the subtitle beneath at 15"""
    title = layout_paragraph(font, _TITLE, 44, 40, 530, 400, "left", True)
    sub = layout_run(font, _SUBTITLE, 15, 40, 640, True)
    return title, sub


def book_cover():
    """chapter 20's walker draws the document; chapter 18 sets the type"""
    c = render_svg(cover_svg(), 480, 680)
    font = roboto()
    title, sub = cover_title(font)
    draw_run(c, font, title, 44, _CREAM, True)
    draw_run(c, font, sub, 15, _ORANGE, True)
    return c


def book_cover_glow():
    """the cover with chapter 23 under the title: every title glyph baked as
    an MTSDF at 32 pixels with spread 8 (11 pixels once drawn at 44 / 32,
    past the glow's reach of 10, so a clamped texel never glows), an orange
    glow read from the true-distance channel, and then draw_run paints the
    letters exactly as book_cover() does"""
    c = render_svg(cover_svg(), 480, 680)
    font = roboto()
    title, sub = cover_title(font)
    baked = {}
    for pl in title:
        if pl.name not in baked:
            baked[pl.name] = bake_mtsdf(font, pl.name, 32, 8)
    for pl in title:
        draw_effect(c, baked[pl.name], 44 / 32, pl.x, pl.y, _ORANGE, True, glow_of)
    draw_run(c, font, title, 44, _CREAM, True)
    draw_run(c, font, sub, 15, _ORANGE, True)
    return c


def glow_of(d):
    """0.45 at the edge and inside, falling off as a square to 0 at 10 pixels out"""
    return 0.45 * (1 - clamp(d / 10)) ** 2


def _cover_art():
    """the document alone, before the type: the scenarios draw it with
    render_svg directly"""
    return render_svg(cover_svg(), 480, 680)


RENDERS = {
    "cover-art": _cover_art,
    "cover": book_cover,
    "cover-glow": book_cover_glow,
}
