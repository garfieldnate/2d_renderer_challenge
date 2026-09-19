#!/usr/bin/env python3
"""
Run every features/chapter01-*.feature against the reference implementation.

This is a deliberately tiny Gherkin executor: it understands exactly the step
shapes the book uses and nothing else. Its job is to prove that every number
printed in a scenario was produced by running code, so an edit to either side
that breaks the agreement fails loudly.

    ./reference/impl/run_features.py            # all chapter 1 features
    ./reference/impl/run_features.py features/chapter01-mix.feature
"""

import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import importlib
import renderer as R  # noqa: E402

CHAPTERS = [importlib.import_module(p.stem) for p in
            sorted(Path(__file__).resolve().parent.glob("chapter*.py"))]

ROOT = Path(__file__).resolve().parents[2]


class StepError(AssertionError):
    pass


def read_file(rel):
    return (ROOT / rel).read_bytes()


def make_env():
    env = {n: getattr(R, n) for n in dir(R) if not n.startswith("_")}
    for m in CHAPTERS:
        env.update({n: getattr(m, n) for n in dir(m) if not n.startswith("_")})
    env["read_file"] = read_file
    env["round"] = lambda v: int(math.floor(v + 0.5))
    env["length"] = len
    env["true"], env["false"], env["none"] = True, False, None
    env["sqrt"] = math.sqrt
    env["π"] = math.pi
    return env


def to_python(expr):
    """the book's expression syntax is nearly Python already"""
    return expr.strip()


def evaluate(expr, env):
    try:
        return eval(to_python(expr), {"__builtins__": {}}, env)
    except Exception as e:  # pragma: no cover
        raise StepError("could not evaluate %r: %s" % (expr, e))


def approx_equal(a, b, eps):
    if a is None or b is None:
        return a is b
    if hasattr(a, "approx"):          # Color, and chapter 4's Tuple and Matrix3
        return a.approx(b, eps)
    if hasattr(b, "approx"):
        return b.approx(a, eps)
    if isinstance(a, (tuple, list)) and isinstance(b, (tuple, list)):
        return len(a) == len(b) and all(approx_equal(x, y, eps) for x, y in zip(a, b))
    if isinstance(a, (str, bytes, bool)) or isinstance(b, (str, bytes, bool)):
        return a == b
    return abs(a - b) <= eps


EPS_RE = r"(?:\s*±\s*(?P<eps>[0-9.]+))?"


def matrix_from(table, env):
    values = [evaluate(cell, env) for row in table for cell in row]
    if len(values) != 9:
        raise StepError("a matrix table needs 3 rows of 3")
    return env["matrix3"](*values)


