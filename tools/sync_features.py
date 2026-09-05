#!/usr/bin/env python3
"""
Copy every feature file into the chapter that prints it.

A chapter marks where a feature file belongs with

    <div class="test" data-feature="chapter01-colors.feature">
      <p class="label">features/chapter01-colors.feature</p>
      <pre><code>...</code></pre>
    </div>

and this script replaces the <pre><code> contents with the file, HTML-escaped
and with Gherkin keywords wrapped in <span class="kw">. Run it after editing
either side. With --check it exits non-zero instead of writing, for CI.

    ./tools/sync_features.py                # every chapter
    ./tools/sync_features.py --check
"""

import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KEYWORDS = ("Feature", "Scenario Outline", "Scenario", "Examples", "Given", "When", "Then", "And", "But")
KW_RE = re.compile(r"^(\s*)(%s)(:|\b)" % "|".join(KEYWORDS))
BLOCK_RE = re.compile(
    r'(<div class="test" data-feature="([^"]+)">.*?<pre><code>)(.*?)(</code></pre>)', re.S)


def highlight(text):
    out = []
    for line in text.rstrip("\n").split("\n"):
        esc = html.escape(line, quote=False)
        m = KW_RE.match(esc)
        if m:
            esc = '%s<span class="kw">%s</span>%s%s' % (
                m.group(1), m.group(2), m.group(3), esc[m.end():])
        out.append(esc)
    return "\n".join(out)


def sync(chapter, check):
    src = chapter.read_text(encoding="utf-8")
    seen = []

    def fill(m):
        name = m.group(2)
        seen.append(name)
        feature = (ROOT / "features" / name).read_text(encoding="utf-8")
        return m.group(1) + highlight(feature) + m.group(4)

    out = BLOCK_RE.sub(fill, src)
    stem = chapter.stem.replace("chapter-", "chapter")
    expected = sorted(p.name for p in (ROOT / "features").glob(stem + "-*.feature"))
    missing = sorted(set(expected) - set(seen))
    dupes = sorted(n for n in set(seen) if seen.count(n) > 1)
    problems = []
    if missing:
        problems.append("%s does not print %s" % (chapter.name, ", ".join(missing)))
    if dupes:
        problems.append("%s prints %s more than once" % (chapter.name, ", ".join(dupes)))
    if out != src:
        if check:
            problems.append("%s is out of date with features/" % chapter.name)
        else:
            chapter.write_text(out, encoding="utf-8")
            print("updated %s (%d feature blocks)" % (chapter.name, len(seen)))
    elif not check:
        print("%s up to date (%d feature blocks)" % (chapter.name, len(seen)))
    return problems


def main(argv):
    check = "--check" in argv
    problems = []
    for ch in sorted((ROOT / "chapters").glob("chapter-*.html")):
        problems += sync(ch, check)
    for p in problems:
        print("ERROR: " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
