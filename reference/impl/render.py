#!/usr/bin/env python3
"""
Regenerate reference/chapter-01/*.ppm from the reference implementation.

    ./reference/impl/render.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import renderer as R  # noqa: E402

OUT = Path(__file__).resolve().parents[1] / "chapter-01"


def main():
    OUT.mkdir(exist_ok=True)
    for name, fn in R.RENDERS.items():
        ppm = R.canvas_to_ppm(fn())
        path = OUT / (name + ".ppm")
        path.write_text(ppm, encoding="utf-8")
        print("%-40s %7.1f KB" % (path.relative_to(OUT.parents[1]), len(ppm) / 1024))
    R.set_linear_blending(True)


if __name__ == "__main__":
    main()
