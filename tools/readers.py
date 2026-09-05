#!/usr/bin/env python3
"""
Stage and collect reader implementations for agent testing.

readers/<lang>/ holds one implementation of the book per language, written by
reader agents chapter by chapter. To test chapter N, an agent gets an isolated
copy of its language's code plus the built chapters 1..N, their feature files
and reference images, and nothing else. When it finishes, its code comes back;
its renders, feedback and copies of the book do not.

    ./tools/readers.py stage <lang> <chapter> <dir>    # dir is created
    ./tools/readers.py collect <lang> <chapter> <dir>  # code -> readers/<lang>,
                                                       # FEEDBACK.md -> readers/feedback/
"""

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# never copied back into the repo
EXCLUDE = ["out/", "reference/", "features/", "chapter-*.html", "FEEDBACK.md",
           "target/", "classes/", "bin/", "obj/", ".build/", "__pycache__/",
           "node_modules/", ".lake/", "*.olean", "*.ilean", "*.o", "*.class",
           "*.pyc", ".DS_Store"]


def rsync(src, dst, excludes=()):
    cmd = ["rsync", "-a", "--delete"] + ["--exclude=%s" % e for e in excludes] + [str(src) + "/", str(dst) + "/"]
    subprocess.run(cmd, check=True)


def stage(lang, chapter, d):
    d = Path(d)
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    src = ROOT / "readers" / lang
    if src.exists():
        rsync(src, d, EXCLUDE)
    subprocess.run([sys.executable, str(ROOT / "build.py")], check=True, stdout=subprocess.DEVNULL)
    (d / "features").mkdir(exist_ok=True)
    (d / "reference").mkdir(exist_ok=True)
    for n in range(1, chapter + 1):
        shutil.copy(ROOT / "dist" / ("chapter-%02d.html" % n), d)
        for f in (ROOT / "features").glob("chapter%02d-*.feature" % n):
            shutil.copy(f, d / "features")
        ref = ROOT / "reference" / ("chapter-%02d" % n)
        if ref.exists():
            shutil.copytree(ref, d / "reference" / ref.name, dirs_exist_ok=True)
    print("staged %s for chapter %d in %s" % (lang, chapter, d))


def collect(lang, chapter, d):
    d = Path(d)
    dst = ROOT / "readers" / lang
    dst.mkdir(parents=True, exist_ok=True)
    rsync(d, dst, EXCLUDE)
    fb = d / "FEEDBACK.md"
    if fb.exists():
        out = ROOT / "readers" / "feedback" / ("chapter%02d-%s.md" % (chapter, lang))
        out.parent.mkdir(exist_ok=True)
        shutil.copy(fb, out)
        print("feedback -> %s" % out.relative_to(ROOT))
    print("collected %s into %s" % (lang, dst.relative_to(ROOT)))


def main(argv):
    if len(argv) != 4 or argv[0] not in ("stage", "collect"):
        print(__doc__)
        return 2
    {"stage": stage, "collect": collect}[argv[0]](argv[1], int(argv[2]), argv[3])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
