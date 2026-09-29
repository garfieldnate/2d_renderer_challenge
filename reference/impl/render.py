#!/usr/bin/env python3
"""
Regenerate reference/chapter-NN/*.ppm from the reference implementation.

    ./reference/impl/render.py            # every chapter and the epilogue
    ./reference/impl/render.py 4          # one chapter
    ./reference/impl/render.py epilogue   # the cover
"""

import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import importlib
import renderer as R  # noqa: E402

REF = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent


def main(only=None):
    modules = [R] + [importlib.import_module(p.stem) for p in sorted(HERE.glob("chapter*.py"))] + [importlib.import_module("epilogue")]
    for m in modules:
        chapter = getattr(m, "CHAPTER", 1)
        if only is not None and chapter != only:
            continue
        fmt = getattr(m, "FORMAT", "P3")
        out = REF / (chapter if isinstance(chapter, str) else "chapter-%02d" % chapter)
        out.mkdir(exist_ok=True)
        for name, fn in m.RENDERS.items():
            c = fn()
            if fmt == "P3":
                data = R.canvas_to_ppm(c).encode("ascii")
            else:
                from chapter02 import canvas_to_p6
                data = canvas_to_p6(c)
            path = out / (name + ".ppm")
            path.write_bytes(data)
            print("%-40s %7.1f KB" % (path.relative_to(REF.parent), len(data) / 1024))
            if chapter == "epilogue" and name == "cover":
                # chapter 0 and the contents page show the finished cover as an image
                png = REF.parent / "assets" / "cover.png"
                png.write_bytes(to_png(c))
                print("%-40s %7.1f KB" % (png.relative_to(REF.parent), png.stat().st_size / 1024))
    R.set_linear_blending(True)


def to_png(c):
    """the canvas as an 8-bit RGB PNG, bytes exactly as the P6 writer makes them"""
    from chapter02 import canvas_to_p6
    p6 = canvas_to_p6(c)
    pixels = p6[len(p6) - c.width * c.height * 3:]
    row = c.width * 3
    raw = b"".join(b"\x00" + pixels[y * row:(y + 1) * row] for y in range(c.height))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", c.width, c.height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    main(arg if arg is None or not arg.isdigit() else int(arg))