def run_step(text, doc, env):
    text = text.strip()
    if isinstance(doc, list):                    # a data table follows the step
        m = re.match(r"the following matrix (\w+):$", text)
        if m:
            env[m.group(1)] = matrix_from(doc, env)
            return
        m = re.match(r"(.+?) is the following matrix:$", text)
        if m:
            got, want = evaluate(m.group(1), env), matrix_from(doc, env)
            if not approx_equal(got, want, R.EPSILON):
                raise StepError("%r is not %r" % (got, want))
            return
        raise StepError("unknown table step: " + text)
    if doc is not None:
        m = re.match(r"lines (\d+)-(\d+) of (\w+) are$", text)
        if not m:
            raise StepError("unknown docstring step: " + text)
        lo, hi, name = int(m.group(1)), int(m.group(2)), m.group(3)
        got = env[name].split("\n")[lo - 1:hi]
        if got != doc.split("\n"):
            raise StepError("lines %d-%d were %r" % (lo, hi, got))
        return

    m = re.match(r"(\w+) ← (.+)$", text)
    if m:
        env[m.group(1)] = evaluate(m.group(2), env)
        return
    m = re.match(r"linear blending is (on|off)$", text)
    if m:
        # as a Given it sets the switch; as a Then it checks it. Same text, so
        # the runner treats it as: set when off is requested, check otherwise.
        if m.group(1) == "off":
            R.set_linear_blending(False)
        elif not R.LINEAR_BLENDING:
            raise StepError("linear blending is off")
        return
    m = re.match(r"(write_pixel|fill|set_coverage|paint_through|line_bresenham|line_wu|move_to|line_to|close|fill_span|add_cell|accumulate_row|accumulate|paint_fill|set_layer_pixel)\((.+)\)$", text)
    if m:
        evaluate(text, env)
        return
    m = re.match(r"every pixel of (\w+) is (.+)$", text)
    if m:
        want = evaluate(m.group(2), env)
        c = env[m.group(1)]
        bad = [i for i, p in enumerate(c.pixels) if not p.approx(want)]
        if bad:
            raise StepError("%d pixels differ, first at index %d" % (len(bad), bad[0]))
        return
    m = re.match(r"exactly (\d+) pixels of (\w+) are (.+)$", text)
    if m:
        want = evaluate(m.group(3), env)
        n = sum(1 for p in env[m.group(2)].pixels if p.approx(want))
        if n != int(m.group(1)):
            raise StepError("counted %d" % n)
        return
    m = re.match(r'line (\d+) of (\w+) is "(.*)"$', text)
    if m:
        got = env[m.group(2)].split("\n")[int(m.group(1)) - 1]
        if got != m.group(3):
            raise StepError("line was %r" % got)
        return
    m = re.match(r"every line of (\w+) is at most (\d+) characters$", text)
    if m:
        for i, line in enumerate(env[m.group(1)].split("\n")):
            if len(line) > int(m.group(2)):
                raise StepError("line %d is %d characters" % (i + 1, len(line)))
        return
    m = re.match(r'(\w+) begins with "(.*)"$', text)
    if m:
        want = eval('"' + m.group(2) + '"')
        got = env[m.group(1)]
        if isinstance(got, bytes):
            want = want.encode("latin-1")
        if not got.startswith(want):
            raise StepError("begins with %r" % got[:len(want) + 4])
        return
    m = re.match(r"byte (\d+) of (\w+) = (\d+)$", text)
    if m:
        got = env[m.group(2)][int(m.group(1)) - 1]
        if got != int(m.group(3)):
            raise StepError("byte was %d" % got)
        return
    m = re.match(r"(\w+) ends with a newline character$", text)
    if m:
        if not env[m.group(1)].endswith("\n"):
            raise StepError("no trailing newline")
        return
    m = re.match(r"(.+?) ≤ (.+)$", text)
    if m:
        a, b = evaluate(m.group(1), env), evaluate(m.group(2), env)
        if not a <= b:
            raise StepError("%r > %r" % (a, b))
        return
    m = re.match(r"(.+?) ≥ (.+)$", text)
    if m:
        a, b = evaluate(m.group(1), env), evaluate(m.group(2), env)
        if not a >= b:
            raise StepError("%r < %r" % (a, b))
        return
    m = re.match(r"(.+?) (=|≠) (.+?)" + EPS_RE + "$", text)
    if m:
        a, b = evaluate(m.group(1), env), evaluate(m.group(3), env)
        eps = float(m.group("eps")) if m.group("eps") else R.EPSILON
        eq = approx_equal(a, b, eps)
        if (m.group(2) == "=") != eq:
            raise StepError("%r %s %r (± %g) is false" % (a, m.group(2), b, eps))
        return
    raise StepError("unknown step: " + text)


def parse(path):
    """yield (scenario name, [(step text, docstring, table or None), ...]) with outlines expanded"""
    lines = path.read_text(encoding="utf-8").split("\n")
    scenarios, cur, examples, in_examples, i = [], None, None, False, 0
    while i < len(lines):
        raw = lines[i]
        s = raw.strip()
        i += 1
        if s.startswith("Scenario Outline:"):
            cur = (s.split(":", 1)[1].strip(), []); examples = []; in_examples = False
            scenarios.append((cur, examples))
        elif s.startswith("Scenario:"):
            cur = (s.split(":", 1)[1].strip(), []); examples = None; in_examples = False
            scenarios.append((cur, None))
        elif s.startswith("Examples"):
            in_examples = True
        elif s.startswith("|") and cur:
            cells = [c.strip() for c in s.strip("|").split("|")]
            if in_examples:
                examples.append(cells)
            else:                                 # a data table under the step before it
                step, table = cur[1][-1]
                table = table if isinstance(table, list) else []
                table.append(cells)
                cur[1][-1] = (step, table)
        elif re.match(r"(Given|When|Then|And|But)\b", s) and cur:
            step = re.sub(r"^(Given|When|Then|And|But)\s+", "", s)
            docstring = None
            if i < len(lines) and lines[i].strip() == '"""':
                indent = len(lines[i]) - len(lines[i].lstrip())
                i += 1
                buf = []
                while lines[i].strip() != '"""':
                    buf.append(lines[i][indent:]); i += 1
                i += 1
                docstring = "\n".join(buf)
            cur[1].append((step, docstring))
    out = []
    for (name, steps), ex in scenarios:
        if ex is None:
            out.append((name, steps))
        else:
            header, rows = ex[0], ex[1:]
            for row in rows:
                sub = dict(zip(header, row))
                out.append((name + " " + str(row),
                            [(re.sub(r"<(\w+)>", lambda m: sub[m.group(1)], t), d) for t, d in steps]))
    return out


def main(argv):
    targets = [Path(a) for a in argv] or sorted((ROOT / "features").glob("chapter*.feature"))
    total = failed = 0
    for f in targets:
        for name, steps in parse(f):
            total += 1
            R.set_linear_blending(True)
            env = make_env()
            try:
                for text, doc in steps:
                    run_step(text, doc, env)
            except StepError as e:
                failed += 1
                print("FAIL %s :: %s\n     %s" % (f.name, name, e))
    R.set_linear_blending(True)
    print("%d scenarios, %d failed" % (total, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
