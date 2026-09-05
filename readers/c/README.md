# The 2D Renderer Challenge — chapters 1 and 2, in C11

Run everything from this directory (the tests read `reference/` by relative path).

    make          # build bin/tests and bin/render (clang, -std=c11, libm)
    make test     # every scenario in features/, chapter 1 and chapter 2
    make render   # write the chapters' pictures into out/

`make test` prints a per-chapter subtotal and then a total; it exits non-zero if
anything failed. `TIMING=1 ./bin/tests` adds a per-feature time.

`make render` writes chapter 1's pictures as P3 text (`out/gray-match.ppm`,
`quarter-match`, `ramp`, `clamp-pair`, `plate-01`) and chapter 2's as P6 binary
(`out/disc-centers.ppm`, `out/disc-coverage.ppm`, `out/painted-twice.ppm`,
`out/plate-02.ppm`). The four chapter-2 files are byte-identical to
`reference/chapter-02/`.

Layout: `src/renderer.h` and `src/renderer.c` are the renderer, `src/tests.c` is
one function per feature file and one `S(...)` block per scenario,
`src/harness.c` is the assert helpers, `src/main.c` writes the pictures.
