# The 2D Renderer Challenge — Java

Chapters 1-2, hand-rolled test runner, no JUnit, no network.

## Compile, test, render

Run from this directory (`reference/` and `features/` resolve as relative paths):

```
javac -d classes src/*.java
java -cp classes Chapter01Tests
java -cp classes Chapter02Tests
```

Each run prints one `PASS`/`FAIL` line per scenario, a pass/fail total, and
then writes that chapter's renders to `out/` (chapter 1 as P3, chapter 2 as
P6): `out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
`out/plate-02.ppm`.
