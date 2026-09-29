#!/usr/bin/env python3
"""
Stage and collect reader implementations for agent testing.

readers/<lang>/ holds one implementation of the book per language, written by
reader agents chapter by chapter. To test chapter N, an agent gets an isolated
copy of its language's code plus the built chapters 1..N, their feature files
and reference images, and nothing else. When it finishes, its code comes back;
its renders, feedback and copies of the book do not.

    ./tools/readers.py stage <lang> <chapter> <dir>    # dir is created; chapter 1..25 or "epilogue"
    ./tools/readers.py collect <lang> <chapter> <dir>  # code -> readers/<lang>,
                                                       # FEEDBACK.md -> readers/feedback/
"""

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# never copied back into the repo
# build products are anchored to the reader's root: rust keeps its src/bin/
EXCLUDE = ["/out/", "/reference/", "/features/", "/chapter-*.html", "/epilogue.html", "/FEEDBACK.md", "/TASK.md",
           "/target/", "/classes/", "/bin/", "/obj/", "/.build/", "__pycache__/",
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
    last = 25 if chapter == "epilogue" else chapter
    shutil.copy(ROOT / "dist" / "chapter-00.html", d)
    stems = ["chapter-%02d" % n for n in range(1, last + 1)] + (["epilogue"] if chapter == "epilogue" else [])
    for stem in stems:
        shutil.copy(ROOT / "dist" / (stem + ".html"), d)
        for f in (ROOT / "features").glob(stem.replace("chapter-", "chapter") + "-*.feature"):
            shutil.copy(f, d / "features")
        ref = ROOT / "reference" / stem
        if ref.exists():
            shutil.copytree(ref, d / "reference" / ref.name, dirs_exist_ok=True)
    print("staged %s for %s in %s" % (lang, stems[-1], d))


def collect(lang, chapter, d):
    d = Path(d)
    dst = ROOT / "readers" / lang
    dst.mkdir(parents=True, exist_ok=True)
    rsync(d, dst, EXCLUDE)
    fb = d / "FEEDBACK.md"
    if fb.exists():
        name = "epilogue" if chapter == "epilogue" else "chapter%02d" % chapter
        out = ROOT / "readers" / "feedback" / ("%s-%s.md" % (name, lang))
        out.parent.mkdir(exist_ok=True)
        shutil.copy(fb, out)
        print("feedback -> %s" % out.relative_to(ROOT))
    print("collected %s into %s" % (lang, dst.relative_to(ROOT)))


def main(argv):
    if len(argv) != 4 or argv[0] not in ("stage", "collect"):
        print(__doc__)
        return 2
    chapter = argv[2] if argv[2] == "epilogue" else int(argv[2])
    {"stage": stage, "collect": collect}[argv[0]](argv[1], chapter, argv[3])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
