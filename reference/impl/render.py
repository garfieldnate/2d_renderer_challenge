#!/usr/bin/env python3
"""
Regenerate reference/chapter-01/*.ppm from the reference implementation.

    ./reference/impl/render.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import importlib
import renderer as R  # noqa: E402

REF = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent


def main():
    modules = [R] + [importlib.import_module(p.stem) for p in sorted(HERE.glob("chapter*.py"))]
    for m in modules:
        chapter = getattr(m, "CHAPTER", 1)
        fmt = getattr(m, "FORMAT", "P3")
        out = REF / ("chapter-%02d" % chapter)
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
    R.set_linear_blending(True)


if __name__ == "__main__":
    main()
