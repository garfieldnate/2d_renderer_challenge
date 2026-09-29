#!/usr/bin/env python3
"""
Inline a chapter's CSS and JS into one self-contained file.

Chapters are written as ordinary HTML documents that link ../assets/book.css
and ../assets/book.js, so they open by double-clicking with no build step.
This script produces the other thing we sometimes need: a single file with
nothing external, suitable for publishing or emailing.

    ./build.py                     # the contents page and every chapter, into dist/
    ./build.py chapters/chapter-01.html
    ./build.py --fragment ...      # drop <html>/<head>/<body>, for Artifacts

The --fragment form is what the Artifact publisher wants: a bare <title>,
<style>, content and <script>, with the document skeleton supplied for you.
"""

import base64
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"


def inline(path: Path, fragment: bool = False) -> str:
    html = path.read_text(encoding="utf-8")
    base = path.parent

    def css(m):
        href = base / m.group(1)
        return "<style>\n%s\n</style>" % href.read_text(encoding="utf-8").strip()

    def js(m):
        src = base / m.group(1)
        return "<script>\n%s\n</script>" % src.read_text(encoding="utf-8").strip()

    html = re.sub(r'<link rel="stylesheet" href="([^"]+)">', css, html)
    html = re.sub(r'<script src="([^"]+)"></script>', js, html)

    def img(m):
        data = (base / m.group(1)).resolve()
        return '<img src="data:image/png;base64,%s"' % base64.b64encode(data.read_bytes()).decode("ascii")

    html = re.sub(r'<img src="([^"]+\.png)"', img, html)

    if fragment:
        # keep the title, drop the rest of the skeleton
        title = re.search(r"<title>(.*?)</title>", html, re.S)
        body = re.search(r"<body[^>]*>(.*)</body>", html, re.S)
        html = "<title>%s</title>\n%s" % (
            title.group(1) if title else path.stem,
            body.group(1).strip() if body else html,
        )

    # dist/ is flat: the contents page and every chapter side by side
    html = html.replace('href="../index.html"', 'href="index.html"')
    html = html.replace('href="chapters/', 'href="')
    return html


def main(argv):
    fragment = "--fragment" in argv
    args = [a for a in argv if not a.startswith("--")]
    targets = [Path(a) for a in args] or [ROOT / "index.html"] + sorted((ROOT / "chapters").glob("*.html"))

    if not targets:
        print("nothing to build")
        return 1

    DIST.mkdir(exist_ok=True)
    for t in targets:
        out = DIST / t.name
        out.write_text(inline(t, fragment), encoding="utf-8")
        print("%-34s %7.1f KB" % (out.relative_to(ROOT), out.stat().st_size / 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
